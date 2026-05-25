//! 基础实体组件

const builtin = @import("component_builtin");

/// 实体发送请求标记 (id=23, version=1)
pub const EntitySendRequest = extern struct {
    pub const COMPONENT_ID: u16 = 23;
    pub const COMPONENT_VERSION: u16 = 1;
    pub const SYNC_TIER: builtin.SyncTier = builtin.SyncTier.None;
};
