# M7 · 职业与技能系统 · 出图任务卡

> **里程碑**：M7 职业与技能系统（多职业 + 多技能 + 冷却/蓝条）  
> **优先级**：**P0（当前最高）**  
> **预计出图量**：~30 张（6 技能图标 + 6 特效参考，含废稿）  
> **预计人工后期**：~6h  
> **状态**：**代码骨架已完成（2026-10-09）**，剩出图部分待开始  
> **完成前置**：ComfyUI 已起来（Qwen-Image 2.1 三件套就位；Qwen 侧暂无 UI 类 LoRA）

---

## 1. 目标

为三个职业（**战 / 法 / 游**）各设计 2 个基础技能（普攻 + 大招），共计 **6 个技能**：
- 每个技能需要 1 张图标（64×64 PNG，透明背景）
- 每个技能需要 1 张特效参考图（1024²，文生图后人工切帧成 4–8 帧粒子）

为 M7 同时给三个职业建立**视觉基线**（后续 M10/M11 的"职业色 + 职业风"都基于这 6 个图标定义）。

**验收标准**：
- [ ] 6 个技能图标已出图并导入 `res://assets/icons/skills/`
- [ ] 6 张特效参考已出图并归档到 `assets/_wip/effects/`
- [ ] 至少 1 个特效成功切成 4+ 帧粒子 sprite sheet
- [ ] `data/skills.json` 新建，6 个技能都有 `icon` 字段
- [ ] `scripts/skills/skill.gd` 和 `scripts/ui/skill_bar.gd` 引用新资源
- [ ] 游戏中按快捷键能看到图标 + 释放时有粒子

---

## 2. 资源清单

| # | 资源 | 数量 | 尺寸 | 用途 |
| --- | --- | --- | --- | --- |
| 1 | 战士技能图标 | 2 | 64×64（出图 512² 降采样） | M7 战-普攻 / 战-大招 |
| 2 | 法师技能图标 | 2 | 64×64 | M7 法-普攻 / 法-大招 |
| 3 | 游侠技能图标 | 2 | 64×64 | M7 游-普攻 / 游-大招 |
| 4 | 技能特效参考 | 6 | 1024² | 后期切 4–8 帧粒子 |

**技能列表**（用户需确认名字，暂用占位）：

| 职业 | 普攻图标关键词 | 大招图标关键词 |
| --- | --- | --- |
| 战士 (Warrior) | `[slash]` | `[whirlwind]` |
| 法师 (Mage) | `[fireball]` | `[meteor]` |
| 游侠 (Ranger) | `[arrow]` | `[multishot]` |

> 上面 `[xxx]` 是 _PROMPTS.md §E 模板里的可选词，**出图时直接选**。

---

## 3. 模型 / LoRA 选择

| 资源类型 | checkpoint | LoRA 关键词（Civitai 搜） | 引用 |
| --- | --- | --- | --- |
| 技能图标 | Qwen-Image 2.1 | `pixel skill icon`, `rpg ability icon` | 待登记到 `assets/_LICENSES.md` |
| 技能特效 | Qwen-Image 2.1 | `fantasy spell effect`, `magic particle` | 待登记到 `assets/_LICENSES.md` |

> **LoRA 优先选 1 个 UI 类的**（覆盖图标 + 特效），等出图验证风格后再决定要不要加第二个。

---

## 4. Prompt 草稿

### 4.1 技能图标（6 张）

模板：`assets/_PROMPTS.md` §E（技能图标）

**正向**（每张图复制下面，**只改 `[职业 + 技能关键词]`**）：
```
<lora:UI LoRA名:0.7>, single game skill icon, centered, transparent background,
pixel art style, simple shading, sharp outline, fantasy [warrior slash / mage fireball / ranger arrow / warrior whirlwind / mage meteor / ranger multishot],
front view, RPG skill icon
```

**6 张图的自定义关键词**（直接替换 `[...]`）：
1. 战-普攻：`warrior slash`
2. 战-大招：`warrior whirlwind`
3. 法-普攻：`mage fireball`
4. 法-大招：`mage meteor`
5. 游-普攻：`ranger arrow`
6. 游-大招：`ranger multishot`

**负向**（6 张共用）：
```
3d, realistic, photo, multiple icons, character, scene, watermark, text
```

**参数**：`512×512 · steps 25 · CFG 7 · DPM++ 2M Karras`

### 4.2 技能特效参考（6 张）

模板：`assets/_PROMPTS.md` §D（Boss 概念图，但本次用在技能特效上）

**正向**：
```
<lora:UI LoRA名:0.7>, full body skill visual effect, dynamic motion,
[slashing energy / fireball explosion / arrow rain / whirlwind vortex / meteor impact / multishot burst],
dramatic lighting, concept art, detailed, painterly, fantasy RPG skill effect
```

**负向**：
```
pixel art, 8-bit, chibi, cute, blurry, low quality, watermark
```

**参数**：`1024²（32 的倍数）· steps 25 · CFG 1 · euler · simple`

---

## 5. 后期处理要点

### 5.1 技能图标

1. **Aseprite**：
   - 打开 512² 出图 → Image → Mode → Indexed (32 色)（**保留**：调色板收敛是风格一致性的主要来源）
   - Image → Resize → 64×64（**Lanczos3 / Area 平滑降采样**，不是 Nearest Neighbor）
   - 删除背景（Select by Color → 白色 → Delete）
   - 居中对齐（中心放视觉中心，不是几何中心）
   - 导出 PNG：`assets/icons/skills/skill_<职业>_<技能>.png`
2. **导入 Godot**：
   - 拖入 `res://assets/icons/skills/`
   - 导入设置：Filter = **Linear**，Mipmaps = **on**（非像素风；代码当前仍是 NEAREST，待实测）

### 5.2 技能特效

1. **Aseprite**：
   - 按 1024² 出图
   - 删除背景
   - **手动切 4–8 个关键帧**（用 Lasso + 移动/旋转，做出动画序列）
   - 每帧导出为 `assets/_wip/effects/<技能>_frame_<N>.png`
2. **Godot 整合**：
   - 创建 `SpriteFrames` 资源（`assets/spriteframes/effects/<技能>.tres`）
   - 帧率 12–24 FPS
   - 配合 `CPUParticles2D` 或 `GPUParticles2D` 做真实粒子叠加

---

## 6. 关联代码文件

> 这些是 M7 需要新建/修改的代码位置（出图前先改好结构，再出图填字段）。

> ✅ **代码骨架已于 2026-10-09 落地**，下面表格是**实际路径**（与最初拆卡片时的设想略有出入：
> 数据层统一放 `scripts/data/`、UI 统一放 `scripts/ui/`）。模块说明见 [../modules/skills.md](../modules/skills.md)。

| 文件 | 状态 | 实际改动 |
| --- | --- | --- |
| `data/skills.json` | ✅ 已建 | 6 个技能：id / name / profession / kind / cooldown / mana_cost / damage_mult / cast_range / half_angle_deg / color / **icon** |
| `data/professions.json` | ✅ 已建 | 3 个职业：id / display_name / color / base_stats / skills（技能 id 列表） |
| `scripts/data/skill_def.gd` | ✅ 已建 | `class_name SkillDef`（含 `is_full_circle()` / `short_label()`） |
| `scripts/data/skill_registry.gd` | ✅ 已建 | `class_name SkillRegistry`：`load_default()` / `get_skill(id)` / `skills_of(profession)` |
| `scripts/data/profession.gd` | ✅ 已建 | `class_name Profession` |
| `scripts/data/profession_registry.gd` | ✅ 已建 | `class_name ProfessionRegistry` |
| `scripts/ui/skill_bar.gd` | ✅ 已建 | 底部技能栏：冷却遮罩 + 蓝量可用性 + 程序化占位图标 |
| `scripts/ui/hud.gd` | ✅ 已改 | 加蓝条 / 职业标签；挂载 `SkillBar` 子节点 |
| `scripts/actors/player.gd` | ✅ 已改 | 职业驱动属性 + `cast_slot()` / `cast_skill()` + 冷却表 + 蓝量 + 每技能弧光 |
| `tests/test_skills.gd` | ✅ 已建 | 5 个用例：施放 / 冷却拦截 / 360° 判定 / 转职 / 蓝量门槛 |

**本卡片仍未完成的部分**：6 个技能图标 + 6 张特效参考（纯出图工作）。

---

## 7. 验收清单

- [ ] 6 个技能图标出图（512²）
- [ ] 6 个技能图标降采样到 64×64
- [ ] 6 个图标导入 `res://assets/icons/skills/`
- [ ] 6 个图标已写到 `data/skills.json` 的 `icon` 字段
- [ ] 至少 1 个特效参考切出 4+ 帧 spritesheet
- [ ] 至少 1 个技能可以在游戏中释放并看到图标 + 粒子（技能已可释放，图标与粒子待出图）
- [x] 玩家蓝条 UI 显示正常 —— 代码部分 2026-10-09 完成
- [x] 冷却倒计时显示正常 —— 代码部分 2026-10-09 完成
- [x] 6 个技能可释放，伤害 / 冷却 / 蓝耗 / 360° 判定正确 —— `tests/test_skills.gd` 5 用例通过
- [ ] `_LICENSES.md` 已登记所有用到的 LoRA
- [ ] git 提交 + push

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版：M7 任务卡片，从 `ai-asset-generation.md` §7 拆分 |
| 2026-10-09 | **代码骨架落地**：`data/skills.json` + `data/professions.json` + 4 个数据层类 + `SkillBar` + `Player` 职业/技能改造 + `tests/test_skills.gd`；§6 表格改为实际路径；状态改为「出图待开始」 |
| 2026-10-09 | §2 技能列表的**名字已确定**（裂颅斩 / 旋风斩 / 火球术 / 陨石术 / 穿刺箭 / 箭雨），不再用占位关键词 |
| 2026-10-10 | **风格基线改为"不做像素风"**：后期步骤去掉"像素化"，`Nearest Neighbor` 换成 **Lanczos3/Area 平滑降采样**（**保留** Indexed 调色板收敛，它是风格一致性的主要来源）；导入设置改 `Filter = Linear` + `Mipmaps = on`；图标仍为 64×64 |
