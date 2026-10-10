class_name TitleScreen
extends CanvasLayer
## 启动选档界面（M13）：3 个槽位，每槽可「继续 / 新游戏 / 删除」。
##
## - 打开时 `get_tree().paused = true` 冻结世界。**已实测**：暂停时 `SceneTree.process_frame`
##   仍会触发，所以 `--script` 自测的帧循环不会被挂住。
## - 「新游戏」在**已有档**的槽位上、以及「删除」都需要**点两次确认**（第二次按钮文字会变）。
## - 与外界只走 Events：本节点不认识 Player / Game / SaveService。
##   槽位摘要来自 `save_slots_changed`；选择动作发 `save_load_requested` /
##   `save_new_game_requested` / `save_delete_requested`。

const WINDOW_SIZE := Vector2(600.0, 420.0)
## 槽位数，与 SaveService.SLOT_COUNT 保持一致（这里不引用它，避免 UI 依赖服务层常量）
const SLOT_ROWS := 3
## 需要二次确认的动作
const CONFIRM_NEW := "new"
const CONFIRM_DELETE := "delete"

var _backdrop: ColorRect
var _window: Panel
var _hint_label: Label
## [{slot, info, continue_btn, new_btn, delete_btn}]
var _rows: Array = []
## Array[Dictionary]，来自 save_slots_changed，下标 i 对应槽位 i+1
var _summaries: Array = []
## 正在等待二次确认的 {slot, action}
var _confirm: Dictionary = {}


func _ready() -> void:
	name = "TitleScreen"
	layer = 30                                   # 盖在 HUD(10) / 面板(20) 之上、DevPause(100) 之下
	process_mode = Node.PROCESS_MODE_ALWAYS      # 自己得在暂停时也能点
	_build()
	Events.save_slots_changed.connect(_on_slots_changed)
	# 不在这里 open()：由 main.gd 在全部节点都接好线之后再调，避免要摘要时没人应答
	visible = false


func open() -> void:
	visible = true
	add_to_group("modal_ui")
	_confirm.clear()
	# 冻结世界（营地里的怪不会在选档时把玩家打死）
	var tree := get_tree()
	if tree != null:
		tree.paused = true
	Events.save_slots_requested.emit()
	_refresh()


func close() -> void:
	visible = false
	if is_in_group("modal_ui"):
		remove_from_group("modal_ui")
	_confirm.clear()
	var tree := get_tree()
	if tree != null:
		tree.paused = false


func is_open() -> bool:
	return visible


# ---------------------------------------------------------------- 构建

func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.02, 0.04, 0.88)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_window = Panel.new()
	_window.anchor_left = 0.5
	_window.anchor_right = 0.5
	_window.anchor_top = 0.5
	_window.anchor_bottom = 0.5
	_window.offset_left = -WINDOW_SIZE.x * 0.5
	_window.offset_right = WINDOW_SIZE.x * 0.5
	_window.offset_top = -WINDOW_SIZE.y * 0.5
	_window.offset_bottom = WINDOW_SIZE.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.10, 0.98)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.34, 0.28, 0.44)
	style.shadow_size = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	_window.add_theme_stylebox_override("panel", style)
	add_child(_window)

	_make_label(Vector2(24.0, 18.0), Vector2(400.0, 30.0), "恐惧秘境 · Dreadmyst 复刻", 24,
		Color(0.94, 0.92, 1.0))
	_make_label(Vector2(24.0, 50.0), Vector2(400.0, 20.0), "选择一个存档槽位开始", 14,
		Color(0.72, 0.72, 0.82))

	for i in range(SLOT_ROWS):
		_build_row(i)

	_hint_label = _make_label(Vector2(24.0, WINDOW_SIZE.y - 30.0), Vector2(552.0, 20.0),
		"游戏内：F5 存档 · F9 读档 · I 背包 · C 属性", 12, Color(0.55, 0.56, 0.66))


func _build_row(index: int) -> void:
	var slot := index + 1
	var row := Panel.new()
	row.position = Vector2(24.0, 86.0 + float(index) * 96.0)
	row.size = Vector2(WINDOW_SIZE.x - 48.0, 86.0)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.10, 0.10, 0.14, 0.95)
	row_style.set_corner_radius_all(6)
	row_style.set_border_width_all(1)
	row_style.border_color = Color(0.28, 0.26, 0.36)
	row.add_theme_stylebox_override("panel", row_style)
	_window.add_child(row)

	var info := _make_label_in(row, Vector2(14.0, 10.0), Vector2(330.0, 66.0), "", 14,
		Color(0.90, 0.91, 0.97))

	var cont := _make_button(row, Vector2(352.0, 16.0), Vector2(84.0, 30.0), "继续")
	cont.pressed.connect(_on_continue.bind(slot))
	var new_btn := _make_button(row, Vector2(442.0, 16.0), Vector2(84.0, 30.0), "新游戏")
	new_btn.pressed.connect(_on_new_game.bind(slot))
	var del := _make_button(row, Vector2(352.0, 52.0), Vector2(174.0, 26.0), "删除此存档")
	del.pressed.connect(_on_delete.bind(slot))

	_rows.append({
		"slot": slot,
		"info": info,
		"continue": cont,
		"new": new_btn,
		"delete": del,
	})


func _make_label(pos: Vector2, size: Vector2, text: String, font_size: int,
		color: Color) -> Label:
	return _make_label_in(_window, pos, size, text, font_size, color)


func _make_label_in(parent: Node, pos: Vector2, size: Vector2, text: String,
		font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_button(parent: Node, pos: Vector2, size: Vector2, text: String) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = size
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	parent.add_child(button)
	return button


# ---------------------------------------------------------------- 刷新

func _on_slots_changed(slots: Array) -> void:
	_summaries = slots
	_refresh()


func _refresh() -> void:
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var slot := int(row["slot"])
		var summary := _summary_of(slot)
		var exists := not summary.is_empty() and bool(summary.get("exists", false))
		var info: Label = row["info"]
		var cont: Button = row["continue"]
		var new_btn: Button = row["new"]
		var del: Button = row["delete"]

		if exists:
			info.text = "存档 %d    %s · %d 级 · %d 金\n[%s]  最后保存：%s" % [
				slot, _profession_name(String(summary.get("profession", ""))),
				int(summary.get("level", 1)), int(summary.get("gold", 0)),
				"存档", String(summary.get("saved_at", "—"))]
			cont.disabled = false
		else:
			info.text = "存档 %d    （空）\n点「新游戏」在这个槽位开始" % slot
			cont.disabled = true
		del.disabled = not exists

		# 二次确认态：对应按钮改成「确认…？」，其他按钮恢复正常文案
		var confirming_new := _is_confirming(slot, CONFIRM_NEW)
		var confirming_delete := _is_confirming(slot, CONFIRM_DELETE)
		new_btn.text = "确认覆盖？" if confirming_new else "新游戏"
		del.text = "确认删除？" if confirming_delete else "删除此存档"


func _summary_of(slot: int) -> Dictionary:
	for summary in _summaries:
		if int(summary.get("slot", -1)) == slot:
			return summary
	return {}


func _profession_name(profession_id: String) -> String:
	if profession_id.is_empty():
		return "未知职业"
	var prof := ProfessionRegistry.get_profession(profession_id)
	return prof.display_name if prof != null else profession_id


func _is_confirming(slot: int, action: String) -> bool:
	return int(_confirm.get("slot", -1)) == slot and String(_confirm.get("action", "")) == action


func _set_confirm(slot: int, action: String) -> void:
	_confirm = {"slot": slot, "action": action}
	_refresh()


func _clear_confirm() -> void:
	_confirm.clear()


# ---------------------------------------------------------------- 点击

func _on_continue(slot: int) -> void:
	_clear_confirm()
	Events.save_load_requested.emit(slot)


## 「新游戏」：槽位为空直接开；已有档要点两次（第二次按钮会变成「确认覆盖？」）。
func _on_new_game(slot: int) -> void:
	var exists := bool(_summary_of(slot).get("exists", false))
	if exists and not _is_confirming(slot, CONFIRM_NEW):
		_set_confirm(slot, CONFIRM_NEW)
		return
	_clear_confirm()
	Events.save_new_game_requested.emit(slot)


func _on_delete(slot: int) -> void:
	if not _is_confirming(slot, CONFIRM_DELETE):
		_set_confirm(slot, CONFIRM_DELETE)
		return
	_clear_confirm()
	Events.save_delete_requested.emit(slot)
