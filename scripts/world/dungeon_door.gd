class_name DungeonDoor
extends Node3D
## 房间之间的门：横在走廊正中的实心门（`collision_layer = 1`）。
##
## 当前房间的怪物全部清空后由 Dungeon 调用 `open()`：
## 先**立刻取消碰撞**（玩家不用等动画就能过），再播一段下沉 + 淡出动画后自毁。

## 门在玩法平面上的宽度（横跨走廊，Z 方向）
var span: float = 140.0
var height: float = 30.0
var thickness: float = 14.0
var color: Color = Color(0.62, 0.45, 0.95)

var is_open: bool = false

var _body: StaticBody3D
var _mesh: MeshInstance3D


func _ready() -> void:
	name = "DungeonDoor"
	_build()


func _build() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0

	var size := Vector3(thickness, height, span)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	_body.add_child(shape)

	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.45
	_mesh = MeshInstance3D.new()
	_mesh.mesh = box
	_mesh.material_override = mat
	_mesh.position.y = height * 0.5
	_body.add_child(_mesh)

	add_child(_body)


## 开门：立即放行，然后播放下沉动画并自毁。
func open() -> void:
	if is_open:
		return
	is_open = true
	# 立刻断掉碰撞（动画只是表现，不能让玩家在门口干等）
	_body.collision_layer = 0
	if _mesh == null:
		queue_free()
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_mesh, "position:y", -height * 0.9, 0.45)
	tween.tween_property(_mesh, "scale", Vector3(1.0, 0.05, 1.0), 0.45)
	tween.chain().tween_callback(queue_free)
