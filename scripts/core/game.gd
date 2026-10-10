extends Node
## 全局运行时状态 + 输入映射注册（Autoload 名称：Game）
##
## 这里只放「全局」的东西：竞技场范围、角色等级/经验/金币、输入动作。
## 具体玩法状态（血量、装备）放在 Player 里。

## 原野（竞技场）的固定边界。`arena` 会随进出地城切换，所以「回家」要看这个常量。
const ARENA_HOME := Rect2(-960.0, -640.0, 1920.0, 1280.0)

## 当前可行走范围（玩法平面坐标）。原地是竞技场；进入地城后由 main.gd 换成地城范围，
## 这样玩家 / 敌人 / 相机的边界钳制全部沿用同一份数据，不用各自感知「在不在副本里」。
var arena: Rect2 = ARENA_HOME

## 当前是否在地城内 + 地城 id（由 main.gd 维护）
var in_dungeon: bool = false
var dungeon_id: String = ""

var gold: int = 0
var level: int = 1
var xp: int = 0

## 1 级升 2 级所需经验，之后按指数增长。
const BASE_XP := 70

func _ready() -> void:
	_setup_input()

# ---------------------------------------------------------------- 输入映射

func _setup_input() -> void:
	_action("move_up", [KEY_W, KEY_UP])
	_action("move_down", [KEY_S, KEY_DOWN])
	_action("move_left", [KEY_A, KEY_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT])
	_action("attack", [KEY_SPACE, KEY_J])
	_action("dash", [KEY_SHIFT, KEY_K])
	_action("pause", [KEY_ESCAPE, KEY_P])
	_add_mouse("attack", MOUSE_BUTTON_LEFT)

	# M7 技能：1/2 = 当前职业的普攻 / 大招（Q/E 为同义键）
	_action("skill_1", [KEY_1, KEY_Q])
	_action("skill_2", [KEY_2, KEY_E])
	# 原型期切职业：F1/F2/F3 = 战/法/游。
	# 正式版应改为角色创建流程，这里的目的是让三个职业立刻可试。
	_action("profession_1", [KEY_F1])
	_action("profession_2", [KEY_F2])
	_action("profession_3", [KEY_F3])

	# M8 属性加点：C 开关加点界面（Character）
	_action("attributes", [KEY_C])

	# M10 交互：F 使用传送门（进/出地城）
	_action("interact", [KEY_F])

func _action(action_name: StringName, keys: Array) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)
	InputMap.add_action(action_name)
	for key in keys:
		# 同时注册两套事件，缺一不可：
		#   physical_keycode —— 按键盘上的物理位置，与布局无关
		#   keycode          —— 按字符，布局相关
		# 只注册 physical 时，若环境不提供物理码（远程桌面 / 部分驱动 / 虚拟机），
		# 该动作会完全收不到键盘输入。实测 InputMap.event_is_action() 只认 physical，
		# 所以这里必须两个都加。
		var physical := InputEventKey.new()
		physical.physical_keycode = key
		InputMap.action_add_event(action_name, physical)

		var logical := InputEventKey.new()
		logical.keycode = key
		InputMap.action_add_event(action_name, logical)

func _add_mouse(action_name: StringName, button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action_name, ev)

# ---------------------------------------------------------------- 等级 / 经验

func xp_to_next_level() -> int:
	return int(round(BASE_XP * pow(1.4, float(level - 1))))

func add_xp(amount: int) -> void:
	xp += amount
	var leveled := false
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		leveled = true
	if leveled:
		# 升级同时给自由属性点（点数曲线在 data/attributes.json），提示里带上，避免玩家不知道可以加点
		Events.toast.emit("等级提升！现在是 %d 级（+%d 属性点，按 C 加点）" % [
			level, AttributeRegistry.free_points_per_level()], Color(1.0, 0.85, 0.25))
		Events.player_level_changed.emit(level, xp, xp_to_next_level())

# ---------------------------------------------------------------- 金币

func add_gold(amount: int) -> void:
	gold += amount
	Events.gold_changed.emit(gold)

# ---------------------------------------------------------------- 工具

func get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node3D


# ------------------------------------------------------- 玩法平面 <-> 世界坐标
#
# 玩法逻辑（距离、方向、角度）仍然全部用 Vector2 在「玩法平面」上计算，
# 只在读写节点位置时转换成 Vector3。映射约定：Vector2(x, y) -> Vector3(x, 0, y)。
# 这样转换面积最小，AI/攻击判定等逻辑一行都不用改。

static func world(plane_point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(plane_point.x, height, plane_point.y)


static func plane(world_point: Vector3) -> Vector2:
	return Vector2(world_point.x, world_point.z)


## 取节点的「玩法平面」坐标，供距离/方向计算使用。
func plane_of(node: Node3D) -> Vector2:
	if node == null or not is_instance_valid(node):
		return Vector2.ZERO
	return plane(node.global_position)
