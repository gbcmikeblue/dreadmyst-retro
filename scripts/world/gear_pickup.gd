class_name GearPickup
extends Node2D
## 地面掉落物：玩家靠近一定半径后自动拾取。
##
## 用「距离判定」而不是 Area2D，避免碰撞层配置带来的意外。

var gear: GearItem
var pickup_radius: float = 40.0
var collected: bool = false

var _bob_time: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	add_to_group("pickups")
	_bob_time = randf() * TAU


func _process(delta: float) -> void:
	_bob_time += delta * 3.0
	queue_redraw()
	if collected:
		return

	if _player == null or not is_instance_valid(_player):
		_player = Game.get_player()
	if _player == null:
		return

	if global_position.distance_to(_player.global_position) <= pickup_radius:
		_collect()


func _collect() -> void:
	collected = true
	if _player != null and is_instance_valid(_player) and _player.has_method("receive_loot"):
		_player.call("receive_loot", gear)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	if gear == null:
		return
	var color := gear.rarity_color()
	var bob := sin(_bob_time) * 3.0

	# 品质光晕
	draw_circle(Vector2(0, 2), 16.0, Color(color.r, color.g, color.b, 0.18))

	# 菱形宝石
	var points := PackedVector2Array([
		Vector2(0, -12 + bob),
		Vector2(9, bob),
		Vector2(0, 12 + bob),
		Vector2(-9, bob),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
		Color(1, 1, 1, 0.75), 1.5)
