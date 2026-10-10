class_name SaveData
extends RefCounted
## 一份存档的纯数据结构 + 校验兜底。**不做文件 IO**（IO 在 `SaveService`）。
##
## ⚠️ 存档是**外部输入**：可能被手改、可能来自旧版本。所以 `from_dict()` 全程只做
## 「尽力还原 + 兜底」，不 `push_error`、不抛异常。语义层面的兜底（未知职业 id、
## 未知属性 id）在 `Player.import_state()` 里处理；结构层面的兜底（非法枚举、
## 未知词条键、背包超容量）在这里。
##
## 存档形状（`user://save_<槽>.json`）：
## ```json
## { "version": 1, "saved_at": "...", "kills": 12,
##   "game":   { "level": 5, "xp": 120, "gold": 800 },
##   "player": { "profession": "mage", "hp": 95.0, "mana": 140.0,
##               "attributes": { "strength": 12 },
##               "equipment": { "weapon": { ...GearItem.to_dict()... } },
##               "backpack":  [ { ... } ] } }
## ```

## 当前存档版本。改结构时 +1，并在 `SaveService` 的 `_migrate()` 里补迁移。
const CURRENT_VERSION := 1

var version: int = CURRENT_VERSION
var saved_at: String = ""
## HUD 击杀数（顺手存，只用于显示）
var kills: int = 0

# --- 进度（归属 Game）---
var level: int = 1
var xp: int = 0
var gold: int = 0

# --- 角色（归属 Player）---
var profession_id: String = ""
## 当前生命 / 法力。**< 0 表示存档里没写** → 载入时按满值处理。
var hp: float = -1.0
var mana: float = -1.0
## {属性 id: 已投入点数}
var attributes: Dictionary = {}
## {部位 key(String): GearItem}
var equipment: Dictionary = {}
## Array[GearItem]
var backpack: Array = []
## 载入时因背包超容量被丢掉的件数（> 0 时由调用方 Toast 提示）
var dropped_backpack_items: int = 0


# ---------------------------------------------------------------- 写出

func to_dict() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"saved_at": saved_at,
		"kills": kills,
		"game": {
			"level": level,
			"xp": xp,
			"gold": gold,
		},
		"player": {
			"profession": profession_id,
			"hp": hp,
			"mana": mana,
			"attributes": attributes.duplicate(),
			"equipment": equipment_to_dict(equipment),
			"backpack": backpack_to_list(backpack),
		},
	}


# ---------------------------------------------------------------- 读入

static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	s.version = int(d.get("version", CURRENT_VERSION))
	s.saved_at = String(d.get("saved_at", ""))
	s.kills = maxi(0, int(d.get("kills", 0)))

	var game: Variant = d.get("game", {})
	if typeof(game) == TYPE_DICTIONARY:
		var g: Dictionary = game
		s.level = maxi(1, int(g.get("level", 1)))
		s.xp = maxi(0, int(g.get("xp", 0)))
		s.gold = maxi(0, int(g.get("gold", 0)))

	var player: Variant = d.get("player", {})
	if typeof(player) != TYPE_DICTIONARY:
		return s
	var p: Dictionary = player
	s.profession_id = String(p.get("profession", ""))
	s.hp = float(p.get("hp", -1.0))
	s.mana = float(p.get("mana", -1.0))

	var raw_attrs: Variant = p.get("attributes", {})
	if typeof(raw_attrs) == TYPE_DICTIONARY:
		var attrs: Dictionary = raw_attrs
		for key in attrs:
			var v: Variant = attrs[key]
			if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
				s.attributes[String(key)] = maxi(0, int(v))

	s.equipment = equipment_from_dict(p.get("equipment", {}))

	var bag: Dictionary = _load_backpack(
		p.get("backpack", []), InventoryConfig.load_default().backpack_capacity)
	s.backpack = bag["items"]
	s.dropped_backpack_items = int(bag["dropped"])
	return s


## 版本是否受支持。不支持时由 `SaveService` 走「备份旧档 + 新建」。
func is_supported_version() -> bool:
	return version == CURRENT_VERSION


## 只取「槽位摘要」用的几个字段（标题选档界面用，不必还原整份存档）。
static func summary_from_dict(d: Dictionary, exists: bool) -> Dictionary:
	var level := 1
	var gold := 0
	var profession := ""
	var game: Variant = d.get("game", {})
	if typeof(game) == TYPE_DICTIONARY:
		var g: Dictionary = game
		level = maxi(1, int(g.get("level", 1)))
		gold = maxi(0, int(g.get("gold", 0)))
	var player: Variant = d.get("player", {})
	if typeof(player) == TYPE_DICTIONARY:
		var p: Dictionary = player
		profession = String(p.get("profession", ""))
	return {
		"exists": exists,
		"saved_at": String(d.get("saved_at", "")),
		"level": level,
		"gold": gold,
		"profession": profession,
		"version": int(d.get("version", 0)),
	}


# ---------------------------------------------------------------- 装备 / 背包转换

## Player.equipment（{slot 枚举: GearItem}）-> 存档形状（{部位 key: Dictionary}）。
static func equipment_to_dict(equipment: Dictionary) -> Dictionary:
	var out := {}
	for slot in equipment:
		var gear: GearItem = equipment[slot]
		if gear == null:
			continue
		out[GearItem.slot_key(int(slot))] = gear.to_dict()
	return out


## 存档形状 -> {slot 枚举: GearItem}。非法项跳过（不报错）。
static func equipment_from_dict(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw
	for key in d:
		var entry: Variant = d[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		out[GearItem.slot_from_key(String(key))] = GearItem.from_dict(entry)
	return out


static func backpack_to_list(backpack: Array) -> Array:
	var out: Array = []
	for gear in backpack:
		if gear is GearItem:
			out.append(gear.to_dict())
	return out


## 把存档里的背包还原成 Array[GearItem]，**超出容量的部分丢弃并计数**。
static func _load_backpack(raw: Variant, capacity: int) -> Dictionary:
	var items: Array = []
	var dropped := 0
	if raw is Array:
		var list: Array = raw
		for entry in list:
			if not (entry is Dictionary):
				continue
			if capacity > 0 and items.size() >= capacity:
				dropped += 1
				continue
			items.append(GearItem.from_dict(entry))
	return {"items": items, "dropped": dropped}
