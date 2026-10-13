# 美术出图 Prompt 速查（Qwen-Image 2.1）

> ⚠️ **本文件是只读速查副本**。**唯一权威是 `tools/lora-compare/data/prompts.json`**（对比台里改、点保存）
> —— 两边不一致时以 JSON 为准。
> 2026-10-13：SD 1.5 / SDXL 时代的全部内容（模板的 base 建议、512² 尺寸、ControlNet 与 LoRA 权重规则）
> 已随 SD 系整体删除，本文件按 Qwen-Image 2.1 重写。

---

## 0. 出图管线（就一套）

| 环节 | 用什么 |
| --- | --- |
| 前端 / API | ComfyUI 0.39.0（`127.0.0.1:8188`，启动：双击 `D:\AI\启动ComfyUI.bat`） |
| 对比台 | `tools/lora-compare/`（双击 `start.bat` → `http://127.0.0.1:7788/`） |
| 底模 | `qwen_image_2.1_int8_convrot`（7B 视觉生成分支） |
| 文本编码器 | **`qwen3vl_8b_nvfp4`**（备用 `int8_convrot`；两者速度打平，nvfp4 小 2.84 GiB） |
| VAE | `qwen_image_2.1_vae_bf16`（**带 alpha 通道，不可换**） |
| 加速 | `qwen_image_2.1_turbo_lora_avg_rank_178_bf16`（8 步；**必须 cfg=1**） |

---

## 1. 参数纪律（2026-10-13 实测）

| 项 | 值 | 说明 |
| --- | --- | --- |
| 挂 Turbo LoRA | **steps 8 / cfg 1** | cfg>1 会直接崩；此时**负向提示词完全失效** |
| 不挂 LoRA | **steps 25 / cfg 1** | 官方 2.1 模板默认值；想更细 30~40 步 |
| 想让负向生效 | **cfg 2.5~4** | 必须不挂 Turbo —— 这是「要速度」和「要可控」的取舍（backlog T-21） |
| 尺寸 | **32 的倍数**，1024² 舒适 | 2.1 原生最高 2048²，8GB 显存别超过 1024² |
| 单张耗时 | 热态 **12 s**（8 步 / 1024² / Turbo） | cu130 升级前是 611 s |

**`--lowvram` 自 2026-10-13 起已是 no-op**（torch 2.11+cu130 → DynamicVRAM 接管）；
要调显存用 `--vram-headroom` / `--reserve-vram`。

---

## 2. 三条铁律级提示词规则

1. **投影词是硬需求**：`isometric` 放**开头**（权重最高）+ `no perspective` / `orthographic` + `30 degree angle`
   —— 缺一个只会得到「稍微倾斜的 3D 渲染图」；负向必须压 `perspective, vanishing point, tilted camera, wide angle lens, photographic`。
   ⚠️ **不要写相机术语**（`camera pitched about 45 degrees down` 这类是 SD 时代踩过的坑）。
2. **国风要写具体符号，不写抽象词**：`chinese style` / `oriental aesthetics` 模型没学过 →
   写云纹 `ruyi cloud pattern`、玉佩 `jade`、披帛 `silk ribbons`、流苏 `tassel`、描金 `gold trim`（即 `guofeng` 块）。
3. **不要 Q 版**：保持正常头身比 → 通用负向固定压 `chibi, big head, super deformed`。

---

## 3. 全局要求块（`prompts.json → global.要求块`）

| key | 名称 | 类型 | 用途 |
| --- | --- | --- | --- |
| `portrait` | 立绘要求（阶段1） | 正向 | 阶段1 出正面全身立绘（**不要把视角要求塞进来**） |
| `viewshift` | 视角转换要求（阶段2） | 正向 | 阶段2 转 3/4 俯视：`isometric view, 30 degree angle, no perspective, orthographic…` |
| `style` | 风格要求 | 正向 | 2.5D 东方玄幻手绘、高饱和、`rich vivid colors` |
| `composition` | 构图要求 | 正向 | `centered composition, plain background, game asset` |
| `viewneg` | 视角转换负向 | 负向 | 压俯视/正面立绘/透视词 |
| `commonneg` | 通用负向 | 负向 | 灰阶线稿、像素风、照片感、Q 版、水印等（**已删掉 `western fantasy`** —— 与中世纪题材矛盾） |
| `guofeng` | 国风符号 | 正向 | 装饰 / 工艺词 |

拼装顺序：`<lora:名:权重> + 触发词 + [勾选的正向块…] + 模板·要求 + 模板·正向`
负向：`[勾选的负向块…] + 模板·负向`

---

## 4. 项目需要出的图（= 对比台页面 A 的 8 个卡片）

| id | 项目 | 阶段 | 出图尺寸 | 要求块 |
| --- | --- | --- | --- | --- |
| A1 | 角色立绘（阶段1） | 文生图 | 1024² | portrait · guofeng · style · composition · commonneg |
| A2 | 视角转换 → 3/4 俯视 | 编辑（i2i） | 跟随底图 | viewshift · guofeng · style · composition · viewneg · commonneg |
| A3 | 3/4 俯视立绘（一步出图） | 文生图 | 1024² | 同 A2，但**不要勾 `portrait`** |
| B | 场景 tileset | 文生图 | 1024²（切 64²） | guofeng · style · composition · commonneg |
| C | 装备图标 | 文生图 | 1024² → 64² | guofeng · style · composition · commonneg |
| D | Boss 概念图 / 立绘 | 文生图 | 1024² | guofeng · style · composition · commonneg |
| E | 技能图标 | 文生图 | 1024² → 64² | style · composition · commonneg |
| F | UI 元素 | 文生图 | 512²/1024² | style · composition · commonneg |

**透明底**：提示词里写一句 `transparent background / alpha channel` 即可 —— 2.1 的 VAE 是 4 通道，
**原生输出 RGBA**（实测 32~34% 全透明像素），后期抠图可以省掉。

**⚠️ 图生图 ≠ 旧 img2img**：2.1 是**指令式编辑**（官方模板 `denoise` 恒 1.0），「强度」由指令决定，
不是靠 denoise 旋钮 → 要转视角就**在提示词里直说**。对比台目前还没接 i2i（backlog T-20）。

---

## 5. 未解问题：3/4 俯视（P0）

- SD 时代实测：img2img 三档 denoise + 抽卡都没转成；换 Qwen 后**仍未验证**
- 已收窄的候选：① 指令式编辑直说视角（配 `viewshift`）② **ControlNet-Union 补丁**
  （官方 `qwen_image_2.1_fun_controlnet_union_int8_convrot`，3.52 GiB，本机节点已具备，见 T-24）
  ③ 改走 3D 渲染 sprite（工程本就是 3D + billboard，视角严格可控）
- ⚠️ 注意 billboard 始终面向相机：sprite 到底要「正面」还是「3/4 俯视」取决于 billboard 模式

---

## 6. 后期统一规范

1. 平滑降采样（Area / Lanczos3），**不做**最近邻硬像素化（本项目不做像素风）
2. 调色板收敛到同一套 32~48 色 —— 这是「看起来像一套」的主要来源
3. 命名：`{类别}_{id}_{姿态}.png`，例 `enemy_slime_idle.png`、`item_sword_iron_icon.png`
4. 素材走 Git LFS（单文件 > 100 KB）
5. 进游戏前对照 `assets/_LICENSES.md` 确认许可与署名义务

---

## 7. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-10 | 风格基线改为「非像素风」，A–F 模板与 8GB 纪律按 SD 1.5 / SDXL 写 |
| 2026-10-12 | 叠加「东方玄幻（梦幻西游向）」：相机术语换投影词、新增 `guofeng` 符号块 |
| 2026-10-13 | **整篇按 Qwen-Image 2.1 重写**：删除全部 SD 口径（SD 1.5/SDXL 尺寸、ControlNet tile、LoRA 权重规则、去背流程）；补参数纪律、nvfp4 编码器、原生透明底、指令式编辑与 T-21/T-24 |
