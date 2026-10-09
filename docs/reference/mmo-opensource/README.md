# 开源 2D/2.5D MMORPG 参考研究

> 本文件夹是对 GitHub 上三个综合最优秀的开源 2D/2.5D MMORPG 项目的结构与素材分析，
> 作为 Dreadmyst Clone（Godot 4）后续开发（尤其是 Roadmap 中的技能、背包、地下城、联机）的规范与参考。

## 三个项目与入选理由

| 维度 | Kaetram-Open | Stendhal | Intersect Engine |
| --- | --- | --- | --- |
| 仓库 | [Kaetram/Kaetram-Open](https://github.com/Kaetram/Kaetram-Open) | [arianne/stendhal](https://github.com/arianne/stendhal) | [AscensionGameDev/Intersect-Engine](https://github.com/AscensionGameDev/Intersect-Engine) |
| 技术栈 | TypeScript + Node.js + WebSocket + MongoDB | Java + Marauroa 框架 | C# / .NET 8 + MonoGame |
| 形态 | 浏览器 2D 俯视角 MMORPG（BrowserQuest 后继者） | 完整成熟的 2D 俯视角/斜 45° MMORPG | 客户端 + 权威服务器 + 可视化编辑器三件套 |
| 亮点 | 现代 TS monorepo、数据驱动、跨服 Hub、Discord 集成 | 20+ 年持续维护、300ms 回合制同步、100+ 任务、素材库庞大 | 无代码可做完整 MMORPG、事件系统、活跃社区 |
| 对本项目的价值 | 联机架构与数据驱动 JSON 设计的最佳范本 | 任务/NPC/区域内容工程化与网络同步模型 | 编辑器思路、对象数据库（items/npcs/quests）组织 |
| 许可证 | MIT | GPL | MIT |

## 为什么是这三个

在 GitHub 上检索 "2D/2.5D MMORPG" 相关主题（`mmorpg-engine`、`tileset`、`browserquest` 等）后，综合以下标准筛选：

1. **完整性**：客户端 + 服务端 + 游戏内容三者齐备，能真正跑起来，而非半成品引擎。
2. **活跃度与成熟度**：有持续维护或长期积累（Stendhal 2000 年至今，Intersect 社区活跃，Kaetram 仍在迭代）。
3. **可借鉴性**：技术栈和设计模式对我们有直接参考意义（数据驱动、权威服务器、素材规范）。
4. **素材可用性**：三者均自带成体系的美术素材，且许可证允许二次使用。

## 文档列表

- [Kaetram-Open 开发参考](./kaetram-open.md) —— 现代客户端/服务端架构范本
- [Stendhal 开发参考](./stendhal.md) —— 内容工程与网络同步模型范本
- [Intersect Engine 开发参考](./intersect-engine.md) —— 无代码内容管线与编辑器范本

## 三者共同的设计原则（可直接作为本项目规范）

1. **权威服务器（Authoritative Server）**：碰撞、伤害、掉落全部在服务端判定，客户端只做表现。对应本项目的联机 Roadmap：`Enemy`/`LootTable` 逻辑需与表现层解耦（当前 `main.gd` 承担了部分权威逻辑，联机前应抽成独立的模拟层）。
2. **数据与代码分离**：怪物、物品、技能、任务全部是 JSON/XML 数据文件 + Registry 加载，新增内容不改代码。本项目已有的 `data/enemies.json`、`loot.json` 方向正确，应扩展到技能、职业、地下城。
3. **区块化地图（Region/Chunk）**：三个项目都把大地图切分为区块，用于渲染裁剪与网络兴趣管理（AOI），是 2D MMO 的标准做法。
4. **统一的素材规范**：固定 tile 尺寸（Kaetram 16px、Stendhal 32px）、统一 spritesheet 打包与 manifest 索引、命名约定统一。
5. **协议先行**：客户端/服务端共享包定义（Kaetram 的 packets 模块、Intersect 的共享程序集、Marauroa 的 RPAction），两端类型一致，减少同步 bug。

## 阅读建议

- 只关心联机怎么做 → 先读 Kaetram-Open。
- 关心怎么做大量任务/NPC/地图内容 → 先读 Stendhal。
- 关心怎么做编辑器和内容管线 → 先读 Intersect Engine。
