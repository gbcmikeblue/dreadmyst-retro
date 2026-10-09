# Intersect Engine 开发参考

> 仓库：<https://github.com/AscensionGameDev/Intersect-Engine>（MIT）· 官网 <https://www.freemmorpgmaker.com>
> 定位："2D MMORPG Maker"——客户端 + 权威服务器 + 可视化编辑器三件套的完整游戏开发套件，基于 MonoGame / .NET 8。
> 参考价值：**无代码内容管线（编辑器 + 事件系统）与对象数据库的标准组织方式**，社区活跃、文档完善。

---

## 1. 项目概览

- **技术栈**：C# / .NET 8；客户端与编辑器基于 **MonoGame**（客户端 DesktopGL 跨平台，编辑器 DirectX + WinForms）；网络层 LiteNetLib；数据 JSON。
- **产品形态**：解压即用的编辑器，"无需编程经验"即可做出完整 2D MMORPG——通过编辑器配置物品/NPC/技能/任务（事件系统）。
- **内置系统**：实时动作战斗（ABS）、背包/装备、银行、商店、合成、采集（资源点）、公会、好友/组队、任务事件系统、投射物与动画、昼夜/时间、PvP 区域、传送与门开关。
- **许可证**：MIT，且官方明确随引擎分发的素材"风格统一、可安全商用"。

## 2. 仓库结构（来自官方文档 Repository → File Structure）

| 目录 | 职责 |
| --- | --- |
| `Intersect (Core)` | **客户端/编辑器/服务端共享程序集**：游戏对象类定义（Item/Npc/Quest/Spell…）、配置、对象 ID 类型 |
| `Intersect.Shared` | 所有项目共享的辅助函数与基础信息 |
| `Intersect.Client.Framework` | 客户端抽象层：音频、文件、图形输出接口 + 深度改造的 **Gwen UI** 库 |
| `Intersect.Client` | 客户端实现（MonoGame DesktopGl，跨平台） |
| `Intersect.Editor` | **可视化编辑器**（MonoGame DirectX + WinForms，因 SwapChainRenderTargets 限 Windows） |
| `Intersect.Server` | **权威服务器**（控制台应用），游戏中一切行为由它裁决 |
| `Intersect.Tests.*` | 各项目单元测试 |
| `Documentation/` | 许可与文档入口 |

架构三原则（官方明确）：

1. **分层清晰**：Core/Shared（共享契约）→ Framework（抽象）→ Client/Editor/Server（实现）；
2. **服务器权威**（authoritative）：客户端永远只是表现；
3. **两端共享对象定义**：Item/Npc/Quest 等 POJO 在 Core 中定义，两端序列化一致。

**→ 对本项目的落地**：Godot 联机时应有对应的"共享层"——把 `GearItem`、`EnemyArchetype` 这类纯数据模型放进 `scripts/data/`（已是现状，保持），确保服务端/客户端可复用同一套定义；UI/渲染在客户端，模拟在服务端。

## 3. 值得借鉴的设计

### 3.1 编辑器 + 对象数据库管线

Intersect 的内容生产流程：

```
编辑器（表单填写）→ 对象数据库（resources 下 JSON：items/npcs/spells/quests/animations…）
                 → 地图数据（JSON，含图块层/对象层/事件层）
                 → 服务端与客户端各自读取同一份数据渲染/模拟
```

- 每类游戏对象是一个带 GUID 主键的 JSON 数据库，编辑器本质是"数据库表单 + 地图画板"；
- 地图自带**事件层**：格子上放"事件"，事件由命令列表（对话/给物品/开传送门/开关变量/战斗判定）组成——这就是其"无代码任务系统"。

**→ 对本项目的落地**：
- 我们已走"JSON + Registry"路线，对应其对象数据库；
- 缺的是**事件/任务命令的中间层**：Roadmap 的"背包与交易""地下城"之后接任务系统时，可借鉴"任务 = 事件命令序列 + 变量/开关"的模型，用 GDScript 数据类实现，避免每任务硬编码。

### 3.2 事件命令系统（无代码任务的核心）

事件命令是受限指令集（显示对话、给/取物品、设置变量、跳转条件、生成 NPC…），在服务端解释执行。收益：内容生产与引擎代码解耦，且天然防作弊（服务端解释）。

### 3.3 权威服务器细节

- 服务端为控制台应用，独立于客户端进程部署；
- 战斗/移动/掉落全部服务端裁决，客户端发意图；
- 服务端资源（`server/resources/`）与客户端资源（`resources/` 图形音频）分离——**服务端不需要美术**。

**→ 对本项目的落地**：Godot 做权威服务端时，服务器工程可不加载任何美术资源（headless 导出模板），数据层 JSON 两端共享一份仓库内路径。

## 4. 素材组织

发布包的 `resources/` 目录（客户端侧）：

```
resources/
├── animations/   # 帧动画（攻击特效、技能效果）
├── entities/     # 实体 spritesheet：player（含 paperdoll 分层）、npcs/monsters
├── images/       # 杂项图片（头像、过场）
├── items/        # 物品图标
├── fonts/  gui/  # UI 皮肤（Gwen 皮肤 XML）、字体
├── sounds/  music/
└── maps/         # （服务端侧）地图 JSON
```

要点：

1. **按对象类型分目录**，目录名即对象数据库的类别，编辑器按目录索引；
2. **实体用 paperdoll 分层**：身体/武器/护甲各是一层 sheet，运行时按装备叠画——"穿什么画什么"；
3. 官方素材风格统一且**明确允许商用**（MIT + 官方声明），可作为本项目引入正式美术前的**过渡素材来源**。

**→ 对本项目的落地**：paperdoll 分层对"掉装 + 穿装"玩法（本项目核心循环）价值极大——`GearItem` 已有部位字段，将来换正式美术时按 `身体/武器/护甲` 多层 spritesheet 组织，装备变化即换层，无需为每套装备画整图。

## 5. 快速上手

- 下载：<https://www.ascensiongamedev.com/files/>（解压即用，无需编译）；
- 先跑 `Client/Intersect Client.exe` + `Server/Intersect Server.exe`，再用 `Editor` 改一张地图、配一个 NPC 和任务，**1 小时内可体会完整内容管线**；
- 编译：VS 打开 `Intersect.sln`（.NET 8 SDK），产物在各自 bin 目录；文档 <https://docs.freemmorpgmaker.com>。

## 6. 与本项目 Roadmap 的对应关系

| 本项目 Roadmap | Intersect 对应实现 | 借鉴动作 |
| --- | --- | --- |
| 职业系统 | class + 初始属性/技能绑定 | 职业表 JSON：属性初值 + 技能白名单 |
| 背包与交易 | 背包/商店/银行 + 图标库 | 物品图标目录按类型归档 |
| 掉落穿装（已实现） | paperdoll 分层渲染 | 装备分层 spritesheet 规范 |
| 地下城 | 传送门 + 事件层 | 地图事件层：开关门/Boss 房触发 |
| 联机 | 权威服务端 + LiteNetLib 意图协议 | 服务端 headless、零美术依赖 |

## 7. 风险与注意

- 编辑器仅限 Windows（DirectX 限制），且是"引擎套件"而非"源码参考型游戏"——我们借鉴其**内容管线与数据组织**，而非照搬其编辑器实现；
- C#/MonoGame 与 Godot 无直接迁移关系，代码不搬，**搬规范**；
- 其默认美术为"复古像素 MMO 通用风"，与本项目的 2.5D 复古定位契合度高，过渡期可直接取用（注意 MIT 及各素材原始作者署名要求，发布前逐张核对）。
