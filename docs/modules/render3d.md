# 模块：2.5D 渲染（真 3D + 固定相机）

**文件**：`scripts/world/sprite_factory.gd`、`scripts/main.gd`（相机/光照部分）

## 方案

真 3D 空间 + **固定俯角的正交相机** + **billboard 精灵**。这是 2.5D 的标准做法：
角色是 2D 贴图，但站在真实 3D 空间里，所以能拿到真实光影、深度遮挡、任意视角。

## 相机（`main.gd`）

```gdscript
camera.projection = Camera3D.PROJECTION_ORTHOGONAL   # 正交：无透视畸变
camera.size = 620.0                                   # 竖直视野（世界单位）
camera.rotation_degrees = Vector3(-45.0, 0.0, 0.0)    # 俯角
```

| 常量 | 值 | 作用 |
| --- | --- | --- |
| `CAMERA_TILT_DEG` | -45.0 | 俯角。更"平"用 -55，更"俯"用 -35 |
| `CAMERA_ORTHO_SIZE` | 620.0 | 竖直视野范围，等价于 2D 的 zoom |
| `CAMERA_DIST` | 1600.0 | 沿视线后撤距离，正交下只影响裁剪 |
| `CAMERA_FOLLOW_SPEED` | 6.0 | 平滑跟随速度 |

相机位置 = 焦点 + `(0, D·sin(t), D·cos(t))`，保证焦点落在画面正中。

### 鼠标滚轮式缩放
改 `camera.size` 即可（正交投影下这就是缩放），无需移动相机。

### 边界钳制（重要坑）
**`Camera3D` 没有 `Camera2D` 的 `limit_left/right/top/bottom`**，必须手动钳制焦点：

```gdscript
half_x = CAMERA_ORTHO_SIZE * aspect * 0.5
half_z = CAMERA_ORTHO_SIZE * 0.5 / cos(tilt)   # 俯角把纵深压缩 cos(t) 倍
```

视野比场地大时退化为居中，避免 `min > max`。见 `main.gd::_clamp_focus()`。

## 光照与环境（`main.gd::_build_environment()`）

- `WorldEnvironment`：深色背景 + 环境光 + FILMIC 色调映射
- `DirectionalLight3D`：方向光 + **真实阴影**（`SHADOW_ORTHOGONAL`，最大距离 2400）

地面、边界矮墙、岩石都是真 3D 网格，会真正互相投影，比 2D 版手画的假阴影好得多。

## Billboard 精灵

```gdscript
sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
sprite.shaded = false            # 不受光照影响，保持 2D 观感
sprite.alpha_cut = ALPHA_CUT_DISCARD
sprite.texture_filter = TEXTURE_FILTER_NEAREST   # 像素风
```

完全 billboard 的精灵永远正对相机，所以固定俯角下**看起来是直立的、无畸变的 2D 图**。

精灵底面贴地：`position.y = world_height * 0.5`。

### 影斑（必须）
billboard 精灵是正对相机的平面，投射的阴影是条薄片，很难看。所以**关闭精灵投影**，
改用脚下一个平躺的深色圆盘（`SpriteFactory.blob_shadow`）。这是 billboard 游戏的通行做法。

## 方向对齐约定（重要）

所有"朝向型"网格（弧光、朝向指示条）的本地前方统一为 **+X**，因此：

```gdscript
node.rotation.y = -facing.angle()      # facing 是玩法平面的 Vector2
node.position = Vector3(facing.x, 0, facing.y).normalized() * offset
```

推导：绕 Y 旋转 θ 把 +X 映射到 `(cosθ, 0, -sinθ)`，令其等于 `(fx, 0, fy)` 得 `θ = atan2(-fy, fx) = -angle()`。

## 零素材：程序化占位贴图

`SpriteFactory` 用 `Image.set_pixel` 逐像素生成贴图（带静态缓存）：

| 方法 | 产出 |
| --- | --- |
| `actor_texture(path, pixels, body, outline)` | 圆形角色（优先加载 `path`） |
| `gem_texture(pixels, body)` | 菱形宝石（掉落物） |
| `grid_texture(cell, ground, line)` | 地面网格（平铺，1 个 draw call） |
| `white_texture()` | 1×1 白贴图（血条缩放/染色） |
| `arc_fx(...)` | 扇形弧光（运行时构建 ArrayMesh） |
| `blob_shadow / flat_disc / box_marker / hp_bar` | 影斑 / 圆盘 / 指示条 / 血条 |

## 接入真实 sprite（不改代码）

`data/enemies.json` 每个原型都有 `sprite_path` 字段：

```json
{ "id": "slime", "sprite_path": "res://art/enemies/slime.png", ... }
```

- 留空 → 用程序化占位贴图
- 填了有效路径 → 自动加载真图（`ResourceLoader.exists` 校验，失败自动回退）

**渲染路径完全一致**（都是 `Sprite3D` billboard），所以换图不需要改任何渲染代码。

## 已知限制 / TODO

- [ ] `CAMERA_ORTHO_SIZE` 与俯角需要目视微调（我无法看到渲染结果）
- [ ] 网格贴图未生成 mipmap，远处可能有轻微摩尔纹
- [ ] 玩家朝向指示仍是几何体（金色长条），接入真美术后可换成精灵
- [ ] 未做相机旋转/缩放切换（结构上已支持：只改 `camera.rotation` / `camera.size`）
