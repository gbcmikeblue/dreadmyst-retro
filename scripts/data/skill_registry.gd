class_name SkillRegistry
extends RefCounted
## 技能注册表：从 data/skills.json 加载全部技能，并提供按 id / 职业查询。
##
## 加技能 = 改 JSON，不改代码。

const _DEFAULT_PATH := "res://data/skills.json"

static var _cached: Array = []          # Array[SkillDef]
static var _by_id: Dictionary = {}      # {id: SkillDef}


## 加载并缓存。返回 SkillDef 数组（注册顺序 = JSON 顺序）。
static func load_default() -> Array:
	if not _cached.is_empty():
		return _cached
	if not FileAccess.file_exists(_DEFAULT_PATH):
		push_error("SkillRegistry: 找不到 %s" % _DEFAULT_PATH)
		return []
	var raw := FileAccess.get_file_as_string(_DEFAULT_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SkillRegistry: %s 解析失败（非字典）" % _DEFAULT_PATH)
		return []
	var root: Dictionary = parsed
	var entries: Array = root.get("skills", [])
	for entry in entries:
		if entry is Dictionary:
			var skill := SkillDef.from_dict(entry)
			if skill.id.is_empty():
				push_warning("SkillRegistry: 跳过一条没有 id 的技能定义")
				continue
			_cached.append(skill)
			_by_id[skill.id] = skill
	return _cached


## 按 id 查技能。找不到返回 null。
static func get_skill(id: String) -> SkillDef:
	if _by_id.is_empty():
		load_default()
	return _by_id.get(id)


## 取某职业的全部技能，按 JSON 顺序（约定第 0 个是普攻，第 1 个是大招）。
static func skills_of(profession_id: String) -> Array:
	var out: Array = []
	for skill in load_default():
		if skill.profession_id == profession_id:
			out.append(skill)
	return out


## 仅供测试 / 热重载使用。
static func clear_cache() -> void:
	_cached.clear()
	_by_id.clear()
