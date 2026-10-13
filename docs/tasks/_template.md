# 任务卡片模板（_template）

> 所有里程碑任务卡片都按本模板组织。新建一张卡片时复制本文件，再按需修改。

---

## 1. 目标

_用 1–2 句话说明本里程碑的玩法目标，以及"为什么需要这些素材"。_

**验收标准**：
- [ ] 资源全部出图
- [ ] 后期处理完成（Aseprite / Tiled / 降采样）
- [ ] 资源导入 Godot 并被代码引用
- [ ] `_LICENSES.md` 无"待填"行
- [ ] 截图/录屏验证游戏中可见

---

## 2. 资源清单

| # | 资源 | 数量 | 尺寸 | 用途 |
| --- | --- | --- | --- | --- |
| 1 | _例：技能图标_ | 6 | 64×64 | M7 职业技能图标 |
| 2 | _例：特效参考_ | 6 | 1024² | M7 技能特效后期切帧 |

---

## 3. 模型 / LoRA 选择

| 资源类型 | checkpoint | LoRA | 引用 |
| --- | --- | --- | --- |
| _例：技能图标_ | Qwen-Image 2.1 | _Civitai 关键词：`pixel skill icon`_ | `assets/_LICENSES.md` 待填 |
| _例：技能特效_ | Qwen-Image 2.1 | _Civitai 关键词：`fantasy spell effect`_ | `assets/_LICENSES.md` 待填 |

> **下载后必填**：把 LoRA 实际名、来源 URL、License 写到 `_LICENSES.md`。

---

## 4. Prompt 草稿

> 完整模板见 `assets/_PROMPTS.md`，下表列出**本卡片用到的模板** + **每个资源的自定义部分**。

| 资源 | 模板（_PROMPTS.md） | 自定义部分（附加 prompt） |
| --- | --- | --- |
| _资源 1_ | E. 技能图标 | `[fireball/heal/dash/shield/slash/burst]` 按技能类型选 |
| _资源 2_ | _无（直接文生图）_ | _后期切帧_ |

---

## 5. 后期处理要点

- **Aseprite**：居中对齐、**平滑降采样**（Area/Lanczos3，**不是**最近邻）、透明背景
- **Tiled**：tileset 切片、导出 JSON → Godot TileSet
- **Real-ESRGAN**（可选）：2x 放大低清图
- **统一调色板**：从主色派生 5 阶灰度，避免风格分散

---

## 6. 关联代码文件

> 导入素材后需要改/新增的代码位置。

| 文件 | 改动 |
| --- | --- |
| `scripts/...` | _例：加 `icon: Texture2D` 字段到 `data/loot.json` 的物品定义_ |
| `scenes/...` | _例：`Sprite2D` 节点引用新贴图_ |
| `data/...` | _例：`loot.json` 加 `"icon": "res://assets/...png"` 字段_ |

---

## 7. 验收清单（出图后逐项打勾）

- [ ] 资源 1：_描述_
- [ ] 资源 2：_描述_
- [ ] _LICENSES.md 已登记所有用到的 LoRA
- [ ] 资源已导入 `res://assets/...` 对应目录
- [ ] 代码已引用新资源（替换了 _draw() 或加了字段）
- [ ] Godot 启动无警告/报错
- [ ] 游戏中能正常显示

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版 |
