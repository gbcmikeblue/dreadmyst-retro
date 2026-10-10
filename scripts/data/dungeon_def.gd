class_name DungeonDef
extends RefCounted
## 地城定义：房间流布局参数 + 每房怪物数 + Boss + 通关奖励。纯数据、不含表现。
##
## 数据来自 data/dungeon.json，加载器是 DungeonRegistry。
## ⚠️ 数值为自行设计的占位值，待原作资料校准。
##
## 布局约定（只做一条直线的「房间 → 走廊 → 房间」，无分支）：
##   X 轴方向依次排 room_count 个房间，房间之间是 corridor_length 长的走廊，
##   走廊正中放一扇门（清空当前房间后开启）。所有几何计算都在**玩法平面**（Vector2）上做，
##   调用方传入 origin（地城在原野之外的偏移原点），避免与竞技场的地面重叠。

var id: String = ""
var display_name: String = "未知地城"

## 地城内敌人的等级 = 玩家等级 + level_bonus
var level_bonus: int = 2
var room_count: int = 3
## 单个房间的尺寸（X 宽、Z 深），玩法平面单位
var room_size: Vector2 = Vector2(560.0, 480.0)
## 房间之间的走廊长度
var corridor_length: float = 200.0
var wall_height: float = 30.0
var wall_thickness: float = 12.0
## 墙上门洞（走廊出入口）的宽度
var door_width: float = 140.0
## 每个房间的怪物数量，下标 = 房间号；长度不足时沿用最后一个值
var enemies_per_room: Array[int] = []

## Boss 原型 id（data/enemies.json）与等级加成
var boss_id: String = ""
var boss_level_bonus: int = 4

## 通关奖励
var reward_gold: int = 150
var reward_xp: int = 250
## 保底掉落品质 key（common/uncommon/rare/epic/legendary）。留空 = 不给保底
var guaranteed_rarity: String = ""

# --- 外观（程序化占位美术）---
var ground_color: Color = Color(0.10, 0.09, 0.13)
var line_color: Color = Color(0.16, 0.14, 0.20)
var wall_color: Color = Color(0.30, 0.24, 0.38)
var accent_color: Color = Color(0.62, 0.45, 0.95)


# ---------- 构造 ----------

static func from_dict(d: Dictionary) -> DungeonDef:
	var def := DungeonDef.new()
	def.id = String(d.get("id", ""))
	def.display_name = String(d.get("display_name", "未知地城"))
	def.level_bonus = int(d.get("level_bonus", 2))
	def.room_count = maxi(1, int(d.get("room_count", 3)))
	def.room_size = _parse_vec2(d.get("room_size", [560.0, 480.0]), Vector2(560.0, 480.0))
	def.corridor_length = maxf(1.0, float(d.get("corridor_length", 200.0)))
	def.wall_height = maxf(1.0, float(d.get("wall_height", 30.0)))
	def.wall_thickness = maxf(1.0, float(d.get("wall_thickness", 12.0)))
	def.door_width = maxf(1.0, float(d.get("door_width", 140.0)))

	def.enemies_per_room.clear()
	var raw_counts: Array = d.get("enemies_per_room", [])
	for v in raw_counts:
		def.enemies_per_room.append(maxi(0, int(v)))

	var boss: Variant = d.get("boss", {})
	if typeof(boss) == TYPE_DICTIONARY:
		var boss_dict: Dictionary = boss
		def.boss_id = String(boss_dict.get("archetype", ""))
		def.boss_level_bonus = int(boss_dict.get("level_bonus", 4))

	var rewards: Variant = d.get("rewards", {})
	if typeof(rewards) == TYPE_DICTIONARY:
		var reward_dict: Dictionary = rewards
		def.reward_gold = maxi(0, int(reward_dict.get("gold", 150)))
		def.reward_xp = maxi(0, int(reward_dict.get("xp", 250)))
		def.guaranteed_rarity = String(reward_dict.get("guaranteed_rarity", ""))

	def.ground_color = _parse_color(d.get("ground_color", [0.10, 0.09, 0.13]))
	def.line_color = _parse_color(d.get("line_color", [0.16, 0.14, 0.20]))
	def.wall_color = _parse_color(d.get("wall_color", [0.30, 0.24, 0.38]))
	def.accent_color = _parse_color(d.get("accent_color", [0.62, 0.45, 0.95]))
	return def


static func _parse_vec2(v: Variant, fallback: Vector2) -> Vector2:
	if v is Array:
		var arr: Array = v
		if arr.size() >= 2:
			return Vector2(maxf(1.0, float(arr[0])), maxf(1.0, float(arr[1])))
	return fallback


static func _parse_color(v: Variant) -> Color:
	if v is Array:
		var arr: Array = v
		if arr.size() >= 3:
			var alpha := 1.0 if arr.size() < 4 else float(arr[3])
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), alpha)
	if v is String:
		return Color(String(v))
	return Color.WHITE


# ---------- 布局派生（全部在玩法平面上算）----------

## 房间 i 的平面矩形。origin 是地城原点（相对竞技场偏移，避免地面重叠）。
func room_rect(index: int, origin: Vector2) -> Rect2:
	return Rect2(
		Vector2(origin.x + float(index) * room_pitch(), origin.y - room_size.y * 0.5),
		room_size)


func room_center(index: int, origin: Vector2) -> Vector2:
	return room_rect(index, origin).get_center()


## 相邻房间原点的间距（房间宽 + 走廊长）。
func room_pitch() -> float:
	return room_size.x + corridor_length


## 全部房间 + 走廊的并集矩形。同排对齐，所以并集仍是一个矩形（可直接当 Game.arena）。
## ⚠️ Z 方向要以 origin.y 为**中线**向两侧展开 room_size.y/2，与 room_rect() 的口径一致。
func bounds(origin: Vector2) -> Rect2:
	return Rect2(
		Vector2(origin.x, origin.y - room_size.y * 0.5),
		Vector2(
			float(room_count - 1) * room_pitch() + room_size.x,
			room_size.y))


## 第 index 扇门（连接房间 index 与 index+1）所在的平面坐标（走廊正中）。
func door_point(index: int, origin: Vector2) -> Vector2:
	return Vector2(
		origin.x + float(index) * room_pitch() + room_size.x + corridor_length * 0.5,
		origin.y)


## 入口（房间 0 内、靠西墙）与出口（最后一个房间内、靠东墙）的平面坐标。
## ⚠️ 两者都必须在**房间内部**：房间 0 的西墙是封闭的，玩家出生点若落在墙外就走不进房间。
## 入口特意离西墙留出 160 的距离，好让「返回传送门」（再往西 110）既能放进屋里、
## 又不会被出生点立刻触发交互提示（提示半径 96）。
func entrance_point(origin: Vector2) -> Vector2:
	var c := room_center(0, origin)
	return Vector2(c.x - room_size.x * 0.5 + 160.0, c.y)


func exit_point(origin: Vector2) -> Vector2:
	var c := room_center(room_count - 1, origin)
	return Vector2(c.x + room_size.x * 0.5 - 90.0, c.y)


## 房间 index 的怪物数量（下标越界时沿用最后一个值）。
func enemy_count_for_room(index: int) -> int:
	if enemies_per_room.is_empty():
		return 0
	var i := clampi(index, 0, enemies_per_room.size() - 1)
	return enemies_per_room[i]


## 地城内敌人的等级（房号越大越强）。
func enemy_level(base_level: int, room_index: int) -> int:
	return maxi(1, base_level + level_bonus + room_index)


## Boss 等级。
func boss_level(base_level: int) -> int:
	return maxi(1, base_level + level_bonus + boss_level_bonus)
