const engine = @import("engine");
const log = @import("log");

pub export fn init_game_instance(game_inst: *engine.ScriptContext) c_int {
    if (game_inst.is_initialized) return 0;

    game_inst.is_initialized = true;
    log.info("Client game instance initialized successfully", .{});
    return 0;
}
