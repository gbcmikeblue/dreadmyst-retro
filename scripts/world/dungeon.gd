class_name Dungeon
extends Node3D
## 一间地城的运行时实例：房间流（按房刷怪 → 清房开门 → Boss 房）+ 出入口传送门 + 通关奖励。
##
## 挂载方式：`main.gd` 在**远离竞技场**的平面原点（`origin`）上创建本节点，
## 地城几何用 `origin + def.room_rect(i, origin)` 算出来，因此不会与竞技场地面重叠；
## 进出地城只需切换 `Game.arena` 与玩家位置，不需要销毁竞技场。
##
## 与外界的通信只走 `Events`：
##   - 进入 / 离开由 `main.gd` 监听 `dungeon_enter_requested` / `dungeon_exit_requested` 执行
##   - 本节点广播 `dungeon_room_cleared` / `boss_spawned` / `boss_health_changed` / `boss_defeated`
##
## Boss 血条为什么不给 Enemy 加专属信号：全场地城只有 1 个 Boss，
## 在 `_process` 里轮询它的血量（值变了才发信号）比给 Enemy 装一套「我是 Boss 要上报」的
## 机制更省事，也不会把 Boss 概念泄漏到通用敌人逻辑里（Enemy 只多了一个 `is_boss` 表现开关）。

var def: DungeonDef = null
## 地城原点（玩法平面坐标）。调用方应给一个远离竞技场的值。
var origin: Vector2 = Vector2.ZERO
## 进入时的玩家等级（决定地城内敌人等级）
var base_level: int = 1

var rooms: Array = []           # Array[DungeonRoom]
var doors: Array = []           # Array[DungeonDoor]，下标 i = 房间 i 与 i+1 之间那扇门
var boss: Enemy = null
var return_portal: Portal = null
var exit_portal: Portal = null

var _room_enemies: Array = []   # Array[Array]，每个房间的敌人（含 Boss 房里的 Boss）
var _room_cleared: Array = []   # Array[bool]
var _boss_total_hp: int = 0
var _last_boss_hp: int = -1
var _boss_settled: bool = false


## 由 main.gd 在 add_child 之前调用。
func setup(dungeon_def: DungeonDef, dungeon_origin: Vector2, player_level: int) -> void:
	def = dungeon_def
	origin = dungeon_origin
	base_level = maxi(1, player_level)


func _ready() -> void:
	name = "Dungeon"
	if def == null:
		push_error("Dungeon: 未调用 setup()，无法构建地城")
		return

	for i in range(def.room_count):
		_room_enemies.append([])
		_room_cleared.append(false)

	_build_rooms()
	_build_doors()
	_build_portals()
	Events.enemy_died.connect(_on_enemy_died)

	_spawn_room_enemies()
	_spawn_boss()
	# 没有怪的房间（以及没有 Boss 的最后一间）应当立刻算清空，否则门永远不开
	_refresh_rooms()


func _process(_delta: float) -> void:
	_poll_boss_hp()


# ---------------------------------------------------------------- 构建

func _build_rooms() -> void:
	for i in range(def.room_count):
		var room := DungeonRoom.new()
		room.room_index = i
		room.rect = def.room_rect(i, origin)
		room.wall_height = def.wall_height
		room.wall_thickness = def.wall_thickness
		room.door_width = def.door_width
		# 首尾房间只有一侧通向走廊
		room.open_west = i > 0
		room.open_east = i < def.room_count - 1
		room.ground_color = def.ground_color
		room.line_color = def.line_color
		room.wall_color = def.wall_color
		room.accent_color = def.accent_color
		add_child(room)
		rooms.append(room)


func _build_doors() -> void:
	for i in range(maxi(0, def.room_count - 1)):
		var door := DungeonDoor.new()
		door.span = def.door_width
		door.height = def.wall_height
		door.thickness = def.wall_thickness
		door.color = def.accent_color
		var p := def.door_point(i, origin)
		door.position = Vector3(p.x, 0.0, p.y)
		add_child(door)
		doors.append(door)


func _build_portals() -> void:
	return_portal = _make_portal("返回原野", true)
	# 放在房间 0 内部、出生点西侧 110 处：房间 0 西墙是封闭的，放到墙外就点不到了
	var entrance := def.entrance_point(origin)
	return_portal.position = Vector3(entrance.x - 110.0, 0.0, entrance.y)
	add_child(return_portal)

	exit_portal = _make_portal("离开地城", false)
	var exit_point := def.exit_point(origin)
	exit_portal.position = Vector3(exit_point.x, 0.0, exit_point.y)
	add_child(exit_portal)


func _make_portal(label: String, active: bool) -> Portal:
	var portal := Portal.new()
	portal.mode = Portal.Mode.EXIT
	portal.dungeon_id = def.id
	portal.label = label
	portal.active = active
	portal.color = def.accent_color
	return portal


func _spawn_room_enemies() -> void:
	for i in range(def.room_count):
		var count := def.enemy_count_for_room(i)
		for n in range(count):
			var arch := EnemyRegistry.pick_weighted()
			if arch == null:
				push_warning("Dungeon: EnemyRegistry 为空，跳过刷怪")
				return
			var enemy := _spawn_enemy(arch, def.enemy_level(base_level, i), _random_room_point(i))
			_room_enemies[i].append(enemy)


func _spawn_boss() -> void:
	if def.boss_id.is_empty():
		return
	var arch := EnemyRegistry.get_archetype(def.boss_id)
	if arch == null:
		push_warning("Dungeon: 找不到 Boss 原型 '%s'" % def.boss_id)
		return
	var last := def.room_count - 1
	var center := def.room_center(last, origin)
	boss = _spawn_enemy(arch, def.boss_level(base_level), center + Vector2(60.0, 0.0))
	_room_enemies[last].append(boss)

	_boss_total_hp = int(round(boss.max_hp))
	_last_boss_hp = _boss_total_hp
	Events.boss_spawned.emit(arch.display_name, boss.level, _boss_total_hp)


func _spawn_enemy(arch: EnemyArchetype, level: int, point: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(level, arch)
	add_child(enemy)
	# 必须先 add_child 才能写 global_position（未入树时 global_transform 无效）
	enemy.global_position = Game.world(point)
	return enemy


## 房间内随机落点（留出墙边距离，且不贴着入口，免得刚进门就被围）。
func _random_room_point(index: int) -> Vector2:
	var rect := def.room_rect(index, origin).grow(-80.0)
	var entrance := def.entrance_point(origin)
	for attempt in range(12):
		var p := Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y))
		if p.distance_to(entrance) > 140.0:
			return p
	return rect.get_center()


# ---------------------------------------------------------------- 房间流

## 重算每个房间的存活数：有怪 → 无怪的瞬间开门并上报。
func _refresh_rooms() -> void:
	for i in range(_room_enemies.size()):
		var alive := 0
		for enemy in _room_enemies[i]:
			if is_instance_valid(enemy) and enemy.is_alive():
				alive += 1
		if alive == 0 and not _room_cleared[i]:
			_room_cleared[i] = true
			_on_room_cleared(i)


func _on_room_cleared(index: int) -> void:
	if index < doors.size():
		doors[index].open()
	Events.dungeon_room_cleared.emit(index, def.room_count)
	if index == def.room_count - 1:
		_activate_exit()


func _activate_exit() -> void:
	if exit_portal == null or exit_portal.active:
		return
	exit_portal.active = true
	Events.toast.emit("地城已清空 —— 出口已开启", def.accent_color)


func cleared_room_count() -> int:
	var n := 0
	for cleared in _room_cleared:
		if cleared:
			n += 1
	return n


## 房间 index 的怪物列表（自测与后续 UI 用；返回内部数组，调用方只读）。
func room_enemies(index: int) -> Array:
	if index < 0 or index >= _room_enemies.size():
		return []
	return _room_enemies[index]


## 房间 index 是否已清空。
func room_cleared(index: int) -> bool:
	if index < 0 or index >= _room_cleared.size():
		return false
	return _room_cleared[index]


# ---------------------------------------------------------------- Boss

func _on_enemy_died(_enemy_level: int, _world_position: Vector3) -> void:
	_refresh_rooms()
	if _boss_settled or boss == null or not is_instance_valid(boss) or boss.is_alive():
		return
	_boss_settled = true
	_grant_boss_rewards()
	Events.boss_defeated.emit(boss.archetype.display_name if boss.archetype != null else "Boss")


## 轮询 Boss 血量：值变了才广播（空闲期零信号，与技能冷却同一思路）。
func _poll_boss_hp() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var hp := int(maxf(0.0, boss.hp))
	if hp == _last_boss_hp:
		return
	_last_boss_hp = hp
	Events.boss_health_changed.emit(hp, _boss_total_hp)


## 通关奖励：金币 + 经验 + 一件保底品质的装备（掉在 Boss 原地）。
func _grant_boss_rewards() -> void:
	Game.add_gold(def.reward_gold)
	Game.add_xp(def.reward_xp)
	Events.toast.emit("击败 Boss！+%d 金币 +%d 经验" % [def.reward_gold, def.reward_xp],
		def.accent_color)
	if def.guaranteed_rarity.is_empty():
		return
	var level := boss.level if boss != null and is_instance_valid(boss) else base_level
	var gear := LootTable.generate(level, def.guaranteed_rarity)
	if gear == null:
		return
	var pickup := GearPickup.new()
	pickup.gear = gear
	add_child(pickup)
	var pos := boss.global_position if boss != null and is_instance_valid(boss) else global_position
	pickup.global_position = pos
