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

开源项目检索可参考清单 **`bobeff/open-source-games`**（约 145 个开源游戏汇总）：与本项目**同构的只有约 8 个** ——
`Abyss Engine`（暗黑 2 净室重实现，**MIT**，对应 M3 掉落 / M11 背包的数据与 UI 结构）、
`DCSS` / `Shattered Pixel Dungeon`（地牢生成算法；**代码是 GPL，只看不抄**）、
`Unknown Horizons godot-port` / `Liblast`（全清单里仅有的两个 Godot 4 项目）、
`Veloren` / `OpenKO` / `OpenKore`（留给 M14 联机）；**其余（反编译类、赛车 / 城建 / RTS / 回合制等）与本项目无关**。
沿用既有铁律：**不复制 GPL 项目的代码与素材**（见 [`docs/tasks/README.md`](docs/tasks/README.md) 的全局规则）。
注意**代码许可 ≠ 素材许可**：例如 DCSS 代码是 GPLv2+，但其 32×32 tiles 是 **CC0**（可自由商用）。

**第三方模型 / 素材许可口径**（2026-10-10 修订，判定基准 = 本项目**非商用**）：

1. 本项目**非商用**：个人自用原型，不售卖、不收费、不投放广告。故**模型的 `allowCommercialUse` 不再作为筛选硬条件**
   —— 含 `RentCivit` / `Rent` / `Sell` / 空值 的条目**都可以用**，只排除**明确禁止任何使用 / 仅限查看**的条目。
2. **署名义务不受"非商用"影响**：`allowNoCredit = False` 的条目**必须署名**，在游戏内 credits 或 README 列出作者与出处。
3. 任何第三方模型 / 素材**一律登记**到 [`assets/_LICENSES.md`](assets/_LICENSES.md)：来源 URL、作者、许可原文、署名义务、放置路径。
4. ⚠️ **一旦本项目转为商用（上架 / 收费 / 广告变现），必须回头复核 `_LICENSES.md` 全部条目**，
   以其中「商用」列为依据逐条重判；届时不合格的模型与素材要替换或删除。**转商用时不得跳过这一步**。

| 项 | 值 |
| --- | --- |
| 引擎 | Godot 4（`project.godot` 声明 **4.7**；编辑器 4.3+ 可开，本机实测版本 **4.4.1**） |
| 渲染 | `gl_compatibility` 后端 |
| 语言 | GDScript，**静态类型必须完整** |
| 空间 | **真 3D**（XZ 为地面、Y 为高度）+ 固定正交俯角相机（-45°）+ billboard 精灵 |
| 主场景 | `res://scenes/main.tscn`，根 `Node3D`，**其余节点全部由代码构建** |
| 美术 | 零外部素材，贴图由 `SpriteFactory` 用代码生成（**占位用，无固定风格**；出图基线见 [`assets/_PROMPTS.md`](assets/_PROMPTS.md)） |

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
- **`var x := f()` 而 `f()` 返回 `Variant` 会直接编译失败**（Godot 4.7 报
  `The variable type is being inferred from a Variant value ... (Warning treated as error.)`）。
  凡是「可能返回 `null` 的辅助函数」都要写成 `var x: Variant = f()`。
- 局部变量别叫 `name`（遮蔽 `Node.name`）；`String + Variant` 的结果也是 `Variant`，要显式转换。
- `is_equal_approx()` 只吃 `float`；两个 `Vector2` 要用 `a.is_equal_approx(b)`。

**Godot 3D**

- **必须先 `add_child()` 才能写 `global_position`**，否则报 `Condition "!is_inside_tree()" is true`。
- ⚠️ **但 `add_child()` 与 `setup()` 的先后要分开看**：`Enemy` / `Player` 的视觉是在 `_ready()`（入树时）
  按 `archetype` / `profession` 建的，所以必须**先 `setup(level, archetype)` 再 `add_child()`**
  （`main.gd::_spawn_enemy` 就是这个顺序）。反了不报错，但会**静默退回「默认配色的程序化占位贴图」**
  —— 症状是「真素材填了却像没生效」，极难查。
- `Camera3D` **没有** `limit_left/right/top/bottom`，边界钳制要手写（见 `main.gd::_clamp_focus()`）。
- 顶视角用 `CharacterBody3D` 时要设 `motion_mode = MOTION_MODE_FLOATING`（关掉重力 / 贴地）。
- billboard 精灵**不要投射阴影**（会变成薄片），改用脚下的平躺圆盘做影斑。
- 朝向型网格的本地前方统一为 **+X**，所以 `node.rotation.y = -facing.angle()`。

**存档（M13）**

- **存档是外部输入**（可能被手改、可能是旧版本）：解析后一律兜底，别 `push_error`、别假设字段存在。
- **解析存档 JSON 用 `JSON` 实例（`json.parse(text)`），不要用 `JSON.parse_string()`**：
  后者失败时会往 stderr 打引擎级 `ERROR: Parse JSON failed`，而「存档损坏」是**预期内**的情况，
  会破坏「0 ERROR / 0 WARNING」的验收口径。见 `SaveService._parse_json_dict()`。
- **启动会先弹标题选档界面（`get_tree().paused = true`，世界是暂停的）**：
  - 需要世界跑起来的自测必须自己选槽位（`main.choose_slot(1, true)`）—— 见 `test_input_move.gd`；
    只断言状态的测试不受影响。
  - 暂停时 `SceneTree.process_frame` **仍会触发**（已实测），所以基于帧的 `--script` 自测不会被挂住。
  - 用 `Engine.time_scale = 0` 之类「假装暂停」的写法不要引入：那是另一套语义，会和 DevPause / 自测打架。

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

# 7) 背包自测：入包 / 装备换装 / 分解 / 容量 / 一键换装 / 买卖 / 界面
godot --headless --path . --script res://tests/test_inventory.gd

# 8) 存档自测：序列化往返 / 兜底 / 槽位 IO / 坏档备份 / 标题选档 / 一条龙存读
godot --headless --path . --script res://tests/test_save.gd

# 9) 相机自测：配置 / 缩放旋转俯角钳制 / 含旋转的边界钳制 / 瞬移对齐 / 副本边界
godot --headless --path . --script res://tests/test_camera.gd

# 10) 长时运行：主场景跑 900 帧（M13 起启动停在标题选档界面、世界是暂停的）
#    → 这条只保证「待机 + 自动保存防抖」路径无报错；
#      真正的战斗 soak（刷怪/追击/攻击/受伤/掉落）在 test_smoke_3d.gd（它自己选槽位让世界跑）
godot --headless --quit-after 900 --path . res://scenes/main.tscn
```

全部脚本**自行 `quit(0/1)`**，所以看退出码即可判断成败。
验收口径：10 条全过，且最后一条 **0 ERROR / 0 WARNING**。

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
| 改背包 / 商店 / 装备对比 | [`docs/modules/inventory.md`](docs/modules/inventory.md) |
| 改存档 / 槽位 / 标题选档 | [`docs/modules/save.md`](docs/modules/save.md) |
| 改掉落 / 装备 / 敌人数值 | [`docs/modules/loot.md`](docs/modules/loot.md) |
| 改竞技场 / 掉落物 | [`docs/modules/world.md`](docs/modules/world.md) |
| 改 HUD / 伤害数字 | [`docs/modules/ui.md`](docs/modules/ui.md) |
| 看下一步做什么 | [`docs/roadmap.md`](docs/roadmap.md) |
| 出美术素材 | [`docs/tasks/`](docs/tasks/) 对应卡片 + [`assets/_PROMPTS.md`](assets/_PROMPTS.md) + [`assets/_LICENSES.md`](assets/_LICENSES.md) |
| 看跨里程碑待办 / 未决项 / 已作废项 | [`docs/tasks/backlog.md`](docs/tasks/backlog.md) |
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
**M10 地城与 Boss（3 房间房间流 + 清房开门 + 真墙体碰撞 + Boss 房 + 传送门进出）** /
**M11 背包与交易（24 格背包 + 装备对比 + 一键换装 + 商店购买 / 刷新）** /
**M13 存档（3 槽位 + 标题选档界面 + 原子写 / 坏档备份 / 防抖自动存 + F5 存 · F9 读）** /
**M16 相机微调（参数进 `data/camera.json` + `CameraRig`：滚轮缩放 / 旋转 / 俯角 / 含旋转的边界钳制）**。

下一步：**M15 素材接入**（真实 sprite / 中文字体 / 音频）。
✅ **2026-10-13 角色 sprite 链路全部跑通**：出图（A4 多视角设定图）→ 对比台一键裁切 4 张 128² →
`assets/sprites/` → 填 JSON 的 `sprite_path` → 游戏内生效，**渲染代码零改动**。
已接入 **4 个敌人**（走 `data/enemies.json`）与 **3 个职业主角**（走 `data/professions.json`，转职即时换图），
共 28 张；同时把 billboard 的 `texture_filter` 改为按「真素材 / 程序化占位」分流（Linear / Nearest），
并加了 **Git LFS** 规则（**按类型 / 目录**圈：源图 `assets/concepts/**` + 字体 + 音频走 LFS，
`assets/{sprites,tilesets,icons,ui}/` 的游戏内小图直存；⚠️ MB 级源图必须放 `concepts/`）。
接入口径与导入参数见 [`docs/modules/render3d.md`](docs/modules/render3d.md)。
✅ **技能图标已接（2026-10-13）**：6 个技能各一张 128²，走 `data/skills.json` 的 `icon`（`SkillBar` 渲染，
留空退回「技能名首字」占位；生成脚本 `tools/lora-compare/gen_icons.py`）。
⏳ **仍待素材**：装备 / 物品图标（`data/loot.json` 的 `icon`，需先给 `ItemDef` 加字段 + 改三处 UI）、
地砖 tileset（替换 `DungeonRoom` 的程序化网格）、中文字体 `.ttf`（HUD 当前用引擎回退字体，实测中文显示正常）、音频。
细节见 [`docs/roadmap.md`](docs/roadmap.md) 与 [`docs/tasks/`](docs/tasks/)。

> ⚠️ **范围决定（别再主动提议）**
> - **M12 PVP 区域暂不做**：单机原型没有第二个玩家可打，要等联机之后才有意义。
> - **M14 联机暂不做**（2026-10-10 决定）：前置是把权威模拟层从表现层里抽出来
>   —— 现在 `main.gd` 同时管世界搭建 / 刷怪 / 结算，`Player`、`Enemy` 直接读写 `global_position`，
>   不先重构就没法落「客户端发意图、服务端裁决」这一刀。参考
>   [`docs/reference/mmo-opensource/README.md`](docs/reference/mmo-opensource/README.md) 的「权威服务器」原则。

> ⚠️ **数据校准欠账**：M7 的职业与技能、M8 的属性与加点曲线、M10 的地城与 Boss、
> M11 的背包容量与价格**全部是自行设计的占位值**（原作官网 403 无法访问）。拿到原作资料后只需改
> `data/professions.json`、`data/skills.json`、`data/attributes.json`、`data/dungeon.json`、
> `data/enemies.json`、`data/inventory.json`、`data/shop.json`，代码一行不用动。
> 出图任务见 [`docs/tasks/M7-skills.md`](docs/tasks/M7-skills.md)、
> [`docs/tasks/M8-attributes.md`](docs/tasks/M8-attributes.md)、
> [`docs/tasks/M10-dungeon.md`](docs/tasks/M10-dungeon.md)、
> [`docs/tasks/M11-inventory.md`](docs/tasks/M11-inventory.md)。

> 💡 **美术欠账**：M7 / M8 / M10 / M11 的代码都已落地，但**全部用程序化占位美术**
> （`SpriteFactory` 逐像素/网格生成），接真素材只需要填 JSON 的 `sprite_path` / `icon`
> 之类字段，渲染路径不用改。

> 🔁 **M11 起的行为变化（别再当成 bug）**：掉落**不再自动穿 / 自动分解**，而是进背包；
> 背包满了才当场分解；在背包里换装时，**换下来的旧装备会回到背包**。

---

## 7. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版：把散落在 `docs/` 与历史对话里的硬性约定收敛成单一入口；补 Godot 版本差异、`icon.svg.import` 副作用、里程碑编号权威三条 |
| 2026-10-10 | §1 登记参考游戏**魔域**（Eudemons Online）：仅借鉴系统设计、不复用素材；参考范围收窄为**副本（M10）+ 属性面板（M8）**，幻兽/转职分支/强化/军团/交易等**明确不做** |
| 2026-10-10 | **M8 属性加点完成**：§4 增加第 5 条验证命令（`tests/test_attributes.gd`，验收口径 5 条 → 6 条）；§5 索引加 `docs/modules/attributes.md`；§6 下一步切到 M10 地城与 Boss |
| 2026-10-10 | **M10 地城与 Boss 完成**：§4 增加第 6 条验证命令（`tests/test_dungeon.gd`，验收口径 6 条 → 7 条）；§5 索引加 `docs/modules/dungeon.md`；§6 下一步切到 M11 背包与交易，并补一条「美术欠账」说明 |
| 2026-10-10 | **M11 背包 / 商店完成**：§4 增加第 7 条验证命令（`tests/test_inventory.gd`，验收口径 7 条 → 8 条）；§5 索引加 `docs/modules/inventory.md`；§6 补一条**掉落行为变化**提醒（不再自动穿，改为入包） |
| 2026-10-10 | **M12 PVP 区域暂不做**：§6 下一步改为 **M13 存档**，并记下「单机原型没有第二个玩家，PVP 等 M14 联机后再做，别再主动提议」 |
| 2026-10-10 | **M13 存档完成**：§3 新增「存档」陷阱组（存档是外部输入要兜底、解析用 `JSON` 实例别用 `JSON.parse_string()`、**启动会先弹标题选档界面并把世界暂停**因此需要世界跑的自测要自己选槽位）；§4 增加第 8 条验证命令（`tests/test_save.gd`，验收口径 8 条 → 9 条）；§5 索引加 `docs/modules/save.md` |
| 2026-10-10 | **M14 联机暂不做**：§6 下一步改为 **M15 素材接入**，并注明「M15 阻塞在素材上，素材没到可先做纯代码的 M16 相机微调」；把 M12 / M14 两条范围决定合并成「别再主动提议」清单 |
| 2026-10-10 | **M16 相机微调完成**：§3 新增 3 条 GDScript 编译期坑（`:=` 推断到 `Variant` 直接编译失败、局部变量叫 `name`、`is_equal_approx` 不吃 `Vector2`）；§4 增加第 9 条验证命令（`tests/test_camera.gd`，验收口径 9 条 → 10 条）；§5 索引不变（相机文档仍在 `docs/modules/render3d.md`）；§6 状态补上 M16，下一步仍是 M15 素材接入 |
| 2026-10-10 | §1 新增**第三方模型 / 素材许可口径**：本项目**非商用** → 模型的 `allowCommercialUse` **不再作为筛选硬条件**（含 `RentCivit` / `Rent` / `Sell` / 空值 均可用），只排除「明确禁止任何使用」的条目；**署名义务不受影响**（`allowNoCredit=False` 必须署名）；第三方模型一律登记 `assets/_LICENSES.md`；⚠️ **转商用前必须回头复核全部登记项** |
| 2026-10-10 | §5 索引加 [`docs/tasks/backlog.md`](docs/tasks/backlog.md)（**跨里程碑待办 / 未决 / 已作废清单**）：固化三条口径（非商用 / 不做像素风 / **Forge 未开 CORS，网页工具必须自带本地代理**），列 T-01~T-13 待办、4 条未决、7 条已作废，并附 Forge API 的 checkpoint 标识与 LoRA 命名等接口事实 |
| 2026-10-10 | §1 登记开源项目清单 **`bobeff/open-source-games`**：记下约 8 个同构候选（Abyss Engine / DCSS / 像素地牢 / Unknown Horizons godot-port / Liblast / Veloren / OpenKO / OpenKore）与「其余无关」的结论；补一条**代码许可 ≠ 素材许可**（DCSS 代码 GPLv2+ 但 tiles 是 CC0），重申**不复制 GPL 代码与素材** |
| 2026-10-10 | **美术风格基线改为"不做像素风"**（保留低分辨率 + 复古观感）：§1 的「美术」行由"**逐像素生成**"改为"代码生成（占位用、**无固定风格**）"，指向新基线；素材规格整体上调一档（角色 128² / 地砖 64² / 图标 64²），导入滤波由 Nearest 改 **Linear + Mipmaps**；`assets/_PROMPTS.md` 的 A–F 模板去像素化并加负向 `pixel art`，新增「后期统一规范」；**LoRA 改为可选**（先不加跑通一轮）。同步：`docs/reference/ai-asset-generation.md`、`docs/tasks/{README,_template,M7,M10,M11}`、`docs/modules/render3d.md`、`docs/reference/mmo-opensource/{intersect-engine,kaetram-open}.md` |
| 2026-10-13 | **M15 第一步：敌人 sprite 接入链路跑通（游戏侧代码零改动）**。新增 A4「角色多视角设定图」模板 + 对比台一键裁切（`crop_sheet.py`）；`assets/sprites/enemy_slime_{front,iso,side,back}.png`（各 128²）+ `slime.sprite_path` 指向 `_iso`；`SpriteFactory.billboard_sprite()` 的 `texture_filter` 改为按来源分流（真素材 `LINEAR` / 占位 `NEAREST`）；新增 `.gitattributes`（**按类型 / 目录**圈 LFS：源图/概念图 + 字体 + 音频；游戏内小图直存）；sprite 的 `.import` 打开 mipmaps + 关掉 `detect_3d` 自动压缩；`test_data_layer.gd` 增加「非空 `sprite_path` 必须能加载成 Texture2D」断言。§6 状态更新（「素材没到就先做 M16」这句已过时，M16 早已完成） |
| 2026-10-13 | **M15 角色 sprite 批次接入（4 敌人 + 3 职业，共 28 张 128²）**：`Profession` 新增 `sprite_path` 字段 + `Player._refresh_sprite()`（转职即时换图，并重算 `pixel_size` —— 占位 64px / 真素材 128px）；`enemies.json` 补齐 `brute` / `wisp` / `bone_lord`（`slime` 换成真正的史莱姆美术）；`professions.json` 三职业全部接图；`test_data_layer.gd` 的素材断言扩展到职业。§3 新增一条**静默陷阱**：`Enemy` 必须先 `setup()` 再 `add_child()`，否则 `_ready()` 里读到空 `archetype`、静默退回占位贴图。10 条验证命令全过、主场景 900 帧 0 ERROR / 0 WARNING，另跑真窗口截图确认四种敌人 + 主角精灵在游戏内正确渲染 |
| 2026-10-13 | **M15 技能图标接入（6 张 128²）—— E 模板首个落地产物**：新增 `tools/lora-compare/gen_icons.py`（提示词拼装与网页端同源：直接读 `prompts.json` 的 E 模板与要求块 → 1024² 透明底 → **去 alpha 噪声地板** → 抠边 → LANCZOS 128²）；`SkillBar` 加真图标渲染（`_set_icon()`：有图显图、无图退回「技能名首字」占位；路径缺失只 `push_warning` 不白屏；蓝/冷却不足时图标压暗 0.45）；`data/skills.json` 6 个 `icon` 全填；`test_data_layer.gd` 的素材断言扩展到技能图标。另：**对比台编码器默认改指 nvfp4**（T-22 ①，`app.js` 把 `S.aux.clip` 排成 nvfp4 优先）、**A2 模板标记废弃**（i2i 已结案 → 改用 A3/A4）。10 条验证命令全过、主场景 900 帧 0 ERROR / 0 WARNING，真窗口截图确认技能栏两个图标正确渲染 |
