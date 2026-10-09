# 架构与规范

## 1. 目录结构

```
d:/yiyi/dreadmyst-1/
├── data/                    # 数据表（JSON，策划可改，不改代码）
│   ├── loot.json            #   掉落表：掉率/部位权重/品质权重/名字池/词条公式
│   └── enemies.json         #   敌人原型：3 种（含 sprite_path）
├── scenes/
│   └── main.tscn            # 唯一场景（根 Node3D + main.gd，其余节点代码构建）
├── scripts/
│   ├── core/                # Autoload（见 modules/core.md）
│   ├── actors/              # 玩家、敌人（见 modules/combat.md）
│   ├── data/                # 数据层：模型 + 加载器（见 modules/loot.md）
│   ├── world/               # 竞技场/装饰/掉落物/程序化美术工厂（见 modules/world.md、render3d.md）
│   ├── ui/                  # HUD/伤害数字（见 modules/ui.md）
│   └── main.gd              # 入口：世界搭建/相机/光照/刷怪/事件接线
├── tests/
│   ├── test_data_layer.gd   # 数据层自测
│   └── test_smoke_3d.gd     # 3D 冒烟测试（实例化主场景跑帧）
└── docs/                    # 本文档体系
```

## 2. 核心架构原则

1. **数据 vs 逻辑分离**：可被策划调整的内容（数值/名字/颜色/权重/贴图路径）进 `data/*.json`。
2. **跨模块通信只走 `Events` 信号总线**，禁止 actor 内自建 signal。信号见 [modules/core.md](modules/core.md)。
3. **数据层**（`scripts/data/`）无渲染调用 / 无 `_process` / 不 emit 信号。
4. **场景文件极简**：只有 `main.tscn` 一个场景，其余节点用 `class_name` 代码实例化。
5. **静态类型必须完整**；`get_tree().get_nodes_in_group(...)` 赋给无类型 `Array` 再迭代。

## 3. 玩法平面与世界坐标（2.5D 的关键设计）

玩法逻辑（距离、方向、角度、边界）**全部用 `Vector2` 在「玩法平面」上计算**，
只在读写节点位置时转换成 `Vector3`：

```gdscript
Game.world(v2, height := 0.0) -> Vector3   # (x, y) -> (x, height, y)
Game.plane(v3) -> Vector2                  # (x, y, z) -> (x, z)
```

映射约定：**`Vector2(x, y)` = `Vector3(x, 0, y)`**，即 XZ 是地面、Y 是高度。

这样做的收益：AI、攻击判定、边界钳制、掉落判定等逻辑与 2D 版**逐字相同**，转换面积最小。
只有 `velocity` 和 `global_position` 两处需要转 3D。

## 4. 渲染：真 3D + 固定相机

详见 [modules/render3d.md](modules/render3d.md)。要点：

- `Camera3D` 正交投影 + 俯角 -45°，固定视角
- 角色用 `Sprite3D` + `BILLBOARD_ENABLED`（billboard 精灵）
- 地面/矮墙/岩石是**真 3D 网格**，享受真实阴影与深度遮挡
- **零外部素材**：`SpriteFactory` 逐像素生成占位贴图；`sprite_path` 填了就自动换真图，不改代码

## 5. 数据驱动模式

| 数据文件 | 加载器 | 说明 |
| --- | --- | --- |
| `data/loot.json` | `LootConfig`（静态缓存） | 掉率、部位/品质权重、名字池、词条公式 |
| `data/enemies.json` | `EnemyRegistry`（静态缓存） | 原型数值公式 + 外观颜色 + `sprite_path` + 行为参数 |

- 加载统一走 `FileAccess.get_file_as_string` + `JSON.parse_string`，**必须** `typeof(x) == TYPE_DICTIONARY` 校验。
- JSON 颜色统一 `[r, g, b]`（可带第 4 位 alpha）。
- 词条公式两种类型：`level_scaled` / `rarity_scaled`（见 loot.md）。
- **新增敌人/词条/名字池 = 改 JSON，不改代码。**

## 6. 验证方式

```powershell
# 数据层自测（加载 JSON / 生成装备 / 加权分布）
godot --headless --path . --script res://tests/test_data_layer.gd

# 3D 冒烟测试（实例化主场景跑 300 帧，清点实体与渲染节点）
godot --headless --path . --script res://tests/test_smoke_3d.gd

# 导入 + 短跑
godot --headless --import --quit --path .
godot --headless --quit-after 900 --path . res://scenes/main.tscn
```

最近一次验证（2026-10-09）：两项自测全部通过，主场景 900 帧 0 ERROR / 0 WARNING。

## 7. 工程规范 skill

`~/.workbuddy/skills/godot4-gdscript-conventions/`，AI 辅助开发时自动生效。

## 8. 常见陷阱备忘

**GDScript**
- `Dictionary.values()` 返回 Array，不是 keyed dict
- `randi_range(a, b)` 包含两端
- `move_and_slide()` 之后修改 `velocity` 不再生效
- `JSON.parse_string` 失败返回 `null`，必须校验

**Godot 3D**
- **必须先 `add_child()` 才能写 `global_position`**，否则报 `Condition "!is_inside_tree()" is true`
- `Camera3D` 没有 `limit_*`，边界钳制要手写
- `CharacterBody3D` 做顶视角游戏要设 `motion_mode = MOTION_MODE_FLOATING`（关闭重力/贴地）
- billboard 精灵不要投射阴影（会变成薄片），用平躺圆盘做影斑
- `TorusMesh` / `PlaneMesh` / `CylinderMesh` 默认就躺在 XZ 平面，无需旋转
- 终端无输出时用 `godot_console.exe`（标准 exe 不带控制台）
