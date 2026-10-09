class_name Enemy
extends CharacterBody2D
## 敌人：所有数值与外观来自 EnemyArchetype（data/enemies.json）。
##
## 调用方在 add_child 之前调用 setup(level, archetype)。
## 敌人之间靠 _separation 排斥，避免完全重叠。

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

var _attack_cd: float = 0.6
var _hit_flash: float = 0.0
var _separation: Vector2 = Vector2.ZERO


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
	# 怪物占 layer 2，只与 layer 1（未来的墙体）碰撞；彼此之间靠 _separation 排斥。
	collision_layer = 2
	collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)


func is_alive() -> bool:
	return alive


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_hit_flash = maxf(0.0, _hit_flash - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_compute_separation()

	var player := Game.get_player()
	if player == null or not is_instance_valid(player):
		velocity = _separation * move_speed * 0.5
		move_and_slide()
		queue_redraw()
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized() if distance > 0.001 else Vector2.ZERO

	if distance > attack_range:
		var steer := (direction + _separation * 0.6).normalized()
		velocity = steer * move_speed
	else:
		velocity = _separation * move_speed * 0.3
		if _attack_cd <= 0.0 and player.has_method("take_damage"):
			_attack_cd = attack_interval
			player.call("take_damage", attack_power)

	move_and_slide()
	_clamp_to_arena()
	queue_redraw()


func take_damage(amount: float, is_crit: bool = false) -> void:
	if not alive:
		return
	hp -= amount
	_hit_flash = 0.12
	Events.damage_dealt.emit(global_position, int(round(amount)), is_crit, false)

	# 轻微击退
	var player := Game.get_player()
	if player != null and is_instance_valid(player):
		var away := (global_position - player.global_position)
		if away.length() > 0.001:
			var kbk := float(archetype.knockback_distance) if archetype != null else 6.0
			global_position += away.normalized() * kbk

	queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	remove_from_group("enemies")
	Events.enemy_died.emit(level, global_position)

	set_physics_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _compute_separation() -> void:
	var push := Vector2.ZERO
	# 用无类型 Array 承载，避免静态类型分析把元素推断为 Node 而报"找不到成员"
	var others: Array = get_tree().get_nodes_in_group("enemies")
	for other in others:
		if other == self or not is_instance_valid(other):
			continue
		var offset: Vector2 = global_position - other.global_position
		var dist := offset.length()
		var min_dist: float = radius + float(other.radius) + 6.0
		if dist > 0.001 and dist < min_dist:
			push += offset.normalized() * (1.0 - dist / min_dist)
	_separation = push


func _clamp_to_arena() -> void:
	var r: Rect2 = Game.arena
	var margin := radius + 8.0
	global_position.x = clampf(global_position.x, r.position.x + margin, r.end.x - margin)
	global_position.y = clampf(global_position.y, r.position.y + margin, r.end.y - margin)


func _draw() -> void:
	# 默认外观（archetype 缺失时的兜底）
	var body := Color(0.76, 0.26, 0.30)
	var outline := Color(0.20, 0.05, 0.08)
	var eye := Color(0.10, 0.04, 0.05)
	var hp_bar := Color(0.92, 0.26, 0.30)
	var outline_w := 3.0
	if archetype != null:
		body = archetype.body_color
		outline = archetype.outline_color
		eye = archetype.eye_color
		hp_bar = archetype.hp_bar_color
		outline_w = archetype.body_outline_width

	# 阴影
	draw_circle(Vector2(0, radius * 0.7), radius * 0.9, Color(0, 0, 0, 0.3))

	var base := body
	if _hit_flash > 0.0:
		base = Color(1.0, 0.92, 0.92)
	draw_circle(Vector2.ZERO, radius, base)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, outline, outline_w)

	# 面向玩家的小眼睛
	var player := Game.get_player()
	if player != null and is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		draw_circle(dir * radius * 0.42, maxf(2.5, radius * 0.16), eye)

	# 头顶血条
	var width := radius * 2.0
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var bar_y := -radius - 13.0
	draw_rect(Rect2(-width * 0.5, bar_y, width, 5.0), Color(0.10, 0.10, 0.12, 0.9))
	draw_rect(Rect2(-width * 0.5, bar_y, width * ratio, 5.0), hp_bar)
