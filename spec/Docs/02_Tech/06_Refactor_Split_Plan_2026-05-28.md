# 大模块重构拆分分析与准备

日期：2026-05-28

状态：准备文档。本文不要求立即搬迁代码，目的是为后续拆分提供边界、顺序、接口约束和验收标准。

## 目标

本轮 review 后项目已经能够通过 GUT、scene smoke 和配置校验。后续重构的目标不是修复当前不可运行问题，而是降低继续迭代时的耦合风险，尤其是：

- 避免 `RunManager` 继续吸收路线、存档、奖励、事件、商店、背包和随机逻辑。
- 避免 `main_game_ui.gd` 同时承载战斗 UI、整理背包 overlay、奖励弹窗、道具栏和布局换算。
- 避免 `BattleManager` 同时处理战斗状态、抽牌、放置、旋转、丢弃、道具、饰品事件和结算请求。
- 保持现有存档 schema、autoload 名称、scene 路径和 GUT/scene smoke 验收流程稳定。

## 当前证据

### 文件规模

| 文件 | 行数 | 函数数 | 当前风险 |
| --- | ---: | ---: | --- |
| `src/autoload/run_manager.gd` | 1043 | 103 | 保存、路线、奖励、商店、事件、背包持久化和 RNG 全部混在同一 autoload。 |
| `src/ui/main_game_ui.gd` | 996 | 80 | 战斗 UI 与 Hub 整理背包 overlay 复用同一 scene/controller。 |
| `src/battle/battle_manager.gd` | 803 | 68 | 战斗生命周期、物品交互、道具、饰品和结算请求边界偏宽。 |
| `src/ui/hub/hub_scene.gd` | 492 | 55 | Hub 布局、路线进入、商人状态、背包 overlay 打开逻辑集中。 |
| `src/ui/backpack/backpack_ui.gd` | 213 | 16 | 体量可控，但坐标换算是 UI 重构的敏感接口。 |

### 必须保持的外部契约

这些契约已经被 scene、UI 或测试直接使用，拆分时应先保留 facade，不直接改调用点：

- `RunManager`
  - `serialize_run()` / `deserialize_run(data)`
  - `save_backpack_state(backpack)` / `restore_backpack_state(backpack, item_db)`
  - `generate_current_shop_offers()` / `refresh_current_shop_offers()` / `buy_shop_offer()`
  - `pick_current_event()` / `apply_event_choice(choice)`
  - `advance_route_node(expected_node_id := "")`
  - `grant_item()` / `apply_reward()` / `grant_tool()` / `consume_tool()`
  - `random_float_for_run()` / `random_int_for_run()` / `shuffle_array_for_run()`
  - signals: `run_started`、`run_finished`、`shards_changed`、`deck_changed`、`route_changed`、`ornaments_changed`、`pending_items_changed`、`tools_changed`
- `BattleManager`
  - `request_draw()`
  - `request_place_item(item_ui, grid_pos)`
  - `request_use_tool(tool_id, target)`
  - `request_finish_battle(reason := "manual")`
  - `mark_battle_finished()`
  - signals: `item_drawn`、`battle_finish_requested`
- `MainGameUI`
  - `configure_for_backpack_overlay(close_callback := Callable())`
  - `close_requested`
  - scene path: `res://src/ui/main_game_ui.tscn`
- `BackpackUI`
  - `setup(context)`
  - `configure_item_for_grid(item_ui, target_parent := null)`
  - `get_grid_pos_at(global_pos)`
  - `add_item_visual(item_ui, grid_pos)`
  - `highlight_placement(root_pos, item_data)`

### 存档 schema 锁定

拆分期间 `RunManager.serialize_run()` 的键必须保持兼容，除非单独引入迁移版本：

`shards`、`deck`、`backpack_items`、`pending_item_rewards`、`next_pending_item_uid`、`tools`、`backpack_locked_cells`、`backpack_deleted_cells`、`temporary_backpack_locked_cells`、`ornaments`、`backpack_usable_width`、`backpack_usable_height`、`shop_purchase_state`、`event_node_state`、`seen_event_ids`、`rng_seed`、`rng_state`、`depth`、`route_id`、`act`、`route_index`、`completed_route_nodes`、`is_active`、`is_complete`。

## 拆分原则

1. 先加契约测试，再搬实现。
2. 先抽纯逻辑和无 scene 依赖的服务，再抽 UI controller。
3. 公开 API 先留在原类上做 facade，内部委托到新模块。
4. 不在同一次提交里同时改 scene 结构和玩法逻辑。
5. 不在没有迁移测试的情况下修改存档 schema。
6. 不把新 helper 做成 autoload，除非有明确跨 scene 生命周期需求。
7. 每个阶段都必须跑完整 GUT、strict scene smoke、配置校验和 `git diff --check`。

## 目标结构

### Run 子系统

建议新建目录：`src/core/run/`。

#### `run_rng_service.gd`

职责：

- 持有 `RandomNumberGenerator`。
- 提供 `set_seed(seed)`、`restore(seed, state)`、`randf()`、`randi_index(max_exclusive)`、`shuffle(values)`。
- 提供 `serialize()` 返回 `rng_seed` / `rng_state`。

迁移方式：

- `RunManager.random_*_for_run()` 继续保留，内部委托给 `RunRngService`。
- 第一阶段不改调用方。

收益：

- 把可复现随机从 `RunManager` 状态堆中移出。
- 以后奖励、商店、事件和战斗洗牌都能共享明确接口。

#### `run_persistence_codec.gd`

职责：

- 只负责 `serialize(manager)` 和 `deserialize_into(manager, data)`。
- 维护 schema 默认值、类型转换、旧存档兼容。
- 不直接保存磁盘，不调用 `SaveManager`。

迁移方式：

- `RunManager.serialize_run()` / `deserialize_run()` 继续存在，内部委托。
- 添加 `test_run_persistence_contract.gd`，固定 schema key 列表和 roundtrip 行为。

收益：

- 后续拆 `RunManager` 时不会把存档兼容逻辑打散到多个 helper。

#### `run_route_progress.gd`

职责：

- 当前 act、route id、route index、completed nodes。
- `get_current_stage_route_id()`、`get_route_nodes()`、`get_current_route_node()`、`can_enter_route_node()`。
- `advance_route_node(expected_node_id)`。
- `get_current_battle_config()`、目标分数判断。

迁移方式：

- 保留 `RunManager` 原方法，内部转发到 route progress。
- `route_changed` 信号仍由 `RunManager` 发出，避免 Hub 和 scene 调用点变化。

收益：

- 路线推进和存档/奖励/事件解耦。
- Hub、Shop、Event、Battle 不需要理解 `RunManager` 内部字段。

#### `run_inventory_state.gd`

职责：

- deck、shards、ornaments、tools、pending item rewards。
- backpack persistence：`save_backpack_state()` / `restore_backpack_state()`。
- item acquisition：`grant_item()`、`consume_pending_item()`、`place_pending_item_in_backpack()`。

迁移方式：

- 第一阶段只抽序列化和纯数据转换函数。
- 第二阶段再把 `grant_item()` 和 backpack persistence 转移。
- `RunManager` 继续负责发 signals 和调用 `save_current_state()`。

收益：

- 长期构筑状态和路线/事件逻辑分离。
- 背包持久化测试可以更聚焦。

#### `run_shop_state.gd`

职责：

- 节点商店缓存 key。
- 生成、刷新、购买状态记录。
- 计算当前刷新费用和 offer price。

迁移方式：

- 先抽 `_get_current_shop_state_key()`、`_record_shop_purchase()`、`_generate_and_cache_current_shop_offers()` 这类函数。
- `RunManager.generate_current_shop_offers()` 等公开方法保留。

收益：

- 商店缓存不再和事件节点缓存、路线推进混在一起。

#### `run_event_transaction.gd`

职责：

- `apply_event_choice()` 的事务边界。
- 事件效果应用、snapshot/rollback。
- 背包 cell 变化效果和 temporary locks 的 tick。

迁移方式：

- 先把 snapshot/rollback 与 effect dispatch 抽出。
- 仍由 `RunManager` 提供当前状态引用和最终保存。

收益：

- 事件失败回滚的风险集中可测。
- 以后新增高风险事件效果时不用继续扩大 `RunManager`。

### MainGameUI / UI 子系统

建议采用两步走，先 controller，后 scene：

1. 从 `main_game_ui.gd` 抽出无 scene 改造的 controller。
2. 等 controller 稳定后，再决定是否拆独立 scene。

#### `backpack_overlay_controller.gd`

职责：

- `configure_for_backpack_overlay()` 之后的 overlay 布局、关闭按钮、说明信息、统计信息刷新。
- 管理 overlay art rect 到 viewport 的换算。
- 不处理战斗抽牌、奖励弹窗和道具栏。

迁移接口：

- `setup(root: Control, backpack_ui: BackpackUI, battle_manager: BattleManager, close_callback: Callable)`
- `apply_layout(viewport_size: Vector2)`
- `refresh_info()`
- `request_close()`

验收重点：

- `test_hub_player.gd` 中 overlay 相关测试仍通过。
- Hub 打开/关闭背包 overlay 不改变 battle input context。
- `main_game_ui.tscn` 不因 overlay controller 缺失节点而报错。

#### `battle_layout_controller.gd`

职责：

- 固定 1920x1080 battle frame 布局。
- dreamcatcher net pose/pivot。
- stage visual 和 potion state 贴图布局。

迁移收益：

- 后续视觉资产替换不会继续膨胀 `MainGameUI`。

#### `reward_popup_controller.gd`

职责：

- 胜利弹窗。
- reward options 获取和按钮渲染。
- reward 应用后的路线推进。

注意：

- 该 controller 会接触 `RunManager` 和 `GlobalScene`，抽出时要保留完整战斗结算测试。

#### `tool_panel_controller.gd`

职责：

- 道具栏渲染。
- 道具按钮输入、拖拽、选择态。
- 将 UI 坐标转换为 `BattleManager.request_use_tool()` 的 target。

注意：

- 这个模块同时依赖 `ToolDatabase`、`RunManager`、`BattleManager`、`BackpackUI` 和 item UI，风险中等。
- 应放在 overlay 拆分之后，避免两个 UI 坐标系统同时变动。

### Battle 子系统

建议先抽状态清晰、测试已覆盖的部分。

#### `battle_deck_runtime.gd`

职责：

- `_current_battle_deck`。
- 从 `RunManager.current_deck` 构建战斗 deck。
- 使用 `RunManager.shuffle_array_for_run()` 洗牌。
- `draw_next()` 返回 `ItemData` 或 item id。

迁移方式：

- `BattleManager._refill_battle_deck_from_run()` 和 `request_draw()` 初期仍保留，内部转发。
- 不在同一阶段改 UI 抽牌动画。

#### `battle_finish_flow.gd`

职责：

- `request_finish_battle()`、`mark_battle_finished()`、`_settle_interactive_state()` 的状态转换。
- 管理 pending finish reason。

迁移收益：

- 梦值归零、手动结束、结算中延迟结束的行为更容易固定。
- 已有 `test_battle_lifecycle.gd` 可直接保护。

#### `battle_tool_controller.gd`

职责：

- `request_use_tool()`。
- tool target 校验。
- 成功消耗和饰品 `after_tool_used`。

迁移注意：

- 依赖 `RunManager.consume_tool()`、`ToolDatabase`、`backpack_manager`、ornament runtime。
- 应在 `RunManager` inventory/tool state 稳定后再抽。

#### `battle_item_interaction_controller.gd`

职责：

- 物品旋转、放置、移出背包、丢弃。
- `BackpackUI` mapping 同步。
- outside item parent 和 cell size 适配。

迁移注意：

- 这是 Battle 拆分里风险最高的一块，因为它直接持有 `Control`、`BackpackUI`、`ItemData` 和 `BackpackManager.ItemInstance`。
- 必须先补交互契约测试，或在真实窗口里做拖拽、旋转、丢弃 QA。

#### `battle_ornament_runtime.gd`

职责：

- 当前饰品效果列表和 per-ornament runtime state。
- `GlobalEventBus` 连接和断开。
- item drawn / placed / discarded / impact resolved / seed events / tool used 的统一分发。

迁移注意：

- 饰品效果多，覆盖面广。建议放在 `battle_tool_controller` 后面，避免一次改变两个事件链。

### Hub 子系统

Hub 暂不列为第一批重构对象。后续可以抽：

- `hub_layout_mapper.gd`：source rect/source x 到 viewport 的换算。
- `hub_stage_visual_controller.gd`：背景、前景、商人动画。
- `hub_route_entry_controller.gd`：进入当前路线节点、路线按钮、商店可用状态。

Hub 的优先级低于 `main_game_ui.gd`，因为它现在的场景职责更单一，且风险主要是布局和入口协调。

## 推荐执行顺序

### Phase 0：契约冻结

目标：在搬代码前补齐会被拆分影响的边界测试。

建议新增：

- `test/unit/test_run_persistence_contract.gd`
  - 固定 `serialize_run()` key 列表。
  - 验证旧字段缺失时能按默认值恢复。
  - 验证 `rng_seed/rng_state` roundtrip。
- `test/unit/test_run_facade_contract.gd`
  - 覆盖 `RunManager` facade 方法仍存在。
  - 检查关键 signals 仍由 `RunManager` 发出。
- `test/unit/test_battle_public_api_contract.gd`
  - 固定 `request_draw()`、`request_finish_battle()`、`request_use_tool()`、`request_place_item()` 的基本返回和状态副作用。
- 扩展 `test_hub_player.gd`
  - 明确 overlay 打开关闭时 `InputManager` 上下文、`close_requested` 和 Hub callback 行为。

验收：

- 全量 GUT 通过。
- strict scene smoke 通过。

### Phase 1：抽 Run RNG 与 Persistence Codec

风险：低。

原因：

- RNG helper 已经统一入口。
- Persistence codec 可以先只移动序列化/反序列化代码，不改变状态字段所有权。

步骤：

1. 新增 `src/core/run/run_rng_service.gd`。
2. `RunManager` 内部持有 `_rng_service`，原 random public methods 委托过去。
3. 新增 `src/core/run/run_persistence_codec.gd`。
4. `RunManager.serialize_run()` / `deserialize_run()` 委托 codec。
5. 保持 `RunManager` 字段名不变。

验收重点：

- `test_run_route.gd` 中随机序列化测试仍通过。
- `test_event_system.gd` 和 `test_shop_system.gd` 的存档恢复仍通过。

### Phase 2：抽 Route Progress

风险：中低。

步骤：

1. 新增 `src/core/run/run_route_progress.gd`。
2. route progress 先持有纯字段副本或接收 `RunManager` 引用，推荐先接收 `RunManager` 引用以降低一次性迁移量。
3. `RunManager` facade 保留当前路线 API。
4. route 相关 signals 仍由 `RunManager` 发出。

验收重点：

- `test_run_route.gd` 全部通过。
- `test_stage_config.gd` 当前战斗配置测试通过。
- `test_scene_smoke.gd` Hub、Shop、Event 场景通过。

### Phase 3：抽 Inventory / Shop / Event

风险：中到高，建议拆成三次提交。

建议顺序：

1. `run_inventory_state.gd`
   - 先抽 backpack serialize/restore helper。
   - 再抽 pending item 和 tool inventory。
2. `run_shop_state.gd`
   - 抽 shop cache、refresh、purchase。
3. `run_event_transaction.gd`
   - 抽 event choice snapshot、effect dispatch、rollback。

验收重点：

- `test_backpack_persistence.gd`
- `test_item_acquisition_semantics.gd`
- `test_tool_system.gd`
- `test_shop_system.gd`
- `test_event_system.gd`

### Phase 4：抽 Backpack Overlay Controller

风险：中。

原因：

- overlay 已经有独立 mode，但仍复用 `main_game_ui.tscn`。
- 这一步不改 scene path，只把 overlay 相关代码转到 controller。

步骤：

1. 新增 `src/ui/backpack/backpack_overlay_controller.gd` 或 `src/ui/main_game/backpack_overlay_controller.gd`。
2. 从 `main_game_ui.gd` 移动：
   - `_apply_backpack_overlay_mode()`
   - `_position_backpack_overlay_panel()`
   - `_layout_backpack_overlay_art()`
   - `_ensure_backpack_overlay_close_button()`
   - `_ensure_backpack_overlay_info()`
   - `_refresh_backpack_overlay_info()`
   - `_overlay_art_rect_to_viewport()`
   - `_layout_overlay_control()`
   - `_request_overlay_close()`
3. `MainGameUI.configure_for_backpack_overlay()` 仍作为 facade。

验收重点：

- `test_hub_player.gd` overlay 相关用例。
- strict scene smoke。
- 手动 QA：Hub 打开背包、关闭背包、窗口缩放后布局正确。

### Phase 5：抽 Tool Panel 与 Reward Popup

风险：中。

建议顺序：

1. `tool_panel_controller.gd`
2. `reward_popup_controller.gd`
3. `battle_layout_controller.gd`

原因：

- 道具栏和奖励弹窗是相对独立 UI 区块。
- battle layout 涉及视觉资产，适合最后抽，避免布局和逻辑同时变化。

验收重点：

- `test_tool_system.gd`
- `test_tool_effect_audit.gd`
- `test_reward_system.gd`
- battle scene smoke。

### Phase 6：抽 Battle Deck 与 Finish Flow

风险：中。

步骤：

1. 新增 `battle_deck_runtime.gd`。
2. 新增 `battle_finish_flow.gd`。
3. `BattleManager` 保持 public API，内部委托。

验收重点：

- `test_battle_lifecycle.gd`
- `test_discard_logic.gd`
- `test_stage_config.gd` 中 `request_draw()` 相关用例。
- `test_item_effect_audit.gd` 中抽牌/结算依赖用例。

### Phase 7：抽 Battle Tool / Item Interaction / Ornament Runtime

风险：高，必须小步做。

建议顺序：

1. `battle_tool_controller.gd`
2. `battle_ornament_runtime.gd`
3. `battle_item_interaction_controller.gd`

理由：

- tool controller 有较多测试保护。
- ornament runtime 依赖 tool、item、impact 多个事件链，放中间。
- item interaction controller 牵涉 UI Control 坐标和 BackpackUI mapping，最后做。

验收重点：

- `test_tool_effect_audit.gd`
- `test_ornament_system.gd`
- `test_rotation_logic.gd`
- `test_card_tooltip.gd`
- 真实交互 QA：拖拽、旋转、移出背包、丢弃、道具释放。

### Phase 8：清理 facade 和日志

风险：低到中。

条件：

- 至少两个版本周期内没有外部调用旧 private helper。
- GUT 和 scene smoke 持续稳定。

内容：

- 删除已经不再被调用的 private helper。
- 将高频 `print()` 迁移到轻量 debug logger。
- 更新 `docs/ai/architecture.md` 和 `ImplementationTODO.md`。

## 每阶段通用验收命令

使用用户当前提供的 Godot 4.6.2 console binary：

```powershell
$env:GODOT_BIN='D:\Workspaces\Library\Software\Installers\DevTools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
.\tools\run_tests_silent.ps1
python -B scripts\run_scene_smoke_tests.py --fail-on-engine-error
python -B scripts\design_config\validate_design_config.py
python -m unittest discover -s test\tools -p "test_*.py"
git diff --check
```

说明：当前 Godot 4.6.2 headless 退出期会输出 `ObjectDB instances leaked at exit`，`run_tests_silent.ps1` 已将其作为非 fatal warning。若出现 `SCRIPT ERROR`、`Parse Error`、`ERROR:`、资源仍被使用或崩溃，仍视为失败。

## 分支与提交建议

建议每个阶段单独提交，不要合并多个阶段：

1. `refactor/contracts`
2. `refactor/run-rng-persistence`
3. `refactor/run-route-progress`
4. `refactor/run-inventory-shop-event`
5. `refactor/backpack-overlay-controller`
6. `refactor/main-game-ui-panels`
7. `refactor/battle-deck-finish`
8. `refactor/battle-tools-ornaments-placement`
9. `refactor/cleanup-logging`

每个提交说明必须包含：

- 移动了哪些职责。
- 原 public API 是否保持。
- 新增或更新了哪些测试。
- 验证命令结果。

## Stop 条件

任一阶段出现以下情况，应停止继续拆分并先修复：

- 存档 roundtrip 结果发生非预期变化。
- `RunManager` public API 调用点需要大面积同步修改。
- scene smoke 通过但真实交互 QA 发现拖拽/旋转/道具释放错位。
- `BattleManager.request_finish_battle()` 状态机语义变得不明确。
- 出现只能靠 `await process_frame` 堆叠才能通过的 UI 生命周期问题。

## 下一步建议

下一次真正动代码时，从 Phase 0 开始。先补契约测试，然后抽 `RunRngService` 和 `RunPersistenceCodec`。这两个阶段不需要改 scene，风险最低，能为后续拆 `RunManager` 建立稳定基础。

## 架构补充与改进建议 (Godot / GDScript 特有)

在实际执行本重构计划时，结合 GDScript 和 Godot 引擎的特性，建议补充以下几点细节以避免常见陷阱：

### 1. 内部组件通信与循环依赖 (Inter-component Communication)
在 Phase 2 和 Phase 3 中，`RunRouteProgress`、`RunInventoryState` 等组件被拆分出来。
- **风险**：如果“获得物品”触发了“路线进度”的变化，互相持有对方的引用或直接调用 `RunManager`，极易产生循环引用（Cyclic Reference）导致解析失败。
- **最佳实践**：让这些子组件**只负责发射 Signal**（例如 `run_inventory_state` 发射 `item_granted`），然后由作为“中介者 (Mediator)”的 `RunManager` 监听这些内部 Signal，再去调用其他组件或对外发射全局 Signal。确保子组件是真正解耦的单向依赖。

### 2. 事件事务与数据回滚的深拷贝陷阱 (Deep Copy Pitfall)
在 Phase 3 拆分 `run_event_transaction.gd` 时，计划提到要实现 `snapshot / rollback`（快照与回滚）。
- **风险**：在 GDScript 中，使用 `Dictionary.duplicate(true)` 或 `Array.duplicate(true)` 时，**不会深拷贝内部的自定义 Resource 对象或 Node 引用**（按引用传递）。
- **最佳实践**：明确定义 snapshot 的数据结构只能是基础类型。涉及对象状态时，应利用 Phase 1 抽离出的 `run_persistence_codec.gd`，把当前状态序列化成 JSON Dictionary 作为快照，回滚时再反序列化，确保获得绝对干净、无引用污染的状态。

### 3. UI Controller 的依赖注入方式 (Dependency Injection)
在 Phase 4 和 Phase 5 拆分 UI Controller（如 `backpack_overlay_controller.gd`）时。
- **风险**：Controller 内部使用 `$NodePath` 或 `%UniqueName` 直接查找节点会导致与特定的 Scene 强绑定，不利于未来的独立 Scene 拆分。
- **最佳实践**：在 Controller 的 `setup()` 或 `init()` 方法中，将所需的 UI 控件作为强类型参数传入（依赖注入）。
  ```gdscript
  func setup(root_panel: Panel, close_btn: Button, item_grid: Control):
      self._close_btn = close_btn
      self._close_btn.pressed.connect(_on_close_pressed)
  ```
  这样未来拆分独立 scene 时，Controller 代码几乎无需改动。

### 4. 类型安全与 `class_name` 使用
- **最佳实践**：拆分出的独立脚本，如果不需挂载到 Node 上（不在编辑器展示），可声明为继承自 `RefCounted`，生命周期由持有者管理，减轻场景树负担。
- **最佳实践**：对于核心服务类，明确加上 `class_name`，以便在项目中使用强类型约束，提升团队协作和代码维护性。
