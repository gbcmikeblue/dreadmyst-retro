class_name DungeonRoom
extends Node3D
## 地城单间：3D 地面 + 四面墙（可留门洞）+ 墙角装饰。全部程序化占位美术。
##
## ⚠️ 这是本项目**第一处真实墙体**：墙带 `collision_layer = 1` 的 `StaticBody3D`，
## 而玩家（layer 4）与怪物（layer 2）的 `collision_mask` 都是 1，所以会被真正挡住
## （竞技场的矮墙与岩石是纯视觉，见 docs/modules/world.md 的 TODO）。
##
## 坐标口径：`rect` 直接就是**玩法平面**上的矩形，房间自身挂在原点（`position = ZERO`），
## 因此子节点的本地坐标 == 世界坐标，构建时不用先 add_child 再写 global_position。

const GRID_STEP := 80.0
const PROP_MARGIN := 26.0

## 玩法平面矩形（全局坐标，含 X 与 Z 范围）
var rect: Rect2 = Rect2(0.0, 0.0, 560.0, 480.0)
var wall_height: float = 30.0
var wall_thickness: float = 12.0
var door_width: float = 140.0
## 西 / 东墙是否留门洞（走廊出入口）
var open_west: bool = false
var open_east: bool = false

var ground_color: Color = Color(0.10, 0.09, 0.13)
var line_color: Color = Color(0.16, 0.14, 0.20)
var wall_color: Color = Color(0.30, 0.24, 0.38)
var accent_color: Color = Color(0.62, 0.45, 0.95)
## 房间序号（只用来做装饰排布与命名，不参与逻辑）
var room_index: int = 0


func _ready() -> void:
	name = "DungeonRoom%d" % room_index
	_build_floor()
	_build_walls()
	_scatter_props()


# ---------------------------------------------------------------- 地面

func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = rect.size

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = SpriteFactory.grid_texture(int(GRID_STEP), ground_color, line_color)
	mat.albedo_color = Color.WHITE
	mat.uv1_scale = Vector3(rect.size.x / GRID_STEP, rect.size.y / GRID_STEP, 1.0)
	mat.roughness = 1.0
	mat.metallic = 0.0

	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	var c := rect.get_center()
	mi.position = Vector3(c.x, 0.0, c.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- 墙

func _build_walls() -> void:
	var c := rect.get_center()
	var hx := rect.size.x * 0.5
	var hz := rect.size.y * 0.5
	var t := wall_thickness
	var h := wall_height

	# 南北墙（Z 两侧）整条拉满：房间之间靠走廊连，不在这一侧开口
	_wall(Vector3(c.x, h * 0.5, rect.position.y), Vector3(rect.size.x + t, h, t))
	_wall(Vector3(c.x, h * 0.5, rect.end.y), Vector3(rect.size.x + t, h, t))

	# 东西墙（X 两侧）：需要开口时拆成两段，中间留 door_width 宽的门洞
	_side_wall(Vector3(c.x - hx, 0.0, c.y), t, h, rect.size.y, open_west)
	_side_wall(Vector3(c.x + hx, 0.0, c.y), t, h, rect.size.y, open_east)


## 东西向的墙。open = true 时只砌两段，中间留门洞。
func _side_wall(edge: Vector3, thickness: float, height: float, length: float, open: bool) -> void:
	if not open:
		_wall(Vector3(edge.x, height * 0.5, edge.z), Vector3(thickness, height, length + thickness))
		return
	var gap := minf(door_width, length * 0.8)
	var seg := (length - gap) * 0.5
	if seg <= 1.0:
		return
	var near_z := edge.z - length * 0.5 + seg * 0.5
	var far_z := edge.z + length * 0.5 - seg * 0.5
	_wall(Vector3(edge.x, height * 0.5, near_z), Vector3(thickness, height, seg))
	_wall(Vector3(edge.x, height * 0.5, far_z), Vector3(thickness, height, seg))


## 一段墙：StaticBody3D（碰撞层 1，挡住玩家与怪物）+ 同尺寸 BoxMesh。
func _wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	# 只作为「墙」存在于 layer 1；自己不主动检测任何东西
	body.collision_layer = 1
	body.collision_mask = 0

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = wall_color
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	body.add_child(mi)

	add_child(body)


# ---------------------------------------------------------------- 装饰

## 墙角放两块石头做点缀（复用竞技场的 ArenaProp，纯视觉、不参与碰撞）。
## 用固定种子保证每次进同一间房布局一致。
func _scatter_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010 + room_index * 977
	for i in range(2):
		var rock := ArenaProp.new()
		rock.prop_radius = rng.randf_range(7.0, 15.0)
		rock.prop_color = wall_color.darkened(0.35)
		var sx := rect.position.x + (PROP_MARGIN if i % 2 == 0 else rect.size.x - PROP_MARGIN)
		var sz := rect.position.y + (PROP_MARGIN if i < 2 else rect.size.y - PROP_MARGIN)
		rock.position = Vector3(sx, 0.0, sz)
		add_child(rock)
