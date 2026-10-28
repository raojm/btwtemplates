//! 项目构建包装（模板实例化：{{MODULES}} 由 template.json "modules" 渲染）
const std = @import("std");
const Dir = std.Io.Dir;

/// zig 0.17：`Build.build_root` 已移除。`Dependency.builder.root` 的 `joinString`
/// 在依赖构建里可能返回相对路径（`Cache.Directory.path` 为 null 表示 cwd）⇒
/// 非绝对时按当前工作目录（= 顶层构建根）解析为绝对路径。
fn rootAbs(b: *std.Build, root: std.Build.Cache.Path) []const u8 {
    const raw = root.joinString(b.allocator, "") catch ".";
    if (std.fs.path.isAbsolute(raw)) return raw;
    const cwd = std.process.currentPathAlloc(b.graph.io, b.allocator) catch ".";
    defer b.allocator.free(cwd);
    return std.fs.path.resolve(b.allocator, &.{ cwd, raw }) catch ".";
}

const GamePhysics = struct { backend: []const u8 = "none", tier: []const u8 = "kinematic" };

/// ★ 物理后端默认值 = game.json 的 `physics`（2026-10-28）。
///   此前 wrapper 写死 `orelse "none"`，而 wasm 构建（xtask）按 game.json 传
///   `-Dphysics=custom -Dphysics-tier=kinematic` ⇒ 同一开发轮里 **dylib 与 wasm
///   的 physics_backend 不一致** ⇒ build_fingerprint 不同 ⇒ 回放版本门判 preview
///   （实测 fps_lifecycle：录制 0xa7a5 vs 引擎 0xea73，测试空转）。
///   现在裸 `zig build` 与 wasm 构建取同一真相源；显式 `-Dphysics` 仍优先。
fn readGamePhysics(b: *std.Build, project_root: []const u8) GamePhysics {
    var out = GamePhysics{};
    const path = std.fs.path.join(b.allocator, &.{ project_root, "game.json" }) catch return out;
    const raw = Dir.readFileAlloc(Dir.cwd(), b.graph.io, path, b.allocator, .unlimited) catch return out;
    defer b.allocator.free(raw);
    const parsed = std.json.parseFromSlice(std.json.Value, b.allocator, raw, .{}) catch return out;
    defer parsed.deinit();
    const obj = switch (parsed.value) {
        .object => |o| o,
        else => return out,
    };
    const phys = obj.get("physics") orelse return out;
    const pobj = switch (phys) {
        .object => |o| o,
        else => return out,
    };
    if (pobj.get("backend")) |v| {
        if (v == .string) out.backend = b.allocator.dupe(u8, v.string) catch out.backend;
    }
    if (pobj.get("tier")) |v| {
        if (v == .string) out.tier = b.allocator.dupe(u8, v.string) catch out.tier;
    }
    return out;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const project_root = b.option([]const u8, "project-root", "Project root directory (parent of .zigscript/)") orelse blk: {
        const cwd = std.process.currentPathAlloc(b.graph.io, b.allocator) catch unreachable;
        defer b.allocator.free(cwd);
        break :blk std.fs.path.resolve(b.allocator, &.{ cwd, ".." }) catch unreachable;
    };

    const build_client = b.option(bool, "client", "Build only client library") orelse false;
    const build_server = b.option(bool, "server", "Build only server library") orelse false;
    // ★ editor 透传（2026-09-18）：框架侧早已提供 -Deditor（zigscript/build.zig 的
    //   build_both = !client and !server and !editor），但游戏包装此前只透传 client/server
    //   → 在游戏目录下 `zig build -Deditor` 直接报 "invalid option"，且开发期惯用的
    //   `zig build -Dserver && zig build -Dclient` **永不产 libzigscript_editor.dylib**，
    //   editor 只能靠无参数全建顺带更新，而这一步最容易被省。
    //   实证（2026-09-18 盘点，判据 = dylib mtime vs 源码最后提交时间，路径限 .zigscript/src +
    //   kernel）：GameHub editor 落后 18 个提交（D-1~D-4 全在内）、GodotTest1 落后 1、
    //   ZombieGame 落后 2；FPSDemo 三产物当时均新鲜（此处仅补齐选项语义）—— 而编辑器
    //   catalog 正是从 editor dylib 读组件元数据（offset/size 运行时真值）
    //   ⇒ 陈旧 editor = 编辑态假绿源。
    const build_editor = b.option(bool, "editor", "Build only editor library") orelse false;
    const static_lib = b.option(bool, "static-lib", "Build a static library (.a) for wasm") orelse false;
    const import_memory = b.option(bool, "import-memory", "Import shared memory from env (mode A)") orelse false;
    const import_table = b.option(bool, "import-table", "Import shared function table from env (mode A)") orelse false;

    // ★ 是否在构建完静态库后自动重链 WASM 播放引擎（模式B：engine_play_full.wasm）。
    //   默认关闭：普通 `zig build` / `zig build -Dclient` 是日常迭代路径，触发完整
    //   cargo + wasm 重链会拖慢迭代且强依赖 wasm 工具链（wasm32-wasip1 target）。
    //   需要生成引擎 wasm 时显式传 `-Dwasm-engine`，或用 `cargo run -p xtask -- build-wasm`
    //   （xtask 内部三阶段流程自带 `-Dwasm-engine=false` 防递归）。
    const wasm_engine = b.option(bool, "wasm-engine", "Auto-build engine_play_full.wasm (mode B) after static lib") orelse false;

    // W2 调度桥（双端产出）：同扫描序额外产出 C 宿主端表
    //   rustserver/crates/libs/wasm_host/src/c/wasm_ffi_gen.h（宿主核心用；
    //   2026-09-11 收敛：宿主核心 C 源已迁入 wasm_host/src/c，btwlabs 改为消费方）。
    const wasm_ffi_gen_c = b.option(bool, "wasm-ffi-gen-c", "Also generate C host dispatch table (wasm_ffi_gen.h) for WAMR PoC host") orelse false;

    // W3b：vtable wasm 桥接透传（仅 wasm 目标 + PoC 链路开启；见 zigscript/src/vt_wasm.zig）。
    const vt_bridge = b.option(bool, "vt-bridge", "W3b: wire ScriptContext.vtable to the bw_vt_* extern-import bridge (wasm PoC host only)") orelse false;

    // P2：L1 共享玩法模块选配——透传给 zigscript 框架。
    //   未传 = "all"（全部启用）；-Dmodules= 空 = 全不启用；逗号列表 = 按名启用。
    // ★ 模板选配的 L1 模块（P8）：{{MODULES}} 由 template.json "modules" 渲染
    //   （空 = 不启用任何 L1 模块；逗号列表 = 精确集合；CLI -Dmodules= 可临时覆盖）。
    const modules = b.option([]const u8, "modules", "L1 gameplay modules: all | empty(none) | comma list") orelse "{{MODULES}}";

    // ★ 物理后端透传（2026-10-27，S0.8）：框架侧提供 -Dphysics / -Dphysics-tier，
    //   包装必须声明并转发。漏转发 = **静默 no-op**（命令成功但产物没变，
    //   比报 invalid option 难查得多）——与 -Deditor / -Dstatic-lib 同族缺陷。
    //   判据固化：scripts/check-zig-build-options.ts（框架 option 面 = 各包装透传面）。
    // ★ 默认值来自 game.json（readGamePhysics）；显式 -Dphysics 仍优先。
    const game_physics = readGamePhysics(b, project_root);
    const physics = b.option([]const u8, "physics",
        "Physics backend: none|custom|box2d|box3d|rapier") orelse game_physics.backend;
    const physics_tier = b.option([]const u8, "physics-tier",
        "custom tier: query|kinematic|rigid") orelse game_physics.tier;

    // K1：解析 bwkernel 包根路径，透传为 zigscript 的 -Dgameplay-root 附加扫描根
    const kernel = b.dependency("bwkernel", .{});
    const kernel_path = rootAbs(b, kernel.builder.root);

    const zigscript = b.dependency("zigscript", .{
        .modules = modules,
        .target = target,
        .optimize = optimize,
        .@"project-path" = project_root,
        .server = build_server,
        .client = build_client,
        .editor = build_editor,
        .@"static-lib" = static_lib,
        .@"import-memory" = import_memory,
        .@"import-table" = import_table,
        .@"wasm-ffi-gen-c" = wasm_ffi_gen_c,
        .@"vt-bridge" = vt_bridge,
        .@"gameplay-root" = kernel_path,
        .@"physics" = physics,
        .@"physics-tier" = physics_tier,
    });

    b.getInstallStep().dependOn(zigscript.builder.getInstallStep());

    // ★ 模式A 游戏逻辑独立 wasm（分模块方案）：构建后部署到 static/wasm/games/[game_id].wasm。
    //   仅当 import-memory / import-table（独立模块，import 共享内存/表）时生效。
    //   源为 zigscript 复制的项目 lib/libzigscript_client_modular.wasm，按 game.json 的 game_id 组织。
    //   ★ 后缀命名（2026-09-21）：本档 _modular（分模块：与 engine_play_modular_<game_id>.wasm 配对，
    //     2026-09-25 起引擎段 per-game 命名，xtask build-wasm --game <Name> 同轮产配套对）
    //     与 WAMR 宿主档 _host（lib/libzigscript_client_host.wasm）曾同名同路径，浏览器档
    //     构建会静默覆写 WAMR 档（宿主全 trap、world_hash 恒 0）。规则见 zigscript/build.zig。
    if (import_memory or import_table) {
        const repo_root = std.fs.path.resolve(b.allocator, &.{ project_root, "..", ".." }) catch unreachable;
        const static_games = std.fs.path.join(b.allocator, &.{ repo_root, "btweditor", "static", "wasm", "games" }) catch unreachable;
        const game_json_path = std.fs.path.join(b.allocator, &.{ project_root, "game.json" }) catch unreachable;
        const game_id = readGameId(game_json_path, b);
        const src = std.fs.path.join(b.allocator, &.{ project_root, "lib", "libzigscript_client_modular.wasm" }) catch unreachable;
        const dst = std.fs.path.join(b.allocator, &.{ static_games, b.fmt("{d}.wasm", .{ game_id }) }) catch unreachable;
        // ★ zig 0.17：自定义 Step 已移除，复用 zigscript 框架的 write-if-changed 复制辅助 exe。
        const copy_step = b.addRunArtifact(zigscript.artifact("copy-if-changed"));
        copy_step.addArg(src);
        copy_step.addArg(dst);
        copy_step.step.dependOn(zigscript.builder.getInstallStep());
        b.getInstallStep().dependOn(&copy_step.step);
    }

    // 静态库构建完成后，自动重链 gamescript.wasm 并复制到前端。
    // 复用 xtask build-wasm（内含跨平台复制 + cargo 重链），避免另写一套。
    if (wasm_engine) {
        const repo_root = std.fs.path.resolve(b.allocator, &.{ project_root, "..", ".." }) catch unreachable;
        const rustserver = std.fs.path.join(b.allocator, &.{ repo_root, "rustserver" }) catch unreachable;
        const cargo_toml = std.fs.path.join(b.allocator, &.{ rustserver, "Cargo.toml" }) catch unreachable;

        const run = b.addSystemCommand(&.{ "cargo", "run", "-p", "xtask", "--manifest-path", cargo_toml, "--", "build-wasm" });
        run.step.dependOn(zigscript.builder.getInstallStep());
        b.getInstallStep().dependOn(&run.step);
    }
}

/// 从 game.json 读取 game_id（u32）。缺失或解析失败回退到 1001。
fn readGameId(game_json_path: []const u8, b: *std.Build) u32 {
    const io = b.graph.io;
    const gpa = b.allocator;
    const raw = Dir.readFileAlloc(Dir.cwd(), io, game_json_path, gpa, .unlimited) catch return 1001;
    defer gpa.free(raw);
    const parsed = std.json.parseFromSlice(std.json.Value, gpa, raw, .{}) catch return 1001;
    defer parsed.deinit();
    const id = parsed.value.object.get("game_id") orelse return 1001;
    return switch (id) {
        .integer => |v| @intCast(v),
        else => 1001,
    };
}

// ★ zig 0.17 迁移（2026-10-09）：原 `GameWasmCopyStep`（自定义 Step）已删除 ——
//   0.17 移除自定义 Step 机制。改为复用 zigscript 的 `copy-if-changed` 辅助 exe
//   （write-if-changed，见调用点）。
