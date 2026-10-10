class_name InventoryConfig
extends RefCounted
## 背包配置：容量 + 分解（卖出）价公式。纯数据、纯计算。
##
## 数据来自 data/inventory.json。**卖出价公式放在数据层**，
## 这样 Player（真正加金币）与背包界面（显示「分解 +N 金币」）用的是同一份口径，
## 不会出现「界面显示 12、实际只给 10」这类漂移。
## ⚠️ 数值为自行设计的占位值，待原作资料校准。

const _DEFAULT_PATH := "res://data/inventory.json"

static var _cached: InventoryConfig = null

var backpack_capacity: int = 24
var sell_price_per_power: float = 0.25
var sell_price_per_level: int = 2
var min_sell_price: int = 1

## 兜底容量：JSON 读不到时也不能让背包变成 0 格
const FALLBACK_CAPACITY := 24


static func load_default() -> InventoryConfig:
	if _cached != null:
		return _cached
	if not FileAccess.file_exists(_DEFAULT_PATH):
		push_error("InventoryConfig: 找不到 %s" % _DEFAULT_PATH)
		_cached = InventoryConfig.new()
		return _cached
	var raw := FileAccess.get_file_as_string(_DEFAULT_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("InventoryConfig: %s 解析失败（非字典）" % _DEFAULT_PATH)
		_cached = InventoryConfig.new()
		return _cached
	_cached = from_dict(parsed)
	return _cached


static func from_dict(d: Dictionary) -> InventoryConfig:
	var c := InventoryConfig.new()
	c.backpack_capacity = maxi(1, int(d.get("backpack_capacity", FALLBACK_CAPACITY)))
	c.sell_price_per_power = maxf(0.0, float(d.get("sell_price_per_power", 0.25)))
	c.sell_price_per_level = maxi(0, int(d.get("sell_price_per_level", 2)))
	c.min_sell_price = maxi(0, int(d.get("min_sell_price", 1)))
	return c


## 一件装备分解（卖出）能换多少金币。
func sell_price_for(gear: GearItem) -> int:
	if gear == null:
		return 0
	var value := gear.power_score() * sell_price_per_power
	value += float(gear.item_level * sell_price_per_level)
	return maxi(min_sell_price, int(round(value)))


## 供测试 / 热重载使用。
static func clear_cache() -> void:
	_cached = null
