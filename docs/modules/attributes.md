# 模块：属性加点（M8）

**代码**：`scripts/data/attribute_def.gd`、`attribute_registry.gd`、`scripts/ui/attribute_panel.gd`
**数据**：`data/attributes.json`
**承载**：`scripts/actors/player.gd`（点数经济 + 派生属性）、`scripts/ui/hud.gd`（剩余点数）、`scripts/main.gd`（挂界面 + 补发初始状态）

> ⚠️ **所有数值均为自行设计的占位值**。原作官网 403，属性公式无人提供，
> 因此按「5 属性 × 每点加成」自设了一套自洽数值。拿到原作资料后**只需改
> `data/attributes.json`**，代码一行不用动。

## 1. 数据模型

| 文件 | 类 | 职责 |
| --- | --- | --- |
| `data/attributes.json` | `AttributeDef` / `AttributeRegistry` | 5 个属性的每点加成 `per_point`、上限 `max_points`、每级自由点数 `free_points_per_level` |

`AttributeRegistry` 与 `ProfessionRegistry` / `SkillRegistry` 同一模式（`extends RefCounted` +
`static var _cached` 静态缓存，`load_default()` / `get_attribute()` / `ids()` / `clear_cache()`）。
**加属性 / 调加点曲线 = 改 JSON，不改代码。**

数据层保持纯净：`AttributeRegistry.bonus_for_all(allocation)` 是**纯计算**函数
（`{属性 id: 点数}` → `{stat 键: 增量}`），不依赖 `Player`，因此自测与后续联机在服务端复算都能直接用。

## 2. 五个属性

`per_point` 的键与 `Player.total_stats()` 完全一致
（`attack` / `max_hp` / `armor` / `crit` / `speed` / `max_mana` / `mana_regen`）。

| id | 名 | 每点加成 | 上限 |
| --- | --- | --- | --- |
| `strength` | 力量 | +2 攻击、+0.3 护甲 | 100 |
| `agility` | 敏捷 | +0.4% 暴击、+1.2 移动速度 | 100 |
| `intelligence` | 智力 | +6 法力上限、+0.3 法力回复 | 100 |
| `vitality` | 体力 | +8 生命上限、+0.4 护甲 | 100 |
| `spirit` | 精神 | +0.5 法力回复、+3 生命上限、+0.15% 暴击 | 100 |

`max_points = 0` 表示**不设上限**（此时不会出现「满级」状态）；当前全部设 100，
所以 UI 的「满级」态是可达到、可验证的。

`total_stats()` 的叠加顺序：**兜底值 → 职业 `base_stats` → 属性点加成 → 装备词条**（全部累加，顺序无副作用）。

## 3. 点数经济

```
累计可分配点数 = (等级 - 1) × free_points_per_level      # 每级 5 点
剩余点数       = 累计可分配点数 - 已投入点数
```

- **等级的唯一来源是 `Game`**：`Game.add_xp()` 升级后发 `player_level_changed`，
  `Player._on_level_changed()` 据此重算 `_points_total`。
  Player **不另存一份「已发点数」**，避免与 `Game.level` 双重记账。
- 属性点是**角色级**成长：`set_profession()`（原型期 F1/F2/F3 转职）**不重置**已投入点数。
- 目前没有洗点功能；后续「存档（M13）」接管后，`attributes` 字典就是需要序列化的字段之一。

## 4. 加点流程

```
加点界面 attribute_panel.gd                 actor/player.gd
「+」按钮 ──> Events.attribute_allocate_requested(id, points) ──> allocate_attribute(id, points)
                                                                        │
UI 刷新   <── Events.attributes_changed(attributes, free, spent) <──────┘
```

UI **不引用 Player**（也拿不到），只发请求；与 `SkillBar` / `HUD` 的「只监听 Events」原则一致。

`allocate_attribute(id, points)` 的拒绝条件（任一满足即返回 `false`，**且不改动任何状态**）：

1. `points <= 0`
2. 属性 id 不存在（并 `push_warning`，用于抓「UI 与 JSON 不同步」的数据 bug）
3. `points >` 剩余点数 → Toast「属性点不足」
4. 加完会超过 `max_points` → Toast「XX 已满级」

> 判定顺序是**先判点数不足、再判满级**。这样「满级被拒」时剩余点数仍 > 0，
> UI / 自测都能把它和「没点数了」区分开（`test_attributes.gd` 就是靠这条断言的）。

**加点不会自动补血**：`_on_attributes_changed()` 只把当前生命 / 法力按新上限**向下钳制**，
不补满——否则「加点」会被当成回血手段滥用。

## 5. 界面

`scripts/ui/attribute_panel.gd`（`class_name AttributePanel extends CanvasLayer`，`layer = 20`）：

- **C 键**开关（输入动作 `attributes`，在 `Game._setup_input()` 注册，同时注册
  `physical_keycode` 与 `keycode` 两套事件）；也有「关闭 (C)」按钮。
- 每行：程序化占位图标（属性色边框 + 属性名首字）、属性名、说明、`已投 / 上限`、
  当前实际加成文本（如「攻击 +24 护甲 +4」）、`+1` / `+5` 按钮。
- **满级**时该行右侧显示金色「满级」，两个按钮禁用；`+5` 在「加完会超上限」时单独禁用。
- 没有真实图标：接入真图时给 `data/attributes.json` 补 `icon` 字段即可（`AttributeDef` 现已预留读取位置）。
- `process_mode = PROCESS_MODE_ALWAYS`：暂停（DevPause）时仍能开关面板。
- 所有按钮 `focus_mode = FOCUS_NONE`，否则点过按钮后空格 / 回车会重复触发按钮而不是攻击。
- **打开时加入 `modal_ui` 组**，`Player._ui_blocking()` 据此冻结移动与攻击 ——
  按钮只拦 GUI 事件，拦不住玩家那种轮询式读输入（`Input.is_action_pressed`）。
  否则点「+」的同时会打出一发普攻。

HUD（`scripts/ui/hud.gd`）在职业 / 等级右侧显示「属性点 N」，> 0 时高亮金色；
底部操作提示里加了 `C 属性加点`。

`main.gd` 负责 `add_child(AttributePanel.new())`，并在 `_push_initial_state()` 里补发一次
`attributes_changed`（Player 先于 HUD 发出初始信号，与其它 UI 状态同理）。

## 6. 自测

```powershell
godot --headless --path . --script res://tests/test_attributes.gd
```

用例（全部在同一个 `process_frame` 回调内同步跑完）：

| 用例 | 断言 |
| --- | --- |
| 数据层 | 5 个属性、每个都有 `per_point` 与 `> 0` 的上限、`free_points_per_level > 0` |
| 1 级无点数 | 剩余 = 0，加点返回 `false` 且不改变状态 |
| 5 级加点 | 剩余 = 20；力量 +1 → 攻击 +2.0（按 `per_point` 精确比对）；剩余变 19 |
| 加点不回血 | 体力 +1 → 生命上限 +8，**当前生命保持不变** |
| 点数不足 | 申请 `剩余 + 1` 被拒，已投入点数不变 |
| 满级 | 力量投满 100 后被拒，且此时剩余 > 0（与「点数不足」区分） |
| 转职不重置 | `set_profession("mage")` 后已投入点数与属性表键集合不变 |
| 输入 / 界面 | `attributes` 动作存在；面板默认关闭，开关时同步 `modal_ui` 组 |

数据侧校验（属性数、`per_point` 非空、`bonus_for_all` 汇总）在 `tests/test_data_layer.gd`；
`tests/test_smoke_3d.gd` 额外断言 `allocate_attribute` 存在、属性表与 JSON 键集合一致、`AttributePanel` 节点存在。

> 自测里**不**调用未知属性 id 那一支：它会 `push_warning`，故意触发会让输出混进 WARNING，
> 破坏「0 ERROR / 0 WARNING」的验收口径；未知 id 改在数据层断言（`get_attribute(...) == null`）。

## 7. TODO

- [ ] **数值校准**：等原作属性公式（当前 5 属性的每点加成、每级点数全为自设）
- [ ] **属性图标**：5 属性 × 4 状态的出图任务见 `docs/tasks/M8-attributes.md`；
      接入后给 JSON 补 `icon` 字段，并在 `AttributePanel._build_rows()` 里改用
      `TextureRect`（当前是程序化占位图标）
- [ ] **洗点 / 重置**：目前投出去就收不回
- [ ] **职业差异**：现在 5 个属性对三职业完全同价，没有职业系数（原作是否有待考）
- [ ] **存档**：`attributes` 需要进 `user://` 序列化（M13）
