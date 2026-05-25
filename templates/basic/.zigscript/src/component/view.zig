//! View 组件 — 客户端专用
//! ID 范围: 900-999

/// 视图状态组件 — 由游戏系统更新，Godot 读取
pub const ViewState = extern struct {
    pub const COMPONENT_ID: u16 = 900;
    pub const COMPONENT_VERSION: u16 = 1;

    world_x: f32 = 0.0,
    world_y: f32 = 0.0,
    world_z: f32 = 0.0,
    rotation: f32 = 0.0,
    scale: f32 = 1.0,
    visible: bool = true,
    animation_state: u8 = 0,
    animation_progress: f32 = 0.0,
};
