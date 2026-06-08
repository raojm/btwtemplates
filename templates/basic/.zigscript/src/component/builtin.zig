//! 内置组件 (Builtin Components)
//!
//! 这些组件在 Rust (gamescript) 和 Zig (zigscript) 中都有完全相同的定义。
//! 用于跨语言共享的核心游戏组件。
//!
//! 注意：修改此文件时，必须同步修改 rustserver/crates/libs/gamescript/src/builtin.rs

const std = @import("std");

// ============================================================================
// 同步层级常量 (Sync Tier Constants)
// ============================================================================

/// 同步层级
pub const SyncTier = enum(u8) {
    /// 高频同步 (50-100ms) - 位置、速度、战斗状态等实时数据
    High = 0,
    /// 中频同步 (200-1000ms) - 外观、背包、客户端状态等
    Medium = 1,
    /// 低频同步 (1000-5000ms) - 任务、成就等不常变化的数据
    Low = 2,
    /// 不同步 - 仅本地使用或系统组件
    None = 255,
};

// ============================================================================
// 枚举类型
// ============================================================================

pub const InitStatus = enum(u8) {
    none = 0,
    create = 1,
    loaded = 2,
    load_failed = 3,
    logined = 4,
    in_room = 5,
    sit_down = 6,
    playing = 7,
};

pub const QuestStatus = enum(u8) {
    none = 0,
    accepted = 1,
    active = 2,
    completed = 3,
    failed = 4,
};

pub const EffectType = enum(u8) {
    none = 0,
    damage = 1,
    heal = 2,
};

// ============================================================================
// 核心实体组件 (Core Entity Components) - ID: 10-19
// ============================================================================

/// 实体唯一标识符 (id=10, version=2)
/// 包含实体自身的 unique_id 和所有者的 owner_unique_id
/// 合并了原来的 OwnerEntityUniqueID (id=11)，逻辑处理更方便
pub const EntityUniqueID = extern struct {
    pub const COMPONENT_ID: u16 = 10;
    pub const COMPONENT_VERSION: u16 = 2;
    pub const SYNC_TIER: SyncTier = .High;
    pub const SYNC_INTERVAL_MS: u16 = 1000;

    unique_id: u64,
    owner_unique_id: u64,
};

/// 实体初始化状态 (id=12, version=1)
pub const EntityInitStatus = extern struct {
    pub const COMPONENT_ID: u16 = 12;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .Medium;
    pub const SYNC_INTERVAL_MS: u16 = 1000;

    status: InitStatus,
};

// ============================================================================
// 标签组件 (Tag Components) - ID: 13-19
// ============================================================================

/// 服务器实体标签 (id=13, version=1)
pub const ServerEntityTag = extern struct {
    pub const COMPONENT_ID: u16 = 13;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;
};

/// 游戏房间标签 (id=14, version=1)
pub const GameRoomTag = extern struct {
    pub const COMPONENT_ID: u16 = 14;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;
};

/// 游戏桌子标签 (id=15, version=1)
pub const GameTableTag = extern struct {
    pub const COMPONENT_ID: u16 = 15;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;
};

/// 游戏实体标签 (id=16, version=1)
pub const GameEntityTag = extern struct {
    pub const COMPONENT_ID: u16 = 16;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;
};

/// 本地游戏实体标签 (id=17, version=1)
pub const LocalGameEntityTag = extern struct {
    pub const COMPONENT_ID: u16 = 17;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;
};

/// 请求实体标签 (id=18, version=1)
pub const RequestEntityTag = extern struct {
    pub const COMPONENT_ID: u16 = 18;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;
};

/// 本地请求标签 (id=19, version=1)
pub const LocalRequestTag = extern struct {
    pub const COMPONENT_ID: u16 = 19;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;
};

/// 响应实体标签 (id=20, version=1)
/// 标记 Request Entity 上的 Response 已就绪
/// 用于服务端同步 Response 组件回客户端，但不会触发保存到 Redis
/// 替代在 Request Entity 上添加 ServerEntityTag 的做法
pub const ResponseEntityTag = extern struct {
    pub const COMPONENT_ID: u16 = 20;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;
};

// ============================================================================
// 玩家相关组件 (Player Components) - ID: 100-101
// ============================================================================

/// 玩家基础属性 (id=100, version=1)
pub const Player = extern struct {
    pub const COMPONENT_ID: u16 = 100;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .Medium;
    pub const SYNC_INTERVAL_MS: u16 = 500;

    player_id: u64,
    level: u32,
    _padding1: u32 = 0,
    exp: u64,
    nickname: [32]u8,
};

/// 玩家属性详情 (id=101, version=1)
pub const PlayerProperty = extern struct {
    pub const COMPONENT_ID: u16 = 101;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;
    pub const SYNC_INTERVAL_MS: u16 = 50;

    hp: i32,
    max_hp: i32,
    mp: i32,
    max_mp: i32,
    attack: i32,
    defense: i32,
    is_dead: u8,
    _padding1: [3]u8 = undefined,
    level: u32,
    exp: u64,
};

/// 玩家信息 (id=102, version=1)
pub const PlayerInfo = extern struct {
    pub const COMPONENT_ID: u16 = 102;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .Medium;
    pub const SYNC_INTERVAL_MS: u16 = 500;

    player_uin: u64,
    game_id: u32,
    gold: u32,
    diamond: u32,
    vip_level: u32,
    _padding1: u32 = 0,
};

// ============================================================================
// 认证请求组件 (Authentication Components) - ID: 200-201
// ============================================================================

/// 认证请求 (id=200, version=1)
pub const AuthenRequest = extern struct {
    pub const COMPONENT_ID: u16 = 200;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None; // 仅本地使用

    account: [64]u8,
    password: [64]u8,
    app_id: u32,
    device_type: u8,
    login_type: u8,
    reserved: u16 = 0,
};

/// 认证响应 (id=201, version=1)
pub const AuthenResponse = extern struct {
    pub const COMPONENT_ID: u16 = 201;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None; // 仅本地使用

    result_code: i32,
    _padding1: u32 = 0,
    player_uin: u64,
    session_id: u64,
    error_message: [64]u8,
};

// ============================================================================
// 位置相关组件 (Position Components) - ID: 300-302
// ============================================================================

/// 位置 (id=300, version=1)
pub const Position = extern struct {
    pub const COMPONENT_ID: u16 = 300;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;
    pub const SYNC_INTERVAL_MS: u16 = 50;

    x: f32,
    y: f32,
    z: f32,
};

/// 速度 (id=301, version=1)
pub const Velocity = extern struct {
    pub const COMPONENT_ID: u16 = 301;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;
    pub const SYNC_INTERVAL_MS: u16 = 50;

    vx: f32,
    vy: f32,
    vz: f32,
};

/// 旋转 (id=302, version=1)
pub const Rotation = extern struct {
    pub const COMPONENT_ID: u16 = 302;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;
    pub const SYNC_INTERVAL_MS: u16 = 50;

    pitch: f32,
    yaw: f32,
    roll: f32,
};

// ============================================================================
// 游戏状态组件 (Game State Components) - ID: 400-404
// ============================================================================

/// 客户端状态 (id=400, version=1)
pub const ClientState = extern struct {
    pub const COMPONENT_ID: u16 = 400;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .Medium;
    pub const SYNC_INTERVAL_MS: u16 = 500;

    is_background: u8,
    _padding1: [3]u8 = undefined,
    afk_time_ms: u32,
};

/// 技能状态 (id=401, version=1)
pub const SkillState = extern struct {
    pub const COMPONENT_ID: u16 = 401;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;
    pub const SYNC_INTERVAL_MS: u16 = 100;

    skill_id: u32,
    _padding1: u32 = 0,
    last_use_time: u64,
    cooldown: u32,
    _padding2: u32 = 0,
    target_id: u64,
};

/// 任务状态 (id=402, version=1)
pub const QuestState = extern struct {
    pub const COMPONENT_ID: u16 = 402;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .Low;
    pub const SYNC_INTERVAL_MS: u16 = 2000;

    quest_id: u32,
    status: QuestStatus,
    progress: u8,
    _padding1: [2]u8 = undefined,
};

/// 背包 (id=403, version=1)
pub const Inventory = extern struct {
    pub const COMPONENT_ID: u16 = 403;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .Medium;
    pub const SYNC_INTERVAL_MS: u16 = 1000;

    item_id_1: u32,
    count_1: u32,
    item_id_2: u32,
    count_2: u32,
    item_id_3: u32,
    count_3: u32,
    gold: u64,
};

/// 战斗效果 (id=404, version=1)
pub const CombatEffect = extern struct {
    pub const COMPONENT_ID: u16 = 404;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;
    pub const SYNC_INTERVAL_MS: u16 = 50;

    effect_type: EffectType,
    effect_id: u32,
    duration_ms: u32,
    source_id: u64,
    target_id: u64,
    value: i32,
};

// ============================================================================
// 请求组件 (Request Components) - ID: 500-504
// ============================================================================

/// 移动请求 (id=500, version=1)
pub const MoveRequest = extern struct {
    pub const COMPONENT_ID: u16 = 500;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None; // 即抛型请求

    direction_x: f32,
    direction_y: f32,
    speed: f32,
};

/// 任务请求 (id=501, version=1)
pub const QuestRequest = extern struct {
    pub const COMPONENT_ID: u16 = 501;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    quest_id: u32,
    action_type: u8,
    _padding1: [3]u8 = undefined,
};

/// 战斗请求 (id=502, version=1)
pub const CombatRequest = extern struct {
    pub const COMPONENT_ID: u16 = 502;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    skill_id: u32,
    _padding1: u32 = 0,
    target_id: u64,
};

/// 复活请求 (id=503, version=1)
pub const ReviveRequest = extern struct {
    pub const COMPONENT_ID: u16 = 503;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    revive_type: u8,
};

/// 使用物品请求 (id=504, version=1)
pub const UseItemRequest = extern struct {
    pub const COMPONENT_ID: u16 = 504;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    item_id: u32,
    slot: u8,
    _padding1: [3]u8 = undefined,
};

// ============================================================================
// 登录和房间管理请求组件 (Room Management Components) - ID: 505-514
// ============================================================================

/// 登录请求 (id=505, version=2) — 与 Rust 端一致
pub const LoginRequest = extern struct {
    pub const COMPONENT_ID: u16 = 505;
    pub const COMPONENT_VERSION: u16 = 2;
    pub const SYNC_TIER: SyncTier = .None;

    lobby_version: u32,
    game_id: u32, // 要进入的游戏 ID
    account: [64]u8,
    role_uin: u64,
    role_name: [64]u8,
};

/// 登录响应 (id=506, version=2) — 与 Rust 端一致
pub const LoginResponse = extern struct {
    pub const COMPONENT_ID: u16 = 506;
    pub const COMPONENT_VERSION: u16 = 2;
    pub const SYNC_TIER: SyncTier = .High;

    result_id: i32,
    game_id: u32, // 服务器确认的游戏 ID
    role_uin: u64,
    role_name: [64]u8,
};

/// 进入房间请求 (id=507, version=1) — 与 Rust 端一致
pub const EnterRoomRequest = extern struct {
    pub const COMPONENT_ID: u16 = 507;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    room_id: i32,
};

/// 进入房间响应 (id=508, version=1) — 与 Rust 端一致
pub const EnterRoomResponse = extern struct {
    pub const COMPONENT_ID: u16 = 508;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .Medium;

    result_id: i32,
    _padding1: u32 = 0,
    room_id: i32,
    _padding2: u32 = 0,
};

/// 坐下请求 (id=509, version=1) — 与 Rust 端一致
pub const SitDownRequest = extern struct {
    pub const COMPONENT_ID: u16 = 509;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    room_id: i32,
    table_id: i32,
    seat_id: i8,
    sit_down_type: i8,
    _padding1: [2]u8 = [_]u8{0} ** 2,
    table_name: [32]u8,
    table_passwd: [32]u8,
    game_map_id: i32,
    game_mod: i32,
};

/// 坐下响应 (id=510, version=1) — 与 Rust 端一致
pub const SitDownResponse = extern struct {
    pub const COMPONENT_ID: u16 = 510;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;

    result_id: i32,
    _padding1: u32 = 0,
    room_id: i32,
    table_id: i32,
    seat_id: i8,
    _padding2: [3]u8 = [_]u8{0} ** 3,
};

/// 站起请求 (id=511, version=1) — 与 Rust 端一致
pub const StandUpRequest = extern struct {
    pub const COMPONENT_ID: u16 = 511;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    room_id: i32,
    table_id: i32,
    mode: i32,
};

/// 站起响应 (id=512, version=1) — 与 Rust 端一致
pub const StandUpResponse = extern struct {
    pub const COMPONENT_ID: u16 = 512;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;

    result_id: i32,
    _padding1: u32 = 0,
};

/// 离开房间请求 (id=513, version=1) — 与 Rust 端一致
pub const LeaveRoomRequest = extern struct {
    pub const COMPONENT_ID: u16 = 513;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    room_id: i32,
};

/// 离开房间响应 (id=514, version=1) — 与 Rust 端一致
pub const LeaveRoomResponse = extern struct {
    pub const COMPONENT_ID: u16 = 514;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;

    result_id: i32,
    _padding1: u32 = 0,
};

// ============================================================================
// 游戏注册请求组件 (Game Registration Components) - ID: 515-516
// ============================================================================

pub const RegisterGameRequest = extern struct {
    pub const COMPONENT_ID: u16 = 515;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    game_id: u32,
    name: [64]u8,
    description: [128]u8,
    scene_path: [128]u8,
    server_dylib: [256]u8,
    client_dylib: [256]u8,
    icon_path: [128]u8,
    max_player_count: u8,
    _padding: [3]u8 = [_]u8{0} ** 3,
};

pub const RegisterGameResponse = extern struct {
    pub const COMPONENT_ID: u16 = 520;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    result_id: i32,
    _padding: u32 = 0,
    game_id: u32,
    _padding2: u32 = 0,
};

pub const LeaveGameRequest = extern struct {
    pub const COMPONENT_ID: u16 = 521;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    game_id: u32,
    _padding: u32 = 0,
};

pub const LeaveGameResponse = extern struct {
    pub const COMPONENT_ID: u16 = 522;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    result_id: i32,
    _padding: u32 = 0,
    game_id: u32,
    _padding2: u32 = 0,
};

pub const ListGameRequest = extern struct {
    pub const COMPONENT_ID: u16 = 523;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    _padding: u32 = 0,
};

pub const ListGameResponse = extern struct {
    pub const COMPONENT_ID: u16 = 524;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    result_id: i32,
    _padding: u32 = 0,
    game_count: u32,
    _padding2: u32 = 0,
};

pub const UnregisterGameRequest = extern struct {
    pub const COMPONENT_ID: u16 = 525;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    game_id: u32,
    _padding: u32 = 0,
};

pub const UnregisterGameResponse = extern struct {
    pub const COMPONENT_ID: u16 = 526;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    result_id: i32,
    _padding: u32 = 0,
    game_id: u32,
    _padding2: u32 = 0,
};

pub const EditorRole = extern struct {
    pub const COMPONENT_ID: u16 = 530;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    pub const FLAG_REGISTER_GAME: u32 = 1 << 0;
    pub const FLAG_HOT_RELOAD: u32 = 1 << 1;
    pub const FLAG_EDIT_LOGIC: u32 = 1 << 2;
    pub const FLAG_MANAGE_PLAYERS: u32 = 1 << 3;
    pub const FLAG_ALL: u32 = 0xFFFFFFFF;

    flags: u32,

    pub fn canRegisterGame(self: @This()) bool {
        return (self.flags & FLAG_REGISTER_GAME) != 0;
    }

    pub fn canHotReload(self: @This()) bool {
        return (self.flags & FLAG_HOT_RELOAD) != 0;
    }

    pub fn canEditLogic(self: @This()) bool {
        return (self.flags & FLAG_EDIT_LOGIC) != 0;
    }

    pub fn canManagePlayers(self: @This()) bool {
        return (self.flags & FLAG_MANAGE_PLAYERS) != 0;
    }
};

// ============================================================================
// 移动请求 (服务端版本) - ID: 516+
// ============================================================================

/// 移动请求 (id=516, version=1) - 服务端版本
pub const GameMoveRequest = extern struct {
    pub const COMPONENT_ID: u16 = 516;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    player_uin: u64,
    target_x: f32,
    target_y: f32,
    target_z: f32,
    velocity_x: f32,
    velocity_y: f32,
    velocity_z: f32,
};

/// 移动响应 (id=517, version=1)
pub const GameMoveResponse = extern struct {
    pub const COMPONENT_ID: u16 = 517;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;

    result_code: i32,
    current_x: f32,
    current_y: f32,
    current_z: f32,
};

// ============================================================================
// 房间和座位组件 (Room Components) - ID: 600-602
// ============================================================================

/// 房间组件 (id=600, version=1)
pub const RoomComponent = extern struct {
    pub const COMPONENT_ID: u16 = 600;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .Medium;
    pub const SYNC_INTERVAL_MS: u16 = 500;

    room_id: u32,
    room_type: u8,
    player_count: u8,
    max_players: u8,
    status: u8,
    _padding1: [4]u8 = undefined,
};

/// 座位组件 (id=601, version=1)
pub const SeatComponent = extern struct {
    pub const COMPONENT_ID: u16 = 601;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;
    pub const SYNC_INTERVAL_MS: u16 = 100;

    seat_index: u8,
    is_ready: u8,
    _padding1: [2]u8 = undefined,
    player_uin: u64,
};

// ============================================================================
// 心跳组件 (KeepAlive) - ID: 700-701
// ============================================================================

/// 心跳请求 (id=700, version=1)
pub const KeepAliveRequest = extern struct {
    pub const COMPONENT_ID: u16 = 700;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    player_uin: u64,
    timestamp: u64,
};

/// 心跳响应 (id=701, version=1)
pub const KeepAliveResponse = extern struct {
    pub const COMPONENT_ID: u16 = 701;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .Medium;

    result_code: i32,
    _padding1: u32 = 0,
    server_time: u64,
};

// ============================================================================
// Echo 组件 (Echo) - ID: 800-801
// ============================================================================

pub const EchoRequest = extern struct {
    pub const COMPONENT_ID: u16 = 800;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .None;

    seq: u64,
    data: u64,
};

pub const EchoResponse = extern struct {
    pub const COMPONENT_ID: u16 = 801;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: SyncTier = .High;

    seq: u64,
    data: u64,
    server_time: u64,
};

// ============================================================================
// 组件校验工具
// ============================================================================

/// 校验组件大小和布局
pub fn validateBuiltinComponents() void {
    const std_debug = std.debug;

    // 核心实体组件
    std_debug.assert(@sizeOf(EntityUniqueID) == 16);
    std_debug.assert(@sizeOf(EntityInitStatus) == 1);

    // 标签组件 (零大小)
    std_debug.assert(@sizeOf(ServerEntityTag) == 0);
    std_debug.assert(@sizeOf(GameRoomTag) == 0);
    std_debug.assert(@sizeOf(GameTableTag) == 0);
    std_debug.assert(@sizeOf(GameEntityTag) == 0);
    std_debug.assert(@sizeOf(LocalGameEntityTag) == 0);
    std_debug.assert(@sizeOf(RequestEntityTag) == 0);
    std_debug.assert(@sizeOf(LocalRequestTag) == 0);
    std_debug.assert(@sizeOf(ResponseEntityTag) == 0);

    // 玩家组件
    std_debug.assert(@sizeOf(Player) == 56);
    std_debug.assert(@sizeOf(PlayerProperty) == 40);

    // 认证组件
    std_debug.assert(@sizeOf(AuthenRequest) == 136);
    std_debug.assert(@sizeOf(AuthenResponse) == 88);

    // 位置组件
    std_debug.assert(@sizeOf(Position) == 12);
    std_debug.assert(@sizeOf(Velocity) == 12);
    std_debug.assert(@sizeOf(Rotation) == 12);

    // 游戏状态组件
    std_debug.assert(@sizeOf(ClientState) == 8);
    std_debug.assert(@sizeOf(SkillState) == 32);
    std_debug.assert(@sizeOf(QuestState) == 8);
    std_debug.assert(@sizeOf(Inventory) == 32);
    std_debug.assert(@sizeOf(CombatEffect) == 40);

    // 请求组件
    std_debug.assert(@sizeOf(MoveRequest) == 12);
    std_debug.assert(@sizeOf(QuestRequest) == 8);
    std_debug.assert(@sizeOf(CombatRequest) == 16);
    std_debug.assert(@sizeOf(ReviveRequest) == 1);
    std_debug.assert(@sizeOf(UseItemRequest) == 8);
}

// ============================================================================
// 测试
// ============================================================================

test "builtin component sizes" {
    validateBuiltinComponents();
}
