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
| **T-01** | **搭 LoRA 对比台**（静态 web 项目，建议 `tools/lora-compare/`） | — | **P0** |
| | ① 同一提示词下，SD 1.5 与 SDXL 分别跑不同 LoRA，**并排对比** | | |
| | ② **提示词库**：查看 / 编辑 / 保存（含修改历史，可回退） | | |
| | ③ 每次生成落盘：记录 + 图片（`data/results.json`） | | |
| | ④ 人工评分（0~5）+ 结论（保留 / 待定 / 淘汰）+ 备注 | | |
| | ⑤ 一键导出 **`RESULTS.md` 对比文档**，作为"最终保留哪些 LoRA"的依据 | | |
| | ⑥ 端到端验证：用真实出图跑通一次 | | |
| **T-02** | 本地服务：静态文件 + `/forge/*` 反向代理 + 写盘 API —— **T-01 的前置**（Forge 没开 CORS） | — | **P0** |
| **T-03** | 用对比台跑一轮 **基线（无 LoRA）vs 各 LoRA** 体检，每个 LoRA 至少 1 组，产出 `RESULTS.md` | T-01 | **P0** |

### 1.2 许可与模型库

| ID | 事项 | 依赖 | 优先级 |
| --- | --- | --- | --- |
| **T-04** | `assets/_LICENSES.md` 的「批量筛选口径」按新规则改写：**去掉 `allowCommercialUse` 含 `Image` 的硬过滤**，改为"全部登记 + 记录商用列，供转商用复核" | — | **P0** |
| **T-05** | **扩大范围重搜 LoRA**：SD 1.5 + SDXL 两个 base，覆盖 角色 / 怪物 / Boss / 装备图标 / 技能图标 / 地砖 / UI / 特效，按非商用门槛重选一批并下载登记 | T-04 | P1 |
| **T-06** | 补齐 3 个被**登录墙**挡住的 LoRA（`medieval_ce_v1` 345MB / `knight_v1` 15MB / `fantasy_knight_armor_v1` 72MB）：需浏览器下载，或提供 Civitai API token 走代理重下 | 你 | P2 |
| **T-07** | **Dark and Darker Portraits 的去留**：非商用下可用，但只核对过许可、没测过效果 → **待 T-03 出对比结果后再决定是否删除** | T-03 | P1 |
| **T-08** | `D:\AI\models\lora\` 的空子目录（`actors / boss / data / skill / ui / world / 角色`）与 `_LICENSES.md` 写的 `角色 / 场景 / 物品 / UI` **命名不统一** → 二选一后统一 | — | P3 |

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
| **3 个被挡 LoRA 怎么取** | 作者要求登录（`401`） | ① 浏览器下载丢进 `D:\AI\models\lora\`（推荐，不必交密钥）② 给临时 API token 走代理重下（用完可立刻吊销） |
| **M7 是否仍是"风格基线"** | `docs/tasks/README.md` 写着"M7 是后续所有玩法素材的风格基线"，但 M7 的图还没出，而风格基线已改为非像素 | 保持 M7 打样 / 改用对比台先定风格 |

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
| LoRA 下载 | 10 个：**7 成功 / 3 被登录墙挡住**；磁盘现有 9 个 / 976 MB |
| 风格基线 | 像素风口径已从 `_PROMPTS.md` / `ai-asset-generation.md` / `tasks/README.md` 移除 |
| 许可口径 | `AGENTS.md` §1 新增"非商用 → 放开模型许可门槛 + 保留署名义务" |

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
