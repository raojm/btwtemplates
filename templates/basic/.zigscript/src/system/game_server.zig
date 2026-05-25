//! 游戏服务端系统 — 处理登录请求

const game_instance = @import("game_instance");
const component = @import("component");
const builtin = component.builtin;
const game_types = @import("game_types");
const log = @import("log").scoped("game");

pub const process_login_request_meta = game_types.SystemAnnotation{ .display_name = "处理登录请求", .phase = .OnUpdate };
pub export fn process_login_request(ctx: *game_instance.ScriptContext, request: *builtin.LoginRequest) callconv(.c) i32 {
    _ = request;
    const current_entity = ctx.current_entity_id;
    var request_unique_id: u64 = 0;
    if (current_entity != 0) {
        if (ctx.getComponent(current_entity, builtin.EntityUniqueID)) |*uid| {
            request_unique_id = uid.unique_id;
        }
    }

    var resp = builtin.LoginResponse{
        .result_id = 0,
        ._padding1 = 0,
        .role_uin = 10000,
        .role_name = [_]u8{0} ** 64,
    };

    _ = ctx.addComponentWithUniqueIdEx(request_unique_id, builtin.LoginResponse, &resp, @intFromEnum(game_instance.SyncFlag.ResponseComponent)) catch |err| {
        log.err("Failed to add LoginResponse: {}", .{err});
        return -1;
    };

    log.debug("LoginResponse added (unique_id=0x{x})", .{request_unique_id});
    return 0;
}
