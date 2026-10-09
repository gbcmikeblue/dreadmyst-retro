# Dreadmyst Clone（恐惧秘境 · 复刻原型）

参考独立游戏 **Dreadmyst**（2.5D 复古画风免费 MMO：魔兽式职业/属性加点 + 传奇式刷怪 + 暗黑式刷宝掉装）
制作的 **Godot 4 单机可玩原型**。

当前版本聚焦一件事：**能跑起来、能操作、能刷怪、能掉装备**。

---

## 运行方式

### 方式一：编辑器（推荐）

1. 安装 [Godot 4](https://godotengine.org/download)（标准版，无需 .NET 版）。
   工程按 **4.7** 声明，实测环境为 Godot 4.7.2；4.3+ 亦可打开。
2. 用 Godot 打开本目录下的 `project.godot`。
3. 按 `F5`（或点击右上角 ▶）运行。

> 首次打开时 Godot 会导入资源并生成 `.godot/` 缓存目录，属正常现象。
> 项目使用 `gl_compatibility` 渲染后端以兼容更多显卡。

### 方式二：命令行（用于快速验证 / CI）

```bash
# 1) 首次必须先导入：生成 .godot 缓存 + 全局类名注册表
godot --headless --import --path .

# 2) 冒烟测试：跑一帧后退出，任何脚本或运行时错误都会打到 stderr
godot --headless --path . --quit

# 3) 长时运行：覆盖刷怪 / 追击 / 攻击 / 受伤 / 掉落等路径
godot --headless --path . --quit-after 1200
```

Windows 上请用 `*_console.exe`，带控制台的版本才会往终端输出日志。

> **重要（克隆仓库后必读）**：如果直接跑命令行而不先执行第 1 步，会看到一堆
> `Parse Error: Could not find type "Player" ...`。这**不是代码错误**。
> Godot 的 `class_name` 全局类名缓存在 `.godot/global_script_class_cache.cfg`，
> 而 `.godot/` 被 gitignore 了，所以新克隆的仓库里没有这份缓存。
> 执行一次 `--import`（或用编辑器打开一次项目）即可生成。

---

## 操作说明

| 操作 | 按键 |
| --- | --- |
| 移动 | `W` `A` `S` `D` / 方向键 |
| 攻击（扇形挥砍） | `空格` / `J` / 鼠标左键（可长按连击） |
| 冲刺 | `Shift` / `K` |

---

## 已实现的玩法

- **角色移动与朝向**：八向移动，攻击方向跟随最后一次移动方向。
- **扇形攻击判定**：范围 + 朝向夹角判定，无需配置碰撞层，行为可预测。
- **玩家属性体系**：攻击力 / 生命上限 / 护甲（递减减伤公式）/ 暴击率 / 移动速度。
- **敌人 AI**：按等级缩放数值、索敌追击、近身攻击、敌人之间简单排斥避免堆叠。
- **刷怪节奏**：随玩家等级提升场上敌人上限与刷怪数量。
- **掉落系统**：`LootTable` 按等级随机生成装备，含 5 部位 × 5 品质（普通→传说）。
- **拾取与装备**：走近自动拾取；更优装备自动穿上，较差的自动分解为金币。
- **成长系统**：击杀获得经验与金币，升级所需经验指数增长，HUD 实时反馈。
- **表现层**：血条、经验条、装备栏（品质配色）、漂浮伤害数字（暴击变金色）、事件提示。

---

## 目录结构

```
dreadmyst-1/
├── project.godot                 # 工程配置（主场景 / 自动加载 / 渲染 / 窗口）
├── icon.svg                      # 工程图标
├── scenes/
│   └── main.tscn                 # 唯一场景：仅挂载 scripts/main.gd
└── scripts/
    ├── main.gd                   # 入口：搭世界、生成玩家、刷怪、掉落、伤害数字
    ├── core/
    │   ├── event_bus.gd          # Autoload「Events」：全局信号总线
    │   └── game.gd               # Autoload「Game」：竞技场范围 / 等级 / 金币 / 输入映射
    ├── data/
    │   ├── gear_item.gd          # class_name GearItem：装备数据模型（部位/品质/词条）
    │   └── loot_table.gd         # class_name LootTable：掉落与随机词条生成
    ├── actors/
    │   ├── player.gd             # class_name Player：移动 / 冲刺 / 攻击 / 装备加成
    │   └── enemy.gd              # class_name Enemy：AI 追击攻击 / 受击 / 死亡
    ├── world/
    │   ├── arena_background.gd   # class_name ArenaBackground：地面网格 + 边界 + 装饰
    │   ├── arena_prop.gd         # class_name ArenaProp：装饰石头
    │   └── gear_pickup.gd        # class_name GearPickup：地面掉落物与拾取
    └── ui/
        ├── hud.gd                # class_name HUD：血条 / 经验 / 金币 / 装备栏 / 提示
        └── damage_number.gd      # class_name DamageNumber：漂浮伤害数字
```

### 两点设计说明

1. **场景文件极简，节点用代码构建。** `main.tscn` 只有一个 `Node2D`，其余角色、掉落物、HUD
   都用 `class_name` 在脚本里实例化。这样场景文件不会因为手工编辑而损坏，逻辑集中易读。
2. **模块间只通过 `Events` 信号通信。** 玩家、敌人、掉落物、HUD 互不直接引用，
   后续替换任意一块（比如把 HUD 换成正式 UI 场景）不会级联改代码。
3. **零外部美术资源。** 所有角色与地面都用 `_draw()` 绘制，克隆工程即可运行。

---

## 后续规划（Roadmap）

按 Dreadmyst 的玩法深度，建议的扩展顺序：

- [ ] **技能系统**：多技能 + 冷却 + 蓝条，替换当前单一普攻（对应"混合能力流派"）。
- [ ] **属性加点**：升级给自由属性点，玩家自行分配（对应 Dreadmyst 的 stat points）。
- [ ] **职业**：战士 / 法师 / 游侠等，不同初始属性与技能树。
- [ ] **地下城（Dungeon）**：独立场景 + 房间流程 + Boss。
- [ ] **背包与交易**：多格背包、装备对比 tooltip、金币商店。
- [ ] **PVP 区域**：玩家之间的对抗场景。
- [x] **数据驱动**：掉落表抽到 `data/loot.json`（`LootConfig`），敌人原型抽到 `data/enemies.json`（`EnemyArchetype` + `EnemyRegistry`），含 3 种原型（粘液怪/重甲兽人/幽影）。新增敌人/词条/名字池 = 改 JSON，不改代码。数据层自测：`godot --headless --path . --script res://tests/test_data_layer.gd`。
- [ ] **存档**：`user://` 序列化角色等级、装备与金币。
- [ ] **联机**：Godot 高层多人 API（ENet）实现客户端-服务器同步。

---

## 常见问题

- **运行后黑屏/无敌人**：确认主场景为 `res://scenes/main.tscn`，且自动加载 `Events`、`Game` 均已启用。
- **没有伤害数字/血条不动**：检查 `Events` 自动加载是否生效（信号总线被禁用会导致全部 UI 失效）。
- **命令行报 `Could not find type "XXX"`**：`.godot/` 缓存未生成，先执行 `godot --headless --import --path .`，见上文「方式二」。
- **终端里敲 `godot` 提示找不到命令**：PATH 改动对**已经打开**的终端不生效，开一个新终端再试。
- **在终端里运行 `godot.exe` 却看不到任何输出**：用 `godot_console.exe`，标准版 exe 不带控制台。
