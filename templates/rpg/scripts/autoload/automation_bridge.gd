extends Node
## 引擎内自动化桥（A6 同族 · 独立 Godot 游戏窗口）：
##   env `BYTEWORLD_AUTOTEST_BRIDGE=1` 时起 WebSocket server（127.0.0.1），对外暴露
##   命令集 + CDP 兼容壳子集。
##
## ★ 端口模式（多实例不冲突）：
##   ① `BYTEWORLD_AUTOTEST_BRIDGE_PORT=<n>` 显式指定（占用则**响亮失败**，不静默改口）；
##   ② `BYTEWORLD_AUTOTEST_BRIDGE_AUTOPORT=1` 强制自动 bind（0 = 操作系统分配空闲端口）；
##   ③ 缺省：先试 9490，被占（多实例）自动回落 auto-bind —— 单实例仍是熟悉的 9490。
##   ⇒ 实际端口两条获取途径：日志 `@BRIDGE ready port=N` + **端口文件**（见下）。
## ★ 端口文件（autobind 后「获取」的落地）：
##   `BYTEWORLD_AUTOTEST_BRIDGE_PORT_FILE=<path>` 显式指定；缺省
##   `{user_data_dir}/automation_bridge_{pid}.port`（按 PID 分文件，多实例不互踩）。
##   内容 = 端口号（纯文本）。退出时清理；客户端应「读文件 → 连 → ping」验证，
##   不把文件存在当链路存在（崩溃可能留陈旧文件）。
##
## ★ 为什么在引擎进程内（而非外部 bun 桥）：这是「游戏窗口无 WebView/无 JS」情境下
##   最贴近 A6 精神的形态——同进程直调引擎（视口截图 / Control 树 / ECS 状态），
##   免前台、不抢焦点、不依赖 OS 命中测试（与 btweditor 的 `autotest_input` 同哲学）。
## ★ 命令集（原生协议，无 id：`{op: ...}`）：
##   · `ping`        链路通（返回 pong + port）
##   · `status`      fps / 节点数 / 视口尺寸
##   · `screenshot`  引擎内截图 → **落盘 PNG，返回路径**（可传 `path` 指定；缺省引擎自选临时路径）
##   · `query`       `{kind:'ui_tree'}` Control 树（name/rect/visible/text）；
##                   `{kind:'ecs'}` 世界态（world_ready/components/names/player_uid/bootstrap）
##   · `input`       引擎内注入 InputEventMouseButton（Input.parse_input_event）
## ★ CDP 兼容壳（`{id, method, params}`）：
##   · `Runtime.evaluate`        → **预置命令集**（expression = status|ui_tree|ecs；无 JS，未知明确报错）
##   · `Page.captureScreenshot`  → screenshot（返回 path；大图不走单条 WS 消息）
##   · `DOM.getContentQuads`     → query ui_tree 折算 quads
##   · `Input.dispatchMouseEvent`→ input（坐标 = 视口逻辑像素）
##   · `Page.reload`             → reload_current_scene
##
## 纪律：日志一律 BwLog（AGENTS.md 红线 1）；env 未设时零影响（不起 server）。

const TAG := "AutomationBridge"
const PORT_DEFAULT := 9490

var _tcp: TCPServer = null
var _peers: Array = []
var _port: int = PORT_DEFAULT
var _active := false
var _debug := false
var _port_file := ""


func _ready() -> void:
	if OS.get_environment("BYTEWORLD_AUTOTEST_BRIDGE") != "1":
		set_process(false)
		return
	# ★ 死亡/暂停画面（get_tree().paused=true）下 _process 默认停转 ⇒ 桥完全失联、
	#   自动化全部超时。桥是自动化基础设施，必须常转。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_debug = OS.get_environment("BYTEWORLD_AUTOTEST_BRIDGE_DEBUG") == "1"
	var explicit := OS.get_environment("BYTEWORLD_AUTOTEST_BRIDGE_PORT")
	var force_auto := OS.get_environment("BYTEWORLD_AUTOTEST_BRIDGE_AUTOPORT") == "1"
	var want := PORT_DEFAULT
	if not explicit.is_empty():
		want = int(explicit)
	elif force_auto:
		want = 0
	_tcp = TCPServer.new()
	if _tcp.listen(want) != OK:
		if not explicit.is_empty():
			# 调用方明确要这个口：响亮失败，不静默改端口（掩盖冲突比失败更糟）
			BwLog.warn(TAG, "@BRIDGE listen failed port=%d（显式指定，不重试；端口被占？）" % want)
			set_process(false)
			return
		# 缺省口被占（多实例第二个窗口）⇒ 自动 bind：操作系统分配空闲端口
		BwLog.info(TAG, "@BRIDGE port %d occupied, fallback to auto-bind" % want)
		_tcp = TCPServer.new()
		if _tcp.listen(0) != OK:
			BwLog.warn(TAG, "@BRIDGE auto-bind failed")
			set_process(false)
			return
	_active = true
	_port = _tcp.get_local_port()
	_write_port_file()
	BwLog.info(TAG, "@BRIDGE ready port=%d file=%s" % [_port, _port_file])


func _exit_tree() -> void:
	# 端口文件随进程退出清理（崩溃会残留 ⇒ 客户端必须「读文件→连→ping」验证）
	if _active and not _port_file.is_empty():
		DirAccess.remove_absolute(_port_file)


func _write_port_file() -> void:
	_port_file = _port_file_path()
	var f := FileAccess.open(_port_file, FileAccess.WRITE)
	if f != null:
		f.store_string(str(_port))
		f.close()
	else:
		BwLog.warn(TAG, "@BRIDGE port file write failed: %s (err=%d)" % [_port_file, FileAccess.get_open_error()])


func _port_file_path() -> String:
	var p := OS.get_environment("BYTEWORLD_AUTOTEST_BRIDGE_PORT_FILE")
	if not p.is_empty():
		return p
	# 缺省按 PID 分文件：多实例各写各的，调用方持引擎 PID 即可定位
	return OS.get_user_data_dir().path_join("automation_bridge_%d.port" % OS.get_process_id())


func _process(_delta: float) -> void:
	if not _active:
		return
	while _tcp.is_connection_available():
		var conn := _tcp.take_connection()
		if conn == null:
			continue
		var ws := WebSocketPeer.new()
		# ★ 不调大 in/outbound_buffer_size（默认 64KB）：大图/大 JSON **不**走单条 WS
		#   消息，改为落盘返回路径（见 _screenshot）⇒ 响应恒为小消息，不依赖缓冲调大。
		if ws.accept_stream(conn) == OK:
			_peers.append(ws)
			BwLog.info(TAG, "@BRIDGE peer accepted")
	for i in range(_peers.size() - 1, -1, -1):
		var ws: WebSocketPeer = _peers[i]
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			if _debug and ws.get_available_packet_count() > 0:
				BwLog.info(TAG, "@BRIDGE recv packets=%d" % ws.get_available_packet_count())
			while ws.get_available_packet_count() > 0:
				_on_packet(ws, ws.get_packet().get_string_from_utf8())
		elif st == WebSocketPeer.STATE_CLOSED:
			BwLog.info(TAG, "@BRIDGE peer closed")
			_peers.remove_at(i)


func _on_packet(ws: WebSocketPeer, text: String) -> void:
	if _debug:
		BwLog.info(TAG, "@BRIDGE recv: %s" % text.substr(0, 120))
	var req: Variant = JSON.parse_string(text)
	var resp: Dictionary
	if typeof(req) != TYPE_DICTIONARY:
		resp = {"ok": false, "error": "bad json"}
	else:
		resp = _dispatch(req)
		# 请求带 id 就回显（CDP 帧本来就有；原生 op 原设计无 id，但带 id 的
		# 客户端按响应关联——不回显则永远等不到，串行单帧客户端不受影响）。
		if resp.has("id") == false and req.has("id"):
			resp["id"] = req["id"]
	var out := JSON.stringify(resp)
	var err := ws.send_text(out)
	ws.poll()
	if err != OK:
		BwLog.warn(TAG, "@BRIDGE send failed len=%d err=%d state=%d" % [out.length(), err, ws.get_ready_state()])


func _dispatch(req: Dictionary) -> Dictionary:
	if req.has("method"):
		return _cdp(req)
	match str(req.get("op", "")):
		"ping": return {"ok": true, "op": "pong", "port": _port}
		"status": return _status()
		"screenshot": return _screenshot(req)
		"query": return _query(req)
		"input": return _cmd_input(req)
		_: return {"ok": false, "error": "unknown op: %s" % str(req.get("op"))}


func _status() -> Dictionary:
	var vp := get_viewport()
	var sz := Vector2i.ZERO
	if vp != null:
		sz = vp.get_visible_rect().size
	return {
		"ok": true, "port": _port,
		"fps": Engine.get_frames_per_second(),
		"nodes": get_tree().get_node_count() if get_tree() != null else 0,
		"viewport": [sz.x, sz.y],
	}


func _screenshot(req: Dictionary = {}) -> Dictionary:
	var vp := get_viewport()
	if vp == null:
		return {"ok": false, "error": "no viewport"}
	var tex := vp.get_texture()
	if tex == null:
		return {"ok": false, "error": "no viewport texture (headless?)"}
	var img := tex.get_image()
	if img == null or img.is_empty():
		return {"ok": false, "error": "empty framebuffer (headless?)"}
	# ★ 落盘返回**路径**（而非 base64 内联）：百 KB 级 base64 会超 WebSocketPeer 默认
	#   64KB out buffer（调大缓冲又费内存）。写文件让调用方按路径读，稳且省。
	#   路径来源：调用方显式 `path`（绝对路径）＞ 缺省引擎自选——AUTO_TEST_SHOT_DIR
	#   （GuiDriver 注入）或 user_data_dir + 时间戳文件名。
	var path := str(req.get("path", ""))
	if path.is_empty():
		var dir := OS.get_environment("AUTO_TEST_SHOT_DIR")
		if dir.is_empty():
			dir = OS.get_user_data_dir()
		path = "%s/bridge_shot_%d.png" % [dir.trim_suffix("/"), Time.get_ticks_usec()]
	var serr := img.save_png(path)
	if serr != OK:
		return {"ok": false, "error": "save_png failed err=%d path=%s" % [serr, path]}
	return {"ok": true, "path": path, "width": img.get_width(), "height": img.get_height()}


func _query(req: Dictionary) -> Dictionary:
	match str(req.get("kind", "")):
		"ui_tree": return _query_ui_tree()
		"ecs": return _query_ecs()
		_: return {"ok": false, "error": "unknown query kind: %s" % str(req.get("kind"))}


## ECS 世界态（模板通用版）：世界是否就绪 / 组件数 / 已注册实体名 / 本机玩家 uid /
## 引导进度。为什么需要它：模板项目没有游戏侧探针，`ui_tree` 读不到「实体在不在」——
## 这是「新项目能否播起来」唯一的机器可读判据。
func _query_ecs() -> Dictionary:
	var h = EcsHelper.get_instance()
	if h == null:
		return {"ok": false, "error": "EcsHelper 未就绪（扩展未加载？）"}
	var names: Array = []
	if h.has_method("get_registered_entity_names"):
		names = Array(h.get_registered_entity_names())
	var comps: Array = []
	if h.has_method("get_components_list"):
		comps = h.get_components_list()
	var player_uid := 0
	if h.has_method("get_entity_uid"):
		player_uid = int(h.get_entity_uid("player"))
	var boot := get_node_or_null("/root/EcsNativeBootstrap")
	var boot_state := "absent"
	if boot != null:
		boot_state = "ready" if int(boot.player_uid()) > 0 else "pending"
	var world_ready := false
	if h.has_method("is_world_ready"):
		world_ready = bool(h.is_world_ready())
	return {
		"ok": true,
		"world_ready": world_ready,
		"components": comps.size(),
		"names": names,
		"player_uid": player_uid,
		"player_known": player_uid > 0,
		"bootstrap": boot_state,
	}


func _query_ui_tree() -> Dictionary:
	var nodes: Array = []
	var tree := get_tree()
	if tree != null:
		_collect_controls(tree.root, nodes)
	return {"ok": true, "nodes": nodes}


func _collect_controls(node: Node, out: Array) -> void:
	if node is Control:
		var c := node as Control
		var txt = c.get("text")
		var m := c.modulate
		var sm := c.self_modulate
		var fc: Color = c.get_theme_color("font_color", "Label") if c is Label else Color(0, 0, 0, 0)
		out.append({
			"name": String(c.name),
			"x": c.global_position.x, "y": c.global_position.y,
			"w": c.size.x, "h": c.size.y,
			"visible": c.is_visible_in_tree(),
			"text": "" if txt == null else String(txt),
			# 诊断面：modulate/self_modulate/主题字色/z —— 「可见但不绘制」类问题的判据
			"mod": [m.r, m.g, m.b, m.a],
			"smod": [sm.r, sm.g, sm.b, sm.a],
			"fc": [fc.r, fc.g, fc.b, fc.a],
			"z": c.z_index,
		})
	for ch in node.get_children():
		_collect_controls(ch, out)


func _cmd_input(req: Dictionary) -> Dictionary:
	var vp := get_viewport()
	if vp == null:
		return {"ok": false, "error": "no viewport"}
	# 引擎内注入（Input.parse_input_event）；坐标 = 视口逻辑像素。
	var down := bool(req.get("pressed", true))
	var btn := int(req.get("button", 1))
	# ★ 响亮校验：MOUSE_BUTTON_NONE(0) 等非法值曾静默 ok:true——注入实际无效
	#   （匹配不到任何 InputMap 动作），客户端误以为点过了（2026-10-29 实测）。
	#   Godot 惯例左键=1；CDP 兼容层已负责 "left"→1 换算。
	if btn < 1 or btn > 9:
		return {"ok": false, "error": "invalid button %d（Godot 惯例：1=左 2=右；CDP 兼容层传 \"left\"/\"right\" 自动换算）" % btn}
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed = down
	ev.position = Vector2(float(req.get("x", 0)), float(req.get("y", 0)))
	Input.parse_input_event(ev)
	return {"ok": true}


# ---- CDP 兼容壳（子集：映射到引擎内真实能力，不假装有 JS/DOM）----
func _cdp(req: Dictionary) -> Dictionary:
	var id = req.get("id")
	var method := str(req.get("method", ""))
	var params: Dictionary = req.get("params", {}) if typeof(req.get("params")) == TYPE_DICTIONARY else {}
	match method:
		"Runtime.evaluate":
			# ★ 预置命令集：游戏窗口无 JS ⇒ expression 只能是命令名，未知明确报错。
			var name := str(params.get("expression", ""))
			match name:
				"status": return {"id": id, "result": {"result": {"type": "object", "value": _status()}}}
				"ui_tree": return {"id": id, "result": {"result": {"type": "object", "value": _query({"kind": "ui_tree"})}}}
				"ecs": return {"id": id, "result": {"result": {"type": "object", "value": _query_ecs()}}}
				_: return {"id": id, "error": {"code": -32601, "message": "游戏窗口无 JS：Runtime.evaluate 仅支持预置命令（status|ui_tree|ecs），收到 %s" % name}}
		"Page.captureScreenshot":
			var r := _screenshot(params)
			if not r.get("ok", false):
				return {"id": id, "error": {"message": str(r.get("error", ""))}}
			# ★ 返回**路径**而非 base64 data：大图不走单条 WS 消息（见 _screenshot 注释）；
			#   与 CDP 原契约（data=base64）有意偏离——游戏窗口无 WebView，落盘读路径更稳。
			return {"id": id, "result": {"path": r["path"], "width": r["width"], "height": r["height"]}}
		"DOM.getContentQuads":
			var q := _query({"kind": "ui_tree"})
			var sel := str(params.get("selector", "")).trim_prefix(".")
			var quads: Array = []
			for n in q.get("nodes", []):
				if sel.is_empty() or String(n.get("name", "")).contains(sel):
					quads.append([n["x"], n["y"], n["w"], 0.0, n["x"], n["y"] + n["h"], n["w"], n["h"]])
			return {"id": id, "result": {"quads": quads}}
		"Input.dispatchMouseEvent":
			var t := str(params.get("type", "mousePressed"))
			var pressed := t != "mouseReleased"
			var btn := 1 if str(params.get("button", "left")) == "left" else 3
			return {"id": id, "result": _cmd_input({
				"x": float(params.get("x", 0)), "y": float(params.get("y", 0)),
				"button": btn, "pressed": pressed,
			})}
		"Page.reload":
			var tree := get_tree()
			if tree != null and tree.current_scene != null:
				tree.reload_current_scene()
			return {"id": id, "result": {}}
		_: return {"id": id, "error": {"code": -32601, "message": "unsupported method: %s" % method}}