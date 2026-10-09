class_name SkillDef
extends RefCounted
## 单个技能的定义（纯数据，不含表现）。
##
## 数据来自 data/skills.json，加载器是 SkillRegistry。
## ⚠️ 数值为自行设计的占位值，待拿到原作资料后校准（见 docs/roadmap.md「待用户提供的信息」）。

enum Kind { BASIC, ULTIMATE }

var id: String = ""
var display_name: String = "未知技能"
## 所属职业 id，对应 Profession.id
var profession_id: String = ""
var kind: int = Kind.BASIC

# --- 数值 ---
var cooldown: float = 0.5        # 冷却（秒）
var mana_cost: float = 0.0       # 单次耗蓝
var damage_mult: float = 1.0     # 伤害倍率（乘总攻击力）
var cast_range: float = 90.0     # 命中半径（玩法平面单位）
## 扇形半角（弧度）。>= PI 视为 360° 全方位命中
var half_angle: float = 1.0

# --- 外观 ---
var color: Color = Color.WHITE
## 真实图标路径（res://...）。留空则用程序化占位图标（技能名首字 + 技能色）。
var icon: String = ""


# ---------- 构造 ----------

static func from_dict(d: Dictionary) -> SkillDef:
	var s := SkillDef.new()
	s.id = String(d.get("id", ""))
	s.display_name = String(d.get("name", "未知技能"))
	s.profession_id = String(d.get("profession", ""))
	s.kind = Kind.ULTIMATE if String(d.get("kind", "basic")) == "ultimate" else Kind.BASIC
	s.cooldown = maxf(0.0, float(d.get("cooldown", 0.5)))
	s.mana_cost = maxf(0.0, float(d.get("mana_cost", 0.0)))
	s.damage_mult = float(d.get("damage_mult", 1.0))
	s.cast_range = maxf(1.0, float(d.get("cast_range", 90.0)))
	s.half_angle = deg_to_rad(clampf(float(d.get("half_angle_deg", 60.0)), 1.0, 180.0))
	s.color = _parse_color(d.get("color", [1.0, 1.0, 1.0]))
	s.icon = String(d.get("icon", ""))
	return s


static func _parse_color(v: Variant) -> Color:
	if v is Array:
		var arr: Array = v
		if arr.size() >= 3:
			var a := 1.0 if arr.size() < 4 else float(arr[3])
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	if v is String:
		return Color(String(v))
	return Color.WHITE


# ---------- 查询 ----------

## 是否 360° 全方位命中（旋风斩这类）。
func is_full_circle() -> bool:
	return half_angle >= PI - 0.001


func kind_name() -> String:
	return "大招" if kind == Kind.ULTIMATE else "普攻"


## 程序化图标用的短标签：取技能名首字。
func short_label() -> String:
	if display_name.is_empty():
		return "?"
	return display_name.substr(0, 1)
