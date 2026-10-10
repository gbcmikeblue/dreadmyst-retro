class_name Shop
extends Node
## 商店服务：按 data/shop.json 的货架定义现生成商品，处理购买与刷新。
##
## 为什么不做成 Autoload：它只在游戏里被 main.gd 挂一次，没有跨场景的全局状态需求；
## 但也不是「世界里的物件」（没有位置），所以放 core/ 而不是 world/。
##
## 与外界只走 Events：
##   - UI 打开商店页 → `shop_stock_requested` → 本节点回 `shop_stock_changed`
##   - UI 买 / 刷新 → `shop_buy_requested` / `shop_restock_requested`
##   - 买到的装备通过 `backpack_add_requested` 交给 Player（本节点不碰背包）
##
## 金币由 `Game` 统一记账（读取 `Game.gold`，扣钱走 `Game.add_gold(-n)`）。

## 货架：Array[Dictionary]，元素 {gear: GearItem, price: int, slot_key: String}
var stock: Array = []

var _config: ShopConfig = null
## 背包占用（跟着 `backpack_changed` 更新）。Shop 不引用 Player，
## 买卖前靠这份缓存判断「放不放得下」，避免扣了钱东西却进不了包。
var _bag_size: int = 0
var _bag_capacity: int = 0


func _ready() -> void:
	name = "Shop"
	_config = ShopConfig.load_default()
	roll_stock()
	Events.shop_stock_requested.connect(_on_stock_requested)
	Events.shop_restock_requested.connect(_on_restock_requested)
	Events.shop_buy_requested.connect(_on_buy_requested)
	Events.backpack_changed.connect(_on_backpack_changed)


func _on_backpack_changed(items: Array, capacity: int) -> void:
	_bag_size = items.size()
	_bag_capacity = capacity


func restock_cost() -> int:
	return _config.restock_cost if _config != null else 0


## 重新生成整个货架（名字与词条都是新的）。
func roll_stock() -> void:
	stock.clear()
	if _config == null:
		_config = ShopConfig.load_default()
	for i in range(_config.offers.size()):
		var entry := _make_entry(i)
		if not entry.is_empty():
			stock.append(entry)
	_emit_stock()


## 按第 offer_index 条货架定义生成一件商品（含价格与货架下标）。
func _make_entry(offer_index: int) -> Dictionary:
	if offer_index < 0 or offer_index >= _config.offers.size():
		return {}
	var offer: Dictionary = _config.offers[offer_index]
	# 部位/品质都交给数据层指定，名字池与词条才会跟着部位走
	var gear := LootTable.generate(
		int(offer["item_level"]), String(offer["rarity_key"]), String(offer["slot_key"]))
	if gear == null:
		return {}
	return {
		"gear": gear,
		"price": int(offer["price"]),
		"slot_key": String(offer["slot_key"]),
		"offer_index": offer_index,
	}


## 购买第 index 件。背包已满 / 金币不足返回 false（并 Toast 提示），不改动任何状态。
func buy(index: int) -> bool:
	if index < 0 or index >= stock.size():
		return false
	var entry: Dictionary = stock[index]
	var price := int(entry["price"])
	if _bag_capacity > 0 and _bag_size >= _bag_capacity:
		Events.toast.emit("背包已满，先分解或装备再购买", Color(1.0, 0.72, 0.35))
		return false
	if Game.gold < price:
		Events.toast.emit("金币不足：需要 %d" % price, Color(1.0, 0.72, 0.35))
		return false
	Game.add_gold(-price)
	Events.backpack_add_requested.emit(entry["gear"])
	# 卖掉的那一格立刻补一件同款（同部位/品质/等级，词条重新随）
	_refresh_entry(index)
	return true


## 花金币刷新整个货架。金币不足返回 false。
func restock() -> bool:
	var cost := restock_cost()
	if Game.gold < cost:
		Events.toast.emit("刷新货架需要 %d 金币" % cost, Color(1.0, 0.72, 0.35))
		return false
	Game.add_gold(-cost)
	roll_stock()
	Events.toast.emit("货架已刷新（-%d 金币）" % cost, Color(0.80, 0.90, 1.0))
	return true


## 单格补货：保持 部位/品质/等级/价格 不变，只换一件新的（随机的名字与词条）。
func _refresh_entry(index: int) -> void:
	if index < 0 or index >= stock.size():
		return
	var offer_index := int(stock[index].get("offer_index", index))
	var entry := _make_entry(offer_index)
	if entry.is_empty():
		stock.remove_at(index)
	else:
		stock[index] = entry
	_emit_stock()


func _on_stock_requested() -> void:
	_emit_stock()


func _on_restock_requested() -> void:
	restock()


func _on_buy_requested(offer_index: int) -> void:
	buy(offer_index)


func _emit_stock() -> void:
	Events.shop_stock_changed.emit(stock.duplicate())
