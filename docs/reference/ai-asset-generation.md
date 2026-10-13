# AI 资产生图方案（Dreadmyst Clone）

> 本文档定义 **本项目美术素材的 AI 生产工作流**：硬件、模型、Prompt、后处理、Godot 集成、许可登记的完整链路。
> **出图管线只有一条：ComfyUI + Qwen-Image 2.1**（2026-10-13 起，SD 1.5 / SDXL / Forge 方案已整体删除）。

---

## 0. 文档位置与维护

- 路径：`docs/reference/ai-asset-generation.md`
- 配套：
  - `assets/_LICENSES.md` —— 素材 / 模型许可登记表（每次新增都登记一行）
  - `assets/_PROMPTS.md` —— Prompt 速查（只读副本）
  - `tools/lora-compare/` —— 出图对比台（**改提示词、出图、评分、导结论都在这里**）
  - `docs/tasks/backlog.md` —— 跨里程碑待办（模型 / 显存 / 视角问题都在那追踪）
- 重大变更记录在本文件末尾「变更记录」。

---

## 1. 硬件与选型

### 1.1 本机配置

| 项 | 值 | 含义 |
| --- | --- | --- |
| GPU | RTX 5070 Laptop **8GB** VRAM（Blackwell, sm_120） | 决定能跑多大的模型；**硬约束** |
| CPU | Ryzen 9 7845HX (12C/24T) | 数据预处理 / 导出快 |
| 内存 | 32 GB（实测 31 GB 可用） | 模型 offload 的落脚点 |
| 磁盘 | D 盘 259G 空闲 | 模型 / 输出都放 D 盘 |
| 驱动 | 616.92（CUDA UMD 13.4） | 决定能用哪个 cuXXX 的 torch |

> ⚠️ **8GB 显存是硬约束**：不换硬件的前提下，"更大分辨率""更多 ControlNet""同时驻留多个模型"都要付出代价。

### 1.2 选型结论

| 角色 | 用什么 | 说明 |
| --- | --- | --- |
| **主生成模型** | **Qwen-Image 2.1**（`qwen_image_2.1_int8_convrot`，6.76 GiB） | 7B 视觉生成分支；**文生图 + 指令式编辑同一个模型**；**原生 RGBA 透明底** |
| 文本编码器 | **`qwen3vl_8b_nvfp4`**（5.87 GiB） | 备用 `int8_convrot`（8.71 GiB）。两者热态**速度打平（12 s）**，nvfp4 小 2.84 GiB → 选它 |
| VAE | `qwen_image_2.1_vae_bf16`（0.63 GiB） | **4 通道，带 alpha**；不可换成别的 VAE（会变色 / 丢透明） |
| 加速 LoRA | `qwen_image_2.1_turbo_lora_avg_rank_178_bf16`（0.85 GiB） | 8 步收敛；⚠️ **必须 cfg=1** |
| 出图前端 | ComfyUI 0.39.0（`D:\AI\ComfyUI\comfyui-master`） | 官方模板已升到 `0.11.78`（含 2.1 的 t2i / image_edit / 背景移除三个模板） |
| 工作台 | `tools/lora-compare/`（对比台） | 提示词 / 要求块的唯一可编辑落点；出图 + 评分 + 导出 `RESULTS.md` |

模型统一放 `D:\AI\models-comfy\`（经 `extra_model_paths.yaml` 挂载）。

**许可提醒**：Qwen-Image 2.1 是 **Qwen Research License（研究用途）** —— 本项目非商用可用，**转商用需申请授权**。

### 1.3 部署现状（2026-10-13 实测）

| 项 | 值 / 坑 |
| --- | --- |
| venv | `D:\AI\venv-comfy\`（Python 3.10.11 + **torch 2.11.0+cu130** / torchvision 0.26.0 / torchaudio 2.11.0）。⚠️ `D:\AI\python-full` 是 base 解释器，**没有 torch**，不能拿来跑 ComfyUI |
| 启动 | 双击 `D:\AI\启动ComfyUI.bat`（内部 `cd /d D:\AI\ComfyUI\comfyui-master` 后起 `--port 8188`）。**必须 cd 到该目录**，否则 `extra_model_paths.yaml` 不生效 |
| `--lowvram` | ⚠️ **自 cu130 起已是 no-op**：`enables_dynamic_vram()` 的排除列表里没有它 → torch ≥2.8 时 **DynamicVRAM 接管**。要调显存用 `--vram-headroom` / `--reserve-vram` |
| CUDA 版本门槛 | ComfyUI 0.39 的 `comfy-kitchen` 优化内核**要求 cu130+**；本机已升到 **cu130**（`Found comfy_kitchen backend cuda: {'disabled': False}`）→ int8_convrot / nvfp4 的硬件内核才启用 |
| torch 下载 | `download.pytorch.org` 实测 ~2.6 MB/s（可用但慢）；**上海交大镜像** `https://mirror.sjtu.edu.cn/pytorch-wheels/cu130/` 可用，清华 / 阿里的 `pytorch-wheels` **没有 cu130 目录**。⚠️ 装 torch **必须写 `+cu130` 本地版本号**，否则 pip 会挑走普通 PyPI 的 CPU 版 |
| 网络 | Civitai / HuggingFace 直连不通 → 本机代理 `127.0.0.1:7890`（系统代理开关是关的，命令行要显式带 `-x` / `-Proxy`）。⚠️ PowerShell 的 `Invoke-WebRequest` **不认 308 跳转**。ModelScope / gitcode 镜像可直连 |
| 日志 | ComfyUI 启动 / 运行日志在 `D:\AI\logs\`（`cu130_startup.err` 等）；pip 版本备份 `pip-freeze-20261013-*.txt` 可作回滚依据 |

---

## 2. 素材分类与出图匹配

| 类别 | 形态 | 数量级 | 出图尺寸 | 用途 |
| --- | --- | --- | --- | --- |
| **角色 sprite** | 俯视角角色，收口 128×128 | ~20 个敌人 + 主角 | 1024²（再平滑降采样） | `data/enemies.json` 的 `sprite_path` |
| **怪物 sprite** | 同上 | ~20 种 | 1024² | 同上 |
| **场景 tileset** | 64×64 地砖（非像素） | ~15 套 | 1024²（再切 64²） | `world/` 场景背景 |
| **装备图标** | 64×64 物品（非像素） | 50–100 个 | 1024² → 降采样 | `data/loot.json` 的 `icon` |
| **UI 元素** | 图标、按钮、边框 | ~30 个 | 512² / 1024² | `ui/` 资源 |
| **技能特效** | 粒子 / 光效概念图 | ~10 个 | 1024² | 后期切帧 |
| **Boss 概念图** | 全身立绘 | ~5 个 | 1024² | 战斗场景背景 |
| **场景氛围图** | 整图氛围参考 | 几张 | 1024² | 氛围参考（不进游戏） |

> 📌 **Qwen 时代的实测结论（2026-10-12 / 13，同机同提示词）**：
>
> 1. **风格与画质大幅胜出**（完整中世纪骑士、华丽板甲，远超此前的 SD 1.5 / 国风3）。
> 2. **原生 RGBA 透明底成功**：实测 **32~34% 全透明像素** → **抠图这一步可以省掉**，提示词写一句
>    `transparent background / alpha channel` 即可。
> 3. **速度不再是瓶颈**：单张 8 步 / 1024² / Turbo LoRA = **热态 12 s**（cu130 升级前是 **611 s**）。
>    提速来自 cu130（comfy-kitchen 硬件内核 + DynamicVRAM + 文本编码器回到 GPU），**不是**换编码器。
> 4. **LoRA 目前只有一个**（Turbo 加速），因为 Qwen 的 LoRA 生态还很薄；一致性主要靠
>    **固定 seed 家族 + 调色板收敛 + 后期统一**（见 `assets/_PROMPTS.md` §6）。
> 5. ⚠️ **3/4 俯视视角仍未解决**（P0）：SD 时代实测三档 denoise + 抽卡都没转成；换 Qwen 后仍未验证。
>    候选路线：指令式编辑直说视角 / **ControlNet-Union 补丁**（官方 int8 版 3.52 GiB）/ 3D 渲染 sprite。

---

## 3. 模型获取与登记

### 3.1 下载流程

1. 优先 **ModelScope / Hugging Face 官方仓库**（`Comfy-Org/Qwen-Image-2.1`），次选 gitcode 等镜像。
2. 只下**单文件 safetensors**，按用途放：
   ```
   D:\AI\models-comfy\
   ├── diffusion_models\   qwen_image_2.1_int8_convrot.safetensors
   ├── text_encoders\      qwen3vl_8b_nvfp4.safetensors / qwen3vl_8b_int8_convrot.safetensors
   ├── vae\                qwen_image_2.1_vae_bf16.safetensors
   └── loras\              qwen_image_2.1_turbo_lora_avg_rank_178_bf16.safetensors
   ```
3. 体积核对 + `certutil -hashfile <文件> SHA256`，回填 `assets/_LICENSES.md` §5。
4. 重读 ComfyUI（或点对比台的「重读」）即可在下拉里看到。

### 3.2 许可登记（**必须**）

每次新增模型 / LoRA，立即在 `assets/_LICENSES.md` 登记：来源 URL、**许可原文**（照抄页面）、商用与否、署名义务、体积、路径。
LoRA 还要同步 `tools/lora-compare/data/loras.json`（用途 / 分组 / base / 触发词 / 署名），对比台靠它做兼容判断与触发词注入。

---

## 4. 出图工作流（对比台 + ComfyUI）

### 4.1 参数（Qwen-Image 2.1）

| 场景 | Steps | CFG | 备注 |
| --- | --- | --- | --- |
| **挂 Turbo LoRA**（默认） | **8** | **1** | cfg>1 会直接崩；此时**负向提示词完全失效** |
| 不挂 LoRA（基础模型） | 25（官方模板默认）/ 30–40 | 1 | 想让**负向生效**必须把 cfg 提到 2.5~4（见 backlog T-21） |
| 尺寸 | —— | —— | **必须 32 的倍数**；1024² 是 8GB 的舒适档（2.1 原生上限 2048²） |
| Sampler / Scheduler | `euler` / `simple` | | 官方模板默认值 |
| Batch | 1 | | —— |
| Seed | -1 或固定 | | 复现关键图要固定；对比台会「本批锁一个 seed 家族」 |

> 出图入口：对比台（`start.bat` → `http://127.0.0.1:7788/`）→ 页面 A 选项目 → 页面 B 调模型 / LoRA / 提示词 / 参数 → 「开始生成」。

### 4.2 提示词（**以 `data/prompts.json` 为唯一权威**）

模板与要求块都放在 [`tools/lora-compare/data/prompts.json`](../../tools/lora-compare/data/prompts.json)：
- 对比台【提示词 → 模板】：8 个生成项目（A1 立绘 / A2 视角转换 / A3 一步出图 / B 地砖 / C 装备图标 /
  D Boss / E 技能图标 / F UI），每个含正向、要求、负向、勾选的要求块
- 对比台【提示词 → 要求 / 规范】：7 个全局要求块（`portrait` / `viewshift` / `style` / `composition` /
  `viewneg` / `commonneg` / `guofeng`）+ 其他规范，改一处所有勾了它的模板一起变
- **只读速查**：[`assets/_PROMPTS.md`](../../assets/_PROMPTS.md)（三条铁律、参数纪律、项目清单）

拼装顺序：`<lora:名:权重> + 触发词 + [勾选的正向块…] + 模板·要求 + 模板·正向`
负向：`[勾选的负向块…] + 模板·负向`

### 4.3 出图后立即归档

产出落在 `tools/lora-compare/images/`（不入库）与 `D:\AI\ComfyUI\output\`。
**每周整理一次**到 `assets/_wip/<类别>/<名称>.png`，并对照 `_LICENSES.md` 确认许可。

---

## 5. 后期处理与 Godot 集成

### 5.1 流程总览

```
对比台 / ComfyUI 出图（RGBA png，1024²）
  → 图像编辑器：平滑降采样（Area / Lanczos3）、对齐、调色板收敛、拼 spritesheet
    （⚠️ 去背这一步**通常可以省掉** —— 2.1 原生输出带 alpha）
  → Real-ESRGAN（可选）：2x 放大低清图
  → Tiled：把 tileset 拼成关卡地图，导出 JSON
  → Godot：导入 .png / TileSet / .tscn
  → GDScript：填 `sprite_path` / `icon` 字段（**不改渲染路径**）
```

### 5.2 与现有代码的衔接

> ⚠️ 现在是**真 3D + billboard**（见 [`../modules/render3d.md`](../modules/render3d.md)），不是 2D 绘制。
> 真实接入点只有三处：
> 1. `data/enemies.json` 的 `sprite_path`（`SpriteFactory` 会优先加载它，填了即生效）
> 2. `data/loot.json` 的 `icon`
> 3. 地砖：替换 `DungeonRoom` 的程序化地面网格
>
> 替换原则：**先 1 个敌人 + 1 个物品跑通完整链路**，再批量替换。

### 5.3 素材导入 Godot 规范

1. **路径**：`res://assets/` 下分 `sprites/`、`tilesets/`、`icons/`、`ui/`、`concepts/`
2. **导入设置**：**`Filter = Linear`、`Mipmaps = on`**（非像素风不要 Nearest，否则边缘硬锯齿）
   ⚠️ 代码当前是 `TEXTURE_FILTER_NEAREST`（`scripts/world/sprite_factory.gd`），出图接入后按实际观感切换
3. **文件命名**：`{类别}_{id}_{姿态}.png`，例 `enemy_slime_idle.png`、`item_sword_iron_icon.png`
4. **版本控制**：素材走 **Git LFS**（单文件 > 100KB 都要 LFS），否则仓库会爆

---

## 6. 8GB 显存纪律（2026-10-13 实测版）

| 限制 | 推荐做法 |
| --- | --- |
| 单批出图 | 1 张 |
| 分辨率 | **≤ 1024²**（且必须 32 的倍数） |
| 文本编码器 | 用 **nvfp4（5.87 GiB）**；`int8_convrot` 8.71 GiB 在编码器回 GPU 后压力明显 |
| 同时挂 LoRA | 目前只有 Turbo 一个；**挂它就必须 cfg=1** |
| `--lowvram` | ⚠️ **已失效（no-op）** —— DynamicVRAM 接管；要预留显存用 `--vram-headroom` / `--reserve-vram` |
| 失败 OOM | 停掉 ComfyUI 进程清理显存后重启；同时确认没有别的进程抢显存（浏览器硬件加速、夸克等） |
| 其它 | 避免多个 ComfyUI 实例同时跑（会抢显存）；`comfy_kitchen` 需要 cu130+ 才启用优化内核 |

实测参考：单张 8 步 / 1024² / Turbo LoRA → 冷 18 s、**热 12 s**（升级前 611 s）。

---

## 7. 工作量估算

| 阶段 | 需要的素材 | AI 出图量（含废稿） | 人工后期 + 整合 |
| --- | --- | --- | --- |
| M7 职业技能 | 技能图标 ×6 + 特效参考 ×6 | ~30 张 | ~6h |
| M8 属性加点 | UI 元素 ×5 | ~20 张 | ~3h |
| M10 地城与 Boss | tileset ×3 套 + Boss 概念图 ×1 | ~80 张 | ~30h |
| M11 背包/商店 | 装备图标 ×50 + 商店 UI ×1 | ~150 张 | ~20h |
| M14 联机 | 玩家头像框 ×1 + 阵营图标 ×2 | ~15 张 | ~2h |
| **小计** | | ~300 张 | **~60h** |

> **出图已不是瓶颈**（12 s/张：300 张 ≈ 1 小时），**人工后期才是**。
> ⚠️ 上表的人工后期是**下限**：非像素风下每张都要平滑降采样 + 对齐 + 调色板收敛；
> 好消息是 **2.1 原生透明底**省掉了抠图。建议先按"跑通一条完整链路（1 敌人 + 1 物品）"实测一轮再修正本表。

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初稿：基于 RTX 5070 + Forge + SD 1.5/SDXL + 清华 pip 镜像 |
| 2026-10-09 | §7 工作量估算表的里程碑编号改为与 `docs/roadmap.md` 一致（M7 / M8 / M10 / M11 / M14） |
| 2026-10-10 | **风格基线改为"不做像素风"**：规格上调为角色 128²、地砖 64²、图标 64²；§5.3 导入改 `Filter = Linear` + `Mipmaps = on`；LoRA 由"起步必建 3–5 个"改为"非必需" |
| 2026-10-10 | **端到端跑通 + 实测结论入档**（当时的 SD 环境：torch 2.7.0+cu128 / 交大镜像 / junction / 代理 7890 等） |
| 2026-10-12 | **提示词拆成「模板 + 要求」两层**，落到可编辑的 `data/prompts.json`；更正 A 模板视角写法为投影词 |
| 2026-10-13 | **生图后端换代 + 本文档整体重写**：**SD 1.5 / SDXL / Forge 全部删除**（底模、45 个 LoRA、ControlNet、整棵 `D:\AI\models\`），改为 **ComfyUI 0.39 + Qwen-Image 2.1**；§1 选型表换成 Qwen 三件套 + Turbo LoRA（含 nvfp4 编码器说明）；§1.3 部署现状重写（torch 2.11.0+cu130 / comfy-kitchen 启用 / DynamicVRAM / **`--lowvram` 已失效** / 交大镜像有 cu130）；§2 删掉 SD LoRA 关键词列，换成 Qwen 实测结论（**12 s 出图 + 原生透明底 + 速度瓶颈消失**）；§3 换成 ModelScope/HF 获取；§4 换成对比台工作流 + Qwen 参数纪律；§6 换成 Qwen 显存纪律；§7 注明"出图不再是瓶颈、人工后期才是"。SD 时代的细节（img2img denoise 扫档、圆底图/纯色块底图的坑、Civitai 登录墙）随 SD 方案一并删除，需要追溯请查 git 历史 |

---

## 附录 A：许可登记表

见 [`assets/_LICENSES.md`](../../assets/_LICENSES.md)（**唯一权威**）。登记项：名称 / 类型 / 来源 URL / 用途 /
许可原文 / 商用 / 署名义务 / 状态 / 登记日期 / 体积 / 本地路径。LoRA 另需同步 `tools/lora-compare/data/loras.json`。

---

## 附录 B：常见问题

**Q: 出图很快但图不对，该先调什么？**
A: ① 确认 **cfg=1**（挂了 Turbo LoRA 时 cfg>1 会崩）；② 尺寸是 32 的倍数且 ≤1024²；③
换提示词前先看对比台【提示词检查】里的拼装结果，确认要求块勾对了。

**Q: 想要负向提示词生效怎么做？**
A: **不挂 Turbo LoRA**，并把 cfg 提到 2.5~4（步数 25~40）。挂 Turbo 时 cfg 恒 1，负向被完全忽略。

**Q: 换文本编码器会更快吗？**
A: 不会。2026-10-13 实测 **nvfp4（5.87 GiB）与 int8_convrot（8.71 GiB）热态都是 12 s**；
换 nvfp4 只是为了省 2.84 GiB 磁盘 / 内存。

**Q: 透明底还要抠图吗？**
A: 不用。2.1 的 VAE 是 4 通道，**原生输出 RGBA**（实测 32~34% 全透明像素），提示词写
`transparent background / alpha channel` 即可。

**Q: 出图有版权风险吗？**
A: 底模是 **Qwen Research License（非商用）** —— 本项目自用没问题，**转商用必须申请授权**；
第三方 LoRA 的许可**单独算**，逐条看 `assets/_LICENSES.md`。
