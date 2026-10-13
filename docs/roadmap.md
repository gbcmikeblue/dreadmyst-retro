# Roadmap 与变更记录

## Roadmap（未完成，按优先级）

- [x] **M7 职业与技能系统**：3 职业（战/法/游）+ 6 技能 + 冷却/蓝条 + 技能栏。
  **代码完成；数值为自设占位，待原作资料校准**。详见 [modules/skills.md](modules/skills.md)
- [x] **M8 属性加点**：升级给自由属性点（5 属性 + 加点界面）。
  **代码完成；数值为自设占位，待原作资料校准**。详见 [modules/attributes.md](modules/attributes.md)
- [x] **M10 地城与 Boss**：3 房间房间流 + 清房开门 + 真墙体碰撞 + Boss 房 + 通关奖励 + 传送门进出。
  **代码完成；美术仍为程序化占位，数值为自设占位**。详见 [modules/dungeon.md](modules/dungeon.md)
- [x] **M11 背包与交易**：24 格背包、装备对比、一键换装、商店（购买 / 刷新）。
  **代码完成；美术仍为程序化占位，数值为自设占位**。详见 [modules/inventory.md](modules/inventory.md)
- [ ] **M12 PVP 区域** —— ⚠️ **暂不做**（2026-10-10 决定）。
  参考游戏里 PVP 是「区域属性」，但本项目是**单机原型**，没有第二个玩家可打；
  等 M14 联机之后再做才有意义（届时按 `docs/reference/mmo-opensource/kaetram-open.md`
  的「区域作为地图数据属性层」实现）
- [x] **M13 存档**：`user://` 3 槽位（等级 / 经验 / 属性点 / 背包 / 装备 / 金币）+ 标题选档界面
      + 原子写 / 坏档备份 / 防抖自动存。**代码完成**。详见 [modules/save.md](modules/save.md)
- [ ] **M14 联机** —— ⚠️ **暂不做**（2026-10-10 决定）。ENet 客户端-服务器要先做一件大工程：
  **把权威模拟层从表现层里抽出来**（当前 `main.gd` 同时管世界搭建、刷怪与结算，`Player`/`Enemy`
  直接读写 `global_position`），否则「客户端发意图、服务端裁决」无处落刀。
  顺带：PVP（M12）也等着它
- [ ] **M15 素材接入**：真实 sprite（`sprite_path`）/ 中文字体 / 音频 ← *当前最高优先级*  
  ↳ 出图任务卡片见 [`docs/tasks/`](tasks/)；完整方案见 [`docs/reference/ai-asset-generation.md`](reference/ai-asset-generation.md)  
  ✅ **2026-10-13 角色 sprite 链路全部跑通**：Qwen-Image 2.1 出 2×2 多视角设定图（1536²）→
  对比台「裁 sprite」切成 4 张 128² → `assets/sprites/` → 填 JSON 的 `sprite_path` → **游戏内生效，
  渲染代码零改动**。已接入 **4 个敌人**（`slime` / `brute` / `wisp` / `bone_lord`，走 `data/enemies.json`）
  与 **3 个职业主角**（`warrior` / `mage` / `ranger`，走 `data/professions.json` 的 `sprite_path`，
  `Player._refresh_sprite()` 在转职时换图并重算 `pixel_size`），各 4 视角共 **28 张**。
  顺带把 billboard 的 `texture_filter` 按「真素材 / 占位贴图」分流，并加了 **Git LFS** 规则（**按类型 / 目录**圈：源图 `assets/concepts/**` + 字体 + 音频走 LFS，`assets/{sprites,tilesets,icons,ui}/` 的小图直存）。  
  ✅ **技能图标已接（2026-10-13）**：6 个技能各一张 128²，走 `data/skills.json` 的 `icon`（`SkillBar` 渲染，
  留空退回「技能名首字」占位）；生成脚本 `tools/lora-compare/gen_icons.py`（E 模板 → 1024² → 去噪声地板 / 抠边 → 128²）。
  ⏳ **仍待素材**：装备 / 物品图标（`data/loot.json` 的 `icon`，需先给 `ItemDef` 加字段 + 改三处 UI）、
  地砖 tileset（替换 `DungeonRoom` 的程序化网格）、中文字体 `.ttf`（HUD 当前用引擎回退字体）、音频；
  以及「方向性精灵」（billboard 目前只用 `_iso` 一张）。
- [x] **M16 相机微调**：参数进 `data/camera.json`（`CameraConfig`），相机逻辑独立成 `CameraRig`；
      滚轮/`=`·`-` 缩放、`,`·`.` 旋转、`PageUp/Down` 俯角、`R` 重置；含旋转的边界钳制（斜矩形的 AABB）。
      **代码完成**；`size` / `tilt_deg` 的数值仍待目视校准（游戏内调完抄回 JSON 即可）。
      详见 [modules/render3d.md](modules/render3d.md)

## 待用户提供的信息

1. **职业列表与技能数据**：名字 / 冷却 / 耗蓝 / 伤害公式（M7 开工前必须）
2. **原作数值曲线**：官网 403 无法访问，当前全为自设
3. **角色/怪物 sprite 图**：填进 `enemies.json` 的 `sprite_path` 即生效，无需改代码
4. **中文字体** `.ttf`（HUD 与伤害数字当前用引擎回退字体，有显示异常风险）
5. **地城/区域规划**：几个区域、连接方式、Boss 机制（M10 已用「一条直线 3 房间 + 1 Boss」占位实现，
   真实规划 —— 尤其 Boss 机制与多间地城的开放顺序 —— 仍待提供）
6. **属性公式**：5 个属性的每点加成、每级自由点数、是否有职业系数（M8 开工后拿到资料即可只改 `data/attributes.json`）
7. **相机目视校准值**：M16 已把相机参数搬进 `data/camera.json` 并加了游戏内调参与读数
   （滚轮/`=`·`-` 缩放、`,`·`.` 旋转、`PageUp/Down` 俯角、`R` 重置；DevPause 面板与控制台都会显示当前值），
   **当前值仍是照 2D 版推的**，需要你目视确认后抄回 JSON

## 已完成里程碑

| 里程碑 | 日期 | 要点 |
| --- | --- | --- |
| M0 工程骨架 | 2026-10-09 | project.godot、Events/Game Autoload、输入映射 |
| M1 玩家 | 2026-10-09 | 移动/扇形攻击/冲刺/装备加成/死亡复活 |
| M2 敌人 AI | 2026-10-09 | 追击/攻击/受击/死亡，separation 排斥 |
| M3 掉落系统 | 2026-10-09 | 5 部位 × 5 品质 × 5 词条 |
| M4 HUD | 2026-10-09 | 血条/经验/金币/装备栏/伤害数字/Toast |
| M5 数据驱动 | 2026-10-09 | loot.json + enemies.json，3 种敌人原型，自测通过 |
| M6 工程规范 | 2026-10-09 | 专属 skill + 文档体系 |
| **M7 职业与技能** | **2026-10-09** | **3 职业 + 6 技能 + 各自冷却/耗蓝 + 蓝条 + 技能栏；新增 `professions.json` / `skills.json`；数值为自设占位待校准** |
| **M9 2.5D 渲染** | **2026-10-09** | **转真 3D + 固定正交相机 + billboard 精灵；数据层零改动** |
| **M8 属性加点** | **2026-10-10** | **新增 `data/attributes.json` + `AttributeDef`/`AttributeRegistry`；5 属性 × 每点加成 × 满级上限；每级 5 点自由分配；`AttributePanel` 加点界面（C 键 / +1·+5 / 满级态 / `modal_ui` 冻结操作）；新增 `tests/test_attributes.gd`（8 用例全通过）。数值为自设占位** |
| **M16 相机微调** | **2026-10-10** | **新增 `data/camera.json` + `CameraConfig`、`CameraRig`（`extends Camera3D`：跟随 / 缩放 / 旋转 / 俯角 / 边界钳制 / 瞬移自动对齐）；`main.gd` 里的 4 个相机常量与 3 个函数整体搬进 rig；新增 7 个相机输入动作（滚轮 `=` `-` `,` `.` `PageUp/Down` `R`）；DevPause 增加相机读数、调参时打控制台便于回写 JSON；**边界钳制支持旋转**（斜矩形的世界轴对齐包围盒）；新增 `tests/test_camera.gd`（10 用例）** |
| **M13 存档** | **2026-10-10** | **新增 `SaveData`（结构 + 版本 + 兜底）、`SaveService`（3 槽位 / 原子写 / 读取回退链 / 坏档改名备份 / 2 秒防抖自动存）、`TitleScreen`（启动选档：继续 / 新游戏 / 删除，危险操作二次确认）；`Player` 增加 `export_state`/`import_state`/`reset_state`，`Game` 增加 `load_progress`/`reset_progress`；`GearItem` 增加 `to_dict`/`from_dict` 并把「枚举↔可读键」收敛成唯一一份（`LootConfig` 改为转发）；新增 `tests/test_save.gd`（9 用例）。存档损坏是预期情况，解析改用 `JSON` 实例以免刷引擎 ERROR** |
| **M11 背包 / 商店 / 装备对比** | **2026-10-10** | **新增 `data/inventory.json`（容量 + 卖出价公式）与 `data/shop.json`（货架 + 刷新价）、`InventoryConfig`/`ShopConfig`；`Player` 增加背包（入包 / 装备 / 分解 / 一键换装，**掉落入包、换装回包**）；新增 `Shop` 服务（货架生成 / 购买 / 刷新，扣钱前校验背包空位）；新增 `InventoryPanel`（背包 / 商店两页签 + 装备对比 + `I` 键 + `modal_ui` 冻结）；HUD 增加背包占用；`LootTable.generate()` 支持指定部位；新增 `tests/test_inventory.gd`（8 用例）。数值为自设占位** |
| **M10 地城与 Boss** | **2026-10-10** | **新增 `data/dungeon.json` + `DungeonDef`/`DungeonRegistry`；`Dungeon`/`DungeonRoom`/`DungeonDoor`/`Portal`；3 房间房间流 + 清房开门 + **项目首处真墙体碰撞（layer 1）** + Boss 房（`bone_lord`，`is_boss` 不入野外池、免疫击退、HUD 大血条）+ 通关奖励（金币/经验/保底品质装备）+ 传送门进出（F 交互）；新增 `tests/test_dungeon.gd`（6 用例）。数值为自设占位** |

## M9 迁移记录（2D → 3D，供参考）

| 文件 | 改动 |
| --- | --- |
| `data/loot.json`、`data/enemies.json` | 数据保留；enemies.json 增 `sprite_path` 字段 |
| `scripts/data/*`（5 个） | 仅 `EnemyArchetype` 增 `sprite_path` 字段，其余零改动 |
| `scripts/ui/hud.gd` | **零改动**（CanvasLayer + Control 本来就是 2D） |
| `core/event_bus.gd` | 2 个信号的位置参数 `Vector2` → `Vector3` |
| `core/game.gd` | `get_player()` 返回 `Node3D`；新增 `world()/plane()` 转换工具 |
| `scenes/main.tscn` | 根节点 `Node2D` → `Node3D` |
| `scripts/main.gd` | 重写：3D 环境/光照/正交相机 + 手动边界钳制 |
| `actors/player.gd`、`actors/enemy.gd` | 重写：`CharacterBody3D`(FLOATING) + billboard 精灵 |
| `world/arena_background.gd`、`arena_prop.gd`、`gear_pickup.gd` | 重写：真 3D 网格 |
| `ui/damage_number.gd` | 重写：`Node2D` + `_draw()` → `Label3D`（自带 billboard，更简单） |
| `world/sprite_factory.gd` | **新增**：程序化占位贴图 / 网格工厂 |
| `tests/test_smoke_3d.gd` | **新增**：3D 冒烟测试 |

**踩到的坑**：`Camera3D` 必须先 `add_child()` 才能写 `global_position`（节点未入树时 `global_transform` 无效），否则报 `Condition "!is_inside_tree()" is true`。

## 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | M0-M4：单机原型可玩 |
| 2026-10-09 | M5：数据驱动改造（loot.json / enemies.json，新增 3 敌人原型） |
| 2026-10-09 | M6：创建工程规范 skill；开发文档拆分为多模块（docs/） |
| 2026-10-09 | M9：2D → 2.5D 重构（真 3D + 固定正交相机 + billboard 精灵 + 程序化占位美术） |
| 2026-10-09 | **修复 WASD 失效**：`_action()` 原来只注册 `physical_keycode`，环境不提供物理键码时键盘完全失灵（鼠标点击不受影响，故症状为「左键能攻击、WASD 死了」）。改为同时注册 `physical_keycode` + `keycode` |
| 2026-10-09 | 新增开发工具 `DevPause`（右上角暂停按钮 / Esc·P 快捷键 / 暂停遮罩 / 实时输入显示），由 `main.gd` 的 `DEV_TOOLS` 开关控制；新增输入链路诊断 `tests/test_input_move.gd` |
| 2026-10-09 | **基线回归验证（Godot 4.4.1）**：3 项自测 + 主场景 900 帧全部通过，0 ERROR / 0 WARNING；M9 迁移后无回归。验证细节与 3 条「已知非问题」见 [architecture.md](architecture.md) §6 |
| 2026-10-09 | **统一里程碑编号**：以本文件为唯一权威，`docs/tasks/` 的 4 张卡片重命名对齐（M8→**M11** 背包、M9→**M10** 地城、M10→**M8** 属性、M11→**M14** 联机），并同步 `ai-asset-generation.md` §7 与全部交叉引用 |
| 2026-10-09 | **M7 职业与技能（代码骨架完成）**：新增 `data/professions.json` + `data/skills.json`、`Profession`/`SkillDef` 数据层与两个注册表；`Player` 改为职业驱动并支持多技能施放（各自冷却 / 耗蓝 / 伤害倍率 / 射程 / 扇角 / 360° 判定 / F1-F3 转职）；新增 `SkillBar` 技能栏与 HUD 蓝条、职业标签；新增 `tests/test_skills.gd`（5 用例全通过），3 项既有自测 + 主场景 900 帧 0 ERROR / 0 WARNING。**数值为自设占位，待原作资料校准** |
| 2026-10-10 | **M8 属性加点（代码完成）**：新增 `data/attributes.json` + `AttributeDef`/`AttributeRegistry`（5 属性、`per_point` 每点加成、`max_points` 上限、`free_points_per_level`）；点数经济 = `(等级-1) × 每级点数 - 已投入`，等级只由 `Game` 提供；`Player.allocate_attribute()` + `Events.attribute_allocate_requested/attributes_changed`（UI 不引用 Player）；新增 `AttributePanel` 加点界面（C 键 / +1·+5 / 满级态 / `modal_ui` 冻结操作）+ HUD 剩余点数；新增 `tests/test_attributes.gd`（8 用例），6 条验证命令全过、主场景 900 帧 0 ERROR / 0 WARNING。**数值为自设占位** |
| 2026-10-10 | **修复地城 `bounds()` 口径**：Z 起点原为 `origin.y`，与 `room_rect()`（以 `origin.y` 为中线）不一致，自测报「房间不在 bounds 内」；改为 `origin.y - room_size.y * 0.5`（属 M10 期间的修复） |
| 2026-10-10 | **M10 地城与 Boss（代码完成）**：新增 `data/dungeon.json` + `DungeonDef`/`DungeonRegistry`（房间流布局的平面几何派生）；`Dungeon`（按房刷怪 / 清房开门 / Boss 房 / 通关奖励）、`DungeonRoom`（3D 地面 + **layer 1 碰撞墙** + 门洞）、`DungeonDoor`（先放行再播动画）、`Portal`（平面距离判定 + F 交互）；`enemies.json` 新增 `bone_lord` 与 `is_boss`（不入野外池 / 免疫击退 / HUD 大血条）；`Game` 增加 `ARENA_HOME` / `in_dungeon` / `arena` 切换；HUD 增加 Boss 血条、房间进度、交互提示；新增 `tests/test_dungeon.gd`（6 用例），7 条验证命令全过、主场景 900 帧 0 ERROR / 0 WARNING。**美术与数值仍为占位** |
| 2026-10-10 | **M11 背包 / 商店（代码完成）**：新增 `data/inventory.json` + `data/shop.json` 与 `InventoryConfig`/`ShopConfig`；`Player` 增加 `backpack` 与 `add_to_backpack`/`equip_from_backpack`/`sell_from_backpack`/`optimize_equipment`（**M11 起掉落不再自动穿/自动分解，改为入包；背包满才当场分解；换下来的旧装备回到背包**）；新增 `Shop` 服务（货架由 `LootTable.generate(level, rarity, slot)` 现生成，购买前校验背包空位与金币）；新增 `InventoryPanel`（`I`/`B` 键、背包 / 商店页签、装备对比、一键换装）；`LootTable.generate()` 增加 `forced_slot_key`；新增 `tests/test_inventory.gd`（8 用例），8 条验证命令全过、主场景 900 帧 0 ERROR / 0 WARNING |
| 2026-10-10 | **范围决定：M12 PVP 区域暂不做**。单机原型没有第二个玩家，PVP 要等 M14 联机之后才有意义；当前最高优先级改为 **M13 存档**（等级 / 属性点 / 背包 / 装备 / 金币已经是一整套真实状态，值得先落盘） |
| 2026-10-10 | **M13 存档（代码完成）**：`SaveData` / `SaveService` / `TitleScreen`；`Player` 的 `export_state`/`import_state`/`reset_state` 与 `Game` 的 `load_progress`/`reset_progress`；`GearItem` 序列化 + 枚举键映射收敛到唯一一份（`LootConfig` 转发）；**标题界面用 `get_tree().paused` 冻结世界**（已实测暂停时 `process_frame` 仍触发，帧驱动的自测不会被挂住）；新增 `F5` 存 / `F9` 读；新增 `tests/test_save.gd`（9 用例），9 条验证命令全过、主场景 900 帧 0 ERROR / 0 WARNING。附：`test_input_move.gd` 需在启动时替玩家选槽位（世界初始是暂停的） |
| 2026-10-10 | **M16 相机微调（代码完成）**：`data/camera.json` + `CameraConfig` + `CameraRig`；缩放 / 旋转 / 俯角 / 重置 / 瞬移自动对齐；边界钳制改成「斜矩形 AABB」以支持旋转；新增 `tests/test_camera.gd`（10 用例），10 条验证命令全过、主场景 900 帧 0 ERROR / 0 WARNING。**size / tilt 的具体数值仍待目视校准**（游戏内调完抄回 JSON） |
| 2026-10-10 | **范围决定：M14 联机暂不做**。ENet 联机的前置是「把权威模拟层从表现层抽出来」，是一整块重构；当前最高优先级改为 **M15 素材接入**（注意它阻塞在素材上，素材没到可以先做**纯代码的 M16 相机微调**） |
| 2026-10-13 | **M15 第一步：敌人 sprite 接入链路跑通（游戏侧代码零改动）**。出图侧：新增 A4「角色多视角设定图」模板（2×2 一图流）+ 对比台一键裁切 `tools/lora-compare/crop_sheet.py`（四格共用缩放 / 底对齐 / 保 alpha，尺寸 128~1024 可选）。游戏侧：`assets/sprites/enemy_slime_{front,iso,side,back}.png`（各 128²，取自 1536² 设定图）+ `slime.sprite_path` 指向 `_iso`；`SpriteFactory.billboard_sprite()` 的 `texture_filter` 改为**按贴图来源分流**（真素材 `LINEAR` / 占位贴图 `NEAREST`）；新增 `.gitattributes`（**按类型 / 目录**圈 LFS：源图/概念图 + 字体 + 音频；游戏内小图直存）；4 张 sprite 的 `.import` 打开 mipmaps 并关掉 `detect_3d` 自动有损压缩；`tests/test_data_layer.gd` 增加「JSON 里非空 `sprite_path` 必须能加载成 Texture2D」的断言。**10 条验证命令全过、主场景 900 帧 0 ERROR / 0 WARNING** |
| 2026-10-13 | **M15 角色 sprite 批次接入（4 敌人 + 3 职业，28 张）**：`data/enemies.json` 的 `brute` / `wisp` / `bone_lord`（`slime` 已接且本次换成真正的史莱姆美术）与 `data/professions.json` 三个职业的 `sprite_path`；`Profession` 增加 `sprite_path` 字段，`Player._refresh_sprite()` 在 `set_profession()` 里换图并**重算 `pixel_size`**（占位 64px / 真素材 128px，不重算尺寸差一倍）；`tests/test_data_layer.gd` 的素材断言扩展到职业。另修/记两条坑：**`Enemy` 必须先 `setup()` 再 `add_child()`**（否则静默退回占位贴图，已记入 `AGENTS.md` §3）、`--script` 入口脚本要用 `load()` 动态取类名（否则因依赖链引用 `Game` 而编译失败）。10 条验证命令全过、主场景 900 帧 0 ERROR / 0 WARNING；另跑真窗口截图确认四种敌人 + 主角精灵在游戏内正确渲染（图存 `tools/lora-compare/images/_game_shot_*.png`，不入库） |
| 2026-10-13 | **M15 技能图标接入（6 张 128²）**：新增 `tools/lora-compare/gen_icons.py`（E 模板 → 1024² 透明底 → 去 alpha 噪声地板 / 抠边 → 128²，拼装与网页端同源）；`SkillBar` 支持真图标（无图自动退回「技能名首字」占位）；`data/skills.json` 6 个 `icon` 全填；`test_data_layer.gd` 断言扩展到图标。另：**对比台编码器默认改指 nvfp4**（T-22 ①）、**A2 模板标记废弃**（i2i 结案）。10 条验证命令全过、900 帧 0 ERROR / 0 WARNING + 真窗口截图确认 |
| 2026-10-13 | **M7 挥砍手感（程序化，零素材）**：动作时长 0.18 → **0.30 s**（蓄力后撤 / 前冲 / 收势 + 挤压拉长），**伤害改到「挥出帧」结算**（+0.05 s 命中顿帧），弧光升级为**刀光扫过**（窄弧扫过整个扇形；360° 技能仍整片圆环），判定朝向出手瞬间锁定。逐帧动作方案留 **T-26**（A5 动作分镜表 + `crop_sheet.py --anim`）。10 条验证命令全过、900 帧 0 ERROR / 0 WARNING + 真窗口抓帧确认 |

