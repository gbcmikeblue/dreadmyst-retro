# M10 · 地城与 Boss · 出图任务卡

> **里程碑**：M10 地城与 Boss（房间流 + Boss 战）  
> **优先级**：P1（视觉骨架，所有玩法的背景）  
> **预计出图量**：~80 张（3 套 tileset × 25 + 5 张 Boss 概念图）  
> **预计人工后期**：~30h（tileset 切片 + 拼接 + 调整是大头）  
> **状态**：**代码已完成**（2026-10-10，房间流 + Boss 战，美术仍为程序化占位）；**出图待开始**  
> **完成前置**：Forge + 至少 1 个"场景 tileset"LoRA  
> **代码侧已就位**：地城的房间/墙/门/Boss/传送门都可跑，缺的只是 tileset 贴图。
> 接入真贴图时改 `DungeonRoom`（把程序化网格地面换成 tileset UV）与
> `data/enemies.json` 的 `sprite_path`，**玩法代码不用动**。详见
> [`docs/modules/dungeon.md`](../modules/dungeon.md)。

---

## 1. 目标

3 套主题 tileset（**地牢/森林/沙漠**）每套覆盖 4 类 tile（**地面/墙/装饰/陷阱**），每类约 25 个变体。
+ 1 张最终 Boss 概念图（出师表 / 地下城最终 Boss）。

**验收标准**：
- [ ] 3 套 tileset（每套 ~100 tile）出图并切片
- [ ] 1 张 Boss 概念图（SDXL）
- [ ] 至少 1 个地城能完整铺设 tileset
- [ ] 玩家/敌人已接入真实 sprite（填 `data/enemies.json` 的 `sprite_path` + `SpriteFactory.actor_texture`），
      渲染路径不变（见 `docs/modules/render3d.md` §接入真实 sprite）
- [ ] Boss 战有视觉氛围

---

## 2. 资源清单

| # | 资源 | 数量 | 尺寸 | 用途 |
| --- | --- | --- | --- | --- |
| 1 | 地牢 tileset | 1 套（~25 切片） | 1024² 出图 → 切 **64×64** | `world/dungeon_*.tscn` |
| 2 | 森林 tileset | 1 套 | 同上 | `world/forest_*.tscn` |
| 3 | 沙漠 tileset | 1 套 | 同上 | `world/desert_*.tscn` |
| 4 | Boss 概念图 | 1 | 1024×1536 | `assets/concepts/boss_dungeon.png` |
| 5 | 氛围参考图（不进游戏） | 3 | 1024² | 仅供作者参考色板 |

---

## 3. 模型 / LoRA 选择

| 资源类型 | checkpoint | LoRA 关键词 |
| --- | --- | --- |
| 场景 tileset | SD 1.5 + **ControlNet tile** | `isometric tileset`, `dungeon tileset seamless`, `2.5D rpg`, `fantasy forest seamless`, `desert tileset pixel` |
| Boss 概念图 | SDXL | `fantasy boss concept`, `dungeon boss creature` |

> **必装 ControlNet**：SD 1.5 配套 `control_v11f1e_sd15_tile`，SDXL 配套 `sai_xl_tile`。详见 `assets/_PROMPTS.md` §B 注释。

---

## 4. Prompt 草稿

### 4.1 场景 tileset（3 张大图）

模板：`assets/_PROMPTS.md` §B（场景 tileset）

**正向**（替换 `[主题]`）：
```
<lora:场景LoRA名:0.7>, seamless tileset, top-down RPG, 32x32 grid,
[dungeon stone brick / forest grass dirt / desert sand sandstone] tiles,
pixel art, fantasy medieval, orthographic view, game asset, no characters, no UI
```

**负向**：
```
3d, perspective, isometric, characters, watermark, text, signature, blurry
```

**参数**：`1024×1024 · steps 30 · CFG 7 · DPM++ 2M Karras`  
**ControlNet**：上传一张地砖参考（可手画或从已有素材找），Preprocessor = `tile`，Model = `control_v11f1e_sd15_tile`

### 4.2 Boss 概念图

模板：`assets/_PROMPTS.md` §D（Boss 概念图）

**正向**：
```
<lora:boss LoRA名:0.7>, full body boss character, dark fantasy creature,
dramatic pose, atmospheric lighting, concept art, detailed, painterly,
game key art, 2.5D retro MMO style, dungeon overlord
```

**负向**：
```
pixel art, 8-bit, chibi, cute, blurry, low quality, watermark
```

**参数**：`1024×1536 · steps 30 · CFG 7 · DPM++ 2M Karras · SDXL`

---

## 5. 后期处理要点

### 5.1 tileset 切片

1. **Tiled**（免费）：打开 1024² 大图 → New Tileset → Tile size **64×64** → 切片
2. **导出 JSON**：`tileset_dungeon.json`
3. **Godot 导入**：`res://assets/tilesets/dungeon/` → 创建 TileSet 资源 → 指向切片
4. **铺地城**：用 Tiled 编辑房间布局（每个房间 20×20 tile）→ 导出 `.tmx` → 转换或重新铺

### 5.2 Boss 概念图

1. 直接用做战斗场景背景（叠在战斗背景上）
2. 后期加 `CanvasModulate` 调暗 50%，避免抢戏
3. **可选**：用 Real-ESRGAN 2x 放大到 2048×3072（仅当原图细节不够时）

### 5.3 与当前 2.5D 渲染的衔接（M9 已完成，方案已变更）

> ⚠️ 本节原先写的是 2D 时代的「`scale.y` 拉扁 + `y_sort`」方案。项目在 **M9 已改为真 3D +
> 固定正交相机 + billboard 精灵**，`scale.y` / `y_sort` **不再适用**。

地城地面应改用 3D 网格（`PlaneMesh` / 自建 `ArrayMesh`）铺贴，相机与坐标转换沿用现有约定：

- 坐标：`Game.world(v2)` / `Game.plane(v3)`（XZ 为地面，Y 为高度）
- 相机：固定正交 + 俯角 `CAMERA_TILT_DEG`，详见 `docs/modules/render3d.md`
- 贴图导入设 **Linear + Mipmaps**（非像素风；代码当前是 `Sprite3D.texture_filter = TEXTURE_FILTER_NEAREST`，待实测后改）

---

## 6. 关联代码文件

| 文件 | 状态 | 改动 |
| --- | --- | --- |
| `data/dungeon.json` | ✅ 已建 | 房间流布局 / 每房怪数 / Boss / 通关奖励 / 配色 |
| `scripts/data/dungeon_def.gd`、`dungeon_registry.gd` | ✅ 已建 | 地城定义 + 注册表（含房间平面几何派生） |
| `scripts/world/dungeon.gd` | ✅ 已建 | 房间流 / 清房开门 / Boss 房 / 通关奖励 / 出入口 |
| `scripts/world/dungeon_room.gd` | ✅ 已建 | 单间房：3D 地面 + **layer 1 碰撞墙** + 门洞 |
| `scripts/world/dungeon_door.gd` | ✅ 已建 | 房间之间的门（清房后开） |
| `scripts/world/portal.gd` | ✅ 已建 | 传送门（靠近提示 + `F` 交互） |
| `data/enemies.json` | ✅ 已改 | 新增 `bone_lord`（`is_boss = true`、`spawn_weight = 0`） |
| `scripts/actors/enemy.gd` | ✅ 已改 | Boss 免疫击退 + 大血条 + 脚下光环（外观仍可接 `sprite_path`） |
| `scripts/actors/player.gd` | ⬜ 待做 | 玩家的 `sprite_path` 尚未数据驱动（仍是硬编码程序化贴图） |
| `scripts/main.gd`、`scripts/ui/hud.gd`、`scripts/core/game.gd` | ✅ 已改 | 进出地城流程 / Boss 血条 / 房间进度 / 交互提示 / 边界切换 |
| `tests/test_dungeon.gd` | ✅ 已建 | 6 用例：数据层 / 野外池 / 进入 / 清房 / Boss / 离开 |
| `scripts/world/boss_arena.gd` | ⬜ 待做 | Boss 战**独立场景**尚未做（当前 Boss 房就是最后一个房间，背景是地城本身） |
| ~~`scenes/world/dungeon/dungeon_01.tscn`~~ | ❌ 废弃 | 本项目约定只有 `main.tscn` 一个场景（AGENTS.md §2.4），地城由代码构建 |

---

## 7. 验收清单

- [x] **1 个完整地城能跑通（3 个房间 + 清房开门 + Boss 房）** —— 代码完成，美术待接入
- [x] **Boss 战可打**（骸骨领主：免疫击退 + HUD 大血条 + 通关奖励）
- [x] **地城进出口**（竞技场传送门 `F` 进入，地城内原路返回 / 清空后开出口）
- [ ] 3 套 tileset 出图
- [ ] 3 套 tileset 在 Tiled 中切片为 **64×64**
- [ ] 3 套 TileSet 资源导入 Godot，替换 `DungeonRoom` 的程序化网格地面
- [ ] 玩家/敌人 sprite 已切 2.5D 视角（`data/enemies.json` 的 `sprite_path`）
- [ ] Boss 概念图出图
- [ ] Boss 战场景有视觉氛围
- [ ] `_LICENSES.md` 已登记所有用到的 LoRA + ControlNet
- [ ] git 提交 + push

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版 |
| 2026-10-09 | **编号由 M9 改为 M10**（原 M9 已被已完成的「2.5D 渲染」占用），与 `docs/roadmap.md` 统一 |
| 2026-10-09 | 修正过期内容：删除 2D 时代的 `scale.y` + `y_sort` 方案，改为真 3D billboard / 3D 地面网格 |
| 2026-10-10 | **代码部分完成**（房间流 / 真墙体碰撞 / Boss 房 / 奖励 / 传送门 + 自测 + 文档）：地城改为纯代码构建，废弃卡片里的 `dungeon_01.tscn`；tileset 与 Boss 概念图**仍未开始** |
| 2026-10-10 | **风格基线改为"不做像素风"**：tileset 切片由 32×32 上调为 **64×64**（资源清单表 / Tiled 步骤 / 验收项三处）；导入滤波改 `Filter = Linear` + `Mipmaps = on` |
