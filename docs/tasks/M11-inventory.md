# M11 · 背包 / 商店 / 装备对比 · 出图任务卡

> **里程碑**：M11 背包 / 商店 / 装备对比  
> **优先级**：P1（等 M7 跑通后）  
> **预计出图量**：~170 张（50 装备图标 + 100 废稿 + 20 商店 UI 元素）  
> **预计人工后期**：~23h（主要是图标对齐和品质边框）  
> **状态**：待开始  
> **完成前置**：M7 完成（建立职业色 + 视觉基线）

---

## 1. 目标

为 5 部位（**头/胸/腿/手/武器**）× 5 品质（**普通/优秀/稀有/史诗/传说**）× 3 职业（**战/法/游**）共 **225 个** 装备条目做图标。
- 实际只需出 **50 个**（每职业每部位 1 套通用底），其余通过颜色 + 名字后缀区分
- + 1 套商店 UI（按钮、标签页、对比箭头、品质边框）

**验收标准**：
- [ ] 50 个装备图标出图 + 降采样到 32×32
- [ ] 5 套品质边框（普通灰/优秀绿/稀有蓝/史诗紫/传说橙）
- [ ] 1 套商店 UI 元素
- [ ] `data/loot.json` 全部 225 装备条目都有 `icon` 字段
- [ ] 背包/商店界面能正常打开

---

## 2. 资源清单

| # | 资源 | 数量 | 尺寸 | 用途 |
| --- | --- | --- | --- | --- |
| 1 | 装备图标（武器类） | 15 | 32×32（512² 降采样） | 剑/斧/锤/弓/法杖 各 3 职业各 1 |
| 2 | 装备图标（护甲类） | 20 | 32×32 | 头/胸/腿/手 各 3 职业各 1 + 1 套通用 |
| 3 | 装备图标（饰品类） | 15 | 32×32 | 项链/戒指/披风 各 5 |
| 4 | 品质边框 | 5 | 64×64 | 5 品质 × 1 套通用边框 |
| 5 | 商店 UI | 1 套 | 256² 混合 | 按钮 4 种 + 标签页 2 + 箭头 + 货币图标 |

---

## 3. 模型 / LoRA 选择

| 资源类型 | checkpoint | LoRA 关键词（Civitai 搜） |
| --- | --- | --- |
| 装备图标 | SD 1.5 | `pixel item icon`, `rpg inventory icon` |
| 品质边框 | SD 1.5 | `pixel frame`, `ui border fantasy` |
| 商店 UI | SD 1.5 | `rpg ui pixel`, `fantasy shop interface` |

> 全部待登记到 `assets/_LICENSES.md`。

---

## 4. Prompt 草稿

### 4.1 装备图标（50 张）

模板：`assets/_PROMPTS.md` §C（装备图标）

**正向**（替换 `[职业]` 和 `[物品]`）：
```
<lora:物品LoRA名:0.7>, single game item icon, centered, transparent background,
pixel art style, simple shading, sharp outline, fantasy [warrior/mage/ranger] [sword/axe/bow/staff/helmet/chest/legs/gloves],
front view, RPG inventory icon
```

**生成策略**：
- 每个 (职业, 部位) 组合出 1 张 → 3 × 5 = 15 张"底图"
- 着色差异化：出图后用 Aseprite 替换主色 → 复制出 5 品质变体
- 这样实际出图数从 225 降到 15 + 着色 = 50 张工作量

### 4.2 品质边框（5 张）

模板：`assets/_PROMPTS.md` §F（UI 元素）

**正向**：
```
<lora:UI LoRA名:0.7>, single UI element, centered, transparent background,
pixel art style, sharp outline, fantasy item frame, [gray/green/blue/purple/orange] border,
front view, RPG game UI asset
```

### 4.3 商店 UI（1 套）

模板：`assets/_PROMPTS.md` §F（UI 元素）

每个 UI 元素单独出图（避免一次性太复杂）：
- 4 种按钮（normal/hover/pressed/disabled）
- 2 种标签页（active/inactive）
- 1 上下箭头
- 1 货币图标（金币/钻石各 1）

---

## 5. 后期处理要点

1. **装备图标**：
   - 512² → 32×32（最近邻）
   - **着色（关键）**：用 Aseprite Replace Color 工具把主色替换为品质色
   - 品质色板：普通 #C0C0C0 / 优秀 #1EFF00 / 稀有 #0070DD / 史诗 #A335EE / 传说 #FF8000
2. **品质边框**：
   - 64×64 透明背景
   - 描边宽度 2px（避免在小图标上糊）
3. **商店 UI**：
   - 全部统一 5 阶灰度（`#1A1A1A → #F0F0F0`）
   - 高亮色用主色（暂定 `#FFD700` 金色）

---

## 6. 关联代码文件

| 文件 | 状态 | 改动 |
| --- | --- | --- |
| `data/loot.json` | 改 | 全部 225 条目加 `icon` 字段 |
| `data/loot.json` | 改 | 加 `quality_color` 字段（直接存 16 进制色码） |
| `scripts/ui/inventory.gd` | **新建** | 背包界面，引用 32×32 icon |
| `scripts/ui/shop.gd` | **新建** | 商店界面，引用商店 UI 元素 |
| `scripts/ui/equip_compare.gd` | **新建** | 装备对比浮窗 |
| `scripts/data/loot_table.gd` | 改 | `LootTable` 类加 `icon` 字段 |

---

## 7. 验收清单

- [ ] 15 张底图标出图
- [ ] 5 套着色变体生成（15 × 5 = 75 实际使用图标）
- [ ] 5 张品质边框
- [ ] 1 套商店 UI（~10 个元素）
- [ ] `data/loot.json` 全部 `icon` 字段非空
- [ ] 游戏中能打开背包看到图标 + 品质边框颜色正确
- [ ] 商店能正常买卖（图标显示在物品上）
- [ ] 装备对比能正常切换
- [ ] `_LICENSES.md` 已登记所有用到的 LoRA
- [ ] git 提交 + push

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版 |
| 2026-10-09 | **编号由 M8 改为 M11**，与 `docs/roadmap.md` 的权威编号统一（原 M8 与「属性加点」撞号） |
