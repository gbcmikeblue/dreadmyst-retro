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

# ---------------------------------------------------------------- M8 属性加点

## 属性点分配变化(属性 id -> 已投入点数, 剩余可加点数, 已投入总点数)
signal attributes_changed(attributes: Dictionary, free_points: int, spent_points: int)
## UI 请求投入属性点(属性 id, 点数)。由 Player 监听并执行，结果通过 attributes_changed 广播。
## UI 不直接引用 Player，与「跨模块只走信号总线」的约定保持一致。
signal attribute_allocate_requested(attribute_id: String, points: int)

# ---------------------------------------------------------------- M10 地城与 Boss

## 传送门请求进入地城(地城 id) / 请求离开地城。由 Portal 发出，main.gd 执行进出流程。
signal dungeon_enter_requested(dungeon_id: String)
signal dungeon_exit_requested
## 已进入地城(地城显示名, 房间总数)
signal dungeon_entered(display_name: String, room_count: int)
## 某个房间已清空(房间号从 0 开始, 房间总数)
signal dungeon_room_cleared(room_index: int, room_count: int)
## 已离开地城
signal dungeon_exited
## Boss 出现(显示名, 等级, 生命上限)
signal boss_spawned(display_name: String, level: int, max_hp: int)
## Boss 血量变化(current, maximum)。只在数值变化时发
signal boss_health_changed(current: int, maximum: int)
## Boss 被击败(显示名)
signal boss_defeated(display_name: String)
## 交互提示文本变化("" 表示隐藏)。由 Portal 发出（靠近/离开时各发一次），HUD 显示
signal interact_prompt_changed(text: String)

# ---------------------------------------------------------------- M11 背包 / 商店

## 背包内容变化(物品数组 Array[GearItem], 容量)
signal backpack_changed(items: Array, capacity: int)
## 请求把一件装备放进背包（商店购买等外部来源）。背包满时 Player 会提示并不入包
signal backpack_add_requested(gear)
## UI 请求把背包第 index 件装备穿上（换下来的旧装备回到背包）
signal backpack_equip_requested(index: int)
## UI 请求分解（卖出）背包第 index 件装备
signal backpack_sell_requested(index: int)
## UI 请求一键换装（每个部位挑背包里评分最高且优于当前的那件）
signal backpack_optimize_requested
## 商店货架变化(Array[Dictionary]，元素 {gear: GearItem, price: int, slot_key: String})
signal shop_stock_changed(offers: Array)
## UI 请求拉一次货架（打开商店页时发）
signal shop_stock_requested
## UI 请求刷新货架（花金币重roll）
signal shop_restock_requested
## UI 请求购买第 index 件货架商品
signal shop_buy_requested(offer_index: int)

# ---------------------------------------------------------------- M13 存档

## 请求槽位摘要（标题选档界面打开时发）
signal save_slots_requested
## 槽位摘要变化(Array[Dictionary]，元素见 SaveData.summary_from_dict + slot)
signal save_slots_changed(slots: Array)
## 请求：读取槽位 slot 开始游戏
signal save_load_requested(slot: int)
## 请求：在槽位 slot 开新档（已有档则覆盖）
signal save_new_game_requested(slot: int)
## 请求：删除槽位 slot
signal save_delete_requested(slot: int)
