extends Node

# Log levels (match C++ ByteWorldLog::Level)
# 0=TRACE, 1=DEBUG, 2=INFO, 3=WARN, 4=ERROR
const LVL_TRACE := 0
const LVL_DEBUG := 1
const LVL_INFO := 2
const LVL_WARN := 3
const LVL_ERROR := 4

# Current log level (default INFO=2, synced from C++ via ProjectSettings)
static func _get_level() -> int:
	return ProjectSettings.get_setting("bw_log_level", LVL_INFO)

# Variadic signature accepts 1 or 2 arguments:
#   BwLog.info("message")            -> default module "app"
#   BwLog.info("module", "message")  -> standard usage
func trace(module: String = "", message: String = "") -> void:
	_emit(module, message, "TRACE", LVL_TRACE)

func debug(module: String = "", message: String = "") -> void:
	_emit(module, message, "DEBUG", LVL_DEBUG)

func info(module: String = "", message: String = "") -> void:
	_emit(module, message, "INFO", LVL_INFO)

func warn(module: String = "", message: String = "") -> void:
	_emit(module, message, "WARN", LVL_WARN)

func error(module: String = "", message: String = "") -> void:
	_emit(module, message, "ERROR", LVL_ERROR)

static func _emit(module: String, message: String, level: String, level_int: int) -> void:
	# Level filter: only emit if current_level <= this level
	if _get_level() > level_int:
		return

	var mod: String = module
	var msg: String = message
	if msg == "" and mod != "":
		# Single argument: treat as message
		msg = mod
		mod = "app"
	elif mod == "" and msg == "":
		mod = "app"
		msg = ""
	# print_rich is a global GDScript function in Godot 4.x. It is wired
	# to __print_line_rich() internally, which converts BBCode to ANSI
	# for stdout AND dispatches to the editor's "Output" dock.
	print_rich(_format_bbcode(_timestamp(), level, mod, msg))

static func _format_bbcode(timestamp: String, level: String, module: String, message: String) -> String:
	# Use named colors so the auto-conversion to ANSI (in __print_line_rich)
	# produces standard escape codes (e.g. \033[92m for "green") that work
	# on all terminals. Hex colors like #5b9bd5 are converted to truecolor
	# (\033[38;2;91;155;213m) which is fine in modern terminals but not
	# supported in Windows Terminal legacy mode or some CI logs.
	#
	# Layout mirrors the C++ ByteWorldLog format:
	#   HH:MM:SS.mmm LEVEL [module] message
	# with a leading space on level names so TRACE/DEBUG/ INFO/ WARN/ERROR
	# all align to 5 chars (matches C++ " INFO"/" WARN" etc.).
	var level_padded: String
	match level:
		"INFO": level_padded = " INFO"
		"WARN": level_padded = " WARN"
		_: level_padded = level
	var color: String
	match level:
		"INFO": color = "green"
		"DEBUG": color = "blue"
		"WARN": color = "yellow"
		"ERROR": color = "red"
		_: color = "white"
	return "[color=gray]%s[/color] [b][color=%s]%s[/color][/b] [color=cyan][%s][/color] %s" % [
		timestamp, color, level_padded, module, message
	]

static func _timestamp() -> String:
	var ticks = Time.get_ticks_msec()
	var total_sec = int(ticks / 1000.0)
	var millis = ticks % 1000
	var h = int(total_sec / 3600.0)
	var m = int((total_sec % 3600) / 60.0)
	var s = total_sec % 60
	return "%02d:%02d:%02d.%03d" % [h, m, s, millis]
