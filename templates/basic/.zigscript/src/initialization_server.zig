const engine = @import("engine");
const component = @import("component");
const builtin = component.builtin;
const log = @import("log");

const ROOM_UNIQUE_ID: u64 = 100;
const PLAYER_UNIQUE_ID: u64 = 10000;

pub export fn init_game_instance(game_inst: *engine.ScriptContext) c_int {
    if (game_inst.is_initialized) return 0;

    log.info("init_game_instance: START", .{});

    const room_uid = engine.makeGameRoomUid(ROOM_UNIQUE_ID);
    _ = game_inst.addComponentWithUniqueId(room_uid, builtin.GameRoomTag, &builtin.GameRoomTag{}) catch {};

    const player_uid = engine.makePlayerUinUid(PLAYER_UNIQUE_ID);
    _ = game_inst.addComponentWithUniqueId(player_uid, builtin.EntityUniqueID, &builtin.EntityUniqueID{ .unique_id = player_uid, .owner_unique_id = 0 }) catch {};

    game_inst.is_initialized = true;
    log.info("Server game instance initialized successfully", .{});
    return 0;
}
