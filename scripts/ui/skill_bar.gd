class_name SkillBar
extends Control
## 底部技能栏：显示当前职业的普攻 / 大招两个槽位（冷却 + 耗蓝 + 快捷键）。
##
## 设计约定：
##   - 只监听 Events 信号更新，不反向引用 Player（与 HUD 同一原则）。
##   - 没有真实图标时用**程序化占位图标**：技能色边框 + 技能名首字。
##     接入真图标后只要在 data/skills.json 填 icon 字段即可（无需改本文件）。
##   - 全部子节点 mouse_filter = IGNORE，否则会挡住鼠标左键攻击。

const SLOT_SIZE := 56.0
const SLOT_GAP := 12.0
const BOTTOM_MARGIN := 28.0
## 槽位快捷键提示（对应 data/skills.json 的约定顺序：0 = 普攻、1 = 大招）
const KEY_HINTS: Array[String] = ["1", "2"]

var _slots: Array = []              # [{panel, label, cd_overlay, cd_label, name_label, key_label}]
var _skills: Array = []             # Array[SkillDef]
var _cooldowns: Dictionary = {}     # {skill_id: 剩余秒数}
var _mana: float = 0.0
var _mana_max: float = 1.0


func _ready() -> void:
	name = "SkillBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_layout()
	_connect_events()


# ---------------------------------------------------------------- 构建

func _build_layout() -> void:
	var bar_w := SLOT_SIZE * 2.0 + SLOT_GAP
	# 锚在屏幕底部正中，窗口尺寸变化时自动跟随
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -bar_w * 0.5
	offset_right = bar_w * 0.5
	offset_top = -(SLOT_SIZE + BOTTOM_MARGIN)
	offset_bottom = -BOTTOM_MARGIN

	for i in range(2):
		var root := Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.position = Vector2(float(i) * (SLOT_SIZE + SLOT_GAP), 0.0)
		root.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		add_child(root)

		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		panel.add_theme_stylebox_override("panel", _slot_style(Color(0.5, 0.5, 0.6)))
		root.add_child(panel)

		# 程序化占位图标：技能名首字
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		root.add_child(label)

		# 冷却遮罩：从顶部向下退去，剩余比例 = 高度比例
		var cd_overlay := ColorRect.new()
		cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_overlay.color = Color(0.0, 0.0, 0.0, 0.66)
		cd_overlay.position = Vector2.ZERO
		cd_overlay.size = Vector2(SLOT_SIZE, 0.0)
		cd_overlay.visible = false
		root.add_child(cd_overlay)

		var cd_label := Label.new()
		cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_label.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_label.add_theme_font_size_override("font_size", 18)
		cd_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
		cd_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		cd_label.add_theme_constant_override("shadow_offset_x", 1)
		cd_label.add_theme_constant_override("shadow_offset_y", 1)
		cd_label.visible = false
		root.add_child(cd_label)

		# 快捷键提示（左上角）
		var key_label := Label.new()
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.position = Vector2(4.0, 1.0)
		key_label.text = KEY_HINTS[i]
		key_label.add_theme_font_size_override("font_size", 11)
		key_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 0.75))
		key_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		key_label.add_theme_constant_override("shadow_offset_x", 1)
		key_label.add_theme_constant_override("shadow_offset_y", 1)
		root.add_child(key_label)

		# 技能名（槽位下方）
		var name_label := Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.position = Vector2(-10.0, SLOT_SIZE + 2.0)
		name_label.size = Vector2(SLOT_SIZE + 20.0, 14.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.95))
		name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		name_label.add_theme_constant_override("shadow_offset_x", 1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		root.add_child(name_label)

		_slots.append({
			"panel": panel,
			"label": label,
			"cd_overlay": cd_overlay,
			"cd_label": cd_label,
			"name_label": name_label,
			"key_label": key_label,
		})
		_apply_slot_style(i, null)


func _slot_style(accent: Color, dim: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.12, 0.88) if not dim else Color(0.06, 0.06, 0.08, 0.88)
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = accent
	return style


# ---------------------------------------------------------------- 信号

func _connect_events() -> void:
	Events.player_skills_changed.connect(_on_skills_changed)
	Events.skill_cooldowns_changed.connect(_on_cooldowns_changed)
	Events.player_mana_changed.connect(_on_mana_changed)
	Events.player_profession_changed.connect(_on_profession_changed)


func _on_skills_changed(skills: Array) -> void:
	_skills = skills
	for i in range(_slots.size()):
		_apply_slot_style(i, _skills[i] if i < _skills.size() else null)
	_on_cooldowns_changed(_cooldowns)
	_refresh_affordable()


func _on_cooldowns_changed(cooldowns: Dictionary) -> void:
	_cooldowns = cooldowns
	for i in range(_slots.size()):
		if i >= _skills.size():
			continue
		var skill: SkillDef = _skills[i]
		var remain := float(_cooldowns.get(skill.id, 0.0))
		var slot: Dictionary = _slots[i]
		var overlay: ColorRect = slot["cd_overlay"]
		var cd_label: Label = slot["cd_label"]
		if remain > 0.0:
			var ratio := clampf(remain / maxf(0.01, skill.cooldown), 0.0, 1.0)
			overlay.visible = true
			overlay.size = Vector2(SLOT_SIZE, SLOT_SIZE * ratio)
			cd_label.visible = true
			cd_label.text = "%.1f" % remain
		else:
			overlay.visible = false
			cd_label.visible = false


func _on_mana_changed(current: int, maximum: int) -> void:
	_mana = float(current)
	_mana_max = float(maxi(1, maximum))
	_refresh_affordable()


func _on_profession_changed(_id: String, _display_name: String, _color: Color) -> void:
	# 职业换色由 player_skills_changed 带来的技能色驱动，这里只需重算可用性
	_refresh_affordable()


# ---------------------------------------------------------------- 刷新

## 蓝不足或冷却中时把槽位压暗，给出"现在点不了"的视觉反馈。
func _refresh_affordable() -> void:
	for i in range(_slots.size()):
		if i >= _skills.size():
			continue
		var skill: SkillDef = _skills[i]
		var slot: Dictionary = _slots[i]
		var cooling := float(_cooldowns.get(skill.id, 0.0)) > 0.0
		var affordable := _mana >= skill.mana_cost
		var dim := cooling or not affordable
		var accent: Color = skill.color
		if not affordable:
			accent = Color(0.45, 0.45, 0.50)
		var panel: Panel = slot["panel"]
		panel.add_theme_stylebox_override("panel", _slot_style(accent, dim))
		var label: Label = slot["label"]
		label.add_theme_color_override("font_color", skill.color if not dim else Color(0.55, 0.55, 0.62))


func _apply_slot_style(index: int, skill: SkillDef) -> void:
	var slot: Dictionary = _slots[index]
	var panel: Panel = slot["panel"]
	var label: Label = slot["label"]
	var name_label: Label = slot["name_label"]
	if skill == null:
		panel.add_theme_stylebox_override("panel", _slot_style(Color(0.30, 0.30, 0.36), true))
		label.text = "—"
		label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
		name_label.text = ""
		return
	label.text = skill.short_label()
	label.add_theme_color_override("font_color", skill.color)
	name_label.text = skill.display_name
