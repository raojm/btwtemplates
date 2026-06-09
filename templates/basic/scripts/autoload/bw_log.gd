extends Node

# Single sink, both targets handled by the same call:
#  • Godot "Output" dock renders BBCode as RichText
#  • Godot's __print_line_rich internally converts the BBCode tags we use
#    (`[color=name]`, `[b]`, `[/b]`) to ANSI escape codes for stdout, so
#    real terminals also see colors.

# Variadic signature accepts 1 or 2 arguments:
#   BwLog.info("message")            -> default module "app"
#   BwLog.info("module", "message")  -> standard usage
static func info(module: String = "", message: String = "") -> void:
	_emit(module, message, "INFO")

static func warn(module: String = "", message: String = "") -> void:
	_emit(module, message, "WARN")

static func error(module: String = "", message: String = "") -> void:
	_emit(module, message, "ERROR")

static func debug(module: String = "", message: String = "") -> void:
	_emit(module, message, "DEBUG")

static func _emit(module: String, message: String, level: String) -> void:
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
	var total_sec = ticks / 1000
	var millis = ticks % 1000
	var h = total_sec / 3600
	var m = (total_sec % 3600) / 60
	var s = total_sec % 60
	return "%02d:%02d:%02d.%03d" % [h, m, s, millis]
