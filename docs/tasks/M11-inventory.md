# M11 · 背包 / 商店 / 装备对比 · 出图任务卡

> **里程碑**：M11 背包 / 商店 / 装备对比  
> **优先级**：P1（等 M7 跑通后）  
> **预计出图量**：~170 张（50 装备图标 + 100 废稿 + 20 商店 UI 元素）  
> **预计人工后期**：~23h（主要是图标对齐和品质边框）  
> **状态**：**代码已完成**（2026-10-10，背包 / 对比 / 商店骨架，图标仍为程序化占位）；**出图待开始**  
> **完成前置**：M7 完成（建立职业色 + 视觉基线）—— ✅ 已满足  
> **代码侧已就位**：背包 / 装备对比 / 一键换装 / 商店买卖都能跑，缺的只是图标与商店 UI 素材。
> 详见 [`docs/modules/inventory.md`](../modules/inventory.md)。

---

## 1. 目标

为 5 部位（**头/胸/腿/手/武器**）× 5 品质（**普通/优秀/稀有/史诗/传说**）× 3 职业（**战/法/游**）共 **225 个** 装备条目做图标。
- 实际只需出 **50 个**（每职业每部位 1 套通用底），其余通过颜色 + 名字后缀区分
- + 1 套商店 UI（按钮、标签页、对比箭头、品质边框）

**验收标准**：
- [ ] 50 个装备图标出图 + 平滑降采样到 **64×64**
- [ ] 5 套品质边框（普通灰/优秀绿/稀有蓝/史诗紫/传说橙）
- [ ] 1 套商店 UI 元素
- [ ] `data/loot.json` 全部 225 装备条目都有 `icon` 字段
- [ ] 背包/商店界面能正常打开

---

## 2. 资源清单

| # | 资源 | 数量 | 尺寸 | 用途 |
| --- | --- | --- | --- | --- |
| 1 | 装备图标（武器类） | 15 | **64×64**（512² 平滑降采样） | 剑/斧/锤/弓/法杖 各 3 职业各 1 |
| 2 | 装备图标（护甲类） | 20 | **64×64** | 头/胸/腿/手 各 3 职业各 1 + 1 套通用 |
| 3 | 装备图标（饰品类） | 15 | **64×64** | 项链/戒指/披风 各 5 |
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
   - 512² → 64×64（**Lanczos3/Area 平滑降采样**，不是最近邻）
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
| `data/inventory.json` | ✅ 已建 | 背包容量 + 卖出价公式 |
| `data/shop.json` | ✅ 已建 | 货架（部位 / 品质 / 等级 / 价格）+ 刷新价 |
| `scripts/data/inventory_config.gd`、`shop_config.gd` | ✅ 已建 | 两个配置的数据层（卖出价是唯一实现） |
| `scripts/ui/inventory_panel.gd` | ✅ 已建 | **背包 + 商店 + 对比合成一个界面**（两个页签，`I`/`B` 键） |
| `scripts/core/shop.gd` | ✅ 已建 | 商店服务：货架生成 / 购买 / 刷新（扣钱前校验背包空位） |
| `scripts/actors/player.gd` | ✅ 已改 | `backpack` + 入包 / 装备 / 分解 / 一键换装；掉落入包、换装回包 |
| `scripts/data/loot_table.gd` | ✅ 已改 | `generate()` 增加 `forced_slot_key`（商店要卖指定部位） |
| `data/loot.json` | ⬜ 待做 | 225 条目加 `icon`（等图标出图后再加；`quality_color` 已被 `GearItem.RARITY_COLORS` 取代，不需要） |
| `scripts/ui/equip_compare.gd` | ❌ 废弃 | 对比直接画在背包界面的详情区，不单开浮窗 |
| `tests/test_inventory.gd` | ✅ 已建 | 8 用例：配置 / 入包 / 换装 / 分解 / 容量 / 一键换装 / 商店 / 界面 |

---

## 7. 验收清单

- [x] **游戏中能打开背包**（`I` / `B`）+ 品质色边框正确（程序化占位版）
- [x] **装备对比**：逐词条显示增减，绿 = 提升 / 红 = 变差，空位有专门提示
- [x] **商店买卖**：购买扣钱入包、刷新货架扣钱；背包满 / 金币不足时按钮禁用并给出原因
- [ ] 15 张底图标出图
- [ ] 5 套着色变体生成（15 × 5 = 75 实际使用图标）
- [ ] 5 张品质边框
- [ ] 1 套商店 UI（~10 个元素）
- [ ] `data/loot.json` 全部 `icon` 字段非空，并把格子换成 `TextureRect`
- [ ] `_LICENSES.md` 已登记所有用到的 LoRA
- [ ] git 提交 + push

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版 |
| 2026-10-09 | **编号由 M8 改为 M11**，与 `docs/roadmap.md` 的权威编号统一（原 M8 与「属性加点」撞号） |
| 2026-10-10 | **代码部分完成**（背包 / 对比 / 一键换装 / 商店 + 自测 + 文档）：三个界面脚本合并为 `inventory_panel.gd`（双页签），`equip_compare.gd` 废弃（对比画在详情区）；`quality_color` 由 `GearItem.RARITY_COLORS` 取代；图标出图**仍未开始** |
| 2026-10-10 | **风格基线改为"不做像素风"**：装备图标由 32×32 上调为 **64×64**（资源清单三行 + 验收项 + 后期步骤），降采样方式由"最近邻"改为 **Lanczos3/Area 平滑** |
