extends SceneTree
## 数据层自测脚本（headless 运行，不进游戏）：
##   godot --headless --script res://tests/test_data_layer.gd --path .
##
## 验证 data/loot.json 与 data/enemies.json 能正确加载并生成装备/敌人原型。

func _initialize() -> void:
	var failed := false

	# ---------- LootConfig ----------
	var cfg := LootConfig.load_default()
	if cfg == null:
		print("FAIL: LootConfig.load_default() 返回 null")
		quit(1)
		return
	print("[OK] LootConfig 加载成功")
	print("     drop_chance = ", cfg.drop_chance, "  level_jitter = ", cfg.level_jitter)
	print("     slot_weights = ", cfg.slot_weights)
	print("     rarity_weights = ", cfg.rarity_weights)
	print("     stat_specs keys = ", cfg.stat_specs.keys())
	if cfg.slot_weights.is_empty() or cfg.rarity_weights.is_empty() \
			or cfg.name_pools.is_empty() or cfg.stat_specs.is_empty():
		print("FAIL: LootConfig 有空字段")
		failed = true

	# ---------- EnemyRegistry ----------
	var archs: Array = EnemyRegistry.load_default()
	if archs.is_empty():
		print("FAIL: EnemyRegistry.load_default() 返回空")
		quit(1)
		return
	print("[OK] EnemyRegistry 加载成功，共 ", archs.size(), " 个原型：")
	for a in archs:
		print("     - ", a.id, " / ", a.display_name,
			"  hp(1)=", a.compute_hp(1),
			"  atk(1)=", a.compute_attack(1),
			"  weight=", a.spawn_weight)

	# ---------- 抽样生成 8 件装备 ----------
	print("[OK] 随机生成 8 件装备（lv=3）：")
	for i in range(8):
		var item := LootTable.generate(3)
		if item == null:
			print("FAIL: 第 ", i, " 件装备为 null")
			failed = true
			continue
		print("     ", item.rarity_name(), " ", item.item_name, " [", item.slot_name(),
			" lv", item.item_level, "] stats=", item.stats)

	# ---------- 加权抽取 200 次统计分布 ----------
	var counts := {}
	for i in range(200):
		var a: EnemyArchetype = EnemyRegistry.pick_weighted()
		if a == null:
			print("FAIL: pick_weighted() 返回 null")
			failed = true
			break
		counts[a.id] = int(counts.get(a.id, 0)) + 1
	print("[OK] pick_weighted × 200 分布：", counts)

	if failed:
		print("========== 测试失败 ==========")
		quit(1)
	else:
		print("========== 全部通过 ==========")
		quit(0)
