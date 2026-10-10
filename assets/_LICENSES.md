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
| SD 1.5 pruned-emaonly | checkpoint | https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5 | SD 1.5 出图（sprite/tileset/icon 主力） | Open RAIL-M | ✓ | 否 | 已部署 | 2026-10-10 | 3.97 GB（实际） | `D:\AI\models\checkpoints\v1-5-pruned-emaonly.safetensors` |
| **BG3 Item Icons** | LoRA | https://civitai.com/models/114331?modelVersionId=123588 （作者 Lykon） | **M11 装备图标**（50~100 张）；触发词 `bg3 item icon`；该模型**只有 SD 1.5 一个版本** | Civitai License：`allowCommercialUse = Image / RentCivit / Rent`；`allowNoCredit = True`；`allowDerivatives = True`；`allowDifferentLicense = True` | **✓ 允许**（列表含 `Image`） | 否（`allowNoCredit = True`） | 已部署 | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\bg3_item_icons_v1.safetensors` |
| **Dark and Darker - Portraits 2023** | LoRA | https://civitai.com/models/146048?modelVersionId=162546 （作者 UncleJert，取 name=`SD15` 那版） | **角色 / Boss 立绘**风格；触发词 `dark_and_darker_game_portrait_style`, `low_resolution` | Civitai License：`allowCommercialUse = **RentCivit**`（**不含 `Image`**）；`allowNoCredit = True`；`allowDerivatives = True`；`allowDifferentLicense = False` | **✗ 不允许商用生成图** | 否（`allowNoCredit = True`） | 已部署（**仅限原型/内部参考，发布前必须替换或删除**） | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\dark_and_darker_portraits_v1.safetensors` |
| **Medieval Style Armor Suit** | LoRA | https://civitai.com/models/59925?modelVersionId=67849 （作者 axebro） | **护甲类装备图标 + 角色装备**；触发词 `medieval armor` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\medieval_armor_suit_v1.safetensors` |
| **Creatures Portraits** | LoRA | https://civitai.com/models/31845?modelVersionId=38286 （作者 smereces_ai） | **怪物 / Boss 立绘**；触发词 `a fantz creature` | Civitai License：`allowCommercialUse = Image`；`allowNoCredit = **False**` | **✓ 允许** | **⚠️ 是（必须署名）** | 已部署 | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\creatures_portraits_v1.safetensors` |
| **Creatures Design V1** | LoRA | https://civitai.com/models/31618?modelVersionId=38059 （作者 smereces_ai） | **怪物设计**；触发词 `fantz creature`, `monster` | Civitai License：`allowCommercialUse = Image`；`allowNoCredit = **False**` | **✓ 允许** | **⚠️ 是（必须署名）** | 已部署 | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\creatures_design_v1.safetensors` |
| **Game Icon_Skill_Buff** | LoRA | https://civitai.com/models/86741?modelVersionId=92267 （作者 HuXiangameicon） | **M7 技能图标**（增益/光环类）；触发词 `guangquan(skill icon)`, `aura`, `glowing` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-10 | 72.1 MB | `D:\AI\models\lora\game_icon_skill_buff_v1.safetensors` |
| **Handpainted RPG Icons Style** | LoRA | https://civitai.com/models/6876?modelVersionId=8081 （作者 Nix0npolska） | 图标兜底（手绘 RPG 图标）；触发词 `rpgicondiff` | Civitai License：`allowCommercialUse = Image`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\handpainted_rpg_icons_v1.safetensors` |
| **Medieval Background slider (or de-Modern)** | LoRA | https://civitai.com/models/247828?modelVersionId=286106 （作者 oosayam） | 场景 / **去现代感**；触发词 `Half-timbered Construction` | Civitai License：`allowCommercialUse = Image / RentCivit`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-10 | 3.1 MB | `D:\AI\models\lora\medieval_background_slider_v1.safetensors` |
| **Monsters Attack - Surrounded by monsters** | LoRA | https://civitai.com/models/96018?modelVersionId=102553 （作者 Tomas_Aguilar） | 怪群 / 多怪场景氛围；**无触发词** | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-10 | 36.1 MB | `D:\AI\models\lora\monsters_attack_v1.safetensors` |
| Medieval - CE | LoRA | https://civitai.com/models/754926?modelVersionId=851008 （作者 CreativeEdge） | 通用中世纪风格（兜底）；触发词 `mdvlCE` | Civitai License：`allowCommercialUse = Image / RentCivit`；`allowNoCredit = True` | **✓ 允许** | 否 | ⛔ **未下载**（作者要求登录，`401 Unauthorized`） | — | 345 MB | `D:\AI\models\lora\medieval_ce_v1.safetensors` |
| Knight | LoRA | https://civitai.com/models/299760?modelVersionId=336656 （作者 oosayam） | 骑士（角色/Boss 轻量试错）；触发词 `knight`, `armor` | Civitai License：`allowCommercialUse = Image / RentCivit`；`allowNoCredit = True` | **✓ 允许** | 否 | ⛔ **未下载**（同上） | — | 15 MB | `D:\AI\models\lora\knight_v1.safetensors` |
| Fantasy Knight Armor | LoRA | https://civitai.com/models/320076?modelVersionId=358910 （作者 Ark_Ai） | 奇幻骑士铠甲（角色/Boss）；触发词 `FantasyKnightV1` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent`；`allowNoCredit = True` | **✓ 允许** | 否 | ⛔ **未下载**（同上） | — | 72 MB | `D:\AI\models\lora\fantasy_knight_armor_v1.safetensors` |
| _待填_ | LoRA | _Civitai URL_ | _角色/场景/物品/UI_ | _Open RAIL-M / CC-BY-SA / 等_ | _是/否_ | _是/否_ | _待部署_ | _YYYY-MM-DD_ | _X MB_ | `D:\AI\models\lora\子目录\xxx.safetensors` |

> ⚠️ **许可取值口径修正**（2026-10-10）：Civitai 的许可字段在**模型层级**（`/api/v1/models/{id}` 的
> `allowCommercialUse` / `allowNoCredit` / `allowDerivatives` / `allowDifferentLicense`），**不在**版本层级
> （版本详情只有 `usageControl`，所有模型都是同一个值，用不了）。`allowCommercialUse` 里**必须有 `Image`**
> 才表示"生成的图片可用于商业用途"；只有 `RentCivit` / `Rent` 则表示**不能**商用生成图。
>
> 上表的许可值**全部取自模型层级 API**（模型页右侧 Details 卡片里的 **License** 一栏可复核）；
> 页面若有 API 字段之外的附加条款，以页面为准。
> **`Dark and Darker - Portraits` 因不允许商用，发布前必须换掉**（已由下面这批可商用的替代）。
>
> ✅ **批量筛选口径（2026-10-10 起固定用这条）**：用 `/api/v1/models?query=...&types=LORA&baseModels=SD 1.5`
> 检索（**列表接口也带模型层级许可字段**，一次请求即可筛），只保留 `allowCommercialUse` **含 `Image`** 的；
> 本轮 60+ 个候选里**有 7 个被这一条挡掉**。另发现 2 类要单独排除：
> ①`allowCommercialUse` **为空**（如 `Game Icon_Skill_Healing`，同作者另一条却写着 `Sell`）→ 按未授权处理；
> ② 只有 `RentCivit` / `Rent`（如 Dark and Darker）→ 不能商用生成图。

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
| 2026-10-10 | SD 1.5 pruned-emaonly 状态改为**已部署**（实际 3.97 GB，路径 `D:\AI\models\checkpoints\`）；`D:\AI\models\{lora,controlnet,vae,embeddings}` 目前均为空 |
| 2026-10-10 | 新增 2 个 LoRA：**BG3 Item Icons**（M11 装备图标）+ **Dark and Darker Portraits**（角色/Boss 立绘），各 144.1 MB，经本机代理从 Civitai 下载。**许可字段留「待确认」**——Civitai 新版 API 已不返回许可信息，需人工看模型页回填。`D:\AI\models\lora` 经 junction 挂到 Forge 的 `models\Lora\_D_AI` |
| 2026-10-10 | **按"允许商用"重新筛选并批量下载 10 个 LoRA**（中世纪奇幻方向，风格要求放宽）：7 个已部署（Medieval Style Armor Suit / Creatures Portraits / Creatures Design V1 / Game Icon_Skill_Buff / Handpainted RPG Icons / Medieval Background slider / Monsters Attack），3 个因**作者要求登录（401）**暂缺。修正许可口径：字段在**模型层级**（不是版本层级），判定条件是 `allowCommercialUse` 含 `Image`。**`smereces_ai` 的两条要求署名**（`allowNoCredit=False`） |
