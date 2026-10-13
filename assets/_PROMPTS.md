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
| 尺寸 | **32 的倍数** | 1024² 舒适 · **1536² 可行** · **2048²（2.1 原生上限）实测也可行**；只有 >2K 才会损失提示词遵循度 |
| 单张耗时 | 8 步 / Turbo：1024² **12~16 s** · 1536² **24 s** · **2048² 57 s** | cu130 升级前是 611 s |

**`--lowvram` 自 2026-10-13 起已是 no-op**（torch 2.11+cu130 → DynamicVRAM 接管）；
要调显存用 `--vram-headroom` / `--reserve-vram`。

---

## 2. 四条铁律级提示词规则（2026-10-13 按 Qwen-Image 2.1 规范重修）

1. ⭐ **正向自足**：主路径是 Turbo / 8 步 / **cfg=1**，而 **cfg=1 时 ComfyUI 跳过 negative conditioning，负向提示词完全不生效**
   （ComfyUI 官方文档）→ **所有要求必须能用正向词写出来**，负向块只当 cfg>1 时的护栏。
   禁止再出现「靠负向压住某效果」的设计（`chibi` / `pixel art` / 视角负向都属这一类）。
2. **投影词是硬需求，且必须正向化**：`isometric view` 放**开头**（权重最高）+ `orthographic projection` / `parallel projection`
   + `30 degree downward camera tilt`（带参照，别只写 `30 degree angle`）。
   ⚠️ **正向里禁止 `no perspective` 这类否定式**；⚠️ **禁止 `facing the viewer` / `front view` 与俯视同框**
   —— 这是旧版视角转不出来的头号原因（已从 `viewshift` 里删除）。⚠️ 不要写相机术语。
3. **国风要写具体符号，不写抽象词**：`chinese style` / `oriental aesthetics` 模型没学过 →
   写云纹 `"ruyi" cloud pattern`、玉佩 `jade ornaments`、流苏 `tassel details`、描金 `gold trim`、花窗 `carved wood lattice`
   （即 `guofeng` 块，只放**对象无关**的装饰/工艺词）；专有名词按规范**加引号**。
4. **不要 Q 版**：保持正常头身比 → 正向靠 `game sprite proportions`，负向固定压 `chibi, big head, super deformed`。
5. **参考结构（社区经验，可信度中）**：逗号分隔的**扁平标签流**，顺序 `主体 + 环境 + 光影 + 材质 + 风格 + 质量`；
   抽象词换成具象物理特征（`brushed steel blade with nicks` 胜于 `detailed sword`）。⚠️ 光影/材质属未实测新变量，一次只开一个做 A/B。
6. **语言纪律**：统一英文输出（中文构思 → 英文标签），仅专有名词加引号保留拼音。

---

## 3. 全局要求块（`prompts.json → global.要求块`）

| key | 名称 | 类型 | 用途 |
| --- | --- | --- | --- |
| **`transparency`** | 透明底（官方句式） | 正向 | **新增**。官方模型卡给定的 RGBA 写法；**已放在 `要求块` 的第一个键**（拼装顺序 = 键顺序，见下） |
| `portrait` | 立绘要求（阶段1） | 正向 | 阶段1 出正面全身立绘（**不要把视角要求塞进来**；背景交 `transparency`） |
| `viewshift` | 视角转换要求（阶段2） | 正向 | 阶段2 转 3/4 俯视：`isometric view, 30 degree downward camera tilt, orthographic projection…`（**已删 `facing the viewer` / `no perspective`**） |
| `style` | 风格要求 | 正向 | 2.5D 东方玄幻手绘、`saturated jewel tones` + 具象笔触/材质词 |
| `composition` | 构图要求 | 正向 | `centered composition` + 留白与可读性（**已删 `plain background`** —— 与透明底/平铺冲突）。⚠️ B 与 D 不勾 |
| `viewneg` | 视角转换负向 | 负向 | 压 90° 正俯视 / 正面平视 / 透视词（仅 cfg>1 生效） |
| `commonneg` | 通用负向 | 负向 | 三类护栏：结构安全（`fused fingers`…）/ 质感防护（`wax figure`…）/ 干扰过滤（`watermark`、`jpeg artifacts`…） |
| `guofeng` | 国风符号 | 正向 | 只放**对象无关**的装饰 / 工艺词；服饰词进各模板自己的正向 |

拼装顺序：`<lora:名:权重> + 触发词 + [勾选的正向块…] + 模板·要求 + 模板·正向`
负向：`[勾选的负向块…] + 模板·负向`

---

## 4. 项目需要出的图（= 对比台页面 A 的 8 个卡片）

| id | 项目 | 阶段 | 出图尺寸 | 要求块（勾选；⚠️ **实际拼装顺序 = `要求块` 的键顺序**，不是这里的先后） |
| --- | --- | --- | --- | --- |
| A1 | 角色立绘（阶段1） | 文生图 | 1024² | **transparency** · portrait · guofeng · style · composition · commonneg |
| A2 | 视角转换 → 3/4 俯视 | 编辑（i2i） | 跟随底图 | **transparency** · viewshift · guofeng · style · viewneg · commonneg（**去掉 composition**） |
| A3 | 3/4 俯视立绘（一步出图） | 文生图 | 1024² | **transparency** · viewshift · guofeng · style · composition · viewneg · commonneg（**不要勾 `portrait`**） |
| **A4** | **角色多视角设定图（一图流）** | 文生图 | **1536²**（1024² 也能出 4 格 / 2048² 可行 +57 s） | **transparency** · style · guofeng · commonneg（**不要勾 `composition`** —— 与 2×2 版面冲突） |
| B | 场景 tileset | 文生图 | 1024²（切 64²） | guofeng · style · commonneg（**去掉 composition**，无缝/正交词写在模板自己的「要求」里） |
| C | 装备图标 | 文生图 | 1024² → 64² | **transparency** · guofeng · style · composition · commonneg |
| D | Boss 概念图 / 立绘 | 文生图 | 1024² | guofeng · style · commonneg（**去掉 composition** —— 概念图要场景背景） |
| E | 技能图标 | 文生图 | 1024² → 64² | **transparency** · style · composition · commonneg |
| F | UI 元素 | 文生图 | 512²/1024² | **transparency** · style · composition · commonneg |

**透明底（2026-10-13 改）**：官方模型卡给定写法，已固化成 `transparency` 块，**排第一位**：

```
This is an RGBA image with transparency. The image has alpha channel and the background is transparent.
```

2.1 的 VAE 是 4 通道，**原生输出 RGBA**（实测 32~34% 全透明像素），后期抠图可以省掉。
⚠️ **不要再写 `plain background` / `simple background`** —— 那会画出纯色底，与透明底直接冲突（旧版就踩了这个）。

**⚠️ 图生图 ≠ 旧 img2img**：2.1 是**指令式编辑**（官方模板 `denoise` 恒 1.0），「强度」由指令决定。
官方规范写法 = **英文祈使句 + `<image1>` 引用 + 显式列出「什么保持不变」**：

```
Turn <image1> into an isometric 3/4 view game sprite, rotate the camera downward and in front of the character,
keep the character identity, outfit, colors and equipment unchanged, keep the transparent background,
preserve the original proportions and silhouette
```

对比台目前还没接 i2i（backlog T-20）。

---

## 5. 3/4 俯视（P0）—— 2026-10-13 起有解

**A. i2i（指令式编辑）这条路：实测走不通。** 用 `TextEncodeQwenImage21` 手工跑通 i2i 后：
- **保人没问题**：剪影 IoU 0.97、画面相关 0.97（对比「无底图的纯文生图」只有 0.03 —— 那才是"换人"）
- **但转视角几乎不动**：IoU 0.969~0.972、bbox 宽高比恒为 0.61。换提示词（含删掉与转视角自相矛盾的
  `preserve the original proportions and silhouette`）、改 cfg（1→3.5）、改步数（8→25）、挂不挂 Turbo，
  **结果全部一样**；而同一条链路下「换背景为日落海滩」（官方模型卡示例）是**正常生效**的
  → 结论：模型不是"听不懂指令"，而是**不做整体视角变换**
- ✅ 顺带实测：i2i 若**不写透明底声明**，输出会变成 **100% 不透明的带背景图** → `transparency` 块是必需的

**B. A4 一图流（不改造视角，让模型直接多画几个视角）：✅ 可用。**
2×2 格 = 正面 / **3-4 俯视** / 侧面 / 背面；1024² / 1536² / 2048² 都**稳定出满 4 格**（每格人物尺寸一致），
再用 `tools/lora-compare/crop_sheet.py` 裁成 4 张 128² sprite（共用缩放 + 底对齐 + 保 alpha）。
⚠️ 实测右上格更接近「**3/4 转身 + 轻微俯视**」，不是强俯视；要更强俯视需再压词或上 ControlNet。

**C. 仍未用的候选**：① **ControlNet-Union 补丁**（官方 `qwen_image_2.1_fun_controlnet_union_int8_convrot`，
3.52 GiB，本机节点已具备，见 T-24）② 改走 3D 渲染 sprite（工程本就是 3D + billboard，视角严格可控）。

**D. 已修掉的一个头号嫌疑**：`viewshift` 里原有 `facing the viewer`（正面面对镜头），与「3/4 俯视」
**语义互斥**（相当于让模型同时画正视图和俯视图）；A2 的模板正向里同类矛盾也已删。要单独验证它，
用 A3 同 seed 家族跑新老 `viewshift` 各 4~8 张对比。

⚠️ 注意 billboard 始终面向相机：sprite 到底要「正面」还是「3/4 俯视」取决于 billboard 模式

---

## 6. 后期统一规范

1. **裁切（A4「一图流」专用）**：`tools/lora-compare/crop_sheet.py` 把 2×2 设定图切成 4 张 sprite ——
   默认**四格共用缩放（比例一致）+ 底对齐（脚底对齐）+ 保留 alpha**；输出**默认 128²**
   （界面弹窗里可选 128 / 256 / 384 / 768，也可手填 32~1024；游戏内显示偏大就升档）。
   **也可以在对比台结果卡片上点「裁 sprite →」一键裁**（选中 A4 时宽高会自动变 1536²）；
   命令行等价写法（见该目录 `README.md`）：
   ```powershell
   D:\AI\venv-comfy\Scripts\python.exe crop_sheet.py images\_mv_1536.png --name enemy_slime
   ```
2. 平滑降采样（Area / Lanczos3），**不做**最近邻硬像素化（本项目不做像素风）
3. 调色板收敛到同一套 32~48 色 —— 这是「看起来像一套」的主要来源
4. 命名：`{类别}_{id}_{姿态}.png`，例 `enemy_slime_idle.png`、`item_sword_iron_icon.png`；
   A4 裁切产物用 `{类别}_{id}_{视角}.png`，例 `enemy_slime_iso.png` / `_front` / `_side` / `_back`
5. 版本控制（2026-10-13 改口径）：**按类型 / 目录**圈 LFS —— 源图 / 概念图放 `assets/concepts/`（走 LFS）、
   字体与音频也走 LFS；`assets/{sprites,tilesets,icons,ui}/` 的游戏内小图**直存 git**。规则见 `.gitattributes`
6. 进游戏前对照 `assets/_LICENSES.md` 确认许可与署名义务

---

## 7. 多视角设定图（A4）的社区范式来源（2026-10-13 联网核实）

两套成熟范式，共识是「**先锁版式 → 再定角色 → 最后枚举一致性**」：

| 范式 | 来源 | 做法要点 | 参数 |
| --- | --- | --- | --- |
| **版式锁定法** | GitHub `Pyrolistical/qwen-image-2.1-workflows` → `character-turnaround-sheet` | 用一张**空白人偶版式图**当画布（白底 + 灰分栏线 + 虚线参考线），提示词只说「**精确保留版式 / 位置 / 缩放 / 视角角度**，把这些空白人偶替换成该角色」；左大面板全身三次（正面 → 右侧面 → 背面），右侧两格头颈特写（正视 + 3/4 右转） | 2400×1792（4:3 上限） |
| **单次提示词式** | Wikiprompt 收录 `@junwatu` | 左「连续完整肩半身特写」+ 右「正面 / 侧面 / 背面全身三视图」；角色按**固定字段顺序**堆叠（姓名→年龄→地域→身高头身比→发型→五官→服装→鞋→姿态）；末尾**逐项枚举一致性**；负向写进正文（不要拼贴、不要局部小图） | 2752×1536 / steps 40 / cfg 1 |

第一套作者总结的硬纪律：先列**特征清单** → 每个特征指定「**由哪张参考图主导**」→
**某特征没有背面/侧面图时，按「正面设计的延续」来画**（而不是让模型自由发挥）。

**本项目的落地（A4）**：不用版式图，纯文字锁版式 → 2×2 格 = 正面 / **3-4 俯视** / 侧面 / 背面。
把「3/4 俯视」放进格子里，就**绕开**了 i2i 转视角走不通的问题
（实测 i2i 转视角剪影 IoU 0.97 ≈ 几乎不动，见 backlog T-20）。
后续可升级为「版式锁定法」：拿一张空白版式图 + 已有立绘，走 i2i 的多图槽（`TextEncodeQwenImage21` 支持 image_1..image_16）。

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-10 | 风格基线改为「非像素风」，A–F 模板与 8GB 纪律按 SD 1.5 / SDXL 写 |
| 2026-10-12 | 叠加「东方玄幻（梦幻西游向）」：相机术语换投影词、新增 `guofeng` 符号块 |
| 2026-10-13 | **整篇按 Qwen-Image 2.1 重写**：删除全部 SD 口径（SD 1.5/SDXL 尺寸、ControlNet tile、LoRA 权重规则、去背流程）；补参数纪律、nvfp4 编码器、原生透明底、指令式编辑与 T-21/T-24 |
| 2026-10-13 | **全量提示词规范化（8 模板 + 8 块）**：① 确立「**正向自足**」第一原则（Turbo/cfg1 下负向全失效）；② 新增 `transparency` 块（官方 RGBA 句式），删掉所有 `plain background` 冲突；③ 修 `viewshift` 的 `facing the viewer` 自相矛盾 + 否定式改正向；④ `composition` 去掉背景词，B/D 不再勾；⑤ 8 个模板的中文短语清零、改具象材质描述；⑥ A2 改官方祈使句 + `<image1>`；⑦ `commonneg` 按三类护栏重排、`guofeng` 去重加引号；⑧ 语言纪律 = 统一英文 + 专有名词加引号。校验：JSON 合法 / 8 模板拼装通过 / 冲突检查 0 告警 |
| 2026-10-13 | **新增 A4「角色多视角设定图（一图流）」+ 分辨率上限实测**：① 联网核实两套社区范式（版式锁定法 / 单次提示词式，见 §7），落地成 A4 = 2×2 格（正面 / **3-4 俯视** / 侧面 / 背面）；② 实测 **1024² / 1536² / 2048² 都能稳定出满 4 格**（alpha 连通域计数 = 4，每格人物尺寸一致），耗时 16 / 24 / **57** s；③ **2048²（2.1 原生上限）在 8GB 上实测可行** —— 旧文档「1536² 会 OOM」的 SD 时代结论作废；④ A4 **不勾 `composition`**（居中留白与多格版面冲突）；⑤ 方案动机：i2i 转视角实测剪影 IoU 0.97 ≈ 几乎不动 → 改为「让模型直接多画几个视角」 |
