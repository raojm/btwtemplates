//! 输入组件 — 客户端专用
//! ID 范围: 820-899

/// 玩家输入组件 — 由 Godot 设置
pub const PlayerInput = extern struct {
    pub const COMPONENT_ID: u16 = 820;
    pub const COMPONENT_VERSION: u16 = 1;

    move_x: f32 = 0.0,
    move_y: f32 = 0.0,
    action_pressed: u32 = 0,
    target_x: f32 = 0.0,
    target_y: f32 = 0.0,
    timestamp: u64 = 0,
    processed: bool = false,
};
