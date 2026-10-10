class_name GearItem
extends Resource
## 一件装备的数据模型（纯数据，不含表现）。
##
## 对应 Dreadmyst 的「暗黑式掉装」：装备有部位、品质、物品等级和随机词条。

enum Slot { WEAPON, HELMET, ARMOR, BOOTS, RING }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const SLOT_NAMES := {
	Slot.WEAPON: "武器",
	Slot.HELMET: "头盔",
	Slot.ARMOR: "护甲",
	Slot.BOOTS: "战靴",
	Slot.RING: "戒指",
}

const RARITY_NAMES := {
	Rarity.COMMON: "普通",
	Rarity.UNCOMMON: "优秀",
	Rarity.RARE: "稀有",
	Rarity.EPIC: "史诗",
	Rarity.LEGENDARY: "传说",
}

const RARITY_COLORS := {
	Rarity.COMMON: Color(0.80, 0.80, 0.80),
	Rarity.UNCOMMON: Color(0.35, 0.90, 0.35),
	Rarity.RARE: Color(0.35, 0.62, 1.00),
	Rarity.EPIC: Color(0.76, 0.42, 1.00),
	Rarity.LEGENDARY: Color(1.00, 0.62, 0.12),
}

## 品质对词条数值的放大倍率
const RARITY_MULT := {
	Rarity.COMMON: 1.0,
	Rarity.UNCOMMON: 1.6,
	Rarity.RARE: 2.4,
	Rarity.EPIC: 3.4,
	Rarity.LEGENDARY: 4.8,
}

const STAT_NAMES := {
	"attack": "攻击力",
	"max_hp": "生命上限",
	"armor": "护甲",
	"crit": "暴击率",
	"speed": "移动速度",
}

## 排序用的部位顺序（HUD 装备栏展示顺序）
const SLOT_ORDER := [Slot.WEAPON, Slot.HELMET, Slot.ARMOR, Slot.BOOTS, Slot.RING]

## 枚举 <-> 可读键。**这里是唯一一份**：`LootConfig`（loot.json 的 slot_weights /
## rarity_weights 键）与存档（M13）都转发到这两个方法，避免各写一份映射漂移。
const SLOT_KEYS := {
	Slot.WEAPON: "weapon",
	Slot.HELMET: "helmet",
	Slot.ARMOR: "armor",
	Slot.BOOTS: "boots",
	Slot.RING: "ring",
}
const RARITY_KEYS := {
	Rarity.COMMON: "common",
	Rarity.UNCOMMON: "uncommon",
	Rarity.RARE: "rare",
	Rarity.EPIC: "epic",
	Rarity.LEGENDARY: "legendary",
}

var item_name: String = "未知装备"
var slot: int = Slot.WEAPON
var rarity: int = Rarity.COMMON
var item_level: int = 1
## 键为 STAT_NAMES 中的字符串，值为数值（crit 为 0~1 的小数）
var stats: Dictionary = {}


func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func rarity_name() -> String:
	return RARITY_NAMES.get(rarity, "未知")


func slot_name() -> String:
	return SLOT_NAMES.get(slot, "未知")


## 用于比较两件装备好坏的粗略评分（同部位比较）。
func power_score() -> float:
	var score := 0.0
	score += float(stats.get("attack", 0)) * 2.0
	score += float(stats.get("max_hp", 0)) * 0.15
	score += float(stats.get("armor", 0)) * 1.5
	score += float(stats.get("crit", 0.0)) * 200.0
	score += float(stats.get("speed", 0)) * 0.5
	return score


# ---------------------------------------------------------------- 序列化（M13 存档）

## 转成可 JSON 化的字典。slot / rarity 存**整数枚举**，键名保持可读。
func to_dict() -> Dictionary:
	var stats_out := {}
	for key in stats:
		var v: Variant = stats[key]
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			stats_out[String(key)] = float(v)
	return {
		"name": item_name,
		"slot": slot,
		"rarity": rarity,
		"item_level": item_level,
		"stats": stats_out,
	}


## 从存档字典还原。**存档是外部输入，一律走兜底、不 push_error**：
## 未知 slot / rarity 钳到合法枚举，未知词条键丢弃，非法数值忽略。
static func from_dict(d: Dictionary) -> GearItem:
	var gear := GearItem.new()
	gear.item_name = String(d.get("name", "未知装备"))
	gear.slot = clampi(int(d.get("slot", Slot.WEAPON)), 0, SLOT_KEYS.size() - 1)
	gear.rarity = clampi(int(d.get("rarity", Rarity.COMMON)), 0, RARITY_KEYS.size() - 1)
	gear.item_level = maxi(1, int(d.get("item_level", 1)))
	var raw: Variant = d.get("stats", {})
	if typeof(raw) == TYPE_DICTIONARY:
		var stats_in: Dictionary = raw
		for key in stats_in:
			var stat_key := String(key)
			# 只收 STAT_NAMES 里认识的词条，避免存档里塞进杂物污染 total_stats
			if not STAT_NAMES.has(stat_key):
				continue
			var v: Variant = stats_in[key]
			if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
				gear.stats[stat_key] = maxf(0.0, float(v))
	return gear


# ---------------------------------------------------------------- 枚举 <-> 键

static func slot_key(slot_enum: int) -> String:
	return String(SLOT_KEYS.get(slot_enum, "weapon"))


static func slot_from_key(key: String) -> int:
	for slot_enum in SLOT_KEYS:
		if String(SLOT_KEYS[slot_enum]) == key:
			return slot_enum
	return Slot.WEAPON


static func rarity_key(rarity_enum: int) -> String:
	return String(RARITY_KEYS.get(rarity_enum, "common"))


static func rarity_from_key(key: String) -> int:
	for rarity_enum in RARITY_KEYS:
		if String(RARITY_KEYS[rarity_enum]) == key:
			return rarity_enum
	return Rarity.COMMON


## 多行描述文本（可用于 tooltip / 控制台输出）。
func tooltip() -> String:
	var lines: Array[String] = [
		"[%s] %s（%s · %d 级）" % [rarity_name(), item_name, slot_name(), item_level]
	]
	for key in stats:
		var value = stats[key]
		if key == "crit":
			lines.append("    %s +%d%%" % [STAT_NAMES.get(key, key), int(round(float(value) * 100.0))])
		else:
			lines.append("    %s +%d" % [STAT_NAMES.get(key, key), int(round(float(value)))])
	return "\n".join(lines)
