class_name Profession
extends RefCounted
## 职业定义：基础属性 + 技能列表（id 引用 data/skills.json）。
##
## 数据来自 data/professions.json，加载器是 ProfessionRegistry。
## ⚠️ 数值为自行设计的占位值，待原作资料校准。

var id: String = ""
var display_name: String = "未知职业"
var color: Color = Color.WHITE
## 基础属性。键与 Player.total_stats() 的键一致：
## attack / max_hp / armor / crit / speed / max_mana / mana_regen
var base_stats: Dictionary = {}
## 技能 id 列表。约定第 0 个是普攻，第 1 个是大招。
var skill_ids: Array[String] = []


# ---------- 构造 ----------

static func from_dict(d: Dictionary) -> Profession:
	var p := Profession.new()
	p.id = String(d.get("id", ""))
	p.display_name = String(d.get("display_name", "未知职业"))
	p.color = _parse_color(d.get("color", [1.0, 1.0, 1.0]))
	p.base_stats = d.get("base_stats", {})
	var raw_skills: Array = d.get("skills", [])
	for s in raw_skills:
		p.skill_ids.append(String(s))
	return p


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

## 该职业的技能（SkillDef 数组）。技能数据缺失的 id 会被跳过。
func skills() -> Array:
	var out: Array = []
	for skill_id in skill_ids:
		var skill := SkillRegistry.get_skill(skill_id)
		if skill != null:
			out.append(skill)
		else:
			push_warning("Profession %s: 技能 id '%s' 在 skills.json 中不存在" % [id, skill_id])
	return out


func stat(key: String, fallback: float = 0.0) -> float:
	return float(base_stats.get(key, fallback))
