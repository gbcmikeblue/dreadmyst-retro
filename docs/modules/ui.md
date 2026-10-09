# 模块：UI 与表现

**文件**：`scripts/ui/hud.gd`、`damage_number.gd`、`dev_pause.gd`

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

## 开发用暂停控件（DevPause, CanvasLayer）

由 `main.gd` 的 `DEV_TOOLS` 常量控制，设为 `false` 即整体移除。

| 元素 | 说明 |
| --- | --- |
| 右上角按钮 | 用锚点贴住右上角（窗口尺寸变化自动跟随），文字在「暂停 / 继续」间切换 |
| 快捷键 | `Esc` / `P`（`pause` 动作，注册在 `game.gd`） |
| 全屏遮罩 | 暂停时显示半透明黑 + 居中「已暂停」 |
| 实时输入显示 | 左上角显示 `输入 (x, y)   按住: ...` |

### 为什么单独成文件而不放进 HUD
HUD 的职责是「读 `Events` 显示状态」（只读）；暂停是「写全局 `get_tree().paused`」的开发工具，
是写操作。职责不同，混在一起会让 HUD 不再纯粹。

### 三个必须注意的点
1. **`process_mode = PROCESS_MODE_ALWAYS`** —— 否则暂停后按钮点不动、快捷键也收不到。
2. **`layer = 100`** —— 要盖在 HUD（`layer = 10`）之上。
3. **`Button.focus_mode = FOCUS_NONE`** —— 否则点过一次按钮后，空格/回车会重复触发按钮
   而不是游戏里的攻击。

暂停会冻结 `Main` 下所有默认 `PROCESS_MODE_INHERIT` 的节点：玩家、敌人、相机跟随、刷怪计时、掉落物全部停住。

## TODO

- [ ] **中文字体**：HUD 与 `Label3D` 都用引擎回退字体，中文可能显示异常（方块），需接入 `.ttf`
- [ ] 装备栏 tooltip（当前拾取时 Toast 提示属性）
- [ ] 技能栏（M7 职业系统时新增）
- [ ] 伤害数字对象池（当前每击 `new`，量大会有 GC 压力）
