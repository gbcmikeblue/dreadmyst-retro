# 架构与规范

## 1. 目录结构

```
d:/yiyi/dreadmyst-1/
├── data/                    # 数据表（JSON，策划可改，不改代码）
│   ├── loot.json            #   掉落表：掉率/部位权重/品质权重/名字池/词条公式
│   └── enemies.json         #   敌人原型：3 种
├── scenes/
│   └── main.tscn            # 唯一场景（根 Node2D + main.gd，其余节点代码构建）
├── scripts/
│   ├── core/                # Autoload（见 modules/core.md）
│   ├── actors/              # 玩家、敌人（见 modules/combat.md）
│   ├── data/                # 数据层：模型 + 加载器（见 modules/loot.md）
│   ├── world/               # 竞技场背景/装饰/掉落物（见 modules/world.md）
│   ├── ui/                  # HUD/伤害数字（见 modules/ui.md）
│   └── main.gd              # 入口：世界搭建/刷怪/事件接线
├── tests/
│   └── test_data_layer.gd   # 数据层自测
└── docs/                    # 本文档体系
```

## 2. 核心架构原则

1. **数据 vs 逻辑分离**：可被策划调整的内容（数值/名字/颜色/权重）进 `data/*.json`；行为逻辑进 `scripts/`。
2. **跨模块通信只走 `Events` 信号总线**，禁止 actor 内自建 signal。当前信号：
   `damage_dealt / enemy_died / player_health_changed / player_stats_changed / player_level_changed / gold_changed / toast`
3. **数据层**（`scripts/data/`）无 `_draw` / `_process` / 不 emit 信号；**表现层**（actors/world/ui）渲染全部 `_draw()`。
4. **场景文件极简**：只有 `main.tscn` 一个场景，其余节点用 `class_name` 代码实例化，避免场景文件损坏且逻辑集中。
5. **静态类型必须完整**：函数参数/返回值/局部变量都标类型；`get_tree().get_nodes_in_group(...)` 赋给无类型 `Array` 再迭代（否则静态分析把元素推断为 `Node` 误报）。

## 3. 数据驱动模式

| 数据文件 | 加载器 | 说明 |
| --- | --- | --- |
| `data/loot.json` | `LootConfig`（静态缓存） | 掉率、部位/品质权重、名字池、词条公式 |
| `data/enemies.json` | `EnemyRegistry`（静态缓存） | 敌人原型：数值公式 + 外观颜色 + 行为参数 |

- 加载统一走 `FileAccess.get_file_as_string` + `JSON.parse_string`，**必须** `typeof(x) == TYPE_DICTIONARY` 校验。
- JSON 颜色统一 `[r, g, b]`（可带第 4 位 alpha）三元组。
- 词条公式两种类型：
  - `level_scaled`：`value = round((base + per_lv × lv) × rarity_mult)`
  - `rarity_scaled`：可带 `min_rarity` 门槛，`value = per_rarity × (rarity + rarity_offset)`
- **新增敌人/词条/名字池 = 改 JSON，不改代码。**

## 4. 2.5D 斜俯视预留（预定方向，未开工）

- 方案：世界根节点 `scale.y = 0.5` + `y_sort_enabled = true`。
- 现有代码已兼容：`_draw()` 全用局部坐标（阴影偏移基于 `radius`），零贴图依赖。
- 相机集中在 `main.gd` `_spawn_player()` 内创建，切换视角只调一处。
- 2D 无 Z 轴，绘制顺序用 `z_index`，不用 `position.z`。

## 5. 验证方式

```powershell
# 数据层自测（加载 JSON / 生成装备 / 加权分布统计）
godot --headless --path . --script res://tests/test_data_layer.gd

# 导入 + 短跑烟测
godot --headless --import --quit --path .
godot --headless --quit-after 1200 --path . res://scenes/main.tscn
```

最近一次验证：全部通过，0 ERROR / 0 WARNING（2026-10-09）。

## 6. 工程规范 skill

完整规范存于 `~/.workbuddy/skills/godot4-gdscript-conventions/`，AI 辅助开发时自动生效。包含：目录约定、命名、静态类型、Events 约定、数据驱动模式、常见陷阱、修改前自查清单。

## 7. 常见陷阱备忘

- `Dictionary.values()` 返回 Array，不是 keyed dict
- `randi_range(a, b)` 包含两端
- `move_and_slide()` 之后修改 `velocity` 不再生效
- `JSON.parse_string` 失败返回 `null`，必须校验
- 终端无输出时用 `godot_console.exe`（标准 exe 不带控制台）
