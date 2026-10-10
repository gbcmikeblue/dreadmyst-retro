class_name AttributeDef
extends RefCounted
## 单个属性（力量 / 敏捷 / 智力 / 体力 / 精神）的定义，纯数据、不含表现。
##
## 数据来自 data/attributes.json，加载器是 AttributeRegistry。
## ⚠️ 数值为自行设计的占位值，待原作资料校准（见 docs/roadmap.md「待用户提供的信息」）。

var id: String = ""
var display_name: String = "未知属性"
var description: String = ""
var color: Color = Color.WHITE

## 每点加成 {stat_key: delta}。键与 Player.total_stats() 一致：
## attack / max_hp / armor / crit / speed / max_mana / mana_regen
var per_point: Dictionary = {}

## 该属性可投入的点数上限。0 = 不设上限（此时不会出现「满级」状态）。
var max_points: int = 0


# ---------- 构造 ----------

static func from_dict(d: Dictionary) -> AttributeDef:
	var a := AttributeDef.new()
	a.id = String(d.get("id", ""))
	a.display_name = String(d.get("name", "未知属性"))
	a.description = String(d.get("description", ""))
	a.color = _parse_color(d.get("color", [1.0, 1.0, 1.0]))
	a.max_points = maxi(0, int(d.get("max_points", 0)))
	var raw: Variant = d.get("per_point", {})
	if typeof(raw) == TYPE_DICTIONARY:
		var dict: Dictionary = raw
		for key in dict:
			# 过滤掉非数值项，避免 JSON 里写错一个字符串就把整条属性算崩
			var v: Variant = dict[key]
			if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
				a.per_point[String(key)] = float(v)
	return a


static func _parse_color(v: Variant) -> Color:
	if v is Array:
		var arr: Array = v
		if arr.size() >= 3:
			var alpha := 1.0 if arr.size() < 4 else float(arr[3])
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), alpha)
	if v is String:
		return Color(String(v))
	return Color.WHITE


# ---------- 查询 ----------

## 已投入 points 点时的加成汇总 {stat_key: delta}。
func bonus_for(points: int) -> Dictionary:
	var out: Dictionary = {}
	if points <= 0:
		return out
	for key in per_point:
		out[key] = float(per_point[key]) * float(points)
	return out


## 该属性在 points 点下是否已满级（max_points = 0 视为不设上限，永远不满）。
func is_capped(points: int) -> bool:
	return max_points > 0 and points >= max_points


## 程序化图标用的短标签：取属性名首字。
func short_label() -> String:
	if display_name.is_empty():
		return "?"
	return display_name.substr(0, 1)
