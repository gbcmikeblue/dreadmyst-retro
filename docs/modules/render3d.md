# 模块：2.5D 渲染（真 3D + 正交俯视相机）

**文件**：`scripts/world/sprite_factory.gd`、`scripts/world/camera_rig.gd`、`scripts/data/camera_config.gd`、`scripts/main.gd`（环境/光照部分）
**数据**：`data/camera.json`

## 方案

真 3D 空间 + **固定俯角的正交相机** + **billboard 精灵**。这是 2.5D 的标准做法：
角色是 2D 贴图，但站在真实 3D 空间里，所以能拿到真实光影、深度遮挡、可旋转视角。

## 相机（M16 起独立成 `CameraRig`）

参数全在 `data/camera.json`（`CameraConfig`），**改数值不用改代码**；
相机逻辑（跟随 / 缩放 / 旋转 / 俯角 / 边界钳制）在 `CameraRig`（`extends Camera3D`）里，
`main.gd` 只负责创建它并 `make_current()`。

```json
{ "size": 620.0, "tilt_deg": -45.0, "distance": 1600.0, "follow_speed": 6.0,
  "zoom":   { "min": 340.0, "max": 980.0, "step": 40.0 },
  "rotate": { "step_deg": 15.0 },
  "tilt":   { "min_deg": -70.0, "max_deg": -22.0, "step_deg": 3.0 } }
```

| 字段 | 作用 |
| --- | --- |
| `size` | 正交视野高度（世界单位）：越小越近。等价于 2D 的 zoom |
| `tilt_deg` | 俯角，**必须为负**（0 = 平视，-90 = 垂直俯视）。更「平」用 -55，更「俯」用 -35 |
| `distance` | 沿视线后撤距离（正交下只影响裁剪范围） |
| `follow_speed` | 焦点平滑跟随速度 |
| `zoom.*` | 缩放区间与每次步进 |
| `rotate.step_deg` | 每次水平旋转的角度 |
| `tilt.*` | 俯角可调区间与步进。⚠️ `min_deg` 是**数值最小**的那个（最俯视），别搞反 |

### 操作（M16 新增）

| 动作 | 键 | 说明 |
| --- | --- | --- |
| `zoom_in` / `zoom_out` | 滚轮上/下、`=` / `-` | 改 `size`（正交下这就是缩放，不用移动相机） |
| `rotate_left` / `rotate_right` | `,` / `.` | 水平旋转（每次 `rotate.step_deg`） |
| `tilt_up` / `tilt_down` | `PageUp` / `PageDown` | 调俯角（每次 `tilt.step_deg`） |
| `camera_reset` | `R` | 回到 `data/camera.json` 里的默认视角 |

- 游戏内改完的值会**打在控制台**（`[camera] 视野 500 ← 抄进 data/camera.json 即可固化`），
  DevPause 面板（右上角）也会实时显示当前读数 —— 这就是「目视校准」的闭环：
  调 → 看读数 → 抄回 JSON。
- 有模态界面（加点 / 背包 / 标题选档）打开时**不响应**相机键，免得翻背包时把镜头转走。
- 相机位置 = 焦点 − 视线方向 × `distance`，保证焦点落在画面正中（旋转后依然成立：
  先写 `rotation`，再取 `-transform.basis.z` 作为视线方向）。

### 边界钳制（重要坑，M16 起支持旋转）

**`Camera3D` 没有 `Camera2D` 的 `limit_left/right/top/bottom`**，必须手动钳制焦点。
旋转后画面的地面足迹是一个**斜矩形**，所以取它的世界轴对齐包围盒（保守估计）：

```gdscript
half_w = size * aspect * 0.5                    # 屏幕横向半宽
half_h = size * 0.5 / cos(|tilt|)               # 俯角把地面纵深压缩 cos(t) 倍（有个下限兜底）
ext.x  = |right.x| * half_w + |up.x| * half_h    # right / up 是绕 Y 旋转 yaw 后的画面轴
ext.y  = |right.y| * half_w + |up.y| * half_h
```

`yaw = 0` 时退化成 `half_w / half_h`（与 M16 之前一致）；`yaw = 90°` 时 X/Z 互换。
视野比场地还大时**退化为居中**，避免 `min > max`。见 `CameraRig.clamp_focus()`。

> 💡 有两种焦点：`focus_plane()` 是**实际对准的点**（已钳制），`focus_target()` 是
> **玩家位置**（未钳制）。瞬移判定用后者 —— 否则玩家走到场地边缘时，被钳住的焦点
> 会被误判成「瞬移」，每帧都重新对齐。

### 瞬移自动对齐

焦点离目标超过「视野 × 3」时**直接对齐**，不做平滑：
复活、进出地城都会瞬移玩家，让它一路平移过去会很难看（`SNAP_DISTANCE_FACTOR`）。

## 光照与环境（`main.gd::_build_environment()`）

- `WorldEnvironment`：深色背景 + 环境光 + FILMIC 色调映射
- `DirectionalLight3D`：方向光 + **真实阴影**（`SHADOW_ORTHOGONAL`，最大距离 2400）

地面、边界矮墙、岩石都是真 3D 网格，会真正互相投影，比 2D 版手画的假阴影好得多。

## Billboard 精灵

```gdscript
sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
sprite.shaded = false            # 不受光照影响，保持 2D 观感
sprite.alpha_cut = ALPHA_CUT_DISCARD         # ⚠️ 仍会硬切羽化边，见下方
# 滤波按贴图来源分流（2026-10-13 M15 起）：真素材 Linear / 程序化占位 Nearest
sprite.texture_filter = LINEAR if not tex.resource_path.is_empty() else NEAREST
```

**真素材 vs 程序化占位贴图（2026-10-13 起）**：

| | 程序化占位贴图 | 从文件加载的真素材 |
| --- | --- | --- |
| 来源 | `Image.set_pixel` 生成（`resource_path` 为空） | `data/*.json` 的 `sprite_path`（`resource_path` 非空） |
| `texture_filter` | `NEAREST`（本来就按像素格生成，Linear 反而糊） | **`LINEAR`**（非像素风用 Nearest 会硬锯齿） |
| 导入参数 | — | `mipmaps/generate=true` · `detect_3d/compress_to=0`（防被自动改成 VRAM 有损压缩） · `compress/mode=0` 无损 · `process/fix_alpha_border=true` |

> ⚠️ **仍待办**：`alpha_cut` 两边都还是 `ALPHA_CUT_DISCARD`，会**硬切 1px 羽化边**。
> 真素材要不要改成 `ALPHA_CUT_DISABLED` 得看实际观感 —— 代价是透明物**不写深度**，
> 多个精灵重叠时可能出现排序闪烁。**先看到渲染效果再定。**

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

## 素材：占位贴图与真素材（M15）

**第一张真素材已接入**（2026-10-13）：`assets/sprites/enemy_slime_{front,iso,side,back}.png` ——
Qwen-Image 2.1 出 2×2 多视角设定图 → [`tools/lora-compare/crop_sheet.py`](../../tools/lora-compare/README.md)
裁成 4 张 128²；`data/enemies.json` 的 `slime.sprite_path` 指向 `_iso`（3/4 俯视）那张，**渲染代码零改动**。

> 接入口径：出图 → 裁切 → 拷进 `assets/sprites/`（命名 `{类别}_{id}_{视角}.png`）→ 填 `data/*.json` 的
> `sprite_path`。⚠️ 4 个视角目前只用 1 张 —— billboard 永远正对相机，多视角要等「方向性精灵」需求出现再接。
> `assets/sprites/` 的 sprite 只有 128²（十几 KB），**直存 git**；走 **Git LFS** 的只有源图 / 概念图
> （`assets/concepts/**`，MB 级）、字体与音频（规则见仓库根 `.gitattributes`）。
> ⚠️ 所以 **MB 级源图必须放 `assets/concepts/`**。许可登记见 [`assets/_LICENSES.md`](../../assets/_LICENSES.md)。

**已接入的真素材（2026-10-13）**：4 个敌人（`slime` / `brute` / `wisp` / `bone_lord`）+ 3 个职业主角
（`warrior` / `mage` / `ranger`），各 4 个视角共 **28 张 128²**，全部取自 1536² 的 2×2 设定图。
实机验证截图存 `tools/lora-compare/images/_game_shot_*.png`（过程产物，**不入库**）。

| 谁 | 路径来源 | 用的是哪一张 |
| --- | --- | --- |
| 敌人 | `data/enemies.json` 的 `archetype.sprite_path`（`enemy.gd::_build_visuals` 读取） | `_iso`（3/4 俯视） |
| 主角 | `data/professions.json` 的 `profession.sprite_path`（`Player._refresh_sprite()` 读取） | `_iso` |

- 主角**转职即时换图**：`set_profession()` 会调 `_refresh_sprite()`；
  ⚠️ 换图必须重算 `pixel_size = SPRITE_WORLD_HEIGHT / 贴图高度` —— 占位贴图 64px、真素材 128px，不重算角色尺寸会差一倍。
- ⚠️ 敌人**必须先 `setup(level, archetype)` 再 `add_child()`**：视觉是在 `_ready()` 里按 `archetype` 建的，
  顺序反了会静默退回占位贴图（见 `AGENTS.md` §3）。
- 尺寸：`sprite_world_height = radius * 2.4`（敌人，Boss 自然更大）/ `SPRITE_WORLD_HEIGHT = 44`（主角）；
  贴图只影响清晰度，不影响世界尺寸（`pixel_size` 按贴图高度反算）。

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

## 自测

```powershell
godot --headless --path . --script res://tests/test_camera.gd
```

覆盖：配置合法性与非法值钳制 / 初始状态（正交、视野与俯角来自 JSON）/ 缩放钳制在区间内 /
旋转步进与角度归一化 + `yaw = 90°` 时足迹 X/Z 互换 / 俯角两端钳制 + 越俯视足迹越深 /
重置回默认 / 含旋转的边界钳制 / 小位移平滑与**大位移瞬移对齐** / 副本内边界切换 / 7 个输入动作都注册。

> ⚠️ 自测里**不能写 `CameraRig` 这个类名**（它所在脚本引用了 `Game`，会让 `--script` 入口
> 编译失败），相机一律通过 `_main.camera` 动态访问。

## 已知限制 / TODO

- [ ] **数值仍需目视校准**：`size` / `tilt_deg` 的当前值是照 2D 版推的（我无法看到渲染结果）。
      现在可以在游戏里调好再抄回 `data/camera.json`（见上「操作」）
- [ ] 地面 / 墙体等**网格**贴图未生成 mipmap，远处可能有轻微摩尔纹（角色精灵已开 mipmaps）
- [ ] 真素材的 `alpha_cut` 仍是 `ALPHA_CUT_DISCARD`（羽化边被硬切）—— 看渲染效果后决定是否改 `DISABLED`
- [ ] 玩家朝向指示仍是几何体（金色长条），接入真美术后可换成精灵
- [ ] 旋转后**阴影方向不变**（`DirectionalLight3D` 是固定朝向）：如果将来要「阳光跟着镜头转」，
      让光的 yaw 跟随相机 yaw 即可
- [ ] 没有中键拖拽平移 / 惯性；俯仰只有固定步进，没有平滑插值
