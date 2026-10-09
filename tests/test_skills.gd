extends SceneTree
## M7 技能系统自测：真正实例化主场景，验证施放 / 冷却 / 360° 判定 / 转职 / 蓝量门槛。
##
##   godot --headless --path . --script res://tests/test_skills.gd
##
## 设计要点：所有用例都在**同一个 process_frame 回调内同步跑完**，
## 中间不会插入物理帧，所以敌人的 AI 移动不会干扰命中判定。
## 摆位按玩法平面算（Vector2(x, y) == Vector3(x, 0, y)），口径与游戏内一致。
##
## ⚠️ 本脚本是 --script 入口，编译早于 autoload 注册，因此**不能**引用 Events / Game
##    这两个单例名（会报 Identifier not found）。需要坐标转换时手写等价代码。

var _main: Node = null
var _player = null
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
	if _player == null:
		print("FAIL: 场景里没有玩家节点")
		quit(1)
		return
	_run()
	_report()
	quit(1 if _failed else 0)


# ---------------------------------------------------------------- 用例

func _run() -> void:
	_check(_player.skills().size() >= 2, "应有 2 个技能槽（普攻 / 大招）")
	_case_basic_hit()
	_case_cooldown_blocks()
	_case_full_circle()
	_case_switch_profession()
	_case_mana_gate()


## 普攻：把敌人放到正前方，应当命中掉血。
func _case_basic_hit() -> void:
	_player.set_profession("warrior")
	var enemy = _place_enemy(Vector2(60.0, 0.0))
	if enemy == null:
		return
	var before: float = enemy.hp
	var ok: bool = _player.cast_slot(0)
	_log.append("普攻 裂颅斩 -> cast=%s   敌人 hp %.1f -> %.1f" % [ok, before, enemy.hp])
	_check(ok, "普攻应当施放成功")
	_check(enemy.hp < before, "正前方的敌人应当被普攻命中")


## 冷却：同一技能立刻再放应当被拒绝。
func _case_cooldown_blocks() -> void:
	_place_enemy(Vector2(50.0, 0.0))
	var again: bool = _player.cast_slot(0)
	_log.append("冷却中再放普攻 -> cast=%s（期望 false）" % again)
	_check(not again, "冷却未走完时不应能再次施放")


## 360°：旋风斩（half_angle_deg = 180）应当打到身后的敌人。
func _case_full_circle() -> void:
	var enemy = _place_enemy(Vector2(-60.0, 0.0))
	if enemy == null:
		return
	var before: float = enemy.hp
	var ok: bool = _player.cast_slot(1)
	_log.append("大招 旋风斩（敌在身后）-> cast=%s   敌人 hp %.1f -> %.1f" % [ok, before, enemy.hp])
	_check(ok, "旋风斩应当施放成功")
	_check(enemy.hp < before, "旋风斩是 360°，应当打到身后的敌人")


## 转职：技能列表、蓝量上限应随职业切换。
func _case_switch_profession() -> void:
	_player.set_profession("mage")
	var skills: Array = _player.skills()
	var first_id: String = skills[0].id if not skills.is_empty() else ""
	_log.append("转职法师 -> 技能[0]=%s   蓝量上限=%d   当前蓝=%d" % [
		first_id, int(round(_player.max_mana())), int(round(_player.mana))])
	_check(_player.profession_id() == "mage", "转职后 profession_id 应为 mage")
	_check(first_id == "mage_fireball", "法师普攻应为 mage_fireball")
	_check(int(round(_player.max_mana())) == 140, "法师蓝量上限应为 140")


## 蓝量门槛：蓝不足时耗蓝技能应当被拒绝。
func _case_mana_gate() -> void:
	_player.mana = 0.0
	var ok: bool = _player.cast_slot(1)
	_log.append("蓝=0 时放陨石术 -> cast=%s（期望 false）" % ok)
	_check(not ok, "蓝不足时不应能施放耗蓝技能")


# ---------------------------------------------------------------- 工具

## 把 enemies[0] 挪到「玩家玩法平面坐标 + offset」，返回它。
func _place_enemy(offset: Vector2) -> Variant:
	var enemies: Array = get_nodes_in_group("enemies")
	if enemies.is_empty():
		print("FAIL: 场上没有敌人，无法测试命中")
		_failed = true
		return null
	var enemy = enemies[0]
	# 注意：这里故意**不**用 Game.plane() / Game.world()。
	# --script 模式下测试脚本的编译早于 autoload 单例注册，写 Game 会直接编译失败
	# （Identifier not found: Game）。映射约定与 Game 完全一致：Vector2(x, y) == Vector3(x, 0, y)。
	var pos: Vector3 = _player.global_position
	enemy.global_position = Vector3(pos.x + offset.x, 0.0, pos.z + offset.y)
	return enemy


func _first(group: String) -> Variant:
	# 先赋给无类型 Array，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var nodes: Array = get_nodes_in_group(group)
	return null if nodes.is_empty() else nodes[0]


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		_log.append("  FAIL: %s" % msg)


func _report() -> void:
	print("[skills] 帧数 = ", _frame)
	for line in _log:
		print("     ", line)
	if _failed:
		print("========== 技能自测失败 ==========")
	else:
		print("========== 技能自测通过 ==========")
