class_name HUD
extends CanvasLayer
## 游戏内 HUD：血条 / 经验 / 等级 / 金币 / 装备栏 / 提示。
##
## 全部通过监听 Events 信号更新，不反向引用游戏对象。

var kills: int = 0

var _hp_bar: ProgressBar
var _hp_label: Label
var _mana_bar: ProgressBar
var _mana_label: Label
var _profession_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _stats_label: Label
var _gold_label: Label
var _kill_label: Label
var _equip_label: RichTextLabel
var _toast_label: Label
var _hint_label: Label
var _toast_tween: Tween

## 底部技能栏（M7）。自身监听 Events，HUD 只负责把它挂上来。
var skill_bar: SkillBar = null


func _ready() -> void:
	layer = 10
	_build()
	skill_bar = SkillBar.new()
	add_child(skill_bar)
	_connect_events()


# ---------------------------------------------------------------- 构建

func _build() -> void:
	_hp_bar = _make_bar(Vector2(24, 24), Vector2(320, 26), Color(0.78, 0.18, 0.22))
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0

	_hp_label = _make_label(Vector2(36, 26), "HP 100 / 100", 15, Color(1, 1, 1, 0.95))

	# 蓝条（M7 技能耗蓝）压在血条下方，颜色用青蓝以区别于蓝色的经验条
	_mana_bar = _make_bar(Vector2(24, 54), Vector2(320, 12), Color(0.28, 0.72, 0.95))
	_mana_bar.max_value = 100.0
	_mana_bar.value = 100.0
	_mana_label = _make_label(Vector2(352, 51), "MP 100 / 100", 11, Color(0.62, 0.86, 1.0))

	_profession_label = _make_label(Vector2(24, 72), "战士", 15, Color(0.9, 0.85, 1.0))
	_level_label = _make_label(Vector2(150, 72), "等级 1", 15, Color(0.9, 0.85, 1.0))

	_xp_bar = _make_bar(Vector2(24, 96), Vector2(320, 8), Color(0.45, 0.75, 1.0))
	_xp_bar.max_value = 100.0
	_xp_bar.value = 0.0

	_stats_label = _make_label(Vector2(24, 110), "", 13, Color(0.75, 0.78, 0.85))

	_gold_label = _make_label(Vector2(940, 24), "金币 0", 18, Color(1.0, 0.84, 0.25))
	_kill_label = _make_label(Vector2(940, 52), "击杀 0", 14, Color(0.8, 0.8, 0.85))

	_equip_label = RichTextLabel.new()
	_equip_label.bbcode_enabled = true
	_equip_label.scroll_active = false
	_equip_label.position = Vector2(24, 430)
	_equip_label.size = Vector2(300, 240)
	_equip_label.add_theme_font_size_override("normal_font_size", 14)
	add_child(_equip_label)

	_toast_label = _make_label(Vector2(420, 120), "", 20, Color.WHITE)
	_hint_label = _make_label(Vector2(24, 690),
		"WASD/方向键 移动   空格/左键 攻击   1/2 技能   Shift 冲刺   F1/F2/F3 切职业",
		13, Color(0.6, 0.6, 0.7))


func _make_bar(pos: Vector2, size: Vector2, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = size
	bar.show_percentage = false

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	background.set_corner_radius_all(4)
	background.set_border_width_all(1)
	background.border_color = Color(0.26, 0.22, 0.32)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)

	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	return bar


func _make_label(pos: Vector2, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label


# ---------------------------------------------------------------- 信号

func _connect_events() -> void:
	Events.player_health_changed.connect(_on_health_changed)
	Events.player_mana_changed.connect(_on_mana_changed)
	Events.player_profession_changed.connect(_on_profession_changed)
	Events.player_level_changed.connect(_on_level_changed)
	Events.player_stats_changed.connect(_on_stats_changed)
	Events.equipment_changed.connect(_on_equipment_changed)
	Events.gold_changed.connect(_on_gold_changed)
	Events.toast.connect(_on_toast)


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_bar.max_value = maxi(1, maximum)
	_hp_bar.value = current
	_hp_label.text = "HP %d / %d" % [current, maximum]


func _on_mana_changed(current: int, maximum: int) -> void:
	_mana_bar.max_value = maxi(1, maximum)
	_mana_bar.value = current
	_mana_label.text = "MP %d / %d" % [current, maximum]


func _on_profession_changed(_id: String, display_name: String, color: Color) -> void:
	_profession_label.text = display_name
	_profession_label.add_theme_color_override("font_color", color)


func _on_level_changed(level: int, xp: int, xp_to_next: int) -> void:
	_level_label.text = "等级 %d" % level
	_xp_bar.max_value = maxi(1, xp_to_next)
	_xp_bar.value = xp


func _on_stats_changed(stats: Dictionary) -> void:
	_stats_label.text = "攻击 %d   护甲 %d   暴击 %d%%   速度 %d" % [
		int(round(float(stats.get("attack", 0.0)))),
		int(round(float(stats.get("armor", 0.0)))),
		int(round(float(stats.get("crit", 0.0)) * 100.0)),
		int(round(float(stats.get("speed", 0.0)))),
	]


func _on_gold_changed(amount: int) -> void:
	_gold_label.text = "金币 %d" % amount


func _on_equipment_changed(equipment: Dictionary) -> void:
	var lines: Array[String] = ["[b]装备栏[/b]"]
	for slot in GearItem.SLOT_ORDER:
		var gear: GearItem = equipment.get(slot)
		var slot_name: String = GearItem.SLOT_NAMES.get(slot, "?")
		if gear == null:
			lines.append("[color=#666670]%s：空[/color]" % slot_name)
		else:
			var hex := gear.rarity_color().to_html(false)
			lines.append("[color=#%s]%s：%s[/color]" % [hex, slot_name, gear.item_name])
	_equip_label.text = "\n".join(lines)


func _on_toast(message: String, color: Color) -> void:
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", color)
	_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.3)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.8)


func refresh_kills() -> void:
	_kill_label.text = "击杀 %d" % kills
