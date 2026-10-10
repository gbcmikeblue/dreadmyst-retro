class_name Enemy
extends CharacterBody3D
## 敌人：所有数值与外观来自 EnemyArchetype（data/enemies.json）。
##
## 调用方在 add_child 之前调用 setup(level, archetype)。
## 玩法逻辑在 Vector2 玩法平面上计算，只在读写位置时转 Vector3。

const SPRITE_PIXELS := 64

var archetype: EnemyArchetype = null

var level: int = 1
var max_hp: float = 40.0
var hp: float = 40.0
var attack_power: float = 6.0
var move_speed: float = 105.0
var attack_range: float = 48.0
var attack_interval: float = 1.2
var radius: float = 18.0
var alive: bool = true

## 精灵在世界中的高度（相对半径的比例）
var sprite_world_height: float = 0.0

var _attack_cd: float = 0.6
var _hit_flash: float = 0.0
var _separation: Vector2 = Vector2.ZERO

var _sprite: Sprite3D
var _eye: MeshInstance3D
var _bar_root: Node3D
var _bar_fill: Sprite3D
var _bar_width: float = 36.0


## 由生成器调用。arch 必须非空。
func setup(new_level: int, arch: EnemyArchetype) -> void:
	archetype = arch
	level = maxi(1, new_level)
	max_hp = archetype.compute_hp(level)
	hp = max_hp
	attack_power = archetype.compute_attack(level)
	move_speed = archetype.compute_speed(level)
	radius = archetype.compute_radius()
	attack_range = archetype.attack_range
	attack_interval = archetype.attack_interval
	# 错开首发攻击，避免所有敌人同时出手
	_attack_cd = randf_range(0.0, attack_interval)


func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

	# 怪物占 layer 2，只与 layer 1（未来的墙体）碰撞；彼此之间靠 _separation 排斥。
	collision_layer = 2
	collision_mask = 1

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = radius * 2.2
	shape.shape = cyl
	add_child(shape)

	_build_visuals()
	_update_visuals()


func is_alive() -> bool:
	return alive


## 是否是 Boss（血条更大 + 免疫击退 + 脚下光环）。
func _is_boss() -> bool:
	return archetype != null and archetype.is_boss


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_hit_flash = maxf(0.0, _hit_flash - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_compute_separation()

	var player := Game.get_player()
	if player == null or not is_instance_valid(player):
		velocity = Vector3(_separation.x, 0.0, _separation.y) * move_speed * 0.5
		move_and_slide()
		_update_visuals()
		return

	var my_plane := Game.plane(global_position)
	var to_player: Vector2 = Game.plane(player.global_position) - my_plane
	var distance := to_player.length()
	var direction := to_player.normalized() if distance > 0.001 else Vector2.ZERO

	var move2: Vector2
	if distance > attack_range:
		var steer := (direction + _separation * 0.6).normalized()
		move2 = steer * move_speed
	else:
		move2 = _separation * move_speed * 0.3
		if _attack_cd <= 0.0 and player.has_method("take_damage"):
			_attack_cd = attack_interval
			player.call("take_damage", attack_power)

	velocity = Vector3(move2.x, 0.0, move2.y)
	move_and_slide()
	_clamp_to_arena()
	_update_visuals()


func take_damage(amount: float, is_crit: bool = false) -> void:
	if not alive:
		return
	hp -= amount
	_hit_flash = 0.12
	Events.damage_dealt.emit(global_position, int(round(amount)), is_crit, false)

	# 轻微击退（Boss 免疫：体型太大，被推着走会破坏 Boss 战节奏）
	var player := Game.get_player()
	if player != null and is_instance_valid(player) and not _is_boss():
		var my_plane := Game.plane(global_position)
		var away: Vector2 = my_plane - Game.plane(player.global_position)
		if away.length() > 0.001:
			var kbk := float(archetype.knockback_distance) if archetype != null else 6.0
			global_position = Game.world(my_plane + away.normalized() * kbk)

	_update_visuals()
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	remove_from_group("enemies")
	Events.enemy_died.emit(level, global_position)

	set_physics_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.4, 1.4, 1.4), 0.25)
	if _sprite != null:
		tween.tween_property(_sprite, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _compute_separation() -> void:
	var push := Vector2.ZERO
	var my_plane := Game.plane(global_position)
	# 用无类型 Array 承载，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var others: Array = get_tree().get_nodes_in_group("enemies")
	for other in others:
		if other == self or not is_instance_valid(other):
			continue
		var offset: Vector2 = my_plane - Game.plane(other.global_position)
		var dist := offset.length()
		var min_dist: float = radius + float(other.radius) + 6.0
		if dist > 0.001 and dist < min_dist:
			push += offset.normalized() * (1.0 - dist / min_dist)
	_separation = push


func _clamp_to_arena() -> void:
	var r: Rect2 = Game.arena
	var margin := radius + 8.0
	var p := Game.plane(global_position)
	global_position = Game.world(Vector2(
		clampf(p.x, r.position.x + margin, r.end.x - margin),
		clampf(p.y, r.position.y + margin, r.end.y - margin)
	))


# ---------------------------------------------------------------- 表现

func _build_visuals() -> void:
	var body := Color(0.76, 0.26, 0.30)
	var outline := Color(0.20, 0.05, 0.08)
	var eye_col := Color(0.10, 0.04, 0.05)
	var bar_col := Color(0.92, 0.26, 0.30)
	var sprite_path := ""
	if archetype != null:
		body = archetype.body_color
		outline = archetype.outline_color
		eye_col = archetype.eye_color
		bar_col = archetype.hp_bar_color
		sprite_path = archetype.sprite_path

	sprite_world_height = radius * 2.4

	# Boss 脚下光环：普通怪只有影斑，Boss 多一层品质色光晕（纯视觉，方便一眼认出）
	if _is_boss():
		add_child(SpriteFactory.flat_disc(
			radius * 1.9, Color(bar_col.r, bar_col.g, bar_col.b, 0.22), 0.05))

	add_child(SpriteFactory.blob_shadow(radius * 1.25))

	_sprite = SpriteFactory.billboard_sprite(
		SpriteFactory.actor_texture(sprite_path, SPRITE_PIXELS, body, outline),
		sprite_world_height)
	add_child(_sprite)

	# 面向玩家的"眼睛"：小球体，每帧移动到朝向玩家的一侧
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = maxf(2.5, radius * 0.17)
	eye_mesh.height = maxf(5.0, radius * 0.34)
	eye_mesh.radial_segments = 8
	eye_mesh.rings = 4
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = eye_col
	_eye = MeshInstance3D.new()
	_eye.mesh = eye_mesh
	_eye.material_override = eye_mat
	_eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_eye)

	_build_hp_bar(bar_col)


func _build_hp_bar(bar_col: Color) -> void:
	# Boss 血条更宽更高，悬得也更高（体型大，贴着头顶会挡视线）
	var boss := _is_boss()
	_bar_width = radius * (2.6 if boss else 2.0)
	var bar_h := maxf(4.0, radius * (0.42 if boss else 0.30))

	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0.0, sprite_world_height + (24.0 if boss else 14.0), 0.0)
	add_child(_bar_root)

	var bar := SpriteFactory.hp_bar(_bar_width, bar_h, bar_col)
	var bg: Sprite3D = bar["bg"]
	var fill: Sprite3D = bar["fill"]
	_bar_root.add_child(bg)
	_bar_root.add_child(fill)
	_bar_fill = fill


func _update_visuals() -> void:
	if _sprite != null:
		var body := archetype.body_color if archetype != null else Color(0.76, 0.26, 0.30)
		if _hit_flash > 0.0:
			body = Color(1.0, 0.92, 0.92)
		_sprite.modulate = body

	if _eye != null:
		var player := Game.get_player()
		if player != null and is_instance_valid(player):
			var dir3 := player.global_position - global_position
			dir3.y = 0.0
			if dir3.length_squared() > 0.0001:
				_eye.position = dir3.normalized() * radius * 0.5 + Vector3(0.0, sprite_world_height * 0.5, 0.0)

	if _bar_fill != null and max_hp > 0.0:
		SpriteFactory.update_bar(_bar_fill, _bar_width, hp / max_hp)
