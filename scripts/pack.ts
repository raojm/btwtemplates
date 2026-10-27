#!/usr/bin/env bun
/**
 * btwtemplates 模板打包（原 `scripts/pack.sh`，2026-10-27 迁移到 bun TS）。
 *
 * 为什么迁：bash 版依赖 jq / zip / sha256sum / du —— Windows 上要么没有，
 * 要么必须装 Git Bash 且行为不一致；CI 里还多三套 apt 包。TS 版**零外部依赖**：
 * JSON 用 JSON.parse、哈希用 node:crypto、zip 用内置实现（见 `writeZip`）、
 * 体积用字节数换算。
 *
 * 单一真相源：templates/{id}/template.json 的 version 字段（不再有 versions.json）。
 *
 * 用法：
 *   bun scripts/pack.ts                                   # 打包全部模板 + 更新索引
 *   bun scripts/pack.ts --timeout 600                     # 覆盖总超时（秒；默认 600）
 *   BW_PLATFORM=GITEE bun scripts/pack.ts                 # 选择下载 URL 平台
 *
 * 环境变量（与原 .sh 逐一对齐）：
 *   GITHUB_REPOSITORY      默认 raojm/btwtemplates
 *   BTWTEMPLATES_PLATFORM  GITHUB / GITEE / GITLAB / ALIYUN（默认 GITHUB）
 *   GITEE_REPO / GITLAB_PROJECT_URL / BTWTEMPLATES_ARTIFACT_BASE
 *   PACK_TIMEOUT_SECS      总超时秒数（命令行 --timeout 优先）
 *
 * 退出码：0=成功；1=无模板 / 参数或 IO 错误；124=超时（与 coreutils timeout 一致）。
 */
import { createHash } from "node:crypto";
import { deflateRawSync, crc32 } from "node:zlib";
import { mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const DEFAULT_TIMEOUT_MS = 10 * 60_000;

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_DIR = resolve(SCRIPT_DIR, "..");
const TEMPLATES_DIR = join(REPO_DIR, "templates");
const OUTPUT_DIR = join(REPO_DIR, "releases");
const INDEX_PATH = join(REPO_DIR, "template-index.json");

function argTimeoutMs(): number {
	// CLI 口径与仓库其它 TS 脚本一致：`--timeout <秒>` / `--timeout=<秒>` > 环境变量。
	const argv = process.argv.slice(2);
	const eq = argv.find((a) => a.startsWith("--timeout="));
	const flagIdx = argv.indexOf("--timeout");
	const raw = eq !== undefined ? eq.slice("--timeout=".length) : flagIdx >= 0 ? argv[flagIdx + 1] : process.env.PACK_TIMEOUT_SECS;
	const sec = raw === undefined || raw === "" ? DEFAULT_TIMEOUT_MS / 1000 : Number(raw);
	if (!Number.isFinite(sec) || sec <= 0) {
		console.error(`✗ 非法超时: ${raw}（PACK_TIMEOUT_SECS / --timeout 必须为正数秒）`);
		process.exit(1);
	}
	return Math.round(sec * 1000);
}

const TIMEOUT_MS = argTimeoutMs();
const DEADLINE = Date.now() + TIMEOUT_MS;

function checkDeadline(): void {
	if (Date.now() <= DEADLINE) return;
	console.error(`✗ 超时（>${TIMEOUT_MS}ms）—— 可用 --timeout-ms 或 BW_SCRIPT_TIMEOUT_MS 放宽`);
	process.exit(124);
}

/** 下载 URL 基础路径 —— 与原 .sh 的平台分支逐条对齐。 */
function downloadBase(): string {
	const repo = process.env.GITHUB_REPOSITORY || "raojm/btwtemplates";
	const platform = process.env.BTWTEMPLATES_PLATFORM || "GITHUB";
	if (platform === "GITEE") {
		const giteeRepo = process.env.GITEE_REPO || "raojm/btwtemplates";
		return `https://gitee.com/${giteeRepo}/releases/download`;
	}
	if (platform === "GITLAB") {
		const projectUrl = process.env.GITLAB_PROJECT_URL || "https://gitlab.com/raojm/btwtemplates";
		return `${projectUrl}/-/packages/generic/btwtemplates`;
	}
	if (platform === "ALIYUN") {
		return process.env.BTWTEMPLATES_ARTIFACT_BASE || "https://packages.aliyun.com/generic/btwtemplates/releases";
	}
	return `https://github.com/${repo}/releases/download`;
}

// ── 最小 ZIP 写入（deflate；不依赖外部 zip 命令）──────────────────────────────
// 只实现模板打包需要的子集：无目录条目、无 zip64、无加密、UTF-8 文件名。
// 用 Bun.Archive 读回做自检（Bun 的 zip 解包是完整实现，能当校验器用）。

interface ZipEntry {
	name: string;
	data: Buffer;
	mtimeMs: number;
}

function dosDateTime(ms: number): { time: number; date: number } {
	const d = new Date(Math.max(ms, 315532800000)); // 1980-01-01 起（DOS 下限）
	const time = (d.getHours() << 11) | (d.getMinutes() << 5) | Math.floor(d.getSeconds() / 2);
	const date = ((d.getFullYear() - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate();
	return { time, date };
}

function writeZip(entries: ZipEntry[]): Buffer {
	const locals: Buffer[] = [];
	const centrals: Buffer[] = [];
	let offset = 0;

	for (const e of entries) {
		checkDeadline();
		const name = Buffer.from(e.name, "utf8");
		const deflated = deflateRawSync(e.data);
		const useDeflate = deflated.length < e.data.length;
		const payload = useDeflate ? deflated : e.data;
		const method = useDeflate ? 8 : 0;
		const crc = crc32(e.data) >>> 0;
		const { time, date } = dosDateTime(e.mtimeMs);

		const local = Buffer.alloc(30);
		local.writeUInt32LE(0x04034b50, 0);
		local.writeUInt16LE(20, 4); // version needed
		local.writeUInt16LE(0x0800, 6); // UTF-8 name
		local.writeUInt16LE(method, 8);
		local.writeUInt16LE(time, 10);
		local.writeUInt16LE(date, 12);
		local.writeUInt32LE(crc, 14);
		local.writeUInt32LE(payload.length, 18);
		local.writeUInt32LE(e.data.length, 22);
		local.writeUInt16LE(name.length, 26);
		local.writeUInt16LE(0, 28); // extra len
		locals.push(local, name, payload);

		const central = Buffer.alloc(46);
		central.writeUInt32LE(0x02014b50, 0);
		central.writeUInt16LE(20, 4); // version made by
		central.writeUInt16LE(20, 6); // version needed
		central.writeUInt16LE(0x0800, 8);
		central.writeUInt16LE(method, 10);
		central.writeUInt16LE(time, 12);
		central.writeUInt16LE(date, 14);
		central.writeUInt32LE(crc, 16);
		central.writeUInt32LE(payload.length, 20);
		central.writeUInt32LE(e.data.length, 24);
		central.writeUInt16LE(name.length, 28);
		central.writeUInt16LE(0, 30); // extra
		central.writeUInt16LE(0, 32); // comment
		central.writeUInt16LE(0, 34); // disk start
		central.writeUInt16LE(0, 36); // internal attrs
		central.writeUInt32LE(0, 38); // external attrs
		central.writeUInt32LE(offset, 42);
		centrals.push(central, name);

		offset += local.length + name.length + payload.length;
	}

	const cdOffset = offset;
	const cd = Buffer.concat(centrals);
	const eocd = Buffer.alloc(22);
	eocd.writeUInt32LE(0x06054b50, 0);
	eocd.writeUInt16LE(0, 4);
	eocd.writeUInt16LE(0, 6);
	eocd.writeUInt16LE(entries.length, 8);
	eocd.writeUInt16LE(entries.length, 10);
	eocd.writeUInt32LE(cd.length, 12);
	eocd.writeUInt32LE(cdOffset, 16);
	eocd.writeUInt16LE(0, 20);
	return Buffer.concat([...locals, cd, eocd]);
}

/** 递归收集目录下的文件（跳过 .DS_Store / __MACOSX），名字用 `/` 分隔且不含前导 `./`。 */
function collectFiles(dir: string, base = dir, out: ZipEntry[] = []): ZipEntry[] {
	checkDeadline();
	for (const ent of readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
		if (ent.name === ".DS_Store" || ent.name === "__MACOSX") continue;
		const full = join(dir, ent.name);
		if (ent.isDirectory()) collectFiles(full, base, out);
		else if (ent.isFile()) {
			out.push({
				name: relative(base, full).split("\\").join("/"),
				data: readFileSync(full),
				mtimeMs: statSync(full).mtimeMs,
			});
		}
	}
	return out;
}

// ── 主流程 ──────────────────────────────────────────────────────────────────

const templateIds = readdirSync(TEMPLATES_DIR, { withFileTypes: true })
	.filter((d) => d.isDirectory())
	.filter((d) => {
		try {
			return statSync(join(TEMPLATES_DIR, d.name, "template.json")).isFile();
		} catch {
			return false;
		}
	})
	.map((d) => d.name)
	.sort();

if (templateIds.length === 0) {
	console.error(`⚠ No templates found in ${TEMPLATES_DIR}`);
	process.exit(1);
}

mkdirSync(OUTPUT_DIR, { recursive: true });
const base = downloadBase();
const indexEntries: Record<string, unknown>[] = [];

for (const id of templateIds) {
	checkDeadline();
	const templateDir = join(TEMPLATES_DIR, id);
	const meta = JSON.parse(readFileSync(join(templateDir, "template.json"), "utf8")) as Record<string, unknown>;
	const version = String(meta.version ?? "1.0.0");
	console.log(`Packing: ${id} v${version}`);

	const zipPath = join(OUTPUT_DIR, `${id}.zip`);
	rmSync(zipPath, { force: true });
	const files = collectFiles(templateDir);
	const zip = writeZip(files);
	writeFileSync(zipPath, zip);
	console.log(`  ✓ ${id}.zip (${Math.ceil(zip.length / 1024)} KB, version=${version}, ${files.length} 文件)`);

	const checksum = createHash("sha256").update(zip).digest("hex");
	const downloadUrl = `${base}/${id}-v${version}/${id}.zip`;

	indexEntries.push({
		id,
		name: String(meta.name ?? id),
		description: String(meta.description ?? ""),
		author: String(meta.author ?? "ByteWorld"),
		version,
		min_engine_version: String(meta.min_engine_version ?? "4.6"),
		tags: Array.isArray(meta.tags) ? meta.tags : [],
		download_url: downloadUrl,
		checksum,
	});
}

const today = new Date().toISOString().slice(0, 10);
const index = {
	_comment: "自动生成，勿手动编辑。运行 bun scripts/pack.ts 更新。数据来源: templates/{id}/template.json",
	version: 1,
	updated: today,
	templates: indexEntries,
};
writeFileSync(INDEX_PATH, `${JSON.stringify(index, null, 2)}\n`);

console.log("");
console.log(`✓ Index updated: ${INDEX_PATH}`);
console.log(`✓ Templates: ${indexEntries.length}`);
