# 出图对比台（ComfyUI + Qwen-Image 2.1）

给 Dreadmyst Clone 原型选出图方案用的本地小工具：**同一提示词 + 同一 seed + 同一参数，只换一个变量**
（模型 / LoRA / 提示词模板 / 步数 / CFG / 尺寸），把结果并排摆出来，人工打分后导出 `RESULTS.md`。

- 纯静态前端（HTML / CSS / JS，无框架、无构建步骤）
- 一个本地 Python 服务负责：静态托管 + **ComfyUI API 反向代理** + 结果落盘

> **后端是 ComfyUI + Qwen-Image 2.1**（2026-10-12 从 Forge 换过来；SD 系底模、45 个 SD LoRA 与
> ControlNet 已于 2026-10-13 全部删除 —— 那次清理的收尾记录见 `docs/tasks/backlog.md`）。
> 现在能对比的变量：**模板 / 提示词 / 模型(unet) / 尺寸 / 步数 / CFG / seed**，以及仓库里那 1 个 Qwen LoRA。

---

## 为什么必须有一个本地服务？

1. 浏览器不能直连 `127.0.0.1:8188` 再写回磁盘 —— 需要同源代理 + 落盘接口。
2. 顺带把"把结果写回仓库"这件事解决了。

所以 `serve.py` 提供 **`/comfy/*` 反向代理**（前端一律请求同源的 `/comfy/...`），
以及 `/api/save|image|delete` 落盘接口。

> 需要 `python`（本机用 `D:\AI\python-full\python.exe`，`start.bat` 会自动找）。

---

## 快速开始

1. **先启动 ComfyUI**：双击 **`D:\AI\启动ComfyUI.bat`**（等价于先在 `D:\AI\ComfyUI\comfyui-master` 下
   `cd`，再运行 `D:\AI\venv-comfy\Scripts\python.exe main.py --lowvram --port 8188`）。
   ⚠️ 必须先 `cd` 到 `comfyui-master`，否则 `extra_model_paths.yaml` 不生效、模型列表会是空的。
   ⚠️ 脚本里的 `--lowvram` **自 2026-10-13 起已是 no-op**（DynamicVRAM 接管，见下"显存 / 速度"一节），留着无害但别再指望它。
   界面在 <http://127.0.0.1:8188>，模型经 `extra_model_paths.yaml` 挂在 `D:\AI\models-comfy\`。
2. **双击 `start.bat`** —— 找到 python、在 `127.0.0.1:7788` 起服务并自动开浏览器。
3. 界面里按 1→5 走：
   - **1 提示词**：「【模板】」选模板改正向/负向/要求；「【要求 / 规范】」改全局的
     `viewshift` 视角与构图 / `viewneg` / `style` 风格 / `composition` 构图 / `commonneg` 通用负向 /
     `guofeng` 国风符号 / `其他规范`；下方**拼装预览**实时显示最终正负向（自动去重）。
     **生成用的就是编辑器里的当前内容，不必先保存。**
   - **2 参数**：选模型（unet）、LoRA、**步数 / CFG**（⚠️ 见下一节）、尺寸、采样器、seed。
     `seed = -1` 表示本批随机取一次后**锁死**，保证全批可比。
   - **3 对比对象**：勾要测的项（`（无 LoRA 基线）` 是必看的对照组）。
   - **4 结果**：每张图打 0~5 星 + 结论（保留 / 待定 / 淘汰）+ 备注，改完自动落盘。
   - **5 结论汇总** + 右上角 **「导出 RESULTS.md」**。

---

## ⚙️ 步数与 CFG 怎么设（Qwen-Image 2.1）

**CFG（`cfg_scale`）= 引导强度**，它同时决定两件事：
① 画面多大程度"贴着提示词走"；② **负向提示词是否参与计算**。

| cfg | 行为 |
| --- | --- |
| **1** | 完全不做引导（扩散退化成纯条件生成）。**负向提示词被完全忽略**；画面自然但"叫不动" |
| 2.5~4 | 常规区间：负向生效，提示词服从度好 |
| ≥6 | 过饱和、僵硬、易崩 |

**步数（`steps`）= 采样步数**。关键：**步数几乎不影响显存**（每步的中间张量大小固定），
只影响时间 —— 想省显存要从别处下手（下一节）。

**Qwen-Image 2.1 的两种配法（不要混）**：

| 配法 | 步数 | CFG | 说明 |
| --- | --- | --- | --- |
| **挂 Turbo LoRA**（本机现有那个） | **8**（4 也行） | **必须 1** | 蒸馏模型，采样轨迹 8 步就收敛；**调到 20 步不会更好**，只浪费时间；cfg>1 会直接崩 |
| **不挂 Turbo（基础模型）** | 官方口径 **40~50** | 2.5~4 | 20 步能出图但细节/结构偏弱；想快就配 Turbo |

> 所以"调到 20 步可以吗"的答案：**看搭配** —— 挂 Turbo 就老老实实 8 步；不挂 Turbo 则 20 步偏少，建议 30~40 起步。
> **想让负向提示词生效，就必须不挂 Turbo 并把 cfg 提到 2.5~4** —— 这是"要速度"和"要可控"的取舍。

---

## 🧠 8 GB 显存 / 速度（2026-10-13 全部重测）

> ⚠️ **本节旧版（截至 2026-10-12）已全部作废**：那时 torch 是 `2.7.0+cu128`，
> comfy-kitchen 的 CUDA 内核被禁用、走 legacy `--lowvram`、**文本编码器跑在 CPU 上**。
> 2026-10-13 升到 **torch 2.11.0+cu130** 后前提全变（详见 `docs/tasks/backlog.md` §0 / §4）。

现在的实际格局：

| 项 | 现状 |
| --- | --- |
| comfy-kitchen CUDA 内核 | **已启用**（`disabled: False`）：`int8_linear` / `dequantize_int8_convrot_weight` / `scaled_mm_nvfp4` 等 |
| 显存调度 | **DynamicVRAM 接管**（日志：`DynamicVRAM support detected and enabled`） |
| **`--lowvram`** | ⚠️ **已是 no-op**（`enables_dynamic_vram()` 的排除列表里没有它）。启动脚本里留着无害，但**别再指望它**；要调显存用 `--vram-headroom` / `--reserve-vram` |
| 文本编码器 | **在 GPU 上**（aimdo 启用 → `text_encoder_device()` 返回 GPU），现用 **`qwen3vl_8b_nvfp4`（5.87 GB）** |

**实测**（1024² / 8 步 / Turbo LoRA / cfg 1 / 同 seed 家族，同一台机器）：

| 配置 | 冷 | **热** | 峰值显存（冷 / 热） |
| --- | --- | --- | --- |
| **nvfp4 编码器（5.87 GB）** | 18 s | **12 s** | 7162 / 7176 MB |
| int8 编码器（8.71 GB） | 19 s | **12 s** | 7488 / 7268 MB |
| ~~旧基线（cu128 + CPU 编码器，2026-10-12）~~ | — | **611 s（10 分 11 秒）** | — |

⚠️ 三条容易读错的地方：

1. **nvfp4 与 int8 热态打平（12 s vs 12 s）** → 选 nvfp4 是因为**体积小 2.84 GB**，**不是**因为"更快"。
2. **提速 ~50 倍来自 cu130 升级**（kitchen 内核 + DynamicVRAM + 编码器回 GPU），**不是**换编码器。
3. **"单张 395 s / 618 s"那组数字已作废** —— 它是编码器跑在 CPU 时代的产物；`w4a8` 的否决结论同理（当时 4bit 的收益本来就不存在）→ **w4a8 文件已删**。

仍然有效的优化手段：**降分辨率**（1024² → 896²/768²，必须 32 的倍数）、
**让 ComfyUI 常驻不回退**（省一次冷加载）、**关掉抢显存的东西**（浏览器硬件加速）。

> 基准脚本（都在 `D:\AI\tmp\`，非仓库文件）：`enc_bench.py`（int8 vs w4a8，含冷/热设计）、
> `nvfp4_vs_int8.py`（同场 A/B，可加第三档）。测试图落在 `images/_enc_*.png` / `_nv_*.png`。

---

## ✂️ A4 设定图裁切（`crop_sheet.py`）

A4 模板出的是一张 **2×2 多视角设定图**（正面 / 3-4 俯视 / 侧面 / 背面）。

**方式一：界面里一键裁切（推荐）** —— 结果卡片上点「**裁 sprite →**」→ 弹窗里填**输出名前缀**、
选**输出边长**（128 / 256 / 384 / 768，也可手填 32~1024）→ 就地在卡片里出 4 张缩略图。
走 `/api/crop` → `crop_sheet.py`，参数与下面的命令行完全一致；**尺寸会记住上次用的值**。

> 💡 选中 A4 模板时，**宽高会自动变成 1536²**（模板里的 `默认尺寸` 字段）—— 别再手动改了。
> 裁切用的解释器由后端自动探测（`CROP_PYTHON` 环境变量可覆盖），因为 start.bat 默认挑的
> `D:\AI\python-full\python.exe` **没有 Pillow**；探测顺序：
> `CROP_PYTHON` → `D:\AI\venv-comfy\Scripts\python.exe` → 跑 serve.py 的解释器 → `python`。

**方式二：命令行**（只依赖 Pillow，产物与一键裁切相同）：

```powershell
D:\AI\venv-comfy\Scripts\python.exe crop_sheet.py images\_mv_1536.png --name enemy_slime
# → images\_mv_1536_crops\enemy_slime_front.png / _iso.png / _side.png / _back.png   （128²，RGBA）
```

| 选项 | 默认 | 说明 |
| --- | --- | --- |
| `--size` | `128` | 输出 sprite 边长（正方形画布，等比缩放进框） |
| `--mode` | `grid` | `grid` = 按 2×2 直接切；`auto` = **每格内** alpha 连通域定位（更抗偏移，需 numpy） |
| `--pad` | `0.04` | 人物 bbox 外再留的余量（占长边比例） |
| `--anchor` | `bottom` | 底对齐（脚底对齐）；`center` = 居中 |
| `--views` | `front,iso,side,back` | 按 **左上 / 右上 / 左下 / 右下** 顺序命名 |
| `--no-common-scale` | 关 | 关掉「四格共用缩放」→ 每格各自满框（**视角间比例会失真，不建议**） |
| `--out` / `--name` | `<图名>_crops` / 图名 | 输出目录 / 文件名前缀 |

要点：

- **默认四格共用同一缩放系数**（以最高的那个人形为基准）→ 正面/侧/背/3-4 俯视的**相对身高一致**，可直接进游戏；
- 每格按 alpha 收紧到人物 bbox（去掉空格与多余透明边），**透明底原样保留**；
- 每格空着就跳过并提示；auto 若认不到 4 个主体会**自动退回 grid** 模式（不会静默出错）。

---

## 文件说明

| 路径 | 说明 | 入库？ |
| --- | --- | --- |
| `data/prompts.json` | 提示词库 + 要求块（含各自的修改历史）。**这是提示词知识的落点，换模型也照样用** | ✅ |
| `data/loras.json` | LoRA 元数据：用途 / 分组 / 触发词 / base / 许可 / 署名义务（⚠️ 内容是 SD 时代的，已过期） | ✅ |
| `data/results.json` | 全部对比记录（含评分与结论） | ❌ **本地专用**，已在 `.gitignore`；首次保存时自动生成 |
| `RESULTS.md` | 由记录生成的结论文档（分组对比 + 建议保留哪些） | ✅ **这才是可交付物** |
| `images/*.png` | 生成的对比图（过程产物，体积大） | ❌ 已被 `.gitignore` 排除 |
| `crop_sheet.py` | **A4 设定图 → 单视角 sprite 裁切**（2×2 切格 + alpha 收紧 + 共用缩放 + 底对齐，只依赖 Pillow） | ✅ |
| `gen_icons.py` | **技能图标批量出图**（读 `prompts.json` 的 E 模板 → 1024² 透明底 → 去 alpha 噪声地板 → 抠边 → 128² 落 `assets/icons/`） | ✅ |

---

## 排错

| 现象 | 原因 / 处理 |
| --- | --- |
| 顶部红条：`本地服务没有响应` | 没起服务。双击 `start.bat`，或 `python serve.py` |
| 双击 `index.html` 直接打开 | 不行。必须走 `http://127.0.0.1:7788/`（否则调不到 ComfyUI、也写不了盘） |
| `读不到 ComfyUI：...` | ComfyUI 没启动 → 双击 `D:\AI\启动ComfyUI.bat` |
| `后端不可达（http://127.0.0.1:8188）` | ComfyUI 进程没在跑；`502` 是代理如实转达 |
| `ComfyUI 执行失败：...` | 图本身的问题（模型名/尺寸不是 32 的倍数/cfg 配错）——**前端现在会把真实报错抛出来**，不再只显示超时 |
| 端口 7788 被占 / **明明改了代码却像没生效** | ⚠️ 本机可能出现**多个 serve.py 实例同时绑 7788**（Windows 允许），请求会落到旧进程。按端口杀干净再起（见下） |
| 想换 ComfyUI 地址 | `python serve.py --comfy http://127.0.0.1:8189` |
| 改完 JS 没生效 | 服务已发 `Cache-Control: no-store`；仍异常就 Ctrl+F5 |

```powershell
# 按端口杀干净再重启（Windows 允许多个进程绑同一端口，务必先确认监听数为 0）
$p = (Get-NetTCPConnection -LocalPort 7788 -State Listen -EA SilentlyContinue).OwningProcess
if ($p) { taskkill /PID $p /T /F }
```

本机没有 `node`，所以自带了替代检查（语法括号 / 字符串闭合 / HTML id 引用一致性）：

```bash
python _check_static.py
```

---

## 已知限制

- **图生图（i2i）不接 —— 已实测结案（backlog T-20）**：手工用 `TextEncodeQwenImage21` 跑通 i2i 后
  **保人没问题**（剪影 IoU 0.97 / 画面相关 0.97），但**转视角几乎不动**（改提示词、cfg 1→3.5、8→25 步、
  挂不挂 Turbo 全都一样；而「换背景」这类内容编辑是正常生效的）→ **A2 模板已标记废弃**，
  视角改走 **A4 一图流**（让模型直接多画几个视角）或 ControlNet-Union（T-24）。
- ~~单张耗时 3~12 分钟~~ → **2026-10-13 起为 12~37 秒**（见上"显存 / 速度"一节）。
- `data/loras.json` 里那 50+ 个 SD LoRA **在 Qwen 上不可用**，只剩 1 个（Turbo）。

---

## 目录结构

```
tools/lora-compare/
├── index.html        界面骨架（含前端异常兜底）
├── styles.css        深色样式
├── app.js            全部逻辑（无框架；含 ComfyUI 图构造 comfyGraph/waitComfy/fetchComfyImage）
├── serve.py          本地服务：静态 + /comfy 反代 + /api/save|image|delete|list
├── start.bat         一键启动（自动找 python）
├── _check_static.py  静态自检（替代 node 语法检查）
├── crop_sheet.py     A4 设定图 → 单视角 sprite 裁切（只依赖 Pillow）
├── gen_icons.py      技能图标批量出图（读 prompts.json 的 E 模板 → 去 alpha 噪声地板 → 抠边 → 128²）
├── data/            prompts.json · loras.json · results.json
├── images/          生成的对比图（不入库）
└── RESULTS.md       导出的结论文档
```

**ComfyUI 侧（本机）**：

```
D:\AI\ComfyUI\comfyui-master\      ComfyUI 0.39.0 源码（模板/前端已升到 0.11.78 / 1.55.14）
D:\AI\venv-comfy\                  venv（python 3.10.11 + **torch 2.11.0+cu130**，tv 0.26.0 / ta 2.11.0）
D:\AI\models-comfy\
    diffusion_models\  qwen_image_2.1_int8_convrot.safetensors   6.76 GiB
    text_encoders\     qwen3vl_8b_nvfp4.safetensors              5.87 GiB   ← 现用
                       qwen3vl_8b_int8_convrot.safetensors       8.71 GiB   ← 备用（官方模板默认指向它）
                       （qwen3vl_8b_w4a8 已于 2026-10-13 删除）
    vae\               qwen_image_2.1_vae_bf16.safetensors        0.63 GiB
    loras\             qwen_image_2.1_turbo_lora_...bf16          0.85 GiB
D:\AI\启动ComfyUI.bat              一键启动（内部：cd 到 comfyui-master 后起 8188）
D:\AI\logs\                        启动/运行日志 + pip freeze 备份（回滚依据）
```

相关文档：提示词源头 `assets/_PROMPTS.md`、许可登记 `assets/_LICENSES.md`、
待办与口径 `docs/tasks/backlog.md`。
