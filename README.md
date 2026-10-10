# Dreadmyst Clone（恐惧秘境 · 复刻原型）

参考独立游戏 **Dreadmyst**（2.5D 复古画风免费 MMO：魔兽式职业/属性加点 + 传奇式刷怪 + 暗黑式刷宝掉装）
制作的 **Godot 4 单机可玩原型**。

当前版本聚焦一件事：**能跑起来、能操作、能刷怪、能掉装备**。

- **渲染**：真 3D 空间 + 固定正交相机（俯角 -45°）+ billboard 精灵 —— 标准 2.5D 做法。
- **零外部素材**：贴图由代码逐像素生成（`SpriteFactory`），克隆工程即可运行。
- **数据驱动**：怪物 / 掉落 / 词条全在 `data/*.json`，加内容不改代码。

开发文档：[`docs/README.md`](docs/README.md)

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

# 2) 数据层自测：JSON 加载 / 装备生成 / 加权分布
godot --headless --path . --script res://tests/test_data_layer.gd

# 3) 3D 冒烟测试：实例化主场景跑 300 帧，清点实体与渲染节点
godot --headless --path . --script res://tests/test_smoke_3d.gd

# 4) 技能自测：施放 / 冷却拦截 / 360° 判定 / 转职 / 蓝量门槛
godot --headless --path . --script res://tests/test_skills.gd

# 5) 属性加点自测：加点 / 上限 / 满级 / 转职不重置 / 界面开关
godot --headless --path . --script res://tests/test_attributes.gd

# 6) 地城自测：进出地城 / 房间流 / 清房开门 / Boss / 奖励 / 边界还原
godot --headless --path . --script res://tests/test_dungeon.gd

# 7) 背包自测：入包 / 装备换装 / 分解 / 容量 / 一键换装 / 买卖 / 界面
godot --headless --path . --script res://tests/test_inventory.gd

# 8) 长时运行：覆盖刷怪 / 追击 / 攻击 / 受伤 / 掉落等路径
godot --headless --quit-after 900 --path . res://scenes/main.tscn
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
| 普攻（技能槽 0） | `空格` / `J` / 鼠标左键（可长按连击） |
| 大招（技能槽 1） | `2` / `E` |
| 强制施放普攻 | `1` / `Q` |
| 冲刺 | `Shift` / `K` |
| 切换职业（原型期） | `F1` 战士 / `F2` 法师 / `F3` 游侠 |
| 属性加点面板 | `C`（开关；面板内 `+1` / `+5` 按钮加点） |
| 交互（传送门） | `F`（靠近竞技场中央下方的传送门进入地城；地城内可原路返回） |
| 背包 / 商店 | `I` 或 `B`（背包页：装备对比 / 装备 / 分解 / 一键换装；商店页：购买 / 刷新货架） |

---

## 已实现的玩法

- **2.5D 渲染**：真 3D 空间（XZ 为地面、Y 为高度）+ 固定正交俯角相机（-45°）+ billboard 精灵；
  角色数值与 AI 逻辑仍以 `Vector2` 平面计算，只在读写位置时转 `Vector3`。
- **角色移动与朝向**：八向移动，技能方向跟随最后一次移动方向。
- **技能扇形判定**：范围 + 朝向夹角判定，无需配置碰撞层，行为可预测；180° 技能即 360° 全方位。
- **职业与技能（M7）**：3 职业（战士 / 法师 / 游侠）× 2 技能（普攻 + 大招），
  每个技能有独立冷却 / 耗蓝 / 伤害倍率 / 射程 / 扇角；蓝条回蓝、冷却倒计时、底部技能栏。
  数据全在 `data/professions.json` 与 `data/skills.json` —— 加职业 / 改数值不改代码。
  **数值为自设占位（原作官网 403），待资料校准。**
- **玩家属性体系**：攻击力 / 生命上限 / 护甲（递减减伤公式）/ 暴击率 / 移动速度 / 蓝量上限 / 回蓝，
  基数来自职业，再叠加属性点与装备词条。
- **属性加点（M8）**：每升 1 级得 5 点自由属性点，投入 力量 / 敏捷 / 智力 / 体力 / 精神，
  按 `data/attributes.json` 的 `per_point` 实时计入总属性；`C` 键开界面，支持 `+1` / `+5` 与满级上限，
  加点**不会**自动补血。**数值为自设占位，待原作资料校准。**
- **地城与 Boss（M10）**：竞技场传送门（`F`）进入「亡者地窖」——3 个房间依次刷怪，
  清空当前房间才会开门；**墙体带真实碰撞**（玩家与怪物都会被挡住，竞技场的矮墙只是装饰）；
  最后一间是 Boss 房（骸骨领主：免疫击退、专属大血条、HUD 顶部显示血条），
  击败后发通关奖励（金币 / 经验 / 保底稀有装备）并开启出口传送门。
  布局与数值全在 `data/dungeon.json` + `data/enemies.json`。**数值为自设占位，美术仍为程序化占位。**
- **背包 / 商店 / 装备对比（M11）**：24 格背包（容量在 `data/inventory.json`）。
  掉落**先进背包**，在 `I` 界面里与身上装备逐词条对比（绿 = 提升 / 红 = 变差）后决定穿上或分解；
  换下来的旧装备会回到背包；背包满了掉落才会自动分解。商店（同一界面的「商店」页签）
  按 `data/shop.json` 现生成货架，可购买并花金币刷新。**数值为自设占位，图标仍为程序化占位。**
- **敌人 AI**：按等级缩放数值、索敌追击、近身攻击、敌人之间简单排斥避免堆叠；Boss 免疫击退。
- **刷怪节奏**：随玩家等级提升场上敌人上限与刷怪数量。
- **掉落系统**：`LootTable` 按等级随机生成装备，含 5 部位 × 5 品质（普通→传说）。
- **拾取与装备**：走近自动拾取；更优装备自动穿上，较差的自动分解为金币。
- **成长系统**：击杀获得经验与金币，升级所需经验指数增长，HUD 实时反馈。
- **表现层**：血条、经验条、装备栏（品质配色）、漂浮伤害数字（暴击变金色）、事件提示。

---

## 目录结构

```
dreadmyst-retro/
├── project.godot                 # 工程配置（主场景 / 自动加载 / 渲染 / 窗口）
├── icon.svg                      # 工程图标
├── AGENTS.md                     # AI 协作约定（硬性规范 + 文档索引）
├── data/                         # 数据表（JSON，策划可改，不改代码）
│   ├── loot.json                 #   掉落表：掉率 / 部位权重 / 品质权重 / 名字池 / 词条公式
│   ├── enemies.json              #   敌人原型（3 种，含 sprite_path）
│   ├── professions.json          #   职业：基础属性 + 技能 id 列表（M7）
│   ├── skills.json               #   技能：冷却 / 耗蓝 / 倍率 / 射程 / 扇角（M7）
│   ├── attributes.json           #   属性：每点加成 / 上限 / 每级自由点数（M8）
│   ├── dungeon.json              #   地城：房间流布局 / 每房怪数 / Boss / 通关奖励（M10）
│   ├── inventory.json            #   背包：容量 + 卖出价公式（M11）
│   └── shop.json                 #   商店：货架 / 刷新价（M11）
├── scenes/
│   └── main.tscn                 # 唯一场景：根 Node3D，仅挂载 scripts/main.gd
├── scripts/
│   ├── main.gd                   # 入口：搭 3D 环境 / 正交相机 / 刷怪 / 事件接线
│   ├── core/
│   │   ├── event_bus.gd          # Autoload「Events」：全局信号总线
│   │   ├── game.gd               # Autoload「Game」：竞技场 / 等级 / 金币 / 输入映射 / 坐标转换
│   │   └── shop.gd               # class_name Shop：商店服务（货架 / 购买 / 刷新）（M11）
│   ├── data/
│   │   ├── gear_item.gd          # class_name GearItem：装备数据模型（部位 / 品质 / 词条）
│   │   ├── loot_config.gd        # class_name LootConfig：loot.json 加载器（含加权抽取）
│   │   ├── loot_table.gd         # class_name LootTable：掉落与随机词条生成
│   │   ├── enemy_archetype.gd    # class_name EnemyArchetype：敌人原型（数值公式 + 外观）
│   │   ├── enemy_registry.gd     # class_name EnemyRegistry：enemies.json 加载 + 加权抽取
│   │   ├── profession.gd         # class_name Profession：职业（基础属性 + 技能 id）（M7）
│   │   ├── profession_registry.gd # class_name ProfessionRegistry：professions.json 加载（M7）
│   │   ├── skill_def.gd          # class_name SkillDef：单技能定义（M7）
│   │   ├── skill_registry.gd     # class_name SkillRegistry：skills.json 加载 / 按 id 查询（M7）
│   │   ├── attribute_def.gd      # class_name AttributeDef：单属性定义（每点加成 / 上限）（M8）
│   │   ├── attribute_registry.gd # class_name AttributeRegistry：attributes.json 加载 / 加成汇总（M8）
│   │   ├── dungeon_def.gd        # class_name DungeonDef：地城布局（房间/门/Boss/奖励）（M10）
│   │   ├── dungeon_registry.gd   # class_name DungeonRegistry：dungeon.json 加载（M10）
│   │   ├── inventory_config.gd   # class_name InventoryConfig：背包容量 + 卖出价公式（M11）
│   │   └── shop_config.gd        # class_name ShopConfig：商店货架 / 刷新价加载（M11）
│   ├── actors/
│   │   ├── player.gd             # class_name Player：移动 / 冲刺 / 职业与技能 / 属性点 / 背包与装备
│   │   └── enemy.gd              # class_name Enemy：AI 追击攻击 / 受击 / 死亡
│   ├── world/
│   │   ├── arena_background.gd   # class_name ArenaBackground：3D 地面网格 + 边界 + 装饰
│   │   ├── arena_prop.gd         # class_name ArenaProp：装饰石头
│   │   ├── gear_pickup.gd        # class_name GearPickup：地面掉落物与拾取
│   │   ├── portal.gd             # class_name Portal：传送门（靠近提示 + F 交互）（M10）
│   │   ├── dungeon.gd            # class_name Dungeon：房间流 / 清房开门 / Boss 房 / 奖励（M10）
│   │   ├── dungeon_room.gd       # class_name DungeonRoom：单间房（3D 地面 + 碰撞墙 + 门洞）（M10）
│   │   ├── dungeon_door.gd       # class_name DungeonDoor：房间之间的门（清房后开）（M10）
│   │   └── sprite_factory.gd     # class_name SpriteFactory：程序化占位贴图 / 网格工厂
│   └── ui/
│       ├── hud.gd                # class_name HUD：血条 / 蓝条 / 职业 / 经验 / 金币 / 装备栏 / 提示
│       ├── skill_bar.gd          # class_name SkillBar：底部技能栏（冷却 + 耗蓝 + 快捷键）（M7）
│       ├── attribute_panel.gd    # class_name AttributePanel：属性加点界面（C 键开关）（M8）
│       ├── inventory_panel.gd    # class_name InventoryPanel：背包 / 商店界面（I 键开关）（M11）
│       ├── damage_number.gd      # class_name DamageNumber：Label3D 漂浮伤害数字
│       └── dev_pause.gd          # class_name DevPause：开发用暂停面板（DEV_TOOLS 开关）
├── tests/                        # headless 自测（命令见 docs/architecture.md §6）
│   ├── test_data_layer.gd        #   数据层：JSON 加载 / 装备生成 / 职业技能 / 加权分布
│   ├── test_smoke_3d.gd          #   3D 冒烟：实例化主场景跑 300 帧
│   ├── test_input_move.gd        #   输入链路诊断：按键 → 动作 → 移动
│   ├── test_skills.gd            #   技能：施放 / 冷却 / 360° 判定 / 转职 / 蓝量门槛（M7）
│   ├── test_attributes.gd        #   属性：加点 / 上限 / 满级 / 转职不重置 / 界面开关（M8）
│   ├── test_dungeon.gd           #   地城：进出 / 房间流 / 清房开门 / Boss / 奖励 / 边界还原（M10）
│   └── test_inventory.gd         #   背包：入包 / 换装 / 分解 / 容量 / 一键换装 / 买卖（M11）
├── assets/                       # 美术素材；_LICENSES.md / _PROMPTS.md 为出图登记与模板
└── docs/                         # 文档体系（索引见 docs/README.md）
```

### 三点设计说明

1. **场景文件极简，节点用代码构建。** `main.tscn` 只有一个 `Node3D`，其余角色、掉落物、HUD
   都用 `class_name` 在脚本里实例化。这样场景文件不会因为手工编辑而损坏，逻辑集中易读。
2. **模块间只通过 `Events` 信号通信。** 玩家、敌人、掉落物、HUD 互不直接引用，
   后续替换任意一块（比如把 HUD 换成正式 UI 场景）不会级联改代码。
3. **零外部美术资源。** 角色 / 地面 / 特效的贴图由 `SpriteFactory` 用 `Image` 逐像素生成。
   接入真美术时只需在 `data/enemies.json` 填 `sprite_path`，渲染代码一行都不用改。

---

## 后续规划（Roadmap）

按 Dreadmyst 的玩法深度，建议的扩展顺序：

- [x] **技能系统**：3 职业 × 2 技能，各自冷却 + 蓝条 + 技能栏（M7）。
- [x] **职业**：战士 / 法师 / 游侠，不同初始属性与技能（M7）。
- [x] **属性加点**：升级给自由属性点，玩家自行分配（对应 Dreadmyst 的 stat points）（M8）。5 属性（力量/敏捷/智力/体力/精神），`C` 键加点界面，数值在 `data/attributes.json`。
- [ ] **职业选择 UI**：当前是原型期 `F1`/`F2`/`F3` 硬切。
- [x] **地下城（Dungeon）**：房间流程（清房开门）+ Boss 房 + 通关奖励 + 传送门进出（M10）。布局在 `data/dungeon.json`，Boss 数值在 `data/enemies.json`。
- [x] **背包与交易**：24 格背包、逐词条装备对比、一键换装、金币商店（购买 / 刷新）（M11）。
  背包容量与价格在 `data/inventory.json` / `data/shop.json`。
- [ ] **背包与交易**：多格背包、装备对比 tooltip、金币商店。
- [ ] **PVP 区域**：玩家之间的对抗场景。**暂不做**（单机原型没有第二个玩家，等联机之后再说）
- [x] **数据驱动**：掉落表抽到 `data/loot.json`（`LootConfig`），敌人原型抽到 `data/enemies.json`（`EnemyArchetype` + `EnemyRegistry`），含 3 种原型（粘液怪/重甲兽人/幽影）。新增敌人/词条/名字池 = 改 JSON，不改代码。
- [x] **2.5D 渲染**：由 2D 重构为真 3D + 固定正交俯角相机 + billboard 精灵，数据层零改动（详见 `docs/modules/render3d.md` 与 `docs/roadmap.md` 的 M9 迁移记录）。
- [ ] **存档**：`user://` 序列化角色等级、属性点、背包、装备与金币 ← *下一步（M13）*。
- [ ] **联机**：Godot 高层多人 API（ENet）实现客户端-服务器同步。

---

## 常见问题

- **运行后黑屏/无敌人**：确认主场景为 `res://scenes/main.tscn`，且自动加载 `Events`、`Game` 均已启用。
- **没有伤害数字/血条不动**：检查 `Events` 自动加载是否生效（信号总线被禁用会导致全部 UI 失效）。
- **命令行报 `Could not find type "XXX"`**：`.godot/` 缓存未生成，先执行 `godot --headless --import --path .`，见上文「方式二」。
- **终端里敲 `godot` 提示找不到命令**：PATH 改动对**已经打开**的终端不生效，开一个新终端再试。
- **在终端里运行 `godot.exe` 却看不到任何输出**：用 `godot_console.exe`，标准版 exe 不带控制台。
