//! 内置组件 (Builtin Components)
//!
//! 这些组件与 Rust gamescript 同步，ID 范围 10-801。
//! 不要修改此文件中的 ID，它们必须与服务器端一致。

const SyncTier = enum(u8) {
    None = 0,
    ClientToServer = 1,
    ServerToClient = 2,
    Bidirectional = 3,
};

/// 实体唯一ID (id=10, version=1)
pub const EntityUniqueID = extern struct {
    pub const COMPONENT_ID: u16 = 10;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .ServerToClient;

    unique_id: u64,
    owner_unique_id: u64,
};

/// 位置组件 (id=30, version=1)
pub const Position = extern struct {
    pub const COMPONENT_ID: u16 = 30;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .ServerToClient;

    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
};

/// 速度组件 (id=31, version=1)
pub const Velocity = extern struct {
    pub const COMPONENT_ID: u16 = 31;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .ClientToServer;

    vx: f32 = 0.0,
    vy: f32 = 0.0,
    vz: f32 = 0.0,
};

/// 游戏房间标签 (id=50, version=1)
pub const GameRoomTag = extern struct {
    pub const COMPONENT_ID: u16 = 50;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;
};

/// 本地请求标签 (id=60, version=1)
pub const LocalRequestTag = extern struct {
    pub const COMPONENT_ID: u16 = 60;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;
};

/// 登录请求 (id=500, version=1)
pub const LoginRequest = extern struct {
    pub const COMPONENT_ID: u16 = 500;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .ClientToServer;
};

/// 登录响应 (id=501, version=1)
pub const LoginResponse = extern struct {
    pub const COMPONENT_ID: u16 = 501;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .ServerToClient;

    result_id: i32,
    _padding1: u32,
    role_uin: i64,
    role_name: [64]u8,
};
