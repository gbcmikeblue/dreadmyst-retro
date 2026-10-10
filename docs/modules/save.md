# 模块：存档（M13）

**代码**：`scripts/data/save_data.gd`、`scripts/core/save_service.gd`、`scripts/ui/title_screen.gd`
**数据**：无独立 JSON（存档本身就是数据文件，形状见下）
**承载**：`scripts/main.gd`（唯一同时知道 `Game` 与 `Player` 的地方：收集状态 / 灌回状态）、
`scripts/actors/player.gd`（`export_state` / `import_state` / `reset_state`）、`scripts/core/game.gd`（`load_progress` / `reset_progress`）

## 1. 存档形状

`user://save_<槽>.json`（Windows 实际落在 `%APPDATA%\Godot\app_userdata\Dreadmyst Clone\`）：

```json
{ "version": 1, "saved_at": "2026-10-10T21:30:00", "kills": 12,
  "game":   { "level": 5, "xp": 120, "gold": 800 },
  "player": { "profession": "mage", "hp": 95.0, "mana": 140.0,
              "attributes": { "strength": 12, "vitality": 6 },
              "equipment":  { "weapon": { "name": "火舌法杖", "slot": 0, "rarity": 2,
                                          "item_level": 5, "stats": { "attack": 21.0 } } },
              "backpack":   [ { ...同 GearItem.to_dict()... } ] } }
```

**不存**的东西：`arena` / `in_dungeon` / `dungeon_id` / `respawn_point` / 技能冷却 / 挥砍动画 ——
都是瞬态或派生值。读档一律回到「营地 + 不在副本 + 技能就绪」。

## 2. 分层与职责

| 层 | 文件 | 职责 |
| --- | --- | --- |
| 数据层（无 IO、无信号） | `save_data.gd`（`SaveData`） | 结构 + **版本校验 + 结构兜底**（非法枚举钳制、未知词条丢弃、背包超容量计数） |
| 数据层 | `gear_item.gd` 的 `to_dict()` / `from_dict()` | 单件装备的序列化 |
| 运行时服务 | `save_service.gd`（`SaveService extends Node`） | 槽位文件 IO / 原子写 / 读取回退 / 坏档备份 / 防抖自动保存 / 槽位摘要 |
| 状态所有者 | `player.gd`、`game.gd` | 各自 `export/import`、`reset`，并重发对应 `Events` 信号 |
| 装配 | `main.gd` | 收集 `Game` + `Player` + `HUD.kills` → `SaveData`；反向灌回；标题选档流程；F5/F9 |

**为什么 `SaveService` 不是 Autoload**：只有 `main.tscn` 一个场景，也没有跨场景需求；
它也不是「世界里的物件」（没有位置），所以放 `core/`（与 `Shop` 同一处理）。

**为什么状态收集在 `main.gd` 而不是 `SaveService`**：`SaveService` 只做文件 IO，
不认识 `Player` / `Game`；`main.gd` 用 `state_provider`（一个 `Callable`）把「怎么收集状态」注入进去：

```gdscript
save_service.state_provider = _collect_save   # main.gd 里的收集函数
```

## 3. 健壮性（这一节是这个模块的重点）

| 情况 | 处理 |
| --- | --- |
| **写入中途挂掉** | **原子写**：先写 `<file>.tmp` → 旧档改名 `<file>.bak` → tmp 改名正式档 → 删 `.bak`。任何一步挂掉都不会留下半截正式档 |
| **正式档丢了 / 半截** | 读取回退链 **正式档 → `.bak` → `.tmp`**；从回退档读出来后立刻写回正式档 |
| **解析失败 / 空文件 / 版本不符** | 改名 `<file>.corrupt-<时间戳>` **保留证据**（不静默删），按「没有存档」处理 + Toast |
| **存档里枚举越界**（`slot: 99`） | 钳到合法枚举（`GearItem.from_dict`） |
| **未知词条键 / 负数值** | 丢弃 / 归零（只收 `GearItem.STAT_NAMES` 里认识的键） |
| **未知职业 id** | 回退默认职业（`Player.set_profession` 内部兜底 + Warning） |
| **未知属性 id** | 忽略该键（以 `AttributeRegistry.ids()` 为准）+ Warning |
| **背包件数 > 容量**（改过 `inventory.json`） | 只收前 N 件，记 `dropped_backpack_items`，读档后 Toast 提示丢了几件 |
| **hp / mana 缺字段** | 按满值处理（存档里 `< 0` 即视为没写） |

> ⚠️ **解析 JSON 用 `JSON` 实例，不要用 `JSON.parse_string()`**：后者失败时会往 stderr
> 打一条引擎级 `ERROR: Parse JSON failed`。存档损坏是**预期内**的情况（手改 / 半截文件），
> 不该在日志里刷红，更不该破坏「0 ERROR / 0 WARNING」的验收口径。
> `SaveService._parse_json_dict()` 就是干这个的。

## 4. 什么时候存

| 触发 | 说明 |
| --- | --- |
| 关键事件后 **2 秒防抖** | 监听 `player_level_changed` / `gold_changed` / `equipment_changed` / `backpack_changed` / `attributes_changed` / `dungeon_entered` / `dungeon_exited`。连捡 5 件只写一次 |
| `F5` 手动存 | 立刻落盘 + Toast |
| 关闭窗口 | `NOTIFICATION_WM_CLOSE_REQUEST` → `flush_current()`，绕过防抖 |
| 开新档 | 选完槽位立刻写一次，否则刚开局就退出的话槽位还是「空的」 |

`current_slot < 0`（还没在标题界面选槽）时**不记账也不落盘** —— 标题界面期间的那批启动信号不会白写盘。

## 5. 标题选档界面（`TitleScreen`）

```
启动 → main._ready() 建好世界 / UI / SaveService → 开标题界面（3 个槽位）
                                                    │  get_tree().paused = true 冻结世界
   每个槽位显示：职业 · 等级 · 金币 · 最后保存时间     │
   [继续]（空档禁用） [新游戏]（有档时二次确认） [删除]（二次确认）
                                                    ▼
   选择 → Events.save_load_requested / save_new_game_requested / save_delete_requested
        → main.choose_slot(slot, as_new)
             ├─ as_new：Game.reset_progress() + Player.reset_state() + 立刻写盘
             └─ 读档：SaveService.load_slot() → Game.load_progress() + Player.import_state()
                       （读不到 / 坏档 → 自动退化成开新档）
        → 关闭标题界面（解冻世界）→ 重新启用 DevPause → _push_initial_state() → 欢迎 Toast
```

- 「删除」是新档之外唯一会毁数据的操作，所以**必须点两次**（第二次按钮文字变「确认删除？」）；
  在已有档的槽位上「新游戏」同理（变「确认覆盖？」）。
- **暂停用 `get_tree().paused`**。已实测（临时探针）：暂停时 `SceneTree.process_frame`
  仍会触发 72 次 / 0.5 秒，所以基于帧的 `--script` 自测**不会被挂住**。
  另：暂停期间 `main._process()` 不跑，标题界面上按 F5/F9 不会误存。
- 标题界面与 `AttributePanel` / `InventoryPanel` 一样进 `modal_ui` 组；`DevPause` 在有
  `modal_ui` 时不响应暂停热键，且在标题界面期间被 `set_enabled(false)` 整体关掉
  （否则点「继续」会把标题界面后面的世界解冻）。

## 6. 自测

```powershell
godot --headless --path . --script res://tests/test_save.gd
```

`⚠️` 用例会**真的写文件**，但全部走测试专用路径模板 `user://test_save_%d.json`，
跑完删干净（含 `.corrupt-*` 备份），真实存档不受影响。

| 用例 | 断言 |
| --- | --- |
| GearItem 往返 | 名字 / 部位 / 品质 / 等级 / 词条逐项一致（词条按数值比，JSON 往返 int→float） |
| GearItem 兜底 | `slot:99`/`rarity:-3`/`item_level:-5` 被钳制；未知词条丢弃；负词条归零 |
| SaveData 往返 | 进度 / 职业 / hp / mana / 属性 / 装备（键还原成枚举）/ 背包 |
| SaveData 兜底 | 背包 30 件 → 只收容量 24 件并记「丢弃 6」；`version:999` → 判定不受支持 |
| 槽位 IO | 写 → 摘要（等级/金币）→ 读回一致 → 删；**不残留 `.tmp`** |
| 坏档 | 空文件 / 语法错 / 类型不对 三种，都返回 null、原文件被改名搬走、留下 `.corrupt-*` |
| 标题界面 | 启动时打开且 `paused == true`、在 `modal_ui` 组、槽位行数 = 3 |
| 一条龙 | 选新档 → 新档立刻落盘 → 改等级/金币/属性点/装备/背包 → 存 → 清空 → 读回 → 逐项一致 |
| 自动保存标记 | 状态变化后 `has_pending_write() == true`；落盘后清掉 |

数据侧的 `GearItem` / `SaveData` 往返与「枚举键映射只在 `GearItem` 一份」在 `tests/test_data_layer.gd`；
`tests/test_smoke_3d.gd` 断言 `TitleScreen` / `SaveService` 节点与玩家的 `export_state` / `import_state` / `reset_state` 方法存在。

> ⚠️ 现有自测启动时会**先被标题界面挡在暂停状态**。需要「活世界」的用例会在第 1 帧替玩家选槽位
> （`test_smoke_3d.gd` 要刷怪 / 追击 / 攻击 / 掉落，`test_input_move.gd` 要断言物理位移），
> 并把 `save_service.path_pattern` 指到测试专用文件、收尾删掉；其余用例只断言状态、不依赖帧推进，
> 因此不受影响。**新写的用例要注意**：需要世界跑起来就先调 `main.choose_slot(1, true)`。

## 7. TODO

- [ ] **角色创建流程**：现在选槽位就直接开始，没有「起名 / 选职业」（职业仍靠 F1/F2/F3 硬切）
- [ ] **版本迁移**：目前 `version` 不符只做「备份 + 新建」，**没有任何迁移函数**
      （真要改结构时：`SaveData.CURRENT_VERSION` +1，并在 `SaveService` 里加迁移分支）
- [ ] **云存档 / 导出导入**：现在只有本地 `user://`
- [ ] **存档里的地城进度**：进地城时存档只记「在营地」，中途退出会丢本次副本进度（有意为之）
- [ ] **联机（M14）后**：存档要变服务端权威，客户端只上传意图
