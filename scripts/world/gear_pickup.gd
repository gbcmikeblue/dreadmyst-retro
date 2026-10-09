class_name GearPickup
extends Node3D
## 地面掉落物：玩家靠近一定半径后自动拾取。
##
## 用「平面距离判定」而不是 Area3D，避免碰撞层配置带来的意外。

const SPRITE_PIXELS := 32
const ICON_WORLD_HEIGHT := 22.0
const BOB_AMPLITUDE := 3.0
const BOB_SPEED := 3.0

var gear: GearItem
var pickup_radius: float = 40.0
var collected: bool = false

var _bob_time: float = 0.0
var _player: Node3D = null
var _sprite: Sprite3D
var _glow: MeshInstance3D
var _base_sprite_y: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	_bob_time = randf() * TAU
	_build_visuals()


func _process(delta: float) -> void:
	_bob_time += delta * BOB_SPEED
	_update_visuals()
	if collected:
		return

	if _player == null or not is_instance_valid(_player):
		_player = Game.get_player()
	if _player == null:
		return

	var here := Game.plane(global_position)
	var there := Game.plane(_player.global_position)
	if here.distance_to(there) <= pickup_radius:
		_collect()


func _collect() -> void:
	collected = true
	if _player != null and is_instance_valid(_player) and _player.has_method("receive_loot"):
		_player.call("receive_loot", gear)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.6, 1.6, 1.6), 0.18)
	if _sprite != null:
		tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	if _glow != null:
		tween.tween_property(_glow, "scale", Vector3(1.8, 1.0, 1.8), 0.18)
	tween.chain().tween_callback(queue_free)


# ---------------------------------------------------------------- 表现

func _build_visuals() -> void:
	if gear == null:
		return
	var color := gear.rarity_color()

	_glow = SpriteFactory.flat_disc(24.0, Color(color.r, color.g, color.b, 0.20), 0.06)
	add_child(_glow)

	_sprite = SpriteFactory.billboard_sprite(
		SpriteFactory.gem_texture(SPRITE_PIXELS, color), ICON_WORLD_HEIGHT)
	_base_sprite_y = _sprite.position.y
	add_child(_sprite)


func _update_visuals() -> void:
	if _sprite == null:
		return
	_sprite.position.y = _base_sprite_y + sin(_bob_time) * BOB_AMPLITUDE
