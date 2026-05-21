# 05 Passive Item Audit

日期：2026-05-21

本文把用户侧“被动物品/物品”与代码内 `ornament` 数据表对齐。当前数据源是 `data/ornaments/ornaments.json`，共 56 个条目；运行时仍沿用 `OrnamentData`、`OrnamentEffect`、`GenericOrnamentEffect` 命名。

结论：

- 数据总数：56/56。
- 可获得状态：56/56 已启用。
- 效果绑定：56/56 运行时 `effect_id` 非空，空表项由 `OrnamentDatabase` 回填为自身 id 并绑定通用效果。
- 直接行为验证：56/56 在 `test/unit/test_ornament_system.gd` 有直接效果测试或入口测试。
- 本轮修正：`apple_wooden_tag` 补齐苹果核变回苹果的替换监听；`empty_dream_trophy` 的奖励加槽判断下沉到 `RunManager` 以便纯逻辑测试；51-56 号道具联动物品补齐 `after_tool_used` 直接测试。

| # | id | 名称 | 分类/稀有度 | 实现入口 | 直接验证 |
|---|---|---|---|---|---|
| 01 | `old_pocket_watch` | 旧怀表 | 通用/普通 | `OldPocketWatchEffect.modify_sanity_loss` | `test_old_pocket_watch_and_safety_pin_modify_sanity_loss_in_order` |
| 02 | `dreamcatcher_filter` | 捕梦滤网 | 通用/普通 | `DreamcatcherFilterEffect.after_item_drawn` | `test_dreamcatcher_filter_scores_every_three_draws` |
| 03 | `echo_earring` | 回音耳坠 | 通用/普通 | `EchoEarringEffect.after_impact_chain_resolved` | `test_echo_earring_scores_once_when_chain_hits_any_item` |
| 04 | `guiding_compass` | 导向罗盘 | 通用/普通 | `GuidingCompassEffect.after_impact_chain_resolved` | `test_guiding_compass_rotates_root_dream_after_empty_chain` |
| 05 | `safety_pin` | 安全别针 | 通用/普通 | `SafetyPinEffect.modify_sanity_loss` | `test_old_pocket_watch_and_safety_pin_modify_sanity_loss_in_order` |
| 06 | `sanity_coin_purse` | 梦值零钱包 | 通用/普通 | `GenericOrnamentEffect.after_item_discarded` | `test_discard_ornaments_apply_once_and_count_discards` |
| 07 | `recycling_coupon` | 回收券 | 通用/普通 | `RunManager.get_current_shop_offer_price` | `test_recycling_coupon_discounts_next_item_after_first_item_purchase` |
| 08 | `sturdy_strap` | 稳固背带 | 通用/进阶 | `GenericOrnamentEffect.modify_sanity_loss` | `test_sturdy_strap_reduces_large_item_draw_cost` |
| 09 | `buckle_guide` | 卡扣指南 | 通用/进阶 | `GenericOrnamentEffect.after_item_placed` | `test_buckle_guide_scores_once_per_draw_for_same_direction_neighbors` |
| 10 | `light_pendant` | 轻盈吊坠 | 通用/进阶 | `GenericOrnamentEffect.after_item_discarded` | `test_discard_ornaments_apply_once_and_count_discards` |
| 11 | `protective_gloves` | 防护手套 | 污染/普通 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_pollution_chain_ornaments_apply_hit_thresholds` |
| 12 | `sealed_bottle` | 密封瓶 | 污染/普通 | `GenericOrnamentEffect.after_pollution_changed` | `test_pollution_ornaments_react_to_pollution_changes` |
| 13 | `active_petri_dish` | 活性培养皿 | 污染/普通 | `GenericOrnamentEffect.after_pollution_changed` | `test_pollution_ornaments_react_to_pollution_changes` |
| 14 | `leaking_valve` | 漏液阀 | 污染/进阶 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_leaking_valve_adds_pollution_from_root_dream_hits` |
| 15 | `stain_sticker` | 污斑贴纸 | 污染/普通 | `GenericOrnamentEffect.after_item_drawn` | `test_stain_sticker_and_black_tide_bottle_add_pollution_on_draws` |
| 16 | `waste_receipt` | 废物收据 | 污染/进阶 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_pollution_chain_ornaments_apply_hit_thresholds` |
| 17 | `corrosion_guide` | 腐蚀指南 | 污染/进阶 | `GenericOrnamentEffect.after_pollution_changed` | `test_pollution_ornaments_react_to_pollution_changes` |
| 18 | `purification_bell` | 净化铃 | 污染/进阶 | `GenericOrnamentEffect.after_pollution_changed` | `test_purification_ornaments_score_and_restore_sanity_with_caps` |
| 19 | `black_raincoat` | 黑色雨衣 | 污染/进阶 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_pollution_chain_ornaments_apply_hit_thresholds` |
| 20 | `pathology_lens` | 病理镜 | 污染/稀有 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_pollution_chain_ornaments_apply_hit_thresholds` |
| 21 | `black_tide_bottle` | 黑潮瓶 | 污染/稀有 | `GenericOrnamentEffect.after_item_drawn` | `test_stain_sticker_and_black_tide_bottle_add_pollution_on_draws` |
| 22 | `black_market_trash_bag` | 黑市垃圾袋 | 污染/稀有 | `GenericOrnamentEffect.after_pollution_changed` | `test_purification_ornaments_score_and_restore_sanity_with_caps` |
| 23 | `gardener_gloves` | 园丁手套 | 梦境之种与丢弃/普通 | `GenericOrnamentEffect.after_seed_sown` | `test_gardener_gloves_scores_first_seed_sown_only` |
| 24 | `moon_dew_bottle` | 月露瓶 | 梦境之种与丢弃/普通 | `GenericOrnamentEffect.after_item_drawn` | `test_moon_dew_bottle_upgrades_first_seed_every_four_draws` |
| 25 | `compost_bag` | 堆肥袋 | 梦境之种与丢弃/进阶 | `GenericOrnamentEffect.after_item_discarded` | `test_compost_bag_upgrades_seed_at_most_twice_per_draw` |
| 26 | `honey_spoon` | 蜂蜜勺 | 梦境之种与丢弃/进阶 | `GenericOrnamentEffect.after_item_discarded` | `test_honey_spoon_only_counts_official_food_items` |
| 27 | `greenhouse_glass` | 温室玻璃 | 梦境之种与丢弃/进阶 | `GenericOrnamentEffect.after_seed_upgraded` | `test_seed_upgrade_ornaments_score_and_restore_sanity` / `test_greenhouse_glass_scores_when_upgrade_crosses_seed_threshold` |
| 28 | `root_bell` | 根须铃 | 梦境之种与丢弃/进阶 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_root_bell_upgrades_adjacent_seed_when_seed_is_hit` |
| 29 | `seed_insurance` | 种子保险 | 梦境之种与丢弃/进阶 | `GenericOrnamentEffect.after_seed_sow_failed` | `test_seed_insurance_scores_when_seed_growth_cannot_fit` |
| 30 | `apple_wooden_tag` | 苹果木牌 | 梦境之种与丢弃/进阶 | `GenericOrnamentEffect.after_item_discarded` / `after_item_replaced` | `test_apple_wooden_tag_sows_from_discard_and_scores_core_transformation` |
| 31 | `harvest_basket` | 收获篮 | 梦境之种与丢弃/稀有 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_harvest_basket_scores_once_when_4x4_seed_resolves` |
| 32 | `rejuvenation_talisman` | 返青符 | 梦境之种与丢弃/稀有 | `GenericOrnamentEffect.after_seed_upgraded` | `test_seed_upgrade_ornaments_score_and_restore_sanity` |
| 33 | `marble_spring` | 弹珠发条 | 机械与撞击/普通 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_basic_mechanical_hit_ornaments_score_from_chain_summary` |
| 34 | `tailing_spark` | 追尾火花 | 机械与撞击/普通 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_basic_mechanical_hit_ornaments_score_from_chain_summary` |
| 35 | `return_ruler` | 归位尺 | 机械与撞击/进阶 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_basic_mechanical_hit_ornaments_score_from_chain_summary` |
| 36 | `chain_counter` | 命中计数器 | 机械与撞击/进阶 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_chain_end_ornaments_score_from_hit_count_thresholds` |
| 37 | `magnetic_pendant` | 磁性挂坠 | 机械与撞击/进阶 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_basic_mechanical_hit_ornaments_score_from_chain_summary` |
| 38 | `gear_oil` | 齿轮油 | 机械与撞击/进阶 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_gear_oil_scores_successful_mechanical_transmissions_only` / `test_gear_oil_ignores_mechanical_hits_without_transmission` |
| 39 | `recoil_plate` | 反冲片 | 机械与撞击/稀有 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_recoil_plate_queues_mechanical_filtered_recoil` |
| 40 | `universal_bearing` | 万向轴承 | 机械与撞击/稀有 | `GenericOrnamentEffect.get_extra_transmission_modes` | `test_universal_bearing_adds_bidirectional_transmission_inside_same_resolution` |
| 41 | `overload_lamp` | 过载灯 | 机械与撞击/稀有 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_overload_lamp_scores_on_consecutive_impact_draws` |
| 42 | `terminal_pressure_gauge` | 终端压力表 | 机械与撞击/稀有 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_terminal_pressure_gauge_counts_mechanical_hits_only` |
| 43 | `kaleidoscope` | 万花镜 | 后期混合/稀有 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_mixed_chain_ornaments_score_tags_negative_value_and_neighbors` |
| 44 | `black_market_stamp` | 黑市图章 | 后期混合/稀有 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_mixed_chain_ornaments_score_tags_negative_value_and_neighbors` |
| 45 | `fusion_badge` | 融合胶章 | 后期混合/稀有 | `GenericOrnamentEffect.after_impact_chain_resolved` | `test_mixed_chain_ornaments_score_tags_negative_value_and_neighbors` |
| 46 | `nightmare_contract` | 梦魇契约 | 后期混合/稀有 | `GenericOrnamentEffect.after_item_drawn` | `test_late_game_score_modifiers_bonus_and_multiplier` |
| 47 | `twilight_hourglass` | 暮梦沙漏 | 后期混合/稀有 | `GenericOrnamentEffect.after_item_drawn` | `test_late_game_score_modifiers_bonus_and_multiplier` |
| 48 | `collection_cabinet` | 收藏柜 | 后期混合/稀有 | `GenericOrnamentEffect.after_battle_started` | `test_collection_cabinet_scores_for_category_diversity_on_battle_start` |
| 49 | `tri_phase_crown` | 三相王冠 | 后期混合/稀有 | `GenericOrnamentEffect.after_battle_started` / `after_pollution_changed` / `after_seed_sown` / `after_impact_chain_resolved` | `test_tri_phase_crown_requires_pollution_seed_and_large_chain_once` |
| 50 | `empty_dream_trophy` | 空梦奖杯 | 后期混合/稀有 | `RunManager.has_empty_dream_trophy_reward_bonus` | `test_empty_dream_trophy_bonus_requires_target_and_score_margin` |
| 51 | `tool_belt` | 工具腰包 | 通用/普通 | `GenericOrnamentEffect.after_tool_used` | `test_tool_linked_score_ornaments_react_to_tool_usage` |
| 52 | `specimen_pin_case` | 标本针盒 | 污染/进阶 | `GenericOrnamentEffect.after_tool_used` | `test_tool_linked_score_ornaments_react_to_tool_usage` |
| 53 | `gardening_toolkit` | 园艺工具包 | 梦境之种与丢弃/进阶 | `GenericOrnamentEffect.after_tool_used` | `test_tool_linked_score_ornaments_react_to_tool_usage` |
| 54 | `recycling_hook` | 回收挂钩 | 梦境之种与丢弃/进阶 | `GenericOrnamentEffect.after_tool_used` / `after_item_discarded` | `test_tool_linked_score_ornaments_react_to_tool_usage` |
| 55 | `calibration_screwdriver` | 校准螺丝刀 | 机械与撞击/进阶 | `GenericOrnamentEffect.after_tool_used` + `ImpactResolver` 传动加分 | `test_calibration_screwdriver_scores_next_successful_mechanical_transmission` |
| 56 | `universal_toolbox` | 万用工具箱 | 后期混合/稀有 | `GenericOrnamentEffect.after_tool_used` | `test_universal_toolbox_rewards_once_after_three_target_types` |
