class_name ArenaProp
extends Node2D
## 竞技场装饰物（岩石 / 残骸），纯视觉，不参与碰撞。

var prop_radius: float = 12.0
var prop_color: Color = Color(0.16, 0.15, 0.20)


func _draw() -> void:
	# 阴影
	draw_circle(Vector2(0, prop_radius * 0.35), prop_radius * 1.05, Color(0, 0, 0, 0.28))
	# 不规则多边形让它看起来像石头
	var points := PackedVector2Array()
	var segments := 7
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 31.0 + position.y * 17.0)
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var r := prop_radius * rng.randf_range(0.72, 1.12)
		points.append(Vector2(cos(angle), sin(angle) * 0.72) * r)
	draw_colored_polygon(points, prop_color)
	draw_polyline(_closed(points), Color(0, 0, 0, 0.5), 1.5)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	if out.size() > 0:
		out.append(out[0])
	return out
