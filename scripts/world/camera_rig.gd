class_name CameraRig
extends Camera3D
## 正交俯视相机装配：参数在 `data/camera.json`（`CameraConfig`），
## 本节点负责**跟随 / 缩放 / 旋转 / 俯角微调 / 边界钳制**。
##
## 为什么单独成节点：M16 之前这套逻辑散在 `main.gd` 里（4 个常量 + 3 个函数），
## 加上缩放与旋转之后已经够复杂，独立出来才能单独写自测（`tests/test_camera.gd`）。
##
## 目标位置每帧从 `Game.get_player()` 取；边界钳制用 `Game.arena`
## （进出地城时 `main.gd` 会换掉它，见 [dungeon.md](../modules/dungeon.md)）。
##
## 操作：滚轮 / `=` / `-` 缩放，`,` / `.` 旋转，`PageUp` / `PageDown` 调俯角，`R` 重置视角。

## 瞬移判定：焦点离目标超过「视野 × 这个倍数」时直接 snap，不做平滑
## （复活、进出地城都会瞬移玩家，让它一路平移过去会很难看）
const SNAP_DISTANCE_FACTOR := 3.0
## 俯角过平时 cos 会趋近 0，纵深会被放大到离谱 —— 兜一个下限
const MIN_TILT_COS := 0.15

var config: CameraConfig = null

## 当前正交视野高度（越小越近）
var ortho_size: float = 620.0
## 当前俯角（负值）/ 水平旋转角（度）
var tilt_deg: float = -45.0
var yaw_deg: float = 0.0

## 调参时把当前值打到控制台（由 main.gd 按 DEV_TOOLS 开关）
var debug_report: bool = false

## 期望焦点（玩家位置，未钳制）—— 平滑与瞬移判定都用它
var _desired: Vector2 = Vector2.ZERO
## 实际焦点（已按场地钳制）—— 相机真正对准的点
var _focus: Vector2 = Vector2.ZERO
var _distance: float = 1600.0
var _follow_speed: float = 6.0


func _ready() -> void:
	name = "CameraRig"
	projection = PROJECTION_ORTHOGONAL
	near = 1.0
	far = 9000.0
	apply_config(CameraConfig.load_default())


func _process(delta: float) -> void:
	step(delta)


## 一帧的相机推进（输入 + 跟随）。独立成公开方法，自测可以直接调它，
## 不必去碰 `_process`（而且在世界被暂停时自测也能推进相机）。
func step(delta: float) -> void:
	_handle_input()
	_follow(delta)


## 相机操作输入。模态界面（加点 / 背包 / 标题选档）打开时不响应，
## 免得翻背包时顺手把镜头转走或缩放掉。
func _handle_input() -> void:
	if _ui_blocked():
		return
	if Input.is_action_just_pressed("zoom_in"):
		zoom_by(1)
	if Input.is_action_just_pressed("zoom_out"):
		zoom_by(-1)
	if Input.is_action_just_pressed("rotate_left"):
		rotate_by(-1)
	if Input.is_action_just_pressed("rotate_right"):
		rotate_by(1)
	if Input.is_action_just_pressed("tilt_up"):
		tilt_by(1)
	if Input.is_action_just_pressed("tilt_down"):
		tilt_by(-1)
	if Input.is_action_just_pressed("camera_reset"):
		reset_view()
		Events.toast.emit("相机视角已重置", Color(0.80, 0.90, 1.0))


func _ui_blocked() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	return not tree.get_nodes_in_group("modal_ui").is_empty()


# ---------------------------------------------------------------- 配置

## 套用配置（回到 JSON 里的默认视角）。
func apply_config(cfg: CameraConfig) -> void:
	config = cfg
	if config == null:
		return
	ortho_size = config.size
	tilt_deg = config.tilt_deg
	yaw_deg = 0.0
	_distance = config.distance
	_follow_speed = config.follow_speed
	_apply_transform()


# ---------------------------------------------------------------- 操作

## 缩放：正数 = 拉近（视野变小）。返回是否真的变了。
func zoom_by(steps: int) -> bool:
	if config == null or steps == 0:
		return false
	var before := ortho_size
	ortho_size = clampf(ortho_size - config.zoom_step * float(steps),
		config.zoom_min, config.zoom_max)
	return _after_change(before != ortho_size, "视野 %.0f" % ortho_size)


## 水平旋转：正数 = 顺时针（步进 = config.rotate_step_deg），结果归一化到 (-180, 180]。
func rotate_by(steps: int) -> bool:
	if config == null or steps == 0:
		return false
	var before := yaw_deg
	yaw_deg = wrapf(yaw_deg + config.rotate_step_deg * float(steps), -180.0, 180.0)
	return _after_change(not is_equal_approx(before, yaw_deg), "旋转 %.0f°" % yaw_deg)


## 俯角：正数 = 更俯视（角度更负）。
func tilt_by(steps: int) -> bool:
	if config == null or steps == 0:
		return false
	var before := tilt_deg
	tilt_deg = clampf(tilt_deg - config.tilt_step_deg * float(steps),
		config.tilt_min_deg, config.tilt_max_deg)
	return _after_change(not is_equal_approx(before, tilt_deg), "俯角 %.0f°" % tilt_deg)


## 回到 JSON 里的默认视角（缩放 / 旋转 / 俯角一起复位）。
func reset_view() -> void:
	if config == null:
		return
	ortho_size = config.size
	tilt_deg = config.tilt_deg
	yaw_deg = 0.0
	_after_change(true, "已重置为 JSON 默认视角")


# ---------------------------------------------------------------- 跟随

## 立刻把焦点对准玩家（不做平滑）。进出地城 / 复活后调用。
func snap() -> void:
	# 显式标注：_player_plane() 返回 Variant（可能是 null），用 := 会触发
	# 「inferred from a Variant」警告，而本工程把该警告当错误
	var target: Variant = _player_plane()
	if target != null:
		_desired = target
	_focus = clamp_focus(_desired)
	_apply_transform()


## 相机实际对准的点（玩法平面坐标，**已按场地钳制**）。
func focus_plane() -> Vector2:
	return _focus


## 期望焦点（玩家位置，未钳制）。调试与自测用来区分「玩家在哪」与「镜头对准哪」。
func focus_target() -> Vector2:
	return _desired


## 手动设置焦点（自测与将来的「跟随目标切换」用）。
func set_focus(point: Vector2) -> void:
	_desired = point
	_focus = clamp_focus(_desired)
	_apply_transform()


func _follow(delta: float) -> void:
	# 同样显式标注（_player_plane() 返回 Variant）
	var target: Variant = _player_plane()
	if target == null:
		_apply_transform()
		return
	# 瞬移（复活 / 进出地城）直接对齐，别让相机横穿整张地图。
	# 判定用**未钳制**的期望焦点：否则玩家走到场地边缘时会被钳制值误判成瞬移。
	if _desired.distance_to(target) > ortho_size * SNAP_DISTANCE_FACTOR:
		_desired = target
	else:
		_desired = _desired.lerp(target, clampf(_follow_speed * delta, 0.0, 1.0))
	_focus = clamp_focus(_desired)
	_apply_transform()


func _player_plane() -> Variant:
	var player := Game.get_player()
	if player == null or not is_instance_valid(player):
		return null
	return Game.plane(player.global_position)


# ---------------------------------------------------------------- 变换与钳制

func _apply_transform() -> void:
	size = ortho_size
	rotation = Vector3(tilt_deg, yaw_deg, 0.0)
	# 先设 rotation 再读 basis：本节点已在树里，写 rotation 后 transform 立刻可用
	var view_dir := -transform.basis.z
	# _focus 已经是钳制后的值（snap / _follow / set_focus 都会钳一次）
	global_position = Game.world(_focus) - view_dir * _distance


## 把焦点钳在场地内，保证画面不会露出场地之外。
## 旋转时画面的地面足迹是个**斜矩形**，这里取它的世界轴对齐包围盒（保守估计）：
##   ext = |右轴分量| × 半宽 + |上轴分量| × 半深
func clamp_focus(focus: Vector2) -> Vector2:
	var rect: Rect2 = Game.arena
	var ext := view_extents()
	var min_x := rect.position.x + ext.x
	var max_x := rect.end.x - ext.x
	var min_z := rect.position.y + ext.y
	var max_z := rect.end.y - ext.y
	# 视野比场地还大时退化为居中，避免 min > max
	if min_x > max_x:
		min_x = (rect.position.x + rect.end.x) * 0.5
		max_x = min_x
	if min_z > max_z:
		min_z = (rect.position.y + rect.end.y) * 0.5
		max_z = min_z
	return Vector2(clampf(focus.x, min_x, max_x), clampf(focus.y, min_z, max_z))


## 画面在地面上覆盖的「世界轴对齐」半宽（X）与半深（Z）。
func view_extents() -> Vector2:
	var aspect := _viewport_aspect()
	var half_w := ortho_size * aspect * 0.5
	# 俯角把纵深压缩 cos(t) 倍（-45° 时地面纵深约为画面高度的 1.41 倍）
	var half_h := ortho_size * 0.5 / maxf(MIN_TILT_COS, cos(deg_to_rad(absf(tilt_deg))))
	var yaw := deg_to_rad(yaw_deg)
	# 绕 Y 旋转 yaw 后：画面右方向 = (cos, 0, -sin)，画面「上」在地面上的投影与之垂直
	var right := Vector2(cos(yaw), -sin(yaw))
	var up := Vector2(sin(yaw), cos(yaw))
	return Vector2(
		absf(right.x) * half_w + absf(up.x) * half_h,
		absf(right.y) * half_w + absf(up.y) * half_h)


func _viewport_aspect() -> float:
	var vp := get_viewport()
	if vp == null:
		return 16.0 / 9.0
	var vp_size := vp.get_visible_rect().size
	if vp_size.y <= 0.0:
		return 16.0 / 9.0
	return vp_size.x / vp_size.y


# ---------------------------------------------------------------- 调试

## 一行读数，给 DevPause 面板显示（也方便把调好的值抄回 data/camera.json）。
func debug_text() -> String:
	if config == null:
		return "相机  未载入配置"
	return "相机  视野 %.0f（%.0f~%.0f）  俯角 %.0f°（%.0f~%.0f）  旋转 %.0f°  后撤 %.0f" % [
		ortho_size, config.zoom_min, config.zoom_max,
		tilt_deg, config.tilt_min_deg, config.tilt_max_deg, yaw_deg, _distance]


## 配置里的默认视角（调试用）
func default_text() -> String:
	if config == null:
		return ""
	return "默认：视野 %.0f 俯角 %.0f° 后撤 %.0f 跟随 %.1f" % [
		config.size, config.tilt_deg, config.distance, config.follow_speed]


func _after_change(changed: bool, label: String) -> bool:
	if not changed:
		return false
	_apply_transform()
	if debug_report:
		print("[camera] ", label, "   ← 抄进 data/camera.json 即可固化")
	return true
