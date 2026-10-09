class_name Player
extends CharacterBody2D
## 玩家角色：移动 / 冲刺 / 扇形挥砍 / 生命 / 装备属性加成。
##
## 视觉全部由 _draw() 绘制，零外部美术资源即可运行。
## 攻击判定用「距离 + 朝向夹角」手写，不依赖 Area2D，行为可预测。

const BASE_STATS := {
	"attack": 10.0,
	"max_hp": 120.0,
	"armor": 0.0,
	"crit": 0.05,
	"speed": 235.0,
}

const ATTACK_INTERVAL := 0.42      # 攻击间隔（秒）
const ATTACK_RANGE := 84.0         # 挥砍半径
const ATTACK_HALF_ANGLE := 1.0     # 扇形半角（弧度，约 57°）
const ATTACK_ANIM_TIME := 0.18
const DASH_SPEED := 780.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 1.1
const REST_HP_REGEN := 0.6         # 每秒回血（脱战简化实现）

## GearItem.Slot -> GearItem
var equipment: Dictionary = {}
var hp: float = 0.0
var facing: Vector2 = Vector2.RIGHT
var dead: bool = false

var _attack_cd: float = 0.0
var _attack_anim: float = 0.0
var _dash_cd: float = 0.0
var _dash_time: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _hit_flash: float = 0.0


func _ready() -> void:
	add_to_group("player")
	# 碰撞层：玩家占 layer 4，只与 layer 1（未来的墙体/障碍）碰撞。
	# 玩家与怪物之间不互相阻挡，避免被怪物围住卡死；视觉分离交给排斥力。
	collision_layer = 4
	collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	add_child(shape)

	hp = max_hp()
	Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))
	Events.player_stats_changed.emit(total_stats())


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_attack_anim = maxf(0.0, _attack_anim - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_dash_time = maxf(0.0, _dash_time - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)

	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() > 0.05:
		facing = input.normalized()

	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and input.length() > 0.05:
		_dash_cd = DASH_COOLDOWN
		_dash_time = DASH_TIME
		_dash_dir = input.normalized()

	var speed: float = total_stats().get("speed", BASE_STATS["speed"])
	if _dash_time > 0.0:
		velocity = _dash_dir * DASH_SPEED
	else:
		velocity = input * speed

	if Input.is_action_pressed("attack"):
		_try_attack()

	move_and_slide()
	_clamp_to_arena()

	# 简化脱战回血
	if hp < max_hp():
		hp = minf(max_hp(), hp + REST_HP_REGEN * delta)
		Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))

	queue_redraw()


# ---------------------------------------------------------------- 属性

func max_hp() -> float:
	return float(total_stats().get("max_hp", BASE_STATS["max_hp"]))


## 基础属性 + 所有装备词条的汇总。
func total_stats() -> Dictionary:
	var result: Dictionary = BASE_STATS.duplicate(true)
	for slot in equipment:
		var gear: GearItem = equipment[slot]
		if gear == null:
			continue
		for key in gear.stats:
			result[key] = float(result.get(key, 0.0)) + float(gear.stats[key])
	return result


# ---------------------------------------------------------------- 攻击

func _try_attack() -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = ATTACK_INTERVAL
	_attack_anim = ATTACK_ANIM_TIME

	var stats := total_stats()
	var attack_power: float = float(stats.get("attack", 0.0))
	var crit_chance: float = clampf(float(stats.get("crit", 0.0)), 0.0, 0.9)

	# 用无类型 Array 承载，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() > ATTACK_RANGE:
			continue
		if absf(facing.angle_to(to_enemy)) > ATTACK_HALF_ANGLE:
			continue
		var is_crit := randf() < crit_chance
		var damage := attack_power * (1.6 if is_crit else 1.0)
		damage *= randf_range(0.9, 1.1)
		enemy.take_damage(damage, is_crit)


# ---------------------------------------------------------------- 受伤 / 死亡

func take_damage(amount: float) -> void:
	if dead:
		return
	var armor: float = maxf(0.0, float(total_stats().get("armor", 0.0)))
	# 护甲按递减公式减伤：armor=100 时减伤 50%
	var reduced := amount * (100.0 / (100.0 + armor))
	hp = maxf(0.0, hp - reduced)
	_hit_flash = 0.15
	Events.player_health_changed.emit(int(ceil(hp)), int(round(max_hp())))
	Events.damage_dealt.emit(global_position, int(round(reduced)), false, true)
	queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	Events.toast.emit("你倒下了…… 3 秒后在营地复活", Color(1.0, 0.4, 0.4))
	await get_tree().create_timer(3.0).timeout
	_respawn()


func _respawn() -> void:
	dead = false
	hp = max_hp()
	global_position = Game.arena.get_center()
	Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))
	Events.toast.emit("你已复活", Color(0.6, 1.0, 0.6))


# ---------------------------------------------------------------- 装备 / 拾取

## 由 GearPickup 调用：装备更好的，自动分解更差的换金币。
func receive_loot(gear: GearItem) -> void:
	var current: GearItem = equipment.get(gear.slot)
	if current == null or gear.power_score() > current.power_score():
		equipment[gear.slot] = gear
		hp = minf(hp, max_hp())
		Events.equipment_changed.emit(equipment)
		Events.player_stats_changed.emit(total_stats())
		Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))
		Events.toast.emit("已装备 %s（%s）" % [gear.item_name, gear.slot_name()], gear.rarity_color())
	else:
		var value := int(round(gear.power_score() / 4.0)) + gear.item_level * 2
		Game.add_gold(value)
		Events.toast.emit("分解 %s，获得 %d 金币" % [gear.item_name, value], gear.rarity_color())
	Events.loot_picked_up.emit(gear)


# ---------------------------------------------------------------- 表现

func _clamp_to_arena() -> void:
	var r: Rect2 = Game.arena
	var margin := 24.0
	global_position.x = clampf(global_position.x, r.position.x + margin, r.end.x - margin)
	global_position.y = clampf(global_position.y, r.position.y + margin, r.end.y - margin)


func _draw() -> void:
	# 阴影
	draw_circle(Vector2(0, 14), 15.0, Color(0, 0, 0, 0.35))

	var body_color := Color(0.86, 0.86, 0.96)
	if _hit_flash > 0.0:
		body_color = Color(1.0, 0.5, 0.5)
	if dead:
		body_color = Color(0.4, 0.4, 0.42)

	draw_circle(Vector2.ZERO, 15.0, body_color)
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color(0.14, 0.14, 0.20), 3.0)

	# 朝向指示（武器柄）
	draw_line(Vector2.ZERO, facing * 20.0, Color(0.92, 0.76, 0.22), 4.0)

	# 挥砍弧光
	if _attack_anim > 0.0:
		var progress := 1.0 - _attack_anim / ATTACK_ANIM_TIME
		var sweep := lerpf(-0.9, 0.9, progress)
		var base_angle := facing.angle()
		draw_arc(Vector2.ZERO, ATTACK_RANGE * 0.72,
			base_angle + sweep - 0.35, base_angle + sweep + 0.35,
			16, Color(1.0, 0.95, 0.7, 0.85), 6.0)

	if _dash_time > 0.0:
		draw_circle(Vector2.ZERO, 22.0, Color(0.6, 0.8, 1.0, 0.25))
