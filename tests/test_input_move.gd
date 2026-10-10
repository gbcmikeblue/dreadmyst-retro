extends SceneTree
## 输入链路诊断：把「按键 -> 动作映射」与「动作 -> 玩家移动」拆开分别验证，
## 这样能直接定位 WASD 失效到底是哪一环。
##
##   godot --headless --path . --script res://tests/test_input_move.gd
##
## 输出解读：
##   [映射] InputMap 里实际注册了什么
##   [A]    Input.action_press() 直接按动作名 —— 验证移动代码本身
##   [B]    InputMap.event_is_action() —— 验证「OS 送来的按键事件」能否匹配上动作

const WARMUP := 3
const HOLD := 40

## 声明成 Variant：M13 之后要动态调 `_main.choose_slot()`（静态类型 Node 上没有这个方法）
var _main: Variant = null
var _player = null
var _frame: int = 0
var _failed: bool = false
var _start := Vector3.ZERO


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("FAIL: 无法加载 res://scenes/main.tscn")
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1

	if _frame == 1:
		# M13：启动会先弹标题选档界面（此时世界是暂停的）。自测直接替玩家选一个槽位开新档，
		# 并把存档路径指到测试专用文件，免得覆盖真实存档。
		_main.save_service.path_pattern = "user://test_input_save_%d.json"
		_main.choose_slot(1, true)
		return

	if _frame == WARMUP:
		_dump_input_map()
		_player = _first("player")
		if _player == null:
			print("FAIL: 场景里没有玩家节点")
			quit(1)
			return
		_start = _player.global_position
		Input.action_press("move_right")
		print("[A] 已按下动作 move_right，起点 = %s" % _start)
		return

	if _frame == WARMUP + HOLD:
		var now: Vector3 = _player.global_position
		Input.action_release("move_right")
		var moved := now.x - _start.x
		print("[A] 按住 %d 帧后 X 位移 = %.2f  (%s -> %s)" % [HOLD, moved, _start, now])
		_check(moved > 50.0, "动作按下后玩家没有移动 —— 问题在移动代码（move_and_slide / 边界钳制）")
		_probe_matching()
		# 收尾：删掉本测试写出来的存档，别把垃圾留在 user://
		_main.save_service.delete_slot(1)
		print("========== %s ==========" % ("输入诊断发现问题" if _failed else "输入链路正常"))
		quit(1 if _failed else 0)


func _dump_input_map() -> void:
	print("[映射] InputMap 当前注册：")
	for a in ["move_up", "move_down", "move_left", "move_right", "attack", "dash", "pause"]:
		if not InputMap.has_action(a):
			print("       %-11s -> (动作不存在!)" % a)
			continue
		var parts: Array[String] = []
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				parts.append("Key(phys='%s' key='%s')" % [
					OS.get_keycode_string(ev.physical_keycode),
					OS.get_keycode_string(ev.keycode)])
			elif ev is InputEventMouseButton:
				parts.append("Mouse(%d)" % ev.button_index)
		print("       %-11s -> %s" % [a, ", ".join(parts)])


func _probe_matching() -> void:
	# B1：模拟 Windows 正常送来的事件（physical 与 key 都会填）
	var full := InputEventKey.new()
	full.pressed = true
	full.physical_keycode = KEY_D
	full.keycode = KEY_D
	var r1 := InputMap.event_is_action(full, "move_right")
	print("[B1] physical=KEY_D + keycode=KEY_D -> move_right = %s" % r1)
	_check(r1, "完整按键事件匹配不上 move_right")

	# B2：只填 physical（Godot 官方推荐写法）
	var phys_only := InputEventKey.new()
	phys_only.pressed = true
	phys_only.physical_keycode = KEY_D
	print("[B2] 仅 physical=KEY_D              -> move_right = %s" % InputMap.event_is_action(phys_only, "move_right"))

	# B3：只填 keycode（某些驱动 / 远程桌面 / 部分布局下 physical 为空）
	var key_only := InputEventKey.new()
	key_only.pressed = true
	key_only.keycode = KEY_D
	print("[B3] 仅 keycode=KEY_D               -> move_right = %s" % InputMap.event_is_action(key_only, "move_right"))


func _first(group: String):
	var nodes := get_nodes_in_group(group)
	return null if nodes.is_empty() else nodes[0]


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		print("     FAIL: ", msg)
