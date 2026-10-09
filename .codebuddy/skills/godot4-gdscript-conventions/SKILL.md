---
name: godot4-gdscript-conventions
description: 强制 Dreadmyst Clone（Godot 4 / GDScript 单机原型，仓库 dreadmyst-retro）的工程规范：静态类型、Events 信号总线、data/*.json 数据驱动、Vector2 玩法平面坐标转换，以及 InputMap 与 3D 节点的已知陷阱。在本仓库中编写、审阅、重构任何 GDScript，新增玩法模块、编辑 data/*.json、或新增 headless 测试时，都应使用本 skill。
---

# Godot 4 / GDScript 工程规范（Dreadmyst Clone）

## 目的

把本项目的架构约定与 Godot 4 踩坑经验固化成可执行清单，使新增代码与既有代码风格一致、
不引入已知会翻车的写法。**核心目标：数据 / 逻辑分离、跨模块只走信号、逻辑永远在 Vector2 平面算。**

## 使用时机

在 `dreadmyst-retro` 仓库内做以下任一事情时使用：

- 新增或修改任意 `.gd` 脚本
- 新增玩法模块（技能、背包、地城、属性加点……）
- 编辑 `data/*.json` 数据表
- 新增或修改 `tests/` 下的 headless 自测
- 审阅他人提交的 GDScript

## 动手前的两步

1. 读仓库根目录的 `AGENTS.md`（硬性规范 + 文档索引 + 当前状态）。
2. 读 `docs/architecture.md`（目录结构、架构原则、坐标转换、验证方式）。

只在需要模块细节时才读 `docs/modules/<模块>.md`，不要一次全读。

## 硬性规范（违反即视为 bug）

1. **数据 / 逻辑分离**：数值、名字、颜色、权重、贴图路径等策划可调项一律进 `data/*.json`。
   「加敌人 / 加词条 / 加名字池 = 只改 JSON，不改代码」是硬指标。
2. **跨模块通信只走 `Events` 信号总线**：禁止在 actor / UI 内部自建 `signal` 做跨模块通知。
   新信号写在 `scripts/core/event_bus.gd`，并带类型标注与一行中文注释。
3. **数据层纯净**：`scripts/data/` 不做渲染调用、不写 `_process`、不 emit 信号。
4. **场景文件极简**：只有 `scenes/main.tscn` 一个场景，根节点 `Node3D`。不要手工编辑 `main.tscn`，
   也不要为了放逻辑节点新增 `.tscn`——节点一律用 `class_name` 在代码里实例化。
5. **玩法逻辑用 `Vector2` 在"玩法平面"上算**，只在读写节点位置时转换：
   ```gdscript
   Game.world(v2, height := 0.0) -> Vector3   # (x, y)  -> (x, height, y)
   Game.plane(v3) -> Vector2                  # (x, y, z) -> (x, z)
   ```
   映射约定 `Vector2(x, y)` = `Vector3(x, 0, y)`。距离 / 方向 / 夹角 / 边界判定全部在平面内完成。
6. **静态类型必须完整**：函数返回值、参数、成员变量都要标注。
   最大的坑：`get_tree().get_nodes_in_group(...)` 的结果**先赋给无类型 `Array`** 再迭代，
   否则静态分析会把元素推断为 `Node` 而报「找不到成员」：
   ```gdscript
   # 正确
   var enemies: Array = get_tree().get_nodes_in_group("enemies")
   for enemy in enemies:
       if enemy.has_method("is_alive") and not enemy.is_alive():
           continue
       enemy.take_damage(dmg, false)
   ```
7. **JSON 加载**：`FileAccess.get_file_as_string` + `JSON.parse_string`，
   且**必须**校验 `typeof(parsed) == TYPE_DICTIONARY`（解析失败返回 `null`）。
   加载器统一用 `static var _cached` 做静态缓存，并提供 `clear_cache()` 供测试用。
8. **`class_name` 脚本**：新增可复用类型时用 `class_name Xxx` + `extends RefCounted`（纯数据）
   或对应 Node 类型（有生命周期的实体）。
9. **常量**：只有真正不可调的才用 `const`，且**必须写中文注释说明含义与单位**。
10. **注释用中文**，解释"为什么"而不是"做了什么"；分隔大块用 `# ---- 标题` 风格。

## 新增「数据驱动内容」的标准步骤

1. 在 `data/<name>.json` 顶层放 `{"version": N, "<items>": [...]}`。
   颜色统一写 `[r, g, b]`（可带第 4 位 alpha），不要写 CSS 十六进制。
2. 在 `scripts/data/` 新增 `class_name XxxArchetype`（单条记录，含 `static func from_dict(d) -> ...`）
   与 `class_name XxxRegistry`（加载 + 缓存 + 加权抽取），照抄 `enemy_archetype.gd` / `enemy_registry.gd` 的结构。
3. 所有字段都要有**与 JSON 一致的默认值**，缺字段时能退化运行。
4. 在 `tests/` 加一条自测（照抄 `test_data_layer.gd` 的风格：`print("[OK] ...")` / 失败 `quit(1)`）。
5. 在对应 `docs/modules/<模块>.md` 补字段说明，并在 `docs/roadmap.md` 变更记录加一行。

## 新增实体的标准步骤

1. `extends CharacterBody3D`，`_ready()` 里设 `motion_mode = MOTION_MODE_FLOATING`（顶视角关重力）。
2. 碰撞：玩家 `layer 4 / mask 1`，敌人 `layer 2 / mask 1`。**玩家与怪物互不阻挡**
   （避免被围死），视觉分离交给 separation 排斥力。
3. 视觉：`SpriteFactory.blob_shadow()` 影斑 + `SpriteFactory.billboard_sprite()` 身体。
   **billboard 精灵不要投射阴影**（会变成薄片）。
4. 朝向型网格的本地前方统一为 **+X**，因此 `node.rotation.y = -facing.angle()`。
5. **必须先 `add_child()` 才能写 `global_position`**，否则报 `Condition "!is_inside_tree()" is true`。
6. 状态变化通过 `Events.*.emit(...)` 广播给 UI，不要反向引用 HUD。

## 新增输入动作

一律在 `scripts/core/game.gd::_setup_input()` 里注册，**`physical_keycode` 与 `keycode` 两套都要加**：

```gdscript
func _action(action_name: StringName, keys: Array) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)
		InputMap.add_action(action_name)
	for key in keys:
		var physical := InputEventKey.new()
		physical.physical_keycode = key
		InputMap.action_add_event(action_name, physical)
		var logical := InputEventKey.new()
		logical.keycode = key
		InputMap.action_add_event(action_name, logical)
```

只注册 `physical_keycode` 时，远程桌面 / 虚拟机 / 部分驱动不提供物理键码，该动作会**完全收不到键盘输入**；
症状是「鼠标点击正常、只有键盘失灵」，极具迷惑性。

## 完成前自检

- [ ] 新增可调项进了 JSON，没硬编码
- [ ] 新跨模块通知走 `Events`，没在 actor 内自建 signal
- [ ] 玩法逻辑用 `Vector2`，只有写 `position` / `velocity` 时转 `Vector3`
- [ ] 静态类型完整；`get_nodes_in_group` 结果先赋给无类型 `Array`
- [ ] 跑通 4 条验证命令（见下），第 4 条 0 ERROR / 0 WARNING
- [ ] 用低于 4.7 的引擎验证过 → `git checkout -- icon.svg.import` 还原
- [ ] 相关 `docs/modules/*.md` 与 `docs/roadmap.md` 变更记录已更新

```powershell
godot --headless --import --path .                                      # 首次 / 换机器
godot --headless --path . --script res://tests/test_data_layer.gd
godot --headless --path . --script res://tests/test_smoke_3d.gd
godot --headless --path . --script res://tests/test_input_move.gd
godot --headless --quit-after 900 --path . res://scenes/main.tscn
```

## 参考

- `references/pitfalls.md` —— GDScript / InputMap / Godot 3D / 运行期的完整陷阱清单（含症状与成因）。
  遇到"代码看起来没错但行为不对"时先查这里。
- `references/data-schema.md` —— `data/loot.json` 与 `data/enemies.json` 的字段结构、加载器对应关系、
  以及"加一条内容"的最小改动清单。
