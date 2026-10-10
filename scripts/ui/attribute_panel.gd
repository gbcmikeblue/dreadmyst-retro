class_name AttributePanel
extends CanvasLayer
## M8 属性加点界面（C 键开关）。
##
## 设计约定（与 SkillBar / HUD 一致）：
##   - 只监听 Events 信号刷新，**不反向引用 Player**；点「+」只发
##     `attribute_allocate_requested`，实际加点在 Player 里执行。
##   - 没有真实图标时用**程序化占位图标**：属性色边框 + 属性名首字。
##     接入真图标后只要给 data/attributes.json 补 `icon` 字段（当前 AttributeDef 尚未读取）。
##   - 打开时把自身加入 `modal_ui` 组，Player 据此冻结移动 / 攻击
##     ——按钮只拦 GUI 事件，拦不住玩家那种轮询式读输入（Input.is_action_pressed）。
##   - 所有按钮 `focus_mode = FOCUS_NONE`，否则点过之后空格 / 回车会重复触发按钮而不是攻击。

const WINDOW_SIZE := Vector2(560.0, 440.0)
const ROW_SIZE := Vector2(520.0, 58.0)
const ROW_GAP := 6.0
const ROWS_TOP := 76.0
const ICON_SIZE := 40.0

## stat 键 -> 中文说明。crit 是比例，单独按百分比显示。
const STAT_NAMES := {
	"attack": "攻击",
	"max_hp": "生命",
	"armor": "护甲",
	"crit": "暴击",
	"speed": "速度",
	"max_mana": "法力",
	"mana_regen": "回蓝",
}

var _backdrop: ColorRect
var _window: Panel
var _points_label: Label
## [{id, accent, points_label, bonus_label, plus1, plus5}]
var _rows: Array = []
var _attributes: Dictionary = {}    # {属性 id: 已投入点数}
var _free_points: int = 0
var _spent_points: int = 0


func _ready() -> void:
	name = "AttributePanel"
	layer = 20                                  # 盖在 HUD（10）之上、DevPause（100）之下
	process_mode = Node.PROCESS_MODE_ALWAYS     # 暂停时也要能开关与点按钮
	_build()
	_connect_events()
	_set_open(false)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("attributes"):
		toggle()


# ---------------------------------------------------------------- 开关

func toggle() -> void:
	_set_open(not visible)


func _set_open(open: bool) -> void:
	visible = open
	if open:
		add_to_group("modal_ui")
		_refresh()
	elif is_in_group("modal_ui"):
		remove_from_group("modal_ui")


# ---------------------------------------------------------------- 构建

func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.02, 0.04, 0.55)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 吃掉点击，避免透过面板误操作到游戏（玩家侧另有 modal_ui 冻结）
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
	_window.add_theme_stylebox_override("panel", _window_style())
	add_child(_window)

	_make_label(_window, Vector2(20.0, 12.0), Vector2(240.0, 26.0),
		"属性加点", 20, Color(0.94, 0.95, 1.0))

	_points_label = _make_label(_window, Vector2(20.0, 44.0), Vector2(400.0, 20.0),
		"", 14, Color(0.72, 0.74, 0.80))

	var close := _make_button(_window, Vector2(WINDOW_SIZE.x - 104.0, 12.0),
		Vector2(88.0, 30.0), "关闭 (C)")
	close.pressed.connect(toggle)

	_build_rows()


func _build_rows() -> void:
	var ids := AttributeRegistry.ids()
	for i in range(ids.size()):
		var id := ids[i]
		var attr := AttributeRegistry.get_attribute(id)
		var accent := attr.color if attr != null else Color(0.6, 0.6, 0.65)

		var row := Panel.new()
		row.position = Vector2(20.0, ROWS_TOP + float(i) * (ROW_SIZE.y + ROW_GAP))
		row.size = ROW_SIZE
		row.add_theme_stylebox_override("panel", _row_style(accent))
		_window.add_child(row)

		# 程序化占位图标：属性色边框 + 属性名首字
		var icon_bg := Panel.new()
		icon_bg.position = Vector2(9.0, 9.0)
		icon_bg.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon_bg.add_theme_stylebox_override("panel", _icon_style(accent))
		row.add_child(icon_bg)

		var icon_label := _make_label(icon_bg, Vector2.ZERO, Vector2(ICON_SIZE, ICON_SIZE),
			attr.short_label() if attr != null else "?", 20, accent)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		_make_label(row, Vector2(58.0, 5.0), Vector2(160.0, 20.0),
			attr.display_name if attr != null else id, 15, Color(0.92, 0.93, 0.98))
		_make_label(row, Vector2(58.0, 27.0), Vector2(236.0, 18.0),
			attr.description if attr != null else "", 11, Color(0.62, 0.64, 0.72))

		var points_label := _make_label(row, Vector2(300.0, 6.0), Vector2(120.0, 18.0),
			"", 13, Color(0.88, 0.90, 0.96))
		points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var bonus_label := _make_label(row, Vector2(300.0, 27.0), Vector2(120.0, 18.0),
			"", 11, accent)
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var plus1 := _make_button(row, Vector2(426.0, 17.0), Vector2(40.0, 24.0), "+1")
		plus1.pressed.connect(_request_allocate.bind(id, 1))
		var plus5 := _make_button(row, Vector2(470.0, 17.0), Vector2(40.0, 24.0), "+5")
		plus5.pressed.connect(_request_allocate.bind(id, 5))

		_rows.append({
			"id": id,
			"accent": accent,
			"points_label": points_label,
			"bonus_label": bonus_label,
			"plus1": plus1,
			"plus5": plus5,
		})


func _window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.10, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.30, 0.26, 0.38)
	style.shadow_size = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	return style


func _row_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.13, 0.92)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	return style


func _icon_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	style.border_color = accent
	return style


func _make_label(parent: Node, pos: Vector2, size: Vector2, text: String,
		font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label


func _make_button(parent: Node, pos: Vector2, size: Vector2, text: String) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = size
	button.text = text
	# 不吃键盘焦点：否则点过一次后，空格 / 回车会重复触发按钮而不是攻击
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	parent.add_child(button)
	return button


# ---------------------------------------------------------------- 信号

func _connect_events() -> void:
	Events.attributes_changed.connect(_on_attributes_changed)


func _on_attributes_changed(attributes: Dictionary, free_points: int, spent_points: int) -> void:
	_attributes = attributes
	_free_points = free_points
	_spent_points = spent_points
	if visible:
		_refresh()


## UI -> 事件总线 -> Player：不直接引用 Player。
func _request_allocate(attribute_id: String, points: int) -> void:
	Events.attribute_allocate_requested.emit(attribute_id, points)


# ---------------------------------------------------------------- 刷新

func _refresh() -> void:
	_points_label.text = "剩余属性点：%d        已投入：%d" % [_free_points, _spent_points]
	_points_label.add_theme_color_override("font_color",
		Color(1.0, 0.86, 0.32) if _free_points > 0 else Color(0.72, 0.74, 0.80))

	for row in _rows:
		var attr := AttributeRegistry.get_attribute(String(row["id"]))
		if attr == null:
			continue
		var points := int(_attributes.get(attr.id, 0))
		var capped := attr.is_capped(points)

		var points_label: Label = row["points_label"]
		var bonus_label: Label = row["bonus_label"]
		if attr.max_points > 0:
			points_label.text = "%d / %d" % [points, attr.max_points]
		else:
			points_label.text = "%d" % points

		if capped:
			bonus_label.text = "满级"
			bonus_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
		else:
			bonus_label.text = _bonus_text(attr, points)
			bonus_label.add_theme_color_override("font_color", row["accent"])

		# 「不可加」的三种原因：没点数 / 已满级 / 一次加 5 会超上限
		var can_add_once := _free_points > 0 and not capped
		var can_add_five := can_add_once and _free_points >= 5 \
			and (attr.max_points == 0 or points + 5 <= attr.max_points)
		var plus1: Button = row["plus1"]
		var plus5: Button = row["plus5"]
		plus1.disabled = not can_add_once
		plus5.disabled = not can_add_five


## 已投入点数带来的实际加成文本，例如「攻击 +24 护甲 +4」。
func _bonus_text(attr: AttributeDef, points: int) -> String:
	if points <= 0:
		return "未加点"
	var parts: Array[String] = []
	for key in attr.per_point:
		var stat_name: String = STAT_NAMES.get(key, String(key))
		var value := float(attr.per_point[key]) * float(points)
		if key == "crit":
			parts.append("%s +%.1f%%" % [stat_name, value * 100.0])
		else:
			parts.append("%s +%d" % [stat_name, int(round(value))])
	return " ".join(parts)
