.{
    .name = .{{PROJECT_NAME_SNAKE}},
    .version = "0.0.1",
    .fingerprint = 0x0,
    .minimum_zig_version = "0.16.0",
    .dependencies = .{
        // zigscript 路径在项目打开时由 editor 通过 `zig fetch --save=zigscript <data_dir>/zigscript/<version>` 自动注入
        // 不需要手动填写，每个人机器路径不同
        .zigscript = .{
            .url = "zigscript:PENDING_FETCH",
            .hash = "zigscript:PENDING_FETCH",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
