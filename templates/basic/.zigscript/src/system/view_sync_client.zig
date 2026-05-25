//! 视图同步系统 — 客户端专用

const component = @import("component");
const builtin = component.builtin;
const view = component.view;
const game_types = @import("game_types");

pub const system_sync_position_to_view_meta = game_types.SystemAnnotation{
    .display_name = "同步位置到视图",
    .phase = .PostUpdate,
};
pub export fn system_sync_position_to_view(
    pos: *const builtin.Position,
    view_state: *view.ViewState,
) void {
    view_state.world_x = pos.x;
    view_state.world_y = pos.y;
    view_state.world_z = pos.z;
}
