class_name LootConfig
extends RefCounted
## 掉落表配置。从 data/loot.json 加载，集中所有可调参数。
##
## 改掉落/词条/名字池 = 改 JSON，不必改代码。
## 加新品质/部位 = 在 enum 加值，并在 JSON 中补 key/value。

const _DEFAULT_PATH := "res://data/loot.json"

static var _cached: LootConfig = null

# ---------- 加载 ----------

static func load_default() -> LootConfig:
	if _cached != null:
		return _cached
	_cached = load_from_path(_DEFAULT_PATH)
	return _cached


static func load_from_path(path: String) -> LootConfig:
	if not FileAccess.file_exists(path):
		push_error("LootConfig: 找不到 %s" % path)
		return null
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("LootConfig: %s 解析失败（非字典）" % path)
		return null
	return _from_dict(parsed)


# ---------- 字段 ----------

var drop_chance: float = 0.55
var level_jitter: int = 1
## {slot_key(String): weight(float)}，相对权重
var slot_weights: Dictionary = {}
## {rarity_key(String): weight(float)}，相对权重
var rarity_weights: Dictionary = {}
## {slot_key(String): [name, ...]}
var name_pools: Dictionary = {}
## {slot_key(String): {"primary": {...}, "secondary": {...}}}
var stat_specs: Dictionary = {}


# ---------- 构造 ----------

static func _from_dict(d: Dictionary) -> LootConfig:
	var c := LootConfig.new()
	c.drop_chance = float(d.get("drop_chance", 0.55))
	c.level_jitter = int(d.get("level_jitter", 1))
	c.slot_weights = d.get("slot_weights", {})
	c.rarity_weights = d.get("rarity_weights", {})
	c.name_pools = d.get("name_pools", {})
	c.stat_specs = d.get("stat_specs", {})
	return c


# ---------- 枚举映射 ----------
#
# 映射本体在 GearItem（SLOT_KEYS / RARITY_KEYS），这里只做转发：
# 存档（M13）也要用同一份键，两份映射各写一遍必然漂移。

func slot_enum_for(key: String) -> int:
	return GearItem.slot_from_key(key)


func rarity_enum_for(key: String) -> int:
	return GearItem.rarity_from_key(key)


func slot_key_for(e: int) -> String:
	return GearItem.slot_key(e)


func rarity_key_for(e: int) -> String:
	return GearItem.rarity_key(e)


# ---------- 加权抽取 ----------

func pick_slot_key() -> String:
	return _weighted_pick(slot_weights, "weapon")


func pick_rarity_key() -> String:
	return _weighted_pick(rarity_weights, "common")


static func _weighted_pick(weights: Dictionary, fallback: String) -> String:
	if weights.is_empty():
		return fallback
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	if total <= 0.0:
		return fallback
	var roll := randf() * total
	var acc := 0.0
	for k in weights:
		acc += float(weights[k])
		if roll <= acc:
			return String(k)
	return String(weights.keys().back())
