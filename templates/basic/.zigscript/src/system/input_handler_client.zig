//! 输入处理系统 — 客户端专用

const component = @import("component");
const builtin = component.builtin;
const input = component.input;
const game_types = @import("game_types");

pub const system_handle_player_input_meta = game_types.SystemAnnotation{ .display_name = "处理玩家输入", .phase = .OnUpdate };
pub export fn system_handle_player_input(input_data: *input.PlayerInput, request_tag: *builtin.LocalRequestTag) void {
    if (input_data.processed) return;
    // 在此处理输入逻辑
    input_data.processed = true;
}
