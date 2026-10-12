# 出图对比台（ComfyUI + Qwen-Image 2.1）

给 Dreadmyst Clone 原型选出图方案用的本地小工具：**同一提示词 + 同一 seed + 同一参数，只换一个变量**
（模型 / LoRA / 提示词模板 / 步数 / CFG / 尺寸），把结果并排摆出来，人工打分后导出 `RESULTS.md`。

- 纯静态前端（HTML / CSS / JS，无框架、无构建步骤）
- 一个本地 Python 服务负责：静态托管 + **ComfyUI API 反向代理** + 结果落盘

> ⚠️ **2026-10-12 换后端**：原本接的是 **Forge（SD 1.5 / SDXL）**，现已改为 **ComfyUI + Qwen-Image 2.1**。
> SD 系底模与那 53 个 SD LoRA **全部弃用**（与 Qwen 架构不通），本机正在清理（见 `docs/tasks/backlog.md`）。
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

1. **先启动 ComfyUI**：双击 **`D:\AI\启动ComfyUI.bat`**（等价于在 `D:\AI\ComfyUI\comfyui-master` 下运行
   `D:\AI\venv-comfy\Scripts\python.exe main.py --lowvram --port 8188`）。
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

## 🧠 8 GB 显存怎么优化（本机实测）

前提：Qwen-Image 2.1 的权重 **6.76 GB（unet）+ 8.71 GB（文本编码器）= 15.5 GB**，
**必然超过 8 GB** → 每次出图都要在显存↔内存之间搬运十几个 GB。这才是慢的根因。

| 手段 | 收益 | 代价 |
| --- | --- | --- |
| ⭐ **换更小的文本编码器**：`qwen3vl_8b_w4a8`（**5.88 GB**，比现在用的 int8 少 **2.83 GB**） | 最直接，少搬近 3 GB | 需再下 5.88 GB；质量影响很小 |
| **让 ComfyUI 常驻不回退**（别反复重启） | 省掉一次 ~15 GB 冷加载 | 常驻占 RAM |
| **降分辨率** 1024² → 896²/768²（必须是 **32 的倍数**） | 中间张量显著变小，明显更快 | 细节变少 |
| **关掉抢显存的东西**（Forge 实例 / 浏览器硬件加速） | 直接腾出百 MB~GB | — |
| 启动参数保持 `--lowvram` | 8 GB 的正确选择 | `--novram` 更慢；`--gpu-only` 会 OOM |
| 系统 RAM 尽量空（本机 31 GB，够 offload） | 避免换页拖慢 | — |

**实测参考**（1024² / 8 步 / Turbo / cfg 1）：首次 206 秒（含冷加载），
模型被换出后再跑 **716 秒** —— 差别全在"要不要重新搬那 15 GB"。所以**常驻 + 小 TE** 是最有效的两招。

---

## 文件说明

| 路径 | 说明 | 入库？ |
| --- | --- | --- |
| `data/prompts.json` | 提示词库 + 要求块（含各自的修改历史）。**这是提示词知识的落点，换模型也照样用** | ✅ |
| `data/loras.json` | LoRA 元数据：用途 / 分组 / 触发词 / base / 许可 / 署名义务（⚠️ 内容是 SD 时代的，已过期） | ✅ |
| `data/results.json` | 全部对比记录（含评分与结论） | ❌ **本地专用**，已在 `.gitignore`；首次保存时自动生成 |
| `RESULTS.md` | 由记录生成的结论文档（分组对比 + 建议保留哪些） | ✅ **这才是可交付物** |
| `images/*.png` | 生成的对比图（过程产物，体积大） | ❌ 已被 `.gitignore` 排除 |

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

- **图生图未接**：模板 A2（视角转换）目前只能按**文生图**跑（界面会提示）。
  要接需要另做一版 Qwen-Edit 图结构。
- **单张耗时 3~12 分钟**（见上"显存"一节）。
- `data/loras.json` 里那 50+ 个 SD LoRA **在 Qwen 上不可用**，只剩 1 个（Turbo）。

---

## 目录结构

```
tools/lora-compare/
├── index.html        界面骨架（含前端异常兜底）
├── styles.css        深色样式
├── app.js            全部逻辑（无框架；含 ComfyUI 图构造 comfyGraph/waitComfy/fetchComfyImage）
├── serve.py          本地服务：静态 + /comfy 反代（+/forge 兼容）+ /api/save|image|delete
├── start.bat         一键启动（自动找 python）
├── _check_static.py  静态自检（替代 node 语法检查）
├── _import_results.py 把脚本产物补登进 results.json 的幂等导入工具
├── data/            prompts.json · loras.json · results.json
├── images/          生成的对比图（不入库）
└── RESULTS.md       导出的结论文档
```

**ComfyUI 侧（本机）**：

```
D:\AI\ComfyUI\comfyui-master\      ComfyUI 0.39.0 源码
D:\AI\venv-comfy\                  它的 venv（python 3.10.11 + torch 2.7.0+cu128，移植自 Forge）
D:\AI\models-comfy\                模型（16.95 GB）
    diffusion_models\  qwen_image_2.1_int8_convrot.safetensors   6.76 GB
    text_encoders\     qwen3vl_8b_int8_convrot.safetensors       8.71 GB
    vae\               qwen_image_2.1_vae_bf16.safetensors       0.63 GB
    loras\             qwen_image_2.1_turbo_lora_...bf16         0.85 GB
D:\AI\启动ComfyUI.bat              一键启动
```

相关文档：提示词源头 `assets/_PROMPTS.md`、许可登记 `assets/_LICENSES.md`、
待办与口径 `docs/tasks/backlog.md`。
