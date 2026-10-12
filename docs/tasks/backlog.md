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
| **调用方式** | Forge 启动**未开 CORS**（`/sdapi/v1/cmd-flags` 的 `cors_allow_origins` 为空）→ **任何网页工具都必须自带本地代理**才能调 Forge API，纯静态页直连必然失败 |

---

## 1. 待做（有明确动作）

### 1.1 素材管线工具

| ID | 事项 | 依赖 | 优先级 |
| --- | --- | --- | --- |
| **T-03** | 用对比台跑一轮 **基线（无 LoRA）vs 各 LoRA** 体检（每个 LoRA 至少 1 组），产出 `RESULTS.md`，据此决定保留哪些（**这一步只有你能做：需要人眼判断风格**） | T-01 ✅ | **P0** |
| **T-15** | 启动方式固化：Forge **必须用 `webui-user.bat`（带 `--api`）**，用 `webui.bat` 会导致出图接口 `{"detail":"Not Found"}` —— 已在工具 README 记下，可考虑加个启动检查脚本 | — | P3 |

### 1.2 许可与模型库

| ID | 事项 | 依赖 | 优先级 |
| --- | --- | --- | --- |
| **T-07** | **Dark and Darker Portraits 的去留**：非商用下可用，但只核对过许可、没测过效果 → **待 T-03 出对比结果后再决定是否删除** | T-03 | P1 |

> ✅ **T-05 / T-06 / T-14 已于 2026-10-12 完成并删除**：登录墙挡住的 **20 个全部补齐**，
> 三个类别缺口（SD 1.5 地砖 / SDXL 技能特效 / SDXL UI）也都有对应 LoRA 了。
> 磁盘现 **45 个 / 5.90 GB**（`sd15_*` ×15 / `sdxl_*` ×18 / 早期命名 ×12），登记表行数与 Forge 识别数一致。

### 1.3 M15 素材接入（主线）

| ID | 事项 | 依赖 | 优先级 |
| --- | --- | --- | --- |
| **T-09** | **M15 素材接入本体**（真实 sprite + 中文字体 + 音频）：代码侧管线已就绪（`data/*.json` 的 `sprite_path` / `icon` + `SpriteFactory` 加载分支），**卡在没有图** | T-03 | **P0** |
| **T-10** | **中文字体选型**：非像素风 → 像素字体出局，改常规 OFL 字体（思源黑体 / 霞鹜文楷 / LXGW），字号不再受 8/10/12px 限制 | — | P1 |
| **T-11** | **出图规模与后期成本重估**：`ai-asset-generation.md` §7 的 ~315 张 / ~64h 是按像素风估的；非像素风要 1024²+ 出图 + 去背 / 羽化 → 人工后期明显上涨，且 8GB 显存下 SDXL 1024² 已是上限 | — | P1 |
| **T-12** | **代码侧风格切换**（4 处，待 T-03 看实际观感后再定）：`scripts/world/sprite_factory.gd` 的 `TEXTURE_FILTER_NEAREST` → `Linear + Mipmaps`、`ALPHA_CUT_DISCARD` → `ALPHA_CUT_DISABLED`、占位贴图分辨率（`player.gd` / `enemy.gd` 64、`gear_pickup.gd` 32）、`_make_disc` / `_make_gem` 的逐像素硬描边 | T-03 | P2 |
| **T-13** | `alpha_cut` 改成 alpha 混合后，**半透明精灵的深度排序**问题需实测（多个羽化边精灵互遮会闪） | T-12 | P2 |

---

## 2. 未决（需拍板）

| 事项 | 现状 | 选项 |
| --- | --- | --- |
| **Dark and Darker 删或留** | 已部署（144.1 MB），许可只有 `RentCivit` | 测试满意 → 留（非商用合规）；不满意 → 删 |
| **M7 是否仍是"风格基线"** | `docs/tasks/README.md` 写着"M7 是后续所有玩法素材的风格基线"，但 M7 的图还没出，而风格基线已改为非像素 | 保持 M7 打样 / 改用对比台先定风格 |
| **3/4 俯视角色怎么出**（**P0，卡住 T-09**） | **实测 2026-10-12：提示词不是主因**。修好要求块后（上色 ✓ / 不裁 ✓）仍拿不到 3/4 俯视：① img2img 转视角 `denoise` 0.80/0.85/0.90 **三档都没转成**，0.85 以上反而把角色**糊成色块剪影**；② 文生图直接带视角要求 + 抽卡 4 张，抽看的 2 张仍**正面 / 略仰视**。**本机只有原始 SD 1.5 base 与 SDXL base，无任何社区微调底模** → 怀疑是**底模能力**而非模板问题 | ① 先用 **SDXL** 重跑同组（零下载，现成可用）② 下 1~2 个 **SD 1.5 社区底模**再测 ③ 用**角色 LoRA** 配合重测（`sd15_A_*` / `sdxl_A_*`）④ 若 2D 出图始终做不到 → **走 3D 渲染 sprite**（工程本身就是 3D + billboard，视角严格可控） |

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
| SD 1.5 checkpoint | `_LICENSES.md` 状态改为**已部署**（3.97 GB） |
| LoRA 下载（首轮） | 10 个：7 成功 / 3 被登录墙挡住（**后续已全部补齐**，见下行） |
| 风格基线 | 像素风口径已从 `_PROMPTS.md` / `ai-asset-generation.md` / `tasks/README.md` 移除 |
| 许可口径 | `AGENTS.md` §1 新增"非商用 → 放开模型许可门槛 + 保留署名义务" |
| **LoRA 对比台** | [`tools/lora-compare/`](../../tools/lora-compare/README.md) 落地：静态前端 + 本地代理服务 + 提示词库（含历史回退）+ 评分 / 结论 + 一键导出 `RESULTS.md`；端到端验证通过 |
| **LoRA 池** | 两轮扩张后磁盘共 **45 个 / 5.90 GB**（`sd15_*` ×15 / `sdxl_*` ×18 / 早期命名 ×12）；**登录墙的 20 个全部补齐**；Forge 识别数、登记表行数、磁盘文件数三方一致 |
| **许可筛选口径** | `_LICENSES.md` 改为「非商用 → `allowCommercialUse` 不硬过滤，但逐条记录供转商用复核」；LoRA 命名统一为 `sd15_`/`sdxl_` + 用途 + 描述，平铺不再分子目录 |
| **要求块修正（有效）** | 实测发现"灰阶线稿 + 头顶裁切"**确由提示词造成**并已修：`portrait` 补"不许裁"、`style` 补显式上色词、`commonneg` 压 `monochrome`/`line art`/`sketch` 等 → A1 立绘由**灰阶线稿变上色插画**、裁切消失（提交 `8de0800`）。副作用：风格偏向"可爱卡通"，待调 |
| **ControlNet 可用** | `control_v11f1e_sd15_tile`（1.35 GB）已下载并由 Forge 识别 → **`/controlnet/model_list?update=true` 只在启动时重扫**，运行时新增模型必须**重启 Forge**（重启仅 25s） |
| **实测记录方式** | 出图验证脚本全部走 `tools/lora-compare` 的本地代理（7788 → 7860），并把测试图落在 `images/_*.png`（已 gitignore）；**结论只入文档与提交信息，图不入库** |

---

## 附：已探明的接口事实（做 T-01 / T-02 直接用，别再重查）

| 项 | 值 |
| --- | --- |
| Forge API | `http://127.0.0.1:7860`（`api=True`；`cors_allow_origins` **为空**） |
| checkpoint 标识（`sd_model_checkpoint`） | SD 1.5：`_D_AI_ckpt\v1-5-pruned-emaonly.safetensors [6ce0161689]`；SDXL：`_D_AI_ckpt\sd_xl_base_1.0.safetensors` |
| 切模型方式 | `POST /sdapi/v1/options` 设 `sd_model_checkpoint`，再轮询 `/sdapi/v1/options` 确认（8GB 下切换需数十秒） |
| LoRA 名（用于 `<lora:名字:权重>`） | 即文件名去扩展名，如 `bg3_item_icons_v1`（列表见 `GET /sdapi/v1/loras`） |
| 采样器 | 含 `DPM++ 2M`（推荐起步）、`Euler a`、`DPM++ 2M SDE` 等 |
| 当前 CLIP skip | `CLIP_stop_at_last_layers = 1.0` |
| 本机 python | `D:\AI\python-full\python.exe`（3.10.11，含 `http.server`）；`D:\AI\python\`、`D:\AI\stable-diffusion-webui-forge\venv\Scripts\python.exe` 同样可用 |
| 本机 PowerShell | **5.1**（`HttpListener` 异步回调缺 runspace）→ 本地服务**用 python 写**，不要用 PowerShell 起 HTTP 服务 |
| 出图存放约定 | 先落 `D:\AI\outputs\YYYY-MM-DD\`，再归档 `assets/_wip/<类别>/`（见 [README.md](README.md) 全局规则） |

---

## 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-10 | 初版：把本轮对话里散落的待办收成 **T-01 ~ T-13** + 4 条未决 + 7 条已作废；顶部固化三条口径（非商用 / 不做像素风 / Forge 无 CORS 必须代理）；文末补「已探明的接口事实」 |
| 2026-10-10 | 修正：删掉「`.tmp-asset-compare/` 临时对比目录」这条未决项 —— 该目录已清理，无需再拍板 |
| 2026-10-12 | 落地 **T-01~T-05、T-08**：新增 **LoRA 对比台**（`tools/lora-compare/`，端到端验证通过）；扩大检索并**下载 16 个新 LoRA**（磁盘共 25 个 / 2.66 GB）；许可筛选口径改为「非商用放开」；LoRA 命名统一。**发现 Civitai 登录墙**（33 次尝试里 17 个 `401`）→ 新开 **T-06**（20 个被挡清单）/ **T-14** / 重写 **T-05** |
| 2026-10-12 | **阶段1 实测 + 要求块修正**：确认"灰阶线稿 / 头顶裁切"是提示词问题并修好（提交 `8de0800`，A1 立绘已上色且不裁切）；**但 3/4 俯视仍出不来** → 新开 **§2 未决项「3/4 俯视角色怎么出」（P0，卡住 T-09）**，记录三组实测证据与 4 条候选路线（SDXL / 社区底模 / 角色 LoRA / 3D 渲染）。另：`control_v11f1e_sd15_tile` 下载并由 Forge 识别（**运行时新增 ControlNet 模型必须重启 Forge**，仅 25s） |
| 2026-10-12 | **清单清理**：删掉已完成的 **T-05 / T-06 / T-14** 与 §2「3 个被挡 LoRA 怎么取」（登录墙的 20 个已全部落盘）；§4 计数由「25 个 / 2.66 GB」更正为 **45 个 / 5.90 GB** |
