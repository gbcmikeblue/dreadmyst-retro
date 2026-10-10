# 模块：战斗（玩家 + 敌人）

**文件**：`scripts/actors/player.gd`、`scripts/actors/enemy.gd`
两者都是 `CharacterBody3D` + `motion_mode = MOTION_MODE_FLOATING`（顶视角，关闭重力/贴地）。
玩法逻辑用 `Vector2` 平面计算，只在写 `velocity` / `global_position` 时转 `Vector3`。

## 玩家（Player）

### 属性来源（M7 起）

属性基数来自**职业**（`data/professions.json`），不再有单一 `BASE_STATS`：

```
总属性 = 职业 base_stats（缺失时用 Player.FALLBACK_STATS）+ 全身装备词条累加  → total_stats()
```

| 属性 | 战士 | 法师 | 游侠 |
| --- | --- | --- | --- |
| attack | 12 | 16 | 11 |
| max_hp | 150 | 95 | 115 |
| armor | 10 | 0 | 4 |
| crit | 5% | 8% | 16% |
| speed | 225 | 215 | 250 |
| max_mana | 60 | 140 | 90 |
| mana_regen | 4/s | 10/s | 7/s |

### 行为参数

| 参数 | 值 |
| --- | --- |
| 普攻间隔 | 由技能冷却决定（战 0.45 / 法 0.70 / 游 0.50 秒） |
| 技能射程 / 扇角 | 由技能决定，见 [skills.md](skills.md) §3 |
| 技能挥砍动画 | 0.18s |
| 冲刺速度 | 780 / 时长 0.16s / 冷却 1.1s |
| 脱战回血 | 0.6/s |
| 回蓝 | 按职业 `mana_regen` |
| 碰撞圆柱 | 半径 15 / 高 34 |
| 精灵 | 高 44 世界单位 |

### 战斗公式
- 伤害 = `总攻击力 × 技能倍率 × (暴击 ? 1.6 : 1.0) × randf_range(0.9, 1.1)`，暴击率上限钳制 0.9
- 减伤：`amount × 100 / (100 + armor)`（armor=100 减伤 50%）
- 命中判定：以玩法平面上的「距离 + 朝向夹角」手写，不用 `Area3D`，行为可预测
- 施放门槛（死亡 / 冷却 / 蓝量）与 360° 技能的处理见 [skills.md](skills.md) §4

### 装备流转（自动）
拾取后与同部位当前装备比 `power_score()`：
- 更高 → 自动装备（Toast 提示）
- 更低 → 自动分解，金币 = `round(评分/4) + item_level × 2`

### 视觉组成（`_build_visuals()`）
| 节点 | 内容 |
| --- | --- |
| `BlobShadow` | 脚下影斑（`SpriteFactory.blob_shadow`） |
| `Sprite3D` | billboard 圆形身体（占位贴图，受伤变红 / 死亡变灰） |
| `FacingMarker` | 金色长条，`rotation.y = -facing.angle()` |
| `ArcFx` | **每个技能槽一个**扇形弧光（运行时构建的 `ArrayMesh`），转职时按该技能的射程/扇角/颜色重建，施放时对应槽放大淡出 |
| `flat_disc` | 冲刺残影（半透明蓝圆盘） |

### 死亡/复活
死亡 → Toast 红字 → 3s 后回营地（场地中心）满血满蓝复活。

### TODO
- [x] 单一普攻已替换为多技能（各自冷却 + 蓝条）——M7
- [x] 已有 3 职业分化（战 / 法 / 游），属性来自 `data/professions.json`
- [ ] 职业选择 UI（当前 F1/F2/F3 硬切）
- [ ] 技能只有扇形判定，没有弹道 / 投射物（法师火球也是近身扇形）

## 敌人（Enemy）

### 数据来源
数值与外观来自 `EnemyArchetype`（`data/enemies.json`），见 [loot.md](loot.md) §3。
生成方调用 `setup(level, archetype)` → `compute_hp/attack/speed/radius` 按等级派生（速度/半径带随机抖动）。

`EnemyArchetype.is_boss` 只影响**表现与免疫**（M10）：免疫击退、3D 血条更大更高、脚下多一层品质色光环。
Boss 的生成不由刷怪器负责 —— 它由 [dungeon.md](dungeon.md) 用 `EnemyRegistry.get_archetype(id)` 指名生成。

### AI 状态机（隐式）

```
每帧取 Game.get_player()
 ├─ 距离 > attack_range → 追击（方向 + separation×0.6 合成转向）
 ├─ 距离 ≤ attack_range 且 CD 到 → 攻击（player.take_damage）
 └─ 玩家无效 → 仅 separation 漂移
```

- separation 排斥：`min_dist = r1 + r2 + 6`，重叠按比例互推
- 受击：白闪 0.12s + 击退 `knockback_distance` + 伤害数字
- 死亡：`scale` 1.4× + 精灵淡出 0.25s → `queue_free`；发 `Events.enemy_died`
- 首发攻击 CD 随机错开，避免同时出手
- 碰撞：layer 2 / mask 1（怪物不撞怪物，只与未来墙体 layer 1 碰撞）

### 视觉
| 节点 | 内容 |
| --- | --- |
| `BlobShadow` | 脚下影斑 |
| `Sprite3D` | billboard 身体（`sprite_path` 有效则用真图） |
| `SphereMesh` | 「眼睛」，每帧移到朝向玩家的一侧 |
| 血条 | `Node3D` 容器 + 两个 1×1 白贴图 billboard 精灵，`SpriteFactory.update_bar()` 左对齐更新 |

### 刷怪（main.gd）

| 参数 | 值 |
| --- | --- |
| 开局数量 | 6 只（距玩家 380~620） |
| 补充间隔 | 3.5s，每轮 1~3 只（距玩家 380~640） |
| 数量上限 | `8 + level × 2` |
| 等级 | `Game.level ± 1` |
| 原型选择 | `EnemyRegistry.pick_weighted()`（`spawn_weight` 加权） |
| 何时不刷 | `Game.in_dungeon` 为 true 时 `main._process()` 直接返回（副本内由 `Dungeon` 按房间刷） |

`pick_weighted()` **跳过** `is_boss` 与 `spawn_weight <= 0` 的原型，所以 Boss 永远不会出现在野外；
从野外进地城时，场上的野怪会被 `main._clear_arena_enemies()` 撤掉（立刻退出 `enemies` 组，不给经验/掉落）。

生成位置用玩法平面计算：`center + Vector2(cos(angle), sin(angle)) * distance`，再 `Game.world()` 转世界坐标。
