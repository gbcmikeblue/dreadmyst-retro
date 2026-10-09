# 模块：UI 与表现

**文件**：`scripts/ui/hud.gd`、`damage_number.gd`

## HUD（CanvasLayer）

**构建方式**：全部程序化（`ProgressBar`/`Label`/`RichTextLabel` + `StyleBoxFlat`），无场景文件。

### 布局（自上而下）

| 元素 | 位置 | 说明 |
| --- | --- | --- |
| HP 条 | 左上 | 红/深底，`player_health_changed` 驱动 |
| 经验条 | HP 下方 | `player_level_changed` 驱动，显示 `等级 N · xp/next` |
| 属性面板 | 左侧 | `player_stats_changed` 驱动（attack/armor/crit/speed） |
| 金币/击杀 | 右上 | `gold_changed` / `enemy_died` 驱动 |
| 装备栏 | 左下 | 5 格（SLOT_ORDER 顺序），品质色块，空位显示"空" |
| 操作提示 | 底部 | "WASD 移动 · 空格 攻击 · Shift 冲刺" |
| Toast | 顶部中央 | `toast` 信号驱动，定时淡出 |

### 数据流
全部通过 Events 信号更新，HUD 不持有 Player 引用（解耦，可直接替换为正式 UI 场景）。

## 漂浮伤害数字（DamageNumber）

| 参数 | 值 |
| --- | --- |
| 字号 | 18（引擎回退字体 `ThemeDB.fallback_font`） |
| 存活 | 0.75s |
| 动画 | 上浮 + 淡出 |

颜色规则（main.gd `_on_damage_dealt`）：

| 情形 | 颜色 |
| --- | --- |
| 玩家受伤 | 红 (1.0, 0.35, 0.35) |
| 暴击 | 金 (1.0, 0.85, 0.2) |
| 普通 | 白 |

渲染：先画深色偏移描边 (0,0,0,0.8) 再画本体，保证任何底色上可读。

## TODO

- [ ] **中文字体**：当前用引擎回退字体，中文可能显示异常（方块），需接入 `.ttf`
- [ ] 装备栏 tooltip（当前拾取时 Toast 提示属性）
- [ ] 技能栏（M7 职业系统时新增）
- [ ] 伤害数字对象池（当前每击 new，量大会 GC 压力）
