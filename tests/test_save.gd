extends SceneTree
## M13 存档自测：数据层往返 / 兜底、槽位读写删、坏档处理、一条龙存读、标题选档界面。
##
##   godot --headless --path . --script res://tests/test_save.gd
##
## ⚠️ 会真的写文件（`user://`），但**全部走测试专用路径模板** `test_save_%d.json`，
##    跑完会删干净；坏档备份产生的 `.corrupt-*` 也一并清理，真实存档不受影响。
##
## ⚠️ 本脚本是 --script 入口，编译早于 autoload 注册，不能直接写 Events / Game
##    （会 Identifier not found）。这里用 root.get_node_or_null 动态取，
##    并把 _main / _events / _game 都声明成 Variant 以免静态类型分析卡住动态属性访问。

const TEST_PATTERN := "user://test_save_%d.json"

var _main: Variant = null
var _events: Variant = null
var _game: Variant = null
var _player = null
var _service = null
var _failed: bool = false
var _frame: int = 0
var _log: Array[String] = []
## 最近一次 save_slots_changed 的内容
var _slots: Array = []


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
	_service = _main.save_service
	if _player == null or _events == null or _game == null or _service == null:
		print("FAIL: 缺少玩家 / Events / Game / SaveService")
		quit(1)
		return
	# 一切 IO 都走测试专用路径，别动真实存档
	_service.path_pattern = TEST_PATTERN
	_cleanup()
	_events.save_slots_changed.connect(_on_slots_changed)

	_run()
	_cleanup()
	_report()
	quit(1 if _failed else 0)


func _on_slots_changed(slots: Array) -> void:
	_slots = slots


# ---------------------------------------------------------------- 用例

func _run() -> void:
	_case_gear_roundtrip()
	_case_savedata_bounds()
	_case_slot_io()
	_case_corrupt_slot()
	_case_title_screen()
	_case_full_roundtrip()
	_case_autosave_flag()


## GearItem 序列化往返 + 非法输入兜底。
func _case_gear_roundtrip() -> void:
	var gear := GearItem.new()
	gear.item_name = "存读测试剑"
	gear.slot = GearItem.Slot.RING
	gear.rarity = GearItem.Rarity.EPIC
	gear.item_level = 7
	gear.stats = {"attack": 21.0, "crit": 0.05}

	var back := GearItem.from_dict(gear.to_dict())
	_check(back.item_name == gear.item_name, "名字应往返一致")
	_check(back.slot == gear.slot and back.rarity == gear.rarity, "部位 / 品质应往返一致")
	_check(back.item_level == gear.item_level, "物品等级应往返一致")
	_check(is_equal_approx(float(back.stats.get("attack", 0.0)), 21.0), "attack 词条应往返一致")
	_check(is_equal_approx(float(back.stats.get("crit", 0.0)), 0.05), "crit 词条应往返一致")

	# 非法输入：枚举越界钳制、等级下限、未知词条丢弃、负词条归零
	var messy := GearItem.from_dict({
		"slot": 99, "rarity": -3, "item_level": -5,
		"stats": {"attack": -8.0, "nonsense": 123.0},
	})
	_log.append("非法装备 -> slot=%d rarity=%d lv=%d stats=%s" % [
		messy.slot, messy.rarity, messy.item_level, str(messy.stats)])
	_check(messy.slot >= 0 and messy.slot <= 4, "非法 slot 应被钳到合法枚举")
	_check(messy.rarity >= 0 and messy.rarity <= 4, "非法 rarity 应被钳到合法枚举")
	_check(messy.item_level >= 1, "非法等级应被钳到 >= 1")
	_check(not messy.stats.has("nonsense"), "未知词条应被丢弃")
	_check(float(messy.stats.get("attack", -1.0)) >= 0.0, "负词条应归零")


## SaveData 往返 + 背包超容量 / 版本判定。
func _case_savedata_bounds() -> void:
	var data := SaveData.new()
	data.saved_at = "2026-10-10T12:00:00"
	data.kills = 9
	data.level = 6
	data.xp = 55
	data.gold = 1234
	data.profession_id = "mage"
	data.hp = 70.0
	data.mana = 30.0
	data.attributes = {"strength": 3, "vitality": 4}
	data.equipment = {GearItem.Slot.WEAPON: _make_gear(GearItem.Slot.WEAPON, "存档武器", 12.0)}
	data.backpack = [_make_gear(GearItem.Slot.ARMOR, "存档护甲", 8.0)]

	var back := SaveData.from_dict(data.to_dict())
	_log.append("SaveData 往返 -> lv=%d gold=%d prof=%s 装备=%d 件 背包=%d 件" % [
		back.level, back.gold, back.profession_id, back.equipment.size(), back.backpack.size()])
	_check(back.level == 6 and back.xp == 55 and back.gold == 1234, "进度应往返一致")
	_check(back.profession_id == "mage", "职业应往返一致")
	_check(is_equal_approx(back.hp, 70.0) and is_equal_approx(back.mana, 30.0), "hp/mana 应往返一致")
	_check(int(back.attributes.get("strength", 0)) == 3, "属性点应往返一致")
	_check(back.equipment.has(GearItem.Slot.WEAPON), "装备应往返一致（键还原成部位枚举）")
	_check(back.backpack.size() == 1, "背包应往返一致")
	_check(back.is_supported_version(), "当前版本应受支持")

	# 背包超容量：造 capacity+6 件，应该只收 capacity 件并记下丢了多少
	var capacity: int = InventoryConfig.load_default().backpack_capacity
	var overflow := SaveData.new()
	for i in range(capacity + 6):
		overflow.backpack.append(_make_gear(GearItem.Slot.BOOTS, "溢出 %d" % i, float(i)))
	var trimmed := SaveData.from_dict(overflow.to_dict())
	_log.append("背包溢出：存档 %d 件 / 容量 %d -> 收 %d 件，丢弃 %d 件" % [
		capacity + 6, capacity, trimmed.backpack.size(), trimmed.dropped_backpack_items])
	_check(trimmed.backpack.size() == capacity, "超容量部分应被丢弃")
	_check(trimmed.dropped_backpack_items == 6, "应记下丢弃件数")

	# 未知属性 id 与版本不符
	var odd := SaveData.from_dict({
		"version": 999,
		"player": {"attributes": {"strength": 2, "不存在的属性": 5}},
	})
	_check(not odd.is_supported_version(), "版本 999 应被判为不受支持")
	_check(int(odd.attributes.get("strength", 0)) == 2, "合法属性应保留")


## 槽位读写删 + 摘要。
func _case_slot_io() -> void:
	_check(not _service.has_save(1), "初始槽位 1 应为空")
	var data := SaveData.new()
	data.level = 4
	data.gold = 777
	data.profession_id = "ranger"
	_check(_service.write_slot(1, data), "写槽位 1 应成功")
	_check(_service.has_save(1), "写完后槽位 1 应存在")

	var summary: Dictionary = _service.slot_summary(1)
	_log.append("槽位 1 摘要 -> exists=%s lv=%d gold=%d prof=%s" % [
		summary.get("exists"), summary.get("level"), summary.get("gold"),
		summary.get("profession")])
	_check(bool(summary.get("exists", false)), "摘要应报告存在")
	_check(int(summary.get("level", 0)) == 4 and int(summary.get("gold", 0)) == 777,
		"摘要应带等级与金币")

	# 动态调用（_service 是 Variant），所以用无类型 `=` 而不是 `:=`
	var loaded = _service.load_slot(1)
	_check(loaded != null and loaded.level == 4 and loaded.gold == 777, "读回应与写入一致")
	_check(not FileAccess.file_exists((TEST_PATTERN % 1) + ".tmp"), "原子写不应留下 .tmp")

	_events.emit_signal("save_slots_requested")
	_log.append("save_slots_requested -> %d 个槽位摘要" % _slots.size())
	_check(_slots.size() == _service.SLOT_COUNT,
		"摘要应返回 %d 个槽位" % _service.SLOT_COUNT)

	_check(_service.delete_slot(1), "删除已有槽位应返回 true")
	_check(not _service.has_save(1), "删除后槽位应不存在")
	_check(not _service.delete_slot(1), "删除空槽位应返回 false")


## 坏档：不崩、改名备份、按无档处理。三种坏法各测一次：空文件 / 语法错 / 类型不对。
##
## ⚠️ 这里能放心塞「语法都不合法的 JSON」，是因为 `SaveService._parse_json_dict()` 用的是
## `JSON` 实例（失败只返回错误码），不是会往 stderr 打 `ERROR: Parse JSON failed` 的
## `JSON.parse_string()` —— 否则这条用例会把「0 ERROR」的验收口径搞脏。
func _case_corrupt_slot() -> void:
	var payloads: Array = [
		{"slot": 1, "text": "", "note": "空文件"},
		{"slot": 2, "text": "{ 这不是 JSON,,,", "note": "语法错"},
		{"slot": 3, "text": "[1, 2, 3]", "note": "类型不对"},
	]
	for entry in payloads:
		var slot := int(entry["slot"])
		var path := TEST_PATTERN % slot
		var file := FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "应能写入测试用的坏档文件")
		if file == null:
			return
		file.store_string(String(entry["text"]))
		file.close()

		var data = _service.load_slot(slot)
		_log.append("坏档槽位 %d（%s）-> load_slot=%s  原文件还在=%s  备份数=%d" % [
			slot, entry["note"], data, FileAccess.file_exists(path),
			_count_corrupt_backups(slot)])
		_check(data == null, "坏档应返回 null")
		_check(not FileAccess.file_exists(path), "坏档应被改名搬走（不静默覆盖）")
		_check(_count_corrupt_backups(slot) > 0, "应留下 .corrupt-* 备份")


## 标题选档界面：启动时打开且暂停世界；_rows 与槽位数一致。
func _case_title_screen() -> void:
	var title = _main.find_child("TitleScreen", true, false)
	_check(title != null, "主场景应存在 TitleScreen")
	if title == null:
		return
	_log.append("标题界面 -> visible=%s  paused=%s  modal_ui=%s  槽位行=%d" % [
		title.visible, paused, title.is_in_group("modal_ui"), title._rows.size()])
	_check(title.visible, "启动时标题界面应打开")
	_check(paused, "标题界面打开时世界应暂停")
	_check(title.is_in_group("modal_ui"), "标题界面应加入 modal_ui 组")
	_check(title._rows.size() == _service.SLOT_COUNT,
		"标题界面应有 %d 个槽位行" % _service.SLOT_COUNT)


## 一条龙：选新档 → 改状态 → 存 → 清空状态 → 读回 → 逐项一致。
func _case_full_roundtrip() -> void:
	_main.choose_slot(1, true)
	var title = _main.find_child("TitleScreen", true, false)
	_log.append("选新档后 -> title.visible=%s paused=%s current_slot=%d 槽位文件=%s" % [
		title.visible, paused, _service.current_slot, _service.has_save(1)])
	_check(not title.visible, "选档后标题界面应关闭")
	_check(not paused, "选档后世界应解冻")
	_check(_service.current_slot == 1, "当前槽位应为 1")
	_check(_service.has_save(1), "新档应立刻落盘（否则槽位还是空的）")

	# 造一份有辨识度的状态
	_game.add_gold(4321)
	_game.add_xp(10000)
	_check(_player.free_attribute_points() > 0, "升级后应有可分配点数")
	_player.allocate_attribute("strength", 2)
	_player.allocate_attribute("vitality", 1)
	_player.add_to_backpack(_make_gear(GearItem.Slot.RING, "存档戒指", 15.0))
	_player.receive_loot(_make_gear(GearItem.Slot.WEAPON, "存档长刀", 30.0))
	_events.emit_signal("backpack_equip_requested", 1)      # 背包下标 1 = 长刀

	var weapon: GearItem = _player.equipment.get(GearItem.Slot.WEAPON)
	var expected := {
		"level": _game.level,
		"gold": _game.gold,
		"strength": _player.attribute_points("strength"),
		"vitality": _player.attribute_points("vitality"),
		"profession": _player.profession_id(),
		"weapon": weapon.item_name if weapon != null else "",
		"bag": _player.backpack.size(),
		"hp": _player.hp,
		"kills": 0,
	}
	_check(_service.flush_current(), "手动写盘应成功")

	# 「重开游戏」：把进度与角色清空（不动存档），再读回来
	_game.reset_progress()
	_player.reset_state()
	_log.append("清空后 -> lv=%d gold=%d 力量=%d 武器=%s 背包=%d" % [
		_game.level, _game.gold, _player.attribute_points("strength"),
		str(_player.equipment.get(GearItem.Slot.WEAPON)), _player.backpack.size()])
	_check(_game.level == 1 and _game.gold == 0, "清空后进度应归零")
	_check(_player.attribute_points("strength") == 0, "清空后属性点应归零")
	_check(_player.backpack.is_empty(), "清空后背包应为空")

	_main.choose_slot(1, false)
	var loaded_weapon: GearItem = _player.equipment.get(GearItem.Slot.WEAPON)
	_log.append("读档后 -> lv=%d gold=%d 力量=%d 体力=%d 职业=%s 武器=%s 背包=%d hp=%.1f" % [
		_game.level, _game.gold, _player.attribute_points("strength"),
		_player.attribute_points("vitality"), _player.profession_id(),
		loaded_weapon.item_name if loaded_weapon != null else "空",
		_player.backpack.size(), _player.hp])
	_check(_game.level == int(expected["level"]), "等级应恢复")
	_check(_game.gold == int(expected["gold"]), "金币应恢复")
	_check(_player.attribute_points("strength") == int(expected["strength"]), "力量点数应恢复")
	_check(_player.attribute_points("vitality") == int(expected["vitality"]), "体力点数应恢复")
	_check(_player.profession_id() == String(expected["profession"]), "职业应恢复")
	_check(loaded_weapon != null and loaded_weapon.item_name == String(expected["weapon"]),
		"装备武器应恢复")
	_check(_player.backpack.size() == int(expected["bag"]), "背包件数应恢复")
	_check(is_equal_approx(_player.hp, float(expected["hp"])), "当前生命应恢复")


## 自动保存：状态变化后打待写标记，落盘后清掉。
func _case_autosave_flag() -> void:
	_check(_service.current_slot > 0, "此时应已选中槽位")
	_service.flush_current()
	_check(not _service.has_pending_write(), "刚写完不应有待写标记")

	_game.add_gold(1)
	_log.append("改金币后 has_pending_write=%s（防抖 %.1f 秒）" % [
		_service.has_pending_write(), _service.AUTOSAVE_DELAY])
	_check(_service.has_pending_write(), "状态变化后应标记待写（防抖）")
	_check(_service.flush_current(), "flush_current 应能落盘")
	_check(not _service.has_pending_write(), "落盘后待写标记应清掉")


# ---------------------------------------------------------------- 工具

func _make_gear(slot: int, item_name: String, attack: float) -> GearItem:
	var gear := GearItem.new()
	gear.slot = slot
	gear.rarity = GearItem.Rarity.RARE
	gear.item_level = 5
	gear.item_name = item_name
	gear.stats = {"attack": attack}
	return gear


## 清掉测试写出的槽位文件与坏档备份。
func _cleanup() -> void:
	if _service == null:
		return
	for slot in range(1, _service.SLOT_COUNT + 1):
		_service.delete_slot(slot)
	for file_name in _corrupt_backup_names():
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove(file_name)


func _corrupt_backup_names() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("user://")
	if dir == null:
		return out
	# 先收集再删：一边 list_dir 一边 remove 会把迭代器搞乱
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("test_save_") and file_name.contains(".corrupt-"):
			out.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


func _count_corrupt_backups(slot: int) -> int:
	var prefix := "test_save_%d.json.corrupt-" % slot
	var count := 0
	for file_name in _corrupt_backup_names():
		if file_name.begins_with(prefix):
			count += 1
	return count


func _first(group: String) -> Variant:
	# 先赋给无类型 Array，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var nodes: Array = get_nodes_in_group(group)
	return null if nodes.is_empty() else nodes[0]


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		_log.append("  FAIL: %s" % msg)


func _report() -> void:
	print("[save] 帧数 = ", _frame)
	for line in _log:
		print("     ", line)
	if _failed:
		print("========== 存档自测失败 ==========")
	else:
		print("========== 存档自测通过 ==========")
