# 美术出图 Prompt 速查

> 出图时**直接复制下面整块代码框**（含负向 prompt），粘贴到 WebUI 即可。
> 完整文档（含参数解释、显存纪律、后期流程）见 `docs/reference/ai-asset-generation.md` §4。
> 任务清单见 `docs/tasks/`，许可证见 `assets/_LICENSES.md`。

## 风格基线（2026-10-10 决定，取代"像素风"）

**不做像素风**，走「**低分辨率 + 复古观感**」的**平滑手绘**路线。由此三条硬规则：

1. 模板里**不再出现** `pixel art` / `sharp edges`；**负向统一加上** `pixel art, 8-bit, hard pixel edges`
   （防止模型自己往像素风跑）
2. 后期用**平滑降采样**（Area / Lanczos3），**不做**最近邻硬像素化
3. **保留调色板收敛** —— 它原来的作用是"造像素感"，现在改成"让 300 张看起来像一套"，这一条别丢

**目标分辨率（后期收敛点）**：角色 sprite **128×128** · 地砖 **64×64** · 图标（装备/技能）**64×64** ·
UI 元素按显示尺寸 1:1。非像素风下 32×32 装不下细节，比像素风整体上调一档。

**使用规则**：
1. **LoRA 可选**：要用就在提示词**开头**加 `<lora:名字:0.7>`（名字查 `assets/_LICENSES.md`）；
   **不用 LoRA 就什么都不加** —— 一致性改靠：固定 checkpoint + 固定 seed 家族 + **一图多格** + 调色板收敛；
2. `[sword/axe/potion/helmet]` 这种 `[a/b/c]` 选一个替换；
3. 第一次出图后把真实参数 + seed 回填到"已验证版本"区。

---

## A. 俯视角角色 sprite（SD 1.5，LoRA 可选）

**用途**：主角、敌人、NPC 的行走/待机/攻击帧。  
**出图尺寸**：512×512  
**后期**：Aseprite 居中对齐 → 透明背景 → 切帧 → **平滑降到 128×128** → 拼成 spritesheet → 喂 `scripts/actors/`

**正向**：
```
top-down view, full body character, single character, painted 2D game sprite,
2.5D retro RPG style, soft shading, clean silhouette, simple background,
game asset, centered composition, white background
```

**负向**：
```
3d render, realistic, photo, blurry, multiple characters, full scene, watermark,
text, signature, cropped, deformed, extra limbs, ugly,
pixel art, 8-bit, hard pixel edges
```

**参数**：`steps 25 · CFG 7 · DPM++ 2M Karras · seed -1（首次探索）`  
**已验证版本**：_待填（首次出图后回填真实 seed + 备注）_

---

## B. 场景 tileset（SD 1.5 + ControlNet tile，LoRA 可选）

**用途**：地面、墙、装饰等可平铺素材。  
**出图尺寸**：1024×1024（再切 **64×64**）  
**后期**：Tiled 切片 → 导入 Godot TileSet 资源 → 铺到 `world/`

**正向**：
```
seamless tileset, top-down RPG, 64x64 grid, grass stone dirt path tiles,
painterly fantasy medieval, orthographic view, soft shading, limited palette,
game asset, no characters, no UI
```

**负向**：
```
3d, perspective, isometric, characters, watermark, text, signature, blurry,
pixel art, 8-bit, hard pixel edges
```

**参数**：`steps 30 · CFG 7 · DPM++ 2M Karras`  
**关键**：启用 **ControlNet tile**（上传一张地砖参考图，让模型学会无缝拼接）
- SD 1.5: `control_v11f1e_sd15_tile`
- SDXL: `sai_xl_tile`

**已验证版本**：_待填_

---

## C. 装备图标（SD 1.5，LoRA 可选）

**用途**：武器、护甲、药水、材料等物品图标。  
**出图尺寸**：512×512 → **平滑降到 64×64**  
**后期**：透明背景 → 平滑降采样 → PNG → `data/loot.json` 的 `icon` 字段

**正向**：
```
single game item icon, centered, transparent background, painted 2D game icon,
soft shading, clean outline, fantasy [sword/axe/potion/helmet], front view,
RPG inventory icon
```

**负向**：
```
3d render, realistic, photo, multiple items, character, scene, watermark, text,
pixel art, 8-bit, hard pixel edges
```

**参数**：`steps 25 · CFG 7 · DPM++ 2M Karras`  
**已验证版本**：_待填_

---

## D. Boss 概念图（SDXL，LoRA 可选）

**用途**：Boss 立绘、战斗场景背景、过场插画。  
**出图尺寸**：1024×1536（全身像）或 1024×1024（方图）  
**后期**：直接用，不切。或背景虚化后叠到战斗场景。

> 本模板**本来就符合新基线**（`painterly` + 负向已排除 `pixel art`），风格基线变更后无需调整。

**正向**：
```
full body boss character, dark fantasy creature, dramatic pose,
atmospheric lighting, concept art, detailed, painterly,
game key art, 2.5D retro MMO style
```

**负向**：
```
pixel art, 8-bit, chibi, cute, blurry, low quality, watermark
```

**参数**：`steps 30 · CFG 7 · DPM++ 2M Karras · 1024×1024`  
**已验证版本**：_待填_

---

## E. 技能图标（SD 1.5，LoRA 可选）

**用途**：M7 职业技能的图标。  
**出图尺寸**：512×512 → **平滑降到 64×64**  
**后期**：透明背景 → 平滑降采样 → PNG

**正向**：
```
single game skill icon, centered, transparent background, painted 2D game icon,
soft shading, clean outline, [fireball/heal/dash/shield/slash/burst],
front view, RPG skill icon
```

**负向**：
```
3d render, realistic, photo, multiple icons, character, scene, watermark, text,
pixel art, 8-bit, hard pixel edges
```

**参数**：`steps 25 · CFG 7 · DPM++ 2M Karras`  
**已验证版本**：_待填_

---

## F. UI 元素（SD 1.5，LoRA 可选）

**用途**：按钮、边框、菜单、提示框等。  
**出图尺寸**：256×256（小元素） / 512×512（边框）  
**后期**：按 Godot UI 风格统一调色（建议从主色派生 5 阶灰度）

**正向**：
```
single UI element, centered, transparent background, painted fantasy game UI,
soft shading, clean outline, fantasy [button/border/frame/icon], front view,
RPG game UI asset
```

**负向**：
```
3d render, realistic, photo, multiple elements, character, scene, watermark, text,
pixel art, 8-bit, hard pixel edges
```

**参数**：`steps 20 · CFG 7 · DPM++ 2M Karras`  
**已验证版本**：_待填_

---

## 后期统一规范（非像素风版）

| 步骤 | 做法 | 为什么 |
| --- | --- | --- |
| 抠图 | 出图后去背景（Aseprite 魔棒 / RMBG） | billboard 精灵必须有透明边 |
| 降采样 | **Area / Lanczos3 平滑**降到目标分辨率（**不要** Nearest） | 平滑降采样给"低分辨率复古"观感；Nearest 会硬锯齿 |
| 调色板收敛 | 全部素材量化到**同一套 32~48 色**色板 | 这是"看起来像一套"的主要来源，**替代了 LoRA 的一致性作用** |
| 边缘 | 保留 1px 半透明羽化边，**不要**硬切 | 见 `docs/modules/render3d.md` 的 `alpha_cut` 说明 |
| 一图多格 | 一次 1024² 排 4×4 = 16 个图标再切格 | 同批图共享上下文，风格天然一致；做 50~100 个装备图标时最省 |
| 导入 Godot | `Filter = Linear`、`Mipmaps = on`；素材 > 100KB 走 Git LFS | ⚠️ 代码当前是 `TEXTURE_FILTER_NEAREST`（`scripts/world/sprite_factory.gd`），出图跑通后按实际观感二选一 |

---

## 全局参数速查（§4.1 摘要）

| 参数 | SD 1.5 | SDXL |
| --- | --- | --- |
| Sampler | `DPM++ 2M Karras` | 同 |
| Steps | 25 | 30 |
| CFG | 7 | 7 |
| 分辨率 | 512×512 | 1024×1024 |
| Batch size | 1（永远） | 1（永远） |
| Seed | -1 探索 / 固定 复现 | 同 |

## 8GB 显存纪律（一行版）

> 单批 1 张 + SD 1.5 ≤ 512² + SDXL ≤ 1024² + 最多 1 个 ControlNet +（若用 LoRA）权重和 ≤ 1.5。
> 任何超出 → OOM 黑图，立刻关 WebUI 重启。

## LoRA 权重参考（仅在使用 LoRA 时）

| 权重 | 效果 |
| --- | --- |
| 0.3–0.4 | 弱影响（几乎看不出 LoRA 风格） |
| **0.6–0.7** | **推荐起步**（稳定有效） |
| 0.8–0.9 | 强影响（接近过拟合，构图开始崩） |
| ≥ 1.0 | 过拟合（脸/身体畸形） |

---

## 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版：从 `docs/reference/ai-asset-generation.md` §4.2 抽出 A/B/C/D 四模板，新增 E（技能图标）、F（UI 元素） |
| 2026-10-10 | **风格基线改为"不做像素风"**：A/B/C/E/F 去掉 `pixel art` / `sharp edges` / `sharp outline`，负向统一加 `pixel art, 8-bit, hard pixel edges`，改用 `painted 2D game sprite` / `soft shading` / `clean silhouette`；目标分辨率整体上调一档（角色 128²、地砖 64²、图标 64²）；**后期流程从"最近邻像素化"改为"平滑降采样 + 调色板收敛"**，新增「后期统一规范」节；D（Boss）本来就符合新基线，未改内容；**LoRA 改为可选**（不再写进模板，一致性改靠固定 seed 家族 + 一图多格 + 调色板收敛） |
