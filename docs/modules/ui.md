# 模块：UI 与表现

**文件**：`scripts/ui/hud.gd`、`damage_number.gd`

## HUD（CanvasLayer）

**构建方式**：全部程序化（`ProgressBar`/`Label`/`RichTextLabel` + `StyleBoxFlat`），无场景文件。

> 转 3D 时 **HUD 零改动**：`CanvasLayer` + `Control` 本身就是 2D 层，
> 它用的 `Vector2` 全是 UI 布局坐标，与世界坐标无关。

### 布局（自上而下）

| 元素 | 位置 | 说明 |
| --- | --- | --- |
| HP 条 | 左上 (24, 24) | 红/深底，`player_health_changed` 驱动 |
| HP 文本 | (36, 26) | "HP 100 / 100" |
| 等级 | (24, 58) | `player_level_changed` 驱动 |
| 经验条 | (24, 84) | 320×8 |
| 属性面板 | (24, 100) | `player_stats_changed` 驱动 |
| 金币 | (940, 24) | `gold_changed` 驱动 |
| 击杀数 | (940, 52) | `enemy_died` 驱动 |
| 装备栏 | (24, 430) | 300×240，5 格（`SLOT_ORDER`），品质色，空位显示"空" |
| Toast | (420, 120) | `toast` 信号驱动，定时淡出 |
| 操作提示 | (24, 690) | "WASD 移动 · 空格 攻击 · Shift 冲刺" |

### 数据流
全部通过 Events 信号更新，HUD 不持有 Player 引用（解耦，可直接替换为正式 UI 场景）。

## 漂浮伤害数字（DamageNumber, Label3D）

用 `Label3D` 而不是 `Node2D` + `draw_string`：**自带 billboard 与描边，且自动跟随世界坐标**，
省掉了「世界坐标 → 屏幕坐标」的投影转换。

| 参数 | 值 |
| --- | --- |
| 对齐 | `billboard = BILLBOARD_ENABLED` |
| 穿墙可见 | `no_depth_test = true` |
| `font_size` | 64（配合 `pixel_size` 换算成世界尺寸） |
| `pixel_size` | 0.18 世界单位/像素 |
| 描边 | `outline_size = 14`，黑色 0.8 |
| 存活 | 0.75s |
| 动画 | `position.y` 上浮，初速 56，重力衰减 110（先快后慢，同 2D 版） |

颜色规则（`main.gd::_on_damage_dealt`）：

| 情形 | 颜色 |
| --- | --- |
| 玩家受伤 | 红 (1.0, 0.35, 0.35) |
| 暴击 | 金 (1.0, 0.85, 0.2) |
| 普通 | 白 |

## TODO

- [ ] **中文字体**：HUD 与 `Label3D` 都用引擎回退字体，中文可能显示异常（方块），需接入 `.ttf`
- [ ] 装备栏 tooltip（当前拾取时 Toast 提示属性）
- [ ] 技能栏（M7 职业系统时新增）
- [ ] 伤害数字对象池（当前每击 `new`，量大会有 GC 压力）
