extends Node3D
## 入口场景：搭建 3D 世界（地面 / 光照 / 正交俯视相机）、生成玩家、刷怪、掉落与伤害数字。
##
## 2.5D 实现方式：真 3D 空间 + 固定俯角的**正交**相机。
## 玩法逻辑仍是平面（XZ），坐标转换统一走 Game.plane() / Game.world()。

const ENEMY_CAP_BASE := 8          # 场上敌人基础上限
const ENEMY_CAP_PER_LEVEL := 2     # 每级额外允许的敌人数量
const SPAWN_INTERVAL := 3.5        # 刷怪间隔（秒）

## 开发工具开关（右上角暂停按钮 + Esc/P 快捷键 + 实时输入显示）。
## 正式发布时设为 false 即可整体移除。
const DEV_TOOLS := true

## 地城原点（玩法平面坐标）：故意离竞技场很远，这样地城地面不会和竞技场地面重叠，
## 进出地城只要切换 Game.arena + 玩家位置，不必销毁/重建竞技场。
const DUNGEON_ORIGIN := Vector2(0.0, 20000.0)
## 竞技场入口传送门相对营地中心的偏移
const ARENA_PORTAL_OFFSET := Vector2(0.0, -180.0)
## 离开地城回到营地时补刷的野怪数量
const ARENA_RESPAWN_ON_RETURN := 6

## 相机俯角：-45 是标准斜俯视；更"平"用 -55，更"俯"用 -35
const CAMERA_TILT_DEG := -45.0
## 正交视野的竖直范围（世界单位）。2D 版是 720 / zoom1.15 ≈ 626，取接近值。
const CAMERA_ORTHO_SIZE := 620.0
## 相机沿视线方向后撤的距离（正交投影下不影响缩放，只影响裁剪范围）
const CAMERA_DIST := 1600.0
const CAMERA_FOLLOW_SPEED := 6.0

var player: Player
var hud: HUD
var camera: Camera3D

## 当前地城实例（不在副本里时为 null）
var dungeon: Dungeon = null
## 竞技场里的入口传送门
var arena_portal: Portal = null

var _spawn_timer: float = 2.0
## 相机的焦点（玩法平面坐标），平滑跟随玩家
var _focus: Vector2 = Vector2.ZERO


func _ready() -> void:
	seed(Time.get_ticks_msec())

	_build_environment()
	add_child(ArenaBackground.new())
	_spawn_player()
	_spawn_arena_portal()

	hud = HUD.new()
	add_child(hud)
	# M8 加点界面：独立 CanvasLayer（layer 20），C 键开关，不塞进 HUD 以保持 HUD 只读
	add_child(AttributePanel.new())
	if DEV_TOOLS:
		add_child(DevPause.new())
	_connect_events()
	_push_initial_state()

	for i in range(6):
		_spawn_enemy(randf_range(380.0, 620.0))

	Events.toast.emit("欢迎来到 恐惧秘境 Dreadmyst 复刻原型", Color(0.80, 0.72, 1.0))


func _process(delta: float) -> void:
	_update_camera(delta)

	# 副本里不刷野怪（地城的怪由 Dungeon 自己按房间刷）
	if Game.in_dungeon:
		return

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


# ---------------------------------------------------------------- 环境 / 光照

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.035, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.74)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# 方向光 + 真实阴影（石头等实体物体会真正投影，替代 2D 版手画的假阴影）
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 2400.0
	add_child(sun)


# ---------------------------------------------------------------- 相机

func _spawn_player() -> void:
	player = Player.new()
	add_child(player)
	player.global_position = Game.world(Game.arena.get_center())

	_focus = Game.plane(player.global_position)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_ORTHO_SIZE
	camera.near = 1.0
	camera.far = 9000.0
	camera.rotation_degrees = Vector3(CAMERA_TILT_DEG, 0.0, 0.0)

	# 必须先入树，才能写 global_position（否则 global_transform 无效）
	add_child(camera)
	camera.global_position = _focus_to_world(_clamp_focus(_focus))
	camera.make_current()


func _update_camera(delta: float) -> void:
	if camera == null or player == null or not is_instance_valid(player):
		return
	var target := Game.plane(player.global_position)
	_focus = _focus.lerp(target, clampf(CAMERA_FOLLOW_SPEED * delta, 0.0, 1.0))
	camera.global_position = _focus_to_world(_clamp_focus(_focus))


## 焦点（玩法平面坐标）-> 相机世界位置。
## 相机沿视线方向后撤 CAMERA_DIST，保证焦点落在画面正中。
func _focus_to_world(focus: Vector2) -> Vector3:
	var t := deg_to_rad(absf(CAMERA_TILT_DEG))
	return Vector3(focus.x, CAMERA_DIST * sin(t), focus.y + CAMERA_DIST * cos(t))


## Camera3D 没有 limit_left/right/top/bottom，需要手动把焦点钳制在场地内。
func _clamp_focus(focus: Vector2) -> Vector2:
	var r: Rect2 = Game.arena
	var aspect := 1.0
	var vp := get_viewport()
	if vp != null:
		var vp_size := vp.get_visible_rect().size
		if vp_size.y > 0.0:
			aspect = vp_size.x / vp_size.y

	# 正交视野在地面上的半宽 / 半深（俯角会把纵深压缩 cos(t) 倍）
	var half_x := CAMERA_ORTHO_SIZE * aspect * 0.5
	var half_z := CAMERA_ORTHO_SIZE * 0.5 / cos(deg_to_rad(absf(CAMERA_TILT_DEG)))

	var min_x := r.position.x + half_x
	var max_x := r.end.x - half_x
	var min_z := r.position.y + half_z
	var max_z := r.end.y - half_z

	# 视野比场地还大时退化为居中，避免 min > max
	if min_x > max_x:
		min_x = (r.position.x + r.end.x) * 0.5
		max_x = min_x
	if min_z > max_z:
		min_z = (r.position.y + r.end.y) * 0.5
		max_z = min_z

	return Vector2(clampf(focus.x, min_x, max_x), clampf(focus.y, min_z, max_z))


# ---------------------------------------------------------------- 地城（M10）

## 竞技场里的入口传送门：指向 data/dungeon.json 里的第一间地城。
func _spawn_arena_portal() -> void:
	var ids := DungeonRegistry.ids()
	if ids.is_empty():
		push_warning("main: DungeonRegistry 为空，竞技场不放入口传送门")
		return
	var def := DungeonRegistry.get_dungeon(ids[0])
	arena_portal = Portal.new()
	arena_portal.mode = Portal.Mode.ENTER
	arena_portal.dungeon_id = def.id
	arena_portal.label = "进入 %s" % def.display_name
	arena_portal.color = def.accent_color
	add_child(arena_portal)
	var center := Game.ARENA_HOME.get_center()
	arena_portal.position = Vector3(
		center.x + ARENA_PORTAL_OFFSET.x, 0.0, center.y + ARENA_PORTAL_OFFSET.y)


func _on_dungeon_enter_requested(dungeon_id: String) -> void:
	if Game.in_dungeon:
		return
	var def := DungeonRegistry.get_dungeon(dungeon_id)
	if def == null:
		push_warning("main: 找不到地城 '%s'" % dungeon_id)
		return
	if player == null or not is_instance_valid(player):
		return

	# 先撤掉野外的怪，再建地城（否则会把刚刷出来的地城怪一起清掉）
	_clear_arena_enemies()

	dungeon = Dungeon.new()
	dungeon.setup(def, DUNGEON_ORIGIN, Game.level)
	add_child(dungeon)

	Game.in_dungeon = true
	Game.dungeon_id = def.id
	Game.arena = def.bounds(DUNGEON_ORIGIN)

	# 玩家与相机一起瞬移：否则相机会从竞技场一路平移过去，画面很怪
	var entrance := def.entrance_point(DUNGEON_ORIGIN)
	player.global_position = Game.world(entrance)
	_focus = entrance
	camera.global_position = _focus_to_world(_clamp_focus(_focus))

	Events.dungeon_entered.emit(def.display_name, def.room_count)
	Events.toast.emit("进入 %s（%d 个房间）" % [def.display_name, def.room_count],
		def.accent_color)


func _on_dungeon_exit_requested() -> void:
	if not Game.in_dungeon:
		return
	Game.in_dungeon = false
	Game.dungeon_id = ""
	Game.arena = Game.ARENA_HOME

	if dungeon != null and is_instance_valid(dungeon):
		# 地城节点被释放时，它的 Portal._exit_tree 会顺手清掉屏幕上的交互提示
		dungeon.queue_free()
	dungeon = null

	if player != null and is_instance_valid(player):
		player.global_position = Game.world(Game.ARENA_HOME.get_center())
	_focus = Game.ARENA_HOME.get_center()
	camera.global_position = _focus_to_world(_clamp_focus(_focus))

	Events.dungeon_exited.emit()
	Events.toast.emit("回到营地", Color(0.6, 1.0, 0.6))

	for i in range(ARENA_RESPAWN_ON_RETURN):
		_spawn_enemy(randf_range(380.0, 620.0))


## 撤离野外全部敌人。直接 queue_free（不走 take_damage），所以不给经验与掉落。
func _clear_arena_enemies() -> void:
	# 用无类型 Array 承载，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		# queue_free() 要等到帧末才生效，这里必须**立刻**退出 enemies 组：
		# 否则本帧内它们仍会被算作「场上的敌人」（自测与后续 AOI 都会数错）。
		enemy.remove_from_group("enemies")
		enemy.set_physics_process(false)
		enemy.queue_free()


# ---------------------------------------------------------------- 构建世界

func _spawn_enemy(distance: float) -> void:
	var archetype := EnemyRegistry.pick_weighted()
	if archetype == null:
		push_warning("EnemyRegistry 为空，跳过本次刷怪")
		return
	var enemy := Enemy.new()
	enemy.setup(maxi(1, Game.level + randi_range(-1, 1)), archetype)
	add_child(enemy)

	var center := _focus
	if player != null and is_instance_valid(player):
		center = Game.plane(player.global_position)
	var angle := randf() * TAU
	var spawn := center + Vector2(cos(angle), sin(angle)) * distance
	enemy.global_position = Game.world(_clamp_inside_arena(spawn, enemy.radius + 10.0))


func _clamp_inside_arena(p: Vector2, margin: float) -> Vector2:
	var r: Rect2 = Game.arena
	return Vector2(
		clampf(p.x, r.position.x + margin, r.end.x - margin),
		clampf(p.y, r.position.y + margin, r.end.y - margin)
	)


# ---------------------------------------------------------------- 事件

func _connect_events() -> void:
	Events.damage_dealt.connect(_on_damage_dealt)
	Events.enemy_died.connect(_on_enemy_died)
	Events.dungeon_enter_requested.connect(_on_dungeon_enter_requested)
	Events.dungeon_exit_requested.connect(_on_dungeon_exit_requested)


## HUD 创建之前 player 已经发出过初始信号，这里补发一次让 UI 同步。
## （Player 在 _ready 里选职业，而 HUD 是之后才 add_child 的，所以必须补发。）
func _push_initial_state() -> void:
	Events.player_health_changed.emit(int(round(player.hp)), int(round(player.max_hp())))
	Events.player_mana_changed.emit(int(round(player.mana)), int(round(player.max_mana())))
	Events.player_stats_changed.emit(player.total_stats())
	Events.player_level_changed.emit(Game.level, Game.xp, Game.xp_to_next_level())
	Events.gold_changed.emit(Game.gold)
	Events.player_skills_changed.emit(player.skills())
	Events.skill_cooldowns_changed.emit({})
	Events.attributes_changed.emit(
		player.attributes.duplicate(),
		player.free_attribute_points(),
		player.attribute_points_spent())
	if player.profession != null:
		Events.player_profession_changed.emit(
			player.profession_id(), player.profession.display_name, player.profession.color)


func _on_enemy_died(enemy_level: int, world_position: Vector3) -> void:
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


func _on_damage_dealt(world_position: Vector3, amount: int, is_crit: bool, on_player: bool) -> void:
	var number := DamageNumber.new()
	number.amount = amount
	if on_player:
		number.color = Color(1.0, 0.35, 0.35)
	elif is_crit:
		number.color = Color(1.0, 0.85, 0.2)
	else:
		number.color = Color(1.0, 1.0, 1.0)
	add_child(number)
	number.global_position = world_position + Vector3(0.0, 30.0, 0.0)
