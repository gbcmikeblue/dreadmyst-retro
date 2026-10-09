# 模块：掉落与装备（数据层）

**文件**：`scripts/data/gear_item.gd`、`loot_config.gd`、`loot_table.gd`、`enemy_archetype.gd`、`enemy_registry.gd`
**数据**：`data/loot.json`、`data/enemies.json`
**注意**：职业与技能的数据层**不在本模块**，见 [skills.md](skills.md)（`data/professions.json`、`data/skills.json`）。

本模块是数据驱动改造（M5）的产物：**加内容只改 JSON，不改代码**。

## 1. GearItem（装备模型，Resource）

### 枚举

| 枚举 | 值 |
| --- | --- |
| Slot（5） | WEAPON 武器 / HELMET 头盔 / ARMOR 护甲 / BOOTS 战靴 / RING 戒指 |
| Rarity（5） | COMMON 普通 / UNCOMMON 优秀 / RARE 稀有 / EPIC 史诗 / LEGENDARY 传说 |

### 品质参数

| 品质 | 颜色 | 词条倍率 | 掉落权重 |
| --- | --- | --- | --- |
| 普通 | 灰 (0.80,0.80,0.80) | ×1.0 | 60 |
| 优秀 | 绿 (0.35,0.90,0.35) | ×1.6 | 25 |
| 稀有 | 蓝 (0.35,0.62,1.00) | ×2.4 | 10 |
| 史诗 | 紫 (0.76,0.42,1.00) | ×3.4 | 4 |
| 传说 | 橙 (1.00,0.62,0.12) | ×4.8 | 1 |

### 词条（5 种，键为字符串）
`attack` 攻击力 / `max_hp` 生命上限 / `armor` 护甲 / `crit` 暴击率(0~1) / `speed` 移动速度

### 方法
- `power_score()`：装备评分 = attack×2 + max_hp×0.15 + armor×1.5 + crit×200 + speed×0.5（用于自动穿/分解比较）
- `tooltip()`：多行描述文本

## 2. LootConfig（loot.json 加载器）

静态缓存 `load_default()`。字段：`drop_chance`（0.55）、`level_jitter`（±1）、`slot_weights`、`rarity_weights`、`name_pools`、`stat_specs`。

枚举映射：`slot_enum_for/rarity_enum_for`（字符串→枚举）与反向。加权抽取：`pick_slot_key()/pick_rarity_key()`。

### 词条公式（stat_specs）

两种类型，由 LootTable 解释：

```jsonc
// level_scaled：value = round((base + per_lv × lv) × rarity_mult)
{ "type": "level_scaled", "stat": "attack", "base": 5.0, "per_lv": 2.2 }

// rarity_scaled：需品质 ≥ min_rarity 才出现，value = per_rarity × (rarity + offset)
{ "type": "rarity_scaled", "stat": "crit", "per_rarity": 0.01, "rarity_offset": -1, "min_rarity": "rare" }
```

当前配置：武器 attack+crit(稀有+)、头盔 hp+armor、护甲 armor+hp、战靴 speed+armor、戒指 attack+crit。

## 3. 敌人原型（enemies.json）

### EnemyArchetype 字段组

- **标识**：`id`、`display_name`、`spawn_weight`
- **数值公式**：`hp_base/hp_per_lv`、`attack_base/attack_per_lv`、`speed_base/speed_jitter/speed_per_lv`、`radius_base/radius_jitter`
- **行为**：`attack_range`、`attack_interval`、`knockback_distance`
- **外观**：`sprite_path`（真实贴图路径，**留空则用程序化占位贴图**）、`body_color`、`outline_color`、`eye_color`、`hp_bar_color`（均 [r,g,b]）、`body_outline_width`

派生：`hp = hp_base + hp_per_lv×lv`；`speed = base ± jitter + per_lv×lv`；`radius = base ± jitter`。

### 当前 3 种原型（lv1 实际值）

| id | 名 | hp | atk | 定位 | 权重 |
| --- | --- | --- | --- | --- | --- |
| slime | 粘液怪 | 50 | 7.4 | 标准怪（绿色） | 5.0 |
| brute | 重甲兽人 | 152 | 12.2 | 高血高攻慢速大体型（棕） | 1.0 |
| wisp | 幽影 | 31 | 6.3 | 低血高速高频（紫） | 1.5 |

### EnemyRegistry
`load_default()` 静态缓存；`pick_weighted()` 按 spawn_weight 加权抽取（200 次实测分布与理论吻合）。

## 4. 自测

```powershell
godot --headless --path . --script res://tests/test_data_layer.gd
```

覆盖：JSON 加载、8 件随机装备生成（数值与手算一致）、加权抽取 200 次分布校验。

## TODO

- [ ] 名字池按品质分层（当前所有品质共用一个池）
- [ ] 套装 / 更多词条（生命偷取、元素伤、抗性）待原作资料
- [ ] LootConfig 静态缓存无失效机制（改 JSON 需重启，可接受）
