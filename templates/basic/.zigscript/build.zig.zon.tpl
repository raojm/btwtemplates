.{
    .name = .{{PROJECT_NAME_SNAKE}},
    .version = "0.0.1",
    .fingerprint = 0x0000000000000000,
    .minimum_zig_version = "0.16.0",
    .dependencies = .{
        .zigscript = .{ .path = "{{ZIGSCRIPT_PATH}}" },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
