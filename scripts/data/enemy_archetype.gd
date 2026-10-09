class_name EnemyArchetype
extends RefCounted
## 敌人原型：定义一类敌人的所有可调参数（数值、外观、行为）。
##
## 全部从 data/enemies.json 的 dict 构造。生成敌人时随机选一个，
## 按等级调用 compute_* 派生最终数值（速度/半径额外加随机抖动）。

# --- 标识 ---
var id: String = ""
var display_name: String = "未知道"

# --- 数值公式（level 派生）---
var hp_base: float = 34.0
var hp_per_lv: float = 16.0
var attack_base: float = 5.0
var attack_per_lv: float = 2.4
var speed_base: float = 105.0
## 速度抖动量：实际速度 = base + randf(-jitter, +jitter) + per_lv*lv
var speed_jitter: float = 20.0
var speed_per_lv: float = 2.0
## 半径抖动量：实际半径 = base + randf(-jitter, +jitter)
var radius_base: float = 18.0
var radius_jitter: float = 3.0

# --- 行为 ---
var attack_range: float = 48.0
var attack_interval: float = 1.2
var knockback_distance: float = 6.0

# --- 外观 ---
## 真实精灵贴图路径（res://...）。留空则用 SpriteFactory 生成程序化占位贴图。
var sprite_path: String = ""
var body_color: Color = Color(0.76, 0.26, 0.30)
var outline_color: Color = Color(0.20, 0.05, 0.08)
var eye_color: Color = Color(0.10, 0.04, 0.05)
var body_outline_width: float = 3.0
var hp_bar_color: Color = Color(0.92, 0.26, 0.30)

# --- 刷怪权重（相对）---
var spawn_weight: float = 1.0


# ---------- 构造 ----------

static func from_dict(d: Dictionary) -> EnemyArchetype:
	var a := EnemyArchetype.new()
	a.id = String(d.get("id", ""))
	a.display_name = String(d.get("display_name", "未知道"))

	a.hp_base = float(d.get("hp_base", 34.0))
	a.hp_per_lv = float(d.get("hp_per_lv", 16.0))
	a.attack_base = float(d.get("attack_base", 5.0))
	a.attack_per_lv = float(d.get("attack_per_lv", 2.4))
	a.speed_base = float(d.get("speed_base", 105.0))
	a.speed_jitter = float(d.get("speed_jitter", 20.0))
	a.speed_per_lv = float(d.get("speed_per_lv", 2.0))
	a.radius_base = float(d.get("radius_base", 18.0))
	a.radius_jitter = float(d.get("radius_jitter", 3.0))

	a.attack_range = float(d.get("attack_range", 48.0))
	a.attack_interval = float(d.get("attack_interval", 1.2))
	a.knockback_distance = float(d.get("knockback_distance", 6.0))

	a.sprite_path = String(d.get("sprite_path", ""))
	a.body_color = _parse_color(d.get("body_color", [0.76, 0.26, 0.30]))
	a.outline_color = _parse_color(d.get("outline_color", [0.20, 0.05, 0.08]))
	a.eye_color = _parse_color(d.get("eye_color", [0.10, 0.04, 0.05]))
	a.body_outline_width = float(d.get("body_outline_width", 3.0))
	a.hp_bar_color = _parse_color(d.get("hp_bar_color", [0.92, 0.26, 0.30]))

	a.spawn_weight = float(d.get("spawn_weight", 1.0))
	return a


static func _parse_color(v: Variant) -> Color:
	if v is Array:
		var arr: Array = v
		if arr.size() >= 3:
			var a := 1.0 if arr.size() < 4 else float(arr[3])
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	if v is String:
		return Color(String(v))
	return Color(0.76, 0.26, 0.30)


# ---------- 派生计算 ----------

func compute_hp(level: int) -> float:
	return hp_base + hp_per_lv * float(level)


func compute_attack(level: int) -> float:
	return attack_base + attack_per_lv * float(level)


func compute_speed(level: int) -> float:
	return speed_base + randf_range(-speed_jitter, speed_jitter) + speed_per_lv * float(level)


func compute_radius() -> float:
	return radius_base + randf_range(-radius_jitter, radius_jitter)
