class_name AttributeRegistry
extends RefCounted
## 属性注册表：从 data/attributes.json 加载全部属性 + 每级自由点数。
##
## 加属性 / 调加点曲线 = 改 JSON，不改代码。

const _DEFAULT_PATH := "res://data/attributes.json"
## JSON 读不到时的兜底每级点数，保证加点系统不会因为数据缺失而完全失效。
const DEFAULT_FREE_POINTS_PER_LEVEL := 5

static var _cached: Array = []          # Array[AttributeDef]
static var _by_id: Dictionary = {}      # {id: AttributeDef}
static var _free_points_per_level: int = DEFAULT_FREE_POINTS_PER_LEVEL


## 加载并缓存。返回 AttributeDef 数组（注册顺序 = JSON 顺序）。
static func load_default() -> Array:
	if not _cached.is_empty():
		return _cached
	if not FileAccess.file_exists(_DEFAULT_PATH):
		push_error("AttributeRegistry: 找不到 %s" % _DEFAULT_PATH)
		return []
	var raw := FileAccess.get_file_as_string(_DEFAULT_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("AttributeRegistry: %s 解析失败（非字典）" % _DEFAULT_PATH)
		return []
	var root: Dictionary = parsed
	_free_points_per_level = maxi(0, int(root.get(
		"free_points_per_level", DEFAULT_FREE_POINTS_PER_LEVEL)))
	var entries: Array = root.get("attributes", [])
	for entry in entries:
		if entry is Dictionary:
			var attr := AttributeDef.from_dict(entry)
			if attr.id.is_empty():
				push_warning("AttributeRegistry: 跳过一条没有 id 的属性定义")
				continue
			_cached.append(attr)
			_by_id[attr.id] = attr
	return _cached


## 按 id 查属性。找不到返回 null。
static func get_attribute(id: String) -> AttributeDef:
	if _by_id.is_empty():
		load_default()
	return _by_id.get(id)


## 全部属性 id，按 JSON 顺序（加点界面按此顺序排列）。
static func ids() -> Array[String]:
	var out: Array[String] = []
	for attr in load_default():
		out.append(attr.id)
	return out


## 每升 1 级获得的自由属性点。
static func free_points_per_level() -> int:
	if _cached.is_empty():
		load_default()
	return _free_points_per_level


## 把「属性 -> 已投入点数」汇总成一份总属性加成 {stat_key: delta}。
## 纯计算，不依赖 Player，便于自测与后续联机在服务端复算。
static func bonus_for_all(allocation: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for attr in load_default():
		var points := int(allocation.get(attr.id, 0))
		if points <= 0:
			continue
		for key in attr.per_point:
			out[key] = float(out.get(key, 0.0)) + float(attr.per_point[key]) * float(points)
	return out


## 仅供测试 / 热重载使用。
static func clear_cache() -> void:
	_cached.clear()
	_by_id.clear()
	_free_points_per_level = DEFAULT_FREE_POINTS_PER_LEVEL
