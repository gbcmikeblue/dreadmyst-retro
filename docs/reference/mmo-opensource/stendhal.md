# Stendhal 开发参考

> 仓库：<https://github.com/arianne/stendhal>（GPL）· 官网 <https://stendhalgame.org>
> 定位：Arianne 项目旗下、自 2000 年代持续运营至今的完整开源 2D MMORPG（俯视角 + 斜 45° 混合视觉）。
> 参考价值：**如何工程化地组织海量游戏内容（地图/NPC/任务/物品）**，以及经典 MMO 网络同步模型。

---

## 1. 项目概览

- **语言**：Java（客户端 Java2D 渲染；服务端基于同项目的 **Marauroa** 多人游戏框架）。
- **持久化**：H2（内嵌）/ MySQL。
- **内容量**：数百张地图（zone）、大量 NPC、100+ 个任务（quest）、完整的经济/装备/成就体系。
- **许可证**：GPL——**代码与素材用于学习参考没问题，但不能直接复制进 MIT/私有项目**。

玩法特色：完整任务链、阵营与好感度、地下城、家畜养殖、赌场小游戏、结婚系统、玩家房屋、NPC 交易经济、成就与公告牌。

## 2. 仓库结构

```
stendhal/
├── src/                          # Java 源码，按 games.stendhal.* 分包
│   ├── games/stendhal/client/    # 客户端：渲染、精灵动画、界面（hotkey/buddy/chat）
│   ├── games/stendhal/server/    # 服务端：权威逻辑
│   │   ├── core/engine/          # ★ StendhalRPRuleProcessor / zone 管理 / GenerateINI
│   │   ├── entity/               # 实体体系：player/creature/npc/item/portal
│   │   └── maps/                 # ★ 内容工程核心（见 §3）
│   │       ├── <world>/...       #   每张地图一个 Java 装配类（摆 NPC/门/出生点）
│   │       └── quests/           #   每个任务一个 Java 类（状态机）
│   ├── games/stendhal/common/    # 两端共享：消息、常量、工具
│   └── games/stendhal/tools/     # 数据校验/翻译/管理工具
├── data/
│   ├── conf/                     # ★ 物品/怪物/种族等 XML 定义（见 §4）
│   ├── maps/                     # Tiled (TMX) 地图文件
│   ├── sprites/                  # ★ 全部角色/物品/效果精灵图（PNG）
│   ├── tileset/                  # ★ 地形 tileset（32×32 基准，含斜视角 tile）
│   └── script/                   # 历史遗留的 Groovy/Python 脚本位
├── tests/                        # 单元测试 + 内容校验测试（git submodule: matthew-testsuite）
└── build.xml / pom.xml           # Ant/Maven 双构建
```

## 3. 内容工程：值得重点研究的部分

### 3.1 "一张地图 = TMX 文件 + 一个装配类"

- 地形/碰撞画在 **Tiled TMX** 里（`data/maps/`）；
- 每张 zone 另有 `server/maps/<world>/<ZoneName.java>`：实例化 zone、摆放 NPC/传送门/刷怪点、注册对话条件；
- zone 之间通过 portal 实体连接，天然支持分层世界（地上/地下城/室内）。

**→ 对本项目的落地**：Godot 的 `.tscn` 场景本身就可当 "TMX+装配类" 用——**一个地下城/一张地图 = 一个场景 + 一个数据文件**（刷怪表、入口出口、区域标记），Roadmap 中的"地下城"应按此模式落地，而不是在 `main.gd` 里硬编码。

### 3.2 任务系统 = 状态机类

每个任务是 `server/maps/quests/` 下的独立 Java 类：定义"历史状态"（NOT_STARTED → FETCHING → DONE）、NPC 对话钩子、奖励。客户端只收到任务状态变化，不含任务逻辑。

**→ 对本项目的落地**：任务不要写成分支散在 NPC 代码里，而是独立 `Quest` 资源/类 + 状态枚举 + `Events` 信号驱动（本项目已有信号总线，天然适合：`enemy_killed` → 任务进度推进）。

### 3.3 NPC 对话与行为

NPC 由对话状态机（问候 → 选项 → 条件分支）+ 行为（巡逻/闲逛/售货）组成，数据与逻辑集中在装配类。交易经济（NPC 买/卖价差、供需）内置，可作为金币回收机制的参考。

## 4. 素材与数据文件规范

| 目录 | 内容 | 规范要点 |
| --- | --- | --- |
| `data/tileset/` | 地形 tileset | **32×32 基准 tile**；同时维护俯视角与斜 45°（2.5D 视觉）两套风格；按主题（草地/洞窟/室内/城市）分包 |
| `data/sprites/` | 全部实体精灵 | 命名约定严格：`<类型>-<名字>-<朝向>-<帧>.png`；4 向行走/攻击/死亡动画齐全；同一实体多张图即可拼装 |
| `data/conf/*.xml` | items/creatures/races 定义 | 属性（HP/攻防/抗性/掉落/经验）全部 XML 化，`<attributes>`/`<drops>` 标签 |
| `data/maps/*.tmx` | 地图 | 标准 Tiled 格式，碰撞与对象层走 layer 约定 |

要点：

1. **素材命名即协议**：换皮/加怪只需按命名规范扔图 + 改 XML，无代码改动；
2. **XML 内容数据库**与代码 Registry 分离（Godot 下对应：JSON/`.tres` 资源 + `Registry` autoload）；
3. 素材风格统一（社区长期打磨的卡通复古风），**本项目的"复古 2.5D"定位可直接参考其斜 45° tileset 的拼合方式**。

## 5. 网络同步模型（Marauroa）

经典 **回合制感知同步**，值得理解原理：

- 服务端以固定 **turn（约 300ms）** 节拍推进模拟；
- 客户端只发 **RPAction**（意图：移动/攻击/对话），不报告结果；
- 服务端每 turn 向客户端发送 **感知（Perception）增量**：新增/修改/删除视野内 RPObject；
- 客户端对实体做插值平滑，掩盖 300ms 节拍。

**→ 对本项目的落地**：Godot ENet 联机可采用同款思路——**客户端发意图、服务端权威 tick（如 20Hz 模拟 + 快照/增量同步）、客户端插值**。这比"每个节点 MultiplayerSynchronizer 同步属性"的朴素做法更抗作弊、更省带宽。Stendhal 证明了该模型能支撑 20 年的正式运营。

## 6. 快速上手

```bash
git clone https://github.com/arianne/stendhal
ant build          # 或用 Maven
ant run_server     # 服务端（首次运行 GenerateINI 生成 server.ini + 初始化数据库）
ant run_client     # 客户端
```

线上版可直接玩：<https://stendhalgame.org>（建议先玩 1-2 小时再读代码，体验其任务链设计）。

## 7. 与本项目 Roadmap 的对应关系

| 本项目 Roadmap | Stendhal 对应实现 | 借鉴动作 |
| --- | --- | --- |
| 地下城 | zone + portal + 地下城专属装配类 | 一地下城一场景一数据文件 |
| 背包与交易 | NPC 经济 + 商店 + 银行 | 买卖价差作为金币回收口 |
| 联机 | Marauroa turn + perception 增量 | 服务端固定 tick + 意图/快照协议 |
| 任务（Roadmap 未列但 Dreadmyst 有） | quests/ 状态机类 | Quest 状态机 + Events 信号驱动 |
| 2.5D 表现 | 斜 45° tileset 拼合 | tile 基准 32px，2.5D 用斜角地砖 + 俯视角色混排 |

## 8. 风险与注意

- **GPL 许可证**：只能学结构、抄思想，不能复制代码与素材到本项目；
- Java + XML 体系较重，内容装配是"每地图一个类"的纯代码方式，Godot 下应改为数据文件驱动（学其组织方式，简化其实现手段）；
- 项目已进入维护期，迭代慢，不必跟踪其最新提交。
