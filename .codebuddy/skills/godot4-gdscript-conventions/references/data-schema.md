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

## 4. `data/attributes.json`（M8 属性加点）

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | String | 唯一标识（`strength` / `agility` / ...） |
| `name` | String | 中文名（占位图标取它的首字） |
| `description` | String | 一行说明，直接显示在加点界面 |
| `color` | `[r,g,b]` | 属性色：图标边框 + 加成文本 |
| `max_points` | int | 该属性可投入上限。**0 = 不设上限**（此时没有「满级」态） |
| `per_point` | Dictionary | **每点加成**，键必须与 `Player.total_stats()` 一致：`attack` / `max_hp` / `armor` / `crit` / `speed` / `max_mana` / `mana_regen` |

顶层还有 `free_points_per_level`（每升 1 级给多少自由点）。

| 类 | 文件 | 接口 |
| --- | --- | --- |
| `AttributeDef` | `scripts/data/attribute_def.gd` | `from_dict()` / `bonus_for(points)` / `is_capped(points)` / `short_label()` |
| `AttributeRegistry` | `scripts/data/attribute_registry.gd` | `load_default()` / `get_attribute(id)` / `ids()` / `free_points_per_level()` / **`bonus_for_all(allocation)`** / `clear_cache()` |

- 点数经济在 `Player`：`累计 = (等级-1) × free_points_per_level`，`剩余 = 累计 - 已投入`；
  等级只由 `Game` 提供（`player_level_changed`），Player 不另存一份已发点数。
- `AttributeRegistry.bonus_for_all()` 是**纯计算**（不依赖 Player），联机时服务端可直接复算。
- 加属性 / 调曲线 → 只改 `attributes.json`（界面按 `AttributeRegistry.ids()` 的顺序渲染，自动多出一行）。

---

## 5. `data/dungeon.json`（M10 地城与 Boss）

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` / `display_name` | String | 唯一标识 / 中文名 |
| `level_bonus` | int | 地城内敌人等级 = 玩家等级 + 该值 |
| `room_count` | int | 房间数（沿 +X 排成一条直线，无分支） |
| `room_size` | `[宽, 深]` | 单个房间的玩法平面尺寸 |
| `corridor_length` | float | 房间之间的走廊长度（门就开在走廊正中） |
| `wall_height` / `wall_thickness` | float | 墙体尺寸 |
| `door_width` | float | 墙上门洞 / 门的宽度 |
| `enemies_per_room` | `[int]` | 下标 = 房间号；**长度不足时沿用最后一个值** |
| `boss.archetype` | String | Boss 原型 id，必须能在 `enemies.json` 里找到且 `is_boss = true` |
| `boss.level_bonus` | int | Boss 等级额外加成 |
| `rewards.gold` / `rewards.xp` | int | 通关奖励 |
| `rewards.guaranteed_rarity` | String | 保底掉落品质 key，留空 = 不给保底 |
| `ground_color` / `line_color` / `wall_color` / `accent_color` | `[r,g,b]` | 程序化占位美术配色 |

| 类 | 文件 | 接口 |
| --- | --- | --- |
| `DungeonDef` / `DungeonRegistry` | `scripts/data/dungeon_def.gd`、`dungeon_registry.gd` | `load_default()` / `get_dungeon(id)` / `ids()` / `clear_cache()`；`DungeonDef` 还提供**平面几何派生**：`room_rect()` / `room_center()` / `door_point()` / `bounds()` / `entrance_point()` / `exit_point()` |

- Boss 的标记在 `enemies.json`：`"is_boss": true` + `"spawn_weight": 0`。
  **`is_boss` 或 `spawn_weight <= 0` 的原型不会进 `EnemyRegistry.pick_weighted()`**，
  只能由地城用 `get_archetype(id)` 指名生成。
- `bounds()` 的 Z 起点是 `origin.y - room_size.y * 0.5`，必须与 `room_rect()` 同口径
  （否则房间会落在 bounds 之外，自测有一条断言专门盯这个）。
- 加地城 = `dungeons` 数组追加一条 + 在 `enemies.json` 里准备好它的 Boss 原型。

---

## 6. `data/inventory.json` / `data/shop.json`（M11 背包与商店）

### `inventory.json`

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `backpack_capacity` | int | 背包格数（界面按它生成格子） |
| `sell_price_per_power` | float | 卖出价 = 评分 × 该值 + … |
| `sell_price_per_level` | int | 卖出价再加 `等级 × 该值` |
| `min_sell_price` | int | 卖出价下限（不低于此值） |

| 类 | 文件 | 接口 |
| --- | --- | --- |
| `InventoryConfig` | `scripts/data/inventory_config.gd` | `load_default()` / `from_dict()` / **`sell_price_for(gear)`** / `clear_cache()` |

> ⚠️ **卖出价公式只在这里实现**：`Player`（真正加金币）与背包界面（显示「分解 +N」）
> 都调 `sell_price_for()`，否则会出现「界面显示 12、实际给 10」。

### `shop.json`

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `restock_cost` | int | 刷新货架的金币 |
| `offers[].slot` | String | `weapon` / `helmet` / `armor` / `boots` / `ring` |
| `offers[].rarity` | String | `common` … `legendary` |
| `offers[].item_level` | int | 商品等级（决定词条数值） |
| `offers[].price` | int | 买入价 |

| 类 | 文件 | 接口 |
| --- | --- | --- |
| `ShopConfig` | `scripts/data/shop_config.gd` | `load_default()` / `from_dict()` / `clear_cache()`；`offers` 元素已解析成 `{slot, rarity, item_level, price, slot_key, rarity_key}` |
| `Shop` | `scripts/core/shop.gd` | `roll_stock()` / `buy(i)` / `restock()`；与外界只走 Events |

- 货架**不写死装备**：每条 offer 由 `LootTable.generate(item_level, rarity_key, slot_key)` 现生成，
  所以 `LootTable.generate()` 有三个参数，**部位必须在生成时指定**（名字池与词条按部位取
  `loot.json` 的 `stat_specs`，事后改 `gear.slot` 会得到「名字是战靴、词条是武器」的怪东西）。
- `Shop` 用 `backpack_changed` **缓存**背包占用（`_bag_size` / `_bag_capacity`），
  这样不用引用 Player 也能在扣钱之前知道东西放不放得下。

---

## 7. 存档 `user://save_<槽>.json`（M13，不在 `data/` 里）

存档不属于 `data/*.json`（它是**运行时写出的玩家数据**，形状由 `SaveData` 定义）：

```json
{ "version": 1, "saved_at": "...", "kills": 12,
  "game":   { "level": 5, "xp": 120, "gold": 800 },
  "player": { "profession": "mage", "hp": 95.0, "mana": 140.0,
              "attributes": { "strength": 12 },
              "equipment":  { "weapon": { ...GearItem.to_dict()... } },
              "backpack":   [ { ... } ] } }
```

| 类 | 文件 | 职责 |
| --- | --- | --- |
| `SaveData` | `scripts/data/save_data.gd` | 结构 + `CURRENT_VERSION` + 兜底解析（无 IO、无信号） |
| `GearItem.to_dict()` / `static from_dict()` | `scripts/data/gear_item.gd` | 单件装备序列化；`SLOT_KEYS` / `RARITY_KEYS` 是**枚举↔可读键的唯一一份映射**（`LootConfig` 转发过来） |
| `SaveService` | `scripts/core/save_service.gd` | 3 槽位 IO / 原子写 / 读取回退链 / 坏档改名备份 / 防抖自动保存 / 槽位摘要 |

要点（写新的存档字段前必读）：

1. **存档是外部输入**：`from_dict()` 全程兜底，不 `push_error`；未知枚举钳制、未知词条丢弃、
   背包超容量只收前 N 件并计数。
2. **解析用 `JSON` 实例，不要用 `JSON.parse_string()`**：后者失败会往 stderr 打引擎级
   `ERROR: Parse JSON failed`，而坏档是预期情况。见 `SaveService._parse_json_dict()`。
3. **原子写**：`<file>.tmp` → 旧档改名 `.bak` → tmp 改名正式档 → 删 `.bak`；
   读取按 正式档 → `.bak` → `.tmp` 回退。
4. **改结构就 `SaveData.CURRENT_VERSION` +1**，并在 `SaveService` 里加迁移分支
   （目前版本不符只做「备份 + 新建」）。
5. **谁来收集状态**：`main.gd`（唯一同时知道 `Game` 与 `Player` 的地方）通过
   `save_service.state_provider = _collect_save` 注入；`SaveService` 不认识 Player / Game。
6. **自动保存触发**：监听 `player_level_changed` / `gold_changed` / `equipment_changed` /
   `backpack_changed` / `attributes_changed` / `dungeon_entered` / `dungeon_exited` → 2 秒防抖。
   `current_slot < 0`（还没选槽）时不记账。

> ⚠️ 启动会先弹标题选档界面并把世界暂停。需要世界跑起来的 `--script` 自测要自己选槽位：
> `main.choose_slot(1, true)`（并把 `save_service.path_pattern` 指到测试专用文件）。

---

## 8. `data/camera.json`（M16 相机）

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `size` | float | 正交视野高度（世界单位），越小越近。等价于 2D 的 zoom |
| `tilt_deg` | float | 俯角，**必须为负**（0 = 平视，-90 = 垂直俯视） |
| `distance` | float | 沿视线后撤距离（正交下只影响裁剪范围） |
| `follow_speed` | float | 焦点平滑跟随速度 |
| `zoom.min` / `zoom.max` / `zoom.step` | float | 缩放区间与步进 |
| `rotate.step_deg` | float | 每次水平旋转的角度 |
| `tilt.min_deg` / `tilt.max_deg` / `tilt.step_deg` | float | 俯角可调区间与步进。⚠️ `min_deg` 是**数值最小**那个（最俯视） |

| 类 | 文件 | 接口 |
| --- | --- | --- |
| `CameraConfig` | `scripts/data/camera_config.gd` | `load_default()` / `from_dict()` / `clear_cache()`；`from_dict()` 会把非法值钳成能用的（视野落进缩放区间、俯角为负、距离为正…） |
| `CameraRig` | `scripts/world/camera_rig.gd`（`extends Camera3D`） | `apply_config()` / `zoom_by()` / `rotate_by()` / `tilt_by()` / `reset_view()` / `snap()` / `step()` / `focus_plane()` / `focus_target()` / `clamp_focus()` / `view_extents()` / `debug_text()` |

- **不是 Autoload**：相机是场景里的节点，参数在 `main.gd::_spawn_player()` 里由 `CameraRig` 自己读。
- 「目视校准」闭环：游戏内调 → `debug_report` 把当前值打到控制台 + DevPause 面板显示读数 → 抄回 JSON。
- `CameraRig` 引用了 `Game`，所以**在 `--script` 自测里不能写它的类名**，只能 `_main.camera` 动态访问。

---

## 9. 新增一张数据表的标准做法

1. `data/<name>.json`，顶层 `{"version": N, "<items>": [...]}`，颜色用 `[r,g,b]`。
2. `scripts/data/<name>_archetype.gd`：
   `class_name XxxArchetype` + `extends RefCounted` + `static func from_dict(d: Dictionary) -> XxxArchetype`，
   每个字段给出与 JSON 一致的默认值。颜色解析照抄 `EnemyArchetype._parse_color()`（同时兼容数组与字符串）。
3. `scripts/data/<name>_registry.gd`：
   `class_name XxxRegistry` + `extends RefCounted` + `static var _cached: Array = []`，
   提供 `load_default() -> Array`、`pick_weighted()`（如需加权）、`clear_cache()`。
4. `tests/test_data_layer.gd` 追加断言段（照抄现有 `print("[OK] ...")` / 失败 `quit(1)` 风格）。
5. `docs/modules/<模块>.md` 补字段表，`docs/roadmap.md` 变更记录加一行。
