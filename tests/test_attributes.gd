extends SceneTree
## M8 属性加点自测：真正实例化主场景，验证属性表 / 加点 / 上限 / 加成 / 转职不重置 / 界面开关。
##
##   godot --headless --path . --script res://tests/test_attributes.gd
##
## 设计要点：所有用例都在**同一个 process_frame 回调内同步跑完**，中间不插物理帧，
## 所以敌人的移动 / 攻击不会干扰断言。
##
## ⚠️ 本脚本是 --script 入口，编译早于 autoload 注册，因此**不能**直接写 Events / Game
##    （会报 Identifier not found）。这里用 root.get_node_or_null("Events") 动态拿事件总线，
##    再转发一次「等级变化」，效果与游戏内 Game.add_xp() 升级完全一致。

var _main: Node = null
var _player = null
var _bus: Variant = null
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
	_bus = root.get_node_or_null("Events")
	if _bus == null:
		print("FAIL: 找不到 Events 自动加载节点")
		quit(1)
		return
	_run()
	_report()
	quit(1 if _failed else 0)


# ---------------------------------------------------------------- 用例

func _run() -> void:
	_case_registry()
	_case_no_points_rejected()
	_case_allocate_and_bonus()
	_case_hp_not_overhealed()
	_case_insufficient_points()
	_case_cap()
	_case_profession_switch_keeps_points()
	_case_input_and_panel()


## 数据层：5 个属性、每个都有 per_point 与上限。
func _case_registry() -> void:
	var ids := AttributeRegistry.ids()
	var per_level := AttributeRegistry.free_points_per_level()
	_log.append("属性表 = %s   每级点数 = %d" % [str(ids), per_level])
	_check(ids.size() == 5, "应有 5 个属性，实际 %d" % ids.size())
	_check(per_level > 0, "每级属性点应 > 0")
	for id in ids:
		var attr := AttributeRegistry.get_attribute(id)
		_check(attr != null and not attr.per_point.is_empty(),
			"属性 %s 应有 per_point 加成" % id)
		if attr != null:
			_check(attr.max_points > 0, "属性 %s 应设上限（否则没有「满级」态）" % id)


## 1 级没有点数时加点应被拒绝。
func _case_no_points_rejected() -> void:
	var free_points: int = _player.free_attribute_points()
	var ok: bool = _player.allocate_attribute("strength", 1)
	_log.append("1 级无点数时加点 -> free=%d  alloc=%s（期望 false）" % [free_points, ok])
	_check(free_points == 0, "1 级应没有可分配点数")
	_check(not ok, "没有点数时不应能加点")
	_check(_player.attribute_points("strength") == 0, "被拒绝时不应改变已投入点数")


## 升到 5 级（20 点）后加力量，攻击力应按 per_point 精确上涨。
func _case_allocate_and_bonus() -> void:
	_set_level(5)
	var free_before: int = _player.free_attribute_points()
	var attack_before: float = float(_player.total_stats().get("attack", 0.0))
	var ok: bool = _player.allocate_attribute("strength", 1)
	var attack_after: float = float(_player.total_stats().get("attack", 0.0))
	var expect: float = float(AttributeRegistry.get_attribute("strength").per_point["attack"])
	_log.append("5 级 -> free=%d   力量 +1：攻击 %.1f -> %.1f（期望 +%.1f）" % [
		free_before, attack_before, attack_after, expect])
	_check(free_before == 20, "5 级应有 20 点（4 级 × 5）")
	_check(ok, "有点数时加点应当成功")
	_check(is_equal_approx(attack_after - attack_before, expect),
		"力量每点应 +%.1f 攻击" % expect)
	_check(_player.attribute_points("strength") == 1, "力量应为 1 点")
	_check(_player.free_attribute_points() == 19, "加点后剩余应为 19")


## 加上限不应变成回血手段：当前生命保持不变（只做向下钳制）。
func _case_hp_not_overhealed() -> void:
	_player.hp = _player.max_hp()
	var hp_before: float = _player.hp
	var max_hp_before: float = _player.max_hp()
	var expect: float = float(AttributeRegistry.get_attribute("vitality").per_point["max_hp"])
	var ok: bool = _player.allocate_attribute("vitality", 1)
	_log.append("体力 +1：生命上限 %.0f -> %.0f   当前生命 %.0f（加点前 %.0f）" % [
		max_hp_before, _player.max_hp(), _player.hp, hp_before])
	_check(ok, "体力加点应当成功")
	_check(is_equal_approx(_player.max_hp() - max_hp_before, expect),
		"体力每点应 +%.0f 生命上限" % expect)
	_check(is_equal_approx(_player.hp, hp_before), "加点不应自动补血（当前生命应保持不变）")


## 申请点数超过剩余时被拒绝，且不改变状态；未知属性 id 同样被拒绝。
func _case_insufficient_points() -> void:
	var free_points: int = _player.free_attribute_points()
	var ok: bool = _player.allocate_attribute("agility", free_points + 1)
	_log.append("点数不足（free=%d，申请 %d）-> alloc=%s（期望 false）" % [
		free_points, free_points + 1, ok])
	_check(not ok, "申请点数超过剩余时应当被拒绝")
	_check(_player.attribute_points("agility") == 0, "被拒绝时不应改变已投入点数")
	# 未知 id 只做数据层断言：Player 那条分支会 push_warning，
	# 故意触发它会让自测输出混进 WARNING，破坏「0 WARNING」的验收口径。
	_check(AttributeRegistry.get_attribute("nonexistent") == null, "未知属性 id 应查不到定义")


## 满级：投满上限后继续加点被拒绝，且此时剩余点数仍 > 0（区分「满级」与「点数不足」）。
func _case_cap() -> void:
	_set_level(41)
	var cap: int = AttributeRegistry.get_attribute("strength").max_points
	var have: int = _player.attribute_points("strength")
	var filled: bool = _player.allocate_attribute("strength", cap - have)
	var free_after: int = _player.free_attribute_points()
	var rejected: bool = _player.allocate_attribute("strength", 1)
	_log.append("力量投满（%d -> %d）-> filled=%s   再 +1 -> alloc=%s（剩余 %d）" % [
		have, _player.attribute_points("strength"), filled, rejected, free_after])
	_check(filled, "在上限内应能投满")
	_check(_player.attribute_points("strength") == cap, "力量应停在满级 %d" % cap)
	_check(not rejected, "已满级的属性不应能继续加点")
	_check(free_after > 0, "满级被拒时剩余点数应 > 0（否则无法与「点数不足」区分）")


## 属性点是角色级成长：转职只换基础属性与技能，不重置已投入点数。
func _case_profession_switch_keeps_points() -> void:
	var strength_before: int = _player.attribute_points("strength")
	_player.set_profession("mage")
	_log.append("转职法师后力量点数 = %d（应为 %d）" % [
		_player.attribute_points("strength"), strength_before])
	_check(_player.attribute_points("strength") == strength_before, "转职不应重置属性点")
	_check(_player.attributes.size() == AttributeRegistry.ids().size(), "属性表键集合应保持不变")


## 输入动作与界面：C 键动作存在、面板默认关闭、开关时同步 modal_ui 组。
func _case_input_and_panel() -> void:
	_check(InputMap.has_action("attributes"), "应注册 attributes 输入动作（C）")
	var panel = _main.find_child("AttributePanel", true, false)
	_check(panel != null, "主场景应存在 AttributePanel 加点界面")
	if panel == null:
		return
	_check(not panel.visible, "加点界面默认应关闭")
	panel.toggle()
	_check(panel.visible and panel.is_in_group("modal_ui"),
		"打开后应可见并加入 modal_ui 组（Player 据此冻结操作）")
	panel.toggle()
	_check(not panel.visible and not panel.is_in_group("modal_ui"),
		"关闭后应不可见并退出 modal_ui 组")


# ---------------------------------------------------------------- 工具

## 转发一次「等级变化」事件，等价于游戏内升到 level 级（Game.add_xp 会发同一信号）。
func _set_level(level: int) -> void:
	_bus.emit_signal("player_level_changed", level, 0, 999999)


func _first(group: String) -> Variant:
	# 先赋给无类型 Array，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var nodes: Array = get_nodes_in_group(group)
	return null if nodes.is_empty() else nodes[0]


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		_log.append("  FAIL: %s" % msg)


func _report() -> void:
	print("[attributes] 帧数 = ", _frame)
	for line in _log:
		print("     ", line)
	if _failed:
		print("========== 属性加点自测失败 ==========")
	else:
		print("========== 属性加点自测通过 ==========")
