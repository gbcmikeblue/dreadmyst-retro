class_name DevPause
extends CanvasLayer
## 开发用暂停控件：右上角按钮 + Esc/P 快捷键 + 全屏遮罩 + 实时输入显示。
##
## 单独成一个节点而不是塞进 HUD：HUD 的职责是「读 Events 显示状态」（只读），
## 而暂停是「写全局 get_tree().paused」的开发工具，职责不同，混在一起会让 HUD 不再纯粹。
##
## 关键点：暂停后本节点必须继续运行，否则按钮点不动、快捷键也收不到
## —— 所以 _ready() 里设了 PROCESS_MODE_ALWAYS。

const MARGIN := Vector2(16.0, 14.0)
const BUTTON_SIZE := Vector2(96.0, 34.0)

var _button: Button
var _overlay: ColorRect
var _readout: Label
## 标题选档界面打开时由 main.gd 关掉：否则点「继续」会把标题界面后面的世界解冻
var enabled: bool = true


func _ready() -> void:
	# 暂停后仍要响应输入与 _process，否则无法取消暂停
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100    # 盖在 HUD（layer 10）之上
	_build()
	_refresh()


func _process(_delta: float) -> void:
	if not enabled:
		return
	# 有模态界面（加点 / 背包 / 标题选档）打开时不响应暂停：那些界面本身已经把玩家冻住了
	if _ui_blocked():
		return
	if Input.is_action_just_pressed("pause"):
		_toggle()
	_update_readout()


## 开关整个开发面板（标题界面期间关掉）。
func set_enabled(on: bool) -> void:
	enabled = on
	if _button != null:
		_button.visible = on
	if _readout != null:
		_readout.visible = on
	if not on and _overlay != null:
		_overlay.visible = false
		var tree := get_tree()
		if tree != null and tree.paused:
			tree.paused = false


func _ui_blocked() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	return not tree.get_nodes_in_group("modal_ui").is_empty()


# ---------------------------------------------------------------- 构建

func _build() -> void:
	# 全屏遮罩（暂停时显示）
	_overlay = ColorRect.new()
	_overlay.color = Color(0.02, 0.02, 0.04, 0.55)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	var tip := Label.new()
	tip.text = "已暂停"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip.anchor_left = 0.5
	tip.anchor_right = 0.5
	tip.anchor_top = 0.5
	tip.anchor_bottom = 0.5
	tip.offset_left = -200.0
	tip.offset_right = 200.0
	tip.offset_top = -40.0
	tip.offset_bottom = 40.0
	tip.add_theme_font_size_override("font_size", 36)
	tip.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	tip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	tip.add_theme_constant_override("shadow_offset_x", 2)
	tip.add_theme_constant_override("shadow_offset_y", 2)
	_overlay.add_child(tip)

	# 右上角按钮：用锚点贴住右上角，窗口尺寸变化时自动跟随
	_button = Button.new()
	_button.anchor_left = 1.0
	_button.anchor_right = 1.0
	_button.anchor_top = 0.0
	_button.anchor_bottom = 0.0
	_button.offset_left = -(BUTTON_SIZE.x + MARGIN.x)
	_button.offset_right = -MARGIN.x
	_button.offset_top = MARGIN.y
	_button.offset_bottom = MARGIN.y + BUTTON_SIZE.y
	# 不吃键盘焦点：否则点过一次后，空格/回车会重复触发按钮而不是攻击
	_button.focus_mode = Control.FOCUS_NONE
	_button.tooltip_text = "快捷键 Esc / P"
	_button.pressed.connect(_toggle)
	add_child(_button)

	# 实时输入显示：按键没生效时，一眼就能看出是"没收到输入"还是"收到了没动"
	_readout = Label.new()
	_readout.anchor_left = 0.0
	_readout.anchor_top = 0.0
	_readout.offset_left = 16.0
	_readout.offset_top = MARGIN.y + BUTTON_SIZE.y + 6.0
	_readout.add_theme_font_size_override("font_size", 13)
	_readout.add_theme_color_override("font_color", Color(0.55, 0.80, 0.55))
	_readout.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_readout.add_theme_constant_override("shadow_offset_x", 1)
	_readout.add_theme_constant_override("shadow_offset_y", 1)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_readout)


# ---------------------------------------------------------------- 暂停

func _toggle() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = not tree.paused
	_refresh()


func _refresh() -> void:
	var tree := get_tree()
	var paused_now: bool = tree != null and tree.paused
	_button.text = "继续" if paused_now else "暂停"
	_overlay.visible = paused_now


func _update_readout() -> void:
	if _readout == null:
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var held: Array[String] = []
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		if Input.is_action_pressed(a):
			held.append(String(a).trim_prefix("move_"))
	var lines: Array[String] = [
		"输入 (%.2f, %.2f)   按住: %s" % [
			v.x, v.y, "无" if held.is_empty() else ", ".join(held)]
	]
	# M16：顺手显示相机读数（改完参数直接抄进 data/camera.json）
	var lines_camera := _camera_readout()
	if not lines_camera.is_empty():
		lines.append(lines_camera)
	_readout.text = "\n".join(lines)


## 从当前 3D 相机取读数。**不引用具体节点**：谁能当相机就显示谁，
## 这样也顺带覆盖「将来换成别的相机实现」的情况。
func _camera_readout() -> String:
	var vp := get_viewport()
	if vp == null:
		return ""
	var cam := vp.get_camera_3d()
	if cam == null or not cam.has_method("debug_text"):
		return ""
	return String(cam.call("debug_text"))
