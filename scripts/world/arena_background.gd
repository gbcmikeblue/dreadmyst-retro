class_name ArenaBackground
extends Node3D
## 竞技场：3D 地面 + 网格 + 中心营地 + 边界矮墙 + 装饰岩石。
##
## 地面网格用「平铺贴图」而不是画线，成本恒定为 1 个 draw call。

const GRID_STEP := 80.0
const GROUND_COLOR := Color(0.075, 0.075, 0.10)
const LINE_COLOR := Color(0.12, 0.12, 0.16)
const BORDER_COLOR := Color(0.42, 0.28, 0.62, 0.85)
const WALL_HEIGHT := 7.0
const WALL_THICKNESS := 6.0


func _ready() -> void:
	_build_ground()
	_build_camp()
	_build_border()
	_scatter_props()


func _build_ground() -> void:
	# 用 ARENA_HOME 而不是 Game.arena：arena 会随进出地城切换，而竞技场只建一次
	var rect: Rect2 = Game.ARENA_HOME
	var size := rect.size
	var center := rect.get_center()

	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.y)

	var mat := StandardMaterial3D.new()
	# 网格贴图里已经烘焙了地面色，所以 albedo_color 保持白色不做二次染色
	mat.albedo_texture = SpriteFactory.grid_texture(int(GRID_STEP), GROUND_COLOR, LINE_COLOR)
	mat.albedo_color = Color.WHITE
	mat.uv1_scale = Vector3(size.x / GRID_STEP, size.y / GRID_STEP, 1.0)
	mat.roughness = 1.0
	mat.metallic = 0.0

	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(center.x, 0.0, center.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_camp() -> void:
	var center := Game.ARENA_HOME.get_center()

	var disc := CylinderMesh.new()
	disc.top_radius = 96.0
	disc.bottom_radius = 96.0
	disc.height = 0.06
	disc.radial_segments = 48
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.13, 0.11, 0.18)
	var dmi := MeshInstance3D.new()
	dmi.mesh = disc
	dmi.material_override = dmat
	dmi.position = Vector3(center.x, 0.04, center.y)
	dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dmi)

	var ring := TorusMesh.new()
	ring.inner_radius = 94.0
	ring.outer_radius = 98.0
	ring.rings = 64
	ring.ring_segments = 6
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.45, 0.30, 0.65, 0.85)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rmi := MeshInstance3D.new()
	rmi.mesh = ring
	rmi.material_override = rmat
	rmi.position = Vector3(center.x, 0.08, center.y)
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rmi)


func _build_border() -> void:
	var rect: Rect2 = Game.ARENA_HOME
	var size := rect.size
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var h := WALL_HEIGHT * 0.5
	var t := WALL_THICKNESS

	_wall(Vector3(0.0, h, -hz), Vector3(size.x + t, WALL_HEIGHT, t))
	_wall(Vector3(0.0, h, hz), Vector3(size.x + t, WALL_HEIGHT, t))
	_wall(Vector3(-hx, h, 0.0), Vector3(t, WALL_HEIGHT, size.y + t))
	_wall(Vector3(hx, h, 0.0), Vector3(t, WALL_HEIGHT, size.y + t))


## local_offset 是相对场地中心的偏移。
func _wall(local_offset: Vector3, box_size: Vector3) -> void:
	var center := Game.arena.get_center()
	var box := BoxMesh.new()
	box.size = box_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BORDER_COLOR
	mat.emission_enabled = true
	mat.emission = BORDER_COLOR
	mat.emission_energy_multiplier = 0.35
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = Vector3(center.x + local_offset.x, local_offset.y, center.y + local_offset.z)
	add_child(mi)


## 固定装饰物（岩石），用固定随机种子保证每次布局一致。
func _scatter_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261009
	var rect: Rect2 = Game.ARENA_HOME
	for i in range(26):
		var rock := ArenaProp.new()
		rock.prop_radius = rng.randf_range(8.0, 22.0)
		rock.prop_color = Color(0.16, 0.15, 0.20)
		rock.position = Vector3(
			rng.randf_range(rect.position.x + 80.0, rect.end.x - 80.0),
			0.0,
			rng.randf_range(rect.position.y + 80.0, rect.end.y - 80.0)
		)
		add_child(rock)
