# 美术素材许可证登记表

> 每次新增素材/LoRA/模型，**当次**登记一行。发布前用此文件核对所有 license。
> 详细工作流见 `docs/reference/ai-asset-generation.md`。
> 配套 Prompt 速查见 `assets/_PROMPTS.md`，任务卡片见 `docs/tasks/`。

---

## 1. 模型 / LoRA（出图用）

> 状态：`已部署` = 文件存在且 SHA256 已校验；`下载中` = 用户本地下载未完；`已废弃` = 已删除或不再使用。

| 名称 | 类型 | 来源 URL | 用途 | License | 商用 | 作者署名 | 状态 | 下载日期 | 文件大小 | 放置路径 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SDXL base 1.0 | checkpoint | https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0 | SDXL 出图（角色立绘/Boss/概念图） | Open RAIL-M | ✓ | 否 | 已部署 | 2026-10-09 | 6.46 GiB | `D:\AI\models\checkpoints\sd_xl_base_1.0.safetensors` |
| SD 1.5 pruned-emaonly | checkpoint | https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5 | SD 1.5 出图（sprite/tileset/icon 主力） | Open RAIL-M | ✓ | 否 | 已部署 | 2026-10-10 | 3.97 GB（实际） | `D:\AI\models\checkpoints\v1-5-pruned-emaonly.safetensors` |
| **BG3 Item Icons** | LoRA | https://civitai.com/models/114331?modelVersionId=123588 （作者 Lykon） | **M11 装备图标**（50~100 张）；触发词 `bg3 item icon`；该模型**只有 SD 1.5 一个版本** | Civitai License：`allowCommercialUse = Image / RentCivit / Rent`；`allowNoCredit = True`；`allowDerivatives = True`；`allowDifferentLicense = True` | **✓ 允许**（列表含 `Image`） | 否（`allowNoCredit = True`） | 已部署 | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\bg3_item_icons_v1.safetensors` |
| **Dark and Darker - Portraits 2023** | LoRA | https://civitai.com/models/146048?modelVersionId=162546 （作者 UncleJert，取 name=`SD15` 那版） | **角色 / Boss 立绘**风格；触发词 `dark_and_darker_game_portrait_style`, `low_resolution` | Civitai License：`allowCommercialUse = **RentCivit**`（**不含 `Image`**）；`allowNoCredit = True`；`allowDerivatives = True`；`allowDifferentLicense = False` | **✗ 不允许商用生成图** | 否（`allowNoCredit = True`） | 已部署（**仅限原型/内部参考，发布前必须替换或删除**） | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\dark_and_darker_portraits_v1.safetensors` |
| **Medieval Style Armor Suit** | LoRA | https://civitai.com/models/59925?modelVersionId=67849 （作者 axebro） | **护甲类装备图标 + 角色装备**；触发词 `medieval armor` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\medieval_armor_suit_v1.safetensors` |
| **Creatures Portraits** | LoRA | https://civitai.com/models/31845?modelVersionId=38286 （作者 smereces_ai） | **怪物 / Boss 立绘**；触发词 `a fantz creature` | Civitai License：`allowCommercialUse = Image`；`allowNoCredit = **False**` | **✓ 允许** | **⚠️ 是（必须署名）** | 已部署 | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\creatures_portraits_v1.safetensors` |
| **Creatures Design V1** | LoRA | https://civitai.com/models/31618?modelVersionId=38059 （作者 smereces_ai） | **怪物设计**；触发词 `fantz creature`, `monster` | Civitai License：`allowCommercialUse = Image`；`allowNoCredit = **False**` | **✓ 允许** | **⚠️ 是（必须署名）** | 已部署 | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\creatures_design_v1.safetensors` |
| **Game Icon_Skill_Buff** | LoRA | https://civitai.com/models/86741?modelVersionId=92267 （作者 HuXiangameicon） | **M7 技能图标**（增益/光环类）；触发词 `guangquan(skill icon)`, `aura`, `glowing` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-10 | 72.1 MB | `D:\AI\models\lora\game_icon_skill_buff_v1.safetensors` |
| **Handpainted RPG Icons Style** | LoRA | https://civitai.com/models/6876?modelVersionId=8081 （作者 Nix0npolska） | 图标兜底（手绘 RPG 图标）；触发词 `rpgicondiff` | Civitai License：`allowCommercialUse = Image`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-10 | 144.1 MB | `D:\AI\models\lora\handpainted_rpg_icons_v1.safetensors` |
| **Medieval Background slider (or de-Modern)** | LoRA | https://civitai.com/models/247828?modelVersionId=286106 （作者 oosayam） | 场景 / **去现代感**；触发词 `Half-timbered Construction` | Civitai License：`allowCommercialUse = Image / RentCivit`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-10 | 3.1 MB | `D:\AI\models\lora\medieval_background_slider_v1.safetensors` |
| **Monsters Attack - Surrounded by monsters** | LoRA | https://civitai.com/models/96018?modelVersionId=102553 （作者 Tomas_Aguilar） | 怪群 / 多怪场景氛围；**无触发词** | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-10 | 36.1 MB | `D:\AI\models\lora\monsters_attack_v1.safetensors` |
| Medieval - CE | LoRA | https://civitai.com/models/754926?modelVersionId=851008 （作者 CreativeEdge） | 通用中世纪风格（兜底）；触发词 `mdvlCE` | Civitai License：`allowCommercialUse = Image / RentCivit`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署（**API token 补齐**） | 2026-10-12 | 345 MB | `D:\AI\models\lora\medieval_ce_v1.safetensors` |
| Knight | LoRA | https://civitai.com/models/299760?modelVersionId=336656 （作者 oosayam） | 骑士（角色/Boss 轻量试错）；触发词 `knight`, `armor` | Civitai License：`allowCommercialUse = Image / RentCivit`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署（**API token 补齐**） | 2026-10-12 | 15 MB | `D:\AI\models\lora\knight_v1.safetensors` |
| Fantasy Knight Armor | LoRA | https://civitai.com/models/320076?modelVersionId=358910 （作者 Ark_Ai） | 奇幻骑士铠甲（角色/Boss）；触发词 `FantasyKnightV1` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署（**API token 补齐**） | 2026-10-12 | 72 MB | `D:\AI\models\lora\fantasy_knight_armor_v1.safetensors` |
| **Crucible knight armor (ELDEN RING)** | LoRA | https://civitai.com/models/561251?modelVersionId=625113 （作者 tn1102） | 角色 / Boss · 熔炉骑士铠甲（ELDEN RING 风格）；触发词 `crucible armor` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True`；**base = SD 1.5** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 72.1 MB | `D:\AI\models\lora\sd15_A_crucible_knight.safetensors` |
| **Dragonborn Concept LoRA** | LoRA | https://civitai.com/models/114079?modelVersionId=123280 （作者 Lykon） | 角色 / Boss · 龙裔；触发词 `dragonborn`, `[color] dragonborn` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent`；`allowNoCredit = True`；**base = SD 1.5** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 144.1 MB | `D:\AI\models\lora\sd15_A_dragonborn.safetensors` |
| **Game Item UI** | LoRA | https://civitai.com/models/21102?modelVersionId=25116 （作者 378866459393） | 装备图标 / UI 通用；触发词（无） | Civitai License：`allowCommercialUse = 空`；`allowNoCredit = True`；**base = SD 1.5** | ✗ 不含 Image（非商用可用） | 否 | 已部署 | 2026-10-12 | 36.1 MB | `D:\AI\models\lora\sd15_C_game_item_ui.safetensors` |
| **宝石（Game gems）** | LoRA | https://civitai.com/models/142127?modelVersionId=157564 （作者 MysteriousEasternpower） | 装备图标 · 宝石与物品列表；触发词 `Game icons`, `gem designs`, `item lists` | Civitai License：`allowCommercialUse = 空`；`allowNoCredit = True`；**base = SD 1.5** | ✗ 不含 Image（非商用可用） | 否 | 已部署 | 2026-10-12 | 144.1 MB | `D:\AI\models\lora\sd15_C_game_gems.safetensors` |
| **Nargacuga Armorset (Monster Hunter)** | LoRA | https://civitai.com/models/59787?modelVersionId=80896 （作者 pensive_penguin） | 角色装备 · 铠甲套装（Monster Hunter）；触发词 `nargacuga armor` | Civitai License：`allowCommercialUse = Rent / RentCivit`；`allowNoCredit = True`；**base = SD 1.5** | ✗ 不含 Image（非商用可用） | 否 | 已部署 | 2026-10-12 | 36.1 MB | `D:\AI\models\lora\sd15_C_armorset_nargacuga.safetensors` |
| **Real dragons 真实龙** | LoRA | https://civitai.com/models/82903?modelVersionId=88077 （作者 ArienTOP） | Boss · 龙；触发词 `dragon_real`, `flame` | Civitai License：`allowCommercialUse = 空`；`allowNoCredit = True`；**base = SD 1.5** | ✗ 不含 Image（非商用可用） | 否 | 已部署 | 2026-10-12 | 72.1 MB | `D:\AI\models\lora\sd15_D_real_dragons.safetensors` |
| **Creature - Abstract Monster** | LoRA | https://civitai.com/models/221532?modelVersionId=249879 （作者 MerrowDreamer） | Boss · 抽象怪物；触发词 `AbstractMonster` | Civitai License：`allowCommercialUse = 空`；`allowNoCredit = True`；**base = SD 1.5** | ✗ 不含 Image（非商用可用） | 否 | 已部署 | 2026-10-12 | 27.1 MB | `D:\AI\models\lora\sd15_D_abstract_monster.safetensors` |
| **GameIconResearch_skill_Lora3** | LoRA | https://civitai.com/models/82609?modelVersionId=87745 （作者 ConceptConnoisseur） | M7 技能图标；触发词 `skill icon`, `game icon` | Civitai License：`allowCommercialUse = 空`；`allowNoCredit = True`；**base = SD 1.5** | ✗ 不含 Image（非商用可用） | 否 | 已部署 | 2026-10-12 | 72.1 MB | `D:\AI\models\lora\sd15_E_skill_icon_research.safetensors` |
| **Game Icon_Skill_Healing** | LoRA | https://civitai.com/models/84345?modelVersionId=89666 （作者 HuXiangameicon） | M7 技能图标 · 治疗系；触发词 `cureglowing\(skill icon\)`, `glowing`, `aura` | Civitai License：`allowCommercialUse = 空`；`allowNoCredit = **False**`；**base = SD 1.5** | ✗ 不含 Image（非商用可用） | **⚠️ 是（必须署名）** | 已部署 | 2026-10-12 | 72.1 MB | `D:\AI\models\lora\sd15_E_skill_icon_healing.safetensors` |
| **UIA game scene lora｜European architecture** | LoRA | https://civitai.com/models/157637?modelVersionId=177074 （作者 UIAlngenuity） | UI / 场景 · 欧式建筑；触发词 `UIAYX` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True`；**base = SD 1.5** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 36.1 MB | `D:\AI\models\lora\sd15_F_ui_scene_european.safetensors` |
| **Fantasy Character Portraits** | LoRA | https://civitai.com/models/2350357?modelVersionId=2643504 （作者 SebQuenet） | 角色 / Boss · 奇幻立绘；触发词（无） | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True`；**base = SDXL 1.0** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_A_fantasy_portraits.safetensors` |
| **Seamless Patterns by Styx** | LoRA | https://civitai.com/models/949221?modelVersionId=1062759 （作者 STXai） | 地砖 · 无缝图案；触发词（无） | Civitai License：`allowCommercialUse = RentCivit`；`allowNoCredit = True`；**base = SDXL 1.0** | ✗ 不含 Image（非商用可用） | 否 | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_B_seamless_patterns_styx.safetensors` |
| **[SDXL] RPG Item Icons** | LoRA | https://civitai.com/models/2507819?modelVersionId=2818920 （作者 ai_thingies） | 装备图标 · RPG 物品；触发词（无） | Civitai License：`allowCommercialUse = Image / RentCivit / Rent`；`allowNoCredit = True`；**base = SDXL 1.0** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 177.1 MB | `D:\AI\models\lora\sdxl_C_rpg_item_icons.safetensors` |
| **Weapon Sword & Shield - By HailoKnight** | LoRA | https://civitai.com/models/230342?modelVersionId=259964 （作者 HailoKnight） | 装备图标 · 剑与盾；触发词 `Sword and shield` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = **False**`；**base = SDXL 1.0** | **✓ 含 Image** | **⚠️ 是（必须署名）** | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_C_sword_shield.safetensors` |
| **Dark Fantasy Art** | LoRA | https://civitai.com/models/227408?modelVersionId=256543 （作者 humblemikey） | Boss · 暗黑奇幻；触发词 `dark fantasy` | Civitai License：`allowCommercialUse = Image / RentCivit`；`allowNoCredit = True`；**base = SDXL 1.0** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 40.9 MB | `D:\AI\models\lora\sdxl_D_dark_fantasy_art.safetensors` |
| **Western Dragon Collection XL - Classic style** | LoRA | https://civitai.com/models/153332?modelVersionId=171702 （作者 kuritsutian197） | Boss · 西式龙；触发词 `dragon`, `classic dragon`, `exotic dragon` | Civitai License：`allowCommercialUse = Image / RentCivit`；`allowNoCredit = True`；**base = SDXL 1.0** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 163.5 MB | `D:\AI\models\lora\sdxl_D_western_dragon.safetensors` |
| **Fantasy Classes SD** | LoRA | https://civitai.com/models/287148?modelVersionId=322959 （作者 whalebotanist） | A 角色 / 角色 / Boss · 职业角色（fighter / wizard / mage）；触发词 `fighter`, `wizard`, `mage` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True`；**base = SD 1.5** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 36.1 MB | `D:\AI\models\lora\sd15_A_fantasy_classes.safetensors` |
| **Stylized Textures (Game Asset) [ZIT]** | LoRA | https://civitai.com/models/503877?modelVersionId=560098 （作者 CitronLegacy） | B 地砖 / 地砖 · 风格化游戏贴图；触发词 `zzStylizedTexture,` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent`；`allowNoCredit = True`；**base = SD 1.5** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 72.1 MB | `D:\AI\models\lora\sd15_B_stylized_textures.safetensors` |
| **Faithful 32px seamless blocks** | LoRA | https://civitai.com/models/380187?modelVersionId=424453 （作者 Conczin） | B 地砖 / 地砖 · 无缝方块（Faithful 32px）；触发词 `seamless`, `block` | Civitai License：`allowCommercialUse = RentCivit / Rent`；`allowNoCredit = True`；**base = SD 1.5** | ✗ 不含 Image（非商用可用） | 否 | 已部署 | 2026-10-12 | 72.1 MB | `D:\AI\models\lora\sd15_B_seamless_blocks.safetensors` |
| **Treasure Chest宝箱 金币 欧美卡通风格UI** | LoRA | https://civitai.com/models/405125?modelVersionId=451690 （作者 Zaki_zhao） | F UI / UI · 宝箱 / 金币图标；触发词 `Treasure Chest`, `Game chest icon` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True`；**base = SD 1.5** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 36.1 MB | `D:\AI\models\lora\sd15_F_treasure_chest.safetensors` |
| **huanqing_欧美风ui** | LoRA | https://civitai.com/models/358424?modelVersionId=400627 （作者 huanqing） | F UI / UI · 欧美风游戏界面；触发词 `Game interface`, `character information`, `game icon` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True`；**base = SD 1.5** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 72.1 MB | `D:\AI\models\lora\sd15_F_ui_huanqing.safetensors` |
| **Knight Armor | Warrior** | LoRA | https://civitai.com/models/2317023?modelVersionId=2606736 （作者 thevoiid） | A 角色 / 角色 / Boss · 骑士战士；触发词 `knight crusader, helmet, pointy crusader helmet, great helm, great helm with a cross, flat great helm, flat great helm with a cross, flat crusader helmet` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent`；`allowNoCredit = False`；**base = SDXL 1.0** | **✓ 含 Image** | **⚠️ 是** | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_A_knight_warrior.safetensors` |
| **JNetz Character Creator: High Fantasy** | LoRA | https://civitai.com/models/1469306?modelVersionId=1661841 （作者 Alex_Roca_Toolworks） | A 角色 / 角色 / Boss · 高奇幻角色；触发词 `high fantasy` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True`；**base = SDXL 1.0** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_A_high_fantasy_creator.safetensors` |
| **Fantasy Game Characters 0.0.1** | LoRA | https://civitai.com/models/1091297?modelVersionId=1225645 （作者 Doctor_Poon） | A 角色 / 角色 / Boss · 奇幻游戏角色；触发词 （无） | Civitai License：`allowCommercialUse = RentCivit / Rent`；`allowNoCredit = True`；**base = SDXL 1.0** | ✗ 不含 Image（非商用可用） | 否 | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_A_fantasy_chars.safetensors` |
| **Game Icon Forge - Turn Anything Into a Fantasy** | LoRA | https://civitai.com/models/2750041?modelVersionId=3093666 （作者 Booyaka） | C 装备 / 装备 / 技能图标 · 万能图标生成；触发词 `gicon` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True`；**base = SDXL 1.0** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 225.4 MB | `D:\AI\models\lora\sdxl_C_game_icon_forge.safetensors` |
| **Weapon Rune Sword - By HailoKnight** | LoRA | https://civitai.com/models/802160?modelVersionId=896933 （作者 HailoKnight） | C 装备 / 装备图标 · 符文剑；触发词 `runesword` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = False`；**base = SDXL 1.0** | **✓ 含 Image** | **⚠️ 是** | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_C_rune_sword.safetensors` |
| **XL Weapon Dual Swords - By HailoKnight** | LoRA | https://civitai.com/models/315856?modelVersionId=354293 （作者 HailoKnight） | C 装备 / 装备图标 · 双剑；触发词 `Dual Swords` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = False`；**base = SDXL 1.0** | **✓ 含 Image** | **⚠️ 是** | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_C_dual_swords.safetensors` |
| **XL Weapon Curved Sword Slash - By HailoKnight** | LoRA | https://civitai.com/models/367637?modelVersionId=410839 （作者 HailoKnight） | C 装备 / 装备图标 · 弯刀挥砍；触发词 `Curved Sword Slash` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = False`；**base = SDXL 1.0** | **✓ 含 Image** | **⚠️ 是** | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_C_curved_sword_slash.safetensors` |
| **Dark Fantasy | KREA 2, SDXL** | LoRA | https://civitai.com/models/1223108?modelVersionId=1618369 （作者 patrik） | D Boss / Boss · 暗黑奇幻（KREA2）；触发词 `	dark fantasy art style` | Civitai License：`allowCommercialUse = RentCivit / Image / Rent`；`allowNoCredit = True`；**base = SDXL 1.0** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_D_dark_fantasy_krea.safetensors` |
| **Dark Fantasy Painting | Pony & SDXL** | LoRA | https://civitai.com/models/470727?modelVersionId=752937 （作者 peam3178） | D Boss / Boss · 暗黑奇幻厚涂；触发词 （无） | Civitai License：`allowCommercialUse = Rent / RentCivit / Image`；`allowNoCredit = True`；**base = SDXL 1.0** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_D_dark_fantasy_painting.safetensors` |
| **Unfazed magic loras** | LoRA | https://civitai.com/models/487304?modelVersionId=715524 （作者 unfazedanomaly964） | E 技能 / 技能 · 法术对决 / 火焰特效；触发词 `duel, magical duel,`, `fire magic,`, `fire spell,` | Civitai License：`allowCommercialUse = Sell / Rent / RentCivit / Image / SellMerge`；`allowNoCredit = False`；**base = SDXL 1.0** | **✓ 含 Image** | **⚠️ 是** | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_E_magic_duel.safetensors` |
| **Wooden Mobile Game GUI** | LoRA | https://civitai.com/models/746762?modelVersionId=835075 （作者 alexthestork402） | F UI / UI · 木质手游 GUI；触发词 `gui`, `games`, `ui` | Civitai License：`allowCommercialUse = Image / RentCivit / Rent / Sell / SellMerge`；`allowNoCredit = True`；**base = SDXL 1.0** | **✓ 含 Image** | 否 | 已部署 | 2026-10-12 | 188.8 MB | `D:\AI\models\lora\sdxl_F_wooden_gui.safetensors` |
| **Hand-Painted 2d Seamless Textures** | LoRA | https://civitai.com/models/483692?modelVersionId=537948 （作者 Zovya） | B 地砖 / 地砖 · 手绘无缝贴图；触发词 `2d seamless hand-painted texture` | Civitai License：`allowCommercialUse = Image / RentCivit`；`allowNoCredit = False`；**base = SDXL 1.0** | **✓ 含 Image** | **⚠️ 是** | 已部署 | 2026-10-12 | 217.9 MB | `D:\AI\models\lora\sdxl_B_handpainted_seamless.safetensors` |
| _待填_ | LoRA | _Civitai URL_ | _角色/场景/物品/UI_ | _Open RAIL-M / CC-BY-SA / 等_ | _是/否_ | _是/否_ | _待部署_ | _YYYY-MM-DD_ | _X MB_ | `D:\AI\models\lora\子目录\xxx.safetensors` |

> ⚠️ **许可取值口径**（2026-10-12 随「本项目非商用」修订，见 `AGENTS.md` §1）：Civitai 的许可字段在
> **模型层级**（`/api/v1/models/{id}` 的 `allowCommercialUse` / `allowNoCredit` / `allowDerivatives` /
> `allowDifferentLicense`），**不在**版本层级（版本详情只有 `usageControl`，所有模型同一个值，用不了）。
> 字段含义：`allowCommercialUse` **含 `Image`** = 生成图可商用；只有 `RentCivit` / `Rent` = **不能**商用生成图；
> **为空** = 未授权商用。上表取值**全部取自模型层级 API**（模型页右侧 Details 卡片的 **License** 一栏可复核），
> 页面若有 API 之外的附加条款以页面为准。
>
> ✅ **批量筛选口径**（本项目**非商用** → 2026-10-12 起放开）：
> 用 `/api/v1/models?query=...&types=LORA&baseModels=SD 1.5|SDXL 1.0&sort=Most Downloaded&nsfw=false` 检索
> （**列表接口也带模型层级许可字段**，一次请求即可筛）→ **`allowCommercialUse` 不再作为筛选硬条件**，
> `Image` / `RentCivit` / `Rent` / `Sell` / 空值**都可用**。本表仍逐条记录它 ——
> **那是将来转商用复核的唯一依据，不能省**。
> 仍需排除的只有两类：① 明确禁止任何使用 / 仅限查看；② **base 与目标 checkpoint 不一致**的版本
> （SD 1.5 的 LoRA 不能上 SDXL，反之亦然）。`allowNoCredit = False` 的条目**必须署名**（非商用也不免）。
>
> ⚠️ **登录墙**（2026-10-12 实测）：大量模型现在要求登录才能下载，匿名请求返回
> `401 {"error":"Unauthorized","message":"The creator of this asset requires you to be logged in to download it"}`。
> 破解办法：下载 URL 后加 `?token=<Civitai API Key>`（`civitai.com/user/account` → API Keys）。
> 本轮 33 次下载尝试里**有 17 个被这堵墙挡住**（完整清单见 `docs/tasks/backlog.md` T-06）。
>
> ⚠️ **`Dark and Darker - Portraits`**：许可只有 `RentCivit`，**非商用下可用**；
> **待对比结果出来后再决定是否删除**（backlog T-07），不再要求"发布前必须换掉"。

> **如何快速填这一行**：
> 1. 在 Civitai 找 LoRA 时，**同时复制 LoRA 页面 URL + License 字段**（页面右下角"License"下拉）；
> 2. 文件名按「**base + 用途 + 描述**」命名，例如 `sd15_C_game_gems.safetensors`、`sdxl_D_dark_fantasy_art.safetensors`
>    —— `sd15_` / `sdxl_` 前缀直接标明它能在哪个 checkpoint 上测；
> 3. **全部平铺在 `D:\AI\models\lora\`**，不要再分子目录（旧文档写的 `角色\` / `场景\` / `物品\` / `UI\` 已废弃，
>    避免和登记表两套口径）；
> 4. 本表加一行 + 同步 `tools/lora-compare/data/loras.json`（对比台靠它自动注入触发词、判断 base 兼容）
>    → 提交 git。

**国风 / 西游 / 等距 批次（2026-10-12 新增，梦幻西游方向）**

> 底模放在 `D:\AI\models\checkpoints\`（Forge 里经 junction `models\Stable-diffusion\_D_AI_ckpt` 可见），
> LoRA 放在 `D:\AI\models\lora\`。体积均已与 Civitai API 报的 `sizeKB` 核对。

| 名称 | 类型 | 来源 | 用途 | 许可原文 | 商用 | 署名 | 状态 | 登记日期 | 体积 | 本地路径 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **国风3 GuoFeng3** | Checkpoint | https://civitai.com/models/10415?modelVersionId=106289 （作者 xiaolxl，SD 1.5） | 国风3 底模（2.5D 古风游戏角色向） | `allowCommercialUse = []`；`allowNoCredit = False`；`allowDerivatives = True` | ⚠️ 字段为空 | **⚠️ 是（必须署名）** | 已部署 | 2026-10-12 | 2193.4 MB | `D:\AI\models\checkpoints\guofeng3_v32.safetensors` |
| **Isometric Chinese style Architecture LoRa** | LoRA | https://civitai.com/models/63376?modelVersionId=67927 （作者 axebro，SD 1.5） | 等距中国建筑（场景） | `allowCommercialUse = ['Image','RentCivit','Rent','Sell','SellMerge']`；`allowNoCredit = True` | **✓ 允许** | 否 | 已部署 | 2026-10-12 | 72.1 MB | `D:\AI\models\lora\sd15_B_isometric_chinese_arch.safetensors` |
| **HEZI Q版3D泡泡玛特质感** | LoRA | https://civitai.com/models/339670?modelVersionId=380348 （作者 HEZI_，SD 1.5） | Q版 3D 玩具质感（备用） | `allowCommercialUse = ['Image','RentCivit','Rent','Sell','SellMerge']`；`allowNoCredit = True` | **✓ 允许** | 否 | ⛔ **未下载**（`401` 登录墙） | 2026-10-12 | 108.1 MB | `D:\AI\models\lora\sd15_D_qstyle_3d_toy.safetensors` |
| **西游主题插画（Chinese painting style）** | LoRA | https://civitai.com/models/61837?modelVersionId=66943 （作者 bird_of_pool，SD 1.5） | 西游题材插画风 | `allowCommercialUse = []`；`allowNoCredit = True` | ⚠️ 字段为空 | 否 | 已部署 | 2026-10-12 | 72.1 MB | `D:\AI\models\lora\sd15_D_westward_illust.safetensors` |
| **西游Journey2West** | LoRA | https://civitai.com/models/71456?modelVersionId=76159 （作者 WanDou7，SD 1.5） | 西游人物（悟空）；触发词 `Monkey king, wukong_xingzhe` | `allowCommercialUse = []`；`allowNoCredit = True` | ⚠️ 字段为空 | 否 | 已部署 | 2026-10-12 | 36.1 MB | `D:\AI\models\lora\sd15_A_westward_wukong.safetensors` |
| **中国仙侠** | LoRA | https://civitai.com/models/138759?modelVersionId=153361 （作者 ffffff，SD 1.5） | 中国仙侠；触发词 `cnxianxia` | `allowCommercialUse = []`；`allowNoCredit = True` | ⚠️ 字段为空 | 否 | 已部署 | 2026-10-12 | 144.1 MB | `D:\AI\models\lora\sd15_D_cn_xianxia.safetensors` |
| **武侠 Wuxia V2** | LoRA | https://civitai.com/models/76637?modelVersionId=90181 （作者 chocolae，SD 1.5） | 武侠；触发词 `gu, wuxia, holding weapon, dragon` | `allowCommercialUse = []`；`allowNoCredit = True` | ⚠️ 字段为空 | 否 | 已部署 | 2026-10-12 | 96.4 MB | `D:\AI\models\lora\sd15_A_wuxia_v2.safetensors` |
| **仙侠道 / xianxia / taoist** | LoRA | https://civitai.com/models/96244?modelVersionId=102800 （作者 chosen，SD 1.5） | 仙侠道；触发词 `taoist` | `allowCommercialUse = []`；`allowNoCredit = True` | ⚠️ 字段为空 | 否 | 已部署 | 2026-10-12 | 144.1 MB | `D:\AI\models\lora\sd15_A_xianxia_taoist.safetensors` |
| **国风3Lora GuoFeng3_Lora** | LoRA | https://civitai.com/models/11352?modelVersionId=17518 （作者 xiaolxl，base `Other`） | 国风3 配套 LoRA（LoCon，576 MB） | `allowCommercialUse = []`；`allowNoCredit = False`；`allowDerivatives = True` | ⚠️ 字段为空 | **⚠️ 是（必须署名）** | 已部署 | 2026-10-12 | 576.1 MB | `D:\AI\models\lora\sd15_D_guofeng3_lora.safetensors` |

---

**生图后端批次（2026-10-12 换用 Qwen-Image 2.1 + ComfyUI）**

> ⚠️ **SD 系全部弃用**：SD 1.5 / SDXL / 国风3 底模、54 个 SD LoRA、ControlNet tile —— 与 Qwen 架构不通，
> **LoRA 一律不可复用**。上面各表的登记行**保留存档**（用于复核"是否已从磁盘删除"），本机正在清理。
>
> ⚠️ **`ComfyUI` 仅作为本机工具使用**（GPL-3.0，不进本仓库、不复制其代码），符合 §1 的"不复制 GPL 项目代码"铁律。

| 名称 | 类型 | 来源 | 用途 | 许可原文 | 商用 | 状态 | 登记日期 | 体积 | 本地路径 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Qwen-Image 2.1** | Diffusion(unet) | <https://www.modelscope.cn/models/Comfy-Org/Qwen-Image-2.1>（ComfyUI 官方重打包；原模型 `Qwen/Qwen-Image-2.1`） | 主生成模型（视觉生成分支 7B，**原生 RGBA 透明图**） | **Qwen Research License（研究用途）**：免费下载、个人/技术评估可用；**商用（含电商素材、商业插画）需另行申请授权** | ⚠️ **非商用可用；转商用必须申请** | 已部署 | 2026-10-12 | 6.76 GB | `D:\AI\models-comfy\diffusion_models\qwen_image_2.1_int8_convrot.safetensors` |
| **Qwen3-VL-8B**（文本编码器） | Text encoder | 同上 | 文本编码器（`CLIPLoader` 的 type = `qwen_image`） | 随 Qwen-Image 2.1 一并分发，同上许可 | ⚠️ 同上 | 已部署 | 2026-10-12 | 8.71 GB | `D:\AI\models-comfy\text_encoders\qwen3vl_8b_int8_convrot.safetensors` |
| **Qwen-Image 2.1 VAE** | VAE | 同上 | 解码（**带 alpha 通道**，透明底的关键） | 同上 | ⚠️ 同上 | 已部署 | 2026-10-12 | 0.63 GB | `D:\AI\models-comfy\vae\qwen_image_2.1_vae_bf16.safetensors` |
| **Qwen-Image 2.1 Turbo LoRA** | LoRA | 同上 | 8 步加速。⚠️ **用它就必须 cfg=1，此时负向提示词完全失效** | 同上 | ⚠️ 同上 | 已部署 | 2026-10-12 | 0.85 GB | `D:\AI\models-comfy\loras\qwen_image_2.1_turbo_lora_avg_rank_178_bf16.safetensors` |
| **ComfyUI 0.39.0** | 出图前端 | <https://github.com/Comfy-Org/ComfyUI> | 出图界面 / API（**仅本机工具，不入仓库**） | GPL-3.0 | — | 已部署 | 2026-10-12 | — | `D:\AI\ComfyUI\comfyui-master` |

> 未下载（8GB 显存下**必须不启用**）：两个「提示词增强器」各 8.82 GB、ControlNet 补丁 3.52 GB。
> 可选优化（未下）：`qwen3vl_8b_w4a8` 文本编码器 **5.88 GB**（比现在的 int8 少 2.83 GB）。

---

## 2. 直接使用的素材（图、纹理、spritesheet 等）

| 名称 | 来源 | 用途 | License | 作者署名要求 | 项目内路径 |
| --- | --- | --- | --- | --- | --- |
| _待填_ | _URL/作者_ | _敌人/装备/UI_ | _Open RAIL-M / CC0 / 等_ | _是/否_ | `res://assets/...` |

---

## 3. License 速查

- **Open RAIL-M**（Stable Diffusion 默认）：允许商用，无须署名（默认勾选）
- **CC-BY-SA**：允许商用，**必须署名作者**，衍生作品需同 license 发布
- **CC-BY-NC**：仅限非商用，**禁止**发布商业项目
- **CC0 / Public Domain**：完全无限制
- ⚠️ **"待填"或空白**的素材**不得使用**（发布前清空本文件所有待填行）

---

## 4. 登记 SOP（每次新加素材必做）

1. **下载前**先打开本文件，复制一行模板（`模型/LoRA` 表的第 3 行）。
2. **下载中**把表格新行的 6 个必填项填好：
   - `来源 URL`：Civitai 页面 / Hugging Face 仓库链接
   - `License`：从 Civitai 页面右下角"License"读，**不要凭印象写**
   - `商用` / `作者署名`：看 License 字段的"Use the model without crediting" / "Sell generated images"选项
3. **下载完成**后填：
   - `状态` = `已部署`
   - `下载日期` = `YYYY-MM-DD`
   - `文件大小` = 实际下载大小
   - `放置路径` = 完整文件路径
4. **git 提交**：
   ```bash
   git add assets/_LICENSES.md
   git commit -m "licenses: add <LoRA名> (<用途>)"
   ```
5. **启动 Forge 出图前**重新读本表一次，确认没有"待填"行的素材被引用。

---

## 5. 校验记录（已校验的模型 SHA256）

> 本节只登记**已用 hash 校验完整下载**的模型。
> 校验方法：Forge 起来后用 Python（`hashlib.sha256()`）算，或用 `certutil -hashfile`。

| 名称 | SHA256 | 校验日期 | 备注 |
| --- | --- | --- | --- |
| SDXL base 1.0 | _待 Forge 起来后回填_ | _YYYY-MM-DD_ | 之前已通过 `download_models.ps1` 做大小/字节校验 |
| SD 1.5 pruned-emaonly | _待下载完成后回填_ | _YYYY-MM-DD_ | |

---

## 6. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-09 | 初版：登记 SDXL base 1.0（已部署）+ SD 1.5（下载中），加 SOP + License 速查 |
| 2026-10-10 | SD 1.5 pruned-emaonly 状态改为**已部署**（实际 3.97 GB，路径 `D:\AI\models\checkpoints\`）；`D:\AI\models\{lora,controlnet,vae,embeddings}` 目前均为空 |
| 2026-10-10 | 新增 2 个 LoRA：**BG3 Item Icons**（M11 装备图标）+ **Dark and Darker Portraits**（角色/Boss 立绘），各 144.1 MB，经本机代理从 Civitai 下载。**许可字段留「待确认」**——Civitai 新版 API 已不返回许可信息，需人工看模型页回填。`D:\AI\models\lora` 经 junction 挂到 Forge 的 `models\Lora\_D_AI` |
| 2026-10-10 | **按"允许商用"重新筛选并批量下载 10 个 LoRA**（中世纪奇幻方向，风格要求放宽）：7 个已部署（Medieval Style Armor Suit / Creatures Portraits / Creatures Design V1 / Game Icon_Skill_Buff / Handpainted RPG Icons / Medieval Background slider / Monsters Attack），3 个因**作者要求登录（401）**暂缺。修正许可口径：字段在**模型层级**（不是版本层级），判定条件是 `allowCommercialUse` 含 `Image`。**`smereces_ai` 的两条要求署名**（`allowNoCredit=False`） |
| 2026-10-12 | **新增「国风 / 西游 / 等距」批次 9 项**（梦幻西游方向，见 §1 的新表）：**8 个已部署 / 1 个被 401 挡**。含 **国风3 底模**（2193.4 MB，SD 1.5，2.5D 古风游戏角色向）——**必须署名**（`allowNoCredit=False`）；`国风3Lora` 同样**必须署名**。**原计划的 `Journey to the West Game Icons` 经查是 `Krea 2` 底模（不可用于 SD 1.5/SDXL）已弃用**，改用两个 SD 1.5 西游题材 LoRA 替代。检索与下载脚本在 `D:\AI\tmp\gf_fetch.py` / `gf_retry.py` |
