# M9 · 2.5D 斜俯视 + 地城 + Boss · 出图任务卡

> **里程碑**：M9 2.5D 斜俯视 + 地城 + Boss  
> **优先级**：P1（视觉骨架，所有玩法的背景）  
> **预计出图量**：~80 张（3 套 tileset × 25 + 5 张 Boss 概念图）  
> **预计人工后期**：~30h（tileset 切片 + 拼接 + 调整是大头）  
> **状态**：待开始  
> **完成前置**：Forge + 至少 1 个"场景 tileset"LoRA

---

## 1. 目标

3 套主题 tileset（**地牢/森林/沙漠**）每套覆盖 4 类 tile（**地面/墙/装饰/陷阱**），每类约 25 个变体。
+ 1 张最终 Boss 概念图（出师表 / 地下城最终 Boss）。

**验收标准**：
- [ ] 3 套 tileset（每套 ~100 tile）出图并切片
- [ ] 1 张 Boss 概念图（SDXL）
- [ ] 至少 1 个地城能完整铺设 tileset
- [ ] 玩家/敌人 sprite 已替换为 2.5D 视角（参考 `architecture.md` §4 的 `scale.y` + `y_sort` 方案）
- [ ] Boss 战有视觉氛围

---

## 2. 资源清单

| # | 资源 | 数量 | 尺寸 | 用途 |
| --- | --- | --- | --- | --- |
| 1 | 地牢 tileset | 1 套（~25 切片） | 1024² 出图 → 切 32×32 | `world/dungeon_*.tscn` |
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

1. **Tiled**（免费）：打开 1024² 大图 → New Tileset → Tile size 32×32 → 切片
2. **导出 JSON**：`tileset_dungeon.json`
3. **Godot 导入**：`res://assets/tilesets/dungeon/` → 创建 TileSet 资源 → 指向切片
4. **铺地城**：用 Tiled 编辑房间布局（每个房间 20×20 tile）→ 导出 `.tmx` → 转换或重新铺

### 5.2 Boss 概念图

1. 直接用做战斗场景背景（叠在战斗背景上）
2. 后期加 `CanvasModulate` 调暗 50%，避免抢戏
3. **可选**：用 Real-ESRGAN 2x 放大到 2048×3072（仅当原图细节不够时）

### 5.3 2.5D 视角适配

- 玩家/敌人 sprite 加 `scale.y = 0.7`（拉扁）
- 启用 `y_sort` 节点属性
- 相机加 `position.y` 偏移，让角色脚底对齐 tile 中心

---

## 6. 关联代码文件

| 文件 | 状态 | 改动 |
| --- | --- | --- |
| `scripts/world/tileset_loader.gd` | **新建** | 加载 TileSet 资源 + 铺地城 |
| `scripts/world/dungeon_room.gd` | **新建** | 单个房间（20×20 tile） |
| `scripts/world/dungeon_generator.gd` | **新建** | 房间流（多房间 + 连接） |
| `scripts/actors/player.gd` | 改 | `scale.y = 0.7` + 启用 y_sort |
| `scripts/actors/enemy.gd` | 改 | 同上 |
| `scripts/world/boss_arena.gd` | **新建** | Boss 战场景，挂 Boss 概念图背景 |
| `scenes/world/dungeon/dungeon_01.tscn` | **新建** | 第 1 个地城场景 |

---

## 7. 验收清单

- [ ] 3 套 tileset 出图
- [ ] 3 套 tileset 在 Tiled 中切片为 32×32
- [ ] 3 套 TileSet 资源导入 Godot
- [ ] 1 个完整地城场景能跑通（至少 3 个房间）
- [ ] 玩家/敌人 sprite 已切 2.5D 视角
- [ ] Boss 概念图出图
- [ ] Boss 战场景有视觉氛围
- [ ] `_LICENSES.md` 已登记所有用到的 LoRA + ControlNet
- [ ] git 提交 + push

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版 |
