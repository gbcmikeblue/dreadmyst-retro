class_name DamageNumber
extends Label3D
## 漂浮伤害数字。用 Label3D 而不是 CanvasLayer 手动画字，
## 好处是自动跟随 3D 世界坐标 + 自带描边，无需世界坐标转屏幕。

const LIFETIME := 0.75
## 世界单位/像素：让文字在当前正交视野下大小合适
const TEXT_PIXEL_SIZE := 0.18
const RISE_SPEED := 56.0
const GRAVITY := 110.0

var amount: int = 0
var color: Color = Color.WHITE

var _life: float = LIFETIME
var _rise: float = RISE_SPEED


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	font_size = 64
	outline_size = 14
	outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	pixel_size = TEXT_PIXEL_SIZE
	text = str(amount)
	modulate = color


func _process(delta: float) -> void:
	_life -= delta
	position.y += _rise * delta
	_rise = maxf(10.0, _rise - GRAVITY * delta)   # 先快后慢，同 2D 版
	modulate.a = clampf(_life / LIFETIME, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()
