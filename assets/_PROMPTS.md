# 美术出图 Prompt 速查

> 出图时**直接复制下面整块代码框**（含负向 prompt），粘贴到 WebUI 即可。
> 完整文档（含参数解释、显存纪律、后期流程）见 `docs/reference/ai-asset-generation.md` §4。
> 任务清单见 `docs/tasks/`，许可证见 `assets/_LICENSES.md`。

**使用规则**：
1. `<lora:xxx:0.7>` 改成实际加载的 LoRA 名（`assets/_LICENSES.md` 查）；
2. `[sword/axe/potion/helmet]` 这种 `[a/b/c]` 选一个替换；
3. 第一次出图后把真实参数 + seed 回填到"已验证版本"区。

---

## A. 俯视角角色 sprite（SD 1.5 + 角色 LoRA）

**用途**：主角、敌人、NPC 的行走/待机/攻击帧。  
**出图尺寸**：512×512  
**后期**：Aseprite 居中对齐 → 透明背景 → 切帧 → 拼成 spritesheet → 喂 `scripts/actors/`

**正向**：
```
<lora:角色LoRA名:0.7>, top-down view, full body character, single character,
pixel art, 2.5D retro game style, simple background, RPG sprite, game asset,
centered composition, white background, sharp edges
```

**负向**：
```
3d, realistic, photo, blurry, multiple characters, full scene, watermark,
text, signature, cropped, deformed, extra limbs, ugly
```

**参数**：`steps 25 · CFG 7 · DPM++ 2M Karras · seed -1（首次探索）`  
**已验证版本**：_待填（首次出图后回填真实 seed + 备注）_

---

## B. 场景 tileset（SD 1.5 + tileset LoRA + ControlNet tile）

**用途**：地面、墙、装饰等可平铺素材。  
**出图尺寸**：1024×1024（再切 32×32 / 16×16）  
**后期**：Tiled 切片 → 导入 Godot TileSet 资源 → 铺到 `world/`

**正向**：
```
<lora:场景LoRA名:0.7>, seamless tileset, top-down RPG, 32x32 grid,
grass stone dirt path tiles, pixel art, fantasy medieval, orthographic view,
game asset, no characters, no UI
```

**负向**：
```
3d, perspective, isometric, characters, watermark, text, signature, blurry
```

**参数**：`steps 30 · CFG 7 · DPM++ 2M Karras`  
**关键**：启用 **ControlNet tile**（上传一张地砖参考图，让模型学会无缝拼接）
- SD 1.5: `control_v11f1e_sd15_tile`
- SDXL: `sai_xl_tile`

**已验证版本**：_待填_

---

## C. 装备图标（SD 1.5 + 物品 LoRA）

**用途**：武器、护甲、药水、材料等物品图标。  
**出图尺寸**：512×512 → 降采样到 32×32 / 64×64  
**后期**：透明背景 → 降采样 → PNG → `data/loot.json` 的 `icon` 字段

**正向**：
```
<lora:物品LoRA名:0.7>, single game item icon, centered, transparent background,
pixel art style, simple shading, sharp outline, fantasy [sword/axe/potion/helmet],
front view, RPG inventory icon
```

**负向**：
```
3d, realistic, photo, multiple items, character, scene, watermark, text
```

**参数**：`steps 25 · CFG 7 · DPM++ 2M Karras`  
**已验证版本**：_待填_

---

## D. Boss 概念图（SDXL + boss LoRA）

**用途**：Boss 立绘、战斗场景背景、过场插画。  
**出图尺寸**：1024×1536（全身像）或 1024×1024（方图）  
**后期**：直接用，不切。或背景虚化后叠到战斗场景。

**正向**：
```
<lora:boss LoRA名:0.7>, full body boss character, dark fantasy creature,
dramatic pose, atmospheric lighting, concept art, detailed, painterly,
game key art, 2.5D retro MMO style
```

**负向**：
```
pixel art, 8-bit, chibi, cute, blurry, low quality, watermark
```

**参数**：`steps 30 · CFG 7 · DPM++ 2M Karras · 1024×1024`  
**已验证版本**：_待填_

---

## E. 技能图标（SD 1.5 + 物品/UI LoRA）

**用途**：M7 职业技能的图标。  
**出图尺寸**：512×512 → 降采样到 64×64  
**后期**：透明背景 → 降采样 → PNG

**正向**：
```
<lora:UI LoRA名:0.7>, single game skill icon, centered, transparent background,
pixel art style, simple shading, sharp outline, fantasy [fireball/heal/dash/shield/slash/burst],
front view, RPG skill icon
```

**负向**：
```
3d, realistic, photo, multiple icons, character, scene, watermark, text
```

**参数**：`steps 25 · CFG 7 · DPM++ 2M Karras`  
**已验证版本**：_待填_

---

## F. UI 元素（SD 1.5 + UI LoRA）

**用途**：按钮、边框、菜单、提示框等。  
**出图尺寸**：256×256（小元素） / 512×512（边框）  
**后期**：按 Godot UI 风格统一调色（建议从主色派生 5 阶灰度）

**正向**：
```
<lora:UI LoRA名:0.7>, single UI element, centered, transparent background,
pixel art style, sharp outline, fantasy [button/border/frame/icon], front view,
RPG game UI asset
```

**负向**：
```
3d, realistic, photo, multiple elements, character, scene, watermark, text
```

**参数**：`steps 20 · CFG 7 · DPM++ 2M Karras`  
**已验证版本**：_待填_

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

> 单批 1 张 + SD 1.5 ≤ 512² + SDXL ≤ 1024² + 最多 1 个 ControlNet + LoRA 权重和 ≤ 1.5。
> 任何超出 → OOM 黑图，立刻关 WebUI 重启。

## LoRA 权重参考

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
