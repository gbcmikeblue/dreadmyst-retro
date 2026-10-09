# M10 · 属性加点 · 出图任务卡

> **里程碑**：M10 属性加点（升级给自由属性点）  
> **优先级**：P2  
> **预计出图量**：~20 张（5 元素 × 4 状态）  
> **预计人工后期**：~3h  
> **状态**：待开始  
> **完成前置**：M8 完成（属性面板 UI 沿用商店 UI 风格）

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

> 复用 M8 的"商店 UI LoRA"即可（同一视觉族），不需新增。

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
- **统一调色**：和 M8 商店 UI 共用调色板
- **导入 Godot**：4 个状态做成 `AtlasTexture` 同一 sprite sheet

---

## 6. 关联代码文件

| 文件 | 状态 | 改动 |
| --- | --- | --- |
| `data/attributes.json` | **新建** | 5 个属性定义：id, name, icon, max_points |
| `scripts/ui/attribute_panel.gd` | **新建** | 加点界面 |
| `scripts/actors/player.gd` | 改 | 加 `allocate_attribute(id, points)` 方法 |
| `scenes/ui/attribute_panel.tscn` | **新建** | 加点界面场景 |

---

## 7. 验收清单

- [ ] 20 个 UI 元素出图
- [ ] `data/attributes.json` 完整
- [ ] 游戏中升级后能打开加点界面
- [ ] 加点后属性实时更新
- [ ] 满级状态正确显示
- [ ] git 提交 + push

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版 |
