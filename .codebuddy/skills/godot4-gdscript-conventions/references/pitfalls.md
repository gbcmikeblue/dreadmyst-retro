# 陷阱清单（症状 → 成因 → 处置）

本项目实际踩过或极易踩的坑。遇到「代码看起来没错但行为不对」时先查这里。

---

## 1. InputMap / 输入

### 1.1 键盘完全失灵，但鼠标点击正常

- **症状**：`WASD` / 空格全无反应，鼠标左键攻击却正常。
- **成因**：只注册了 `physical_keycode`。远程桌面 / 虚拟机 / 部分键盘驱动**不提供物理键码**，
  于是 `InputMap.event_is_action()` 匹配失败，该动作彻底收不到输入。
  注意实测环境下 `event_is_action()` **只认 `physical`**，所以不能反过来只注册 `keycode`。
- **处置**：`physical_keycode` 与 `keycode` 两套都注册（见 `scripts/core/game.gd::_action()`）。
- **排查**：跑 `godot --headless --path . --script res://tests/test_input_move.gd`，
  看 `[A]` 段（动作→移动）与 `[B1]/[B2]/[B3]` 段（按键→动作）分别是否通过，即可定位断在哪一环。

### 1.2 暂停后 UI 点不动 / 快捷键失效

- **成因**：暂停时 `CanvasLayer` 上的节点默认也停止 `_process` / `_input`。
- **处置**：该层设 `process_mode = PROCESS_MODE_ALWAYS`。

### 1.3 点过一次按钮后，空格/回车会重复触发按钮而不是游戏动作

- **成因**：`Button` 获得焦点后，空格/回车被当作 UI 确认键吞掉。
- **处置**：`button.focus_mode = Control.FOCUS_NONE`。

---

## 2. GDScript 语言层

| 陷阱 | 说明 |
| --- | --- |
| `randi_range(a, b)` | **包含两端**（与 `randf_range` 一致）。写 `randi_range(1, 3)` 会出 1/2/3。 |
| `move_and_slide()` 后改 `velocity` | 无效，必须在调用**之前**设好。 |
| `Dictionary.values()` | 返回 `Array`，不是 keyed dict；需要键值对时用 `for k in dict:`。 |
| `JSON.parse_string` | 失败返回 `null`，**必须**校验 `typeof(x) == TYPE_DICTIONARY` 再取值。 |
| 静态类型 + `get_nodes_in_group` | 返回值被推断为 `Array[Node]`，直接 `nodes[0].hp` 会报「找不到成员」。先赋给**无类型 `Array`** 再迭代，或用 `has_method()` 守卫。 |
| 未使用的参数 | 用 `_` 前缀（如 `_rarity_key`）避免 warning。 |
| `snappedf` | 小数词条（如 `crit`）用它取两位，避免 `0.030000001` 这种值。 |

---

## 3. Godot 3D 节点

| 陷阱 | 症状 | 处置 |
| --- | --- | --- |
| 节点未入树就写 `global_position` | `Condition "!is_inside_tree()" is true` 报错，位置不生效 | **先 `add_child()` 再写位置**（`Camera3D` 尤其明显） |
| `Camera3D` 没有 `limit_*` | 无法像 `Camera2D` 那样限制视野 | 手写焦点钳制，见 `scripts/main.gd::_clamp_focus()` |
| `CharacterBody3D` 默认受重力 | 顶视角角色会往下掉 / 贴地 | `motion_mode = MOTION_MODE_FLOATING` |
| billboard 精灵投射阴影 | 阴影变成一条薄片，很丑 | 关闭精灵投影，脚下放平躺的深色圆盘当影斑 |
| `TorusMesh` / `PlaneMesh` / `CylinderMesh` 朝向 | 以为要旋转，其实不用 | 它们**默认就躺在 XZ 平面** |
| 朝向型网格方向反了 | 弧光/指示条指向与移动方向不一致 | 本地前方统一为 **+X**，用 `node.rotation.y = -facing.angle()` |
| 顶点/纹理模糊 | 像素风被线性插值糊掉 | `texture_filter = TEXTURE_FILTER_NEAREST` |

---

## 4. 运行 / 验证

### 4.1 克隆仓库后满屏 `Parse Error: Could not find type "Player"`

- **成因**：Godot 的 `class_name` 全局类名缓存在 `.godot/global_script_class_cache.cfg`，
  而 `.godot/` 被 gitignore，新克隆的仓库里没有这份缓存。
- **处置**：先跑一次 `godot --headless --import --path .`（或用编辑器打开一次）。
  **这不是代码错误**，不要为此改代码。

### 4.2 终端里跑 `godot.exe` 看不到任何输出

- **成因**：标准版 exe 是 GUI 子系统程序，不带控制台。
- **处置**：用 `godot_console.exe`（或 `*_console.exe` 变体）。

### 4.3 用低于 4.7 的引擎导入后 `icon.svg.import` 被改写

- **成因**：`project.godot` 声明 `4.7`；低版本引擎会删掉它不认识的键
  （`compress/uastc_level`、`compress/rdo_quality_loss`、`process/channel_remap/*`）。
- **处置**：验证完执行 `git checkout -- icon.svg.import` **还原**，
  不要把引擎降级产生的改动提交上去。

### 4.4 冒烟测试退出时报 `ObjectDB instances leaked at exit`

- **成因**：测试脚本 `quit()` 时未释放 `main.tscn` 实例，属测试写法所致。
- **判定**：与游戏代码无关；主场景自身 900 帧运行**无此警告**。不要为此改游戏代码。

### 4.5 冒烟测试里 `player.hp = 0.0`

- **成因**：`test_smoke_3d.gd` 把 `Engine.time_scale` 设为 30（300 帧 ≈ 150 秒游戏时间），
  且不注入任何输入（玩家不攻击），于是玩家被敌人打至阵亡。
- **判定**：**预期行为**，不是回归。

### 4.6 PowerShell 里 git 命令报 `RemoteException`

- **成因**：git 把进度信息写到 stderr，而 PowerShell 5.1 把 stderr 当作错误流。
- **判定**：看 `$LASTEXITCODE` 与实际输出行（如 `- [deleted] xxx`）。退出码 0 即成功。
