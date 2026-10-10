extends SceneTree
## M11 背包 / 商店 / 装备对比自测：真正实例化主场景，验证入包 / 装备 / 分解 / 容量 / 一键换装 / 买卖。
##
##   godot --headless --path . --script res://tests/test_inventory.gd
##
## 设计要点：
##   - 所有用例在**同一个 process_frame 回调内同步跑完**（敌人不插帧，结果确定）。
##   - 装备用**手工构造**的 `GearItem`（词条写死）而不是随机生成，断言才能精确到数值；
##     随机生成的正确性（指定部位/品质）另用 LootTable 单独验一条。
##
## ⚠️ 本脚本是 --script 入口，编译早于 autoload 注册，不能直接写 Events / Game
##    （会 Identifier not found）。这里用 root.get_node_or_null("Events"/"Game") 动态取，
##    并把 _main / _events / _game 都声明成 Variant 以免静态类型分析卡住动态属性访问。

var _main: Variant = null
var _events: Variant = null
var _game: Variant = null
var _player = null
var _failed: bool = false
var _frame: int = 0
var _log: Array[String] = []
## 最近一次 backpack_changed 的内容（验证信号有没有真的发出来）
var _last_bag_size: int = -1
var _last_bag_capacity: int = -1


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
	if _player == null or _events == null or _game == null:
		print("FAIL: 缺少玩家 / Events / Game")
		quit(1)
		return
	_events.backpack_changed.connect(_on_backpack_changed)
	_run()
	_report()
	quit(1 if _failed else 0)


func _on_backpack_changed(items: Array, capacity: int) -> void:
	_last_bag_size = items.size()
	_last_bag_capacity = capacity


# ---------------------------------------------------------------- 用例

func _run() -> void:
	_case_config()
	_case_loot_goes_to_bag()
	_case_equip_and_swap()
	_case_sell()
	_case_capacity_and_auto_sell()
	_case_optimize()
	_case_shop()
	_case_panel()


## 数据层：容量、卖出价、商店配置、LootTable 支持指定部位/品质。
func _case_config() -> void:
	var cfg := InventoryConfig.load_default()
	_check(cfg.backpack_capacity > 0, "背包容量应 > 0")
	_check(_player.backpack_capacity() == cfg.backpack_capacity,
		"Player 的容量应与 data/inventory.json 一致")

	var weapon := _make_gear(GearItem.Slot.WEAPON, "测试剑", {"attack": 10})
	var price: int = _player.sell_price(weapon)
	_check(price >= cfg.min_sell_price, "卖出价不应低于 min_sell_price")
	_check(price == cfg.sell_price_for(weapon), "Player 与界面应共用同一份卖出价公式")

	var shop_cfg := ShopConfig.load_default()
	_check(not shop_cfg.offers.is_empty(), "商店货架不应为空")
	_log.append("配置：容量 %d，卖出价(测试剑) %d，货架 %d 条，刷新价 %d" % [
		cfg.backpack_capacity, price, shop_cfg.offers.size(), shop_cfg.restock_cost])

	# LootTable 指定部位/品质：名字池与词条都要跟着部位走，所以必须在生成时就指定
	var forced := LootTable.generate(3, "rare", "boots")
	_check(forced != null and forced.slot == GearItem.Slot.BOOTS,
		"generate(3, 'rare', 'boots') 应产出战靴")
	_check(forced != null and forced.rarity == GearItem.Rarity.RARE,
		"generate(3, 'rare', 'boots') 应产出稀有品质")


## 掉落改入背包：不再自动穿/自动分解。
func _case_loot_goes_to_bag() -> void:
	var attack_before: float = float(_player.total_stats().get("attack", 0.0))
	var weak := _make_gear(GearItem.Slot.WEAPON, "钝剑", {"attack": 5})
	_player.receive_loot(weak)
	var attack_after: float = float(_player.total_stats().get("attack", 0.0))
	_log.append("拾取 钝剑 -> 背包 %d 件（信号报告 %d 件 / 容量 %d），攻击 %.1f -> %.1f" % [
		_player.backpack.size(), _last_bag_size, _last_bag_capacity, attack_before, attack_after])
	_check(_player.backpack.size() == 1, "掉落应进入背包")
	_check(_last_bag_size == 1 and _last_bag_capacity == _player.backpack_capacity(),
		"应广播 backpack_changed（物品数 + 容量）")
	_check(is_equal_approx(attack_before, attack_after),
		"掉落入包不应改变属性（M11 起不再自动装备）")


## 装备 / 换装：换下来的旧装备回到背包，不凭空消失。
func _case_equip_and_swap() -> void:
	var attack_base: float = float(_player.total_stats().get("attack", 0.0))
	_events.emit_signal("backpack_equip_requested", 0)
	var equipped: GearItem = _player.equipment.get(GearItem.Slot.WEAPON)
	var attack_after: float = float(_player.total_stats().get("attack", 0.0))
	_log.append("装备背包[0] -> 武器=%s，背包 %d 件，攻击 %.1f -> %.1f" % [
		equipped.item_name if equipped != null else "空", _player.backpack.size(),
		attack_base, attack_after])
	_check(equipped != null and equipped.item_name == "钝剑", "应装备上背包里的钝剑")
	_check(_player.backpack.is_empty(), "装备后该件应从背包移除")
	_check(is_equal_approx(attack_after - attack_base, 5.0), "装备应立刻计入总属性（+5 攻击）")

	# 再拾取一件更强的武器并换上：旧武器必须回到背包
	var strong := _make_gear(GearItem.Slot.WEAPON, "利刃", {"attack": 30})
	_player.receive_loot(strong)
	_events.emit_signal("backpack_equip_requested", 0)
	var now: GearItem = _player.equipment.get(GearItem.Slot.WEAPON)
	_log.append("换上 利刃 -> 武器=%s，背包 %d 件（旧武器应回到背包）" % [
		now.item_name if now != null else "空", _player.backpack.size()])
	_check(now != null and now.item_name == "利刃", "应换上利刃")
	_check(_player.backpack.size() == 1, "换下来的旧武器应回到背包")
	if _player.backpack.size() == 1:
		_check(_player.backpack[0].item_name == "钝剑", "背包里应是换下来的钝剑")


## 分解：背包减一、金币增加卖出价。
func _case_sell() -> void:
	var item: GearItem = _player.backpack[0]
	var expect: int = _player.sell_price(item)
	var gold_before: int = _game.gold
	var size_before: int = _player.backpack.size()
	_events.emit_signal("backpack_sell_requested", 0)
	_log.append("分解 %s -> 金币 %d -> %d（应 +%d），背包 %d -> %d" % [
		item.item_name, gold_before, _game.gold, expect, size_before, _player.backpack.size()])
	_check(_player.backpack.size() == size_before - 1, "分解后背包应少一件")
	_check(_game.gold - gold_before == expect, "分解应正好增加 %d 金币" % expect)


## 容量上限：满了以后掉落自动分解（不凭空消失），也不再广播背包变化。
func _case_capacity_and_auto_sell() -> void:
	var filler := _make_gear(GearItem.Slot.ARMOR, "填充皮甲", {"armor": 1})
	for i in range(_player.backpack_capacity() + 5):
		if _player.backpack_full():
			break
		_player.add_to_backpack(filler)
	_log.append("塞满背包：%d / %d，full=%s" % [
		_player.backpack.size(), _player.backpack_capacity(), _player.backpack_full()])
	_check(_player.backpack_full(), "背包应已满")
	_check(_player.backpack.size() == _player.backpack_capacity(), "背包不应超过容量")

	var extra := _make_gear(GearItem.Slot.RING, "溢出的戒指", {"crit": 0.02})
	var gold_before: int = _game.gold
	var size_before: int = _player.backpack.size()
	_player.receive_loot(extra)
	_log.append("满包时拾取 溢出的戒指 -> 背包 %d -> %d，金币 %d -> %d（自动分解）" % [
		size_before, _player.backpack.size(), gold_before, _game.gold])
	_check(_player.backpack.size() == size_before, "满包后不应再入包")
	_check(_game.gold > gold_before, "满包时拾取应自动分解换金币（掉落不凭空消失）")


## 一键换装：空位会被填上；已经不比身上强就不再换。
func _case_optimize() -> void:
	var changed: int = _player.optimize_equipment()
	var armor: GearItem = _player.equipment.get(GearItem.Slot.ARMOR)
	_log.append("一键换装 -> 换了 %d 件，护甲部位=%s" % [
		changed, armor.item_name if armor != null else "空"])
	_check(changed >= 1, "空着的部位应被一键换装填上")
	_check(armor != null, "护甲部位应有装备")
	var again: int = _player.optimize_equipment()
	_log.append("再点一次一键换装 -> 换了 %d 件（期望 0，因为已不比身上强）" % again)
	_check(again == 0, "已经不比身上强时不应再换")


## 商店：拉货架 / 背包满时拒买 / 金币不足拒买 / 买入扣钱入包 / 刷新扣钱。
func _case_shop() -> void:
	var shop = _main.shop
	_check(shop != null, "主场景应有 Shop 节点")
	if shop == null:
		return
	_events.emit_signal("shop_stock_requested")
	var offers_count: int = ShopConfig.load_default().offers.size()
	_check(shop.stock.size() == offers_count, "货架应有 %d 条商品" % offers_count)

	# 先把背包塞满，**并且给足金币**：这样才能确认拒买的原因是「背包满」而不是「钱不够」
	var filler := _make_gear(GearItem.Slot.ARMOR, "商店填充甲", {"armor": 1})
	for i in range(_player.backpack_capacity() + 5):
		if _player.backpack_full():
			break
		_player.add_to_backpack(filler)
	_game.add_gold(2000)
	_check(_player.backpack_full(), "购买用例前应把背包塞满")

	var gold_before: int = _game.gold
	var bought_full: bool = shop.buy(0)
	_log.append("满包时购买（金币充足 %d）-> %s（期望 false），金币 %d" % [
		gold_before, bought_full, _game.gold])
	_check(not bought_full, "背包满时购买应被拒绝")
	_check(_game.gold == gold_before, "被拒绝时不应扣钱")

	# 腾出一格 -> 应当能买到
	_events.emit_signal("backpack_sell_requested", 0)
	var price: int = int(shop.stock[0]["price"])
	var gold_before_buy: int = _game.gold
	var size_before: int = _player.backpack.size()
	var bought: bool = shop.buy(0)
	_log.append("正常购买 -> %s，金币 %d -> %d（应 -%d），背包 %d -> %d，新货价格 %d" % [
		bought, gold_before_buy, _game.gold, price, size_before, _player.backpack.size(),
		int(shop.stock[0]["price"])])
	_check(bought, "有空间且金币足够时应能购买")
	_check(gold_before_buy - _game.gold == price, "购买应扣除 %d 金币" % price)
	_check(_player.backpack.size() == size_before + 1, "买到的装备应进背包")
	_check(int(shop.stock[0]["price"]) == price, "买走后该格应补上同款（价格不变）")

	var restock_cost: int = shop.restock_cost()
	var gold_before_restock: int = _game.gold
	var restocked: bool = shop.restock()
	_log.append("刷新货架 -> %s，金币 %d -> %d（应 -%d）" % [
		restocked, gold_before_restock, _game.gold, restock_cost])
	_check(restocked, "金币足够时应能刷新货架")
	_check(gold_before_restock - _game.gold == restock_cost, "刷新应扣 %d 金币" % restock_cost)


## 界面：默认关闭、可开关、开关时同步 modal_ui 组。
func _case_panel() -> void:
	_check(InputMap.has_action("inventory"), "应注册 inventory 输入动作（I / B）")
	var panel = _main.find_child("InventoryPanel", true, false)
	_check(panel != null, "主场景应存在 InventoryPanel 背包界面")
	if panel == null:
		return
	_check(not panel.visible, "背包界面默认应关闭")
	panel.toggle()
	_check(panel.visible and panel.is_in_group("modal_ui"),
		"打开后应可见并加入 modal_ui 组（Player 据此冻结操作）")
	panel.toggle()
	_check(not panel.visible and not panel.is_in_group("modal_ui"),
		"关闭后应不可见并退出 modal_ui 组")


# ---------------------------------------------------------------- 工具

## 手工构造装备：词条写死，断言才能精确到数值。
func _make_gear(slot: int, item_name: String, stats: Dictionary) -> GearItem:
	var gear := GearItem.new()
	gear.slot = slot
	gear.rarity = GearItem.Rarity.RARE
	gear.item_level = 5
	gear.item_name = item_name
	gear.stats = stats
	return gear


func _first(group: String) -> Variant:
	# 先赋给无类型 Array，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var nodes: Array = get_nodes_in_group(group)
	return null if nodes.is_empty() else nodes[0]


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		_log.append("  FAIL: %s" % msg)


func _report() -> void:
	print("[inventory] 帧数 = ", _frame)
	for line in _log:
		print("     ", line)
	if _failed:
		print("========== 背包自测失败 ==========")
	else:
		print("========== 背包自测通过 ==========")
