# 模块：职业与技能（M7）

**代码**：`scripts/data/profession.gd`、`profession_registry.gd`、`skill_def.gd`、`skill_registry.gd`、`scripts/ui/skill_bar.gd`
**数据**：`data/professions.json`、`data/skills.json`
**承载**：`scripts/actors/player.gd`（施放与判定）、`scripts/ui/hud.gd`（蓝条）

> ⚠️ **所有数值均为自行设计的占位值**。原作官网 403 无法访问，职业/技能数据无人提供，
> 因此按 战/法/游 三职业各 2 技能自设了一套自洽数值。拿到原作资料后**只需改两个 JSON**。
> 见 `docs/roadmap.md`「待用户提供的信息」第 1 条。

## 1. 数据模型

| 文件 | 类 | 职责 |
| --- | --- | --- |
| `data/professions.json` | `Profession` / `ProfessionRegistry` | 职业基础属性 + 技能 id 列表 |
| `data/skills.json` | `SkillDef` / `SkillRegistry` | 单个技能的冷却/耗蓝/倍率/射程/扇角 |

两个注册表都是 `extends RefCounted` + `static var _cached` 静态缓存，与 `LootConfig`/`EnemyRegistry` 同一模式：
`load_default()` / `get_*()` / `clear_cache()`。**加职业 / 加技能 = 改 JSON，不改代码。**

## 2. 三个职业

`base_stats` 的键与 `Player.total_stats()` 完全一致，直接作为属性基数（再叠加装备词条）。

| id | 名 | attack | max_hp | armor | crit | speed | max_mana | mana_regen |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `warrior` | 战士 | 12 | 150 | 10 | 5% | 225 | 60 | 4/s |
| `mage` | 法师 | 16 | 95 | 0 | 8% | 215 | 140 | 10/s |
| `ranger` | 游侠 | 11 | 115 | 4 | 16% | 250 | 90 | 7/s |

定位：战士肉、法师脆但高攻高蓝、游侠均衡高暴击高机动。

## 3. 六个技能

约定：`skills` 数组里**下标 0 = 普攻、1 = 大招**（`SkillDef.Kind.BASIC / ULTIMATE`）。

| id | 名 | 职业 | 类型 | 冷却 | 耗蓝 | 伤害倍率 | 射程 | 半角 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `warrior_slash` | 裂颅斩 | 战士 | 普攻 | 0.45s | 0 | ×1.00 | 88 | 60° |
| `warrior_whirlwind` | 旋风斩 | 战士 | 大招 | 6.0s | 20 | ×2.40 | 112 | **180°（360° 全方位）** |
| `mage_fireball` | 火球术 | 法师 | 普攻 | 0.70s | 4 | ×1.15 | 150 | 28° |
| `mage_meteor` | 陨石术 | 法师 | 大招 | 8.0s | 35 | ×3.20 | 170 | 80° |
| `ranger_arrow` | 穿刺箭 | 游侠 | 普攻 | 0.50s | 0 | ×0.90 | 170 | 24° |
| `ranger_multishot` | 箭雨 | 游侠 | 大招 | 7.0s | 25 | ×2.00 | 145 | 90° |

- `half_angle_deg` 写角度（易读），`SkillDef.from_dict` 转成弧度；**180° 视为全方位命中**（`is_full_circle()`）。
- `color` 决定弧光与技能栏边框配色；`icon` 留空则用**程序化占位图标**（技能名首字）；
  接入真图标时填 `res://assets/icons/skills/xxx.png` 即可，无需改代码。

## 4. 施放流程（`Player`）

```
输入                          actor/player.gd
空格 / 左键按住  ──> cast_slot(0)   普攻（可长按连击，所以用 is_action_pressed）
1 / Q           ──> cast_slot(0)
2 / E           ──> cast_slot(1)   大招（is_action_just_pressed）
F1 / F2 / F3    ──> set_profession(ids[0..2])   原型期切职业
```

`cast_skill(skill_id)` 的拒绝条件（任一满足即返回 `false`，**且不消耗任何资源**）：

1. 已死亡
2. 技能 id 不存在
3. 该技能冷却未走完
4. 蓝量 < `mana_cost`（并弹 Toast「法力不足」）

### 命中判定

沿用「距离 + 朝向夹角」的手写判定，不用 `Area3D`，行为可预测：

```gdscript
to_enemy.length() > skill.cast_range                          → 不命中
not is_full_circle() and absf(facing.angle_to(to_enemy)) > half_angle → 不命中
```

伤害：`attack力 × damage_mult × (暴击 ? 1.6 : 1.0) × randf_range(0.9, 1.1)`，
暴击率取总属性的 `crit` 并钳制在 0~0.9。

### 冷却与蓝量

- 冷却表 `_cooldowns: {skill_id: 剩余秒数}`，每物理帧递减；
- **有任何冷却在走（或刚好走完）时才发 `skill_cooldowns_changed`**，空闲期零信号，避免每帧刷 UI；
- 蓝量每秒按 `mana_regen` 回复；脱战回血仍是 `REST_HP_REGEN = 0.6/s`。

## 5. 表现

- **弧光**：每个技能槽一个 `SpriteFactory.arc_fx()` 网格，在**转职时**按该技能的射程/扇角/颜色重建
  （运行时零分配）；施放时只把对应那个槽的弧光放大淡出。
- **技能栏**（`scripts/ui/skill_bar.gd`）：底部居中两个槽位，锚点跟随窗口尺寸。
  - 冷却遮罩 `ColorRect` 从顶部向下退去，叠加剩余秒数文本；
  - 蓝不足 / 冷却中把槽位压暗；
  - 全部子节点 `mouse_filter = IGNORE`，否则会挡住鼠标左键攻击。
- **蓝条**：HUD 血条下方（青色，与蓝色经验条区分）。

## 6. 自测

```powershell
godot --headless --path . --script res://tests/test_skills.gd
```

覆盖 5 个用例（同一个 `process_frame` 内同步跑完，不受敌人 AI 干扰）：

| 用例 | 断言 |
| --- | --- |
| 普攻命中 | 正前方敌人掉血、`cast_slot(0)` 返回 true |
| 冷却拦截 | 立刻再放同一技能返回 false |
| 360° 判定 | 旋风斩打到**身后**的敌人 |
| 转职 | `profession_id` 变 mage、技能[0] 变 `mage_fireball`、蓝量上限变 140 |
| 蓝量门槛 | 蓝 = 0 时放大招返回 false |

数据侧校验（职业数、每职业技能数、技能 profession 一致性）在 `tests/test_data_layer.gd`。

## 7. TODO

- [ ] **数值校准**：等原作职业/技能数据（当前全部自设）
- [ ] 技能图标：`data/skills.json` 的 `icon` 字段填真图（出图任务见 `docs/tasks/M7-skills.md`）
- [ ] 技能特效：目前只有扇形弧光，没有粒子/投射物（法师火球仍是近身扇形判定，不是弹道）
- [ ] 职业选择 UI：当前是原型期 F1/F2/F3 硬切，应改为角色创建流程
- [ ] 更多技能 / 技能树：当前每职业固定 2 个技能
- [ ] 蓝量装备词条：目前装备不给 `max_mana` / `mana_regen`
