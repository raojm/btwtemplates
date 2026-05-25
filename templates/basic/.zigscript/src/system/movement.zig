//! 移动系统 — 共用

const component = @import("component");
const builtin = component.builtin;
const game_types = @import("game_types");

pub const update_movement_meta = game_types.SystemAnnotation{ .display_name = "更新移动", .phase = .OnUpdate };
pub export fn update_movement(pos: *builtin.Position, vel: *builtin.Velocity) c_int {
    const delta: f32 = 0.016;
    pos.x += vel.vx * delta;
    pos.y += vel.vy * delta;
    pos.z += vel.vz * delta;
    return 0;
}
