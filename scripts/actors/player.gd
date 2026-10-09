class_name Player
extends CharacterBody3D
## 玩家角色：移动 / 冲刺 / 扇形挥砍 / 生命 / 装备属性加成。
##
## 玩法逻辑（距离、朝向夹角）全部在 Vector2「玩法平面」上计算，
## 只在写入 velocity 与位置时转成 Vector3，所以攻击判定等逻辑与 2D 版完全一致。
## 视觉：billboard 精灵（程序化占位贴图，接入真美术后无需改代码）。

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

const BODY_RADIUS := 15.0          # 碰撞圆柱半径
const BODY_HEIGHT := 34.0          # 碰撞圆柱高度
const SPRITE_PIXELS := 64          # 占位贴图分辨率
const SPRITE_WORLD_HEIGHT := 44.0  # 精灵在世界中的高度

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

var _sprite: Sprite3D
var _marker: MeshInstance3D
var _arc: MeshInstance3D
var _dash_fx: MeshInstance3D


func _ready() -> void:
	add_to_group("player")

	# 顶视角游戏：FLOATING 模式完全关闭重力 / 贴地逻辑
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

	# 碰撞层：玩家占 layer 4，只与 layer 1（未来的墙体/障碍）碰撞。
	# 玩家与怪物之间不互相阻挡，避免被怪物围住卡死；视觉分离交给排斥力。
	collision_layer = 4
	collision_mask = 1

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BODY_RADIUS
	cyl.height = BODY_HEIGHT
	shape.shape = cyl
	add_child(shape)

	_build_visuals()
	_update_visuals()

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
		velocity = Vector3.ZERO
		move_and_slide()
		_update_visuals()
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() > 0.05:
		facing = input.normalized()

	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and input.length() > 0.05:
		_dash_cd = DASH_COOLDOWN
		_dash_time = DASH_TIME
		_dash_dir = input.normalized()

	var speed: float = total_stats().get("speed", BASE_STATS["speed"])
	var move2: Vector2
	if _dash_time > 0.0:
		move2 = _dash_dir * DASH_SPEED
	else:
		move2 = input * speed
	velocity = Vector3(move2.x, 0.0, move2.y)

	if Input.is_action_pressed("attack"):
		_try_attack()

	move_and_slide()
	_clamp_to_arena()
	_update_visuals()

	# 简化脱战回血
	if hp < max_hp():
		hp = minf(max_hp(), hp + REST_HP_REGEN * delta)
		Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))


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

	var my_plane := Game.plane(global_position)
	# 用无类型 Array 承载，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		var to_enemy: Vector2 = Game.plane(enemy.global_position) - my_plane
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
	global_position = Game.world(Game.arena.get_center())
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

func _build_visuals() -> void:
	add_child(SpriteFactory.blob_shadow(BODY_RADIUS * 1.3))

	_sprite = SpriteFactory.billboard_sprite(
		SpriteFactory.actor_texture("", SPRITE_PIXELS, Color(0.86, 0.86, 0.96), Color(0.14, 0.14, 0.20)),
		SPRITE_WORLD_HEIGHT)
	add_child(_sprite)

	# 朝向指示（武器柄）：本地 +X 长条
	_marker = SpriteFactory.box_marker(Vector3(20.0, 2.6, 3.0), Color(0.92, 0.76, 0.22))
	add_child(_marker)

	# 挥砍弧光
	_arc = SpriteFactory.arc_fx(
		ATTACK_RANGE * 0.30, ATTACK_RANGE, ATTACK_HALF_ANGLE * 0.78, 24,
		Color(1.0, 0.95, 0.7, 0.85))
	_arc.position.y = 0.12
	_arc.visible = false
	add_child(_arc)

	# 冲刺残影
	_dash_fx = SpriteFactory.flat_disc(BODY_RADIUS * 1.5, Color(0.6, 0.8, 1.0, 0.25), 0.08)
	_dash_fx.visible = false
	add_child(_dash_fx)


func _update_visuals() -> void:
	var body_color := Color(0.86, 0.86, 0.96)
	if _hit_flash > 0.0:
		body_color = Color(1.0, 0.5, 0.5)
	if dead:
		body_color = Color(0.4, 0.4, 0.42)
	if _sprite != null:
		_sprite.modulate = body_color

	var dir3 := Vector3(facing.x, 0.0, facing.y)
	if dir3.length_squared() > 0.0001:
		dir3 = dir3.normalized()
	if _marker != null:
		_marker.position = dir3 * 12.0 + Vector3(0.0, BODY_HEIGHT * 0.45, 0.0)
		_marker.rotation.y = -facing.angle()

	if _arc != null:
		if _attack_anim > 0.0:
			var p := 1.0 - _attack_anim / ATTACK_ANIM_TIME
			var s := lerpf(0.78, 1.06, p)
			_arc.visible = true
			_arc.rotation.y = -facing.angle()
			_arc.scale = Vector3(s, 1.0, s)
		else:
			_arc.visible = false

	if _dash_fx != null:
		_dash_fx.visible = _dash_time > 0.0


func _clamp_to_arena() -> void:
	var r: Rect2 = Game.arena
	var margin := 24.0
	var p := Game.plane(global_position)
	global_position = Game.world(Vector2(
		clampf(p.x, r.position.x + margin, r.end.x - margin),
		clampf(p.y, r.position.y + margin, r.end.y - margin)
	))
