const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const project_root = b.option([]const u8, "project-root", "Project root directory (parent of .zigscript/)") orelse blk: {
        // Zig 0.16: b.build_root is the package root, project root is its parent
        break :blk b.pathFromRoot("..");
    };

    const build_client = b.option(bool, "client", "Build only client library") orelse false;
    const build_server = b.option(bool, "server", "Build only server library") orelse false;

    const zigscript = b.dependency("zigscript", .{
        .target = target,
        .optimize = optimize,
        .@"project-path" = project_root,
        .server = build_server,
        .client = build_client,
    });

    b.getInstallStep().dependOn(zigscript.builder.getInstallStep());
}
