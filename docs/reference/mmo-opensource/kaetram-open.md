# Kaetram-Open 开发参考

> 仓库：<https://github.com/Kaetram/Kaetram-Open>（MIT）
> 定位：开源 2D HTML5 MMORPG，BrowserQuest（Mozilla，2012）的精神续作，完全重写为现代 TypeScript。
> 参考价值：**目前最值得借鉴的轻量级客户端/服务端 MMO 全栈架构**，与本项目计划用 Godot 高层多人 API 自建服务器思路高度吻合。

---

## 1. 项目概览

- **客户端**：TypeScript + 自研 Canvas 渲染器（不用 Phaser），webpack 打包，浏览器运行。
- **服务端**：Node.js + TypeScript，WebSocket（`ws`）通信，**MongoDB** 持久化，**Redis** 做跨服通信。
- **Hub 服务器**：可选的中央服务器，负责多游戏服务器互联、跨服公会/聊天，是"迷你大区网关"的极简实现。
- **许可证**：MIT，代码与素材均可自由二次使用。

核心玩法系统：战斗与技能、PvP 区域、公会、组队、银行/商店/背包、掉落与稀有度、附魔（Enchants）、职业（Professions）、成就系统、 chests/doors 等交互物、NPC 对话、Discord 机器人双向集成（游戏内聊天 ↔ Discord 频道）。

## 2. 仓库结构（monorepo，npm workspaces）

```
Kaetram-Open/
├── packages/
│   ├── client/              # 浏览器客户端
│   │   ├── src/
│   │   │   ├── entity/      # 实体：player / mob / npc / projectile 等
│   │   │   ├── renderer/    # 自研 Canvas 渲染（sprite 批处理、图层）
│   │   │   ├── region/      # 区块：按 chunk 划分地图，渲染裁剪 + 动画调度
│   │   │   ├── input/       # 键鼠输入、点击移动、触屏适配
│   │   │   ├── audio/       # WebAudio 封装
│   │   │   ├── network/     # WebSocket 连接、包编解码
│   │   │   ├── ui/          # HUD：背包/装备/技能/商店/聊天等 DOM UI
│   │   │   └── ...
│   │   └── assets/          # 全部美术素材（见 §4）
│   ├── server/              # 游戏服务器（权威端）
│   │   ├── src/
│   │   │   ├── network/     # packets 定义 + 连接管理（两端共享包类型）
│   │   │   ├── entity/      # 权威实体逻辑：移动/碰撞/战斗/AI/掉落
│   │   │   ├── world/       # 地图加载、区域（PvP/音乐/关卡）划分
│   │   │   ├── plugins/     # 可插拔系统（Discord bot、minigames 等）
│   │   │   └── ...
│   │   ├── data/            # ★ 数据驱动核心：*.json
│   │   ├── maps/            # Tiled 导出的地图 JSON
│   │   └── ...
│   └── hub/                 # 跨服 Hub 服务器（公会/聊天中继）
├── packages/…（shared 类型）
└── package.json             # workspaces + 脚本
```

### 关键分层

- **客户端**只做表现：插值移动、动画播放、本地输入预测式的即时反馈，所有碰撞/伤害由服务端计算后广播。
- **服务端权威**：README 明确"服务端掌握绝大部分信息，计算碰撞、tile 数据与区域（PvP、音乐等）"。
- **packets 是契约**：客户端与服务端共享同一套包定义（`network/`），新增功能先定义包再写两端逻辑。

## 3. 值得借鉴的架构设计

### 3.1 Region/Chunk 区块系统

- 地图按 chunk（如 16×16 tile）切分，客户端只渲染视口内 chunk；
- 服务端同样按 chunk 做兴趣管理（AOI）：只向玩家广播其所在及相邻 chunk 的实体变化；
- 地图数据从 **Tiled 编辑器导出 JSON**（支持 image collection 与多 tileset），服务端解析出碰撞层与区域层。

**→ 对本项目的落地**：联机版应把 `arena` 换成 chunk 化的 `World`，刷怪/AI/掉落按 chunk 管理；即使单机，chunk 化也能为将来大型地图的渲染裁剪打基础。

### 3.2 数据驱动内容（server/data/*.json）

所有游戏内容由 JSON 描述，代码只写通用加载/解释器：

- `items.json` / `weapons` / `armor`…：物品、词条、数值、商店价格；
- `mobs.json` / `npcs.json`：怪物 AI 行为参数、掉落表引用、NPC 对话树；
- `abilities.json`：技能数值、冷却、类型；
- `achievements.json`、`enchants.json`、`shops.json` 等。

**→ 对本项目的落地**：扩展 `data/` 目录规范——技能/职业/地下城均走 JSON + `Registry` 模式（本项目 `EnemyRegistry` 已有雏形），保证"新增内容 = 加数据文件"。

### 3.3 可插拔插件系统

Discord 集成、小游戏等作为 `plugins/` 独立模块挂在服务端生命周期上，核心循环不感知。借鉴：把"活动类"玩法（节日、小游戏）做成可选插件而非硬编码。

### 3.4 Hub 跨服架构

单进程 → 多游戏服务器 + 一个 Hub：Redis 发布订阅中继公会/聊天/玩家列表。证明了"先单服跑通，再横向扩展"的低成本路径——第一版联机完全不需要考虑这个，但包协议设计时留好 `serverId` 字段即可。

## 4. 素材组织（assets）

```
client/assets/
├── tilesets/      # 地形 tileset（Liberated Pixel Cup 风格，16×16 基准）
├── sprites/       # 角色/怪物/武器 spritesheet（含 4/8 向行走 + 攻击帧序列）
├── ui/            # 界面九宫格、图标
├── audio/         # BGM + 音效
└── manifest/      # ★ 素材清单：把散图分组打包成逻辑 spritesheet 的描述文件
```

要点：

1. **基准 tile 16×16**，spritesheet 用 **行列网格 + JSON 索引**（帧名 → 坐标/尺寸），而非散图文件——浏览器加载与 Canvas 绘制都走 sheet；
2. **manifest 驱动**：帧动画（idle/walk/attack/death）、朝向都写在数据文件里，渲染器只认数据；
3. 素材风格统一（社区 LPC 生态，兼容大量免费扩展素材）。

**→ 对本项目的落地**：~~当前项目用 `_draw()` 程序化绘制~~（**已过期**：M9 起是真 3D + billboard，
见 [`../../modules/render3d.md`](../../modules/render3d.md)）；引入正式美术后应沿用该规范：
- 统一基准 tile（**2026-10-10 起定为 64×64**，非像素风；原"32×32 或 16×16 的整数倍"作废）；
- `assets/` 按 `tilesets / sprites / ui / audio / manifest` 分层；
- 动画帧序列数据化（Godot 中即 `SpriteFrames` 资源或 JSON → 生成）。

## 5. 快速上手

```bash
git clone https://github.com/Kaetram/Kaetram-Open
npm install            # workspaces 一次性装齐
# 需本地 MongoDB；Redis 为可选（仅跨服功能需要）
cd packages/server && npm run start    # 起服务端
cd packages/client && npm run start    # webpack dev server，浏览器打开
```

## 6. 与本项目 Roadmap 的对应关系

| 本项目 Roadmap | Kaetram 对应实现 | 借鉴动作 |
| --- | --- | --- |
| 技能系统 | `abilities.json` + 服务端冷却/判定 | 技能表 JSON 化，含冷却/耗蓝/伤害公式 |
| 背包与交易 | 背包/商店/银行三件套 + `shops.json` | 先背包后商店，物品统一走 `items.json` |
| PVP 区域 | 地图区域层标记 PvP | 区域作为地图数据的属性层 |
| 联机（ENet） | WebSocket + packets + 权威服务端 | 包协议先行；碰撞/伤害/掉落留在服务端；chunk 化 AOI |
| 公会/聊天（远期） | guilds + Hub + Discord bot | 协议留 `serverId`，逻辑后置 |

## 7. 风险与注意

- Kaetram 仍在持续重写中（develop 分支），模块细节可能变动，参考**分层思想**而非逐行照抄；
- MongoDB/Redis 是其技术选型，Godot 联机场景下可用 SQLite/JSON 存档替代，不必照搬；
- 其自研 Canvas 渲染器性能上限低于 Godot，渲染层无需借鉴，**重点借鉴网络与数据层**。
