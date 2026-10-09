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
