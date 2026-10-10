class_name EnemyRegistry
extends RefCounted
## 敌人原型注册表：从 data/enemies.json 加载所有原型。
##
## `is_boss = true` 或 `spawn_weight <= 0` 的原型**不会**进入 pick_weighted()，
## 只由地城通过 get_archetype(id) 指名生成。

const _DEFAULT_PATH := "res://data/enemies.json"

static var _cached: Array = []          # Array[EnemyArchetype]
static var _by_id: Dictionary = {}      # {id: EnemyArchetype}


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
			var arch := EnemyArchetype.from_dict(entry)
			if arch.id.is_empty():
				push_warning("EnemyRegistry: 跳过一条没有 id 的原型定义")
				continue
			_cached.append(arch)
			_by_id[arch.id] = arch
	return _cached


## 按 id 查原型（地城指名 Boss 用）。找不到返回 null。
static func get_archetype(id: String) -> EnemyArchetype:
	if _by_id.is_empty():
		load_default()
	return _by_id.get(id)


## 按 spawn_weight 加权抽一个「可野外刷出」的原型。空则返回 null。
## Boss（is_boss）与权重 <= 0 的条目被排除。
static func pick_weighted() -> EnemyArchetype:
	var candidates: Array = []
	var total := 0.0
	for a in load_default():
		if a.is_boss or float(a.spawn_weight) <= 0.0:
			continue
		candidates.append(a)
		total += float(a.spawn_weight)
	if candidates.is_empty():
		return null
	var roll := randf() * total
	var acc := 0.0
	for a in candidates:
		acc += float(a.spawn_weight)
		if roll <= acc:
			return a
	return candidates[candidates.size() - 1]


## 仅供测试 / 热重载使用。
static func clear_cache() -> void:
	_cached.clear()
	_by_id.clear()
