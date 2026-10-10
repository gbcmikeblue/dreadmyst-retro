# M8 · 属性加点 · 出图任务卡

> **里程碑**：M8 属性加点（升级给自由属性点）  
> **优先级**：P2  
> **预计出图量**：~20 张（5 元素 × 4 状态）  
> **预计人工后期**：~3h  
> **状态**：**代码已完成**（2026-10-10，界面用程序化占位图标）；**出图待开始**  
> **完成前置**：代码无前置（加点界面已按 AGENTS §2.4「只有一个 .tscn」纯代码构建）；
> 出图部分建议与 M11 商店 UI 同批，以共用调色板与 LoRA

---

## 1. 目标

5 个属性图标（**力量/敏捷/智力/体力/精神**）各出 4 个状态（**默认/已选/可加/满级**），共 20 个 UI 元素。

**验收标准**：
- [ ] 20 个 UI 元素出图
- [ ] 属性加点界面能正常打开
- [ ] 加点动画/高亮正常

---

## 2. 资源清单

| # | 资源 | 数量 | 尺寸 | 用途 |
| --- | --- | --- | --- | --- |
| 1 | 属性图标 | 5 | 64×64 | 力量/敏捷/智力/体力/精神 |
| 2 | 属性状态变体 | 15 | 64×64 | 5 属性 × 3 状态（已选/可加/满级） |
| 3 | "+"按钮 | 1 | 64×64 | 加点按钮 |
| 4 | 升级提示框 | 1 | 256×128 | 升级时弹出 |

---

## 3. 模型 / LoRA 选择

| 资源类型 | checkpoint | LoRA 关键词 |
| --- | --- | --- |
| 属性 UI | SD 1.5 | `rpg ui pixel`, `fantasy attribute icon` |

> 复用 M11 的"商店 UI LoRA"即可（同一视觉族），不需新增。

---

## 4. Prompt 草稿

模板：`assets/_PROMPTS.md` §F（UI 元素）

**正向**（替换 `[属性名]`）：
```
<lora:UI LoRA名:0.7>, single attribute icon, centered, transparent background,
pixel art style, sharp outline, fantasy [strength/agility/intelligence/vitality/spirit] stat icon,
front view, RPG game UI asset
```

**负向**：
```
3d, realistic, photo, multiple icons, character, scene, watermark, text
```

**参数**：`256×256 · steps 20 · CFG 7 · DPM++ 2M Karras`

---

## 5. 后期处理要点

- **状态变体**：用 Aseprite Hue/Saturation 调整（已选=主色加亮，可加=加绿边，满级=加金边）
- **统一调色**：和 M11 商店 UI 共用调色板
- **导入 Godot**：4 个状态做成 `AtlasTexture` 同一 sprite sheet

---

## 6. 关联代码文件

| 文件 | 状态 | 改动 |
| --- | --- | --- |
| `data/attributes.json` | **新建** | 5 个属性定义：id / name / color / description / per_point / max_points + `free_points_per_level` |
| `scripts/data/attribute_def.gd`、`attribute_registry.gd` | **新建** | 属性数据类与注册表（纯计算 `bonus_for_all()`） |
| `scripts/ui/attribute_panel.gd` | **新建** | 加点界面（纯代码构建，**不新增 .tscn**） |
| `scripts/actors/player.gd` | 改 | `allocate_attribute(id, points)` + 点数经济 + `total_stats()` 计入属性加成 + `modal_ui` 冻结操作 |
| `scripts/core/event_bus.gd` | 改 | `attributes_changed` / `attribute_allocate_requested` 两个信号 |
| `scripts/core/game.gd` | 改 | `attributes` 输入动作（C）；升级提示带上属性点 |
| `scripts/ui/hud.gd` | 改 | 剩余属性点显示 + 操作提示 |
| `scripts/main.gd` | 改 | 挂 `AttributePanel` + 补发初始状态 |
| `tests/test_attributes.gd` | **新建** | 8 用例自测 |

> ⚠️ 原卡片写的 `scenes/ui/attribute_panel.tscn` **已废弃**：本项目约定只有 `main.tscn` 一个场景，
> 逻辑节点全部代码构建（AGENTS.md §2.4），与 M7 的 `SkillBar` 处理方式一致。

---

## 7. 验收清单

- [ ] 20 个 UI 元素出图（属性图标 5 + 状态变体 15 + `+` 按钮 + 升级提示框）
- [x] `data/attributes.json` 完整（5 属性 × per_point × max_points + 每级点数）
- [x] 游戏中升级后能打开加点界面（C 键 / 「关闭 (C)」按钮）
- [x] 加点后属性实时更新（HUD 属性点 + 面板加成文本 + `total_stats()` 即时生效）
- [x] 满级状态正确显示（右侧金色「满级」+ 按钮禁用）
- [ ] 接入真图标后把 `AttributePanel` 的占位图标换成 `TextureRect`
- [ ] git 提交 + push

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版 |
| 2026-10-09 | **编号由 M10 改为 M8**，与 `docs/roadmap.md` 的权威编号统一（roadmap 的 M8 就是属性加点） |
| 2026-10-10 | **代码部分完成**（数据层 + 点数经济 + 加点界面 + 自测 + 文档）：面板改为纯代码构建，废弃卡片里的 `attribute_panel.tscn`；新增 `docs/modules/attributes.md`。出图部分仍未开始 |
