# AI 资产生图方案（Dreadmyst Clone · 2.5D 复古 MMO 风格）

> 本文档定义 **本项目美术素材的 AI 生产工作流**：
> 硬件、模型、LoRA、Prompt、后处理、Godot 集成、版权登记的完整链路。
> 当前阶段从 `D:\AI\` 已搭好的 Forge 环境出发，逐步替换 `scripts/` 里的程序化绘制。

---

## 0. 文档位置与维护

- 路径：`docs/reference/ai-asset-generation.md`
- 配套：
  - `assets/_LICENSES.md` —— 素材许可证登记表（每次新增素材都登记一行）
  - `assets/import_pipeline.md` —— Godot 导入素材的操作规范（待补）
- 重大变更（模型升级、LoRA 替换、流程重构）记录在文末「变更记录」。

---

## 1. 硬件与模型选型

### 1.1 本机配置

| 项 | 值 | 含义 |
| --- | --- | --- |
| GPU | RTX 5070 Laptop **8GB** VRAM（Blackwell, sm_120） | 决定能跑多大的模型 |
| CPU | Ryzen 9 7845HX (12C/24T) | 数据预处理/导出快 |
| 内存 | 32 GB | 留够余量 |
| 磁盘 | D 盘 259G 空闲 | 模型/LoRA/输出都放 D 盘 |

> ⚠️ **8GB 显存是硬约束**。任何"多模型并行""batch>2""开多个 ControlNet"的用法都会 OOM。

### 1.2 选型结论

| 角色 | 模型 | 用途 | 备注 |
| --- | --- | --- | --- |
| **主力** | **SD 1.5**（v1-5-pruned-emaonly） | 角色 sprite、tileset、图标 | 速度最快，LoRA/生态最全，8GB 舒适 |
| **质感提升** | **SDXL base 1.0** | 角色立绘、Boss 概念图、过场 | 显存紧张，分辨率 ≤ 1024² |
| **暂不引入** | Flux.1 / SD 3 Medium | —— | 12GB+ 起，本机跑不动 |

两个 base 模型都放 `D:\AI\models\checkpoints\`。

### 1.3 部署现状

- **Forge 仓库**：`D:\AI\stable-diffusion-webui-forge\`
- **模型**：`D:\AI\models\checkpoints\{v1-5-pruned-emaonly, sd_xl_base_1.0}.safetensors`
- **Python 解释器**：`D:\AI\python-full\python.exe`（3.10.11，完整版，含 venv）
- **pip 镜像**：`%APPDATA%\pip\pip.ini` 指向清华源
- **启动入口**：`D:\AI\stable-diffusion-webui-forge\webui.bat`（自动 `call webui.settings.bat`）
- **首次启动**：会自动建 venv + 装 PyTorch + xformers + 20+ 依赖，约 10–20 分钟
- **WebUI**：`http://127.0.0.1:7860`

详见 `D:\AI\forge-manual.md`。

---

## 2. 素材分类与模型/LoRA 匹配

本项目需要的素材按"用途 × 形态"分类，每类对应**首选模型 + 推荐 LoRA + 建议分辨率**：

| 类别 | 形态 | 数量级 | 首选模型 | 推荐 LoRA 关键词（Civitai 搜） | 出图尺寸 | 用途 |
| --- | --- | --- | --- | --- | --- | --- |
| **角色 sprite** | 俯视角角色，**收口 128×128** | ~20 个敌人 + 主角 | SD 1.5（LoRA 可选） | `top-down character art`, `painted 2d game sprite` | 512×512（单图） | `data/enemies.json` 的 `sprite_path` |
| **怪物 sprite** | 俯视角怪物，**收口 128×128** | ~20 种 | SD 1.5（LoRA 可选） | `monster top-down art`, `painted creature` | 512×512 | `data/enemies.json` 的 `sprite_path` |
| **场景 tileset** | **64×64 地砖（非像素）** | ~15 套 | SD 1.5 + ControlNet tile | `painterly tileset`, `dungeon tileset seamless`, `2.5D rpg` | 1024×1024（再切 64²） | `world/` 场景背景 |
| **装备图标** | **64×64 物品（非像素）** | 50–100 个 | SD 1.5 / SDXL | `rpg item icon`, `painted game icon` | 512² → 平滑降采样 | `data/loot.json` 的 `icon` 字段 |
| **UI 元素** | 图标、按钮、边框（按显示尺寸 1:1） | ~30 个 | SD 1.5（LoRA 可选） | `fantasy game ui`, `painted button` | 256×256 | `ui/` 资源 |
| **技能特效** | 粒子/光效概念图 | ~10 个 | SDXL | `magic effect`, `fantasy spell` | 1024×1024 | 后期切帧 |
| **Boss 概念图** | 全身立绘 | ~5 个 | SDXL | `fantasy boss concept`, `dungeon boss` | 1024×1536 | 战斗场景背景 |
| **场景氛围图** | 整图氛围参考 | 几张即可 | SDXL | `isometric dungeon scene`, `fantasy environment` | 1024×1024 | 氛围参考（不进游戏） |

> **LoRA 不是必需**（2026-10-10 决定）：先**不加 LoRA** 跑通一轮，看 base 模型的实际效果再决定。
> 如果确实需要（固定主角长相 / UI 花纹 / tileset 要求成体系），起步 **1–2 个**即可，不要贪多。
> 不加 LoRA 时一致性改靠：固定 checkpoint + 固定 seed 家族 + **一图多格** + **调色板收敛**
> （见 `assets/_PROMPTS.md` 的「后期统一规范」）。

---

## 3. LoRA 获取与登记

### 3.1 下载流程

1. 打开 <https://civitai.com>，搜索上表里的关键词
2. 筛选条件：
   - **License**：选 "Allow Commercial Use" 或 "CreativeML Open RAIL-M"
   - **Model Type**：`LoRA`
   - **Sort by**：Most Downloaded 或 Highest Rated
3. 点进 LoRA → 下载 `.safetensors`（不是 ckpt）
4. 丢到 `D:\AI\models\lora\<子分类>\`：
   ```
   D:\AI\models\lora\
   ├── 角色\         # 角色 sprite LoRA
   ├── 场景\         # tileset LoRA
   ├── 物品\         # 装备图标 LoRA
   └── UI\           # UI 元素 LoRA
   ```
5. 重启 Forge → 顶部 **LoRA** 标签下拉里能看到

### 3.2 License 登记（**必须**）

每次下载新模型/LoRA，立即在 `assets/_LICENSES.md` 加一行（格式见本文末尾「附录」）。

---

## 4. 文生图工作流（WebUI 操作）

### 4.1 通用参数建议

| 参数 | SD 1.5 | SDXL | 备注 |
| --- | --- | --- | --- |
| **Sampler** | `DPM++ 2M Karras` | `DPM++ 2M Karras` | 通用首选 |
| **Steps** | 25 | 30 | 25 已够；高斯细节需求 30–40 |
| **CFG Scale** | 7 | 7 | 太高会过饱和 |
| **Resolution** | **512×512** | **1024×1024** | 8GB 显存上限 |
| **Batch size** | 1 | 1 | 永远 1 |
| **Seed** | -1（随机）/ 固定值 | 同左 | 复现关键图要固定 seed |

### 4.2 Prompt 模板（针对本项目）

> ⚠️ **风格基线：不做像素风**（2026-10-10 决定，走「低分辨率 + 复古观感」的平滑手绘路线）。
> 下面是**模板的副本**，权威版在 [`assets/_PROMPTS.md`](../../assets/_PROMPTS.md) —— 那里还有
> E（技能图标）、F（UI 元素）两个本文件没有的模板，以及「后期统一规范」。**改一边就要同步另一边。**

#### A. 俯视角角色 sprite（SD 1.5 + 角色 LoRA）

**Prompt：**
```
top-down view, full body character, single character, painted 2D game sprite,
2.5D retro RPG style, soft shading, clean silhouette, simple background,
game asset, centered composition, white background
```

**Negative：**
```
3d render, realistic, photo, blurry, multiple characters, full scene, watermark,
text, signature, cropped, deformed, extra limbs, ugly,
pixel art, 8-bit, hard pixel edges
```

**后处理**（Aseprite/Pixelitor）：居中对齐 → 透明背景 → 切成多帧 → **平滑降到 128×128** → 拼成 spritesheet

#### B. 场景 tileset（SD 1.5 + tileset LoRA + ControlNet tile）

**Prompt：**
```
seamless tileset, top-down RPG, 64x64 grid, grass stone dirt path tiles,
painterly fantasy medieval, orthographic view, soft shading, limited palette,
game asset, no characters, no UI
```

**Negative：**
```
3d, perspective, isometric, characters, watermark, text, signature, blurry,
pixel art, 8-bit, hard pixel edges
```

**启用 ControlNet tile**（关键）：上传任意一张地砖参考图，让模型学会"无缝拼接"。

**后处理**：用 **Tiled** 编辑器（免费）→ 切片导入 Godot TileSet 资源。

#### C. 装备图标（SD 1.5 + 物品 LoRA）

**Prompt：**
```
single game item icon, centered, transparent background, painted 2D game icon,
soft shading, clean outline, fantasy [sword/axe/potion/helmet],
front view, RPG inventory icon
```

**Negative：**
```
3d render, realistic, photo, multiple items, character, scene, watermark, text,
pixel art, 8-bit, hard pixel edges
```

**后处理**：出 512² → **平滑降采样**到 64×64（Lanczos3/Area，**不要** Nearest）→ 转 PNG（透明背景）。

#### D. Boss 概念图（SDXL + boss LoRA）

**Prompt：**
```
<lora:boss LoRA名:0.7>, full body boss character, dark fantasy creature,
dramatic pose, atmospheric lighting, concept art, detailed, painterly,
game key art, 2.5D retro MMO style
```

**Negative：**
```
pixel art, 8-bit, chibi, cute, blurry, low quality, watermark
```

**后处理**：直接用，不切。

> 本模板本来就符合新基线（`painterly` + 负向已排除 `pixel art`），风格基线变更后**无需调整**。

### 4.3 出图后立即归档

每次出图，Forge 会自动存到 `D:\AI\outputs\<日期>\*.png`。
**每周整理一次**到 `assets/_wip/<类别>/<名称>.png`，避免 outputs 爆炸。

---

## 5. 后期处理与 Godot 集成

### 5.1 流程总览

```
Forge 出图 (.png, 1024²)
  → Aseprite：抠图、**平滑降采样**（Area/Lanczos3）、对齐、**调色板收敛**、拼 spritesheet
  → Real-ESRGAN（可选）：2x 放大低清图
  → Tiled：把 tileset 拼成关卡地图，导出 JSON
  → Godot：导入 .png / TileSet / .tscn
  → GDScript：填 `sprite_path` / `icon` 字段（**不改渲染路径**）
```

### 5.2 与现有代码的衔接

> ⚠️ **本节写于 2D 时代（M9 之前），已过期**：现在不是 `_draw()` + `Sprite2D` + `TileMap`，而是
> **真 3D + billboard**（见 [`../modules/render3d.md`](../modules/render3d.md)）。真实接入点只有两处：
> `data/enemies.json` 的 `sprite_path`（`SpriteFactory` 会优先加载它，填了即生效）与 `data/loot.json` 的 `icon`；
> 地砖则替换 `DungeonRoom` 的程序化地面网格。**下表仅作历史参考**，不要照着做。

当前 `scripts/` 全部是 `_draw()` 程序化绘制。引入素材后**逐步替换**，不一次性大改：

| 现有脚本 | 替换策略 |
| --- | --- |
| `scripts/main.gd` | 加一个 `Sprite2D` 节点引用玩家/敌人纹理；绘制代码保留作为 fallback |
| `scripts/actors/player.gd` | `_draw()` 改为 `_ready()` 加载 `SpriteFrames` |
| `scripts/actors/enemy.gd` | 同上，按 `enemy_id` 选贴图 |
| `scripts/world/arena_background.gd` | 改为 `TileMap` 节点 + TileSet 资源 |
| `scripts/world/gear_pickup.gd` | 按 `item_id` 查 icon 贴图 |
| `scripts/ui/hud.gd` | 用 `TextureRect` 替换文字血条；装备图标用物品 icon |
| `data/loot.json` | 加 `"icon": "res://assets/icons/items/<id>.png"` 字段 |
| `data/enemies.json` | 加 `"sprite": "res://assets/sprites/enemies/<id>.png"` 字段 |

> 替换原则：先 1 个敌人 + 1 个物品跑通完整链路 → 再批量替换。

### 5.3 素材导入 Godot 规范

1. **路径**：`res://assets/` 下分 `sprites/`、`tilesets/`、`icons/`、`ui/`、`concepts/`
2. **导入设置**（.import 文件）：**`Filter = Linear`、`Mipmaps = on`**
   （非像素风**不要**选 Nearest，否则边缘硬锯齿）。
   ⚠️ 代码当前是 `TEXTURE_FILTER_NEAREST`（`scripts/world/sprite_factory.gd`），出图跑通后按实际观感二选一
3. **文件命名**：`{类别}_{id}_{姿态}.png`，例：`enemy_slime_idle.png`、`item_sword_iron_icon.png`
4. **版本控制**：素材走 **Git LFS**（每个素材 > 100KB 都要 LFS），否则仓库会爆

---

## 6. 8GB 显存纪律

| 限制 | 推荐做法 |
| --- | --- |
| 单批出图 | 1 张 |
| SD 1.5 分辨率 | ≤ 512×512（特殊需求 ≤ 768） |
| SDXL 分辨率 | ≤ 1024×1024 |
| ControlNet | 最多挂 1 个 |
| 同时挂 LoRA | 2–3 个，权重总和 ≤ 1.5 |
| checkpoint 切换 | 走顶部下拉，自动卸载旧模型 |
| 失败 OOM | 立刻关 WebUI 进程，清理 VRAM，重启 |

显存占用参考（实测）：
- SD 1.5 + 1 LoRA + 1 ControlNet：~5.5 GB
- SDXL + 0 LoRA + 0 ControlNet：~7.5 GB（无余地，必须小分辨率）
- 任何组合超过 8GB 都会黑图

---

## 7. 工作量估算

按当前 Roadmap（背包/技能/地下城/联机），各阶段素材需求（编号以 `docs/roadmap.md` 为准）：

| 阶段 | 需要的素材 | AI 出图量（含废稿） | 人工后期 + 整合 |
| --- | --- | --- | --- |
| M7 职业技能 | 技能图标 ×6 + 特效参考 ×6 | ~30 张 | ~6h |
| M8 属性加点 | UI 元素 ×5 | ~20 张 | ~3h |
| M10 地城与 Boss | tileset ×3 套 + Boss 概念图 ×1 | ~80 张 + ControlNet | ~30h |
| M11 背包/商店 | 装备图标 ×50 + 商店 UI ×1 | ~150 张 | ~20h |
| M14 联机 | 玩家头像框 ×1 + 阵营图标 ×2 | ~15 张 | ~2h |
| **小计** | | ~300 张 | **~60h** |

> 300 张图如果 SD 1.5 每张 10s ≈ 50 分钟；人工是瓶颈。

> ⚠️ **非像素风下上表的人工后期是"下限"**（2026-10-10）：~60h 原本是按"512² 出图 → 最近邻降到 32/64、后期很快"
> 估的。改成平滑手绘路线后，目标分辨率上调（角色 128² / 地砖 64² / 图标 64²），每张都要抠图 +
> 平滑降采样 + 调色板收敛，**实际后期时间会明显增加**；且 8GB 显存下 SDXL 的 1024² 就是上限。
> 先按"不加 LoRA 出 4~6 张、跑通一条完整链路"实测一轮，再回来修正这张表。

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初稿：基于 RTX 5070 + Forge + SD 1.5/SDXL + 清华 pip 镜像 |
| 2026-10-09 | §7 工作量估算表的里程碑编号改为与 `docs/roadmap.md` 一致（M7 / M8 / M10 / M11 / M14） |
| 2026-10-10 | **风格基线改为"不做像素风"**（保留低分辨率 + 复古观感）：§2 表去掉"32×32 像素地砖 / pixel item icon"与 `pixel` 系列关键词，规格上调为角色 128²、地砖 64²、图标 64²，接口字段改回真 3D 时代的 `sprite_path`；§4.2 A/B/C 模板去像素化并补负向 `pixel art, 8-bit, hard pixel edges`（D 无需改）；§5.1 后期流程改"平滑降采样 + 调色板收敛"；§5.3 导入改 `Filter = Linear` + `Mipmaps = on`；给已过期的 §5.2（2D 时代）加警告；§7 标注人工后期为下限；**LoRA 由"起步必建 3–5 个"改为"非必需"**。同步改了 `assets/_PROMPTS.md` |

---

## 附录 A：`assets/_LICENSES.md` 模板

新建文件，路径 `assets/_LICENSES.md`（项目根 `assets/` 目录）：

```markdown
# 美术素材许可证登记表

> 每次新增素材/LoRA/模型，在此登记一行。发布前用此文件核对所有 license。

## 模型 / LoRA

| 名称 | 来源 URL | 用途 | License | 商用 | 作者署名要求 | 放置路径 |
| --- | --- | --- | --- | --- | --- | --- |
| SDXL base 1.0 | https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0 | SDXL 出图 | Open RAIL-M | ✓ | 否 | D:\AI\models\checkpoints\sd_xl_base_1.0.safetensors |
| SD 1.5 pruned-emaonly | https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5 | SD 1.5 出图 | Open RAIL-M | ✓ | 否 | D:\AI\models\checkpoints\v1-5-pruned-emaonly.safetensors |
| (待填) | | | | | | |

## 直接使用的素材

| 名称 | 来源 | 用途 | License | 作者署名要求 | 路径 |
| --- | --- | --- | --- | --- | --- |
| (待填) | | | | | |
```

---

## 附录 B：常见问题

**Q: SDXL 出图比 SD 1.5 慢很多，正常吗？**
A: 正常。SDXL 2.5x 参数 + 1024² 分辨率，单图 20–40s；SD 1.5 512² 约 8–12s。

**Q: 角色 LoRA 出图角色始终不像，权重怎么调？**
A: `<lora:xxx:0.6>` 起步，0.3=弱影响，0.8=强，1.0=过拟合。低于 0.4 几乎无效果，高于 0.9 会崩坏。

**Q: ControlNet tile 怎么用？**
A: 顶部 tab 切到 ControlNet → 上传一张地砖参考 → Preprocessor 选 `tile` 或 `none`（自己画参考线）→ Model 选 `control_v11f1e_sd15_tile`（SD 1.5）或 `sai_xl_tile`（SDXL）。

**Q: 出图有版权风险吗？**
A: SD 1.5 / SDXL 的 license 允许商用，但**用别人 LoRA 出的图，LoRA 作者的 license 单独算**——必须查 LoRA 页面右下角的 License 字段。
