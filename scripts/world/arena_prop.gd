class_name ArenaProp
extends Node3D
## 竞技场装饰物（岩石），纯视觉，不参与碰撞。
##
## 低分段球体 + 随机压扁/旋转做出"岩石"的观感；会投影真实阴影。

var prop_radius: float = 12.0
var prop_color: Color = Color(0.16, 0.15, 0.20)


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = prop_radius
	mesh.height = prop_radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3

	var mat := StandardMaterial3D.new()
	mat.albedo_color = prop_color
	mat.roughness = 1.0

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat

	# 用坐标派生种子，保证每次运行同一块石头形状一致
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x) * 31.0 + absf(position.z) * 17.0)
	mi.scale = Vector3(
		rng.randf_range(0.85, 1.15),
		rng.randf_range(0.55, 0.90),
		rng.randf_range(0.85, 1.15)
	)
	mi.rotation = Vector3(
		rng.randf_range(-0.30, 0.30),
		rng.randf_range(0.0, TAU),
		rng.randf_range(-0.30, 0.30)
	)
	mi.position.y = prop_radius * 0.30
	add_child(mi)
