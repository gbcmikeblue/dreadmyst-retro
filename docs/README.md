# Dreadmyst 复刻项目 · 开发文档中心

> 参考游戏：**Dreadmyst**（2.5D 复古风免费 MMO，WoW 式职业属性 + 传奇式刷怪 + 暗黑式掉装）
> 本项目是其**单机可玩原型**。原作官网已 403，数值为自行设计，待补充原作资料后校准。

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [architecture.md](architecture.md) | 架构约定、目录结构、玩法平面转换、数据驱动、验证方式、陷阱备忘 |
| [modules/render3d.md](modules/render3d.md) | **2.5D 渲染**：正交固定相机、billboard 精灵、程序化占位美术、接入真 sprite |
| [modules/core.md](modules/core.md) | 自动加载：Game 全局状态、Events 事件总线、坐标转换、输入映射 |
| [modules/combat.md](modules/combat.md) | 玩家（移动/技能/冲刺/装备加成）与敌人 AI |
| [modules/skills.md](modules/skills.md) | **职业与技能（M7）**：3 职业 / 6 技能 / 冷却与蓝条 / 扇形判定 / 技能栏；**数值为自设占位待校准** |
| [modules/attributes.md](modules/attributes.md) | **属性加点（M8）**：5 属性 / 每点加成 / 每级点数 / 满级上限 / 加点界面；**数值为自设占位待校准** |
| [modules/loot.md](modules/loot.md) | 装备模型、掉落表、词条公式、敌人原型数据层 |
| [modules/dungeon.md](modules/dungeon.md) | **地城与 Boss（M10）**：房间流 / 清房开门 / 真墙体碰撞 / Boss 房 / 通关奖励 / 进出流程；**数值为自设占位待校准** |
| [modules/inventory.md](modules/inventory.md) | **背包 / 商店 / 装备对比（M11）**：容量的数据驱动、卖出价公式、换装回包、商店货架与购买；**数值为自设占位待校准** |
| [modules/world.md](modules/world.md) | 竞技场（3D 地面/矮墙/岩石）、掉落物拾取 |
| [modules/ui.md](modules/ui.md) | HUD、`Label3D` 伤害数字、Toast |
| [roadmap.md](roadmap.md) | Roadmap、待补信息、里程碑、M9 迁移记录、变更记录 |
| [reference/ai-asset-generation.md](reference/ai-asset-generation.md) | **AI 资产生图方案**：Forge + SD 1.5/SDXL + 8GB 显存纪律 + 版权登记 |
| [reference/mmo-opensource/](reference/mmo-opensource/) | 开源 MMO 参考研究：Kaetram-Open / Stendhal / Intersect Engine 的结构与素材分析 |
| [tasks/](tasks/) | **出图任务卡片**（M7 / M8 / M10 / M11 / M14）：每个里程碑的可执行出图清单 + Prompt + 验收 |

## 项目信息速查

| 项 | 值 |
| --- | --- |
| 引擎 | Godot 4.7.2 stable（`gl_compatibility`） |
| 语言 | GDScript（静态类型） |
| 空间 | **真 3D**（XZ 为地面、Y 为高度），玩法逻辑仍在 Vector2 平面计算 |
| 视角 | **固定正交相机 + 俯角 -45°**（伪 2.5D） |
| 美术 | 零外部素材：`SpriteFactory` 逐像素生成占位贴图 |
| 主场景 | `res://scenes/main.tscn`（根 `Node3D`，节点代码构建） |
| 运行 | 编辑器 F5 / `godot --path .`；验证命令见 architecture.md §6 |

## 当前进度（2026-10-10）

| 里程碑 | 状态 | 说明 |
| --- | --- | --- |
| M0 工程骨架 | ✅ | 配置、事件总线、输入映射 |
| M1 玩家 | ✅ | 移动/扇形攻击/冲刺/装备加成/复活 |
| M2 敌人 AI | ✅ | 追击/攻击/受击/死亡，3 种原型 |
| M3 掉落系统 | ✅ | 5 部位 × 5 品质 × 5 词条，JSON 驱动 |
| M4 HUD | ✅ | 血条/经验/金币/装备栏/伤害数字 |
| M5 数据驱动 | ✅ | loot.json + enemies.json，加内容不改代码 |
| M6 工程规范 | ✅ | 专属 skill + 文档体系 |
| M9 2.5D 渲染 | ✅ | 真 3D + 固定正交相机 + billboard 精灵，数据层零改动 |
| M7 职业与技能 | ✅ 代码 | 3 职业（战/法/游）+ 6 技能 + 冷却/蓝条 + 技能栏；**数值为自设占位，待原作资料校准** |
| **M8 属性加点** | ✅ 代码 | 5 属性（力/敏/智/体/精）+ 每级 5 点 + 加点界面（C 键）；**数值为自设占位，待原作资料校准** |
| **M10 地城与 Boss** | ✅ 代码 | 3 房间 + 清房开门 + 真墙体碰撞 + Boss 房（骸骨领主）+ 通关奖励 + 传送门进出；**美术仍为程序化占位** |
| **M11 背包 / 商店 / 装备对比** | ✅ 代码 | 24 格背包（掉落入包 / 换装回包 / 分解）+ 装备对比 + 一键换装 + 商店（5 货架 / 购买 / 刷新）；`I` 键；**美术仍为程序化占位** |
| M12 PVP 区域 | ⚠️ 暂不做 | **单机原型没有第二个玩家可打**，等 M14 联机后再做（2026-10-10 决定） |
| M13 存档 | ⬜ | ← 下一步：`user://` 序列化等级 / 属性点 / 背包 / 装备 / 金币 |
| M11 背包 / 商店 / 交易 | ⬜ | 见 roadmap.md |
| M14 联机 | ⬜ | 见 roadmap.md |
