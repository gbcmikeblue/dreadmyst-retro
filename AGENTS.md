# AGENTS.md · AI 协作约定

> 本文件是 AI 助手（以及新加入的人类协作者）的**唯一入口**。动手改代码前先读这里，
> 再按下面的「文档索引」去看对应模块的细节。**本文件只放"必须知道"的硬性约定，不放细节。**

---

## 1. 项目是什么

参考独立游戏 **Dreadmyst**（2.5D 复古风免费 MMO：WoW 式职业属性 + 传奇式刷怪 + 暗黑式掉宝）
做成的 **Godot 4 单机可玩原型**。当前聚焦：能跑、能操作、能刷怪、能掉装备。

系统设计可另参考国产复古 MMO **魔域**（网龙 / Eudemons Online）：**仅借鉴系统设计与养成思路，不复用其任何素材**
（商业作品、无授权）。参考范围**仅限两项**：**副本**（对应 M10 地城与 Boss）、**属性面板 / 加点**（对应 M8）。

魔域其余系统**明确不做**（勿再主动提议）：幻兽 / 宠物、转职与职业分支（暂不做）、装备强化 / 升星 / 宝石镶嵌 /
附魔 / 套装、家族军团 PK / 攻城、交易行 / 摆摊 / 押镖 / 挖宝。

| 项 | 值 |
| --- | --- |
| 引擎 | Godot 4（`project.godot` 声明 **4.7**；编辑器 4.3+ 可开，本机实测版本 **4.4.1**） |
| 渲染 | `gl_compatibility` 后端 |
| 语言 | GDScript，**静态类型必须完整** |
| 空间 | **真 3D**（XZ 为地面、Y 为高度）+ 固定正交俯角相机（-45°）+ billboard 精灵 |
| 主场景 | `res://scenes/main.tscn`，根 `Node3D`，**其余节点全部由代码构建** |
| 美术 | 零外部素材，贴图由 `SpriteFactory` 逐像素生成 |

---

## 2. 硬性规范（违反即视为 bug）

1. **数据 / 逻辑分离**：策划可调的内容（数值、名字、颜色、权重、贴图路径）一律进 `data/*.json`。
   加敌人 / 加词条 / 加名字池 = **只改 JSON，不改代码**。
2. **跨模块通信只走 `Events` 信号总线**：禁止在 actor 内部自建 `signal` 做跨模块通知。
   新增信号加在 `scripts/core/event_bus.gd`。
3. **数据层纯净**：`scripts/data/` 不做渲染调用、不写 `_process`、不 emit 信号。
4. **场景文件极简**：只有 `main.tscn` 一个场景。**不要手工编辑它**，也不要新增 `.tscn` 来放逻辑节点。
5. **玩法逻辑用 `Vector2` 在"玩法平面"上算**，只在读写节点位置时转换：
   ```gdscript
   Game.world(v2, height := 0.0) -> Vector3   # (x, y) -> (x, height, y)
   Game.plane(v3) -> Vector2                  # (x, y, z) -> (x, z)
   ```
   这样 AI / 攻击判定 / 边界钳制等逻辑与 2D 版逐字相同，转换面积最小。
6. **静态类型必须完整**；`get_tree().get_nodes_in_group(...)` 的结果先赋给**无类型 `Array`** 再迭代，
   否则静态分析会把元素推断为 `Node` 而报「找不到成员」。
7. **JSON 加载**统一走 `FileAccess.get_file_as_string` + `JSON.parse_string`，
   且**必须**校验 `typeof(x) == TYPE_DICTIONARY`（解析失败返回 `null`）。
8. **新增可调参数放 JSON，不要硬编码进脚本**；确属不可调的常量才用 `const` 并写注释。

---

## 3. 常见陷阱（改代码前务必扫一眼）

**输入 / InputMap**

- 注册动作必须 **`physical_keycode` 与 `keycode` 两套都加**。只注册 `physical_keycode` 时，
  远程桌面 / 虚拟机 / 部分驱动不提供物理键码，该动作会**完全收不到键盘输入**。
  症状极具迷惑性：鼠标点击正常，只有键盘失灵。
- 暂停后 `CanvasLayer` 上的 UI 默认停止响应，需要 `process_mode = PROCESS_MODE_ALWAYS`。
- `Button.focus_mode = FOCUS_NONE`，否则点过按钮后空格 / 回车会重复触发按钮而不是游戏内动作。

**GDScript**

- `randi_range(a, b)` **包含两端**。
- `move_and_slide()` 之后再改 `velocity` 不生效。
- `Dictionary.values()` 返回 `Array`，不是 keyed dict。

**Godot 3D**

- **必须先 `add_child()` 才能写 `global_position`**，否则报 `Condition "!is_inside_tree()" is true`。
- `Camera3D` **没有** `limit_left/right/top/bottom`，边界钳制要手写（见 `main.gd::_clamp_focus()`）。
- 顶视角用 `CharacterBody3D` 时要设 `motion_mode = MOTION_MODE_FLOATING`（关掉重力 / 贴地）。
- billboard 精灵**不要投射阴影**（会变成薄片），改用脚下的平躺圆盘做影斑。
- 朝向型网格的本地前方统一为 **+X**，所以 `node.rotation.y = -facing.angle()`。

**运行 / 验证**

- 终端无输出时用 `godot_console.exe`（标准 exe 不带控制台）。
- 克隆仓库后**必须先** `godot --headless --import --path .`，
  否则会看到一堆 `Parse Error: Could not find type "Player"` —— 这不是代码错误，
  是 `class_name` 全局缓存（`.godot/global_script_class_cache.cfg`）未生成，而 `.godot/` 被 gitignore。
- **用低于 4.7 的引擎导入会改写 `icon.svg.import`**（删掉 4.7 才有的键）。
  验证完请 `git checkout -- icon.svg.import` 还原，**不要提交这个降级改动**。

---

## 4. 验证命令（改完必须跑）

```powershell
# 0) 首次 / 换机器：导入工程（生成 .godot 缓存 + 全局类名注册表）
godot --headless --import --path .

# 1) 数据层自测：JSON 加载 / 装备生成 / 加权分布
godot --headless --path . --script res://tests/test_data_layer.gd

# 2) 3D 冒烟测试：实例化主场景跑 300 帧，清点实体与渲染节点
godot --headless --path . --script res://tests/test_smoke_3d.gd

# 3) 输入链路诊断：按键 -> 动作 -> 移动（键盘失灵时先跑这个）
godot --headless --path . --script res://tests/test_input_move.gd

# 4) 技能自测：施放 / 冷却拦截 / 360° 判定 / 转职 / 蓝量门槛
godot --headless --path . --script res://tests/test_skills.gd

# 5) 属性加点自测：属性表 / 加点 / 上限 / 满级 / 转职不重置 / 界面开关
godot --headless --path . --script res://tests/test_attributes.gd

# 6) 地城自测：进出地城 / 房间流 / 清房开门 / Boss / 奖励 / 边界还原
godot --headless --path . --script res://tests/test_dungeon.gd

# 7) 长时运行：覆盖刷怪 / 追击 / 攻击 / 受伤 / 掉落
godot --headless --quit-after 900 --path . res://scenes/main.tscn
```

全部脚本**自行 `quit(0/1)`**，所以看退出码即可判断成败。
验收口径：7 条全过，且最后一条 **0 ERROR / 0 WARNING**。

> ⚠️ 自测里**别故意触发 `push_warning` 分支**（例如拿未知 id 去调 `Player.allocate_attribute()`）：
> 会让输出混进 WARNING，破坏上面「0 WARNING」的验收口径。这类分支改在数据层断言。

> ⚠️ 写新的 `--script` 测试时**不要**引用 `Events` / `Game` 单例名 —— 入口脚本的编译早于
> autoload 注册，会直接 `Identifier not found` 编译失败。需要坐标转换时手写
> `Vector2(pos.x, pos.z)` / `Vector3(p.x, 0.0, p.y)`，见 `tests/test_skills.gd`。
详细说明与「验证时的已知非问题」见 [`docs/architecture.md`](docs/architecture.md) §6。

---

## 5. 文档索引（按需深入，不要一次全读）

| 你要做什么 | 先读 |
| --- | --- |
| 改架构 / 摸清全局约定 | [`docs/architecture.md`](docs/architecture.md) |
| 改渲染 / 相机 / 精灵 | [`docs/modules/render3d.md`](docs/modules/render3d.md) |
| 改自动加载 / 输入映射 / 坐标转换 | [`docs/modules/core.md`](docs/modules/core.md) |
| 改玩家 / 敌人 / 战斗公式 | [`docs/modules/combat.md`](docs/modules/combat.md) |
| 改职业 / 技能 / 冷却与蓝条 | [`docs/modules/skills.md`](docs/modules/skills.md) |
| 改属性加点 / 加点界面 | [`docs/modules/attributes.md`](docs/modules/attributes.md) |
| 改地城 / 房间流 / Boss / 传送门 | [`docs/modules/dungeon.md`](docs/modules/dungeon.md) |
| 改掉落 / 装备 / 敌人数值 | [`docs/modules/loot.md`](docs/modules/loot.md) |
| 改竞技场 / 掉落物 | [`docs/modules/world.md`](docs/modules/world.md) |
| 改 HUD / 伤害数字 | [`docs/modules/ui.md`](docs/modules/ui.md) |
| 看下一步做什么 | [`docs/roadmap.md`](docs/roadmap.md) |
| 出美术素材 | [`docs/tasks/`](docs/tasks/) 对应卡片 + [`assets/_PROMPTS.md`](assets/_PROMPTS.md) + [`assets/_LICENSES.md`](assets/_LICENSES.md) |
| 总索引 | [`docs/README.md`](docs/README.md) |

**里程碑编号以 [`docs/roadmap.md`](docs/roadmap.md) 为唯一权威。** 历史上 `docs/tasks/` 用过
另一套编号，已于 2026-10-09 统一（对照表见 `docs/tasks/README.md` 文末）。

工程规范 skill：`.codebuddy/skills/godot4-gdscript-conventions/`（本项目内自带，改 GDScript 时适用）。
其中 `references/pitfalls.md` 是踩坑清单（含症状与成因），`references/data-schema.md` 是数据表结构。

---

## 6. 当前状态与下一步（2026-10-10）

已完成：M0 工程骨架 / M1 玩家 / M2 敌人 AI / M3 掉落系统 / M4 HUD / M5 数据驱动 /
M6 工程规范 / **M7 职业与技能（3 职业 + 6 技能 + 冷却 / 蓝条 + 技能栏）** /
**M8 属性加点（5 属性 + 每级 5 点自由分配 + 加点界面 C 键）** /
**M9 2.5D 渲染（2D → 真 3D 重构，数据层零改动）** /
**M10 地城与 Boss（3 房间房间流 + 清房开门 + 真墙体碰撞 + Boss 房 + 传送门进出）**。

下一步：**M11 背包与交易**（多格背包、装备对比、商店）。
细节见 [`docs/roadmap.md`](docs/roadmap.md) 与 [`docs/tasks/M11-inventory.md`](docs/tasks/M11-inventory.md)。

> ⚠️ **数据校准欠账**：M7 的职业与技能、M8 的属性与加点曲线、M10 的地城与 Boss 数值
> **全部是自行设计的占位值**（原作官网 403 无法访问）。拿到原作资料后只需改
> `data/professions.json`、`data/skills.json`、`data/attributes.json`、`data/dungeon.json`、
> `data/enemies.json`，代码一行不用动。
> 出图任务见 [`docs/tasks/M7-skills.md`](docs/tasks/M7-skills.md)、
> [`docs/tasks/M8-attributes.md`](docs/tasks/M8-attributes.md)、
> [`docs/tasks/M10-dungeon.md`](docs/tasks/M10-dungeon.md)。

> 💡 **美术欠账**：M7 / M8 / M10 的代码都已落地，但**全部用程序化占位美术**
> （`SpriteFactory` 逐像素/网格生成），接真素材只需要填 JSON 的 `sprite_path` / `icon`
> 之类字段，渲染路径不用改。

---

## 7. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版：把散落在 `docs/` 与历史对话里的硬性约定收敛成单一入口；补 Godot 版本差异、`icon.svg.import` 副作用、里程碑编号权威三条 |
| 2026-10-10 | §1 登记参考游戏**魔域**（Eudemons Online）：仅借鉴系统设计、不复用素材；参考范围收窄为**副本（M10）+ 属性面板（M8）**，幻兽/转职分支/强化/军团/交易等**明确不做** |
| 2026-10-10 | **M8 属性加点完成**：§4 增加第 5 条验证命令（`tests/test_attributes.gd`，验收口径 5 条 → 6 条）；§5 索引加 `docs/modules/attributes.md`；§6 下一步切到 M10 地城与 Boss |
| 2026-10-10 | **M10 地城与 Boss 完成**：§4 增加第 6 条验证命令（`tests/test_dungeon.gd`，验收口径 6 条 → 7 条）；§5 索引加 `docs/modules/dungeon.md`；§6 下一步切到 M11 背包与交易，并补一条「美术欠账」说明 |
