# 出图任务卡片索引（Dreadmyst Clone · 2.5D 复古 MMO 风格）

> 本目录把 `docs/reference/ai-asset-generation.md` §7 的"工作量估算"拆成**可执行的任务卡片**。
> 每张卡片含资源清单、模型/LoRA 选择、Prompt 引用、后期要点、关联代码、验收标准。
>
> 出图前：**只打开对应里程碑的卡片** + `assets/_PROMPTS.md` + `assets/_LICENSES.md`，三件套即可开工。

> **编号以 [`docs/roadmap.md`](../roadmap.md) 为唯一权威。** 本目录在 2026-10-09 之前使用过另一套编号，
> 现已统一；对照表见文末「编号变更对照」。

---

## 任务卡片清单

| ID | 里程碑 | 卡片 | AI 出图量 | 人工后期 | 优先级 | 出图状态 |
| --- | --- | --- | --- | --- | --- | --- |
| M7 | 职业与技能系统 | [M7-skills.md](M7-skills.md) | ~30 张 | ~6h | **P0** | 待开始 |
| M10 | 地城与 Boss | [M10-dungeon.md](M10-dungeon.md) | ~80 张 | ~30h | P1 | 待开始（**代码已完成 2026-10-10**） |
| M11 | 背包/商店/装备对比 | [M11-inventory.md](M11-inventory.md) | ~170 张 | ~23h | P1 | 待开始（**代码已完成 2026-10-10**） |
| M8 | 属性加点 | [M8-attributes.md](M8-attributes.md) | ~20 张 | ~3h | P2 | 待开始（**代码已完成 2026-10-10**） |
| M14 | 联机（头像/阵营） | [M14-multiplayer.md](M14-multiplayer.md) | ~15 张 | ~2h | P3 | 待开始（**代码侧暂停**，见卡片顶部） |
| **总计** | | | **~315 张** | **~64h** | | |

> 本表「出图状态」只跟踪**美术出图**进度。M7 / M8 / M10 / M11 / M13 的**代码**都已完成
> （见 [`docs/roadmap.md`](../roadmap.md)），当前一律用程序化占位美术，出图后按各卡片接入即可——
> 也就是 **M15「素材接入」已经就等着这些图**。

> **当前最高优先级**：M7（职业与技能）—— 是后续所有玩法素材的"风格基线"。
> **建议执行顺序**：M7（技能） → M10（视觉骨架） → M11（内容） → M8（属性 UI） → M14（修饰）。

> 📋 **不属于任何一张卡片的待做与未决项统一记在 [backlog.md](backlog.md)**
> （非商用许可口径 · LoRA 对比台工具 · 扩大检索 LoRA · M15 素材接入前置 · 已作废清单 · ComfyUI 接口事实）。
> 动工前建议先扫一眼——那里固化了三条口径（非商用 / 不做像素风 / 浏览器需本地代理（serve.py 反代 ComfyUI））。

---

## 使用流程（每个任务卡片）

```
1. 打开本卡片 → 看「资源清单」和「关联代码」
2. 打开 assets/_PROMPTS.md → 复制对应模板
   （**角色 = A1 立绘 + A2 视角转换（两阶段）**, 地砖 = B, 物品 = C, Boss = D, 技能 = E, UI = F）
3. 打开 assets/_LICENSES.md → 确认需要的 LoRA 都已登记
4. 启动 ComfyUI（双击 `D:\AI\启动ComfyUI.bat`）→ 在对比台里选 unet（Qwen-Image 2.1）
5. 出图 → 存到 D:\AI\outputs\YYYY-MM-DD\
6. 后期处理（Aseprite / Tiled / Godot）→ 导入项目
7. 在 GDScript 中替换 _draw() 或加新资源字段
8. 卡片底部打勾 + 在「变更记录」加日期
```

---

## 全局规则（所有卡片共用）

- **不复制 Stendhal 等 GPL 项目代码/素材**（仅借鉴结构与思想）。
- **所有 LoRA 下载即登记** `assets/_LICENSES.md`（不登记不能出图）。
- **8GB 显存纪律**：单批 1 张 + 1024²（32 的倍数）+ 文本编码器用 nvfp4（5.87 GiB）；`--lowvram` 自 cu130 起已是 no-op，改由 DynamicVRAM 管理显存。
- ~~**像素图导入 Godot 必须选 Nearest 滤波**~~ —— **2026-10-10 起风格基线改为"不做像素风"**（见
  [`assets/_PROMPTS.md`](../../assets/_PROMPTS.md)），导入规范改为 **`Filter = Linear` + `Mipmaps = on`**
  （Nearest 用非像素图会硬锯齿）。素材尺寸也整体上调一档：角色 128²、地砖 64²、**图标 128²**（UI 槽位 56px 留 2× 余量，2026-10-13 实测定档）。
- **每次出图后及时归档**到 `assets/_wip/<类别>/<名称>.png`，避免 `D:\AI\outputs` 爆炸。
- **Git LFS（2026-10-13 改口径）**：按**类型 / 目录**圈范围（git 只匹配文件名，做不到「按体积判断」）——
  **走 LFS**：`assets/concepts/**`（源图 / 概念图，MB 级）+ 字体 `.ttf`/`.otf` + 音频 `.wav`/`.ogg` + `.exr`；
  **直存 git**：`assets/{sprites,tilesets,icons,ui}/` 的 PNG 等游戏内小图（几 KB~几十 KB，压过没得再压）。
  ⚠️ 所以 **MB 级源图必须放 `assets/concepts/`** —— 放别处会直存进 git，历史删不掉。规则见仓库根 `.gitattributes`。

---

## 任务卡片标准结构（见 [_template.md](_template.md)）

每张卡片固定 8 节：
1. 目标 + 验收标准
2. 资源清单（编号 + 描述 + 数量 + 尺寸）
3. 模型 / LoRA 选择（引用 _LICENSES.md）
4. Prompt 草稿（指向 _PROMPTS.md 模板 + 自定义部分）
5. 后期处理要点
6. 关联代码文件（`scripts/` 下的具体路径）
7. 验收清单
8. 变更记录

---

## 编号变更对照（2026-10-09 统一）

| 卡片 | 旧编号 | 新编号（＝ `roadmap.md`） | 原因 |
| --- | --- | --- | --- |
| 职业与技能 | M7 | **M7** | 无变化 |
| 属性加点 | M10 | **M8** | roadmap 的 M8 就是属性加点 |
| 地城与 Boss | M9 | **M10** | roadmap 的 M9 已被已完成的「2.5D 渲染」占用 |
| 背包/商店/装备对比 | M8 | **M11** | roadmap 的 M11 是「背包与交易」 |
| 联机 | M11 | **M14** | roadmap 的 M14 是「联机」 |

---

## 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版：5 张里程碑任务卡片 + 标准模板，从 `ai-asset-generation.md` §7 拆分 |
| 2026-10-09 | **统一里程碑编号**：以 `roadmap.md` 为权威，重命名 4 张卡片（`M8-inventory`→`M11`、`M9-dungeon`→`M10`、`M10-attributes`→`M8`、`M11-multiplayer`→`M14`）并同步全部交叉引用；新增「编号变更对照」表 |
| 2026-10-10 | **风格基线改为"不做像素风"**：全局规则里"必须 Nearest 滤波"改为 **`Filter = Linear` + `Mipmaps = on`**；素材尺寸整体上调一档（角色 128² / 地砖 64² / 图标 64²）；`_template.md` 的后期要点由"像素化"改"平滑降采样" |
| 2026-10-10 | 新增 [backlog.md](backlog.md)（跨里程碑待办清单）并在本页加索引：固化非商用许可口径、不做像素风、Forge 无 CORS 必须走本地代理三条口径；登记 LoRA 对比台、扩大检索 LoRA、M15 素材接入前置等待办 |
