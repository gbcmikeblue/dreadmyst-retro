# Dreadmyst 复刻项目 · 开发文档中心

> 参考游戏：**Dreadmyst**（2.5D 复古风免费 MMO，WoW 式职业属性 + 传奇式刷怪 + 暗黑式掉装）
> 本项目是其**单机可玩原型**。原作官网已 403，数值为自行设计，待补充原作资料后校准。

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [architecture.md](architecture.md) | 架构约定、目录结构、数据驱动模式、2.5D 预留、验证方式 |
| [modules/core.md](modules/core.md) | 自动加载：Game 全局状态、Events 事件总线、输入映射 |
| [modules/combat.md](modules/combat.md) | 玩家（移动/攻击/冲刺/装备加成）与敌人 AI |
| [modules/loot.md](modules/loot.md) | 装备模型、掉落表、词条公式、敌人原型数据层 |
| [modules/world.md](modules/world.md) | 竞技场、背景、装饰、掉落物拾取 |
| [modules/ui.md](modules/ui.md) | HUD、漂浮伤害数字、Toast 提示 |
| [roadmap.md](roadmap.md) | Roadmap、待用户提供的信息、变更记录 |
| [reference/mmo-opensource/](reference/mmo-opensource/) | 开源 MMO 参考研究：Kaetram-Open / Stendhal / Intersect Engine 的结构与素材分析，作为开发规范与参考 |

## 项目信息速查

| 项 | 值 |
| --- | --- |
| 引擎 | Godot 4.7.2 stable（`gl_compatibility`） |
| 语言 | GDScript（静态类型） |
| 美术 | 零外部素材，全部 `_draw()` 绘制 |
| 主场景 | `res://scenes/main.tscn`（极简，节点代码构建） |
| 目标画风 | 2D 斜俯视（伪 2.5D），当前正交俯视 |
| 运行 | 编辑器 F5 / `godot --path .`；验证命令见 architecture.md §5 |

## 当前进度（2026-10-09）

| 里程碑 | 状态 | 说明 |
| --- | --- | --- |
| M0 工程骨架 | ✅ | 配置、事件总线、输入映射 |
| M1 玩家 | ✅ | 移动/扇形攻击/冲刺/装备加成/复活 |
| M2 敌人 AI | ✅ | 追击/攻击/受击/死亡，3 种原型 |
| M3 掉落系统 | ✅ | 5 部位 × 5 品质 × 5 词条，JSON 驱动 |
| M4 HUD | ✅ | 血条/经验/金币/装备栏/伤害数字 |
| M5 数据驱动 | ✅ | loot.json + enemies.json，加内容不改代码 |
| M6 工程规范 | ✅ | 专属 skill + 文档体系 |
| M7 职业与技能 | ⬜ | ← 下一步 |
| M8+ | ⬜ | 见 roadmap.md |

详细进度与变更记录：[roadmap.md](roadmap.md)
