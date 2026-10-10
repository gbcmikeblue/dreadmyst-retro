# 模块：UI 与表现

**文件**：`scripts/ui/hud.gd`、`damage_number.gd`、`dev_pause.gd`

## HUD（CanvasLayer）

**构建方式**：全部程序化（`ProgressBar`/`Label`/`RichTextLabel` + `StyleBoxFlat`），无场景文件。

> 转 3D 时 **HUD 零改动**：`CanvasLayer` + `Control` 本身就是 2D 层，
> 它用的 `Vector2` 全是 UI 布局坐标，与世界坐标无关。

### 布局（自上而下）

| 元素 | 位置 | 说明 |
| --- | --- | --- |
| HP 条 | 左上 (24, 24) | 320×26，红/深底，`player_health_changed` 驱动 |
| HP 文本 | (36, 26) | "HP 100 / 100" |
| MP 条 | 左上 (24, 54) | 320×12，**青色**（与蓝色经验条区分），`player_mana_changed` 驱动 |
| MP 文本 | (352, 51) | "MP 60 / 60"，放在条右侧避免挤压 12px 高的条 |
| 职业 | (24, 72) | `player_profession_changed` 驱动，文字用职业色 |
| 等级 | (150, 72) | `player_level_changed` 驱动 |
| 经验条 | (24, 96) | 320×8 |
| 属性面板 | (24, 110) | `player_stats_changed` 驱动 |
| 金币 | (940, 24) | `gold_changed` 驱动 |
| 击杀数 | (940, 52) | `enemy_died` 驱动 |
| 背包占用 | (940, 74) | `backpack_changed` 驱动，满时变橙（M11） |
| 属性点 | (240, 72) | `attributes_changed` 驱动，有点数时金色（M8） |
| Boss 血条 | 顶部居中 | `boss_spawned` / `boss_health_changed` / `boss_defeated`，只在 Boss 出现时显示（M10） |
| 地城进度 | (24, 132) | `dungeon_entered` / `dungeon_room_cleared` / `dungeon_exited`（M10） |
| 交互提示 | 技能栏正上方 | `interact_prompt_changed`，`""` 表示隐藏（M10） |
| 装备栏 | (24, 430) | 300×240，5 格（`SLOT_ORDER`），品质色，空位显示"空" |
| 技能栏 | 底部居中 | `SkillBar` 子节点，锚点跟随窗口（详见下节） |
| Toast | (420, 120) | `toast` 信号驱动，定时淡出 |
| 操作提示 | (24, 690) | 移动 / 攻击 / 技能 / 冲刺 / 切职业 |

### 数据流
全部通过 Events 信号更新，HUD 不持有 Player 引用（解耦，可直接替换为正式 UI 场景）。

## 技能栏（SkillBar，M7）

**文件**：`scripts/ui/skill_bar.gd`。由 HUD 在 `_ready()` 里 `SkillBar.new()` 挂成子节点，
自身监听 `Events`，HUD 不参与其刷新。

| 点 | 做法 |
| --- | --- |
| 位置 | 底部居中，用 anchor(0.5, 1) + offset 定位，窗口尺寸变化自动跟随 |
| 槽位 | 2 个 56×56 Panel（普攻 / 大招），下标与 `Player.skills()` 一致 |
| 图标 | **程序化占位**：技能色边框 + 技能名首字。`data/skills.json` 的 `icon` 填了真图即可替换 |
| 冷却 | `ColorRect` 遮罩从顶部向下退去（高度 = 剩余比例），叠加剩余秒数文本 |
| 可用性 | 冷却中或蓝不足 → 槽位压暗、边框转灰 |
| 输入 | **全部子节点 `mouse_filter = IGNORE`**，否则会挡住鼠标左键攻击 |

配色来源：槽位边框与图标取 `SkillDef.color`，所以换职业（`player_skills_changed`）即自动换色。

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

## 加点面板 / 背包面板（独立 CanvasLayer）

`AttributePanel`（M8，`C` 键）与 `InventoryPanel`（M11，`I`/`B` 键）都不塞进 HUD，
而是**各自一个 `CanvasLayer`（layer 20）**，由 `main.gd` 挂载。三者共用的约定：

| 点 | 做法 |
| --- | --- |
| 刷新 | 只监听 `Events`，不引用 `Player`（对比、卖出价、加成文本都在本地按数据层公式算） |
| 操作 | 只发「请求」信号（如 `backpack_equip_requested`），由 `Player` 执行后广播状态回来 |
| 打开时 | 加入 `modal_ui` 组，`Player._ui_blocking()` 据此冻结移动与攻击（按钮拦不住轮询式读输入） |
| 暂停时 | `process_mode = PROCESS_MODE_ALWAYS`，DevPause 暂停后仍能开关与点按钮 |
| 按钮 | `focus_mode = FOCUS_NONE`，否则点过之后空格 / 回车会重复触发按钮 |
| 遮罩 | 全屏 `ColorRect`（`PRESET_FULL_RECT` + `MOUSE_FILTER_STOP`）吃掉点击 |

详见 [attributes.md](attributes.md) 与 [inventory.md](inventory.md)。

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
- [x] 技能栏（M7 已实现，见上节；技能图标仍是程序化占位，待出图）
- [ ] 伤害数字对象池（当前每击 `new`，量大会有 GC 压力）
