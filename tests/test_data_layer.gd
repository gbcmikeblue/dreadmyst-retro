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

	# ---------- 职业 / 技能（M7）----------
	var profs: Array = ProfessionRegistry.load_default()
	if profs.is_empty():
		print("FAIL: ProfessionRegistry.load_default() 返回空")
		quit(1)
		return
	print("[OK] ProfessionRegistry 加载成功，共 ", profs.size(), " 个职业：")
	for p in profs:
		var prof_skills: Array = p.skills()
		print("     - ", p.id, " / ", p.display_name, "  base=", p.base_stats)
		# 约定：下标 0 = 普攻，1 = 大招
		if prof_skills.size() < 2:
			print("FAIL: 职业 ", p.id, " 的技能不足 2 个（约定 0=普攻、1=大招）")
			failed = true
		for s in prof_skills:
			if s.profession_id != p.id:
				print("FAIL: 技能 ", s.id, " 的 profession 字段与所属职业不一致")
				failed = true

	var all_skills: Array = SkillRegistry.load_default()
	if all_skills.is_empty():
		print("FAIL: SkillRegistry.load_default() 返回空")
		quit(1)
		return
	print("[OK] SkillRegistry 加载成功，共 ", all_skills.size(), " 个技能：")
	for s in all_skills:
		print("     - ", s.id, " / ", s.display_name, " [", s.kind_name(), "]",
			"  cd=", s.cooldown, "s",
			"  mp=", s.mana_cost,
			"  mult=", s.damage_mult,
			"  range=", s.cast_range,
			"  half_angle=", int(round(rad_to_deg(s.half_angle))), "°")

	# ---------- 属性（M8）----------
	var attrs: Array = AttributeRegistry.load_default()
	if attrs.is_empty():
		print("FAIL: AttributeRegistry.load_default() 返回空")
		quit(1)
		return
	print("[OK] AttributeRegistry 加载成功，共 ", attrs.size(), " 个属性，每级 ",
		AttributeRegistry.free_points_per_level(), " 点：")
	for a in attrs:
		print("     - ", a.id, " / ", a.display_name,
			"  max=", a.max_points, "  per_point=", a.per_point)
		if a.per_point.is_empty():
			print("FAIL: 属性 ", a.id, " 没有 per_point 加成")
			failed = true

	var bonus: Dictionary = AttributeRegistry.bonus_for_all({"strength": 2, "vitality": 3})
	print("[OK] bonus_for_all({strength:2, vitality:3}) = ", bonus)
	if not bonus.has("attack") or not bonus.has("max_hp"):
		print("FAIL: bonus_for_all 汇总结果缺少 attack / max_hp")
		failed = true

	# ---------- 地城 / Boss（M10）----------
	var dungeons: Array = DungeonRegistry.load_default()
	if dungeons.is_empty():
		print("FAIL: DungeonRegistry.load_default() 返回空")
		quit(1)
		return
	print("[OK] DungeonRegistry 加载成功，共 ", dungeons.size(), " 间地城：")
	for d in dungeons:
		print("     - ", d.id, " / ", d.display_name,
			"  房间=", d.room_count, "  尺寸=", d.room_size,
			"  每房怪数=", d.enemies_per_room,
			"  Boss=", d.boss_id,
			"  保底品质=", d.guaranteed_rarity)
		if d.boss_id.is_empty():
			print("FAIL: 地城 ", d.id, " 没有配置 Boss")
			failed = true
		var boss_arch: EnemyArchetype = EnemyRegistry.get_archetype(d.boss_id)
		if boss_arch == null or not boss_arch.is_boss:
			print("FAIL: 地城 ", d.id, " 的 Boss 原型 '", d.boss_id, "' 不存在或未标 is_boss")
			failed = true

		# 布局派生自检：并集矩形必须能包住每一间房（相机/边界钳制都依赖它）
		var origin := Vector2(0.0, 1000.0)
		var bounds: Rect2 = d.bounds(origin)
		for i in range(d.room_count):
			if not bounds.encloses(d.room_rect(i, origin)):
				print("FAIL: 地城 ", d.id, " 第 ", i, " 间房不在 bounds 内")
				failed = true

	# Boss 不应混进野外加权刷怪池
	var wild_boss := 0
	for i in range(300):
		var arch: EnemyArchetype = EnemyRegistry.pick_weighted()
		if arch != null and arch.is_boss:
			wild_boss += 1
	print("[OK] pick_weighted × 300 抽到 Boss 次数 = ", wild_boss, "（期望 0）")
	if wild_boss > 0:
		print("FAIL: Boss 混进了野外刷怪池")
		failed = true

	# ---------- 背包 / 商店（M11）----------
	var inv := InventoryConfig.load_default()
	print("[OK] InventoryConfig：容量 ", inv.backpack_capacity,
		"  卖出价 = 评分 × ", inv.sell_price_per_power,
		" + 等级 × ", inv.sell_price_per_level)
	if inv.backpack_capacity <= 0:
		print("FAIL: 背包容量应 > 0")
		failed = true

	var shop_cfg: ShopConfig = ShopConfig.load_default()
	if shop_cfg.offers.is_empty():
		print("FAIL: ShopConfig.offers 为空")
		failed = true
	print("[OK] ShopConfig：刷新价 ", shop_cfg.restock_cost, "，货架 ", shop_cfg.offers.size(), " 条：")
	for o in shop_cfg.offers:
		print("     - ", o["slot_key"], " / ", o["rarity_key"], "  lv", o["item_level"],
			"  price=", o["price"])
		if int(o["price"]) <= 0:
			print("FAIL: 货架商品价格应 > 0")
			failed = true
		# 指定部位 / 品质必须真的生效：商店不能卖「名字是战靴、词条是武器」的货
		var probe := LootTable.generate(
			int(o["item_level"]), String(o["rarity_key"]), String(o["slot_key"]))
		if probe == null or probe.slot != int(o["slot"]) or probe.rarity != int(o["rarity"]):
			print("FAIL: generate(指定 slot/rarity) 结果不符：",
				o["slot_key"], " / ", o["rarity_key"])
			failed = true

	# ---------- 存档数据结构（M13）----------
	var gear := LootTable.generate(3, "epic", "helmet")
	var gear_back := GearItem.from_dict(gear.to_dict())
	print("[OK] GearItem 序列化往返：", gear_back.item_name, " / slot=", gear_back.slot,
		" rarity=", gear_back.rarity, " lv=", gear_back.item_level, " stats=", gear_back.stats)
	if gear_back.slot != gear.slot or gear_back.rarity != gear.rarity \
			or gear_back.item_level != gear.item_level:
		print("FAIL: GearItem 序列化往返的枚举 / 等级不一致")
		failed = true
	# 词条逐项按数值比较：JSON 往返会把 int 变成 float，整字典直接比会误判
	for stat_key in gear.stats:
		if not is_equal_approx(float(gear_back.stats.get(stat_key, -1.0)), float(gear.stats[stat_key])):
			print("FAIL: 词条 ", stat_key, " 往返不一致：", gear.stats[stat_key],
				" -> ", gear_back.stats.get(stat_key))
			failed = true

	# 枚举键映射必须只在 GearItem 里存一份，LootConfig 转发过去（否则两处会漂移）
	for slot_enum in GearItem.SLOT_ORDER:
		var slot_key := GearItem.slot_key(slot_enum)
		if GearItem.slot_from_key(slot_key) != slot_enum:
			print("FAIL: slot 键往返失败：", slot_key)
			failed = true
		if LootConfig.load_default().slot_enum_for(slot_key) != slot_enum:
			print("FAIL: LootConfig 没有转发到 GearItem 的 slot 映射：", slot_key)
			failed = true
	for rarity_enum in GearItem.RARITY_NAMES.keys():
		var rarity_key := GearItem.rarity_key(rarity_enum)
		if GearItem.rarity_from_key(rarity_key) != rarity_enum:
			print("FAIL: rarity 键往返失败：", rarity_key)
			failed = true
	print("[OK] 部位 / 品质 枚举键往返一致（GearItem 为唯一映射，LootConfig 转发）")

	var save_probe := SaveData.new()
	save_probe.level = 3
	save_probe.gold = 42
	save_probe.profession_id = "warrior"
	var save_back := SaveData.from_dict(save_probe.to_dict())
	print("[OK] SaveData 往返：lv=", save_back.level, " gold=", save_back.gold,
		" prof=", save_back.profession_id, " version=", save_back.version,
		" 受支持=", save_back.is_supported_version())
	if save_back.level != 3 or save_back.gold != 42 or not save_back.is_supported_version():
		print("FAIL: SaveData 往返不一致")
		failed = true

	# ---------- 相机配置（M16）----------
	var cam: CameraConfig = CameraConfig.load_default()
	print("[OK] CameraConfig：视野 ", cam.size, "（", cam.zoom_min, "~", cam.zoom_max,
		" 步进 ", cam.zoom_step, "）俯角 ", cam.tilt_deg, "°（",
		cam.tilt_min_deg, "~", cam.tilt_max_deg, " 步进 ", cam.tilt_step_deg,
		"）旋转步进 ", cam.rotate_step_deg, "° 后撤 ", cam.distance)
	if cam.zoom_min <= 0.0 or cam.zoom_max <= cam.zoom_min:
		print("FAIL: 相机缩放区间非法（min 应为正、max 应大于 min）")
		failed = true
	if cam.size < cam.zoom_min or cam.size > cam.zoom_max:
		print("FAIL: 相机初始视野不在缩放区间内")
		failed = true
	if cam.tilt_deg >= 0.0:
		print("FAIL: 相机俯角应为负（负数才是朝下看）")
		failed = true

	if failed:
		print("========== 测试失败 ==========")
		quit(1)
	else:
		print("========== 全部通过 ==========")
		quit(0)
