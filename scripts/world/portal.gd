class_name Portal
extends Node3D
## 传送门：玩家靠近时显示交互提示，按 F 触发（进地城 / 出地城）。
##
## 不用 `Area3D`，用**玩法平面距离判定**（与 GearPickup 同一思路），行为可预测、不用配碰撞层。
## 与外界只走 `Events`：ENTER 发 `dungeon_enter_requested`，EXIT 发 `dungeon_exit_requested`。
##
## 注意：`Node3D` 没有 `modulate`，所以「未激活压暗」是通过改材质颜色 + 精灵 modulate 做的。

enum Mode { ENTER, EXIT }

## 交互半径（玩法平面单位）
const INTERACT_RADIUS := 96.0
const RING_RADIUS := 46.0
const DIM_FACTOR := 0.42

var mode: int = Mode.ENTER
## ENTER 模式要告诉 main 进哪一间地城
var dungeon_id: String = ""
## 提示文案里的动作，例如「进入 亡者地窖」/「离开地城」
var label: String = "使用传送门"
## 未激活的门不响应交互（地城出口要清空后才开）
var active: bool = true
var color: Color = Color(0.62, 0.45, 0.95)

var _player: Node3D = null
var _prompting: bool = false
var _disc: MeshInstance3D
var _disc_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _marker: Sprite3D
var _time: float = 0.0


func _ready() -> void:
	name = "Portal"
	_build_visuals()
	_update_visuals()


func _process(delta: float) -> void:
	_time += delta
	_update_visuals()

	var player := _active_player()
	var in_range := active and not _ui_blocked() and player != null \
		and Game.plane(global_position).distance_to(Game.plane(player.global_position)) <= INTERACT_RADIUS

	if in_range != _prompting:
		_prompting = in_range
		Events.interact_prompt_changed.emit(("按 F %s" % label) if in_range else "")

	if in_range and Input.is_action_just_pressed("interact"):
		_trigger()


## 被释放时（例如离开地城、地城节点被移除）要把提示收掉，否则会一直挂在屏幕上。
func _exit_tree() -> void:
	if _prompting:
		_prompting = false
		Events.interact_prompt_changed.emit("")


func _trigger() -> void:
	if mode == Mode.ENTER:
		Events.dungeon_enter_requested.emit(dungeon_id)
	else:
		Events.dungeon_exit_requested.emit()


# ---------------------------------------------------------------- 表现

func _active_player() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = Game.get_player()
	return _player


## 模态 UI（加点界面）打开时不响应交互：否则按 F 会一边加点一边进副本。
func _ui_blocked() -> bool:
	return not get_tree().get_nodes_in_group("modal_ui").is_empty()


func _build_visuals() -> void:
	_disc = SpriteFactory.flat_disc(RING_RADIUS, Color(color.r, color.g, color.b, 0.18), 0.05)
	_disc_mat = _disc.material_override as StandardMaterial3D
	add_child(_disc)

	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS * 0.92
	torus.outer_radius = RING_RADIUS
	torus.rings = 48
	torus.ring_segments = 6
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = color
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.emission_enabled = true
	_ring_mat.emission = color
	_ring_mat.emission_energy_multiplier = 0.6
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.position.y = 0.10
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_marker = SpriteFactory.billboard_sprite(SpriteFactory.gem_texture(32, color), 34.0)
	add_child(_marker)


func _update_visuals() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 2.4)
	var tint := color if active else Color(color.r * DIM_FACTOR, color.g * DIM_FACTOR,
		color.b * DIM_FACTOR * 1.15)

	if _ring != null:
		_ring.rotation.y = _time * 0.8
		_ring.scale = Vector3.ONE * (1.0 + pulse * 0.05)
	if _ring_mat != null:
		_ring_mat.albedo_color = tint
		_ring_mat.emission = tint
	if _disc != null:
		_disc.scale = Vector3.ONE * (1.0 + pulse * 0.08)
	if _disc_mat != null:
		_disc_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.18 if active else 0.10)
	if _marker != null:
		_marker.position.y = 30.0 + sin(_time * 2.0) * 4.0
		_marker.modulate = Color.WHITE if active else Color(0.60, 0.60, 0.66, 1.0)
