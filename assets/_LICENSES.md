# 美术素材许可证登记表

> 每次新增素材/LoRA/模型，**当次**登记一行。发布前用此文件核对所有 license。
> 详细工作流见 `docs/reference/ai-asset-generation.md`。
> 配套 Prompt 速查见 `assets/_PROMPTS.md`，任务卡片见 `docs/tasks/`。

---

## 1. 模型 / LoRA（出图用）

> 状态：`已部署` = 文件存在且 SHA256 已校验；`下载中` = 用户本地下载未完；`已废弃` = 已删除或不再使用。
>
> ⚠️ **SD 系已于 2026-10-13 整体删除**：SD 1.5 / SDXL / 国风3 三个底模、45 个 SD LoRA、
> ControlNet tile 与整棵 `D:\AI\models\` 目录**均已从磁盘移除**（与 Qwen 架构不通、LoRA 不可复用）。
> 它们的历史登记行不再保留 —— 需要追溯请查 git 历史与 §6 变更记录。

**当前唯一在用的出图管线（Qwen-Image 2.1 + ComfyUI）**

| 名称 | 类型 | 来源 | 用途 | 许可原文 | 商用 | 状态 | 登记日期 | 体积 | 本地路径 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Qwen-Image 2.1** | Diffusion(unet) | <https://www.modelscope.cn/models/Comfy-Org/Qwen-Image-2.1>（ComfyUI 官方重打包；原模型 `Qwen/Qwen-Image-2.1`） | 主生成模型（视觉生成分支 7B，**原生 RGBA 透明图**） | **Qwen Research License（研究用途）**：免费下载、个人/技术评估可用；**商用（含电商素材、商业插画）需另行申请授权** | ⚠️ **非商用可用；转商用必须申请** | 已部署 | 2026-10-12 | 6.76 GiB | `D:\AI\models-comfy\diffusion_models\qwen_image_2.1_int8_convrot.safetensors` |
| **Qwen3-VL-8B · nvfp4**（文本编码器，**现用**） | Text encoder | 同上 | 文本编码器（`CLIPLoader` 的 type = `qwen_image`）。**252 层 nvfp4 + 2 层 fp8**，与 int8 版热态速度打平但小 2.84 GiB | 随 Qwen-Image 2.1 一并分发，同上许可 | ⚠️ 同上 | 已部署 | 2026-10-13 | 5.87 GiB | `D:\AI\models-comfy\text_encoders\qwen3vl_8b_nvfp4.safetensors` |
| **Qwen3-VL-8B · int8_convrot**（备用） | Text encoder | 同上 | 备用编码器。⚠️ 官方 2.1 模板 JSON 里默认写的就是它（要换 nvfp4 得在界面上改下拉） | 同上 | ⚠️ 同上 | 已部署 | 2026-10-12 | 8.71 GiB | `D:\AI\models-comfy\text_encoders\qwen3vl_8b_int8_convrot.safetensors` |
| **Qwen-Image 2.1 VAE** | VAE | 同上 | 解码（**带 alpha 通道**，透明底的关键，不可替换成其它 VAE） | 同上 | ⚠️ 同上 | 已部署 | 2026-10-12 | 0.63 GiB | `D:\AI\models-comfy\vae\qwen_image_2.1_vae_bf16.safetensors` |
| **Qwen-Image 2.1 Turbo LoRA** | LoRA | 同上 | 8 步加速。⚠️ **用它就必须 cfg=1，此时负向提示词完全失效** | 同上 | ⚠️ 同上 | 已部署 | 2026-10-12 | 0.85 GiB | `D:\AI\models-comfy\loras\qwen_image_2.1_turbo_lora_avg_rank_178_bf16.safetensors` |
| **ComfyUI 0.39.0** | 出图前端 | <https://github.com/Comfy-Org/ComfyUI> | 出图界面 / API（**仅本机工具，不入仓库**） | GPL-3.0 | — | 已部署 | 2026-10-12 | — | `D:\AI\ComfyUI\comfyui-master` |

> **未下载 / 未启用**（8GB 显存下不建议启用）：
> - 两个「提示词增强器」各 8.82 GiB（`qwen3.5_9b_qwen_image_2.1_pe_t2i / pe_i2i`，9B）—— `refine_prompt` 默认 off
> - ControlNet-Union 补丁 `qwen_image_2.1_fun_controlnet_union_int8_convrot`（3.52 GiB，解 3/4 视角的候选，见 backlog T-24）
>
> ~~`qwen3vl_8b_w4a8`（5.88 GiB）~~ —— **已删除**：2026-10-13 实测 nvfp4 与 int8 打平，w4a8 无用（详见 backlog T-19 改判）。

---

## 2. 直接使用的素材（图、纹理、spritesheet 等）

| 名称 | 来源 | 用途 | License | 作者署名要求 | 项目内路径 |
| --- | --- | --- | --- | --- | --- |
| **AI 出图角色 sprite（4 敌人 + 3 职业主角，各 4 视角，共 28 张，128²）** —— 敌人 `slime` / `brute` / `wisp` / `bone_lord`；主角 `warrior` / `mage` / `ranger` | 本机 **Qwen-Image 2.1** 生成（见 §1）+ 对比台裁切（`tools/lora-compare/crop_sheet.py`）；每张取自 1536² 的 2×2 多视角设定图 | billboard 精灵。敌人走 `data/enemies.json` 的 `sprite_path`，主角走 `data/professions.json` 的 `sprite_path`（当前都只用 `_iso` 那张，其余 3 视角备用） | **随底模**：Qwen Research License（非商用可用；转商用需申请） | 否（自己生成，无第三方作者） | `res://assets/sprites/enemy_{slime,brute,wisp,bone_lord}_{front,iso,side,back}.png`、`res://assets/sprites/player_{warrior,mage,ranger}_{front,iso,side,back}.png` |
| **AI 出图技能图标（6 张，128²）** —— `warrior_slash` 裂颅斩 / `warrior_whirlwind` 旋风斩 / `mage_fireball` 火球术 / `mage_meteor` 陨石术 / `ranger_arrow` 穿刺箭 / `ranger_multishot` 箭雨 | 本机 **Qwen-Image 2.1** 生成（见 §1，E 模板：透明底官方句式 + 图标语言）+ `tools/lora-compare/gen_icons.py` 后处理（去 alpha 噪声地板 → 抠边 → LANCZOS 降到 128²） | 技能栏图标：`data/skills.json` 的 `icon` → `SkillBar._set_icon()`；留空则退回程序化占位（技能名首字） | **随底模**：Qwen Research License（非商用可用；转商用需申请） | 否（自己生成，无第三方作者） | `res://assets/icons/skill_{warrior_slash,warrior_whirlwind,mage_fireball,mage_meteor,ranger_arrow,ranger_multishot}_icon.png` |

> ⚠️ 本项目**不用第三方现成素材**（不做像素风 + 只走 AI 出图）；本表登记的是 **AI 出图产物**，
> 许可**随底模**（见 §1）。每张图要能追溯到生成用的模型与提示词（提示词见 `assets/_PROMPTS.md`）。

---

## 3. License 速查

- **Qwen Research License**（现用底模）：非商用可用；**转商用需向阿里申请授权**
- **GPL-3.0**（ComfyUI 本体）：**仅本机工具使用，不复制其代码、不入仓库**（`AGENTS.md` §1 铁律）
- **CC-BY-SA**：允许商用，**必须署名作者**，衍生作品需同 license 发布
- **CC-BY-NC**：仅限非商用，**禁止**发布商业项目
- **CC0 / Public Domain**：完全无限制
- ⚠️ **"待填"或空白**的素材**不得使用**（发布前清空本文件所有待填行）

---

## 4. 登记 SOP（每次新加素材必做）

1. **下载前**先打开本文件，复制一行模板。
2. **下载中**把必填项填好：`来源 URL`（ModelScope / Hugging Face / Civitai 页面）、`许可原文`（**照抄页面上写的，不要凭印象**）、`商用` / `署名义务`。
3. **下载完成**后填：`状态` = `已部署`、`登记日期`、实际体积、完整路径。
4. **同步两处**：`tools/lora-compare/data/loras.json`（LoRA 才有：用途 / 分组 / base / 触发词 / 署名）+ 本表。
5. **git 提交**：
   ```bash
   git add assets/_LICENSES.md tools/lora-compare/data/loras.json
   git commit -m "licenses: add <模型名> (<用途>)"
   ```
6. **出图前**重新读本表一次，确认没有"待填"行的素材被引用。

---

## 5. 校验记录（已校验的模型 SHA256）

> 只登记**已用 hash 校验完整下载**的模型。校验方法：`certutil -hashfile <文件> SHA256`，
> 或与本文件同目录的下载清单核对。

| 名称 | SHA256 | 校验日期 | 备注 |
| --- | --- | --- | --- |
| Qwen-Image 2.1 (int8_convrot) | _待回填_ | _YYYY-MM-DD_ | 体积已核对（6.76 GiB） |
| Qwen3-VL-8B (nvfp4) | _待回填_ | _YYYY-MM-DD_ | 体积已核对（5.87 GiB）；safetensors 头部已验：252 层 nvfp4 + 2 层 fp8 |
| Qwen3-VL-8B (int8_convrot) | _待回填_ | _YYYY-MM-DD_ | 体积已核对（8.71 GiB） |
| Qwen-Image 2.1 VAE (bf16) | _待回填_ | _YYYY-MM-DD_ | 体积已核对（0.63 GiB） |
| Qwen-Image 2.1 Turbo LoRA | _待回填_ | _YYYY-MM-DD_ | 体积已核对（0.85 GiB） |

---

## 6. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版：登记 SDXL base 1.0（已部署）+ SD 1.5（下载中），加 SOP + License 速查 |
| 2026-10-10 | SD 1.5 pruned-emaonly 状态改为**已部署**（实际 3.97 GB）；新增 2 个 LoRA（BG3 Item Icons / Dark and Darker Portraits），经本机代理从 Civitai 下载 |
| 2026-10-10 | **批量下载 10 个 LoRA**（中世纪奇幻方向）：7 个已部署、3 个被作者登录墙（401）挡住。修正许可口径：字段在**模型层级**，判定条件是 `allowCommercialUse` 含 `Image` |
| 2026-10-12 | **新增「国风 / 西游 / 等距」批次 9 项**（含国风3 底模，**必须署名**）→ 登记行见 git 历史 |
| 2026-10-12 | **生图后端换代：SD → Qwen-Image 2.1 + ComfyUI**。登记 Qwen 三件套 + Turbo LoRA + ComfyUI 本体；SD 系整体弃用 |
| 2026-10-13 | **文本编码器加登记 `qwen3vl_8b_nvfp4`（5.87 GiB）**：252 层 nvfp4 + 2 层 fp8，与 int8 版热态速度打平、体积小 2.84 GiB → 定为现用编码器；**`qwen3vl_8b_w4a8` 删除**（实测无用） |
| 2026-10-13 | **§2 首次登记 AI 出图素材**：粘液怪 4 视角 sprite（`enemy_slime_{front,iso,side,back}.png`，各 128²）—— 本机 Qwen-Image 2.1 生成 + 对比台 `crop_sheet.py` 裁切，**许可随底模**（Qwen Research，非商用）；同时给 `.gitattributes` 加上素材的 **Git LFS** 规则（**按类型 / 目录**圈：源图/概念图 + 字体 + 音频走 LFS，游戏内小图直存） |
| 2026-10-13 | **§2 扩展为 7 套 28 张角色 sprite**：4 敌人（`slime` / `brute` / `wisp` / `bone_lord`）+ 3 职业主角（`warrior` / `mage` / `ranger`），各 4 视角 128² —— 全部由本机 Qwen-Image 2.1 出 2×2 多视角设定图后裁切；主角改为走 `data/professions.json` 的 `sprite_path`（原硬编码为空） |
| 2026-10-13 | **SD 内容整体清除（本文件重写）**：删掉 §1 的 SDXL / SD 1.5 / 45 个 SD LoRA / 国风批次共 56 行登记，以及基于 Civitai 的下载口径整段（登录墙 / `allowCommercialUse` 筛选细则）；§3 速查里的 `Open RAIL-M` 换成 `Qwen Research License`；§4 SOP 去掉 Forge 步骤。**磁盘侧同步核实**：`D:\AI\models`、`stable-diffusion-webui-forge` 均已不存在，全盘无 SD 权重残留 |
