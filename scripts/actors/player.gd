class_name Player
extends CharacterBody3D
## 玩家角色：移动 / 冲刺 / 职业与技能 / 生命与蓝量 / 装备属性加成。
##
## 玩法逻辑（距离、朝向夹角）全部在 Vector2「玩法平面」上计算，
## 只在写入 velocity 与位置时转成 Vector3，所以技能判定等逻辑与 2D 版完全一致。
## 视觉：billboard 精灵（程序化占位贴图，接入真美术后无需改代码）。
##
## M7 起：属性来自「职业」（data/professions.json），攻击由「技能」（data/skills.json）驱动。
## 每个技能有自己的冷却 / 耗蓝 / 伤害倍率 / 射程 / 扇角，普攻 = 技能槽 0，大招 = 技能槽 1。
##
## M8 起：升级给自由属性点，投入 5 个属性（data/attributes.json）后按各自的 per_point
## 汇总进 total_stats()。属性点是「角色」级成长，转职不会重置。

## 职业 / 技能数据缺失时的兜底属性。正常路径走 Profession.base_stats。
const FALLBACK_STATS := {
	"attack": 10.0,
	"max_hp": 120.0,
	"armor": 0.0,
	"crit": 0.05,
	"speed": 235.0,
	"max_mana": 60.0,
	"mana_regen": 4.0,
}

## 职业注册表读不到任何数据时的兜底职业 id。
const DEFAULT_PROFESSION := "warrior"

const ATTACK_ANIM_TIME := 0.18     # 技能挥砍动画时长（秒）
const DASH_SPEED := 780.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 1.1
const REST_HP_REGEN := 0.6         # 每秒回血（脱战简化实现）

const BODY_RADIUS := 15.0          # 碰撞圆柱半径
const BODY_HEIGHT := 34.0          # 碰撞圆柱高度
const SPRITE_PIXELS := 64          # 占位贴图分辨率
const SPRITE_WORLD_HEIGHT := 44.0  # 精灵在世界中的高度

## 当前职业（Profession，来自 data/professions.json）
var profession: Profession = null

## GearItem.Slot -> GearItem
var equipment: Dictionary = {}

## M11 背包：Array[GearItem]，容量由 data/inventory.json 的 backpack_capacity 决定。
## 掉落不再自动穿/自动分解，而是先进背包，由玩家在背包界面里对比后决定穿上或分解。
var backpack: Array = []

## M8 属性加点：属性 id -> 已投入点数（键集合与 data/attributes.json 一致）
var attributes: Dictionary = {}

var hp: float = 0.0
var mana: float = 0.0
var facing: Vector2 = Vector2.RIGHT
var dead: bool = false

## {skill_id: 剩余冷却秒数}
var _cooldowns: Dictionary = {}
## 当前职业的技能（Array[SkillDef]），约定下标 0 = 普攻、1 = 大招
var _skills: Array = []
## 正在播放挥砍动画的技能槽下标
var _active_slot: int = 0
var _attack_anim: float = 0.0
var _dash_cd: float = 0.0
var _dash_time: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _hit_flash: float = 0.0
## 上一帧是否有冷却在走。用于在冷却全部走完时补发一次「已清空」
var _had_cooldowns: bool = false

## M8：累计可分配属性点 = (等级 - 1) × 每级点数。等级由 player_level_changed 推来，
## 不额外存一份「已发点数」，避免与 Game.level 双重记账。
var _points_total: int = 0

var _sprite: Sprite3D
var _marker: MeshInstance3D
## 每个技能槽一个弧光网格，下标与 _skills 对齐
var _arcs: Array = []
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
	set_profession(_default_profession_id())
	_init_attributes()
	_update_visuals()

	# 等级 -> 可分配属性点：Game 是等级的唯一来源，Player 只做推导
	Events.player_level_changed.connect(_on_level_changed)
	# 加点界面 -> 属性点投入：UI 只发请求，实际动作在 Player 里做
	Events.attribute_allocate_requested.connect(_on_allocate_requested)
	# M11 背包 / 商店 -> 入包 / 装备 / 分解（同样只收请求，不反向引用任何 UI）
	Events.backpack_add_requested.connect(_on_backpack_add_requested)
	Events.backpack_equip_requested.connect(_on_backpack_equip_requested)
	Events.backpack_sell_requested.connect(_on_backpack_sell_requested)
	Events.backpack_optimize_requested.connect(_on_backpack_optimize_requested)

	hp = max_hp()
	mana = max_mana()
	_emit_mana()
	Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))
	Events.player_stats_changed.emit(total_stats())
	Events.skill_cooldowns_changed.emit({})
	_emit_attributes()
	_emit_backpack()


func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	_attack_anim = maxf(0.0, _attack_anim - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_dash_time = maxf(0.0, _dash_time - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)

	if dead:
		velocity = Vector3.ZERO
		move_and_slide()
		_update_visuals()
		return

	# 加点界面等模态 UI 打开时冻结操作：否则点「+」按钮会同时触发普攻 / 移动
	# （按钮只拦 GUI 事件，拦不住 Input.is_action_pressed 这种轮询式读输入）
	if _ui_blocking():
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

	var speed: float = total_stats().get("speed", FALLBACK_STATS["speed"])
	var move2: Vector2
	if _dash_time > 0.0:
		move2 = _dash_dir * DASH_SPEED
	else:
		move2 = input * speed
	velocity = Vector3(move2.x, 0.0, move2.y)

	# 技能输入：空格 / 左键按住 = 普攻（槽 0，可长按连击）；1/2 = 槽 0 / 槽 1
	if Input.is_action_pressed("attack"):
		cast_slot(0)
	if Input.is_action_just_pressed("skill_1"):
		cast_slot(0)
	if Input.is_action_just_pressed("skill_2"):
		cast_slot(1)

	move_and_slide()
	_clamp_to_arena()
	_update_visuals()
	_try_profession_switch()

	# 简化脱战回血 / 回蓝
	if hp < max_hp():
		hp = minf(max_hp(), hp + REST_HP_REGEN * delta)
		Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))
	if mana < max_mana():
		mana = minf(max_mana(), mana + float(total_stats().get("mana_regen", 0.0)) * delta)
		_emit_mana()


# ---------------------------------------------------------------- 属性

func max_hp() -> float:
	return float(total_stats().get("max_hp", FALLBACK_STATS["max_hp"]))


func max_mana() -> float:
	return float(total_stats().get("max_mana", FALLBACK_STATS["max_mana"]))


## 基础属性（职业基础，缺职业时用兜底）+ 属性点加成（M8）+ 所有装备词条的汇总。
func total_stats() -> Dictionary:
	var result: Dictionary = FALLBACK_STATS.duplicate(true)
	if profession != null:
		for key in profession.base_stats:
			result[key] = float(profession.base_stats[key])
	var attribute_bonus := AttributeRegistry.bonus_for_all(attributes)
	for key in attribute_bonus:
		result[key] = float(result.get(key, 0.0)) + float(attribute_bonus[key])
	for slot in equipment:
		var gear: GearItem = equipment[slot]
		if gear == null:
			continue
		for key in gear.stats:
			result[key] = float(result.get(key, 0.0)) + float(gear.stats[key])
	return result


# ---------------------------------------------------------------- 属性加点（M8）

## 初始化属性表：按 data/attributes.json 的顺序把每个属性置 0。
## 顺序与注册表一致，加点界面直接按同一顺序渲染，无需再排一次。
func _init_attributes() -> void:
	attributes.clear()
	for id in AttributeRegistry.ids():
		attributes[id] = 0


func attribute_points(id: String) -> int:
	return int(attributes.get(id, 0))


func attribute_points_spent() -> int:
	var total := 0
	for id in attributes:
		total += int(attributes[id])
	return total


## 剩余可分配点数 = 等级累计点数 - 已投入点数。
func free_attribute_points() -> int:
	return maxi(0, _points_total - attribute_points_spent())


## 属性 id 的定义（供 UI 取名字 / 颜色 / 上限）。找不到返回 null。
func attribute_def(id: String) -> AttributeDef:
	return AttributeRegistry.get_attribute(id)


## 投入 points 点到属性 id。点数不足 / 已满级 / 未知属性时返回 false，且不改动任何状态。
func allocate_attribute(id: String, points: int = 1) -> bool:
	if points <= 0:
		return false
	var attr := AttributeRegistry.get_attribute(id)
	if attr == null:
		push_warning("Player: 未知属性 '%s'" % id)
		return false
	# 先判点数不足、再判满级，这样满级被拒时剩余点数仍 > 0，UI 能区分两种红字提示
	if points > free_attribute_points():
		Events.toast.emit("属性点不足（剩余 %d）" % free_attribute_points(),
			Color(1.0, 0.72, 0.35))
		return false
	var current := attribute_points(id)
	if attr.max_points > 0 and current + points > attr.max_points:
		Events.toast.emit("%s 已满级" % attr.display_name, attr.color)
		return false
	attributes[id] = current + points
	_on_attributes_changed()
	return true


## 分配后重算派生属性。上限提高时只做向下钳制、不自动补满，避免「加点」变成回血手段。
func _on_attributes_changed() -> void:
	hp = clampf(hp, 0.0, max_hp())
	mana = clampf(mana, 0.0, max_mana())
	_emit_attributes()
	Events.player_stats_changed.emit(total_stats())
	Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))
	_emit_mana()


func _emit_attributes() -> void:
	Events.attributes_changed.emit(
		attributes.duplicate(), free_attribute_points(), attribute_points_spent())


## 加点界面发来的请求（UI 不认识 Player，只发信号）。
func _on_allocate_requested(attribute_id: String, points: int) -> void:
	allocate_attribute(attribute_id, points)


## Game 广播等级变化时重算累计点数（等级是唯一来源，这里只做推导与广播）。
func _on_level_changed(level: int, _xp: int, _xp_to_next: int) -> void:
	var total := maxi(0, level - 1) * AttributeRegistry.free_points_per_level()
	if total == _points_total:
		return
	_points_total = total
	_emit_attributes()


## 是否有模态 UI 打开（加点界面）。打开时冻结移动与攻击。
func _ui_blocking() -> bool:
	return not get_tree().get_nodes_in_group("modal_ui").is_empty()


# ---------------------------------------------------------------- 职业

func profession_id() -> String:
	return profession.id if profession != null else ""


## 当前职业的技能（Array[SkillDef]），下标 0 = 普攻、1 = 大招。
func skills() -> Array:
	return _skills


## 切换职业：重算属性、重置蓝量与冷却、重建技能弧光，并广播给 UI。
## 原型期由 main.gd 的 F1/F2/F3 调用；正式版应改为角色创建流程。
func set_profession(id: String) -> void:
	var prof := ProfessionRegistry.get_profession(id)
	if prof == null:
		push_warning("Player: 找不到职业 '%s'，回退到 %s" % [id, DEFAULT_PROFESSION])
		prof = ProfessionRegistry.get_profession(DEFAULT_PROFESSION)
	profession = prof
	_skills = profession.skills() if profession != null else []

	_cooldowns.clear()
	for skill in _skills:
		_cooldowns[skill.id] = 0.0

	hp = clampf(hp, 0.0, max_hp())
	mana = max_mana()
	_attack_anim = 0.0

	_rebuild_skill_arcs()
	_refresh_sprite()
	_emit_profession()
	_emit_skills()
	_emit_mana()
	Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))
	Events.player_stats_changed.emit(total_stats())
	Events.skill_cooldowns_changed.emit(_cooldowns.duplicate())
	if profession != null:
		Events.toast.emit("职业：%s" % profession.display_name, profession.color)


func _default_profession_id() -> String:
	var ids := ProfessionRegistry.ids()
	return ids[0] if not ids.is_empty() else DEFAULT_PROFESSION


## 原型期的切职业快捷键：F1/F2/F3 依次对应注册表里前 3 个职业。
## 正式版应改为角色创建流程，这里的目的只是让三个职业立刻可试。
func _try_profession_switch() -> void:
	var ids := ProfessionRegistry.ids()
	for i in range(mini(ids.size(), 3)):
		var action := "profession_%d" % (i + 1)
		if not InputMap.has_action(action):
			continue
		if Input.is_action_just_pressed(action):
			set_profession(ids[i])
			return


func _emit_profession() -> void:
	if profession == null:
		Events.player_profession_changed.emit("", "未知职业", Color.WHITE)
		return
	Events.player_profession_changed.emit(profession.id, profession.display_name, profession.color)


func _emit_skills() -> void:
	Events.player_skills_changed.emit(_skills.duplicate())


func _emit_mana() -> void:
	Events.player_mana_changed.emit(int(round(mana)), int(round(max_mana())))


# ---------------------------------------------------------------- 技能

## 施放指定技能槽（0 = 普攻，1 = 大招）。成功返回 true。
func cast_slot(slot: int) -> bool:
	if slot < 0 or slot >= _skills.size():
		return false
	var skill: SkillDef = _skills[slot]
	return cast_skill(skill.id)


## 施放指定 id 的技能。死亡 / 冷却未走完 / 蓝不足时返回 false，且不消耗资源。
func cast_skill(skill_id: String) -> bool:
	if dead:
		return false
	var skill: SkillDef = SkillRegistry.get_skill(skill_id)
	if skill == null:
		return false
	if float(_cooldowns.get(skill_id, 0.0)) > 0.0:
		return false
	if mana < skill.mana_cost:
		Events.toast.emit("法力不足：%s 需要 %d 点" % [
			skill.display_name, int(ceil(skill.mana_cost))], Color(0.55, 0.70, 1.0))
		return false

	_cooldowns[skill_id] = skill.cooldown
	mana = maxf(0.0, mana - skill.mana_cost)
	_attack_anim = ATTACK_ANIM_TIME
	_active_slot = maxi(0, _skills.find(skill))
	_apply_skill_damage(skill)

	_emit_mana()
	Events.skill_cooldowns_changed.emit(_cooldowns.duplicate())
	return true


## 冷却每帧递减。有任何冷却在走（或刚好走完）时广播一次状态给 UI，空闲时不发信号。
func _tick_cooldowns(delta: float) -> void:
	var any_active := false
	for skill_id in _cooldowns:
		var remain := float(_cooldowns[skill_id])
		if remain <= 0.0:
			continue
		remain = maxf(0.0, remain - delta)
		_cooldowns[skill_id] = remain
		if remain > 0.0:
			any_active = true
	if any_active or _had_cooldowns:
		_had_cooldowns = any_active
		Events.skill_cooldowns_changed.emit(_cooldowns.duplicate())


## 按技能自身的扇形参数判定命中，返回命中敌人数。
## 判定全部在 Vector2 玩法平面上做（距离 + 朝向夹角），不用 Area3D，行为可预测。
func _apply_skill_damage(skill: SkillDef) -> int:
	var stats := total_stats()
	var attack_power: float = float(stats.get("attack", 0.0))
	var crit_chance: float = clampf(float(stats.get("crit", 0.0)), 0.0, 0.9)

	var my_plane := Game.plane(global_position)
	var hits := 0
	# 用无类型 Array 承载，避免静态类型分析把元素推断为 Node 而报「找不到成员」
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		var to_enemy: Vector2 = Game.plane(enemy.global_position) - my_plane
		if to_enemy.length() > skill.cast_range:
			continue
		# half_angle >= PI 视为 360°（旋风斩这类），不做夹角限制
		if not skill.is_full_circle() and absf(facing.angle_to(to_enemy)) > skill.half_angle:
			continue
		var is_crit := randf() < crit_chance
		var damage := attack_power * skill.damage_mult * (1.6 if is_crit else 1.0)
		damage *= randf_range(0.9, 1.1)
		enemy.take_damage(damage, is_crit)
		hits += 1
	return hits


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
	mana = max_mana()
	# 复活点由 Game 维护（竞技场 = 营地中心；地城内 = 入口）：
	# 直接用 Game.arena.get_center() 在副本里可能落在走廊/墙里。
	global_position = Game.world(Game.respawn_point)
	Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))
	_emit_mana()
	Events.toast.emit("你已复活", Color(0.6, 1.0, 0.6))


# ---------------------------------------------------------------- 装备 / 背包（M11）

## 由 GearPickup 调用：掉落的装备先进背包；背包满了才当场自动分解（避免掉落凭空消失）。
func receive_loot(gear: GearItem) -> void:
	if gear == null:
		return
	if add_to_backpack(gear):
		Events.toast.emit("拾取 %s（%s）→ 背包" % [gear.item_name, gear.slot_name()],
			gear.rarity_color())
	else:
		var value := sell_price(gear)
		Game.add_gold(value)
		Events.toast.emit("背包已满，自动分解 %s（+%d 金币）" % [gear.item_name, value],
			gear.rarity_color())
	Events.loot_picked_up.emit(gear)


func backpack_capacity() -> int:
	return InventoryConfig.load_default().backpack_capacity


func backpack_full() -> bool:
	return backpack.size() >= backpack_capacity()


func backpack_item(index: int) -> GearItem:
	if index < 0 or index >= backpack.size():
		return null
	return backpack[index]


## 一件装备分解能换多少金币（与背包界面显示同一口径，公式在数据层）。
func sell_price(gear: GearItem) -> int:
	return InventoryConfig.load_default().sell_price_for(gear)


## 入包。背包已满返回 false（调用方决定是丢弃、自动分解还是拒绝购买）。
func add_to_backpack(gear: GearItem) -> bool:
	if gear == null or backpack_full():
		return false
	backpack.append(gear)
	_emit_backpack()
	return true


## 把背包第 index 件穿上：换下来的旧装备**回到背包**，不会凭空消失。
func equip_from_backpack(index: int) -> bool:
	var gear := backpack_item(index)
	if gear == null:
		return false
	var previous: GearItem = equipment.get(gear.slot)
	backpack.remove_at(index)
	equipment[gear.slot] = gear
	if previous != null:
		backpack.append(previous)

	# 上限变化时只做向下钳制，不自动补满（与加点一致）
	hp = clampf(hp, 0.0, max_hp())
	mana = clampf(mana, 0.0, max_mana())
	Events.equipment_changed.emit(equipment)
	Events.player_stats_changed.emit(total_stats())
	Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))
	_emit_mana()
	_emit_backpack()
	Events.toast.emit("已装备 %s（%s）" % [gear.item_name, gear.slot_name()], gear.rarity_color())
	return true


## 分解背包第 index 件换金币。
func sell_from_backpack(index: int) -> bool:
	var gear := backpack_item(index)
	if gear == null:
		return false
	backpack.remove_at(index)
	var value := sell_price(gear)
	Game.add_gold(value)
	_emit_backpack()
	Events.toast.emit("分解 %s，获得 %d 金币" % [gear.item_name, value], gear.rarity_color())
	return true


## 一键换装：每个部位挑背包里评分最高的那件，只要比身上的好就换上。返回换了几件。
func optimize_equipment() -> int:
	var changed := 0
	for slot in GearItem.SLOT_ORDER:
		var best_index := -1
		var best_score := 0.0
		for i in range(backpack.size()):
			var item: GearItem = backpack[i]
			if item == null or item.slot != slot:
				continue
			var score := item.power_score()
			if score > best_score:
				best_score = score
				best_index = i
		if best_index < 0:
			continue
		var current: GearItem = equipment.get(slot)
		if current != null and best_score <= current.power_score():
			continue
		if equip_from_backpack(best_index):
			changed += 1
	if changed > 0:
		Events.toast.emit("一键换装：换上了 %d 件" % changed, Color(0.80, 0.90, 1.0))
	return changed


## UI -> 事件总线 -> Player：UI 不引用 Player，只发请求。
func _on_backpack_add_requested(gear) -> void:
	if gear is GearItem and add_to_backpack(gear):
		return
	Events.toast.emit("背包已满，无法放入", Color(1.0, 0.72, 0.35))


func _on_backpack_equip_requested(index: int) -> void:
	equip_from_backpack(index)


func _on_backpack_sell_requested(index: int) -> void:
	sell_from_backpack(index)


func _on_backpack_optimize_requested() -> void:
	optimize_equipment()


func _emit_backpack() -> void:
	Events.backpack_changed.emit(backpack.duplicate(), backpack_capacity())


# ---------------------------------------------------------------- 存档（M13）

## 导出角色状态给存档。等级 / 经验 / 金币归属 Game，由 main.gd 单独收集。
func export_state() -> Dictionary:
	return {
		"profession": profession_id(),
		"hp": hp,
		"mana": mana,
		"attributes": attributes.duplicate(),
		"equipment": equipment.duplicate(),
		"backpack": backpack.duplicate(),
	}


## 灌入存档状态并重新广播。语义层面的兜底都在这里：
## 未知职业 id → 默认职业（set_profession 内部兜底）；未知属性 id → 忽略并 Warning；
## 背包超过容量 / 非 GearItem → 丢弃；hp/mana 缺省（<0）→ 按满值。
func import_state(state: Dictionary) -> void:
	var prof_id := String(state.get("profession", ""))
	set_profession(prof_id if not prof_id.is_empty() else _default_profession_id())

	# 属性点：以注册表为准重建键集合，存档里的陌生 id 一律丢弃
	attributes.clear()
	for id in AttributeRegistry.ids():
		attributes[id] = 0
	var raw_attrs: Variant = state.get("attributes", {})
	if typeof(raw_attrs) == TYPE_DICTIONARY:
		var attrs: Dictionary = raw_attrs
		for key in attrs:
			var id := String(key)
			if not attributes.has(id):
				push_warning("Player: 存档里的属性 '%s' 不存在，已忽略" % id)
				continue
			attributes[id] = maxi(0, int(attrs[key]))

	equipment.clear()
	var raw_equip: Variant = state.get("equipment", {})
	if typeof(raw_equip) == TYPE_DICTIONARY:
		var equip_dict: Dictionary = raw_equip
		for slot in equip_dict:
			var gear: Variant = equip_dict[slot]
			if gear is GearItem:
				equipment[int(slot)] = gear

	backpack.clear()
	var raw_bag: Variant = state.get("backpack", [])
	if raw_bag is Array:
		var bag: Array = raw_bag
		for gear in bag:
			if gear is GearItem and backpack.size() < backpack_capacity():
				backpack.append(gear)

	# hp / mana 必须在属性与装备灌完之后算 —— max_hp() 依赖 total_stats()
	var saved_hp := float(state.get("hp", -1.0))
	var saved_mana := float(state.get("mana", -1.0))
	hp = max_hp() if saved_hp < 0.0 else clampf(saved_hp, 0.0, max_hp())
	mana = max_mana() if saved_mana < 0.0 else clampf(saved_mana, 0.0, max_mana())

	_rebroadcast_state()


## 回到「全新角色」：默认职业、0 属性点、空装备空背包、满血满蓝。
func reset_state() -> void:
	set_profession(_default_profession_id())
	for id in attributes:
		attributes[id] = 0
	equipment.clear()
	backpack.clear()
	hp = max_hp()
	mana = max_mana()
	_rebroadcast_state()


## 载入 / 重置之后把全部状态重新广播一遍（UI 若在其后才创建，main 还会补发一次）。
func _rebroadcast_state() -> void:
	_cooldowns.clear()
	for skill in _skills:
		_cooldowns[skill.id] = 0.0
	_attack_anim = 0.0
	_emit_profession()
	_emit_skills()
	_emit_backpack()
	_emit_attributes()
	Events.equipment_changed.emit(equipment)
	Events.player_stats_changed.emit(total_stats())
	Events.player_health_changed.emit(int(round(hp)), int(round(max_hp())))
	_emit_mana()
	Events.skill_cooldowns_changed.emit(_cooldowns.duplicate())


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

	# 技能弧光不在这里建：每个技能槽一个网格，由 _rebuild_skill_arcs() 在转职时重建
	# （不同技能的射程 / 扇角 / 颜色都不同，共用一个网格无法表达）。

	# 冲刺残影
	_dash_fx = SpriteFactory.flat_disc(BODY_RADIUS * 1.5, Color(0.6, 0.8, 1.0, 0.25), 0.08)
	_dash_fx.visible = false
	add_child(_dash_fx)


## 按当前职业换精灵贴图（真素材缺失 / 路径为空时自动退回程序化占位贴图）。
## ⚠️ 必须重算 pixel_size：占位贴图 64px、真素材 128px，沿用旧值会让角色尺寸差一倍。
func _refresh_sprite() -> void:
	if _sprite == null:
		return
	var path: String = profession.sprite_path if profession != null else ""
	var tex: Texture2D = SpriteFactory.actor_texture(path, SPRITE_PIXELS,
		Color(0.86, 0.86, 0.96), Color(0.14, 0.14, 0.20))
	_sprite.texture = tex
	_sprite.pixel_size = SPRITE_WORLD_HEIGHT / maxf(1.0, float(tex.get_height()))


## 按当前职业技能重建弧光网格（转职时调用，运行时零分配）。
func _rebuild_skill_arcs() -> void:
	for old in _arcs:
		if is_instance_valid(old):
			old.queue_free()
	_arcs.clear()
	for skill in _skills:
		var arc := SpriteFactory.arc_fx(
			skill.cast_range * 0.30,
			skill.cast_range,
			skill.half_angle,
			24,
			Color(skill.color.r, skill.color.g, skill.color.b, 0.75))
		arc.position.y = 0.12
		arc.visible = false
		add_child(arc)
		_arcs.append(arc)


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

	var playing := _attack_anim > 0.0
	for i in range(_arcs.size()):
		var arc: MeshInstance3D = _arcs[i]
		if arc == null or not is_instance_valid(arc):
			continue
		if playing and i == _active_slot:
			var p := 1.0 - _attack_anim / ATTACK_ANIM_TIME
			var s := lerpf(0.80, 1.06, p)
			arc.visible = true
			arc.rotation.y = -facing.angle()
			arc.scale = Vector3(s, 1.0, s)
		else:
			arc.visible = false

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
