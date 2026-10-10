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

var player: Player
var hud: HUD
## M16 起相机逻辑整体在 CameraRig 里（参数在 data/camera.json）
var camera: CameraRig = null

## 当前地城实例（不在副本里时为 null）
var dungeon: Dungeon = null
## 竞技场里的入口传送门
var arena_portal: Portal = null

## 商店服务（M11）：货架由它持有，背包界面通过 Events 拉取
var shop: Shop = null
## 背包 / 商店界面（M11）
var inventory_panel: InventoryPanel = null

## 存档服务（M13）：文件 IO 在它那儿，状态收集在本节点（唯一同时知道 Game 与 Player 的地方）
var save_service: SaveService = null
## 启动选档界面（M13）
var title_screen: TitleScreen = null
## 开发工具面板（DEV_TOOLS 为 false 时为 null）
var dev_pause: DevPause = null

var _spawn_timer: float = 2.0


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
	# M11 商店服务 + 背包界面（I/B 键开关）
	shop = Shop.new()
	add_child(shop)
	inventory_panel = InventoryPanel.new()
	add_child(inventory_panel)

	# M13 存档服务（先建，后面的标题界面会立刻来要槽位摘要）
	save_service = SaveService.new()
	add_child(save_service)
	save_service.state_provider = _collect_save
	title_screen = TitleScreen.new()
	add_child(title_screen)

	if DEV_TOOLS:
		dev_pause = DevPause.new()
		add_child(dev_pause)
	_connect_events()
	_push_initial_state()

	for i in range(6):
		_spawn_enemy(randf_range(380.0, 620.0))

	# 最后才开标题界面：此时事件已全部接好（要摘要时有人应答），且欢迎 Toast 留到选完槽位再弹
	_open_title_screen()


func _process(delta: float) -> void:
	# 手动存读要在「副本里直接 return」之前处理，否则在副本里按 F5 会没反应
	# （标题界面期间本函数根本不跑 —— 那时世界是暂停的）
	if Input.is_action_just_pressed("save_game"):
		_manual_save()
	if Input.is_action_just_pressed("load_game"):
		_manual_load()

	# 相机（跟随 / 缩放 / 旋转 / 边界钳制）由 CameraRig 自己每帧处理，这里不用管

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

	camera = CameraRig.new()
	# 必须先入树，才能写 global_position（否则 global_transform 无效）
	add_child(camera)
	camera.debug_report = DEV_TOOLS
	camera.snap()               # 立刻对准玩家（rig 自己读 Game.get_player()）
	camera.make_current()


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

	# 复活点跟着进副本变（否则死在副本里会复活到地城包围盒中心，可能卡在走廊/墙里）
	Game.respawn_point = def.entrance_point(DUNGEON_ORIGIN)

	# 玩家与相机一起瞬移：否则相机会从竞技场一路平移过去，画面很怪
	var entrance := def.entrance_point(DUNGEON_ORIGIN)
	player.global_position = Game.world(entrance)
	camera.snap()

	Events.dungeon_entered.emit(def.display_name, def.room_count)
	Events.toast.emit("进入 %s（%d 个房间）" % [def.display_name, def.room_count],
		def.accent_color)


func _on_dungeon_exit_requested() -> void:
	if not Game.in_dungeon:
		return
	Game.in_dungeon = false
	Game.dungeon_id = ""
	Game.arena = Game.ARENA_HOME
	Game.respawn_point = Game.ARENA_HOME.get_center()

	if dungeon != null and is_instance_valid(dungeon):
		# 地城节点被释放时，它的 Portal._exit_tree 会顺手清掉屏幕上的交互提示
		dungeon.queue_free()
	dungeon = null

	if player != null and is_instance_valid(player):
		player.global_position = Game.world(Game.ARENA_HOME.get_center())
	camera.snap()

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


# ---------------------------------------------------------------- 存档（M13）

## 打开标题选档界面：先关掉开发面板（它会解冻世界），再让标题界面暂停世界。
func _open_title_screen() -> void:
	if dev_pause != null:
		dev_pause.set_enabled(false)
	if title_screen != null:
		title_screen.open()


## 在槽位 slot 开始游戏。as_new = true 开新档（覆盖），false 读档。
## 由标题界面的信号调用；自测也直接调它（跳过鼠标点击）。
func choose_slot(slot: int, as_new: bool) -> void:
	# 先确保「在营地、不在副本」：读档时地城状态不该跨档残留
	if Game.in_dungeon:
		_on_dungeon_exit_requested()

	save_service.current_slot = slot

	if as_new:
		Game.reset_progress()
		player.reset_state()
		if hud != null:
			hud.kills = 0
			hud.refresh_kills()
		# 新档立刻落盘：否则刚开局就退出的话，槽位还是「空」
		save_service.flush_current()
		Events.toast.emit("在存档 %d 开始新游戏" % slot, Color(0.80, 0.95, 0.80))
	else:
		var data := save_service.load_slot(slot)
		if data == null:
			# 没有档 / 坏档（SaveService 已把坏档改名备份）→ 退化成开新档
			choose_slot(slot, true)
			return
		_apply_save(data)
		Events.toast.emit("已读取存档 %d（%d 级 · %d 金币）" % [slot, Game.level, Game.gold],
			Color(0.80, 0.95, 0.80))

	if title_screen != null:
		title_screen.close()
	if dev_pause != null:
		dev_pause.set_enabled(DEV_TOOLS)
	# 载入时 Player 已经广播过一轮，但 UI 可能是在那之后才同步的，这里再补发一次全量状态
	_push_initial_state()
	Events.toast.emit("欢迎来到 恐惧秘境 Dreadmyst 复刻原型", Color(0.80, 0.72, 1.0))


## 收集当前状态（StateProvider：SaveService 到点写盘时回调它）。
func _collect_save() -> SaveData:
	var data := SaveData.new()
	data.saved_at = Time.get_datetime_string_from_system()
	if hud != null:
		data.kills = hud.kills
	data.level = Game.level
	data.xp = Game.xp
	data.gold = Game.gold
	if player != null and is_instance_valid(player):
		data.profession_id = player.profession_id()
		data.hp = player.hp
		data.mana = player.mana
		data.attributes = player.attributes.duplicate()
		data.equipment = player.equipment.duplicate()
		data.backpack = player.backpack.duplicate()
	return data


## 把存档灌回 Game 与 Player。
func _apply_save(data: SaveData) -> void:
	Game.load_progress(data.level, data.xp, data.gold)
	player.import_state({
		"profession": data.profession_id,
		"hp": data.hp,
		"mana": data.mana,
		"attributes": data.attributes,
		"equipment": data.equipment,
		"backpack": data.backpack,
	})
	if hud != null:
		hud.kills = data.kills
		hud.refresh_kills()
	if data.dropped_backpack_items > 0:
		Events.toast.emit("背包超过容量，丢弃了 %d 件装备" % data.dropped_backpack_items,
			Color(1.0, 0.72, 0.35))


func _manual_save() -> void:
	if save_service.current_slot < 0:
		return
	if save_service.flush_current():
		Events.toast.emit("已保存到存档 %d（F5）" % save_service.current_slot,
			Color(0.80, 0.95, 0.80))


func _manual_load() -> void:
	if save_service.current_slot < 0:
		return
	choose_slot(save_service.current_slot, false)


func _on_save_slots_requested() -> void:
	Events.save_slots_changed.emit(save_service.slot_summaries())


func _on_save_load_requested(slot: int) -> void:
	choose_slot(slot, false)


func _on_save_new_game_requested(slot: int) -> void:
	choose_slot(slot, true)


func _on_save_delete_requested(slot: int) -> void:
	var existed := save_service.delete_slot(slot)
	if existed:
		Events.toast.emit("已删除存档 %d" % slot, Color(0.85, 0.85, 0.90))
	else:
		Events.toast.emit("存档 %d 本来就是空的" % slot, Color(0.85, 0.85, 0.90))
	_on_save_slots_requested()


## 关窗时把待写存档刷出去（防抖可能还没到点）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and save_service != null:
		save_service.flush_current()


# ---------------------------------------------------------------- 构建世界

func _spawn_enemy(distance: float) -> void:
	var archetype := EnemyRegistry.pick_weighted()
	if archetype == null:
		push_warning("EnemyRegistry 为空，跳过本次刷怪")
		return
	var enemy := Enemy.new()
	enemy.setup(maxi(1, Game.level + randi_range(-1, 1)), archetype)
	add_child(enemy)

	# 以玩家为中心刷怪（M16 起相机焦点不再由 main 持有，这里直接用玩家位置）
	var center := Game.arena.get_center()
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
	# M13 存档：标题选档界面的请求
	Events.save_slots_requested.connect(_on_save_slots_requested)
	Events.save_load_requested.connect(_on_save_load_requested)
	Events.save_new_game_requested.connect(_on_save_new_game_requested)
	Events.save_delete_requested.connect(_on_save_delete_requested)


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
	Events.equipment_changed.emit(player.equipment)
	Events.backpack_changed.emit(player.backpack.duplicate(), player.backpack_capacity())
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
