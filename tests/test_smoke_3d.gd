extends SceneTree
## 3D 冒烟测试：真正实例化 main.tscn 并跑若干帧，验证实体与渲染节点都已生成。
##
##   godot --headless --path . --script res://tests/test_smoke_3d.gd
##
## 注意：这里用无类型变量接收节点，避免静态类型分析把元素推断为基类而误报。

var _frames: int = 0
var _main: Node = null
var _failed: bool = false


func _initialize() -> void:
	Engine.time_scale = 30.0
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("FAIL: 无法加载 res://scenes/main.tscn")
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 300:
		return
	_report()
	quit(1 if _failed else 0)


func _report() -> void:
	var players := get_nodes_in_group("player")
	var enemies := get_nodes_in_group("enemies")
	var pickups := get_nodes_in_group("pickups")

	print("[smoke] 帧数 = ", _frames, "   time_scale = ", Engine.time_scale)
	_check(players.size() == 1, "玩家数量应为 1，实际 %d" % players.size())
	_check(enemies.size() > 0, "敌人数量应 > 0，实际 %d" % enemies.size())
	print("     玩家 %d 个 | 敌人 %d 个 | 掉落物 %d 个" % [
		players.size(), enemies.size(), pickups.size()])

	if not players.is_empty():
		var p = players[0]
		print("     玩家 class = ", p.get_class(), "  pos = ", p.global_position, "  hp = ", p.hp)
		_check(p.get_class() == "CharacterBody3D", "玩家应为 CharacterBody3D")
		# M7：职业 / 技能 / 蓝量
		print("     职业 = ", p.profession_id(),
			"  蓝 = ", int(round(p.mana)), "/", int(round(p.max_mana())),
			"  技能 = ", p.skills().size())
		_check(p.has_method("cast_slot"), "玩家应有 cast_slot 方法（M7 技能）")
		_check(p.max_mana() > 0.0, "玩家应有大于 0 的蓝量上限")
		_check(p.skills().size() >= 2, "玩家应至少有 2 个技能槽（普攻 / 大招）")
		_check(p.profession != null, "玩家应已选定职业")
		# M8：属性加点
		print("     属性 = ", p.attributes,
			"  剩余点数 = ", p.free_attribute_points())
		_check(p.has_method("allocate_attribute"), "玩家应有 allocate_attribute 方法（M8 属性加点）")
		_check(p.attributes.size() == AttributeRegistry.ids().size(),
			"玩家的属性表应与 data/attributes.json 一致")

	# M7：技能栏应存在于 HUD 之下
	var skill_bar = _main.find_child("SkillBar", true, false)
	_check(skill_bar != null, "应存在名为 SkillBar 的技能栏节点")

	# M8：加点界面应存在
	var attribute_panel = _main.find_child("AttributePanel", true, false)
	_check(attribute_panel != null, "应存在名为 AttributePanel 的加点界面节点")

	if not enemies.is_empty():
		var e = enemies[0]
		print("     首个敌人 id = ", e.archetype.id, "  lv = ", e.level,
			"  hp = ", e.hp, "/", e.max_hp, "  radius = ", e.radius)
		_check(e.get_class() == "CharacterBody3D", "敌人应为 CharacterBody3D")
		var ids := {}
		for en in enemies:
			ids[en.archetype.id] = int(ids.get(en.archetype.id, 0)) + 1
		print("     敌人原型分布 = ", ids)

	var counts := {}
	_tally(_main, counts)
	print("     节点统计 = ", counts)
	_check(int(counts.get("Camera3D", 0)) == 1, "应恰好有 1 个 Camera3D")
	_check(int(counts.get("DirectionalLight3D", 0)) >= 1, "应有方向光")
	_check(int(counts.get("WorldEnvironment", 0)) >= 1, "应有 WorldEnvironment")
	_check(int(counts.get("Sprite3D", 0)) > 0, "应有 billboard 精灵")
	_check(int(counts.get("MeshInstance3D", 0)) > 20, "应有较多网格实例（地面/墙/岩石/影斑）")

	if _failed:
		print("========== 冒烟测试失败 ==========")
	else:
		print("========== 冒烟测试通过 ==========")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		print("     FAIL: ", msg)


func _tally(node: Node, counts: Dictionary) -> void:
	var c := node.get_class()
	counts[c] = int(counts.get(c, 0)) + 1
	for child in node.get_children():
		_tally(child, counts)
