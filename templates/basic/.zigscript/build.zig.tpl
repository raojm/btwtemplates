//! 项目构建包装（模板实例化：{{MODULES}} 由 template.json "modules" 渲染）
const std = @import("std");

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
    const static_lib = b.option(bool, "static-lib", "Build a static library (.a) for wasm") orelse false;
    const import_memory = b.option(bool, "import-memory", "Import shared memory from env (mode A)") orelse false;
    const import_table = b.option(bool, "import-table", "Import shared function table from env (mode A)") orelse false;

    // ★ 模板写死的 L1 模块选配（P8）：默认 {{MODULES}}；CLI -Dmodules= 可临时覆盖
    //   （all=全部启用 / 空=全不启用 / 逗号列表=精确集合）。
    const modules = b.option([]const u8, "modules", "L1 gameplay modules: all | empty(none) | comma list") orelse "{{MODULES}}";

    // ★ 是否在构建完静态库后自动重链 WASM 播放引擎（模式B）。默认关闭。
    const wasm_engine = b.option(bool, "wasm-engine", "Auto-build engine_play_full.wasm (mode B) after static lib") orelse false;

    // L3 零手工同步：透传给 zigscript 框架——按系统扫描序再生 wasm_ffi_gen.rs
    const wasm_ffi_gen = b.option(bool, "wasm-ffi-gen", "Regenerate gamescript wasm_ffi_gen.rs (Rust dispatch table)") orelse false;

    const zigscript = b.dependency("zigscript", .{
        .target = target,
        .optimize = optimize,
        .@"project-path" = project_root,
        .server = build_server,
        .client = build_client,
        .@"static-lib" = static_lib,
        .@"import-memory" = import_memory,
        .@"import-table" = import_table,
        .@"wasm-ffi-gen" = wasm_ffi_gen,
        .modules = modules,
    });

    b.getInstallStep().dependOn(zigscript.builder.getInstallStep());

    if (import_memory or import_table) {
        const repo_root = std.fs.path.resolve(b.allocator, &.{ project_root, "..", ".." }) catch unreachable;
        const static_games = std.fs.path.join(b.allocator, &.{ repo_root, "btweditor", "static", "wasm", "games" }) catch unreachable;
        const game_json_path = std.fs.path.join(b.allocator, &.{ project_root, "game.json" }) catch unreachable;
        const game_id = readGameId(game_json_path, b);
        const src = std.fs.path.join(b.allocator, &.{ project_root, "lib", "libzigscript_client.wasm" }) catch unreachable;
        const dst = std.fs.path.join(b.allocator, &.{ static_games, b.fmt("{d}.wasm", .{ game_id }) }) catch unreachable;
        const copy_step = GameWasmCopyStep.create(b, src, dst);
        copy_step.step.dependOn(zigscript.builder.getInstallStep());
        b.getInstallStep().dependOn(&copy_step.step);
    }

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
    const raw = std.Io.Dir.readFileAlloc(std.Io.Dir.cwd(), io, game_json_path, gpa, .unlimited) catch return 1001;
    defer gpa.free(raw);
    const parsed = std.json.parseFromSlice(std.json.Value, gpa, raw, .{}) catch return 1001;
    defer parsed.deinit();
    const id = parsed.value.object.get("game_id") orelse return 1001;
    return switch (id) {
        .integer => |v| @intCast(v),
        else => 1001,
    };
}

/// 跨平台复制 step：把构建产物 libzigscript_client.wasm 部署到 static/wasm/games/[game_id].wasm。
const GameWasmCopyStep = struct {
    step: std.Build.Step,
    src_path: []const u8,
    dst_path: []const u8,

    fn create(b: *std.Build, src_path: []const u8, dst_path: []const u8) *GameWasmCopyStep {
        const self = b.allocator.create(GameWasmCopyStep) catch unreachable;
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = b.fmt("copy wasm -> {s}", .{dst_path}),
                .owner = b,
                .makeFn = make,
            }),
            .src_path = src_path,
            .dst_path = dst_path,
        };
        return self;
    }

    fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
        const self: *GameWasmCopyStep = @fieldParentPtr("step", step);
        const b = step.owner;
        const io = b.graph.io;
        const gpa = b.allocator;
        const dst_dir = std.fs.path.dirname(self.dst_path) orelse ".";
        std.Io.Dir.createDir(std.Io.Dir.cwd(), io, dst_dir, .default_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        const data = std.Io.Dir.readFileAlloc(std.Io.Dir.cwd(), io, self.src_path, gpa, .unlimited) catch |err| {
            std.debug.print("GameWasmCopyStep: Failed to read '{s}': {}\n", .{ self.src_path, err });
            return err;
        };
        defer gpa.free(data);
        std.Io.Dir.writeFile(std.Io.Dir.cwd(), io, .{ .sub_path = self.dst_path, .data = data }) catch |err| {
            std.debug.print("GameWasmCopyStep: Failed to write '{s}': {}\n", .{ self.dst_path, err });
            return err;
        };
    }
};
