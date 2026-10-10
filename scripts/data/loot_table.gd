class_name LootTable
extends RefCounted
## 掉落表：根据敌人等级随机生成装备。
##
## 所有可调参数集中在 data/loot.json（LootConfig）。
## 加新词条 / 调掉率 / 改名字池 = 改 JSON。

## 主入口：返回一件随机装备（可能为 null）。
static func roll_drop(enemy_level: int) -> GearItem:
	var cfg := LootConfig.load_default()
	if cfg == null:
		return null
	if randf() > cfg.drop_chance:
		return null
	return generate(enemy_level)


## 无条件生成一件装备。
##   forced_rarity_key 非空 → 跳过品质随机（Boss 保底掉落 / 商店货架用）
##   forced_slot_key   非空 → 跳过部位随机（商店要卖指定部位；名字池与词条会跟着该部位走，
##                          所以必须在这里指定，而不能生成完再改 `gear.slot`）
static func generate(enemy_level: int, forced_rarity_key: String = "",
		forced_slot_key: String = "") -> GearItem:
	var cfg := LootConfig.load_default()
	if cfg == null:
		return null
	var gear := GearItem.new()
	var slot_key := forced_slot_key if not forced_slot_key.is_empty() else cfg.pick_slot_key()
	var rarity_key := forced_rarity_key if not forced_rarity_key.is_empty() \
		else cfg.pick_rarity_key()
	gear.slot = cfg.slot_enum_for(slot_key)
	gear.rarity = cfg.rarity_enum_for(rarity_key)
	gear.item_level = maxi(1, enemy_level + randi_range(-cfg.level_jitter, cfg.level_jitter))
	gear.item_name = _pick_name(cfg, slot_key)
	gear.stats = _roll_stats(cfg, gear)
	return gear


static func _pick_name(cfg: LootConfig, slot_key: String) -> String:
	var pool: Array = cfg.name_pools.get(slot_key, ["神秘装备"])
	if pool.is_empty():
		return "神秘装备"
	return pool[randi() % pool.size()]


static func _roll_stats(cfg: LootConfig, gear: GearItem) -> Dictionary:
	var slot_key := cfg.slot_key_for(gear.slot)
	var rarity_key := cfg.rarity_key_for(gear.rarity)
	var spec_root: Dictionary = cfg.stat_specs.get(slot_key, {})
	var out := {}

	var primary: Dictionary = spec_root.get("primary", {})
	if not primary.is_empty():
		_apply_primary(out, primary, gear)

	var secondary: Dictionary = spec_root.get("secondary", {})
	if not secondary.is_empty():
		_apply_secondary(out, secondary, gear, rarity_key)

	return out


## level_scaled: round((base + per_lv * lv) * rarity_mult)
static func _apply_primary(out: Dictionary, spec: Dictionary, gear: GearItem) -> void:
	var stat := String(spec.get("stat", ""))
	if stat.is_empty():
		return
	var lv := float(gear.item_level)
	var mult: float = GearItem.RARITY_MULT.get(gear.rarity, 1.0)
	var value: float = float(spec.get("base", 0.0)) + float(spec.get("per_lv", 0.0)) * lv
	out[stat] = int(round(value * mult))


static func _apply_secondary(out: Dictionary, spec: Dictionary, gear: GearItem, _rarity_key: String) -> void:
	var stat := String(spec.get("stat", ""))
	if stat.is_empty():
		return
	var spec_type := String(spec.get("type", "level_scaled"))
	var mult: float = GearItem.RARITY_MULT.get(gear.rarity, 1.0)

	if spec_type == "rarity_scaled":
		var min_rarity := String(spec.get("min_rarity", "common"))
		var min_enum: int = LootConfig.load_default().rarity_enum_for(min_rarity)
		if int(gear.rarity) < min_enum:
			return
		var per_rarity := float(spec.get("per_rarity", 0.01))
		var rarity_offset := int(spec.get("rarity_offset", 0))
		out[stat] = snappedf(per_rarity * float(int(gear.rarity) + float(rarity_offset)), 0.01)
	else:
		# 默认 level_scaled（与 _apply_primary 同公式）
		var lv := float(gear.item_level)
		var value: float = float(spec.get("base", 0.0)) + float(spec.get("per_lv", 0.0)) * lv
		out[stat] = int(round(value * mult))
