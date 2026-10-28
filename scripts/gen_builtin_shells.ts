#!/usr/bin/env bun
/**
 * gen_builtin_shells.ts —— 从框架基线再生各模板的 builtin 薄壳 re-export 段。
 *
 * 为什么存在（2026-10-29 J1 全链实证）：模板壳是手冻结的快照——框架基线每加一个
 * 共享组件（如 10-27 的 PhysicsWorldConfig），所有模板立刻缺 re-export，生成期
 * tracked_component 断言 `component_builtin.<X>` 直接编译炸，且错误指向生成物
 * 而非模板壳（最难归因的一类）。本脚本把「补别名」从手工记忆变成一条命令：
 *
 *   bun scripts/gen_builtin_shells.ts   # 再生全部模板壳（保持私有段原样）
 *
 * 规则：
 *   · re-export 段 = 框架基线（<repo>/zigscript/src/component/builtin.zig）的
 *     全部顶层 `pub const X =`，逐个 `pub const X = shared.X;`（超集无害）；
 *   · 私有段 = 模板壳里 `// ---- … 模板私有扩展 ----` 及其后内容，原样保留；
 *   · 私有名与基线重名 = fail-loud（防静默遮蔽）；
 *   · 头部与 import 段取自现有壳（保留各模板自己的说明行）。
 *
 * 打包发布链路：先跑本脚本再跑 pack.ts（CI 的 pack-and-release 不跑它——模板源
 * 变更仍需人工/工具提交，见 docs 里 journey 台账的「模板壳 freshness」条目）。
 */
import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = resolve(fileURLToPath(import.meta.url), "..");
const REPO_DIR = resolve(SCRIPT_DIR, ".."); // btwtemplates/
const BYTEWORLD_ROOT = resolve(REPO_DIR, ".."); // 主仓根（zigscript/ 在此）
const FRAMEWORK_BUILTIN = join(BYTEWORLD_ROOT, "zigscript", "src", "component", "builtin.zig");
const TEMPLATES_DIR = join(REPO_DIR, "templates");

const fw = readFileSync(FRAMEWORK_BUILTIN, "utf8");
const fwNames = [...fw.matchAll(/^pub const ([A-Za-z0-9_]+) =/gm)].map((m) => m[1]);
if (fwNames.length === 0) {
    console.error(`[gen-shells] 框架基线无顶层 pub const（${FRAMEWORK_BUILTIN}）——文件挪动了吗？`);
    process.exit(1);
}

const templates = readdirSync(TEMPLATES_DIR).filter((d) => !d.startsWith("."));
let failed = 0;

for (const tid of templates) {
    const shellPath = join(TEMPLATES_DIR, tid, ".zigscript", "src", "component", "builtin.zig");
    let shell: string;
    try {
        shell = readFileSync(shellPath, "utf8");
    } catch {
        console.log(`[gen-shells] ${tid}: 无 builtin 壳，跳过`);
        continue;
    }

    // 私有段起点：含「模板私有扩展」的 // ---- 标记行（re-export 段的
    // "// ---- 共享组件 re-export…" 也是 // ---- 开头，不能用首出现当私有段）。
    const privMarkerMatch = /^(\/\/ ---- .*(模板私有|私有扩展).*----)$/m.exec(shell);
    if (!privMarkerMatch) {
        console.log(`[gen-shells] ${tid}: 无私有扩展标记，整壳保持原样（本脚本只管有私有段的壳）`);
        continue;
    }
    const privIdx = privMarkerMatch.index;
    const privateSection = shell.slice(privIdx);

    // 头部 = 现有壳的说明 + import 段（到 re-export 段标记行前）
    const reexportMarker = shell.indexOf("// ---- 共享组件 re-export");
    if (reexportMarker < 0) {
        console.error(`[gen-shells] ${tid}: 找不到「共享组件 re-export」段标记`);
        failed++;
        continue;
    }
    const header = shell.slice(0, reexportMarker).trimEnd();

    // 冲突守卫：私有段里的顶层名不得与基线重名
    const privNames = [...privateSection.matchAll(/^pub const ([A-Za-z0-9_]+) =/gm)].map((m) => m[1]);
    const clash = privNames.filter((n) => fwNames.includes(n));
    if (clash.length > 0) {
        console.error(`[gen-shells] ${tid}: 私有组件与框架基线重名（遮蔽危险，fail-loud）：${clash.join(", ")}`);
        failed++;
        continue;
    }

    const out =
        `${header}\n\n// ---- 共享组件 re-export（与共享基线声明一一对应；由 scripts/gen_builtin_shells.ts 再生，勿手改）----\n\n` +
        fwNames.map((n) => `pub const ${n} = shared.${n};`).join("\n") +
        "\n\n" +
        privateSection;

    if (out === shell) {
        console.log(`[gen-shells] ${tid}: 已是最新（${fwNames.length} 个基线组件）`);
        continue;
    }
    writeFileSync(shellPath, out);
    console.log(`[gen-shells] ${tid}: 再生完成（基线 ${fwNames.length} 个 / 私有 ${privNames.length} 个）`);
}

if (failed > 0) {
    console.error(`[gen-shells] ${failed} 个模板失败`);
    process.exit(1);
}
console.log("[gen-shells] 完成");
