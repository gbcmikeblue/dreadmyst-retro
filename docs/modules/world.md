# 模块：世界与场景

**文件**：`scripts/world/arena_background.gd`、`arena_prop.gd`、`gear_pickup.gd`、`scripts/main.gd`

## 竞技场（ArenaBackground）

| 参数 | 值 |
| --- | --- |
| 范围 | `Rect2(-960, -640, 1920, 1280)`（中心原点，来自 `Game.arena`） |
| 地面色 | (0.075, 0.075, 0.10) |
| 网格 | 步长 80，线色 (0.12, 0.12, 0.16) |
| 中心营地 | 半径 96 圆 + 紫描边（复活点） |
| 边界框 | 紫 (0.42, 0.28, 0.62, 0.85)，线宽 5 |

## 装饰岩石（ArenaProp）

- 固定 26 个，随机种子 `20261009`（每次运行相同布局）
- 半径 8~22，色 (0.16, 0.15, 0.20)
- 7 段不规则多边形（顶点半径抖动 0.72~1.12，种子由坐标派生）
- **纯视觉，无碰撞**

## 掉落物（GearPickup）

| 参数 | 值 |
| --- | --- |
| 拾取半径 | 40（玩家进入即触发） |
| 外观 | 品质色光晕圆(半径16) + 白描边菱形宝石(±12/±9) |
| 浮动动画 | 振幅 3.0，频率 3.0（上下漂浮） |

拾取流程：`GearPickup._process` 检测玩家距离 → 调 `player.try_equip(gear)`（自动穿/分解）→ Toast 提示。

## 入口装配（main.gd）

职责顺序（`_ready`）：
1. `seed(Time.get_ticks_msec())`
2. 加背景 → 生成玩家（中心）+ Camera2D（zoom 1.15，平滑 8.0，边界限制到 arena）
3. 加 HUD → 连接 Events → 补发初始状态（HUD 创建晚于玩家信号，重放一次）
4. 开局 6 只怪 → Toast 欢迎

`_process`：刷怪计时（详见 combat.md）。`_on_enemy_died`：经验 `12+lv×7`、金币 `2~6`、`LootTable.roll_drop` 生成掉落物。`_on_damage_dealt`：生成伤害数字（红/金/白）。

## TODO

- [ ] 多区域/地城（当前单一竞技场）
- [ ] 岩石无碰撞，地城版本应接入 layer 1 墙体
- [ ] 相机切换斜俯视时的适配（见 architecture.md §4）
