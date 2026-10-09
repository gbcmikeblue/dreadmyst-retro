# 模块：核心（Autoload）

**文件**：`scripts/core/game.gd`、`scripts/core/event_bus.gd`
**注册**：`project.godot` Autoload，顺序 `Events` → `Game`（Game 依赖 Events 发信号）

## Game（全局状态 + 输入）

### 职责
只放「全局」的东西：竞技场范围、等级/经验/金币、输入动作注册。玩法状态（血量、装备）在 Player。

### 状态

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `arena` | `Rect2(-960, -640, 1920, 1280)` | 竞技场矩形，中心为原点 |
| `gold` | `int` | 金币 |
| `level` | `int` | 玩家等级（初始 1） |
| `xp` | `int` | 当前经验 |

### 经验曲线

- `BASE_XP = 70`，升级需求 `round(70 × 1.4^(level-1))`（指数增长）
- `add_xp()` 内 while 循环支持一次多级；升级发 `Events.toast`（金色）

### 输入映射（`_setup_input()` 代码注册）

| 动作 | 键 |
| --- | --- |
| `move_up / move_down / move_left / move_right` | WASD + 方向键 |
| `attack` | 空格 / J / 鼠标左键 |
| `dash` | Shift / K |

### 工具
- `get_player() -> Node2D`：取 `player` 组第一个成员（供敌人索敌），无则 null

## Events（事件总线）

**原则**：全工程唯一信号定义处，模块间解耦的根基。玩家/敌人/掉落物/HUD 互不直接引用。

| 信号 | 参数 | 发出方 → 消费方 |
| --- | --- | --- |
| `damage_dealt` | `(pos: Vector2, amount: int, is_crit: bool, on_player: bool)` | Enemy/Player → main（伤害数字） |
| `enemy_died` | `(level: int, pos: Vector2)` | Enemy → main（经验/金币/掉落）、HUD（击杀数） |
| `player_health_changed` | `(hp, max_hp)` | Player → HUD 血条 |
| `player_stats_changed` | `(stats: Dictionary)` | Player → HUD 属性面板 |
| `player_level_changed` | `(level, xp, xp_next)` | Game → HUD 经验条 |
| `gold_changed` | `(gold: int)` | Game → HUD 金币 |
| `toast` | `(text: String, color: Color)` | 各处 → HUD 提示 |

## 已知问题 / TODO

- [ ] 玩家死亡时 Game 无感知（复活逻辑在 Player 内），职业系统引入后应上移
- [ ] 输入映射建议最终移到 `project.godot` 的 `[input]` 段，便于玩家改键
