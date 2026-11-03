//! 样板系统 (Sample System)
//!
//! 展示如何实现一个 Entity Request 系统：
//! 1. 接收客户端的 EchoRequest 组件
//! 2. 读取请求数据（tracked shadow 组件用 getter：request.seq()）
//! 3. 创建 EchoResponse 组件并添加到请求实体
//!
//! 删除此文件即可移除样板代码。
//!
//! ── ★★ 写「玩法系统」前的两条框架契约（journey R5 实证，缺一即静默行为异常）──
//! ① `SystemAnnotation` **必须显式 `.interval_ticks = 1`**：缺省 0 ⇒ always_run=false
//!    ⇒ 系统只在参数组件 changed 时执行——输入系统「变化才写」PlayerInput 之类的
//!    语义下，按住键也只推进 1 步就停。FPSDemo 全部玩法系统显式 =1。
//! ② 玩法推进必须过 `entity_source.step_gate.shouldStep`（签名加
//!    `clock: *shared_mod.Shared(input.StepClock)` 参数，packWindow 装、shouldStep 判）：
//!    否则每宿主 tick 推进（渲染帧率），速率 = 墙钟 2.5×，且联机/回放形态确定性分叉。
//!    参考实现 = games/JourneyR5Game/.zigscript/src/system/move_player.zig（单机运动学）。

const std = @import("std");
const game_types = @import("game_types");
const game_instance = @import("game_instance");
const component = @import("component");
const builtin = component.builtin;

pub const process_echo_request_meta = game_types.SystemAnnotation{ .display_name = "处理 Echo 请求", .phase = .OnUpdate };

pub export fn process_echo_request(ctx: *game_instance.ScriptContext, request: *const builtin.EchoRequest, request_tag: *const builtin.RequestEntityTag) callconv(.c) u8 {
    _ = request_tag;
    const current_entity = ctx.current_entity_id;

    var request_unique_id: u64 = 0;
    if (ctx.getComponent(current_entity, builtin.EntityUniqueID)) |*uid| {
        request_unique_id = uid.unique_id();
    }

    var resp = builtin.EchoResponse{
        ._seq = request.seq(),
        ._data = request.data(),
        ._server_time = @as(u64, @bitCast(game_types.milliTimestamp())),
    };

    _ = ctx.addComponentWithUniqueIdEx(request_unique_id, builtin.EchoResponse, &resp, @intFromEnum(game_instance.SyncFlag.ResponseComponent)) catch {
        return 1;
    };

    return 0;
}
