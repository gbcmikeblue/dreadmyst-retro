# 美术素材许可证登记表

> 每次新增素材/LoRA/模型，**当次**登记一行。发布前用此文件核对所有 license。
> 详细工作流见 `docs/reference/ai-asset-generation.md`。
> 配套 Prompt 速查见 `assets/_PROMPTS.md`，任务卡片见 `docs/tasks/`。

---

## 1. 模型 / LoRA（出图用）

> 状态：`已部署` = 文件存在且 SHA256 已校验；`下载中` = 用户本地下载未完；`已废弃` = 已删除或不再使用。

| 名称 | 类型 | 来源 URL | 用途 | License | 商用 | 作者署名 | 状态 | 下载日期 | 文件大小 | 放置路径 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SDXL base 1.0 | checkpoint | https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0 | SDXL 出图（角色立绘/Boss/概念图） | Open RAIL-M | ✓ | 否 | 已部署 | 2026-10-09 | 6.46 GiB | `D:\AI\models\checkpoints\sd_xl_base_1.0.safetensors` |
| SD 1.5 pruned-emaonly | checkpoint | https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5 | SD 1.5 出图（sprite/tileset/icon 主力） | Open RAIL-M | ✓ | 否 | 下载中 | 2026-10-09 | 4.27 GB（目标） | `D:\AI\models\checkpoints\v1-5-pruned-emaonly.safetensors` |
| _待填_ | LoRA | _Civitai URL_ | _角色/场景/物品/UI_ | _Open RAIL-M / CC-BY-SA / 等_ | _是/否_ | _是/否_ | _待部署_ | _YYYY-MM-DD_ | _X MB_ | `D:\AI\models\lora\子目录\xxx.safetensors` |

> **如何快速填这一行**：
> 1. 在 Civitai 找 LoRA 时，**同时复制 LoRA 页面 URL + License 字段**（页面右下角"License"下拉）；
> 2. 文件名按"用途分类 + 描述"命名（如 `角色_topdown_pixel_v1.safetensors`）；
> 3. 放到 `D:\AI\models\lora\角色\` / `场景\` / `物品\` / `UI\` 对应子目录；
> 4. 在本表加一行 → 提交 git → 启动 Forge 校验。

## 2. 直接使用的素材（图、纹理、spritesheet 等）

| 名称 | 来源 | 用途 | License | 作者署名要求 | 项目内路径 |
| --- | --- | --- | --- | --- | --- |
| _待填_ | _URL/作者_ | _敌人/装备/UI_ | _Open RAIL-M / CC0 / 等_ | _是/否_ | `res://assets/...` |

---

## 3. License 速查

- **Open RAIL-M**（Stable Diffusion 默认）：允许商用，无须署名（默认勾选）
- **CC-BY-SA**：允许商用，**必须署名作者**，衍生作品需同 license 发布
- **CC-BY-NC**：仅限非商用，**禁止**发布商业项目
- **CC0 / Public Domain**：完全无限制
- ⚠️ **"待填"或空白**的素材**不得使用**（发布前清空本文件所有待填行）

---

## 4. 登记 SOP（每次新加素材必做）

1. **下载前**先打开本文件，复制一行模板（`模型/LoRA` 表的第 3 行）。
2. **下载中**把表格新行的 6 个必填项填好：
   - `来源 URL`：Civitai 页面 / Hugging Face 仓库链接
   - `License`：从 Civitai 页面右下角"License"读，**不要凭印象写**
   - `商用` / `作者署名`：看 License 字段的"Use the model without crediting" / "Sell generated images"选项
3. **下载完成**后填：
   - `状态` = `已部署`
   - `下载日期` = `YYYY-MM-DD`
   - `文件大小` = 实际下载大小
   - `放置路径` = 完整文件路径
4. **git 提交**：
   ```bash
   git add assets/_LICENSES.md
   git commit -m "licenses: add <LoRA名> (<用途>)"
   ```
5. **启动 Forge 出图前**重新读本表一次，确认没有"待填"行的素材被引用。

---

## 5. 校验记录（已校验的模型 SHA256）

> 本节只登记**已用 hash 校验完整下载**的模型。
> 校验方法：Forge 起来后用 Python（`hashlib.sha256()`）算，或用 `certutil -hashfile`。

| 名称 | SHA256 | 校验日期 | 备注 |
| --- | --- | --- | --- |
| SDXL base 1.0 | _待 Forge 起来后回填_ | _YYYY-MM-DD_ | 之前已通过 `download_models.ps1` 做大小/字节校验 |
| SD 1.5 pruned-emaonly | _待下载完成后回填_ | _YYYY-MM-DD_ | |

---

## 6. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版：登记 SDXL base 1.0（已部署）+ SD 1.5（下载中），加 SOP + License 速查 |
