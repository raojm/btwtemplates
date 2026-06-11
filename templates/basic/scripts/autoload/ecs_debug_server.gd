extends Node

var _tcp_server: TCPServer = null
var _port: int = 9880
var _helper = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	_helper = Engine.get_singleton("EcsHelper")
	_tcp_server = TCPServer.new()
	var err = _tcp_server.listen(_port)
	if err != OK:
		BwLog.warn("EcsDebug", "Failed to listen on port %d" % _port)
		return
	BwLog.info("EcsDebug", "Debug HTTP server ready on port %d" % _port)
	set_process(true)

func _process(_delta: float) -> void:
	if _tcp_server == null:
		return
	while _tcp_server.is_connection_available():
		var client = _tcp_server.take_connection()
		if client != null:
			_handle_client(client)

func _handle_client(client: StreamPeerTCP) -> void:
	client.poll()
	if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var available = client.get_available_bytes()
	if available <= 0:
		return
	var data = client.get_data(available)
	if data[0] != 0:
		return
	var request_str = data[1].get_string_from_utf8()
	var header_end = request_str.find("\r\n\r\n")
	if header_end < 0:
		return
	var header_str = request_str.substr(0, header_end)
	var lines = header_str.split("\r\n")
	if lines.size() == 0:
		return
	var request_line = lines[0].split(" ")
	if request_line.size() < 2:
		return
	var path = request_line[1]

	var result: Dictionary = {"ok": true, "action": "status", "port": _port}
	if path == "/api/debug/status":
		result = _cmd_status()
	else:
		result = {"ok": false, "error": "Unknown endpoint: " + path}

	var body_str = JSON.stringify(result)
	var response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n%s" % [body_str.length(), body_str]
	client.put_data(response.to_utf8_buffer())

func _cmd_status() -> Dictionary:
	return {"ok": true, "action": "status", "port": _port, "helper_available": _helper != null}
