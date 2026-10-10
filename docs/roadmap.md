# Roadmap 与变更记录

## Roadmap（未完成，按优先级）

- [x] **M7 职业与技能系统**：3 职业（战/法/游）+ 6 技能 + 冷却/蓝条 + 技能栏。
  **代码完成；数值为自设占位，待原作资料校准**。详见 [modules/skills.md](modules/skills.md)
- [x] **M8 属性加点**：升级给自由属性点（5 属性 + 加点界面）。
  **代码完成；数值为自设占位，待原作资料校准**。详见 [modules/attributes.md](modules/attributes.md)
- [ ] **M10 地城与 Boss**：房间流 + Boss 战 ← *当前最高优先级*
- [ ] **M11 背包与交易**：多格背包、装备对比、商店
- [ ] **M12 PVP 区域**
- [ ] **M13 存档**：`user://` 序列化等级/装备/金币
- [ ] **M14 联机**：ENet 客户端-服务器
- [ ] **M15 素材接入**：真实 sprite（`sprite_path`）/ 中文字体 / 音频  
  ↳ 出图任务卡片见 [`docs/tasks/`](tasks/)；完整方案见 [`docs/reference/ai-asset-generation.md`](reference/ai-asset-generation.md)
- [ ] **M16 相机微调**：`CAMERA_ORTHO_SIZE` 与俯角目视校准、滚轮缩放、视角旋转

## 待用户提供的信息

1. **职业列表与技能数据**：名字 / 冷却 / 耗蓝 / 伤害公式（M7 开工前必须）
2. **原作数值曲线**：官网 403 无法访问，当前全为自设
3. **角色/怪物 sprite 图**：填进 `enemies.json` 的 `sprite_path` 即生效，无需改代码
4. **中文字体** `.ttf`（HUD 与伤害数字当前用引擎回退字体，有显示异常风险）
5. **地城/区域规划**：几个区域、连接方式、Boss 机制
6. **属性公式**：5 个属性的每点加成、每级自由点数、是否有职业系数（M8 开工后拿到资料即可只改 `data/attributes.json`）

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
