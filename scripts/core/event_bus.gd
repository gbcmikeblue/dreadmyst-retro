extends Node
## 全局事件总线（Autoload 名称：Events）
##
## 设计目的：让 玩家 / 敌人 / 掉落物 / HUD 之间不直接互相引用，
## 只通过信号通信，后续替换任一模块时不会级联修改。

## 玩家血量变化(current, maximum)
signal player_health_changed(current: int, maximum: int)
## 玩家等级变化(level, xp, xp_to_next)
signal player_level_changed(level: int, xp: int, xp_to_next: int)
## 玩家总属性变化（含装备加成）
signal player_stats_changed(stats: Dictionary)
## 装备栏变化
signal equipment_changed(equipment: Dictionary)
## 金币变化
signal gold_changed(amount: int)
## 造成伤害(世界坐标, 数值, 是否暴击, 是否是玩家受伤)
signal damage_dealt(world_position: Vector3, amount: int, is_crit: bool, on_player: bool)
## 敌人死亡(敌人等级, 世界坐标)
signal enemy_died(enemy_level: int, world_position: Vector3)
## 拾取到装备
signal loot_picked_up(gear)
## 屏幕提示(message, color)
signal toast(message: String, color: Color)

# ---------------------------------------------------------------- M7 技能

## 玩家蓝量变化(current, maximum)
signal player_mana_changed(current: int, maximum: int)
## 玩家职业变化(职业 id, 显示名, 职业色)
signal player_profession_changed(profession_id: String, display_name: String, color: Color)
## 玩家技能列表变化（Array[SkillDef]，约定第 0 个是普攻、第 1 个是大招）
signal player_skills_changed(skills: Array)
## 技能冷却变化 {skill_id: 剩余秒数}。冷却全部走完时也会发一次（值为空字典）
signal skill_cooldowns_changed(cooldowns: Dictionary)
