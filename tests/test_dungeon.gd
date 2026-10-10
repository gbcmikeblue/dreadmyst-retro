extends SceneTree
## M10 地城与 Boss 自测：真正实例化主场景，验证进出地城 / 房间流 / 清房开门 / Boss / 边界恢复。
##
##   godot --headless --path . --script res://tests/test_dungeon.gd
##
## 设计要点：
##   - 所有用例在**同一个 process_frame 回调内同步跑完**（敌人不插帧移动，击杀结果确定）。
##   - 击杀用 `take_damage(1e9)`：`Enemy._die()` 会**同步**置 alive=false 并发出 `enemy_died`，
##     而地城的清房判定正挂在这个信号上，所以不需要等任何帧。
##
## ⚠️ 本脚本是 --script 入口，编译早于 autoload 注册，不能直接写 Events / Game
##    （会 Identifier not found）。这里用 root.get_node_or_null("Events"/"Game") 动态取，
##    并且把 _main / _events / _game 都声明成 Variant 以免静态类型分析卡住动态属性访问。

var _main: Variant = null
var _events: Variant = null
var _game: Variant = null
var _player = null
## 进入地城前的竞技场边界，用于验证离开后是否还原
var _arena_before: Rect2 = Rect2()
var _failed: bool = false
var _frame: int = 0
var _log: Array[String] = []


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("FAIL: 无法加载 res://scenes/main.tscn")
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame < 3:
		return
	_player = _first("player")
	_events = root.get_node_or_null("Events")
	_game = root.get_node_or_null("Game")
	if _player == null or _events == null or _game == null:
		print("FAIL: 缺少玩家 / Events / Game")
		quit(1)
		return
	_run()
	_report()
	quit(1 if _failed else 0)


# ---------------------------------------------------------------- 用例

func _run() -> void:
	var def := _case_registry()
	if def == null:
		return
	_case_boss_not_in_wild_pool()
	_case_enter(def)
	_case_clear_first_room(def)
	_case_boss_and_exit(def)
	_case_leave()


## 数据层：地城定义完整，Boss 原型存在且标记正确。
func _case_registry() -> DungeonDef:
	var ids := DungeonRegistry.ids()
	_log.append("地城列表 = %s" % str(ids))
	_check(not ids.is_empty(), "应至少有一间地城")
	if ids.is_empty():
		return null
	var def := DungeonRegistry.get_dungeon(ids[0])
	_check(def.room_count >= 2, "房间数应 >= 2（否则谈不上「房间流」）")
	_check(def.room_size.x > 0.0 and def.room_size.y > 0.0, "房间尺寸应 > 0")
	_check(not def.boss_id.is_empty(), "地城应配置 Boss")
	_check(def.enemy_count_for_room(0) > 0, "第 0 间房应有怪（否则首个房间直接算清空）")
	_log.append("地城 %s：房间 %d 间，尺寸 %s，每房怪数 %s，Boss=%s" % [
		def.id, def.room_count, def.room_size, str(def.enemies_per_room), def.boss_id])

	var boss_arch := EnemyRegistry.get_archetype(def.boss_id)
	_check(boss_arch != null, "Boss 原型 '%s' 应存在于 enemies.json" % def.boss_id)
	if boss_arch != null:
		_log.append("Boss 原型 %s：is_boss=%s  spawn_weight=%s  hp(10)=%.0f" % [
			boss_arch.display_name, boss_arch.is_boss, boss_arch.spawn_weight,
			boss_arch.compute_hp(10)])
		_check(boss_arch.is_boss, "Boss 原型应标记 is_boss = true")
		_check(boss_arch.spawn_weight <= 0.0, "Boss 的 spawn_weight 应为 0（不进野外池）")
	return def


## Boss 不能出现在野外加权刷怪池里。
func _case_boss_not_in_wild_pool() -> void:
	var boss_hits := 0
	for i in range(300):
		var arch: EnemyArchetype = EnemyRegistry.pick_weighted()
		if arch != null and arch.is_boss:
			boss_hits += 1
	_log.append("pick_weighted × 300 抽到 Boss 次数 = %d（期望 0）" % boss_hits)
	_check(boss_hits == 0, "野外刷怪不应抽到 Boss")


## 进入地城：边界切换、房间/门/怪/Boss 全部就位、玩家被传送进房。
func _case_enter(def: DungeonDef) -> void:
	_arena_before = _game.arena
	_events.emit_signal("dungeon_enter_requested", def.id)

	var dungeon = _main.dungeon
	_check(dungeon != null, "进入地城后 main.dungeon 应非空")
	if dungeon == null:
		return
	_check(_game.in_dungeon, "Game.in_dungeon 应为 true")
	_check(_game.dungeon_id == def.id, "Game.dungeon_id 应为 %s" % def.id)
	_check(_game.arena == def.bounds(dungeon.origin), "Game.arena 应换成地城范围")
	_check(dungeon.rooms.size() == def.room_count,
		"应生成 %d 个房间，实际 %d" % [def.room_count, dungeon.rooms.size()])
	_check(dungeon.doors.size() == def.room_count - 1,
		"应有 %d 扇门，实际 %d" % [def.room_count - 1, dungeon.doors.size()])

	var expected := 0
	for i in range(def.room_count):
		expected += def.enemy_count_for_room(i)
	var actual: int = get_nodes_in_group("enemies").size()
	_log.append("进入 %s：房间 %d 间 / 门 %d 扇 / 敌人 %d 只（期望 %d + Boss 1）" % [
		def.display_name, dungeon.rooms.size(), dungeon.doors.size(), actual, expected])
	_check(actual == expected + 1, "地城敌人应为 每房怪数之和 + 1 Boss，实际 %d" % actual)

	# 墙必须真的挡人：地城里应存在 layer 1 的 StaticBody3D（竞技场矮墙是纯视觉）
	var walls := _count_collision_bodies(dungeon)
	_log.append("带碰撞层 1 的 StaticBody3D = %d 个" % walls)
	_check(walls > 0, "地城墙体应有 collision_layer = 1，玩家/怪物才会被挡住")

	_check(_player_in_bounds(), "玩家应被传送进地城范围内")
	_check(dungeon.boss != null, "地城应有 Boss")
	if dungeon.boss != null:
		_log.append("Boss：%s Lv.%d hp=%.0f" % [
			dungeon.boss.archetype.display_name, dungeon.boss.level, dungeon.boss.max_hp])
		_check(dungeon.boss.archetype.is_boss, "地城 Boss 应是 is_boss 原型")
		_check(dungeon.room_enemies(def.room_count - 1).has(dungeon.boss),
			"Boss 应算在最后一间房的怪里（Boss 房清了才开出口）")
	_check(not dungeon.doors[0].is_open, "第 0 间房没清，第一扇门应还没开")
	_check(dungeon.return_portal != null and dungeon.return_portal.active,
		"入口返回传送门应存在且可用")
	_check(dungeon.exit_portal != null and not dungeon.exit_portal.active,
		"出口传送门应存在但未激活")

	# 几何自检：出生点与两个传送门都必须落在**房间内部**。
	# 房间 0 的西墙是封闭的 —— 出生点或返回门若落到墙外，玩家就被隔在屋里出不去了。
	var spawn := Vector2(_player.global_position.x, _player.global_position.z)
	var return_pos := Vector2(dungeon.return_portal.global_position.x,
		dungeon.return_portal.global_position.z)
	var exit_pos := Vector2(dungeon.exit_portal.global_position.x,
		dungeon.exit_portal.global_position.z)
	var room_first: Rect2 = def.room_rect(0, dungeon.origin)
	var room_last: Rect2 = def.room_rect(def.room_count - 1, dungeon.origin)
	_log.append("几何：出生 %s  返回门 %s  出口 %s" % [spawn, return_pos, exit_pos])
	_check(room_first.has_point(spawn), "出生点应在房间 0 内部")
	_check(room_first.has_point(return_pos), "返回传送门应在房间 0 内部（否则被封闭西墙隔在外面）")
	_check(room_last.has_point(exit_pos), "出口传送门应在最后一间房内部")
	_check(spawn.distance_to(return_pos) > 96.0, "出生点不应一进门就触发传送门交互提示")


## 清空第 0 间房 → 第一扇门立刻开。
func _case_clear_first_room(def: DungeonDef) -> void:
	var dungeon = _main.dungeon
	if dungeon == null:
		return
	var enemies: Array = dungeon.room_enemies(0)
	_check(not enemies.is_empty(), "第 0 间房应有怪可供清理")
	if enemies.is_empty():
		return
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			enemy.take_damage(1.0e9)
	_log.append("清空第 0 间房（%d 只）-> room_cleared=%s  door_open=%s  已清 %d 间" % [
		enemies.size(), dungeon.room_cleared(0), dungeon.doors[0].is_open,
		dungeon.cleared_room_count()])
	_check(dungeon.room_cleared(0), "第 0 间房应标记为已清空")
	_check(dungeon.doors[0].is_open, "清空后第一扇门应开启")
	_check(dungeon.cleared_room_count() == 1, "此时应只有 1 间房被清空")


## 打完 Boss 房 → Boss 死亡、发通关奖励、出口开启、全部房间清空。
func _case_boss_and_exit(def: DungeonDef) -> void:
	var dungeon = _main.dungeon
	if dungeon == null or dungeon.boss == null:
		return
	var last := def.room_count - 1
	var gold_before: int = _game.gold

	for enemy in dungeon.room_enemies(last):
		if is_instance_valid(enemy) and enemy.is_alive():
			enemy.take_damage(1.0e9)

	# 中间房间也要清掉，才能验证「全部房间清空」与出口开启的联动
	for i in range(1, last):
		for enemy in dungeon.room_enemies(i):
			if is_instance_valid(enemy) and enemy.is_alive():
				enemy.take_damage(1.0e9)

	var gold_after: int = _game.gold
	_log.append("清空 Boss 房：room_cleared=%s  Boss 存活=%s  金币 %d -> %d（奖励 %d）" % [
		dungeon.room_cleared(last), dungeon.boss.is_alive(), gold_before, gold_after,
		def.reward_gold])
	_check(not dungeon.boss.is_alive(), "Boss 应已被击败")
	_check(dungeon.room_cleared(last), "Boss 房应标记为已清空")
	_check(dungeon.cleared_room_count() == def.room_count, "全部房间都应已清空")
	_check(gold_after - gold_before >= def.reward_gold, "击败 Boss 应发通关金币奖励")
	_check(dungeon.exit_portal.active, "清空后出口传送门应激活")


## 离开地城：边界还原、地城节点释放、玩家回到营地、野外重新刷怪。
func _case_leave() -> void:
	_events.emit_signal("dungeon_exit_requested")
	var enemies_after: int = get_nodes_in_group("enemies").size()
	_log.append("离开地城：in_dungeon=%s  arena=%s  dungeon 节点=%s  野外敌人=%d 只" % [
		_game.in_dungeon, _game.arena, _main.dungeon, enemies_after])
	_check(not _game.in_dungeon, "离开后 Game.in_dungeon 应为 false")
	_check(_game.dungeon_id == "", "离开后 dungeon_id 应清空")
	_check(_game.arena == _arena_before, "离开后边界应还原成进入前的竞技场范围")
	_check(_main.dungeon == null, "离开后 main.dungeon 应置空")
	_check(_player_in_bounds(), "玩家应回到竞技场范围内")
	_check(enemies_after > 0, "回到原野后应重新刷出野怪")


# ---------------------------------------------------------------- 工具

## 递归统计带碰撞层 1 的 StaticBody3D（墙 / 门）。
func _count_collision_bodies(node: Node) -> int:
	var total := 0
	if node is StaticBody3D and (node.collision_layer & 1) != 0:
		total += 1
	for child in node.get_children():
		total += _count_collision_bodies(child)
	return total


func _player_in_bounds() -> bool:
	var arena: Rect2 = _game.arena
	var p := Vector2(_player.global_position.x, _player.global_position.z)
	return arena.has_point(p)


func _first(group: String) -> Variant:
	# 先赋给无类型 Array，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var nodes: Array = get_nodes_in_group(group)
	return null if nodes.is_empty() else nodes[0]


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		_log.append("  FAIL: %s" % msg)


func _report() -> void:
	print("[dungeon] 帧数 = ", _frame)
	for line in _log:
		print("     ", line)
	if _failed:
		print("========== 地城自测失败 ==========")
	else:
		print("========== 地城自测通过 ==========")
