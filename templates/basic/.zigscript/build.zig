const std = @import("std");
const zigscript = @import("zigscript");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const project_root = b.option([]const u8, "project-root", "Project root directory") orelse "..";

    @setEvalBranchQuota(10000);
    zigscript.build(b, target, optimize, project_root);
}
