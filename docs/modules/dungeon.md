# 模块：地城与 Boss（M10）

**代码**：`scripts/data/dungeon_def.gd`、`dungeon_registry.gd`、`scripts/world/dungeon.gd`、`dungeon_room.gd`、`dungeon_door.gd`、`portal.gd`
**数据**：`data/dungeon.json`（+ `data/enemies.json` 里的 Boss 原型）
**承载**：`scripts/main.gd`（进出流程）、`scripts/ui/hud.gd`（Boss 血条 / 房间进度 / 交互提示）、`scripts/core/game.gd`（边界与地城状态）

> ⚠️ **房间尺寸、怪物数、Boss 数值、通关奖励全部是自行设计的占位值**（原作官网 403）。
> 拿到原作资料后**只需改 `data/dungeon.json` 与 `data/enemies.json`**，代码一行不用动。
>
> 📌 出图任务卡 [`docs/tasks/M10-dungeon.md`](../tasks/M10-dungeon.md) 里的 tileset 是**后续的事**：
> 本里程碑先做**房间流 + Boss 战的代码骨架**，美术仍用 `SpriteFactory` 程序化占位。
> 卡片里写的 `scenes/world/dungeon/dungeon_01.tscn` **已废弃** —— 本项目只有 `main.tscn`
> 一个场景（AGENTS.md §2.4），地城由代码构建，与 M7 `SkillBar` / M8 `AttributePanel` 一致。

## 1. 数据模型

| 文件 | 类 | 职责 |
| --- | --- | --- |
| `data/dungeon.json` | `DungeonDef` / `DungeonRegistry` | 房间流布局、每房怪物数、Boss、通关奖励、配色 |
| `data/enemies.json` | `EnemyArchetype`（新增 `is_boss`） | Boss 原型：数值 + `is_boss = true` + `spawn_weight = 0` |

`DungeonRegistry` 与其它注册表同模式（`extends RefCounted` + 静态缓存，`load_default()` /
`get_dungeon(id)` / `ids()` / `clear_cache()`）。**加地城 = 改 JSON。**

`EnemyArchetype.is_boss` 有两个作用：

1. **唯一用途的语义开关**：`is_boss` 或 `spawn_weight <= 0` 的原型**不会**进
   `EnemyRegistry.pick_weighted()`，只由地城通过 `get_archetype(id)` 指名生成
   （双保险：Boss 的 `spawn_weight` 也是 0）。
2. **表现开关**：免疫击退、血条更大更高、脚下多一层品质色光环。

## 2. 布局（房间流）

一条直线，无分支：

```
[房间 0] --走廊--(门 0)-- [房间 1] --走廊--(门 1)-- [房间 2 = Boss 房]
   ↑ 返回传送门                                            ↑ 出口传送门（清空后开）
```

几何全部在**玩法平面**（`Vector2`）上算，`DungeonDef` 提供：

| 方法 | 含义 |
| --- | --- |
| `room_rect(i, origin)` / `room_center(i, origin)` | 第 i 间房的平面矩形 / 中心 |
| `door_point(i, origin)` | 第 i 扇门（房间 i 与 i+1 之间的走廊正中） |
| `bounds(origin)` | 全部房间 + 走廊的并集矩形 → 直接当 `Game.arena` |
| `entrance_point(origin)` / `exit_point(origin)` | 玩家出生点 / 出口传送门位置 |
| `enemy_level(base, i)` / `boss_level(base)` | 房间越靠后越强 |

> ⚠️ `bounds()` 的 Z 起点是 `origin.y - room_size.y * 0.5`（以 `origin.y` 为**中线**），
> 必须与 `room_rect()` 同口径 —— 这里曾被自测抓出过一次「房间不在 bounds 内」。
>
> ⚠️ **出生点与两个传送门都必须落在房间内部**：房间 0 的西墙是封闭的（只有东侧通向走廊），
> 出生点或返回传送门一旦被放到西墙之外，玩家就被封在屋里走不出去。
> 因此 `entrance_point()` 离西墙留 160，返回门再往西 110（既在屋里，又不会被出生点
> 立刻触发 96 半径的交互提示）。自测里有一条几何断言专门盯这两件事。

### 为什么地城要偏移到远处

`main.gd` 用 `DUNGEON_ORIGIN = (0, 20000)` 建地城：地城地面与竞技场地面**不重叠**，
所以进出地城只要切 `Game.arena` + 移动玩家，**不需要销毁/重建竞技场**。
`ArenaBackground` 因此改用固定常量 `Game.ARENA_HOME` 建地面（它只建一次，不能被后续的 `arena` 切换影响）。

## 3. 墙体碰撞：本项目第一处「真墙」

竞技场的矮墙与岩石都是**纯视觉**（`docs/modules/world.md` 的 TODO 里记着这件事）。
地城补上了：

- 玩家 `collision_layer = 4`、怪物 `collision_layer = 2`，两者的 `collision_mask` 都是 **1**；
- `DungeonRoom` 的每段墙 = `StaticBody3D`（`collision_layer = 1`，`collision_mask = 0`）+ 同尺寸 `BoxMesh`；
- `DungeonDoor` 同样在 layer 1，所以**关门时真的拦得住人**。

东西墙按 `open_west` / `open_east` 决定是否留门洞（两段墙 + 中间 `door_width` 宽的缺口），
南北墙整条拉满。

## 4. 房间流与开门

```
Enemy._die() ──> Events.enemy_died ──> Dungeon._on_enemy_died()
                                          └─ _refresh_rooms()：重算每间房的存活数
                                                └─ 某间房由「有怪」变「无怪」→ 开门 + 广播 dungeon_room_cleared
最后一间房（Boss 房）清空 ──> 激活出口传送门
```

- 判定挂在 `enemy_died` 上，而 `Enemy._die()` 是**同步**置 `alive = false` 的，
  所以自测里 `take_damage(1e9)` 之后**不需要等帧**就能断言开门。
- 「有怪 → 无怪」用**逐房重算存活数**实现，不记录「谁死了」，
  这样躲开了 `enemy_died` 只带等级/坐标、不带节点身份的限制。
- 空房间（`enemies_per_room` 里写 0）在 `_ready()` 里就立刻算清空，否则门永远不开。
- 开门时**先取消碰撞再播动画**：玩家不用在门口干等 0.45 秒的下沉动画。

## 5. Boss

- 由 `def.boss_id` 指名生成在最后一间房的中心偏东处，等级 = `玩家等级 + level_bonus + boss_level_bonus`。
- **血条**：场上的 3D 血条更大更高；同时 HUD 顶部有一条**大血条**（`boss_spawned` /
  `boss_health_changed` / `boss_defeated` 三个信号驱动）。
- 血量用**轮询**（`_process` 里值变了才发信号）：全场地城只有 1 个 Boss，
  这比给通用 `Enemy` 装一套「我是 Boss 要上报」的机制更省事，也不会把 Boss 概念泄漏进敌人逻辑
  （`Enemy` 只多了一个 `is_boss` 表现开关）。
- **免疫击退**（`knockback_distance` 为 0 也拦一道），否则被推着走会破坏 Boss 战节奏。
- **通关奖励**：金币 + 经验 + 一件**保底品质**装备（`rewards.guaranteed_rarity`，
  通过 `LootTable.generate(level, forced_rarity_key)` 指定品质），掉在 Boss 原地。
  Boss 的普通掉落（经验/金币/随机装备）仍走 `main._on_enemy_died()`，奖励是额外叠加。

## 6. 进出地城

```
竞技场入口传送门（Portal, Mode.ENTER）
  └─ 靠近 96 单位内 → HUD 显示「按 F 进入 亡者地窖」
       └─ 按 F → Events.dungeon_enter_requested(id)
            └─ main._on_dungeon_enter_requested()：
                 1) 撤掉野外的怪（remove_from_group + queue_free，不给经验/掉落）
                 2) 建 Dungeon 节点（几何在 DUNGEON_ORIGIN 处）
                 3) Game.in_dungeon = true；Game.arena = def.bounds(origin)
                 4) 玩家 + 相机**一起瞬移**到入口（否则相机会横穿整个世界）
                 5) 广播 dungeon_entered

地城内：返回传送门（入口附近，一直可用）/ 出口传送门（Boss 房清空后才激活）
  └─ Events.dungeon_exit_requested → main：arena 还原成 ARENA_HOME、释放地城、
     玩家回到营地、相机瞬移、补刷野怪、广播 dungeon_exited
```

细节：

- **两个 Portal 都用「玩法平面距离判定」**，不用 `Area3D`（与 `GearPickup` 一致，行为可预测）。
- 传送门被释放时（`_exit_tree`）会主动清掉 HUD 上的交互提示，否则离开地城后提示会一直挂着。
- 加点界面（`modal_ui` 组）打开时不响应传送门交互 —— 否则按 F 会一边加点一边进副本。
- `main._process()` 在副本里直接 `return`，**不刷野怪**（地城的怪由 Dungeon 按房间刷）。
- `_clear_arena_enemies()` 必须**立刻** `remove_from_group("enemies")`：
  `queue_free()` 要等帧末，不退出组的话本帧内它们仍会被算作场上敌人（自测就是这么抓到的）。

## 7. HUD

| 元素 | 触发 |
| --- | --- |
| 顶部 Boss 血条 + 名字/等级 | `boss_spawned` → `boss_health_changed` → `boss_defeated` |
| 左上「地城名 · 已清 N/M 间」 | `dungeon_entered` / `dungeon_room_cleared` / `dungeon_exited` |
| 技能栏正上方「按 F …」交互提示 | `interact_prompt_changed`（靠近/离开各发一次，`""` 表示隐藏） |

## 8. 自测

```powershell
godot --headless --path . --script res://tests/test_dungeon.gd
```

用例（全部在同一个 `process_frame` 回调内同步跑完）：

| 用例 | 断言 |
| --- | --- |
| 数据层 | 地城定义完整（房间数 ≥ 2、尺寸 > 0、配了 Boss、第 0 间有怪）；Boss 原型存在且 `is_boss` |
| 野外池 | `pick_weighted() × 300` 抽到 Boss 次数 = 0 |
| 进入 | `Game.arena` 切到 `def.bounds(origin)`；房间数/门数/敌人数（每房怪数和 + 1 Boss）正确；存在 layer 1 的 `StaticBody3D`；玩家被传送进范围；Boss 在最后一间房的怪列表里；门未开、出口未激活 |
| 清房 | 清空第 0 间房 → `room_cleared(0)`、`doors[0].is_open`、已清 1 间 |
| Boss | 清空 Boss 房 → Boss 死亡、金币奖励到账、最后一间房清空、出口激活；清完所有房间 → 已清房间数 = 总数 |
| 离开 | `in_dungeon = false`、`arena` 还原、`main.dungeon` 置空、玩家在竞技场内、野外重新刷怪 |

数据侧校验（地城定义、Boss 标记、`bounds()` 包住所有房间、野外池无 Boss）在
`tests/test_data_layer.gd`；`tests/test_smoke_3d.gd` 额外断言入口 `Portal` 节点与 Boss 原型存在。

> ⚠️ 自测里 `_main` / `_game` / `_events` 都声明为 `Variant`：`--script` 入口不能写
> `Events` / `Game`（编译早于 autoload 注册），而声明成 `Node` 又会让静态分析拦住
> `_main.dungeon` 这类动态属性访问。

## 9. TODO

- [ ] **数值校准**：房间尺寸 / 每房怪数 / Boss 数值 / 奖励（当前全为自设）
- [ ] **tileset 接入**：用真贴图替换 `DungeonRoom` 的程序化网格地面（出图任务见 `docs/tasks/M10-dungeon.md`）
- [ ] **Boss 机制**：目前 Boss 只是「血厚 + 免疫击退」，没有分阶段 / 技能 / 召唤
- [ ] **多间地城**：`dungeon.json` 已支持数组，但竞技场入口只开第一间（需要选择 UI 或按等级开放）
- [ ] **战斗房间**：没有随机房间模板 / 分支路线（当前只有一条直线）
- [ ] **地城内的掉落物**：离开地城时地上的装备会被一起释放，需要「结算后再退出」或保留
