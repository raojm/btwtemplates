extends Node
## ═══════════════════════════════════════════════════════════════════════════
## EcsNativeBootstrap（模板通用骨架）—— 让新项目「播起来」的最后一公里
## ═══════════════════════════════════════════════════════════════════════════
##
## 【问题】native(GDExtension) 形态下没有 TS 宿主，而「本地玩家实体」这一步在旧链路里
##   是宿主做的（`bw_wasm_ecs_spawn_local_player` → pending_spawn_uin → kernel 建实体）。
##   引擎不带这一步 ⇒ 新项目场景能加载、client dylib 能 dlopen，但**玩家实体不存在**
##   ⇒ 任何按玩家实体驱动的逻辑（移动/AI 追击/血条/相机跟随）全部无源，画面停在静态场景。
##
## 【本脚本做什么（四步，全部幂等）】
##   ① 等世界就绪（必要时补调 `EcsHelper.initialize_ecs_world()`）；
##   ② 建**通用 stub 玩家**：EntityUniqueID(10) + GameEntityTag(16) + LocalRequestTag(19)
##      + Position(300) + PlayerProperty(101) + Velocity(301) + Rotation(302)；
##      uid = (UIN<<48)|uin，与 zig `entity_source.makePlayerUinUid` 同一编码；
##   ③ 注册实体名 "player"（`get_entity_uid("player")` 从此可用，绑定/探针有源）；
##   ④ 起一个可见占位（盒子）+ 兜底相机/灯光，并按 Position 每帧跟随。
##
## 【刻意不做（游戏侧扩展点）】输入位掩码 / 相机跟随策略 / 模型动画 / 数组绑定脚手架
##   —— 那些依赖具体组件（如 `framesync.PlayerInput`、`weapon.WeaponState`）。
##   扩展方式：`_extra_player_components()` 追加组件、`_input_keys_mask()` 提供输入、
##   或直接监听 `bootstrap_ready` 信号接自己的表现层。
##
## 【开关】BYTEWORLD_BOOTSTRAP=0 关闭；BYTEWORLD_BOOTSTRAP_IN_EDITOR=1 允许在编辑器
##   主进程里跑（默认跳过）；BYTEWORLD_BOOTSTRAP_VISUAL=0 不建占位/相机；
##   BYTEWORLD_AUTH_UIN / BW_LOCAL_UIN 覆盖本机 uin（默认 1）。
##
## 【排障前缀】日志统一 `[EcsBootstrap]`。看三个判据即可定性：
##   `world ready` → `spawn` → `entity name`；缺哪条，故障就在哪一段。

const TAG := "EcsBootstrap"

## uid 类型位（对齐 zigscript/src/api/types.zig EntityUniqueType.UIN）
const UID_TYPE_UIN := 1
const UID_TYPE_SHIFT := 48

## Q32.32（Fixed = extern struct { raw: i64 }）
const FIXED_ONE := 4294967296.0

## 单机步长（ms）：zig 侧缺省 MOVEMENT_DELTA = 0.016s。仅当 `framesync.StepClock`
## 存在时使用（基础模板无该组件，跳过）。
const STEP_DELTA_MS := 16

## stub 玩家的基础组件（顺序即写入顺序；缺失的组件会被跳过并汇总告警）
const BASE_COMPONENTS: Array = [
	"builtin.EntityUniqueID",
	"builtin.GameEntityTag",
	"builtin.LocalRequestTag",
	"builtin.Position",
	"builtin.PlayerProperty",
	"builtin.Velocity",
	"builtin.Rotation",
]

signal bootstrap_ready(player_uid: int)
signal bootstrap_failed(reason: String)

var _helper = null
var _player_uid: int = 0
var _player_node: Node3D = null
var _cid := {}
var _boot_done := false

func _ready() -> void:
	if Engine.is_editor_hint() and OS.get_environment("BYTEWORLD_BOOTSTRAP_IN_EDITOR") != "1":
		set_process(false)
		return
	if OS.get_environment("BYTEWORLD_BOOTSTRAP") == "0":
		BwLog.info(TAG, "BYTEWORLD_BOOTSTRAP=0 —— 跳过客户端引导")
		set_process(false)
		return
	_boot()

## 本机 uin（单机无认证 ⇒ 固定值；可用 env 覆盖便于多实例并排跑）
func local_uin() -> int:
	for key in ["BYTEWORLD_AUTH_UIN", "BW_LOCAL_UIN"]:
		var raw := OS.get_environment(key)
		if raw.is_valid_int() and int(raw) > 0:
			return int(raw)
	return 1

func player_uid() -> int:
	return _player_uid

func _boot() -> void:
	# ① 等扩展单例（SCENE 级创建；autoload 的 _ready 早于它）
	for _i in range(180):
		if not is_inside_tree():
			return
		_helper = EcsHelper.get_instance()
		if _helper != null:
			break
		await get_tree().process_frame
	if _helper == null:
		_fail("EcsHelper.get_instance() 恒为 null —— 扩展未加载（dist/*.gdextension 缺失？）")
		return

	# ② 等世界就绪；不依赖 world_ecs 组节点（tscn-free 由引擎补建，静态 .tscn 场景
	#    本来就可能有/没有）。世界真没起来时补调一次初始化，再等一轮。
	if not await _wait_world(300):
		if _helper.has_method("initialize_ecs_world"):
			BwLog.info(TAG, "世界未就绪 —— 补调 initialize_ecs_world()")
			_helper.initialize_ecs_world()
		if not await _wait_world(300):
			_fail("ECS 世界迟迟未就绪（initialize_ecs_world 后仍失败）")
			return
	BwLog.info(TAG, "world ready（components=%d）" % _helper.get_components_list().size())

	_collect_component_ids()
	_ensure_step_clock()
	_spawn_local_player()
	_ensure_local_player_uid()
	if OS.get_environment("BYTEWORLD_BOOTSTRAP_VISUAL") != "0":
		_ensure_visual()

	_boot_done = true
	BwLog.info(TAG, "引导完成 player_uid=0x%X uin=%d" % [_player_uid, local_uin()])
	bootstrap_ready.emit(_player_uid)

func _fail(reason: String) -> void:
	BwLog.error(TAG, "引导失败：%s" % reason)
	bootstrap_failed.emit(reason)

func _wait_world(max_frames: int) -> bool:
	for _i in range(max_frames):
		if not is_inside_tree():
			return false
		if _helper.has_method("is_world_ready") and _helper.is_world_ready():
			return true
		await get_tree().process_frame
	return _helper.has_method("is_world_ready") and _helper.is_world_ready()

# ── 组件 id 解析 ───────────────────────────────────────────────────────────
func _collect_component_ids() -> void:
	var missing: Array = []
	for name in BASE_COMPONENTS + _extra_player_components().keys():
		var cid := int(_helper.find_component_id(name))
		if cid < 0:
			missing.append(name)
			continue
		_cid[name] = cid
	if not missing.is_empty():
		# 不是错误：基础模板的 dylib 可能只注册了默认组件集。执行依赖它的动作时才需要它。
		BwLog.warn(TAG, "组件未注册（跳过写入）: %s" % str(missing))
	BwLog.info(TAG, "组件 id: %s" % JSON.stringify(_cid))

# ── 单机步长（仅当 framesync.StepClock 存在）───────────────────────────────
## zig `update_movement` 的位移步长取自 `StepClock.step_delta_ms`，而 `frame_sync_dispatch`
## 每 tick 用 zeroes 回写该单例 ⇒ 单机下若无人写就是 0 ⇒ 位移恒 0（「按键有值但不动」）。
func _ensure_step_clock() -> void:
	var cid := int(_cid.get("framesync.StepClock", -1))
	if cid < 0:
		return
	var clock_uid: int = _helper.get_entity_uid("step_clock")
	if clock_uid == 0:
		return
	var raw: PackedByteArray = _helper.get_component_data(clock_uid, cid)
	if raw.size() < 20:
		return
	if raw.decode_u32(16) == 0:
		_helper.add_component(clock_uid, cid, {"step_delta_ms": STEP_DELTA_MS})
		BwLog.info(TAG, "StepClock.step_delta_ms 0 → %d（否则 Position 永不推进）" % STEP_DELTA_MS)

# ── ② 建通用 stub 玩家 ─────────────────────────────────────────────────────
func _spawn_local_player() -> void:
	var uin := local_uin()
	_player_uid = (UID_TYPE_UIN << UID_TYPE_SHIFT) | uin

	# 幂等：kernel/host 可能已经建过（lockstep 步包路径）
	if _has("builtin.LocalRequestTag") and _has("builtin.PlayerProperty"):
		BwLog.info(TAG, "玩家实体已存在（宿主已建）uid=0x%X —— 仅补名字绑定" % _player_uid)
	else:
		var hp := _init_player_hp()
		var data := {
			"builtin.EntityUniqueID": {"unique_id": _player_uid, "owner_unique_id": 0},
			"builtin.GameEntityTag": {},
			"builtin.LocalRequestTag": {},
			"builtin.Position": {"value": Vector3.ZERO},
			"builtin.PlayerProperty": {
				"hp": hp, "max_hp": hp, "mp": 50, "max_mp": 50,
				"attack": 10, "defense": 5, "is_dead": 0, "level": 1, "exp": 0,
			},
			"builtin.Velocity": {"vx": 0.0, "vy": 0.0, "vz": 0.0},
			"builtin.Rotation": {"pitch": 0.0, "yaw": 0.0, "roll": 0.0},
		}
		data.merge(_extra_player_components(), true)
		var written: Array = []
		for name in data.keys():
			if _add(name, data[name]):
				written.append(name)
		BwLog.info(TAG, "spawn player uid=0x%X uin=%d hp=%d comps=%s"
			% [_player_uid, uin, hp, str(written)])

	# ③ 名字绑定（绑定规则/探针按名字取 uid 的唯一来源）
	_helper.register_entity_uid("player", _player_uid)
	BwLog.info(TAG, "entity name: player → 0x%X（回读 %d）"
		% [_player_uid, _helper.get_entity_uid("player")])

# 初始 HP：与游戏侧同一份宿主契约（`BW_GAME_INIT_PARAMS` 的 player_hp，只认 >0 整数）。
# 两边各写死一个默认值 ⇒ 本引导先建实体时会把注入值覆盖掉（FPSDemo 踩过）。
func _init_player_hp() -> int:
	var raw := OS.get_environment("BW_GAME_INIT_PARAMS")
	if raw.is_empty():
		return 100
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return 100
	var v: Variant = (parsed as Dictionary).get("player_hp")
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return 100
	var n := int(v)
	return n if n > 0 else 100

# ── StepClock.local_player_uid（联机由宿主写，本机单机补写）─────────────────
func _ensure_local_player_uid() -> void:
	if _player_uid == 0:
		return
	if _helper.has_method("set_local_player_uin"):
		# 引擎正解：与 WASM 单机 bw_wasm_ecs_spawn_local_player 同源同语义
		if _helper.set_local_player_uin(local_uin()):
			BwLog.info(TAG, "引擎通道声明本地玩家 uin=%d（下一 tick 写 lpu）" % local_uin())
			return
	var cid := int(_cid.get("framesync.StepClock", -1))
	if cid < 0:
		return
	var clock_uid: int = _helper.get_entity_uid("step_clock")
	if clock_uid == 0:
		return
	var raw: PackedByteArray = _helper.get_component_data(clock_uid, cid)
	if raw.size() >= 8 and raw.decode_u64(0) != 0:
		return  # 联机/宿主已写，不覆盖身份
	_helper.add_component(clock_uid, cid, {"local_player_uid": _player_uid})
	BwLog.info(TAG, "兜底补写 StepClock.local_player_uid=0x%X" % _player_uid)

# ── ④ 可见占位 + 兜底相机/灯光 + 每帧跟随 Position ─────────────────────────
func _ensure_visual() -> void:
	var root := get_tree().current_scene
	if root == null or not (root is Node3D):
		BwLog.info(TAG, "场景根非 Node3D —— 跳过可见占位（实体照常创建）")
		return
	var vis := root.get_node_or_null("PlayerVisual") as Node3D
	if vis == null:
		vis = Node3D.new()
		vis.name = "PlayerVisual"
		root.add_child(vis)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 1.6, 0.6)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.65, 1.0)
		mesh.material_override = mat
		mesh.position = Vector3(0.0, 0.8, 0.0)
		vis.add_child(mesh)
		BwLog.info(TAG, "已建可见占位 PlayerVisual")
	_player_node = vis
	_ensure_camera_and_light(root)
	set_process(true)

# 静态 .tscn 可能既无相机也无灯光（模板 main_scene 只有空 Node3D）⇒ 全黑。
# tscn-free(bwscene) 档由引擎 build_runtime_scene 负责，这里只在缺失时兜底。
func _ensure_camera_and_light(root: Node3D) -> void:
	if _find_first(root, "Camera3D") == null:
		var cam := Camera3D.new()
		cam.name = "BootstrapCamera"
		cam.position = Vector3(0.0, 3.0, 8.0)
		root.add_child(cam)
		cam.look_at(Vector3.ZERO, Vector3.UP)
		BwLog.info(TAG, "已建兜底相机 BootstrapCamera @(0,3,8)")
	if _find_first(root, "Light3D") == null:
		var light := DirectionalLight3D.new()
		light.name = "BootstrapLight"
		light.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
		root.add_child(light)
		BwLog.info(TAG, "已建兜底平行光 BootstrapLight")

func _find_first(node: Node, cls: String) -> Node:
	if node.is_class(cls):
		return node
	for ch in node.get_children():
		var hit := _find_first(ch, cls)
		if hit != null:
			return hit
	return null

func _process(_delta: float) -> void:
	if not _boot_done or _player_node == null or _player_uid == 0:
		return
	var cid := int(_cid.get("builtin.Position", -1))
	if cid < 0:
		return
	var raw: PackedByteArray = _helper.get_component_data(_player_uid, cid)
	if raw.size() < 24:
		return
	# Position = extern struct { value: FixedVec3 }（3 × i64 raw，偏移 0/8/16）
	_player_node.position = Vector3(
		raw.decode_s64(0) / FIXED_ONE,
		raw.decode_s64(8) / FIXED_ONE,
		raw.decode_s64(16) / FIXED_ONE)

# ── 游戏侧扩展点（子类/同名覆写均可；此处给出空实现与契约）─────────────────
## 追加到 stub 玩家上的组件：{ "组件名": {字段: 值}, ... }。未注册的组件会自动跳过。
func _extra_player_components() -> Dictionary:
	return {}

## 本帧要写进 `framesync.PlayerInput.keys_pressed` 的位掩码（无该组件时不生效）。
## 默认 0 = 不驱动输入；需要键盘驱动的游戏在子类里覆写。
func _input_keys_mask() -> int:
	return 0

func _add(comp_name: String, data: Dictionary) -> bool:
	var cid := int(_cid.get(comp_name, -1))
	if cid < 0:
		return false
	_helper.add_component(_player_uid, cid, data)
	return true

func _has(comp_name: String) -> bool:
	var cid := int(_cid.get(comp_name, -1))
	if cid < 0:
		return false
	return EcsHelper.has_component(_player_uid, cid)
