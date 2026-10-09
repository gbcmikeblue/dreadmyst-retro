class_name ProfessionRegistry
extends RefCounted
## 职业注册表：从 data/professions.json 加载全部职业。
##
## 加职业 = 改 JSON，不改代码（但要在 data/skills.json 里有对应技能）。

const _DEFAULT_PATH := "res://data/professions.json"

static var _cached: Array = []          # Array[Profession]
static var _by_id: Dictionary = {}      # {id: Profession}


## 加载并缓存。返回 Profession 数组（注册顺序 = JSON 顺序）。
static func load_default() -> Array:
	if not _cached.is_empty():
		return _cached
	if not FileAccess.file_exists(_DEFAULT_PATH):
		push_error("ProfessionRegistry: 找不到 %s" % _DEFAULT_PATH)
		return []
	var raw := FileAccess.get_file_as_string(_DEFAULT_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ProfessionRegistry: %s 解析失败（非字典）" % _DEFAULT_PATH)
		return []
	var root: Dictionary = parsed
	var entries: Array = root.get("professions", [])
	for entry in entries:
		if entry is Dictionary:
			var prof := Profession.from_dict(entry)
			if prof.id.is_empty():
				push_warning("ProfessionRegistry: 跳过一条没有 id 的职业定义")
				continue
			_cached.append(prof)
			_by_id[prof.id] = prof
	return _cached


## 按 id 查职业。找不到返回 null。
static func get_profession(id: String) -> Profession:
	if _by_id.is_empty():
		load_default()
	return _by_id.get(id)


## 全部职业 id，按 JSON 顺序（用于原型期的 F1/F2/F3 切换）。
static func ids() -> Array[String]:
	var out: Array[String] = []
	for prof in load_default():
		out.append(prof.id)
	return out


## 仅供测试 / 热重载使用。
static func clear_cache() -> void:
	_cached.clear()
	_by_id.clear()
