extends Node2D
## 入口场景：搭建世界、生成玩家、刷怪、掉落与伤害数字。
##
## 这是唯一挂在 .tscn 上的脚本；其余角色/掉落物都用 class_name 在代码中实例化，
## 好处是场景文件保持极简、不易损坏，逻辑也一目了然。

const ENEMY_CAP_BASE := 8          # 场上敌人基础上限
const ENEMY_CAP_PER_LEVEL := 2     # 每级额外允许的敌人数量
const SPAWN_INTERVAL := 3.5        # 刷怪间隔（秒）

var player: Player
var hud: HUD

var _spawn_timer: float = 2.0


func _ready() -> void:
	seed(Time.get_ticks_msec())

	add_child(ArenaBackground.new())
	_spawn_player()

	hud = HUD.new()
	add_child(hud)
	_connect_events()
	_push_initial_state()

	for i in range(6):
		_spawn_enemy(randf_range(380.0, 620.0))

	Events.toast.emit("欢迎来到 恐惧秘境 Dreadmyst 复刻原型", Color(0.80, 0.72, 1.0))


func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = SPAWN_INTERVAL

	var alive_count := get_tree().get_nodes_in_group("enemies").size()
	var cap := ENEMY_CAP_BASE + Game.level * ENEMY_CAP_PER_LEVEL
	if alive_count >= cap:
		return
	for i in range(randi_range(1, 3)):
		_spawn_enemy(randf_range(380.0, 640.0))


# ---------------------------------------------------------------- 构建世界

func _spawn_player() -> void:
	player = Player.new()
	add_child(player)
	player.global_position = Game.arena.get_center()

	var camera := Camera2D.new()
	camera.zoom = Vector2(1.15, 1.15)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = int(Game.arena.position.x)
	camera.limit_top = int(Game.arena.position.y)
	camera.limit_right = int(Game.arena.end.x)
	camera.limit_bottom = int(Game.arena.end.y)
	camera.limit_smoothed = true
	player.add_child(camera)
	camera.make_current()


func _spawn_enemy(distance: float) -> void:
	var archetype := EnemyRegistry.pick_weighted()
	if archetype == null:
		push_warning("EnemyRegistry 为空，跳过本次刷怪")
		return
	var enemy := Enemy.new()
	enemy.setup(maxi(1, Game.level + randi_range(-1, 1)), archetype)
	add_child(enemy)

	var center: Vector2 = player.global_position if player != null else Game.arena.get_center()
	var angle := randf() * TAU
	enemy.global_position = center + Vector2(cos(angle), sin(angle)) * distance
	_clamp_inside_arena(enemy, enemy.radius + 10.0)


func _clamp_inside_arena(node: Node2D, margin: float) -> void:
	var rect: Rect2 = Game.arena
	node.global_position.x = clampf(node.global_position.x, rect.position.x + margin, rect.end.x - margin)
	node.global_position.y = clampf(node.global_position.y, rect.position.y + margin, rect.end.y - margin)


# ---------------------------------------------------------------- 事件

func _connect_events() -> void:
	Events.damage_dealt.connect(_on_damage_dealt)
	Events.enemy_died.connect(_on_enemy_died)


## HUD 创建之前 player 已经发出过初始信号，这里补发一次让 UI 同步。
func _push_initial_state() -> void:
	Events.player_health_changed.emit(int(round(player.hp)), int(round(player.max_hp())))
	Events.player_stats_changed.emit(player.total_stats())
	Events.player_level_changed.emit(Game.level, Game.xp, Game.xp_to_next_level())
	Events.gold_changed.emit(Game.gold)


func _on_enemy_died(enemy_level: int, world_position: Vector2) -> void:
	Game.add_xp(12 + enemy_level * 7)
	Game.add_gold(randi_range(2, 6))

	if hud != null:
		hud.kills += 1
		hud.refresh_kills()

	var gear := LootTable.roll_drop(enemy_level)
	if gear != null:
		var pickup := GearPickup.new()
		pickup.gear = gear
		add_child(pickup)
		pickup.global_position = world_position


func _on_damage_dealt(world_position: Vector2, amount: int, is_crit: bool, on_player: bool) -> void:
	var number := DamageNumber.new()
	number.amount = amount
	if on_player:
		number.color = Color(1.0, 0.35, 0.35)
	elif is_crit:
		number.color = Color(1.0, 0.85, 0.2)
	else:
		number.color = Color(1.0, 1.0, 1.0)
	add_child(number)
	number.global_position = world_position + Vector2(0, -28.0)
