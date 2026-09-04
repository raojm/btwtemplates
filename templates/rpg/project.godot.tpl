config_version=5

[application]
config/name="{{PROJECT_NAME}}"
run/main_scene="res://scenes/main_scene.tscn"
config/features=PackedStringArray("{{GODOT_VERSION}}", "{{RENDERING_METHOD}}")
config/icon="res://icon.svg"
config/gameid={{GAME_ID}}

[autoload]
BwLog="*res://scripts/autoload/bw_log.gd"
EcsDebugServer="*res://scripts/autoload/ecs_debug_server.gd"

[display]
window/size/viewport_width={{VIEWPORT_WIDTH}}
window/size/viewport_height={{VIEWPORT_HEIGHT}}
window/stretch/mode="canvas_items"

[rendering]
viewport/transparent_background=true
