class_name EnemyRegistry
extends RefCounted
## 敌人原型注册表：从 data/enemies.json 加载所有原型。

const _DEFAULT_PATH := "res://data/enemies.json"

static var _cached: Array = []  # Array[EnemyArchetype]


## 加载并缓存。返回 EnemyArchetype 数组。
static func load_default() -> Array:
	if not _cached.is_empty():
		return _cached
	if not FileAccess.file_exists(_DEFAULT_PATH):
		push_error("EnemyRegistry: 找不到 %s" % _DEFAULT_PATH)
		return []
	var raw := FileAccess.get_file_as_string(_DEFAULT_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EnemyRegistry: %s 解析失败（非字典）" % _DEFAULT_PATH)
		return []
	var root: Dictionary = parsed
	var entries: Array = root.get("archetypes", [])
	for entry in entries:
		if entry is Dictionary:
			_cached.append(EnemyArchetype.from_dict(entry))
	return _cached


## 按 spawn_weight 加权抽一个原型。空则返回 null。
static func pick_weighted() -> EnemyArchetype:
	var list: Array = load_default()
	if list.is_empty():
		return null
	var total := 0.0
	for a in list:
		total += float(a.spawn_weight)
	if total <= 0.0:
		return list[0]
	var roll := randf() * total
	var acc := 0.0
	for a in list:
		acc += float(a.spawn_weight)
		if roll <= acc:
			return a
	return list[0]


## 仅供测试 / 热重载使用。
static func clear_cache() -> void:
	_cached.clear()
