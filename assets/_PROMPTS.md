# 美术出图 Prompt 速查

> 出图时**直接复制下面整块代码框**（含负向 prompt），粘贴到 WebUI 即可。
> 完整文档（含参数解释、显存纪律、后期流程）见 `docs/reference/ai-asset-generation.md` §4。
> 任务清单见 `docs/tasks/`，许可证见 `assets/_LICENSES.md`。
>
> ⚠️ **本文件是只读速查；可编辑副本在
> [`tools/lora-compare/data/prompts.json`](../tools/lora-compare/data/prompts.json)。**
> 视角 / 风格 / 构图 / 通用负向这四类**要求**现在集中在对比台的【要求 / 规范】页，
> 改一处即对所有模板生效，并带修改历史可回退。改了那边**不会自动回写本文件**，以那份为准。

## 风格基线（2026-10-10 决定，取代"像素风"）

**不做像素风**，走「**低分辨率 + 复古观感**」的**平滑手绘**路线。由此三条硬规则：

1. 模板里**不再出现** `pixel art` / `sharp edges`；**负向统一加上** `pixel art, 8-bit, hard pixel edges`
   （防止模型自己往像素风跑）
2. 后期用**平滑降采样**（Area / Lanczos3），**不做**最近邻硬像素化
3. **保留调色板收敛** —— 它原来的作用是"造像素感"，现在改成"让 300 张看起来像一套"，这一条别丢

**目标分辨率（后期收敛点）**：角色 sprite **128×128** · 地砖 **64×64** · 图标（装备/技能）**64×64** ·
UI 元素按显示尺寸 1:1。非像素风下 32×32 装不下细节，比像素风整体上调一档。

**使用规则**：
1. **优先用可编辑副本**：出图与调参直接在对比台 `tools/lora-compare` 里做（提示词 / 要求 / 参数 / 结果 / 导出都在那里）。
   本文件用于速查，以及"没有工具时手敲"。
2. **提示词是两层**：**模板（内容描述）** + **要求块（视角 / 风格 / 构图 / 负向）**。
   模板上勾选用哪些要求块 —— 改一处要求，所有勾了它的模板一起变。
3. **LoRA 可选**：用就在提示词开头加 `<lora:名字:权重>`（名字查 `assets/_LICENSES.md`；权重 0.7~0.8 起）。
4. `[sword/axe/potion/helmet]` 这种 `[a/b/c]` 选一个替换。
5. **抽卡别硬扛**：一次出 4 张不同 seed 再挑（对比台的「每项出 N 张」），比一张张点快得多。

---

## ⭐ 角色 sprite 的两阶段流程（2026-10-12 修订）

**首选路线**：不要把「3/4 俯视」写进文生图提示词 —— 那是强约束任务，base 模型命中率极低，结果就是反复抽卡。
正确做法分两步：

> ⚠️ **2026-10-12 实测补充（阶段2 没能跑通）**：`denoise` **0.80 / 0.85 / 0.90 三档都没把正面转成 3/4 俯视**，
> 且 0.85 以上反而把角色**糊成色块剪影**；同时「文生图直接带视角要求 + 抽卡 4 张」也没出俯视（仍正面 / 略仰视）。
> 结论指向**底模能力**（本机只有原始 SD 1.5 base，无社区微调底模）→ 新增模板 **A3** 作为并行尝试；
> 两阶段路线**暂不废弃但待重估**。证据与 4 条候选路线见 `docs/tasks/backlog.md` §2「3/4 俯视角色怎么出」。

```
阶段1  🖼 文生图 txt2img  →  出一张满意的角色【立绘】（正面全身、plain background）
        └ 模板 A1：视角要求**故意不写**；一次出 4 张挑一张
              ↓ 把选中的那张设为「底图」
阶段2  🔁 图生图 img2img  →  转成本作要的【3/4 俯视 sprite】
        └ 模板 A2：denoise 0.7 起；正向 = 视角转换要求，负向 = 俯视 / 正面立绘
```

**denoise 档位参考**：

| denoise | 表现 | 用途 |
| --- | --- | --- |
| 0.50–0.60 | 构图几乎不动，只换材质 / 细节 | 微调贴图、换配色 |
| **0.65–0.70** | 视角明显转过去，角色大体特征还在 | **视角转换的推荐档** |
| 0.75–0.85 | 转得最彻底，但**角色长相开始变** | 剪影底图 / 网格底图 |
| ≥0.90 | 基本等于重新生成，底图只剩构图残影 | 只想借个构图 |

**底图要求**（`docs/reference/ai-asset-generation.md` §2 的实测结论，别再踩）：

- **人形剪影底图 → 0.70~0.85 能出正确的单角色**（站姿 / 比例 / 脚位全跟着底图）
- **纯色块底图必须 ≥ 0.65** 才有内容（0.5 档几乎只把透明底刷成白底）
- **圆形底图不能当角色底**：模型把圆环当"画框"，把角色画在圈里
- 菱形底图适合掉落物 / 宝石；**网格底图 0.85 能出可用的地砖**

⚠️ **当前限制**：转视角**会改变角色长相**。
要严格锁定同一角色，需 SD 1.5 的 `depth` / `openpose` ControlNet（各约 1.4GB）在阶段2 锁形体。
> 2026-10-12：已下载 `control_v11f1e_sd15_tile`（1.35 GB，Forge 已识别），但 **tile 是"保持画面结构"用的，
> 既不能锁角色形体、也不解决转视角** —— 别再指望它。
> ⚠️ 另：**运行时新增 ControlNet 模型必须重启 Forge**（模型列表只在启动时扫描，重启仅 25 秒）。

---

## A1. 角色立绘（阶段1 · 文生图，SD 1.5 / SDXL，LoRA 可选）

**用途**：出一张满意的角色**立绘**，作为阶段2 的底图。  
**出图尺寸**：512×512（SD 1.5）/ 1024×1024（SDXL）  
**抽卡**：一次出 4 张不同 seed 再挑（别一张张点）  
**后期**：阶段1 **先不处理** —— 等阶段2 转完视角再一起抠图 / 降采样

**正向**（视角要求**故意不写**，"正面全身"就够）：
```
full body character, standing pose, front view, plain background,
entire figure head to toe, nothing cropped, clear margin around the figure,
colorful painted illustration, warm palette, smooth colors,
2.5D retro RPG style, soft shading, limited palette,
centered composition, simple background, game asset,
single character, clean readable silhouette, equipment clearly readable,
painted 2D game sprite
```

**负向**：
```
multiple characters, two people, full scene, cropped,
monochrome, greyscale, grayscale, line art, sketch, ink outline, black outline, flat color,
pixel art, 8-bit, hard pixel edges, 3d render, photo, watermark, text,
signature, blurry, deformed, extra limbs, ugly
```

**参数**：`steps 25 · CFG 7 · DPM++ 2M · seed -1（本批锁一个 seed 家族）`  
**已验证版本**：_待填_

---

## A2. 视角转换 → 3/4 俯视（阶段2 · **图生图**，SD 1.5，LoRA 可选）

> ⚠️ **不要写 `top-down view`**：本作相机是 **-45° 正交 + billboard**，纯俯视只会得到"只看得到头顶"的图。
> 正确写法是 **3/4 高角度**，并且要把俯视 **写进负向**。
> 这一条已统一放进对比台的【要求 / 规范】页（`视角转换要求` + `视角转换负向`），所有角色 / Boss 模板共用。

**用途**：把阶段1 选中的立绘（或任何角色图）转成游戏要的 3/4 俯视 sprite。  
**输入**：底图（阶段1 的产出），**尺寸跟随底图**。  
**关键参数**：`denoise 0.7` 起手 —— 保人调到 0.65，转不够调到 0.75~0.85  
**后期**：透明背景 → **平滑降到 128×128** → 切帧 → 拼 spritesheet → 喂 `scripts/actors/`

**正向**：
```
three-quarter high-angle view, camera pitched about 45 degrees down, full body,
standing upright, facing the viewer, whole figure inside the frame,
colorful painted illustration, warm palette, smooth colors,
2.5D retro RPG style, soft shading, limited palette,
centered composition, simple background, game asset,
same character, same outfit, same colors, keep the original silhouette,
painted 2D game sprite
```

**负向**：
```
bird's eye view, directly overhead, flat top-down layout,
only the top of the head visible, extreme foreshortening, front view standing portrait,
different character, different outfit,
monochrome, greyscale, grayscale, line art, sketch, ink outline, black outline, flat color,
pixel art, 8-bit, hard pixel edges, 3d render, photo, watermark, text,
signature, blurry, deformed, extra limbs, ugly
```

**已验证版本**：_待填_

**参数**：`steps 25 · CFG 7 · DPM++ 2M Karras · seed -1（首次探索）`  
**已验证版本**：_待填（首次出图后回填真实 seed + 备注）_

---

## A3. 3/4 俯视立绘（**一步出图 · 文生图**，SD 1.5，LoRA 可选）

> 🆕 2026-10-12 新增。**替代路线**：A1→A2 两阶段转视角实测失败后的并行尝试（见上「两阶段流程」的实测补充）。

**用途**：一步到位直接文生图出 3/4 俯视角色，省掉阶段2。  
**出图尺寸**：512×512（SD 1.5）/ 1024×1024（SDXL）  
**抽卡**：**必开**，一次出 4~8 张（视角命中率低，靠数量挑）  
**后期**：透明背景 → 平滑降到 128×128

⚠️ **不要勾 `portrait`（立绘要求）块** —— 它含 `front view`，与俯视直接冲突。  
（拼装 = `viewshift` + `style` + `composition` + **`viewneg`** + `commonneg`，**不含** `portrait`）

**正向**：
```
three-quarter high-angle view, camera pitched about 45 degrees down, full body,
standing upright, facing the viewer, whole figure inside the frame,
colorful painted illustration, warm palette, smooth colors,
2.5D retro RPG style, soft shading, limited palette,
centered composition, simple background, game asset,
single character, clean readable silhouette, equipment clearly readable,
painted 2D game sprite
```

**负向**：
```
bird's eye view, directly overhead, flat top-down layout,
only the top of the head visible, extreme foreshortening, front view standing portrait,
monochrome, greyscale, grayscale, line art, sketch, ink outline, black outline, flat color,
pixel art, 8-bit, hard pixel edges, 3d render, photo, watermark, text,
signature, blurry, deformed, extra limbs, ugly,
multiple characters, two people, full scene, cropped
```

**参数**：`steps 25 · CFG 7 · DPM++ 2M · seed -1（靠抽卡，不是固定 seed）`  
**已验证版本**：_待填_

**已知可优化点**（拿到实测图后按这 5 条改）：

1. `camera pitched about 45 degrees down` 是**相机术语**，对 SD 1.5 偏抽象 → 试**等距词汇**：`isometric view` / `game sprite sheet, isometric rpg`
2. `facing the viewer` 是**正面词** → 可改 `seen from behind` / `back visible`
3. 负向只压了 `front view standing portrait` → 可再压 `eye level, straight-on, side view`
4. `colorful` 与 `limited palette` **互相抵消**，择一
5. 背景压不住（`full scene` 已在负向仍出天空草地）→ `plain background, blank background` 靠前放

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
| 2026-10-12 | **提示词拆成「模板 + 要求」两层**：视角 / 风格 / 构图 / 通用负向 四类要求集中到可编辑副本 `tools/lora-compare/data/prompts.json`（对比台的【要求 / 规范】页可改可存、带历史回退、实时预览拼装结果），本文件降级为只读速查；**更正 A 模板视角写法**（`top-down view` → `three-quarter high-angle view, camera pitched about 45 degrees down`，并把 `bird's eye view / only the top of the head visible` 写进负向）；拼装时对逗号分段**自动去重** |
| 2026-10-12 | **角色 sprite 改为两阶段**：新增「⭐ 角色 sprite 的两阶段流程」一节（denoise 档位表 + 底图要求），原 A 模板拆成 **A1 角色立绘（文生图）** 与 **A2 视角转换 → 3/4 俯视（图生图，denoise 0.7 起）**；A1 里**故意不含任何视角要求**。使用规则补「优先用可编辑副本」「提示词是两层」「抽卡一次出 4 张」 |
| 2026-10-12 | **同步 `prompts.json` + 新增 A3**：① A1/A2 正负向补上「显式上色 + 构图不许裁」的实测修正（`colorful painted illustration, warm palette, smooth colors` / `entire figure head to toe, nothing cropped` / 负向加 `monochrome, greyscale, line art, sketch, ink outline, black outline, flat color`）；② 新增 **A3「3/4 俯视立绘（一步出图 · 文生图）」** —— 两阶段转视角实测失败后的并行路线，**明确不含 `portrait` 块**（其 `front view` 与俯视冲突），并附 5 条已知可优化点；③ 「两阶段流程」节补实测结论（`denoise` 0.80/0.85/0.90 均未转成俯视、0.85+ 糊成色块）；④ 更正「ControlNet 模型为空」→ 已装 `control_v11f1e_sd15_tile`，但 tile **不解决转视角**，且**运行时新增模型必须重启 Forge** |
