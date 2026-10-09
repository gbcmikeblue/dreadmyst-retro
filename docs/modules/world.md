# 模块：世界与场景

**文件**：`scripts/world/arena_background.gd`、`arena_prop.gd`、`gear_pickup.gd`、`sprite_factory.gd`、`scripts/main.gd`

## 竞技场（ArenaBackground, Node3D）

| 元素 | 实现 |
| --- | --- |
| 范围 | `Rect2(-960, -640, 1920, 1280)` → 地面平面 1920(X) × 1280(Z)，中心原点 |
| 地面 | 单个 `PlaneMesh` + **平铺网格贴图**（`uv1_scale = (24, 16)`），只占 1 个 draw call |
| 地面/网格色 | 地面 (0.075, 0.075, 0.10)，线 (0.12, 0.12, 0.16)，格宽 80 |
| 中心营地 | `CylinderMesh` 圆盘（半径 96）+ `TorusMesh` 紫环（unshaded） |
| 边界 | 4 面矮墙 `BoxMesh`（高 7、厚 6），紫色 + 自发光 |
| 装饰岩石 | 26 个，固定种子 `20261009`，位置限制在离边 80 内 |

**网格为什么用贴图而非画线**：2D 版是 40 条 `draw_line`，3D 里用平铺贴图成本恒定。
若远处出现摩尔纹，给 `grid_texture` 加 `generate_mipmaps()` 即可。

## 装饰岩石（ArenaProp, Node3D）

- `SphereMesh` 低分段（`radial_segments = 6`, `rings = 3`）做出棱面感
- 半径 8~22，随机压扁（Y 轴 0.55~0.90）与随机旋转
- 形状种子由坐标派生（`|x|·31 + |z|·17`），保证每次运行同一块石头一致
- **会投影真实阴影**（`DirectionalLight3D`），且纯视觉、无碰撞

## 掉落物（GearPickup, Node3D）

| 参数 | 值 |
| --- | --- |
| 拾取半径 | 40（玩法平面距离判定，非 `Area3D`） |
| 光晕 | `flat_disc` 平躺品质色半透明圆盘（半径 24） |
| 图标 | billboard 宝石精灵（高 22 世界单位） |
| 浮动动画 | `sin` 上下振幅 3.0，频率 3.0 |

拾取流程：`_process` 用 `Game.plane()` 算平面距离 → 调 `player.receive_loot(gear)`（自动穿/分解）→ Toast。

## 程序化美术工厂（SpriteFactory）

零外部素材的关键。详见 [render3d.md](render3d.md)。

| 方法 | 产出 |
| --- | --- |
| `actor_texture(path, pixels, body, outline)` | 圆形角色（优先加载 `path`） |
| `gem_texture` / `grid_texture` / `white_texture` | 宝石 / 网格 / 1×1 白贴图 |
| `billboard_sprite(tex, world_height)` | `Sprite3D` billboard，底面贴地 |
| `blob_shadow` / `flat_disc` / `box_marker` | 影斑 / 圆盘 / 指示条 |
| `arc_fx(inner, outer, half_angle, seg, color)` | 扇形弧光（运行时 `ArrayMesh`） |
| `hp_bar` / `update_bar` | 血条（左对齐比例更新） |

所有贴图带静态缓存，重复调用不会重复生成。

## 入口装配（main.gd，根 Node3D）

`_ready()` 顺序：
1. `seed(Time.get_ticks_msec())`
2. `_build_environment()`：`WorldEnvironment`（深色背景 + 环境光 + FILMIC）+ `DirectionalLight3D`（真实阴影）
3. 加竞技场 → `_spawn_player()`（玩家 + 正交俯视相机）
4. 加 HUD → 连接 Events → 补发初始状态（HUD 创建晚于玩家信号，重放一次）
5. 开局 6 只怪 → Toast 欢迎

`_process()`：更新相机（平滑跟随 + 边界钳制）→ 刷怪计时。

| 回调 | 行为 |
| --- | --- |
| `_on_enemy_died` | 经验 `12+lv×7`、金币 `2~6`、`LootTable.roll_drop` 生成掉落物 |
| `_on_damage_dealt` | 生成 `Label3D` 伤害数字（受伤红 / 暴击金 / 普通白） |

## TODO

- [ ] 多区域/地城（当前单一竞技场）
- [ ] 岩石无碰撞，地城版本应接入 layer 1 墙体
- [ ] 相机 `CAMERA_ORTHO_SIZE` / 俯角需目视微调（见 render3d.md）
