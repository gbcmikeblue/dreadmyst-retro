class_name DamageNumber
extends Node2D
## 漂浮伤害数字，受伤/暴击时弹出后上浮淡出。

const LIFETIME := 0.75
const FONT_SIZE := 18

var amount: int = 0
var color: Color = Color.WHITE

var _life: float = LIFETIME
var _velocity: Vector2 = Vector2(0, -56.0)


func _process(delta: float) -> void:
	_life -= delta
	position += _velocity * delta
	_velocity.y += 110.0 * delta       # 简单的重力，先快后慢
	modulate.a = clampf(_life / LIFETIME, 0.0, 1.0)
	queue_redraw()
	if _life <= 0.0:
		queue_free()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text := str(amount)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var origin := Vector2(-width * 0.5, 0.0)
	# 描边效果：先画深色偏移，再画本体
	draw_string(font, origin + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0, 0, 0, 0.8))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
