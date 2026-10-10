class_name ShopConfig
extends RefCounted
## 商店货架配置：刷新价 + 货架条目。纯数据、不含表现。
##
## 数据来自 data/shop.json。每条 offer 在生成货架时用 `LootTable` 现生成一件装备
## （名字与词条随机），所以商店卖的是「同款不同货」，不需要在 JSON 里写死具体装备。
## ⚠️ 价格与等级为自行设计的占位值，待原作资料校准。

const _DEFAULT_PATH := "res://data/shop.json"

static var _cached: ShopConfig = null

var restock_cost: int = 25
## Array[Dictionary]：{slot: int(GearItem.Slot), rarity: int(GearItem.Rarity),
##                     item_level: int, price: int}
var offers: Array = []


static func load_default() -> ShopConfig:
	if _cached != null:
		return _cached
	if not FileAccess.file_exists(_DEFAULT_PATH):
		push_error("ShopConfig: 找不到 %s" % _DEFAULT_PATH)
		_cached = ShopConfig.new()
		return _cached
	var raw := FileAccess.get_file_as_string(_DEFAULT_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ShopConfig: %s 解析失败（非字典）" % _DEFAULT_PATH)
		_cached = ShopConfig.new()
		return _cached
	_cached = from_dict(parsed)
	return _cached


static func from_dict(d: Dictionary) -> ShopConfig:
	var c := ShopConfig.new()
	c.restock_cost = maxi(0, int(d.get("restock_cost", 25)))
	var raw_offers: Array = d.get("offers", [])
	for entry in raw_offers:
		if not (entry is Dictionary):
			continue
		var offer: Dictionary = entry
		var price := maxi(1, int(offer.get("price", 50)))
		var item_level := maxi(1, int(offer.get("item_level", 1)))
		var slot_key := String(offer.get("slot", "weapon"))
		var rarity_key := String(offer.get("rarity", "common"))
		c.offers.append({
			"slot": _slot_enum(slot_key),
			"slot_key": slot_key,
			"rarity": _rarity_enum(rarity_key),
			"rarity_key": rarity_key,
			"item_level": item_level,
			"price": price,
		})
	return c


## 部位 / 品质的中文 key -> 枚举。复用 LootConfig 的映射，避免两处各写一份。
static func _slot_enum(key: String) -> int:
	var cfg := LootConfig.load_default()
	if cfg == null:
		return GearItem.Slot.WEAPON
	return cfg.slot_enum_for(key)


static func _rarity_enum(key: String) -> int:
	var cfg := LootConfig.load_default()
	if cfg == null:
		return GearItem.Rarity.COMMON
	return cfg.rarity_enum_for(key)


## 供测试 / 热重载使用。
static func clear_cache() -> void:
	_cached = null
