class_name ArenaBackground
extends Node2D
## 竞技场背景：地面网格 + 边界 + 若干装饰物。
##
## 纯代码绘制，方便快速替换为 TileMap / 真实美术。

const GRID_STEP := 80.0


func _ready() -> void:
	z_index = -10

	# 固定装饰物（岩石 / 残骸），用固定随机种子保证每次一致
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261009
	var rect: Rect2 = Game.arena
	for i in range(26):
		var rock := ArenaProp.new()
		rock.prop_radius = rng.randf_range(8.0, 22.0)
		rock.prop_color = Color(0.16, 0.15, 0.20)
		rock.position = Vector2(
			rng.randf_range(rect.position.x + 80.0, rect.end.x - 80.0),
			rng.randf_range(rect.position.y + 80.0, rect.end.y - 80.0)
		)
		add_child(rock)


func _draw() -> void:
	var rect: Rect2 = Game.arena

	# 地面
	draw_rect(rect, Color(0.075, 0.075, 0.10))

	# 网格
	var x := rect.position.x
	while x <= rect.end.x + 0.5:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0.12, 0.12, 0.16), 1.0)
		x += GRID_STEP
	var y := rect.position.y
	while y <= rect.end.y + 0.5:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.12, 0.12, 0.16), 1.0)
		y += GRID_STEP

	# 中心营地
	var center := rect.get_center()
	draw_circle(center, 96.0, Color(0.13, 0.11, 0.18))
	draw_arc(center, 96.0, 0.0, TAU, 64, Color(0.45, 0.30, 0.65, 0.6), 3.0)

	# 边界
	draw_rect(rect, Color(0.42, 0.28, 0.62, 0.85), false, 5.0)
