# 06 Item And Tool Audit

日期：2026-05-21

本文记录“普通物品”和“道具”的逐项审计结果。这里的“物品”指 `data/items/*.tres` 中进入背包和撞击结算的 44 个条目；“道具”指 `data/tools/tools.json` 中独立道具栏使用的 15 个条目。代码内 `ornament` 命名的 56 个被动物品另见 `spec/Docs/03_Log/05_Passive_Item_Audit.md`。

结论：
- 普通物品数据：44/44 已加载，见 `test/unit/test_item_effect_audit.gd::test_item_database_loads_full_official_item_pool`。
- 普通物品直接行为验证：44/44 已显式映射到直接行为测试，见 `ITEM_DIRECT_ASSERTIONS` 与 `test_every_item_has_direct_behavior_assertion_in_this_file`。
- 道具数据：15/15 已加载，见 `test/unit/test_tool_effect_audit.gd::test_tool_database_loads_full_official_tool_pool`。
- 道具直接行为验证：15/15 已显式映射到直接行为测试，见 `TOOL_DIRECT_ASSERTIONS` 与 `test_every_tool_has_direct_behavior_assertion_in_this_file`。
- 本轮验证：完整 GUT 已通过，195/195 tests passing。

## 普通物品审计表

| # | id | 名称 | 直接行为断言 | 测试入口 |
|---|---|---|---|---|
| 01 | `alarm_clock` | 破旧闹钟 | 被撞按捕梦次数缩放得分。 | `test_simple_score_items_apply_their_hit_values` |
| 02 | `apple` | 苹果 | 背包内丢弃给分并留下苹果核。 | `test_draw_and_discard_reactive_items_trigger_their_runtime_hooks` |
| 03 | `apple_core` | 苹果核 | 全局捕梦监听达到条件后变回苹果。 | `test_draw_and_discard_reactive_items_trigger_their_runtime_hooks` |
| 04 | `baseball` | 棒球 | 捕梦到同名物品时入队发起撞击。 | `test_draw_and_discard_reactive_items_trigger_their_runtime_hooks` |
| 05 | `brake_pad` | 制动片 | 被撞给分并阻断后续传导。 | `test_mechanical_basic_items_score_stop_and_continue_correctly` |
| 06 | `central_engine` | 中央引擎 | 结算结束后按机械命中和转向传动加分。 | `test_mechanical_after_resolution_items_read_final_summary` |
| 07 | `counting_wheel` | 计数轮 | 结算结束后按本次命中数量阶梯给分。 | `test_mechanical_after_resolution_items_read_final_summary` |
| 08 | `cracked_lens` | 裂痕镜片 | 复制撞击来源的非复制类效果并追加自身得分。 | `test_special_hit_items_transform_or_copy_effects` |
| 09 | `crankshaft` | 曲轴 | 成功曲线/机械传导后给分。 | `test_mechanical_transmission_items_turn_filter_and_branch` |
| 10 | `differential` | 差速器 | 结算结束后按机械命中数与转向次数给分。 | `test_mechanical_after_resolution_items_read_final_summary` |
| 11 | `dream_seed_1x1` | 梦境之种 1x1 | 被撞按运行时等级和阶段倍率给分。 | `test_seed_items_score_by_runtime_level_and_stage` |
| 12 | `dream_seed_2x2` | 梦境之种 2x2 | 被撞按运行时等级和阶段倍率给分。 | `test_seed_items_score_by_runtime_level_and_stage` |
| 13 | `dream_seed_3x3` | 梦境之种 3x3 | 被撞按运行时等级和阶段倍率给分。 | `test_seed_items_score_by_runtime_level_and_stage` |
| 14 | `dream_seed_4x4` | 梦境之种 4x4 | 被撞按运行时等级和阶段倍率给分。 | `test_seed_items_score_by_runtime_level_and_stage` |
| 15 | `dual_axis_wheel` | 双轴转轮 | 达到机械命中门槛后触发双向传动并计入结算上下文。 | `test_mechanical_transmission_items_turn_filter_and_branch` |
| 16 | `energy_flywheel` | 蓄能飞轮 | 结算结束后按机械命中数量给最高两档奖励。 | `test_mechanical_after_resolution_items_read_final_summary` |
| 17 | `expired_medicine` | 过期药物 | 被撞给分并给自身增加 3 层污染。 | `test_pollution_and_cleanup_items_apply_direct_effects` |
| 18 | `gear_rack` | 齿条 | 被撞按机械命中上下文给分，成功继续传导后追加得分。 | `test_mechanical_basic_items_score_stop_and_continue_correctly` |
| 19 | `gift_box` | 礼物盒 | 被撞给分并替换为随机物品。 | `test_special_hit_items_transform_or_copy_effects` |
| 20 | `insurance_contract` | 保险契约 | 梦值归零时恢复梦值并移除自身。 | `test_insurance_contract_recovers_failed_target_run_once` |
| 21 | `iron_ball` | 铁珠 | 捕梦到同名物品时入队发起撞击。 | `test_draw_and_discard_reactive_items_trigger_their_runtime_hooks` |
| 22 | `joker` | Joker | 被撞固定给分。 | `test_simple_score_items_apply_their_hit_values` |
| 23 | `leaky_pen` | 漏水钢笔 | 被撞给分，并给所指方向第一个废弃物加污染。 | `test_pollution_and_cleanup_items_apply_direct_effects` |
| 24 | `left_transmission_elbow` | 左传动弯管 | 按当前朝向计算相对左传动并命中机械目标。 | `test_mechanical_transmission_items_turn_filter_and_branch` |
| 25 | `leftover_box` | 剩饭盒 | 被撞后给相邻废弃物加污染。 | `test_pollution_and_cleanup_items_apply_direct_effects` |
| 26 | `mineral_water_bottle` | 矿泉水瓶 | 被撞固定给分。 | `test_simple_score_items_apply_their_hit_values` |
| 27 | `old_soccer_ball` | 旧足球 | 捕梦监听后入队发起撞击。 | `test_draw_and_discard_reactive_items_trigger_their_runtime_hooks` |
| 28 | `paper_ball` | 纸团 | 被撞给分并给自身增加污染。 | `test_pollution_and_cleanup_items_apply_direct_effects` |
| 29 | `pill_bottle` | 小药瓶 | 被撞后给全场污染最高的物品追加污染。 | `test_pollution_and_cleanup_items_apply_direct_effects` |
| 30 | `right_transmission_elbow` | 右传动弯管 | 按当前朝向计算相对右传动并命中机械目标。 | `test_mechanical_transmission_items_turn_filter_and_branch` |
| 31 | `roast_chicken` | 美味烧鸡 | 被撞固定给分。 | `test_simple_score_items_apply_their_hit_values` |
| 32 | `root_dream` | 根源之梦 | 每 5 次捕梦通过全局监听入队发起撞击。 | `test_draw_and_discard_reactive_items_trigger_their_runtime_hooks` |
| 33 | `rusty_gear` | 生锈齿轮 | 被撞污染自身，并向周围物品扩散污染。 | `test_pollution_and_cleanup_items_apply_direct_effects` |
| 34 | `sad_teddy_bear` | 伤心泰迪熊 | 被撞给分；没有继续命中时自身加污染。 | `test_special_hit_items_transform_or_copy_effects` |
| 35 | `small_gear` | 小齿轮 | 被撞按机械命中上下文给分。 | `test_mechanical_basic_items_score_stop_and_continue_correctly` |
| 36 | `star_ring_bearing` | 星环轴承 | 首次触发全向机械传动并避免嵌套重复触发。 | `test_mechanical_transmission_items_turn_filter_and_branch` |
| 37 | `sticky_note` | 便利贴 | 污染跨过每 3 层门槛时给分。 | `test_sticky_note_scores_on_each_three_pollution_threshold` |
| 38 | `syringe` | 针管 | 被撞后给所指方向整行废弃物加污染。 | `test_pollution_and_cleanup_items_apply_direct_effects` |
| 39 | `terminal_computer` | 终端计算机 | 结算结束后按机械命中数封顶给分，并按双向传动追加奖励。 | `test_mechanical_after_resolution_items_read_final_summary` |
| 40 | `tin_can` | 易拉罐 | 被撞固定给分。 | `test_simple_score_items_apply_their_hit_values` |
| 41 | `transmission_belt` | 传动皮带 | 被撞给分，成功继续传导后追加得分。 | `test_mechanical_basic_items_score_stop_and_continue_correctly` |
| 42 | `trash_bag` | 垃圾袋 | 被撞净化相邻物品污染并按净化层数恢复梦值。 | `test_pollution_and_cleanup_items_apply_direct_effects` |
| 43 | `trash_recycler` | 垃圾回收器 | 被撞净化全场污染并按净化层数给分。 | `test_pollution_and_cleanup_items_apply_direct_effects` |
| 44 | `wet_cardboard_box` | 潮湿纸箱 | 被撞给分，并污染所指方向最近物品。 | `test_pollution_and_cleanup_items_apply_direct_effects` |

## 道具审计表

| # | id | 名称 | 直接行为断言 | 测试入口 |
|---|---|---|---|---|
| 01 | `small_patch` | 小补丁 | 目标物品本局价值降低 3。 | `test_common_tools_apply_patch_discount_rotation_and_queued_impact` |
| 02 | `dream_value_candy` | 梦值糖 | 下一次捕梦消耗折扣增加。 | `test_common_tools_apply_patch_discount_rotation_and_queued_impact` |
| 03 | `turning_screw` | 转向螺丝 | 旋转目标物品，仍在背包内时给分。 | `test_common_tools_apply_patch_discount_rotation_and_queued_impact` |
| 04 | `cracked_marble` | 破弹珠 | 从目标物品发起一次撞击并进入撞击队列。 | `test_common_tools_apply_patch_discount_rotation_and_queued_impact` |
| 05 | `black_ink_drop` | 黑墨滴 | 目标加污染，废弃物目标额外加污染。 | `test_pollution_tools_apply_pollution_cleanse_and_value_loss` |
| 06 | `disinfectant_spray` | 消毒喷雾 | 净化目标污染并按净化层数给分。 | `test_pollution_tools_apply_pollution_cleanse_and_value_loss` |
| 07 | `corrosive_acid` | 腐蚀酸 | 目标加污染并降低本局价值。 | `test_pollution_tools_apply_pollution_cleanse_and_value_loss` |
| 08 | `small_water_drop` | 小水滴 | 空格播种梦境之种。 | `test_seed_tools_sow_upgrade_and_score_growth` |
| 09 | `fertilizer_bag` | 肥料包 | 升级目标梦境之种。 | `test_seed_tools_sow_upgrade_and_score_growth` |
| 10 | `fast_sprout_agent` | 快速发芽剂 | 大幅升级梦境之种，跨体型时给分。 | `test_seed_tools_sow_upgrade_and_score_growth` |
| 11 | `extension_hook` | 延长钩 | 目标无继续传导时额外检查下一格。 | `test_mechanical_tools_extend_and_bonus_successful_transmission` |
| 12 | `transmission_oil` | 传动油 | 机械物品成功传导时追加最多 3 次加分。 | `test_mechanical_tools_extend_and_bonus_successful_transmission` |
| 13 | `apple_wax` | 苹果蜡 | 食物丢弃时额外恢复梦值；苹果额外播种。 | `test_discard_tools_apply_food_wax_and_recycling_clip` |
| 14 | `recycling_clip` | 回收夹 | 下一次丢弃废弃物时给分并获得纸团。 | `test_discard_tools_apply_food_wax_and_recycling_clip` |
| 15 | `blank_talisman` | 空白符纸 | 刷新目标被动物品的每关限次状态，且每物品每关最多刷新一次。 | `test_blank_talisman_refreshes_once_per_ornament` |

## 验证记录

- `.\tools\run_tests_silent.ps1`
- `python -B scripts\run_scene_smoke_tests.py --fail-on-engine-error`
- `python -B scripts\design_config\validate_design_config.py`
- `python -m unittest discover -s test\tools -p "test_*.py"`
