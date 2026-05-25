extends Node

const _ANSI_GRAY = "\u001b[90m"
const _ANSI_GREEN = "\u001b[32m"
const _ANSI_YELLOW = "\u001b[33m"
const _ANSI_RED = "\u001b[31m"
const _ANSI_RESET = "\u001b[0m"

static func _format(level_ansi: String, level_name: String, module: String, message: String) -> String:
	var ticks = Time.get_ticks_msec()
	var total_sec = ticks / 1000
	var millis = ticks % 1000
	var h = total_sec / 3600
	var m = (total_sec % 3600) / 60
	var s = total_sec % 60
	return _ANSI_GRAY + "%02d:%02d:%02d.%03d" % [h, m, s, millis] + _ANSI_RESET + " " + \
		level_ansi + level_name + _ANSI_RESET + " " + \
		"[%s] %s" % [module, message]

static func info(module: String, message: String) -> void:
	print(_format(_ANSI_GREEN, " INFO", module, message))

static func warn(module: String, message: String) -> void:
	push_warning(_format(_ANSI_YELLOW, " WARN", module, message))

static func error(module: String, message: String) -> void:
	push_error(_format(_ANSI_RED, "ERROR", module, message))
