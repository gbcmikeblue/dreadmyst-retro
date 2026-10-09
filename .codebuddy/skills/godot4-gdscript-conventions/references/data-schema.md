# 数据表结构与加载器约定

本项目的「数据驱动」指：策划可调的数值 / 名字 / 颜色 / 权重 / 贴图路径全部放 `data/*.json`，
**加内容不改代码**。本文件记录两张现有表的字段含义与加载器对应关系。

统一约定：

- 顶层固定 `{"version": N, "<items>": [...]}`。
- 颜色统一写 `[r, g, b]`（浮点 0~1），可带第 4 位 alpha；**不要写 CSS 十六进制**。
- 加载器统一 `FileAccess.get_file_as_string` + `JSON.parse_string`，
  **必须**校验 `typeof(parsed) == TYPE_DICTIONARY`；用 `static var _cached` 缓存，
  并提供 `clear_cache()` 供测试 / 热重载使用。
- 字段名与 JSON key **完全同名**，且脚本里给出与 JSON 一致的默认值（缺字段能退化运行）。

---

## 1. `data/loot.json` → `LootConfig` → `LootTable`

### 字段

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `version` | int | 表版本号 |
| `drop_chance` | float 0~1 | 敌人死亡时的掉落概率 |
| `level_jitter` | int | 掉落物等级相对敌人等级的浮动范围（± 值） |
| `slot_weights` | `{slot_key: weight}` | 部位相对权重。key 必须是 `LootConfig._SLOT_KEY_TO_ENUM` 里的 5 个之一 |
| `rarity_weights` | `{rarity_key: weight}` | 品质相对权重。key 必须是 `_RARITY_KEY_TO_ENUM` 里的 5 个之一 |
| `name_pools` | `{slot_key: [名字...]}` | 每个部位的名字池，随机取一个 |
| `stat_specs` | `{slot_key: {primary, secondary}}` | 每个部位的词条公式 |

合法 key：

- `slot_key` ∈ `weapon`(武器) / `helmet`(头盔) / `armor`(护甲) / `boots`(战靴) / `ring`(戒指)
- `rarity_key` ∈ `common`(普通) / `uncommon`(优秀) / `rare`(稀有) / `epic`(史诗) / `legendary`(传说)

### 词条公式的两种类型

| `type` | 公式 | 用在哪 |
| --- | --- | --- |
| `level_scaled` | `round((base + per_lv × 物品等级) × 品质倍率)` | `primary` 与多数 `secondary` |
| `rarity_scaled` | `snappedf(per_rarity × (品质枚举值 + rarity_offset), 0.01)` | 只随品质增长（如暴击率） |

`rarity_scaled` 的额外字段：

- `min_rarity`：低于该品质**不给这条词条**（例：`"min_rarity": "rare"` = 稀有及以上才有）
- `rarity_offset`：枚举值偏移，用来把「普通」从 0 抬到 1，避免 0 词条

品质倍率 `GearItem.RARITY_MULT`：普通 1.0 / 优秀 1.6 / 稀有 2.4 / 史诗 3.4 / 传说 4.8。

### 装备生成流程（`LootTable`）

```
roll_drop(enemy_level)
 └─ randf() > drop_chance  → null
 └─ generate(enemy_level)
     ├─ pick_slot_key()     加权抽部位
     ├─ pick_rarity_key()   加权抽品质
     ├─ item_level = max(1, enemy_level ± level_jitter)
     ├─ item_name  = 该部位名字池随机一个
     └─ stats      = primary + secondary 两条公式
```

### 加一条内容的最小改动

| 想做什么 | 改哪里 |
| --- | --- |
| 加一个武器名字 | `name_pools.weapon` 数组追加 |
| 调掉率 / 调品质分布 | `drop_chance` / `rarity_weights` |
| 让戒指也能出护甲词条 | `stat_specs.ring` 加一条 |
| 加**新部位**（如项链） | 改代码：`GearItem.Slot` 加枚举、`SLOT_NAMES`/`RARITY_*`、`LootConfig` 的 4 张映射表都补 key，再补 JSON |

---

## 2. `data/enemies.json` → `EnemyRegistry` → `EnemyArchetype`

### 单条原型字段

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | String | 唯一标识（也是 `Events` / 日志里用的名字） |
| `display_name` | String | 中文显示名 |
| `spawn_weight` | float | 刷怪相对权重（`EnemyRegistry.pick_weighted()`） |
| `hp_base` / `hp_per_lv` | float | `compute_hp(lv) = hp_base + hp_per_lv × lv` |
| `attack_base` / `attack_per_lv` | float | `compute_attack(lv)` 同公式 |
| `speed_base` / `speed_jitter` / `speed_per_lv` | float | `compute_speed(lv) = base + randf(-jitter, +jitter) + per_lv × lv` |
| `radius_base` / `radius_jitter` | float | `compute_radius() = base + randf(-jitter, +jitter)` |
| `attack_range` | float | 进入该距离即停止追击并发起攻击 |
| `attack_interval` | float | 攻击间隔（秒），开局随机错开避免同时出手 |
| `knockback_distance` | float | 受击击退距离 |
| `sprite_path` | String | 真实精灵路径（`res://...`）。**留空则用 `SpriteFactory` 程序化占位贴图**；填了自动生效，不改渲染代码 |
| `body_color` / `outline_color` / `eye_color` | `[r,g,b]` | 占位贴图配色 |
| `body_outline_width` | float | 描边宽度 |
| `hp_bar_color` | `[r,g,b]` | 头顶血条颜色 |

现有 3 种原型：`slime` 粘液怪（数量多、弱）、`brute` 重甲兽人（血厚、慢、重）、`wisp` 幽影（快、脆）。

### 加一种敌人的最小改动

**只改 JSON**：向 `enemies.json` 的 `archetypes` 数组追加一个对象，`id` 唯一即可。
`EnemyRegistry` 会自动加载，`main.gd` 的刷怪逻辑会自动按 `spawn_weight` 抽到它。
若 `sprite_path` 留空，外观由 `body_color` 等字段决定。

---

## 3. `data/professions.json` / `data/skills.json`（M7 职业与技能）

两张表配套使用：职业引用技能 id，技能自带 `profession` 字段。

### `professions.json`

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | String | 唯一标识（`warrior` / `mage` / `ranger`） |
| `display_name` | String | 中文名 |
| `color` | `[r,g,b]` | 职业色：HUD 职业标签 + 技能栏换色 |
| `base_stats` | Dictionary | **属性基数**，键必须与 `Player.total_stats()` 一致：`attack` / `max_hp` / `armor` / `crit` / `speed` / `max_mana` / `mana_regen` |
| `skills` | `[String]` | 技能 id 列表。**约定下标 0 = 普攻、1 = 大招**（`Player.cast_slot(0/1)` 依赖这个顺序） |

### `skills.json`

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | String | 唯一标识 |
| `name` | String | 中文名（占位图标取它的首字） |
| `profession` | String | 所属职业 id，必须能在 `professions.json` 里找到 |
| `kind` | String | `basic`（普攻）/ `ultimate`（大招），只影响显示 |
| `cooldown` | float | 冷却秒数。0 表示可连续施放 |
| `mana_cost` | float | 单次耗蓝。0 表示不耗蓝 |
| `damage_mult` | float | 伤害倍率，实际伤害 = `总攻击力 × damage_mult × (暴击 ? 1.6 : 1.0) × 0.9~1.1` |
| `cast_range` | float | 命中半径（玩法平面单位） |
| `half_angle_deg` | float 1~180 | 扇形**半角**（写角度，读取时转弧度）。**180 = 360° 全方位命中** |
| `color` | `[r,g,b]` | 弧光与技能栏边框色 |
| `icon` | String | 真图标路径（`res://...`）。**留空 → 程序化占位图标（技能名首字 + 技能色）** |

### 加载器

| 类 | 文件 | 接口 |
| --- | --- | --- |
| `Profession` / `ProfessionRegistry` | `scripts/data/profession.gd`、`profession_registry.gd` | `load_default()` / `get_profession(id)` / `ids()` / `clear_cache()`；`Profession.skills()` 返回 `Array[SkillDef]` |
| `SkillDef` / `SkillRegistry` | `scripts/data/skill_def.gd`、`skill_registry.gd` | `load_default()` / `get_skill(id)` / `skills_of(profession_id)` / `clear_cache()`；`is_full_circle()` / `short_label()` / `kind_name()` |

### 加内容的最小改动

| 想做什么 | 改哪里 |
| --- | --- |
| 改数值（伤害 / 冷却 / 耗蓝 / 射程 / 扇角） | 只改 `skills.json` |
| 改职业基础属性 | 只改 `professions.json` 的 `base_stats` |
| 给技能换图标 | 只改 `skills.json` 的 `icon` |
| **加职业** | `professions.json` 追加一条 + 在 `skills.json` 补它的 2 个技能；`F1/F2/F3` 只覆盖前 3 个职业，第 4 个起需要另加切换入口 |
| **加技能** | `skills.json` 追加 + 把 id 加进对应职业的 `skills` 数组；若超过 2 个技能，需要新增技能槽的输入动作与 UI 槽位（当前 SkillBar 固定 2 槽） |

> 数值口径与设计取舍见 `docs/modules/skills.md`。**当前所有数值均为自设占位值，待原作资料校准。**

---

## 4. 新增一张数据表的标准做法

1. `data/<name>.json`，顶层 `{"version": N, "<items>": [...]}`，颜色用 `[r,g,b]`。
2. `scripts/data/<name>_archetype.gd`：
   `class_name XxxArchetype` + `extends RefCounted` + `static func from_dict(d: Dictionary) -> XxxArchetype`，
   每个字段给出与 JSON 一致的默认值。颜色解析照抄 `EnemyArchetype._parse_color()`（同时兼容数组与字符串）。
3. `scripts/data/<name>_registry.gd`：
   `class_name XxxRegistry` + `extends RefCounted` + `static var _cached: Array = []`，
   提供 `load_default() -> Array`、`pick_weighted()`（如需加权）、`clear_cache()`。
4. `tests/test_data_layer.gd` 追加断言段（照抄现有 `print("[OK] ...")` / 失败 `quit(1)` 风格）。
5. `docs/modules/<模块>.md` 补字段表，`docs/roadmap.md` 变更记录加一行。
