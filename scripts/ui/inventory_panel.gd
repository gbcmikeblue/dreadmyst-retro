class_name InventoryPanel
extends CanvasLayer
## M11 背包 / 商店界面（`I` 或 `B` 开关）。
##
## 约定（与 AttributePanel 完全一致）：
##   - 只监听 `Events`、只发请求，**不引用 Player**；卖出价公式从数据层
##     `InventoryConfig.sell_price_for()` 取，与 Player 用的是同一份口径。
##   - 打开时加入 `modal_ui` 组，`Player` 据此冻结移动与攻击。
##   - 所有按钮 `focus_mode = FOCUS_NONE`，否则点过之后空格 / 回车会重复触发按钮。
##   - 装备图标是**程序化占位**（品质色边框 + 名字首字）：接入真图标时改
##     `_refresh_bag()` 里的格子刷新（换成 TextureRect）即可，其余逻辑不用动。
##
## 页签：「背包」（装备栏 + 格子 + 选中详情与对比）/「商店」（货架 + 购买 + 刷新）。

const WINDOW_SIZE := Vector2(760.0, 470.0)
const GRID_COLS := 6
const CELL := 52.0
const CELL_GAP := 4.0
## 空格子上显示的字
const EMPTY_MARK := "空"

const EMPTY_CELL_BG := Color(0.08, 0.08, 0.10, 0.85)
const EMPTY_CELL_BORDER := Color(0.20, 0.20, 0.24)

var _backdrop: ColorRect
var _window: Panel
var _tab_bag: Button
var _tab_shop: Button
var _gold_label: Label
var _bag_page: Control
var _shop_page: Control

# --- 背包页 ---
var _equip_labels: Array = []      # Array[RichTextLabel]，下标与 GearItem.SLOT_ORDER 对齐
var _summary_label: RichTextLabel
var _bag_count_label: Label
var _cells: Array = []             # Array[Button]
var _detail_label: RichTextLabel
var _equip_button: Button
var _sell_button: Button
var _optimize_button: Button

# --- 商店页 ---
var _shop_hint: Label
var _restock_button: Button
var _offer_labels: Array = []      # Array[RichTextLabel]
var _offer_buttons: Array = []     # Array[Button]

# --- 状态 ---
var _backpack: Array = []          # Array[GearItem]
var _capacity: int = 24
var _equipment: Dictionary = {}
var _stats: Dictionary = {}
var _stock: Array = []
var _selected: int = -1
var _gold: int = 0
var _offer_count: int = 0


func _ready() -> void:
	name = "InventoryPanel"
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capacity = InventoryConfig.load_default().backpack_capacity
	_offer_count = maxi(1, ShopConfig.load_default().offers.size())
	_build()
	_connect_events()
	_set_open(false)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		toggle()


# ---------------------------------------------------------------- 开关 / 页签

func toggle() -> void:
	_set_open(not visible)


func _set_open(open: bool) -> void:
	visible = open
	if open:
		add_to_group("modal_ui")
		_selected = -1
		_refresh_all()
	elif is_in_group("modal_ui"):
		remove_from_group("modal_ui")


func _show_bag() -> void:
	_bag_page.visible = true
	_shop_page.visible = false
	_refresh_bag()


func _show_shop() -> void:
	_bag_page.visible = false
	_shop_page.visible = true
	# 货架由 Shop 节点持有，这里只是「拉一次最新货架」（UI 不持有商店状态）
	Events.shop_stock_requested.emit()
	_refresh_shop()


# ---------------------------------------------------------------- 构建

func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.02, 0.04, 0.55)
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
	_window.add_theme_stylebox_override("panel", _window_style())
	add_child(_window)

	_make_label(_window, Vector2(20.0, 12.0), Vector2(150.0, 26.0), "背包 / 商店", 20,
		Color(0.94, 0.95, 1.0))
	_tab_bag = _make_button(_window, Vector2(170.0, 12.0), Vector2(80.0, 30.0), "背包")
	_tab_bag.pressed.connect(_show_bag)
	_tab_shop = _make_button(_window, Vector2(256.0, 12.0), Vector2(80.0, 30.0), "商店")
	_tab_shop.pressed.connect(_show_shop)

	var close := _make_button(_window, Vector2(WINDOW_SIZE.x - 104.0, 12.0),
		Vector2(88.0, 30.0), "关闭 (I)")
	close.pressed.connect(toggle)

	_gold_label = _make_label(_window, Vector2(WINDOW_SIZE.x - 400.0, 18.0),
		Vector2(286.0, 20.0), "", 15, Color(1.0, 0.84, 0.25))
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_bag_page = _build_bag_page()
	_shop_page = _build_shop_page()
	_window.add_child(_bag_page)
	_window.add_child(_shop_page)
	_show_bag()


func _build_bag_page() -> Control:
	var page := Control.new()
	page.size = WINDOW_SIZE

	# 左列：装备中
	_make_label(page, Vector2(20.0, 52.0), Vector2(320.0, 20.0), "装备中", 15,
		Color(0.86, 0.88, 0.95))
	for i in range(GearItem.SLOT_ORDER.size()):
		var label := _make_rich(page, Vector2(20.0, 76.0 + float(i) * 28.0),
			Vector2(330.0, 26.0), 13)
		_equip_labels.append(label)

	_summary_label = _make_rich(page, Vector2(20.0, 226.0), Vector2(340.0, 64.0), 12)

	# 右列：背包格子
	_bag_count_label = _make_label(page, Vector2(380.0, 52.0), Vector2(180.0, 20.0), "",
		15, Color(0.86, 0.88, 0.95))
	_optimize_button = _make_button(page, Vector2(580.0, 48.0), Vector2(160.0, 28.0), "一键换装")
	_optimize_button.pressed.connect(_on_optimize_pressed)

	for i in range(_capacity):
		var col := i % GRID_COLS
		# 用 float 除法再取整：int / int 会触发 GDScript 的 INTEGER_DIVISION 警告
		var row := int(floor(float(i) / float(GRID_COLS)))
		var cell := _make_button(page,
			Vector2(380.0 + float(col) * (CELL + CELL_GAP),
				80.0 + float(row) * (CELL + CELL_GAP)),
			Vector2(CELL, CELL), "")
		cell.add_theme_font_size_override("font_size", 18)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		_cells.append(cell)

	# 底部：选中详情与对比
	_detail_label = _make_rich(page, Vector2(20.0, 300.0), Vector2(520.0, 150.0), 13)
	_equip_button = _make_button(page, Vector2(560.0, 300.0), Vector2(180.0, 34.0), "装备")
	_equip_button.pressed.connect(_on_equip_pressed)
	_sell_button = _make_button(page, Vector2(560.0, 342.0), Vector2(180.0, 34.0), "分解")
	_sell_button.pressed.connect(_on_sell_pressed)
	return page


func _build_shop_page() -> Control:
	var page := Control.new()
	page.size = WINDOW_SIZE
	page.visible = false

	_make_label(page, Vector2(20.0, 52.0), Vector2(320.0, 20.0), "货架", 15,
		Color(0.86, 0.88, 0.95))
	_shop_hint = _make_label(page, Vector2(20.0, 74.0), Vector2(520.0, 18.0), "", 12,
		Color(0.80, 0.62, 0.40))
	_restock_button = _make_button(page, Vector2(580.0, 48.0), Vector2(160.0, 28.0), "刷新货架")
	_restock_button.pressed.connect(_on_restock_pressed)

	for i in range(_offer_count):
		var y := 100.0 + float(i) * 66.0
		var row := Panel.new()
		row.position = Vector2(20.0, y)
		row.size = Vector2(WINDOW_SIZE.x - 40.0, 60.0)
		row.add_theme_stylebox_override("panel",
			_panel_style(Color(0.10, 0.10, 0.13, 0.92), Color(0.32, 0.30, 0.40)))
		page.add_child(row)

		var label := _make_rich(row, Vector2(12.0, 8.0), Vector2(480.0, 46.0), 13)
		_offer_labels.append(label)
		var buy := _make_button(row, Vector2(520.0, 14.0), Vector2(120.0, 32.0), "购买")
		buy.pressed.connect(_on_buy_pressed.bind(i))
		_offer_buttons.append(buy)
	return page


# ---------------------------------------------------------------- 样式小工具

func _window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.10, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.30, 0.26, 0.38)
	style.shadow_size = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	return style


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = border
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


func _make_rich(parent: Node, pos: Vector2, size: Vector2, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.position = pos
	label.size = size
	label.bbcode_enabled = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", font_size)
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
	Events.backpack_changed.connect(_on_backpack_changed)
	Events.equipment_changed.connect(_on_equipment_changed)
	Events.player_stats_changed.connect(_on_stats_changed)
	Events.gold_changed.connect(_on_gold_changed)
	Events.shop_stock_changed.connect(_on_stock_changed)


func _on_backpack_changed(items: Array, capacity: int) -> void:
	_backpack = items
	_capacity = maxi(1, capacity)
	if _selected >= _backpack.size():
		_selected = -1
	if visible:
		_refresh_bag()


func _on_equipment_changed(equipment: Dictionary) -> void:
	_equipment = equipment
	if visible:
		_refresh_bag()


func _on_stats_changed(stats: Dictionary) -> void:
	_stats = stats
	if visible:
		_refresh_bag()


func _on_gold_changed(amount: int) -> void:
	_gold = amount
	_refresh_gold()
	if visible:
		_refresh_buttons()


func _on_stock_changed(offers: Array) -> void:
	_stock = offers
	if visible:
		_refresh_shop()


# ---------------------------------------------------------------- 刷新

func _refresh_all() -> void:
	_refresh_gold()
	if _bag_page.visible:
		_refresh_bag()
	else:
		_refresh_shop()


func _refresh_gold() -> void:
	_gold_label.text = "金币 %d" % _gold


func _refresh_bag() -> void:
	_bag_count_label.text = "背包 %d / %d" % [_backpack.size(), _capacity]

	for i in range(GearItem.SLOT_ORDER.size()):
		var slot: int = GearItem.SLOT_ORDER[i]
		var gear: GearItem = _equipment.get(slot)
		var label: RichTextLabel = _equip_labels[i]
		var slot_name: String = GearItem.SLOT_NAMES.get(slot, "?")
		if gear == null:
			label.text = "[color=#666670]%s：（空）[/color]" % slot_name
		else:
			label.text = "[color=#%s]%s：%s[/color]  [color=#8a8d99]%s[/color]" % [
				gear.rarity_color().to_html(false), slot_name, gear.item_name, _stat_text(gear)]

	_summary_label.text = _summary_text()
	_refresh_cells()
	_refresh_detail()
	_refresh_buttons()


## 角色总属性（来自 Player 广播的 player_stats_changed，含职业 / 属性点 / 装备加成）。
func _summary_text() -> String:
	if _stats.is_empty():
		return "[color=#8a8d99]总属性：等待数据…[/color]"
	return "[color=#8a8d99]总属性[/color]\n攻击 %d   护甲 %d   暴击 %.1f%%   速度 %d\n生命 %d   法力 %d   回蓝 %.1f/s" % [
		int(round(float(_stats.get("attack", 0.0)))),
		int(round(float(_stats.get("armor", 0.0)))),
		float(_stats.get("crit", 0.0)) * 100.0,
		int(round(float(_stats.get("speed", 0.0)))),
		int(round(float(_stats.get("max_hp", 0.0)))),
		int(round(float(_stats.get("max_mana", 0.0)))),
		float(_stats.get("mana_regen", 0.0)),
	]


func _refresh_cells() -> void:
	for i in range(_cells.size()):
		var cell: Button = _cells[i]
		var gear := _backpack_item(i)
		if gear == null:
			# 空格子：不 disable（禁用态用的是主题另一套样式，会跟面板风格不一致），
			# 只在 _on_cell_pressed() 里忽略点击
			cell.text = EMPTY_MARK if i < _capacity else ""
			cell.add_theme_stylebox_override("normal", _panel_style(EMPTY_CELL_BG, EMPTY_CELL_BORDER))
			cell.add_theme_stylebox_override("hover", _panel_style(EMPTY_CELL_BG, EMPTY_CELL_BORDER))
			cell.add_theme_stylebox_override("pressed", _panel_style(EMPTY_CELL_BG, EMPTY_CELL_BORDER))
			cell.add_theme_color_override("font_color", Color(0.42, 0.42, 0.48))
			continue

		# 程序化占位图标：品质色边框 + 名字首字（接真图标后换成 TextureRect）
		var accent := gear.rarity_color()
		var selected := i == _selected
		var bg := Color(0.20, 0.20, 0.28, 0.98) if selected else Color(0.12, 0.12, 0.16, 0.95)
		var border := Color(1.0, 0.92, 0.6) if selected else accent
		cell.text = gear.item_name.substr(0, 1)
		cell.add_theme_stylebox_override("normal", _panel_style(bg, border))
		cell.add_theme_stylebox_override("hover", _panel_style(bg, Color(1, 1, 1, 0.9)))
		cell.add_theme_stylebox_override("pressed", _panel_style(bg, border))
		cell.add_theme_color_override("font_color", accent)


func _refresh_detail() -> void:
	var gear := _backpack_item(_selected)
	if gear == null:
		_detail_label.text = "[color=#8a8d99]点一个背包格子看详情与对比（与当前部位对比，绿色 = 有提升）[/color]"
		return
	var current: GearItem = _equipment.get(gear.slot)
	var lines: Array[String] = []
	lines.append("[color=#%s]%s[/color]  [color=#8a8d99]%s · %d 级[/color]" % [
		gear.rarity_color().to_html(false), gear.item_name, gear.slot_name(), gear.item_level])
	lines.append("属性：%s" % _stat_text(gear))
	lines.append("对比当前：%s" % _delta_text(gear, current))
	lines.append("[color=#8a8d99]分解可得 %d 金币[/color]" % sell_price(gear))
	_detail_label.text = "\n".join(lines)


func _refresh_buttons() -> void:
	var gear := _backpack_item(_selected)
	_equip_button.disabled = gear == null
	_sell_button.disabled = gear == null
	_sell_button.text = "分解 (+%d 金)" % sell_price(gear) if gear != null else "分解"
	_optimize_button.disabled = _backpack.is_empty()

	var cost := restock_cost()
	_restock_button.text = "刷新货架 (-%d)" % cost
	_restock_button.disabled = _gold < cost

	var bag_full := _backpack.size() >= _capacity
	_shop_hint.text = "背包已满：先分解或装备再购买" if bag_full else ""
	for i in range(_offer_buttons.size()):
		var button: Button = _offer_buttons[i]
		if i >= _stock.size():
			button.text = "购买"
			button.disabled = true
			continue
		var price := int(_stock[i]["price"])
		button.text = "购买 %d" % price
		button.disabled = bag_full or _gold < price


func _refresh_shop() -> void:
	for i in range(_offer_labels.size()):
		var label: RichTextLabel = _offer_labels[i]
		if i >= _stock.size():
			label.text = "[color=#8a8d99]（空货架）[/color]"
			continue
		var entry: Dictionary = _stock[i]
		var gear: GearItem = entry["gear"]
		label.text = "[color=#%s]%s[/color]  [color=#8a8d99]%s · %d 级[/color]\n%s" % [
			gear.rarity_color().to_html(false), gear.item_name, gear.slot_name(),
			gear.item_level, _stat_text(gear)]
	_refresh_buttons()


# ---------------------------------------------------------------- 请求（UI -> 事件总线）

func _on_cell_pressed(index: int) -> void:
	if _backpack_item(index) == null:
		return
	_selected = index
	_refresh_bag()


func _on_equip_pressed() -> void:
	if _selected < 0:
		return
	Events.backpack_equip_requested.emit(_selected)
	_selected = -1
	_refresh_bag()


func _on_sell_pressed() -> void:
	if _selected < 0:
		return
	Events.backpack_sell_requested.emit(_selected)
	_selected = -1
	_refresh_bag()


func _on_optimize_pressed() -> void:
	Events.backpack_optimize_requested.emit()


func _on_buy_pressed(offer_index: int) -> void:
	Events.shop_buy_requested.emit(offer_index)


func _on_restock_pressed() -> void:
	Events.shop_restock_requested.emit()


# ---------------------------------------------------------------- 文本工具

## 一件装备的加成文本，例如「攻击力 +12  护甲 +5」。
func _stat_text(gear: GearItem) -> String:
	if gear.stats.is_empty():
		return "无词条"
	var parts: Array[String] = []
	for key in gear.stats:
		var stat_name: String = GearItem.STAT_NAMES.get(key, String(key))
		var value := float(gear.stats[key])
		if key == "crit":
			parts.append("%s +%.1f%%" % [stat_name, value * 100.0])
		else:
			parts.append("%s +%d" % [stat_name, int(round(value))])
	return "  ".join(parts)


## 与当前部位已装备的那件对比，只列出有变化的词条（绿 = 提升 / 红 = 下降）。
func _delta_text(gear: GearItem, current: GearItem) -> String:
	if current == null:
		return "[color=#7fe07f]该部位还是空的，装上就是纯提升[/color]"
	var keys: Array[String] = []
	for key in gear.stats:
		if not keys.has(String(key)):
			keys.append(String(key))
	for key in current.stats:
		if not keys.has(String(key)):
			keys.append(String(key))

	var parts: Array[String] = []
	for key in keys:
		var stat_name: String = GearItem.STAT_NAMES.get(key, key)
		var delta := float(gear.stats.get(key, 0.0)) - float(current.stats.get(key, 0.0))
		if key == "crit":
			delta *= 100.0
			if is_zero_approx(delta):
				continue
			parts.append("%s %+.1f%%" % [stat_name, delta])
		else:
			if is_zero_approx(delta):
				continue
			parts.append("%s %+d" % [stat_name, int(round(delta))])
	if parts.is_empty():
		return "[color=#8a8d99]数值相同[/color]"
	var color := "#7fe07f" if gear.power_score() >= current.power_score() else "#ff8080"
	return "[color=%s]%s[/color]" % [color, "  ".join(parts)]


func _backpack_item(index: int) -> GearItem:
	if index < 0 or index >= _backpack.size():
		return null
	return _backpack[index]


## 与 Player 同一份公式（数据层），UI 不引用 Player。
func sell_price(gear: GearItem) -> int:
	return InventoryConfig.load_default().sell_price_for(gear)


func restock_cost() -> int:
	return ShopConfig.load_default().restock_cost
