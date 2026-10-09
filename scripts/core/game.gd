extends Node
## 全局运行时状态 + 输入映射注册（Autoload 名称：Game）
##
## 这里只放「全局」的东西：竞技场范围、角色等级/经验/金币、输入动作。
## 具体玩法状态（血量、装备）放在 Player 里。

## 竞技场矩形（世界坐标）。同时在 Game 里共享，方便角色边界钳制与背景绘制。
var arena: Rect2 = Rect2(-960.0, -640.0, 1920.0, 1280.0)

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
	_add_mouse("attack", MOUSE_BUTTON_LEFT)

func _action(action_name: StringName, keys: Array) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)
	InputMap.add_action(action_name)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action_name, ev)

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
		Events.toast.emit("等级提升！现在是 %d 级" % level, Color(1.0, 0.85, 0.25))
	Events.player_level_changed.emit(level, xp, xp_to_next_level())

# ---------------------------------------------------------------- 金币

func add_gold(amount: int) -> void:
	gold += amount
	Events.gold_changed.emit(gold)

# ---------------------------------------------------------------- 工具

func get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D
