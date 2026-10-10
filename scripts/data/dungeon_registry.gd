class_name DungeonRegistry
extends RefCounted
## 地城注册表：从 data/dungeon.json 加载全部地城定义。
##
## 加地城 = 改 JSON，不改代码（Boss 原型要在 data/enemies.json 里存在）。

const _DEFAULT_PATH := "res://data/dungeon.json"

static var _cached: Array = []          # Array[DungeonDef]
static var _by_id: Dictionary = {}      # {id: DungeonDef}


## 加载并缓存。返回 DungeonDef 数组（注册顺序 = JSON 顺序）。
static func load_default() -> Array:
	if not _cached.is_empty():
		return _cached
	if not FileAccess.file_exists(_DEFAULT_PATH):
		push_error("DungeonRegistry: 找不到 %s" % _DEFAULT_PATH)
		return []
	var raw := FileAccess.get_file_as_string(_DEFAULT_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DungeonRegistry: %s 解析失败（非字典）" % _DEFAULT_PATH)
		return []
	var root: Dictionary = parsed
	var entries: Array = root.get("dungeons", [])
	for entry in entries:
		if entry is Dictionary:
			var def := DungeonDef.from_dict(entry)
			if def.id.is_empty():
				push_warning("DungeonRegistry: 跳过一条没有 id 的地城定义")
				continue
			_cached.append(def)
			_by_id[def.id] = def
	return _cached


## 按 id 查地城。找不到返回 null。
static func get_dungeon(id: String) -> DungeonDef:
	if _by_id.is_empty():
		load_default()
	return _by_id.get(id)


## 全部地城 id，按 JSON 顺序（原型期只开放第一个）。
static func ids() -> Array[String]:
	var out: Array[String] = []
	for def in load_default():
		out.append(def.id)
	return out


## 仅供测试 / 热重载使用。
static func clear_cache() -> void:
	_cached.clear()
	_by_id.clear()
