# 模块：背包 / 商店 / 装备对比（M11）

**代码**：`scripts/data/inventory_config.gd`、`shop_config.gd`、`scripts/core/shop.gd`、`scripts/ui/inventory_panel.gd`
**数据**：`data/inventory.json`、`data/shop.json`
**承载**：`scripts/actors/player.gd`（背包与装备的真实状态）、`scripts/ui/hud.gd`（背包占用）、`scripts/main.gd`（挂商店与界面）

> ⚠️ **容量、价格、卖出价系数都是自行设计的占位值**（原作官网 403）。改数值只改两个 JSON。
>
> 📌 出图任务卡 [`docs/tasks/M11-inventory.md`](../tasks/M11-inventory.md) 的 50 个图标 + 品质边框 + 商店 UI
> 是**后续的事**：本里程碑先做**背包 / 对比 / 商店的代码骨架**，图标仍是程序化占位
> （品质色边框 + 名字首字）。卡片里写的 `scripts/ui/inventory.gd` / `shop.gd` / `equip_compare.gd`
> **已合并**成 `inventory_panel.gd` 一个界面（背包 / 商店两个页签），对比就画在详情区，不单开浮窗。

## 1. M11 改掉了什么（重要行为变化）

**掉落不再自动穿 / 自动分解**：

| | M3 ~ M10 | M11 起 |
| --- | --- | --- |
| 拾取掉落 | 比身上强就自动穿，否则当场分解换金币 | **进背包**，玩家自己对比后决定 |
| 背包满了 | 不存在背包 | 掉落**当场自动分解**（掉落不会凭空消失） |
| 换装 | 自动覆盖，旧装备消失 | 换下来的旧装备**回到背包** |

所以 M11 之后「变强」的路径是：刷怪 → 拾取进包 → `I` 打开背包 → 看对比 → 装备 / 分解。

## 2. 数据模型

| 文件 | 类 | 职责 |
| --- | --- | --- |
| `data/inventory.json` | `InventoryConfig` | 背包容量 + 卖出价公式 |
| `data/shop.json` | `ShopConfig` | 刷新价 + 货架条目（部位 / 品质 / 等级 / 价格） |

### 卖出价放在数据层

```
卖出价 = max(min_sell_price, round(装备评分 × sell_price_per_power + 物品等级 × sell_price_per_level))
```

`InventoryConfig.sell_price_for(gear)` 是**唯一实现**：Player 用它加金币，背包界面用它显示
「分解 +N 金币」。两边都调数据层，所以不会出现「界面显示 12、实际只给 10」的漂移。

### 商店货架不是写死的装备

`shop.json` 的每条 offer 只写 `slot` / `rarity` / `item_level` / `price`，
生成货架时由 `LootTable.generate(item_level, rarity_key, slot_key)` **现生成**一件
（名字与词条随机）→ 商店卖的是「同款不同货」。

> ⚠️ 部位/品质必须在**生成时**指定，不能「先生成再改 `gear.slot`」——
> 名字池与词条公式是按部位取 `loot.json` 的 `stat_specs`，事后改 slot 会得到
> 「名字是战靴、词条是武器」的怪东西。`LootTable.generate()` 因此有三个参数。

## 3. Player 侧：背包与装备

| 方法 | 说明 |
| --- | --- |
| `backpack: Array[GearItem]` | 背包（真实状态，UI 只读它广播出来的副本） |
| `backpack_capacity()` / `backpack_full()` / `backpack_item(i)` | 查询 |
| `add_to_backpack(gear) -> bool` | 满则返回 false（调用方决定怎么办） |
| `equip_from_backpack(i) -> bool` | 穿上；**换下来的旧装备回到背包** |
| `sell_from_backpack(i) -> bool` | 分解换金币 |
| `optimize_equipment() -> int` | 一键换装：每个部位挑背包里评分最高且优于当前的那件 |
| `receive_loot(gear)` | 掉落入包；满则自动分解 |
| `sell_price(gear)` | 转发 `InventoryConfig.sell_price_for()` |

入包 / 装备 / 分解之后都会 `Events.backpack_changed.emit(backpack.duplicate(), capacity)`，
UI（HUD + 背包界面）据此刷新；装备变化还会照旧发 `equipment_changed` + `player_stats_changed`。

## 4. Shop 服务

`scripts/core/shop.gd`（`class_name Shop extends Node`，由 `main.gd` 挂一个）：

- **不是 Autoload**：没有跨场景的全局状态需求；也**不是世界里的物件**（没有位置），所以放 `core/`。
- `roll_stock()` 按 `shop.json` 生成整个货架，`restock()` 花 `restock_cost` 金币重 roll。
- `buy(index)`：先看**背包是否有空位**，再看金币；任一不满足就 Toast 并返回 false（**不扣钱**）。
- 买走的格子**立刻补一件同款**（同部位/品质/等级/价格，名字与词条重新随机）。
- 背包占用是从 `Events.backpack_changed` **缓存**下来的（`_bag_size` / `_bag_capacity`）——
  这样 Shop 不用引用 Player，也能在扣钱之前知道东西放不放得下。

与外界只走 Events：

```
UI 打开商店页 ──> shop_stock_requested ──> Shop ──> shop_stock_changed
UI 点购买     ──> shop_buy_requested(i) ──> Shop ──> 扣钱 + backpack_add_requested ──> Player 入包
UI 点刷新     ──> shop_restock_requested ──> Shop ──> 扣钱 + 重 roll + shop_stock_changed
```

## 5. 界面（InventoryPanel）

`scripts/ui/inventory_panel.gd`（`class_name InventoryPanel extends CanvasLayer`，`layer = 20`）：

- **`I` 或 `B`** 开关（输入动作 `inventory`）；「关闭 (I)」按钮；打开时加入 `modal_ui` 组
  （与 `AttributePanel` 同一套冻结机制，否则点按钮会同时打出普攻）。
- 页签 **背包 / 商店**；右上角常驻金币。
- **背包页**：左侧 5 行「装备中」+ 总属性摘要；右侧 24 格网格（品质色边框 + 名字首字）；
  底部是选中物品的**详情与对比**（绿色 = 有提升 / 红色 = 变差 / 「该部位还是空的」）+ `装备` / `分解 (+N 金)`。
- **商店页**：货架 5 行（名字 / 部位 / 等级 / 词条 / 价格 + 购买）+ `刷新货架 (-N)`；
  背包满或金币不足时按钮自动禁用，并在标题下给出原因提示。
- 对比、卖出价、刷新价**全部在客户端本地算**（数据层公式 + 已广播的 `equipment` / `gold`），
  不需要为「看一眼对比」而往服务端跑一趟。

## 6. HUD

金币下方显示「背包 N/24」，满时变橙；底部操作提示加了 `I 背包`。

## 7. 自测

```powershell
godot --headless --path . --script res://tests/test_inventory.gd
```

用例（同一个 `process_frame` 内同步跑完；装备用手工构造的 `GearItem`，断言精确到数值）：

| 用例 | 断言 |
| --- | --- |
| 配置 | 容量 > 0；Player 容量与 JSON 一致；Player 与界面共用同一份卖出价公式；`generate(3,'rare','boots')` 真的产出战靴 + 稀有 |
| 掉落改入包 | `receive_loot` 后背包 +1、`backpack_changed` 发出、**属性不变**（不再自动装备） |
| 装备 / 换装 | 装备后攻击 +5；换上更强的武器后**旧武器回到背包** |
| 分解 | 背包 -1，金币正好 + 卖出价 |
| 容量 | 塞满后 `backpack_full()`；满包拾取**自动分解**（金币增加、背包不再增长） |
| 一键换装 | 空位被填上（≥1 件）；已经不比身上强时再点 = 0 件 |
| 商店 | 货架条数 = JSON；**金币充足但背包满**时拒买且不扣钱；腾出一格后买入扣钱入包且该格补同款；刷新扣 `restock_cost` |
| 界面 | `inventory` 动作存在；面板默认关闭，开关时同步 `modal_ui` 组 |

数据侧（容量、货架价格 > 0、`generate(指定 slot/rarity)` 结果相符）在 `tests/test_data_layer.gd`；
`tests/test_smoke_3d.gd` 额外断言 `Shop` / `InventoryPanel` 节点与 `add_to_backpack` 存在。

> 💡 自测里「满包拒买」那条特意**先给足金币**再点购买，否则拒买的原因会是「钱不够」，
> 这条用例就白测了（第一版就是这么写的，日志一看金币才 24、价格 35，立刻改掉）。

## 8. TODO

- [ ] **数值校准**：容量 / 价格 / 卖出价系数（当前全为自设）
- [ ] **装备图标**：50 个图标 + 5 套品质边框 + 商店 UI 元素（出图任务见 `docs/tasks/M11-inventory.md`）；
      接入后把 `_refresh_cells()` 里的占位格子换成 `TextureRect`，并把 `icon` 塞进 `GearItem`
- [ ] **排序 / 筛选**：格子目前按拾取顺序排列，没有「按品质/部位」排序与一键清理
- [ ] **商店分类与限量**：货架一次只有 5 件，不支持分类页签 / 限购 / 回购
- [ ] **装备词条扩展**：`GearItem` 只有 5 个词条键，没有 `max_mana` / `mana_regen`（见 `docs/modules/loot.md`）
- [ ] **存档**：背包与装备需要进 `user://` 序列化（M13）
- [ ] **联机**：买卖与换装都要变成服务端裁决（M14），客户端只发意图
