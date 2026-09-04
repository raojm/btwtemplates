//! basic 模板项目 builtin 扩展（P1/P8 共享玩法内核收敛后）
//!
//! 公共组件由共享基线 zigscript/src/component/builtin.zig 单一定义，
//! 本文件通过显式别名 re-export + 模板私有扩展组成。
//! build.zig 在 DENSE/tracked 生成时合并基线文本解析（别名行会被剥掉）。
//!
//! 新增公共组件 → 改共享基线 + 此处补一行别名；项目私有组件 → 直接加在本文件。
//! 注意：共享基线组件必须同步修改 rustserver/crates/libs/gamescript/src/builtin.rs

const std = @import("std");
const fixed_math = @import("fixed_math");
const FixedVec3 = fixed_math.FixedVec3;
const shared = @import("zigscript_component_builtin");

// ---- 共享组件 re-export（与共享基线声明一一对应）----

pub const InitStatus = shared.InitStatus;
pub const QuestStatus = shared.QuestStatus;
pub const EffectType = shared.EffectType;
pub const EntityUniqueID = shared.EntityUniqueID;
pub const EntityInitStatus = shared.EntityInitStatus;
pub const ServerEntityTag = shared.ServerEntityTag;
pub const GameRoomTag = shared.GameRoomTag;
pub const GameTableTag = shared.GameTableTag;
pub const GameEntityTag = shared.GameEntityTag;
pub const LocalGameEntityTag = shared.LocalGameEntityTag;
pub const RequestEntityTag = shared.RequestEntityTag;
pub const LocalRequestTag = shared.LocalRequestTag;
pub const ResponseEntityTag = shared.ResponseEntityTag;
pub const Player = shared.Player;
pub const PlayerProperty = shared.PlayerProperty;
pub const PlayerInfo = shared.PlayerInfo;
pub const AuthenRequest = shared.AuthenRequest;
pub const AuthenResponse = shared.AuthenResponse;
pub const Position = shared.Position;
pub const Velocity = shared.Velocity;
pub const Rotation = shared.Rotation;
pub const ClientState = shared.ClientState;
pub const SkillState = shared.SkillState;
pub const QuestState = shared.QuestState;
pub const Inventory = shared.Inventory;
pub const CombatEffect = shared.CombatEffect;
pub const MoveRequest = shared.MoveRequest;
pub const QuestRequest = shared.QuestRequest;
pub const CombatRequest = shared.CombatRequest;
pub const ReviveRequest = shared.ReviveRequest;
pub const UseItemRequest = shared.UseItemRequest;
pub const LoginRequest = shared.LoginRequest;
pub const LoginResponse = shared.LoginResponse;
pub const EnterRoomRequest = shared.EnterRoomRequest;
pub const EnterRoomResponse = shared.EnterRoomResponse;
pub const SitDownRequest = shared.SitDownRequest;
pub const SitDownResponse = shared.SitDownResponse;
pub const StandUpRequest = shared.StandUpRequest;
pub const StandUpResponse = shared.StandUpResponse;
pub const LeaveRoomRequest = shared.LeaveRoomRequest;
pub const LeaveRoomResponse = shared.LeaveRoomResponse;
pub const GameMoveRequest = shared.GameMoveRequest;
pub const GameMoveResponse = shared.GameMoveResponse;
pub const RoomComponent = shared.RoomComponent;
pub const SeatComponent = shared.SeatComponent;
pub const KeepAliveRequest = shared.KeepAliveRequest;
pub const KeepAliveResponse = shared.KeepAliveResponse;
pub const EchoRequest = shared.EchoRequest;
pub const EchoResponse = shared.EchoResponse;

// ---- basic 模板私有扩展 ----

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
