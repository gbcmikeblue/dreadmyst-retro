# M14 · 联机 · 出图任务卡

> **里程碑**：M14 联机（ENet 客户端-服务器）  
> **优先级**：P3  
> **预计出图量**：~15 张（头像框 + 阵营图标 + 玩家名牌）  
> **预计人工后期**：~2h  
> **状态**：待开始  
> **完成前置**：M7（技能）、M10（地城）、M11（背包/商店）完成 + 联机协议层完成

---

## 1. 目标

联机功能的视觉元素：玩家头像框（边框装饰）+ 2 个阵营图标（联盟/部落风格）+ 玩家名牌背景。

**验收标准**：
- [ ] 1 套头像框（4 等级：平民/精英/英雄/传奇）
- [ ] 2 个阵营图标
- [ ] 玩家名牌（头顶显示）

---

## 2. 资源清单

| # | 资源 | 数量 | 尺寸 | 用途 |
| --- | --- | --- | --- | --- |
| 1 | 头像框 | 4 | 64×64 边框 | 4 等级玩家身份标识 |
| 2 | 阵营图标 | 2 | 32×32 | 联盟/部落 |
| 3 | 玩家名牌背景 | 1 | 256×32 | 头顶显示背景 |

---

## 3. 模型 / LoRA 选择

| 资源类型 | checkpoint | LoRA 关键词 |
| --- | --- | --- |
| 联机 UI | SD 1.5 | `rpg ui pixel`, `fantasy avatar frame`, `mmorpg faction icon` |

> 复用 M11（商店 UI）/ M8（属性 UI）的 LoRA，不需新增。

---

## 4. Prompt 草稿

### 4.1 头像框

模板：`assets/_PROMPTS.md` §F

**正向**：
```
<lora:UI LoRA名:0.7>, single avatar frame, square border, transparent background,
pixel art style, fantasy [bronze/silver/gold/platinum] ornate frame, decorative corners,
front view, MMORPG player avatar border
```

**负向**：
```
3d, realistic, photo, character face, scene, watermark, text
```

### 4.2 阵营图标

**正向**：
```
<lora:UI LoRA名:0.7>, single faction icon, centered, transparent background,
pixel art style, fantasy [alliance crest / horde skull], simple shading,
front view, MMORPG faction emblem
```

### 4.3 玩家名牌

**正向**：
```
<lora:UI LoRA名:0.7>, single UI nameplate, horizontal banner, transparent background,
pixel art style, fantasy ornate name tag, decorative border,
front view, MMORPG player name background
```

---

## 5. 后期处理要点

- 头像框：4 等级用 4 种金属色（铜/银/金/铂），描边宽度 3px
- 阵营图标：2 个互补色（蓝/红）
- 玩家名牌：256×32 横向，文字留空（运行时填玩家名）

---

## 6. 关联代码文件

| 文件 | 状态 | 改动 |
| --- | --- | --- |
| `data/factions.json` | **新建** | 2 阵营：id, name, icon, color |
| `scripts/net/player_avatar.gd` | **新建** | 玩家头顶名牌 + 头像框 |
| `scripts/net/player.gd` | 改 | 同步头像/阵营字段 |
| `scenes/ui/player_nameplate.tscn` | **新建** | 头顶名牌场景 |

---

## 7. 验收清单

- [ ] 7 个 UI 元素出图
- [ ] `data/factions.json` 完整
- [ ] 联机时能看到其他玩家的名牌 + 阵营图标
- [ ] 头像框等级正确显示
- [ ] git 提交 + push

---

## 8. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版 |
| 2026-10-09 | **编号由 M11 改为 M14**，与 `docs/roadmap.md` 的权威编号统一 |
