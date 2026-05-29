# 当前系统技术架构

文档状态：已按当前代码更新。后续需求优先级以 `ImplementationTODO.md` 为准，Agent 执行流程以 `04_Agent_Development_Workflow.md` 为准。

## 一、核心原则

### 1. `RunManager` 是整局运行状态源

`RunManager` 维护跨场景状态，包括：

- 当前路线 ID、场景层 `current_act`、路线节点下标和已完成节点。
- 长期卡组、碎片、饰品、道具、背包布局、暂存物品。
- 背包可用区域、锁格、删格、临时锁格。
- 商店节点缓存、事件节点缓存、已见事件、可序列化随机源。
- 整局是否活跃、是否完成、失败或胜利结算。

局内、商店、事件和奖励都应通过 `RunManager` 写入长期状态，不应各自维护平行运行数据。

### 2. 数据驱动

静态内容由数据资源或 JSON 驱动：

- 物品：`data/items/*.tres`，由 `ItemDatabase` 加载。
- 饰品：`data/ornaments/ornaments.json`，由 `OrnamentDatabase` 加载。
- 道具：`data/tools/tools.json`，由 `ToolDatabase` 加载。
- 事件：`data/events/events.json`，由 `EventDatabase` 加载。
- 路线：`data/routes/routes.json`，由 `RouteConfig` 加载。
- 场景层：`data/stages/stages.json`，由 `StageConfig` 加载。
- 经济曲线：`data/economy/economy.json`，由 `EconomyConfig` 读取并保留代码默认值作为回退。
- 策划配置 schema：`data/config/design_config_schema.json`，由 `scripts/design_config/*` 校验和导出工具使用。
- 捕梦物品投放：`ItemDrawPool` 按 `ItemDrawProbability.md` 的层数、大类别和定位权重生成局内抽取牌堆；当前覆盖已实现的 `ItemData` 物品资源，未落地为 `.tres` 的梦境之种专用启动件不会进入候选池，其类别权重会自动归零并重归一化。

路线、场景层、奖励、商店、事件和经济数值不应散落在 UI 场景脚本中。策划可编辑配置需要先通过 `scripts/design_config/validate_design_config.py` 校验，再进入导出或发布流程。

### 3. 逻辑与表现分离

- `BackpackManager` 负责网格、物品实例、放置、旋转、播种、锁格和运行时状态。
- `ImpactResolver` 负责撞击解析并产出 `GameAction`。
- `SequencePlayer` 负责按动作序列播放表现并同步数值。
- `BattleManager` 负责局内状态机、抽取、撞击队列、道具使用、背包持久化和饰品触发。
- UI 只发出交互请求并渲染状态，不直接改长期运行状态。

### 4. 运行时资源隔离

`ItemData` 是静态资源。进入背包或局内运行态时必须通过 `ItemInstance` 和深拷贝隔离状态，避免同类物品共享污染、方向、形态、runtime id 等可变数据。

物品变身或替换数据时必须保留原 `runtime_id`，并通知 UI 同步表现节点，避免拖拽、悬浮或动画映射丢失。

### 5. 可测试与可复现

- 随机奖励、商店和事件使用 `RunManager` 的可序列化随机源。
- 关键场景由 `scripts/scene_smoke_scenes.json` 维护并 headless 加载。
- 所有新增功能应补 GUT 测试；UI/场景/资源改动必须跑严格场景冒烟。

## 二、主要子系统

### 1. 路线与场景推进

`RouteConfig` 从 `data/routes/routes.json` 读取默认路线：

```text
局内游戏 -> 商店 -> 事件 -> 局内游戏 -> 商店 -> 事件 -> Boss局内游戏
```

当前支持节点类型：

- `battle`
- `boss_battle`
- `shop`
- `event`
- `cutscene`
- `reward`
- `elite_battle`

`HubScene` 由当前路线节点驱动，只允许进入当前节点；`Z` 键可推进到当前节点，事件节点在未实现前只推进路线不进入事件场景。完成战斗、离开商店或跳过事件后推进路线。完成第 6 个场景最后节点后，整局胜利并返回主菜单。

`StageConfig` 会按 `current_act` 选择当前场景层配置。每层可以覆盖 `route_id`，因此同一整局内可以使用不同路线结构；未配置或非法时回退到默认路线。

### 1.1 场景层差异化

`data/stages/stages.json` 是六大关差异化入口，当前支持：

- `route_id`：当前层使用的路线配置。
- `visual`：局内/局外 BGM key 和 UI tint。
- `boss`：Boss 机制与分数目标。
- `battle_modifiers`：抽取消耗修正、污染增加量修正和禁用背包格。
- `reward_weight_modifiers`：关卡奖励候选权重修正。
- `shop_weight_modifiers`：商店候选权重修正。

`RunManager.get_current_battle_config()` 会把当前层的 `stage`、`visual`、`boss` 和 `battle_modifiers` 一并传给战斗。`BattleManager` 负责应用抽取消耗，`ImpactResolver` 负责应用污染修正，奖励和商店生成器负责应用权重修正。

### 2. 战斗生命周期

`BattleManager` 使用状态机：

- `INTERACTIVE`
- `DRAWING`
- `RESOLVING`
- `FINISHING`
- `FINISHED`

玩家手动结束或梦值归零都会走 `request_finish_battle(reason)`。如果当前仍在抽取或结算中，结束请求会延迟到本次结算完成后再发出，避免中途打断本次撞击结算。

普通战斗默认无分数目标；Boss 战从路线节点和当前场景层读取目标分数。Boss 达到目标分数会请求结束当前战斗；梦值归零或手动结束时仍按目标分数统一判定胜负。

局内捕梦不再直接使用 `RunManager.current_deck` 的固定初始三物品列表。进入战斗时，`BattleManager` 通过 `RunManager.build_current_draw_deck()` 请求 `ItemDrawPool` 生成 60 张可复现抽取序列；`current_deck` 仍保留为长期获得物品列表，并参与同名重复抽取修正。

### 3. 背包与物品状态

背包物理大小为 7x7，初始可用区域为 5x5。新 run 默认在背包中放入 `root_dream`，用于每 5 次捕梦触发一次根源撞击。

`RunManager.current_backpack_items` 持久化背包内物品，保存字段包括物品 id、根坐标、方向、形状和 runtime id。战斗结束时背包外物品丢弃，污染清零，衍生物品不跨战斗保存。

事件可以改变背包区域：

- 扩展可用区域。
- 锁格。
- 删格。
- 临时锁格。
- 强制搬迁已有物品。

锁格、删格和临时锁格都会统一输出为 `blocked_cells`，战斗和整理背包读取同一逻辑。

### 4. 撞击调度

所有撞击统一进入 `BattleManager.queue_impact_at(pos, direction, source, reason)`。队列按左上优先级和入队序号排序；每次只处理一次撞击结算，等待 `ImpactResolver` 与 `SequencePlayer` 完整结算后再处理下一次。

同一结算窗口中新产生的撞击会继续进入队列并重新排序，但不会打断当前正在播放的撞击结算。

`ImpactResolver` 会为每个撞击源创建独立的 `ImpactResolutionContext`。上下文记录本次已经命中过的物品、本次命中物品数、本次命中机械物品数和本次转向传动次数。同一次撞击结算中，同一个物品最多被命中一次；如果后续分支再次指向同一物品，该分支停止，不触发 `被撞`，也不增加统计。旧效果脚本仍可通过兼容的 `visited` 字段屏蔽目标，但新代码应优先调用 `block_instance_for_current_resolution()`。

机械传动由 `ImpactResolver` 内部处理：`MECHANICAL_LEFT`、`MECHANICAL_RIGHT`、`MECHANICAL_BIDIRECTIONAL` 和 `MECHANICAL_OMNI` 分支只命中紧贴的机械物品，不穿过空格或非机械物品。结算上下文额外记录双向传动和成功机械传动统计；需要“本次撞击结算全部停止后”触发的物品效果通过 `after_resolution()` 在整次结算末尾统一执行。

### 5. 播种与梦境之种

`BackpackManager.sow_seed()` 是统一播种入口：

- 指定方向第一格为空时生成 `dream_seed_1x1`。
- 目标格已有梦境之种时调用 `upgrade_seed()`。
- 梦境之种通过运行时等级支持 1-30+：1-9 为 1x1，10-19 为 2x2，20-29 为 3x3，30 及以上为 4x4。
- 4x4 后继续升级只提升等级，不再继续变大。
- 变大空间不足时会掉出背包并发出失败事件，掉出后的梦境之种需要重新放入背包才继续参与结算。

相关事件通过 `GlobalEventBus` 广播，供饰品和道具系统监听。

### 6. 饰品系统

饰品不占背包格，不参与撞击，不能重复获得。当前总表已加载并启用 56 个饰品，已接入：

- 战斗开始。
- 捕梦。
- 放置。
- 丢弃。
- 本次撞击结算结束。
- 播种成功/失败。
- 种子升级。
- 污染增加。
- 净化。
- 道具使用。
- 商店折扣。
- 奖励选项增量。

机械饰品 v1.2 已接入机械传动上下文：齿轮油读取成功机械传动次数，万向轴承可在当前结算为第一次命中的机械物品追加双向传动，反冲片通过机械过滤队列发起反方向机械撞击。

简单饰品通过 `GenericOrnamentEffect` 分发，复杂饰品可拆为独立脚本。51-56 号道具联动饰品通过 `after_tool_used`、丢弃监听和撞击上下文接入；`get_available_ornaments()` 仍负责按层数和已拥有状态过滤奖励/商店候选。

### 7. 道具系统

道具是独立于普通背包格的特殊消耗品，不参与背包撞击占格。当前正式道具池为 `data/tools/tools.json` 中 15 个道具。

- `ToolData` 描述 id、名称、价格、标签、目标类型和效果说明。
- `ToolDatabase` 作为 autoload 读取道具表，并提供按 id 查询和全量列表。
- `RunManager.current_tools` 保存长期堆叠数量，`grant_tool()`、`consume_tool()`、`get_tool_inventory_entries()` 作为唯一库存入口，并参与存档、事件回滚、奖励和商店写入。
- `ToolEffect.apply_tool()` 负责目标校验和效果执行；`BattleManager.request_use_tool()` 先执行效果，成功后消耗 1 个，非法目标或效果失败不消耗。
- `MainGameUI` 渲染独立道具栏，支持点击选择、释放到目标、悬停 tooltip、数量显示和使用失败反馈。
- 当前目标类型覆盖背包物品、空格、物品或空格、捕梦区、垃圾桶和饰品槽。

道具获取已接入奖励、商店、事件效果、饰品效果和物品效果入口。具体掉落权重和价格仍是技术假设，后续可在 `RewardGenerator`、`ShopGenerator` 和 `data/tools/tools.json` 中调优。

### 8. 奖励、商店、事件与经济

`RewardGenerator` 生成奖励选项，支持物品、饰品、道具、碎片、权重随机、Boss 稀有倾向、已有构筑标签倾向和候选为空时的安全回退。

`ShopGenerator` 生成商店库存，支持物品、饰品、道具、节点缓存、刷新、已购买排除、已拥有饰品过滤、构筑倾向推荐和价格曲线。

奖励和商店的饰品候选统一来自 `OrnamentDatabase.get_available_ornaments()`，因此会同时过滤已拥有饰品和层数未解锁饰品。

`EventDatabase` 按层数、已见事件、权重、风险收益和随机源选择事件。`RunManager.apply_event_choice()` 以事务方式应用事件效果，失败会回滚。

`EconomyConfig` 集中维护当前基础经济曲线：普通战斗碎片、Boss 碎片、刷新费、物品价格倍率和饰品稀有度倍率。

### 9. 物品获得语义

统一物品获得入口为 `RunManager.grant_item()`，支持三种去向：

- `deck`：加入卡组。
- `backpack`：尝试自动放入长期背包，失败回退暂存。
- `staging`：进入暂存区，玩家在整理背包界面手动摆放。

商店物品默认进入暂存区；奖励物品默认加入卡组；事件效果可在 JSON 中配置去向。

### 9. UI 与全局反馈

核心场景：

- 主菜单：`src/ui/main_menu/main_menu.tscn`
- Hub：`src/ui/hub/hub_scene.tscn`
- 局内：`src/ui/main_game_ui.tscn`
- 商店：`src/ui/shop/shop_scene.tscn`
- 事件：`src/ui/event/event_scene.tscn`
- 背包：`src/ui/backpack/backpack_ui.tscn`
- 调试沙盒：`src/ui/debug/debug_sandbox.tscn`

`GlobalFeedback` 会为场景内和运行时动态生成的 `BaseButton` 自动绑定 hover 缩放、手型光标和点击音效。

Hub 整理背包当前仍复用 `main_game_ui.tscn`，但通过 `configure_for_backpack_overlay()` 进入独立浮层模式：保持 `UI` 输入上下文，隐藏战斗专属面板，提供鼠标关闭按钮，关闭时保存背包布局并恢复 `WORLD`。若后续继续扩展整理背包专属流程，再考虑拆出独立 scene。

### 10. 测试与发布

本地全量测试：

```powershell
.\tools\run_tests_silent.ps1
```

严格场景冒烟：

```powershell
python -B scripts\run_scene_smoke_tests.py --fail-on-engine-error
```

发布预检：

```powershell
.\tools\export_windows_release.ps1 -PrecheckOnly
```

发布脚本会运行 GUT 和严格场景冒烟，并写入 `package/*.manifest.json`。正式导出使用 `export_presets.cfg` 中的 `Windows Desktop` preset。

## 三、目录结构

```text
res://
├── addons/        # GUT 等第三方插件
├── assets/        # 美术、音频、应用图标
├── data/          # 物品、饰品、道具、事件、路线等静态数据
├── scripts/       # 场景冒烟 runner 配置
├── spec/          # 设计文档、技术文档、历史日志
├── src/
│   ├── autoload/  # 全局管理器和数据库
│   ├── battle/    # 局内流程和动作播放
│   ├── core/      # 背包、效果、事件、饰品、道具、奖励、路线等纯逻辑
│   ├── debug/     # 手工调试场景
│   └── ui/        # 场景和 UI 控制脚本
├── test/          # GUT 单元/集成测试
└── tools/         # 本地测试、发布和资源工具
```

## 四、仍未闭环事项

- 正式捕梦动画、美术或 CG：缺少正式素材，替换点是 `MainGameUI._play_dreamcatcher_animation()`。
- 道具获取权重、商店价格和道具联动饰品数值仍需实机数据与策划表继续调优。
