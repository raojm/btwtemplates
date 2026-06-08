//! 样板系统 (Sample System)
//!
//! 展示如何实现一个 Entity Request 系统：
//! 1. 接收客户端的 EchoRequest 组件
//! 2. 读取请求数据
//! 3. 创建 EchoResponse 组件并添加到请求实体
//!
//! 删除此文件即可移除样板代码。

const std = @import("std");
const game_types = @import("game_types");
const game_instance = @import("game_instance");
const component = @import("component");
const builtin = component.builtin;

pub const process_echo_request_meta = game_types.SystemAnnotation{ .display_name = "处理 Echo 请求", .phase = .OnUpdate };

pub export fn process_echo_request(ctx: *game_instance.ScriptContext, request: *builtin.EchoRequest) callconv(.c) u8 {
    const current_entity = ctx.current_entity_id;

    var request_unique_id: u64 = 0;
    if (ctx.getComponent(current_entity, builtin.EntityUniqueID)) |*uid| {
        request_unique_id = uid.unique_id;
    }

    var resp = builtin.EchoResponse{
        .seq = request.seq,
        .data = request.data,
        .server_time = @as(u64, @bitCast(game_types.milliTimestamp())),
    };

    _ = ctx.addComponentWithUniqueIdEx(request_unique_id, builtin.EchoResponse, &resp, @intFromEnum(game_instance.SyncFlag.ResponseComponent)) catch {
        return 1;
    };

    return 0;
}
