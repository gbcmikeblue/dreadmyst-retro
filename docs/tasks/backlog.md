# 待办清单（跨里程碑 Backlog）

> 这里记**不属于某一张出图任务卡**的待做与未决项。出图卡片见 [README.md](README.md)，
> 里程碑编号以 [`docs/roadmap.md`](../roadmap.md) 为权威。
> **做完一条就把它删掉**，并在文末「变更记录」留一行——本文件只保留"还没做的事"。

---

## 0. 先读：三条当前口径（不读会误判下面所有条目）

| 口径 | 决定（2026-10-10） |
| --- | --- |
| **许可** | 本项目**非商用** → 第三方模型的 `allowCommercialUse` **不再作为筛选硬条件**（含 `RentCivit` / `Rent` / `Sell` / 空值都可用），只排除「明确禁止任何使用」的条目；**署名义务不受影响**（`allowNoCredit = False` 必须署名）。⚠️ **转商用前必须回头复核 `assets/_LICENSES.md` 全部条目** |
| **风格** | **不做像素风**（见 [`assets/_PROMPTS.md`](../../assets/_PROMPTS.md)）→ 走「低分辨率 + 复古观感」平滑手绘路线；即上轮三选一里的 **C 路线**（不引第三方图，纯 AI 出图）。**CC0 像素素材全部出局** |
| **调用方式** | 网页工具**必须自带本地代理**（浏览器直连 ComfyUI `127.0.0.1:8188` 会被同源策略拦，且要能把结果写回磁盘）。`serve.py` 用 `/comfy/*` 反向代理 + `/api/*` 落盘 |
| **生图后端** | **ComfyUI 0.39 + Qwen-Image 2.1**（2026-10-12 换后端、**2026-10-13 SD 系整体删除**）：SD 1.5 / SDXL / 国风3 三个底模、45 个 SD LoRA、ControlNet 与整棵 `D:\AI\models\` **均已移除**（架构不通、LoRA 不可复用）。⚠️ 许可为 **Qwen Research License（研究用途）** → 非商用可用，**转商用需申请**（已登记 `_LICENSES.md`） |
| **题材** | **不转题材，只借风格**（2026-10-12 决定）：内容仍是**中世纪奇幻**，只借梦幻西游方向的**渲染风格（2.5D 高饱和手绘）+ 投影语言（`isometric / orthographic / no perspective`）+ 中式装饰符号**。模板里的 `fantasy medieval dungeon` / `dark fantasy creature` 等题材词**不动**；`guofeng` 块只含装饰 / 工艺词 |
| **运行环境**（2026-10-13 大改） | **torch 2.7.0+cu128 → 2.11.0+cu130**（+ torchvision 0.26.0 / torchaudio 2.11.0），连带：① **comfy-kitchen CUDA 内核已启用**（`disabled: False`，含 `int8_linear` / `dequantize_int8_convrot_weight` / `scaled_mm_nvfp4`）② **DynamicVRAM 已接管**。⚠️ **`--lowvram` 现在是 no-op**（`enables_dynamic_vram()` 的排除列表里没有它）→ 以后调显存要用 `--vram-headroom` / `--reserve-vram`。文本编码器定为 **`qwen3vl_8b_nvfp4.safetensors`（5.87 GiB）**，实测见 §4 |

---

## 1. 待做（有明确动作）

### 1.1 素材管线工具

| ID | 事项 | 依赖 | 优先级 |
| --- | --- | --- | --- |
| **T-03** | 用对比台跑一轮 **基线（无 LoRA）vs 各 LoRA** 体检（每个 LoRA 至少 1 组），产出 `RESULTS.md`，据此决定保留哪些（**这一步只有你能做：需要人眼判断风格**） | T-01 ✅ | **P0** |
| ~~**T-15**~~ | **作废**：Forge 已随 SD 系整体删除（2026-10-13 复核磁盘无残留），启动方式问题不存在了 | — | 作废 |
| ~~**T-16**~~ | **作废**：那 8 个 LoRA 与国风3 底模已随 SD 系整体删除；对比台的 `data/loras.json` 已重写为 Qwen 时代（只留 Turbo LoRA） | — | 作废 |


### 1.2 许可与模型库

| ID | 事项 | 依赖 | 优先级 |
| --- | --- | --- | --- |
| ~~**T-18**~~ ✅ | **已完成（2026-10-13 复核）**：`D:\AI\models`、`stable-diffusion-webui-forge` **均已不存在**，全盘（`D:\AI` + `D:\download`）**无任何 SD 权重残留**；`models-comfy` 只剩 Qwen 三件套 + Turbo LoRA。仓库侧同步清完：删 `_import_results.py` / `data/results.json` / 10 张 SD 测试图，`loras.json`（45 条 SD LoRA）重写，`serve.py` 移除 `/forge` 代理，`app.js` / `index.html` / `prompts.json` 的 SD 口径全部迁到 Qwen | — | 已决 |
| ~~**T-19**~~ ⚠️ **前提已失效（2026-10-13 改判）** | 原结论「w4a8 618 s > int8 395 s，4bit 反量化开销 > 省下的 2.83 GB 搬运」**建立在"文本编码器跑在 CPU"之上**（当时日志：`CLIP/text encoder model load device: cpu`），而 4bit/FP4 的收益本来就在 GPU 张量核上 —— 该前提已被 cu130 升级推翻。**重测（编码器已回 GPU，热态）**：**nvfp4 12 s vs int8 12 s 完全打平**，峰值显存 ~7160 vs ~7280 MiB（噪声内）→ **选 nvfp4 的唯一理由是体积小 2.84 GiB，不是更快**。**w4a8 文件已删**（省 5.88 GiB）。基准脚本保留：`D:\AI\tmp\enc_bench.py` / `nvfp4_vs_int8.py` | — | 已改判 |
| ~~**T-20**~~ ✅ | **已实测结案（2026-10-13）：i2i 接不接都不解决视角 → 不接**。手工跑通官方编辑链路（`LoadImage` → `TextEncodeQwenImage21`（同时给 pos / neg / latent）→ KSampler `denoise` 1.0）：<br>① **保人没问题**：剪影 IoU **0.97** / 画面相关 **0.97**（对照「无底图的纯文生图」只有 0.03 —— 那才是"换人"，也是 A2 之前变脸的原因）；<br>② **但转视角几乎不动**：IoU 0.969~0.972、bbox 宽高比恒为 0.61。换提示词（含删掉自相矛盾的 `preserve the original proportions and silhouette`）、cfg **1→3.5**、步数 **8→25**、挂不挂 Turbo，**结果全部一样**；而同链路「换背景为日落海滩」（官方模型卡示例）**正常生效** → 模型不是听不懂指令，而是**不做整体视角变换**；<br>③ → 视角改走 **A4 一图流**（让模型直接一次画 2×2 格；1024²/1536²/2048² 都稳定出满 4 格；已由此产出 28 张 sprite）或 **T-24 ControlNet-Union**（要更强俯视时）；<br>④ ✅ 顺带实测：i2i **不写透明底声明**会输出 100% 不透明的带背景图 → 透明底必须靠 `transparency` 块 | — | 已决 |
| **T-21** | **测 cfg=4 + 不挂 Turbo（30~40 步）**：验证"负向生效时等距视角能否被遵从"（挂 Turbo 时 cfg=1，负向完全失效）。⚡ **2026-10-13 更新：单张已降到 12~37 s**（原 3~12 分钟）→ **成本几乎为零**；官方 2.1 模板默认 **steps 25 / cfg 1**，Edit-2511 模板的参考表给的是 **steps 40(官方)/20(Comfy)、cfg 4.0**。⚡ **2026-10-13 晚降级**：视角目的已被 **A4 一图流**覆盖（T-20 实测 cfg 1→3.5 对视角无影响）→ 降为「负向在 cfg 2.5~4 下是否有可见收益」的非阻塞实验 | — | P2 |
| **T-22** | **工作流指向 nvfp4**：① ✅ **对比台已改（2026-10-13）**—— `app.js` 的 `refreshComfy()` 把 `S.aux.clip` 排成 **nvfp4 优先**（`S.aux.clip[0]` 是提交图与面包屑共用的取值点；找不到 nvfp4 时自然退回 int8，不会炸）；② ⏳ **GUI 侧仍待**：官方模板 JSON 写死 `qwen3vl_8b_int8_convrot`，且 `image_qwen_image_2_1_t2i.json` 引用本机没有的 **9B 提示词增强器**（≈8.8 GiB）→ 打开后要手改编码器 + 禁用该节点（`refine_prompt` 默认 off），或用「另存为个人工作流」把这两处固化（⚠️ **别改 `site-packages` 里的模板**，升级会被覆盖） | — | P2 |
| **T-23** | **`QwenImage21Cache` 调优**：官方 2.1 模板默认已开（`device=auto, dtype=default`）→ 试 `device=cpu` / `dtype=int8`，看本机（编码器已回 GPU）是省显存还是白加开销 | — | P2 |
| **T-24** | **ControlNet-Union 解视角**（§2「P0 卡住 T-09」的候选路线 (b) 落地）：官方 `qwen_image_2.1_fun_controlnet_union_int8_convrot.safetensors`（**3.5 GiB**，bf16 版 7.0 GiB），本机节点 `QwenImage21FunControlPatch` / `...BlockPatch` 已具备 | — | **P1** |
| ~~**T-25**~~ ✅ | **已完成 2026-10-13**：`tools/lora-compare/README.md` 的「显存 / 速度」章节按实测重写（`--lowvram` 已失效、nvfp4 vs int8 打平 12 s、611 s → 12 s、395 / 618 s 旧数字作废）；「快速开始」补上必须先 `cd` 的说明；目录结构更新为 cu130 + nvfp4 | — | 已决 |
| **T-26** | **角色逐帧动作（挥刀等）** —— 2026-10-13 先只做了**程序化**挥砍（后撤/前冲/挤压/刀光扫过/命中顿帧，见 §4 同名记录），**逐帧未做**。方案已定：billboard 单向 → **一个动作只需一套帧**（挥刀 4 帧 = 1 张 2×2 表，复用 A4 的版式锁定法，新增 **A5「动作分镜表」模板**）；`crop_sheet.py` 加 `--anim` 模式（**脚底基线锚点**，否则挥刀时重心前后移会上下抖）；`Sprite3D` 的 `hframes/vframes/frame` 驱动。⚠️ 两个坑：① `pixel_size` 要按**单格**高度算（`tex.height / vframes`），否则角色缩到一半；② 动作时长要与 `ATTACK_ANIM_TIME`（现 0.30 s）对齐。剩余动作优先级：受击 2 帧 → 死亡 3~4 帧 → 走路 4 帧；**敌人先保持程序化**（4 个敌人若同批做，素材量 ×4） | — | P2 |
| ~~**T-07**~~ | ~~Dark and Darker 去留~~ —— **已作废**：SD 系整体弃用，全部 LoRA 都要删 | — | 作废 |

> ~~✅ **T-05 / T-06 / T-14 已于 2026-10-12 完成并删除**（当时补齐了 45 个 SD LoRA）~~
> → **整条作废**：SD 系已于 2026-10-13 全部删除，这批 LoRA 与相关缺口都不存在了。
> 现在 LoRA 只有 1 个（Qwen 的 Turbo 加速），登记在 `tools/lora-compare/data/loras.json`。

### 1.3 M15 素材接入（主线）

| ID | 事项 | 依赖 | 优先级 |
| --- | --- | --- | --- |
| **T-09** | **M15 素材接入本体**（真实 sprite + 中文字体 + 音频）：代码侧管线已就绪（`data/*.json` 的 `sprite_path` / `icon` + `SpriteFactory` 加载分支），**卡在没有图** | T-03 | **P0** |
| **T-10** | **中文字体选型**：非像素风 → 像素字体出局，改常规 OFL 字体（思源黑体 / 霞鹜文楷 / LXGW），字号不再受 8/10/12px 限制 | — | P1 |
| **T-11** | **出图规模与后期成本重估**：`ai-asset-generation.md` §7 的 ~300 张 / ~60h 是最初按不存在的旧管线估的。**2026-10-13 更新**：出图已不是瓶颈（Qwen 1024² 热态 **12 s/张** → 300 张约 1 小时），**人工后期（平滑降采样 + 对齐 + 调色板收敛）才是**；且 2.1 原生透明底**省掉了抠图**。建议先跑通"1 敌人 + 1 物品"完整链路再修正该表 | — | P1 |
| **T-12** | **代码侧风格切换**（4 处，待 T-03 看实际观感后再定）：`scripts/world/sprite_factory.gd` 的 `TEXTURE_FILTER_NEAREST` → `Linear + Mipmaps`、`ALPHA_CUT_DISCARD` → `ALPHA_CUT_DISABLED`、占位贴图分辨率（`player.gd` / `enemy.gd` 64、`gear_pickup.gd` 32）、`_make_disc` / `_make_gem` 的逐像素硬描边 | T-03 | P2 |
| **T-13** | `alpha_cut` 改成 alpha 混合后，**半透明精灵的深度排序**问题需实测（多个羽化边精灵互遮会闪） | T-12 | P2 |

---

## 2. 未决（需拍板）

| 事项 | 现状 | 选项 |
| --- | --- | --- |
| **生图方案换代的结论**（2026-10-12） | **已定：ComfyUI + Qwen-Image 2.1**。实测：① **风格与画质大幅胜出**（完整中世纪骑士、华丽板甲，远超 SD 1.5 / 国风3）；② **原生 RGBA 透明底成功**（32.8% 全透明像素，**去背问题彻底消失**）；③ **等距 3/4 视角仍未出**（又是正面）；④ ~~单张 3~12 分钟（8GB 显存要来回搬 15.5 GB 权重）~~ → **2026-10-13 已作废**：cu130 升级后单张 **12~37 s**（同一提示词 / 同 8 步 / 同 1024²），详见 §4。⚠️ 注意 ③ 是在 **cfg=1 + Turbo LoRA**（负向完全失效）下测的 → 见 T-21 | ① 先用 **全向 billboard** 的话，正面图可能已经够用（**先查 `sprite_factory.gd`**）② ~~测 T-21~~（2026-10-13：**视角已由 A4 一图流解决**，本项已降级）③ 要更强俯视 → **T-24 ControlNet-Union**（官方补丁仅 3.5 GiB，本机节点已具备）/ 3D 渲染 |
| **M7 是否仍是"风格基线"** | `docs/tasks/README.md` 写着"M7 是后续所有玩法素材的风格基线"，但 M7 的图还没出，而风格基线已改为非像素 | 保持 M7 打样 / 改用对比台先定风格 |
| **3/4 俯视角色怎么出**（**P0，卡住 T-09**）→ ✔️ **已解（2026-10-13）** | ✅ **解法：A4 一图流** —— 让模型一次画 2×2 格（正面 / 3-4 俯视 / 侧面 / 背面），再用 `tools/lora-compare/crop_sheet.py` 裁成 4 张 128² sprite（已接 4 敌人 + 3 职业共 28 张，游戏内验证通过）；**i2i 转视角已实测排除**（见 **T-20**：保人 IoU 0.97，但视角几乎不动，换词 / cfg 1→3.5 / 8→25 步 / 挂不挂 Turbo 全部无效），要更强俯视再上 **T-24 ControlNet-Union**。⚠️ 实测 A4 右上格更接近「3/4 转身 + 轻微俯视」而非强俯视。下面是 SD 时代的排查历史（保留）：<br>**实测 2026-10-12：提示词不是主因**。修好要求块后（上色 ✓ / 不裁 ✓）仍拿不到 3/4 俯视：① img2img 转视角 `denoise` 0.80/0.85/0.90 **三档都没转成**，0.85 以上反而把角色**糊成色块剪影**；② 文生图直接带视角要求 + 抽卡 4 张，抽看的 2 张仍**正面 / 略仰视**。**本机只有原始 SD 1.5 base 与 SDXL base，无任何社区微调底模** → 怀疑是**底模能力**而非模板问题。<br>**③ 改用投影词后（联网查证的事实）**：把相机术语换成 `isometric / no perspective / orthographic` + 负向压 `perspective, vanishing point`，在**原始 base** 上抽 2 张 → 一张正面平视海报、一张俯瞰场景；**再看国风3 底模** → **风格方向解决了**（东方玄幻/高饱和/华丽，A1 立绘质量大幅提升），**但等距视角仍出不来**（仍正面立绘视角） | ① ~~先用 SDXL 重跑同组~~ ② ~~下社区微调底模~~ → **已用国风3 验证：风格 ✓ / 视角 ✗** ③ 视角候选收窄：**(a) 用 isometric 专用 LoRA 或换投影词再试**；**(b) 上 ControlNet（depth/openpose）锁形体**；**(c) 改走 3D 渲染 sprite**（工程本就是 3D + billboard，视角严格可控）。⚠️ 注意：billboard 始终面向相机，所以 sprite 到底要「正面」还是「3/4 俯视」取决于 billboard 模式（Y 轴 billboard 需俯视；全向 billboard 则可直接用正面）—— **动工前先确认 T-12 的实现** |

---

## 3. 已作废（留档，别再提议）

| 项 | 作废原因 |
| --- | --- |
| **DCSS 32×32 tiles**（CC0，3000+ 格） | 不做像素风 → 与基线冲突 |
| **Kenney Tiny Dungeon**（CC0，16×16，130 文件） | 同上，且覆盖不全（缺装备图标 / 法术特效 / Boss） |
| **Ninja Adventure Asset Pack**（CC0，含 Boss / 地砖 / UI / 音乐） | 同上 |
| **缝合像素字体**（OFL-1.1，8/10/12px，全 CJK） | 像素字配平滑手绘会"两张皮" → 改常规 OFL 字体 |
| 「16×16 vs 32×32 格距基线只能选一套」的三选一 | 由"不做像素风"直接终结 |
| `docs/reference/mmo-opensource/intersect-engine.md` 里「其默认美术为复古像素 MMO 通用风，过渡期可直接取用」 | 同上；该条建议已失效 |
| LPC（Liberated Pixel Cup）素材 | 与"不复制 GPL 项目素材"擦边，且是像素风 |

---

## 4. 本次会话已完成（对照用，勿重复劳动）

| 项 | 结果 |
| --- | --- |
| 开源游戏清单筛选 | 结论已登记 `AGENTS.md` §1（约 145 个 → 同构 8 个） |
| ~~SD 1.5 checkpoint~~ | ~~`_LICENSES.md` 状态改为已部署（3.97 GB）~~ → **已从磁盘与登记表删除（2026-10-13）** |
| LoRA 下载（首轮） | 10 个：7 成功 / 3 被登录墙挡住（**后续已全部补齐**，见下行） |
| 风格基线 | 像素风口径已从 `_PROMPTS.md` / `ai-asset-generation.md` / `tasks/README.md` 移除 |
| 许可口径 | `AGENTS.md` §1 新增"非商用 → 放开模型许可门槛 + 保留署名义务" |
| **LoRA 对比台** | [`tools/lora-compare/`](../../tools/lora-compare/README.md) 落地：静态前端 + 本地代理服务 + 提示词库（含历史回退）+ 评分 / 结论 + 一键导出 `RESULTS.md`；端到端验证通过 |
| ~~**LoRA 池**~~ | ~~两轮扩张后磁盘共 45 个 / 5.90 GB~~ → **随 SD 系整体删除（2026-10-13）**，现只剩 1 个 Qwen Turbo LoRA |
| ~~**许可筛选口径**~~ | ~~非商用放过 `allowCommercialUse`~~ → SD LoRA 全部删除后不再适用；现行口径见 `AGENTS.md` §1（非商用 + 署名义务 + 转商用复核） |
| **要求块修正（有效）** | 实测发现"灰阶线稿 + 头顶裁切"**确由提示词造成**并已修：`portrait` 补"不许裁"、`style` 补显式上色词、`commonneg` 压 `monochrome`/`line art`/`sketch` 等 → A1 立绘由**灰阶线稿变上色插画**、裁切消失（提交 `8de0800`）。副作用：风格偏向"可爱卡通"，待调 |
| ~~**ControlNet 可用**~~ | ~~`control_v11f1e_sd15_tile` 已下载~~ → **随 SD 系删除（2026-10-13）**。Qwen 侧的替代是官方 ControlNet-Union 补丁（3.52 GiB，本机节点已具备，见 **T-24**） |
| **实测记录方式** | 出图验证脚本全部走 `tools/lora-compare` 的本地代理（7788 → 7860），并把测试图落在 `images/_*.png`（已 gitignore）；**结论只入文档与提交信息，图不入库** |
| **torch 升 cu130（一石三鸟）** | `torch 2.7.0+cu128 → 2.11.0+cu130`（配 torchvision 0.26.0 / torchaudio 2.11.0，本地 wheel 装入）。**收益不是一档，是数量级**：<br>① `Found comfy_kitchen backend cuda: {... 'disabled': False}`（原来 `True`）→ int8_convrot / nvfp4 的硬件内核启用<br>② `DynamicVRAM support detected and enabled`（原来 `Unsupported Pytorch detected ... Falling back to legacy ModelPatcher`）<br>③ **文本编码器从 CPU 回到 GPU**（`text_encoder_device()` 在 aimdo 启用时返回 GPU）<br>④ **单张 611 s → 12 s（8 步 / 1024² / Turbo LoRA）≈ 50×**<br>⚠️ 代价：`--lowvram` 变 no-op，显存策略改由 DynamicVRAM 管。**备份**：`D:\AI\logs\pip-freeze-20261013-before-cu130.txt`；**回滚**：`pip install --index-url https://download.pytorch.org/whl/cu128 torch==2.7.0+cu128 torchvision==0.22.0+cu128 torchaudio==2.7.0+cu128` |
| **文本编码器选型（nvfp4）** | `qwen3vl_8b_nvfp4.safetensors`（5.87 GiB，252 层 nvfp4 + 2 层 fp8，`QUANT_ALGOS["nvfp4"]` 原生格式）vs `int8_convrot`（8.71 GiB）：**热态 12 s vs 12 s 打平**，峰值显存 ~7160 vs ~7280 MiB。→ **选 nvfp4（省 2.84 GiB 磁盘/内存），速度不亏**。w4a8 已删 |
| **ComfyUI 模板/前端升到官方最新** | `comfyui-workflow-templates 0.11.78` / `-json 0.1.104` / `-core 0.3.369` / `frontend 1.55.14` / `embedded-docs 0.5.13` → 启动日志里那三条「版本低于推荐值」警告消失。**Qwen-Image 2.1 的三个官方模板到位**：`image_qwen_image_2_1_t2i` / `_image_edit` / `_background_removal`。⚠️ 坑：清华镜像**缺** `comfyui-workflow-templates-media-assets-02==0.1.11`（新包未同步），首次 pip 原子回滚 → 需 `--extra-index-url https://pypi.org/simple` 兜底。**备份**：`D:\AI\logs\pip-freeze-20261013-before-templates.txt` |
| **SD 内容整体清除（2026-10-13）** | 用户在"把关于SD的都删除"的口径下要求全清。**磁盘侧复核**：`D:\AI\models`、`stable-diffusion-webui-forge` 均已不存在，全盘无 SD 权重 → **T-18 结案**。**仓库侧**：删 `tools/lora-compare/_import_results.py` + `data/results.json` + 10 张 SD 测试图；`data/loras.json` 45 条 SD LoRA 元数据 → 重写为 Qwen 时代（只留 Turbo LoRA）；`serve.py` 移除 `FORGE` 常量 / `/forge` 反代 / `--forge` 参数；`app.js` 移除 `FORGE`、`baseOf()` 的 SD 分支、`GROUP_BY_PREFIX`（sd15_/sdxl_ 前缀推断）、SD 版错误提示，`refreshForge` 更名 `refreshComfy`；`index.html` 删 SD base 筛选项；`prompts.json` 8 个模板 + 要求块 + 规范整体迁到 Qwen 口径；`assets/_LICENSES.md` 重写（删 56 行 SD 登记 + Civitai 下载口径）；`assets/_PROMPTS.md` 整篇重写为 Qwen 速查 |
| **2.1 官方模板的实际配置（已读出）** | 子图 `Text to Image (Qwen Image 2.1)`：`UNETLoader=qwen_image_2.1_int8_convrot` / `CLIPLoader=qwen3vl_8b_int8_convrot(type=qwen_image)` / `VAELoader=qwen_image_2.1_vae_bf16`（**三件套本机全有**）+ `TextEncodeQwenImage21` + `QwenImage21Cache(device=auto, dtype=default，默认开)` + 第二个 `CLIPLoader` 指向 **9B PE 编码器**（`qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot`，**本机缺** → 需禁用该节点）；`KSampler = steps 25 / cfg 1 / euler / simple`；顶层另有 `ResolutionSelector`（按宽高比 + 百万像素定尺寸） |

---

## 附：已探明的接口事实（做对比台 / 脚本时直接用，别再重查）

> 2026-10-13 更新：下表已从 Forge（SD）换成 **ComfyUI**。

| 项 | 值 |
| --- | --- |
| ComfyUI API | `http://127.0.0.1:8188`（对比台经 `serve.py` 的 `/comfy/*` **同源反代**，避免同源策略） |
| 取可用模型 / 编码器 / VAE / LoRA / 采样器 | `GET /object_info` 的节点输入枚举：`UNETLoader.unet_name` / `CLIPLoader.clip_name` / `VAELoader.vae_name` / `LoraLoader.lora_name` / `KSampler.sampler_name` |
| 提交出图 | `POST /prompt`，body `{"prompt": <图结构>}` → 返回 `prompt_id` |
| 查询进度 / 结果 | `GET /queue`（队列）/ `GET /history/<prompt_id>`（含 `status_str`，`error` 时带报错） |
| 取图 | `GET /view?filename=…&subfolder=…&type=output` |
| 上传底图（图生图用） | `POST /upload/image`（multipart）→ 拿回 name，填进 `LoadImage.image` |
| unet / 编码器 / VAE | 文件名即标识；**没有"切换模型"这一步** —— 每次提交的图里指定 |
| LoRA 名（`LoraLoaderModelOnly.lora_name`） | 文件名去扩展名，如 `qwen_image_2.1_turbo_lora_avg_rank_178_bf16` |
| 文本编码器落在哪个设备 | 日志看 `CLIP/text encoder model load device:`（cu130 + DynamicVRAM 下应为 `cuda:0`） |
| 优化内核是否启用 | 日志看 `Found comfy_kitchen backend cuda: {'disabled': …}`（需 **cu130+** 才为 `False`） |
| 出图存放约定 | 对比台落 `tools/lora-compare/images/`（已 gitignore）；ComfyUI 自身落 `D:\AI\ComfyUI\output\`；归档到 `assets/_wip/<类别>/`（见 [README.md](README.md) 全局规则） |
| 本机 python | 能跑 ComfyUI 的只有 **`D:\AI\venv-comfy\Scripts\python.exe`**（装了 torch）；`D:\AI\python-full\python.exe` 是 base、**没有 torch**，只适合跑纯脚本（如 `serve.py`） |
| 本机 PowerShell | **5.1**（`HttpListener` 异步回调缺 runspace）→ 本地服务**用 python 写**，不要用 PowerShell 起 HTTP 服务 |

---

## 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-10 | 初版：把本轮对话里散落的待办收成 **T-01 ~ T-13** + 4 条未决 + 7 条已作废；顶部固化三条口径（非商用 / 不做像素风 / Forge 无 CORS 必须代理）；文末补「已探明的接口事实」 |
| 2026-10-10 | 修正：删掉「`.tmp-asset-compare/` 临时对比目录」这条未决项 —— 该目录已清理，无需再拍板 |
| 2026-10-12 | 落地 **T-01~T-05、T-08**：新增 **LoRA 对比台**（`tools/lora-compare/`，端到端验证通过）；扩大检索并**下载 16 个新 LoRA**（磁盘共 25 个 / 2.66 GB）；许可筛选口径改为「非商用放开」；LoRA 命名统一。**发现 Civitai 登录墙**（33 次尝试里 17 个 `401`）→ 新开 **T-06**（20 个被挡清单）/ **T-14** / 重写 **T-05** |
| 2026-10-12 | **阶段1 实测 + 要求块修正**：确认"灰阶线稿 / 头顶裁切"是提示词问题并修好（提交 `8de0800`，A1 立绘已上色且不裁切）；**但 3/4 俯视仍出不来** → 新开 **§2 未决项「3/4 俯视角色怎么出」（P0，卡住 T-09）**，记录三组实测证据与 4 条候选路线（SDXL / 社区底模 / 角色 LoRA / 3D 渲染）。另：`control_v11f1e_sd15_tile` 下载并由 Forge 识别（**运行时新增 ControlNet 模型必须重启 Forge**，仅 25s） |
| 2026-10-12 | **清单清理**：删掉已完成的 **T-05 / T-06 / T-14** 与 §2「3 个被挡 LoRA 怎么取」（登录墙的 20 个已全部落盘）；§4 计数由「25 个 / 2.66 GB」更正为 **45 个 / 5.90 GB** |
| 2026-10-12 | **风格基线改为「东方玄幻（梦幻西游向）· 非 Q 版」**：联网查证后把**相机术语换成投影词**（`isometric / no perspective / orthographic`，负向压 `perspective, vanishing point`）；新增 **`guofeng` 国风符号块**；通用负向固定压 `chibi, big head`。落地「国风 / 西游 / 等距」批次（**国风3 底模** + 8 个 LoRA）。**实测结论：国风3 解决了「风格」、没解决「等距视角」** → 更新 §2 该项候选路线，新增 **T-16**（新模型同步进对比台元数据）/ **T-17**（主题材是否转东方玄幻，需拍板） |
| 2026-10-12 | **题材决策落定（T-17 已决）**：**不转题材，只借风格** → 内容仍是中世纪，只借渲染风格 + 投影词 + 中式装饰符号。为此把 `guofeng` 块里的**题材词**（`xianxia immortal aesthetics` / `chinese oriental fantasy theme`）换成**装饰 / 工艺词**（`chinese decorative motifs` / `brocade texture` / `paper lantern glow`）。该决策升为 §0 第 4 条口径；T-17 从 §1 删除 |
| 2026-10-12 | **生图后端换代：SD → Qwen-Image 2.1 + ComfyUI**。§0 新增「生图后端」口径（含 Qwen Research License 提醒）；**SD 系整体弃用**（3 个底模 + 54 个 LoRA + ControlNet，与 Qwen 不通）；对比台后端从 Forge 换到 ComfyUI（提交 `42d9a90`，端到端验证通过），README 重写并写入 **cfg / 步数 / 8GB 显存优化**说明；新增 **T-18**（执行清理 ≈22.5 GB）/ **T-19**（换 w4a8 文本编码器）/ **T-20**（接图生图）/ **T-21**（测 cfg4 无 Turbo 的视角）；**T-07 作废**；§2 记录换代实测结论 |
| 2026-10-13 | **生图环境大升级：torch cu128 → cu130**（2.7.0 → 2.11.0，配 tv 0.26.0 / ta 2.11.0）。§0 新增「运行环境」口径（**`--lowvram` 已失效**，改 DynamicVRAM）。四项验证：kitchen `disabled: False`、DynamicVRAM enabled、编码器回 GPU、**单张 611 s → 12 s（≈50×）**。§4 记录三项收益与回滚命令；**T-25** 记录对比台 README 那节已过期 |
| 2026-10-13 | **文本编码器定为 nvfp4**：`qwen3vl_8b_nvfp4.safetensors`（5.87 GiB）热态 **12 s vs int8 12 s 打平**，峰值显存几乎相同 → 选它的理由是体积小 2.84 GiB。**T-19 改判**（原「w4a8 更慢」的结论建立在"编码器在 CPU"之上，前提已失效）；**w4a8 已删**（5.88 GiB）+ `D:\download` 重复源文件 + cu130 wheel 共回收 ≈13.5 GiB |
| 2026-10-13 | **ComfyUI 模板/前端升到官方最新**（0.11.62→**0.11.78** / 1.53.6→**1.55.14** / 0.5.11→**0.5.13**）→ **Qwen-Image 2.1 三个官方模板到位**（t2i / image_edit / background_removal），2.1 需要的节点（`TextEncodeQwenImage21` / `QwenImage21Cache`）本机 0.39.0 本来就有。记下镜像缺新包的坑；新增 **T-22**（nvfp4 版工作流另存 + 9B PE 编码器缺失）/ **T-23**（Cache 节点调优）/ **T-24**（ControlNet-Union 解视角）；**T-20 / T-21 更新**（编辑模板现成 / 视角实验成本降到秒级） |
| 2026-10-13 | 清理：删 `D:\AI\tmp` 下旧 wheel 与测试脚本以外的过程文件；**基准脚本保留** `D:\AI\tmp\enc_bench.py`（int8 vs w4a8，含冷/热设计）与 `nvfp4_vs_int8.py`（同场 A/B，可加第三档） |
| 2026-10-13 | **对比台前端重构：单页五步 → 两页结构**。页面 A「项目总览」= `prompts.json` 的 8 个生成项目卡片（类别色条 + 阶段徽章 + 建议底模/尺寸/要求块/备注摘要 + 已出图数与最佳评分），点卡片进入页面 B「工作台」（面包屑显示**实际使用的模型 / 编码器 / VAE / 尺寸 / 步数 CFG / 本批对比的 LoRA**，下方完整复用旧 7 个面板）。**所有旧元素 id 原样保留 → 生成/结果/汇总逻辑零改动**；卡片点击走既有的 `#tpl-select` change 绑定。CSS 全量重写为现代深色主题（玻璃拟态顶栏、分段式导航、卡片悬浮、focus 光环、响应式）。顺手修掉一个会"炸图"的坑：`applyDefaults()` 原本让模板的 SD 时代 `base建议` 优先 → Qwen 会被填成 `512²/steps 25/cfg 7`（配 Turbo LoRA 必崩），已改为**现用底模优先** |
| 2026-10-13 | **SD 内容整体清除**（用户要求）：磁盘侧复核无残留 → **T-18 / T-15 / T-16 结案作废**；仓库侧删除 SD 数据与工具、`serve.py` 去掉 Forge 反代、`app.js` / `index.html` / `prompts.json` 迁到 Qwen 口径、`_LICENSES.md` 与 `_PROMPTS.md` 重写。详见 §4 同名条目 |
| 2026-10-13 | **3/4 俯视（P0）结案：走 A4 一图流**。① i2i 这条路线实测排除并 **T-20 结案** —— 保人没问题（剪影 IoU 0.97 / 画面相关 0.97），但**转视角几乎不动**（换词、cfg 1→3.5、8→25 步、挂不挂 Turbo 全一样；同链路「换背景」正常生效 → 模型不做整体视角变换）；② 新增 **A4「角色多视角设定图」模板 + 一键裁切**，由此产出 28 张 sprite 并接入游戏；③ **T-21 降级**（视角目的已被覆盖）、**T-24 保留**为「更强俯视」路线；④ §2 该项标记 ✔️ 已解。顺带清理过程产物：`tools/lora-compare/images/` **57.14 → 7.86 MB**（保留对比台归档 + `_mv_1536` 源设定图 + 实机截图）、删 6 个 i2i 试验脚本（`gen_art.py` / `multiview_test.py` 保留） |
| 2026-10-13 | **M15 技能图标接入（6 张 128²）+ T-22 ①**：E 模板首个落地产物 —— `tools/lora-compare/gen_icons.py` 出图 → `SkillBar` 渲染 → `data/skills.json` 填 6 个 `icon` → `test_data_layer.gd` 加断言。顺带：**对比台编码器默认改成 nvfp4**（`app.js` 里 `S.aux.clip` 排序，**T-22 ① 完成**，GUI 侧另存工作流仍留 P2）、**A2 模板标记废弃**（i2i 已结案 → 用 A3/A4）。⚠️ 记一条实测坑：**2.1 的 VAE 在"透明区"会留 alpha 1~2 的噪声地板**（占画幅 45~66%，四角像素 a1）→ 抠边前必须先掐掉，否则 alpha 包围盒永远等于整幅、永远抠不出边 |
| 2026-10-13 | **M7 挥砍手感（程序化，零素材）**：动作时长 0.18 → **0.30 s**（蓄力后撤 7 / 前冲 13 / 收势回位；**以脚为锚**的挤压拉长）、**伤害挪到挥出帧**（`ATTACK_IMPACT_AT = 0.62` + 0.05 s 命中顿帧，`_tick_attack()` 推进）、弧光升级为**刀光扫过**（`arc_fx` 新增 `width_half_angle` → 22° 窄弧扫过扇形；360° 技能仍整片圆环）、出手瞬间锁定判定朝向（`_attack_dir`）。`test_skills.gd` 新增「按下瞬间不该立刻掉血」断言。逐帧动作方案见 **T-26**。10 条验证命令全过、900 帧 0 ERROR / 0 WARNING + 真窗口抓帧确认（后撤 -4.4 → 前冲 +12.5、压扁→拉长、命中帧顿帧生效） |
