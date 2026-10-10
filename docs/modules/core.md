# 模块：核心（Autoload）

**文件**：`scripts/core/game.gd`、`scripts/core/event_bus.gd`
**注册**：`project.godot` Autoload，顺序 `Events` → `Game`（Game 依赖 Events 发信号）

## Game（全局状态 + 坐标转换 + 输入）

### 职责
只放「全局」的东西：竞技场范围、等级/经验/金币、输入动作注册、坐标转换。玩法状态（血量、装备）在 Player。

### 状态

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `ARENA_HOME` | `const Rect2(-960, -640, 1920, 1280)` | 原野（竞技场）的固定边界。`x`→世界 X，`y`→世界 Z |
| `arena` | `Rect2` | **当前**可行走范围。原地 = `ARENA_HOME`；进地城后换成地城范围（M10） |
| `in_dungeon` / `dungeon_id` | `bool` / `String` | 是否在副本里（由 `main.gd` 维护）；`main._process()` 据此停刷野怪 |
| `respawn_point` | `Vector2` | 复活点（玩法平面）。竞技场 = 营地中心；进地城后 = 地城入口（M10） |
| `gold` | `int` | 金币 |
| `level` | `int` | 玩家等级（初始 1） |
| `xp` | `int` | 当前经验 |

> ⚠️ 玩家 / 敌人 / 相机的边界钳制全部读 `arena`，所以「换场地」只要换这一个值；
> 但**只建一次的节点**（如 `ArenaBackground`）必须读 `ARENA_HOME`，否则会被地城边界带跑。

### 坐标转换（2.5D 的核心）

```gdscript
static func world(plane_point: Vector2, height := 0.0) -> Vector3   # (x,y) -> (x, height, y)
static func plane(world_point: Vector3) -> Vector2                  # (x,y,z) -> (x, z)
static func plane_of(node: Node3D) -> Vector2
func get_player() -> Node3D
```

映射约定：**`Vector2(x, y)` = `Vector3(x, 0, y)`**，XZ 是地面、Y 是高度。
玩法逻辑（距离/方向/角度）全部在 Vector2 平面上算，只在读写节点位置时转换。
详见 [../architecture.md](../architecture.md) §3。

### 经验曲线
`BASE_XP = 70`，升级需求 `round(70 × 1.4^(level-1))`；`add_xp()` 支持一次多级，升级发 `Events.toast`（金色）。

### 输入映射（`_setup_input()` 代码注册）

| 动作 | 键 | 说明 |
| --- | --- | --- |
| `move_up / move_down / move_left / move_right` | WASD + 方向键 | 移动 |
| `attack` | 空格 / J / 鼠标左键 | 当前职业**普攻**（按住可连击） |
| `dash` | Shift / K | 冲刺 |
| `skill_1` | 1 / Q | 技能槽 0（普攻） |
| `skill_2` | 2 / E | 技能槽 1（大招） |
| `profession_1 / 2 / 3` | F1 / F2 / F3 | **原型期**切职业（战 / 法 / 游）——正式版应改为角色创建流程 |
| `pause` | Esc / P | 开发用暂停 |

移动输入是 `Vector2`，直接就是玩法平面上的方向，无需变换。

### ⚠ 每个键必须注册两套事件

`_action()` 对每个键同时注册 `physical_keycode` 与 `keycode` 两个 `InputEventKey`：

```gdscript
var physical := InputEventKey.new()
physical.physical_keycode = key     # 按物理位置，与键盘布局无关
InputMap.action_add_event(action_name, physical)

var logical := InputEventKey.new()
logical.keycode = key               # 按字符，与布局相关
InputMap.action_add_event(action_name, logical)
```

**只注册 `physical_keycode` 会导致该动作在部分环境下完全失效**（远程桌面 / 虚拟机 /
部分键盘驱动 / 某些输入法状态下不提供物理键码）。此时鼠标点击仍正常，于是会出现
「左键能攻击、WASD 却是死的」这种迷惑现象。

验证：`godot --headless --path . --script res://tests/test_input_move.gd`
（诊断脚本会分别报告「按键→动作」与「动作→移动」两个环节的结果）

## Events（事件总线）

**原则**：全工程唯一信号定义处，模块间解耦的根基。

| 信号 | 参数 | 发出方 → 消费方 |
| --- | --- | --- |
| `damage_dealt` | `(world_position: Vector3, amount: int, is_crit: bool, on_player: bool)` | Enemy/Player → main（伤害数字） |
| `enemy_died` | `(level: int, world_position: Vector3)` | Enemy → main（经验/金币/掉落） |
| `player_health_changed` | `(hp: int, max_hp: int)` | Player → HUD |
| `player_stats_changed` | `(stats: Dictionary)` | Player → HUD |
| `player_level_changed` | `(level, xp, xp_next)` | Game → HUD |
| `equipment_changed` | `(equipment: Dictionary)` | Player → HUD |
| `gold_changed` | `(gold: int)` | Game → HUD |
| `loot_picked_up` | `(gear)` | Player → 订阅者 |
| `toast` | `(text: String, color: Color)` | 各处 → HUD |
| `player_mana_changed` | `(current: int, maximum: int)` | Player → HUD（M7 蓝条） |
| `player_profession_changed` | `(profession_id: String, display_name: String, color: Color)` | Player → HUD（M7 职业标签） |
| `player_skills_changed` | `(skills: Array)` | Player → SkillBar（M7 技能栏槽位） |
| `skill_cooldowns_changed` | `(cooldowns: Dictionary)` | Player → SkillBar（M7 冷却遮罩；**无冷却时不发**，避免每帧刷 UI） |

**转 3D 时的唯一改动**：位置类参数从 `Vector2` 改为 `Vector3`。

## 已知问题 / TODO

- [ ] 玩家死亡时 Game 无感知（复活逻辑在 Player 内）；M7 职业系统引入后仍未上移
- [ ] 输入映射建议最终移到 `project.godot` 的 `[input]` 段，便于玩家改键
- [ ] 职业选择应为正式流程（当前是 F1/F2/F3 原型期硬切，见 [skills.md](skills.md) §7）
