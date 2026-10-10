class_name CameraConfig
extends RefCounted
## 相机配置：正交视野 / 俯角 / 后撤距离 / 跟随速度 / 缩放与旋转步进。纯数据。
##
## 数据来自 data/camera.json。所有值在 `from_dict()` 里做一次钳制，
## 免得手改 JSON 写出一个「视野为负」「俯角朝上」之类的值直接把画面搞没。
## ⚠️ 数值为自行设计的占位值，等目视校准后再固化（见 docs/modules/render3d.md）。

const _DEFAULT_PATH := "res://data/camera.json"

static var _cached: CameraConfig = null

# --- 基础 ---
var size: float = 620.0          # 正交视野高度（世界单位）：越小越近
var tilt_deg: float = -45.0      # 俯角，必须为负（0 = 平视，-90 = 垂直俯视）
var distance: float = 1600.0     # 沿视线后撤距离（正交下只影响裁剪）
var follow_speed: float = 6.0    # 焦点平滑跟随速度

# --- 缩放 ---
var zoom_min: float = 340.0
var zoom_max: float = 980.0
var zoom_step: float = 40.0

# --- 旋转 / 俯角微调 ---
var rotate_step_deg: float = 15.0
var tilt_min_deg: float = -70.0
var tilt_max_deg: float = -22.0
var tilt_step_deg: float = 3.0

## JSON 读不到时的兜底（沿用上面字段的默认值即可）
const MIN_TILT_LIMIT := -89.0
const MAX_TILT_LIMIT := -5.0


static func load_default() -> CameraConfig:
	if _cached != null:
		return _cached
	if not FileAccess.file_exists(_DEFAULT_PATH):
		push_error("CameraConfig: 找不到 %s" % _DEFAULT_PATH)
		_cached = CameraConfig.new()
		return _cached
	var raw := FileAccess.get_file_as_string(_DEFAULT_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CameraConfig: %s 解析失败（非字典）" % _DEFAULT_PATH)
		_cached = CameraConfig.new()
		return _cached
	_cached = from_dict(parsed)
	return _cached


static func from_dict(d: Dictionary) -> CameraConfig:
	var c := CameraConfig.new()

	var zoom: Variant = d.get("zoom", {})
	var rotate: Variant = d.get("rotate", {})
	var tilt: Variant = d.get("tilt", {})

	if typeof(zoom) == TYPE_DICTIONARY:
		var z: Dictionary = zoom
		c.zoom_min = maxf(40.0, float(z.get("min", c.zoom_min)))
		c.zoom_max = maxf(c.zoom_min + 1.0, float(z.get("max", c.zoom_max)))
		c.zoom_step = maxf(1.0, float(z.get("step", c.zoom_step)))
	if typeof(rotate) == TYPE_DICTIONARY:
		var r: Dictionary = rotate
		c.rotate_step_deg = maxf(1.0, float(r.get("step_deg", c.rotate_step_deg)))
	if typeof(tilt) == TYPE_DICTIONARY:
		var t: Dictionary = tilt
		c.tilt_min_deg = clampf(float(t.get("min_deg", c.tilt_min_deg)),
			MIN_TILT_LIMIT, MAX_TILT_LIMIT)
		c.tilt_max_deg = clampf(float(t.get("max_deg", c.tilt_max_deg)),
			c.tilt_min_deg, MAX_TILT_LIMIT)
		c.tilt_step_deg = maxf(0.5, float(t.get("step_deg", c.tilt_step_deg)))

	# 基础值要放在缩放区间算好之后再钳，否则会被「还没读到的」区间夹错
	c.size = clampf(float(d.get("size", c.size)), c.zoom_min, c.zoom_max)
	c.tilt_deg = clampf(float(d.get("tilt_deg", c.tilt_deg)), c.tilt_min_deg, c.tilt_max_deg)
	c.distance = maxf(100.0, float(d.get("distance", c.distance)))
	c.follow_speed = maxf(0.1, float(d.get("follow_speed", c.follow_speed)))
	return c


## 供测试 / 热重载使用。
static func clear_cache() -> void:
	_cached = null
