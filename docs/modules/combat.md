# 模块：战斗（玩家 + 敌人）

**文件**：`scripts/actors/player.gd`、`scripts/actors/enemy.gd`

## 玩家（Player, CharacterBody2D）

### 基础属性 `BASE_STATS`

| 属性 | 值 |
| --- | --- |
| attack | 10.0 |
| max_hp | 120.0 |
| armor | 0.0 |
| crit | 0.05（5%） |
| speed | 235.0 |

总属性 = 基础 + 全身装备词条累加（`total_stats()`）。

### 行为参数

| 参数 | 值 |
| --- | --- |
| 攻击间隔 | 0.42s |
| 挥砍半径 | 84.0（扇形半角 ~57°） |
| 攻击动画 | 0.18s 弧光 |
| 冲刺速度 | 780 / 时长 0.16s / 冷却 1.1s |
| 脱战回血 | 0.6/s |
| 碰撞半径 | 15.0 |

### 战斗公式

- 暴击伤害 ×1.6，暴击率上限钳制 0.9
- 伤害浮动 `randf_range(0.9, 1.1)`
- 减伤：`amount × 100 / (100 + armor)`（armor=100 减伤 50%）

### 装备流转（自动）

拾取后与对应部位当前装备比 `power_score()`：
- 更高 → 自动装备（Toast 提示）
- 更低 → 自动分解，金币 = `round(评分/4) + item_level × 2`

### 死亡/复活
死亡 → Toast 红字 → 3 秒后回营地（竞技场中心）满血复活。

### TODO

- [ ] 单一普攻待替换为多技能（冷却/蓝条）——M7 职业系统
- [ ] 无职业分化，仅一套 BASE_STATS

## 敌人（Enemy, CharacterBody2D）

### 数据来源

所有数值与外观来自 `EnemyArchetype`（`data/enemies.json`），见 [loot.md](loot.md) §3。
生成方调用 `setup(level, archetype)` → 内部 `compute_hp/attack/speed/radius` 按等级派生（速度/半径带随机抖动）。

### AI 状态机（隐式）

```
索敌（每帧取 Game.get_player()）
 ├─ 距离 > attack_range → 追击（方向 + separation×0.6 合成转向）
 ├─ 距离 ≤ attack_range 且 CD 到 → 攻击（player.take_damage）
 └─ 玩家无效 → 仅 separation 漂移
```

- 敌人间 separation 排斥：`min_dist = r1 + r2 + 6`，重叠按比例互推
- 受击：白闪 0.12s + 击退 `archetype.knockback_distance` + 伤害数字
- 死亡：缩放 1.4× + 淡出 0.25s → queue_free；发 `Events.enemy_died`
- 首发攻击 CD 随机错开（0 ~ attack_interval），避免同时出手
- 碰撞：layer 2 / mask 1（怪物不撞怪物，只与未来墙体 layer 1 碰撞）

### 刷怪（main.gd）

| 参数 | 值 |
| --- | --- |
| 开局数量 | 6 只（距玩家 380~620） |
| 补充间隔 | 3.5s，每轮 1~3 只（距玩家 380~640） |
| 数量上限 | `8 + level × 2` |
| 等级 | `Game.level ± 1` |
| 原型选择 | `EnemyRegistry.pick_weighted()`（spawn_weight 加权） |
