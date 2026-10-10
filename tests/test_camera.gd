extends SceneTree
## M16 相机自测：配置 / 缩放与旋转与俯角的钳制 / 重置 / 含 yaw 的边界钳制 / 瞬移 snap / 副本边界。
##
##   godot --headless --path . --script res://tests/test_camera.gd
##
## ⚠️ 本脚本是 --script 入口，编译早于 autoload 注册，不能直接写 Events / Game
##    （会 Identifier not found）。这里用 root.get_node_or_null 动态取，
##    并把 _main / _events / _game 都声明成 Variant 以免静态类型分析卡住动态属性访问。
##    同理：**不要写 `CameraRig` 这个类名**（它所在的脚本引用了 Game，会让入口脚本编译失败），
##    相机一律通过 `_main.camera` 动态访问。
##
## ⚠️ M13 起启动会先弹标题选档界面（世界暂停）。本用例只操作状态、不依赖帧推进，
##    所以直接调 `rig.step()` / `rig.snap()`，不需要选槽位。

var _main: Variant = null
var _events: Variant = null
var _game: Variant = null
var _player = null
var _rig = null
var _config: CameraConfig = null
var _failed: bool = false
var _frame: int = 0
var _log: Array[String] = []


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
	if _frame < 3:
		return
	_player = _first("player")
	_events = root.get_node_or_null("Events")
	_game = root.get_node_or_null("Game")
	_rig = _main.camera
	_config = CameraConfig.load_default()
	if _player == null or _events == null or _game == null or _rig == null:
		print("FAIL: 缺少玩家 / Events / Game / 相机")
		quit(1)
		return
	# 关掉「调参打控制台」（DEV_TOOLS 下 main 会打开它），否则自测输出会被几十行 [camera] 刷屏
	_rig.debug_report = false
	_run()
	_report()
	quit(1 if _failed else 0)


# ---------------------------------------------------------------- 用例

func _run() -> void:
	_case_config()
	_case_initial_state()
	_case_zoom_clamp()
	_case_rotate_and_extents()
	_case_tilt_clamp()
	_case_reset()
	_case_focus_clamp()
	_case_teleport_snap()
	_case_input_actions()
	_case_dungeon_bounds()


## 数据层：配置值都要在合法区间里。
func _case_config() -> void:
	_log.append("配置：视野 %.0f（%.0f~%.0f 步进 %.0f）俯角 %.0f°（%.0f~%.0f 步进 %.0f）旋转步进 %.0f° 后撤 %.0f 跟随 %.1f" % [
		_config.size, _config.zoom_min, _config.zoom_max, _config.zoom_step,
		_config.tilt_deg, _config.tilt_min_deg, _config.tilt_max_deg, _config.tilt_step_deg,
		_config.rotate_step_deg, _config.distance, _config.follow_speed])
	_check(_config.zoom_min > 0.0, "缩放下限应 > 0")
	_check(_config.zoom_max > _config.zoom_min, "缩放上限应大于下限")
	_check(_config.size >= _config.zoom_min and _config.size <= _config.zoom_max,
		"初始视野应落在缩放区间内")
	_check(_config.tilt_deg < 0.0, "俯角必须为负（否则相机朝上看）")
	_check(_config.tilt_min_deg < _config.tilt_max_deg, "俯角区间应递增")
	_check(_config.tilt_step_deg > 0.0 and _config.rotate_step_deg > 0.0, "步进应 > 0")
	_check(_config.distance > 0.0 and _config.follow_speed > 0.0, "后撤距离与跟随速度应 > 0")

	# 非法 JSON 也要被钳成能用的值
	var messy := CameraConfig.from_dict({
		"size": -50.0, "tilt_deg": 30.0, "distance": -1.0,
		"zoom": {"min": 100.0, "max": 10.0, "step": -5.0},
		"tilt": {"min_deg": -200.0, "max_deg": 50.0, "step_deg": 0.0},
	})
	_log.append("非法配置 -> 视野 %.0f 俯角 %.0f° 后撤 %.0f 缩放[%.0f, %.0f] 俯角[%.0f, %.0f]" % [
		messy.size, messy.tilt_deg, messy.distance, messy.zoom_min, messy.zoom_max,
		messy.tilt_min_deg, messy.tilt_max_deg])
	_check(messy.size >= messy.zoom_min, "非法视野应被钳进缩放区间")
	_check(messy.tilt_deg < 0.0, "朝上的俯角应被钳回负值")
	_check(messy.distance > 0.0, "非法后撤距离应被钳成正数")
	_check(messy.zoom_max > messy.zoom_min, "缩放上限应被修正为大于下限")


## 初始状态：正交、视野/俯角来自配置、未旋转。
func _case_initial_state() -> void:
	_log.append("初始：projection=%d size=%.0f tilt=%.0f° yaw=%.0f°" % [
		_rig.projection, _rig.ortho_size, _rig.tilt_deg, _rig.yaw_deg])
	_check(_rig.projection == 1, "相机应是正交投影（PROJECTION_ORTHOGONAL = 1）")
	_check(is_equal_approx(_rig.ortho_size, _config.size), "初始视野应等于配置值")
	_check(is_equal_approx(_rig.tilt_deg, _config.tilt_deg), "初始俯角应等于配置值")
	_check(is_zero_approx(_rig.yaw_deg), "初始不应旋转")
	_check(not String(_rig.debug_text()).is_empty(), "应有调试读数")


## 缩放钳制在 [min, max]。
func _case_zoom_clamp() -> void:
	_rig.reset_view()
	for i in range(60):
		_rig.zoom_by(1)
	var zoomed_in: float = _rig.ortho_size
	for i in range(120):
		_rig.zoom_by(-1)
	var zoomed_out: float = _rig.ortho_size
	_log.append("缩放：一直拉近 -> %.0f（下限 %.0f）  一直拉远 -> %.0f（上限 %.0f）" % [
		zoomed_in, _config.zoom_min, zoomed_out, _config.zoom_max])
	_check(is_equal_approx(zoomed_in, _config.zoom_min), "拉近应停在下限")
	_check(is_equal_approx(zoomed_out, _config.zoom_max), "拉远应停在上限")
	_check(not _rig.zoom_by(0), "步进 0 应无变化")


## 旋转：步进正确、角度归一化、90° 时画面足迹的 X/Z 互换。
## ⚠️ 每个小段都先 reset_view()：否则前面剩下的 yaw 会把「足迹」算成斜着的，数值对不上。
func _case_rotate_and_extents() -> void:
	_rig.reset_view()
	var base_ext: Vector2 = _rig.view_extents()
	_rig.rotate_by(1)
	var one_step: float = _rig.yaw_deg
	_check(is_equal_approx(one_step, _config.rotate_step_deg), "一次旋转应走一个步进")

	# 恰好转 90°（步数 = 90 / 步进），足迹的 X/Z 应互换
	var steps := int(round(90.0 / _config.rotate_step_deg))
	_rig.reset_view()
	for i in range(steps):
		_rig.rotate_by(1)
	var quarter_ext: Vector2 = _rig.view_extents()
	var quarter_yaw: float = _rig.yaw_deg
	for i in range(steps):
		_rig.rotate_by(-1)
	_log.append("旋转：一步 %.0f°（配置 %.0f°）  转 %.0f° 后足迹 (%.0f, %.0f) ← 0° 时 (%.0f, %.0f)" % [
		one_step, _config.rotate_step_deg, quarter_yaw,
		quarter_ext.x, quarter_ext.y, base_ext.x, base_ext.y])
	_check(is_equal_approx(quarter_yaw, 90.0), "转 %d 步应恰好是 90°" % steps)
	_check(absf(quarter_ext.x - base_ext.y) < 1.0 and absf(quarter_ext.y - base_ext.x) < 1.0,
		"转 90° 后画面足迹的 X/Z 应互换（边界钳制靠它）")
	_check(is_zero_approx(_rig.yaw_deg), "反向转回来应回到 0°")

	# 大角度也要归一化在 (-180, 180]
	for i in range(40):
		_rig.rotate_by(1)
	_log.append("连转 40 步后 yaw = %.1f°（应在 (-180, 180]）" % _rig.yaw_deg)
	_check(_rig.yaw_deg > -180.0 and _rig.yaw_deg <= 180.0, "旋转角应归一化")


## 俯角钳制在两个端点内。
## 注意命名：`tilt_min_deg` 是**数值最小**的那个（-70°，最俯视），`tilt_max_deg` 是 -22°（最平）。
func _case_tilt_clamp() -> void:
	_rig.reset_view()
	for i in range(80):
		_rig.tilt_by(1)
	var most_top: float = _rig.tilt_deg
	var top_ext: Vector2 = _rig.view_extents()
	_rig.reset_view()
	for i in range(160):
		_rig.tilt_by(-1)
	var most_flat: float = _rig.tilt_deg
	var flat_ext: Vector2 = _rig.view_extents()
	_log.append("俯角：最俯 %.0f°（足迹深 %.0f）  最平 %.0f°（足迹深 %.0f）" % [
		most_top, top_ext.y, most_flat, flat_ext.y])
	_check(is_equal_approx(most_top, _config.tilt_min_deg), "连续更俯应停在 tilt_min（数值最小 = 最俯）")
	_check(is_equal_approx(most_flat, _config.tilt_max_deg), "连续更平应停在 tilt_max（-22° 一带）")
	_check(top_ext.y > flat_ext.y, "相机越俯视，画面覆盖的地面纵深应越大")


## 重置回到 JSON 默认视角。
func _case_reset() -> void:
	_rig.zoom_by(3)
	_rig.rotate_by(2)
	_rig.tilt_by(3)
	_rig.reset_view()
	_log.append("重置后：视野 %.0f 俯角 %.0f° 旋转 %.0f°" % [
		_rig.ortho_size, _rig.tilt_deg, _rig.yaw_deg])
	_check(is_equal_approx(_rig.ortho_size, _config.size), "重置应恢复默认视野")
	_check(is_equal_approx(_rig.tilt_deg, _config.tilt_deg), "重置应恢复默认俯角")
	_check(is_zero_approx(_rig.yaw_deg), "重置应恢复默认（不旋转）")


## 边界钳制：玩家贴边时焦点被推回场地内；玩家在中间时不做钳制。
func _case_focus_clamp() -> void:
	var arena: Rect2 = _game.arena
	var ext: Vector2 = _rig.view_extents()
	var corner := Vector2(arena.position.x - 200.0, arena.position.y - 200.0)
	var clamped: Vector2 = _rig.clamp_focus(corner)
	_log.append("贴边焦点 %s -> 钳后 %s（场地 %s，足迹半宽/半深 %.0f/%.0f）" % [
		corner, clamped, arena, ext.x, ext.y])
	_check(clamped.x >= arena.position.x + ext.x - 0.01, "焦点 X 应被钳进场地左边界")
	_check(clamped.y >= arena.position.y + ext.y - 0.01, "焦点 Y 应被钳进场地上边界")
	_check(clamped.x <= arena.end.x - ext.x + 0.01, "焦点 X 应被钳进场地右边界")
	_check(clamped.y <= arena.end.y - ext.y + 0.01, "焦点 Y 应被钳进场地下边界")

	var center: Vector2 = arena.get_center()
	_check(_rig.clamp_focus(center) == center, "场地中心不应被钳制")

	# 实际跟随：把玩家挪到角落，snap 后焦点必须是钳过的
	_player.global_position = _game.world(corner)
	_rig.snap()
	var focus: Vector2 = _rig.focus_plane()
	_log.append("玩家在角落时相机焦点 = %s" % focus)
	_check(focus.x >= arena.position.x + ext.x - 0.01, "相机焦点应被钳在场地内（X）")
	_check(focus.y >= arena.position.y + ext.y - 0.01, "相机焦点应被钳在场地内（Y）")


## 瞬移（复活 / 进出地城）应直接对齐，不平滑；小位移才平滑。
func _case_teleport_snap() -> void:
	var arena: Rect2 = _game.arena
	# 从**场地中心**出发再做小位移：如果从贴边状态出发，焦点会被边界钳住不动，
	# 看起来像「没跟随」，其实是钳制在正常工作
	var center: Vector2 = arena.get_center()
	var near_target := center + Vector2(40.0, 0.0)
	_rig.set_focus(center)
	_player.global_position = _game.world(near_target)
	var before: Vector2 = _rig.focus_plane()
	_rig.step(0.05)
	var after_small: Vector2 = _rig.focus_plane()
	_log.append("小位移：焦点 %s -> %s（目标 %s，应平滑前进）" % [before, after_small, near_target])
	_check(after_small.distance_to(near_target) < before.distance_to(near_target),
		"小位移时焦点应向目标靠近（平滑跟随）")
	# Vector2 之间比相等要用实例方法（全局 is_equal_approx 只吃 float）
	_check(not after_small.is_equal_approx(near_target), "小位移不应瞬移到位")

	# 先把期望焦点挪到对角，再让玩家瞬移到另一角：距离远大于「视野 × 3」→ 必须直接对齐
	var far_target := arena.position + Vector2(60.0, 60.0)
	_rig.set_focus(arena.end)
	_player.global_position = _game.world(far_target)
	_rig.step(0.05)
	var after_far: Vector2 = _rig.focus_plane()
	var expected_far: Vector2 = _rig.clamp_focus(far_target)
	_log.append("大位移：焦点 %s -> %s（期望钳后 %s）" % [
		arena.end, after_far, expected_far])
	_check(after_far.distance_to(expected_far) < 0.01, "大位移应直接对齐（不做平滑）")


## 相机操作动作都要注册（含滚轮）。
func _case_input_actions() -> void:
	var actions := ["zoom_in", "zoom_out", "rotate_left", "rotate_right",
		"tilt_up", "tilt_down", "camera_reset"]
	var missing: Array[String] = []
	for action in actions:
		if not InputMap.has_action(action):
			missing.append(action)
	_log.append("相机输入动作 %d 个，缺失 %s" % [actions.size(), str(missing)])
	_check(missing.is_empty(), "相机动作应全部注册，缺：%s" % str(missing))


## 进地城后边界换成地城范围，钳制也要跟着换。
func _case_dungeon_bounds() -> void:
	var arena_before: Rect2 = _game.arena
	var ids: Array = DungeonRegistry.ids()
	_check(not ids.is_empty(), "应至少有一间地城")
	if ids.is_empty():
		return
	_events.emit_signal("dungeon_enter_requested", ids[0])
	var arena_dungeon: Rect2 = _game.arena
	var focus: Vector2 = _rig.focus_plane()
	_log.append("进地城：场地 %s -> %s，相机焦点 %s" % [arena_before, arena_dungeon, focus])
	_check(arena_dungeon != arena_before, "进地城后 Game.arena 应换成地城范围")
	_check(arena_dungeon.has_point(focus), "相机焦点应落在地城范围内")
	_check(_rig.clamp_focus(focus) == focus, "地城内的焦点不应被再次钳制")

	_events.emit_signal("dungeon_exit_requested")
	_log.append("离开地城：场地回到 %s" % _game.arena)
	_check(_game.arena == arena_before, "离开地城后场地应还原")


# ---------------------------------------------------------------- 工具

func _first(group: String) -> Variant:
	# 先赋给无类型 Array，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var nodes: Array = get_nodes_in_group(group)
	return null if nodes.is_empty() else nodes[0]


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		_log.append("  FAIL: %s" % msg)


func _report() -> void:
	print("[camera] 帧数 = ", _frame)
	for line in _log:
		print("     ", line)
	if _failed:
		print("========== 相机自测失败 ==========")
	else:
		print("========== 相机自测通过 ==========")
