# Code Review 与重构记录

评审日期：2026-05-28

## 范围

本轮审阅覆盖整个项目，而不只针对 stage/stages 区域：`src/autoload`、`src/battle`、`src/core`、`src/ui`、`data`、`scripts`、`tools`、`test`、发布配置与现有技术文档。工作区开始时已有未提交修改：`battle_manager.gd`、`backpack_ui.gd`、`hub_scene.tscn`、`main_game_ui.gd`，本轮将其视为既有迭代结果继续向前处理，未回退。

## 模块级结论

| 模块 | 结论 | 后续重点 |
| --- | --- | --- |
| Autoload 状态层 | `RunManager` 作为整局状态源的方向正确，但文件过大，保存、路线、随机、事件、商店都集中在同一脚本。 | 逐步抽出 run persistence、route progress、inventory/reward transaction helper。 |
| Battle/Core 玩法层 | `BattleManager`、`BackpackManager`、`ImpactResolver` 分工基本清晰；撞击规则已有测试保护。 | 避免继续向 `BattleManager` 堆 UI/道具分支；随机统一走 `RunManager`。 |
| Item/Tool/Ornament 效果层 | 效果脚本数据驱动程度较好，但仍有少量全局随机和直接运行态修改。 | 新效果优先通过 `GameContext` 获取外部服务，不直接访问全局随机。 |
| Reward/Shop/Event | 生成器结构可测，事件选择事务模型正确但需要防止中途保存。 | 继续强化事务边界和失败回滚测试。 |
| UI 场景层 | 主菜单、Hub、局内、图鉴、设置已按正式美术重构；坐标热区和缩放逻辑较多。 | 用 scene smoke 和真实拖拽验证坐标换算；后续拆出整理背包独立 scene。 |
| Data/Config | JSON/TRES 数据源清晰，配置校验脚本有效。 | 避免运行时代码写回数据库模板资源。 |
| Tools/CI | 发布与配置校验链路已有；Python discover 命令更可靠；Godot 4.6.2 CLI 已实测。 | 保持 GUT、scene smoke、配置校验三条链路同步。 |
| Tests | GUT 覆盖玩法较多，Python 工具测试可跑。 | 新增随机、存档、资源隔离、UI 坐标相关回归。 |

## 验证基线

- `python -B scripts/design_config/validate_design_config.py`：通过，0 warning。
- `python -m unittest discover -s test\tools -p "test_*.py"`：通过，3 个测试。
- `.\tools\run_tests_silent.ps1`：通过，232 个 GUT 测试全部通过；Godot 4.6.2 headless 退出期 `ObjectDB instances leaked at exit` 作为非 fatal warning 输出。
- `python -B scripts\run_scene_smoke_tests.py --fail-on-engine-error`：通过，9 个场景全部加载成功。
- `git diff --check`：通过，仅有既有 CRLF/LF 提示。
- 文档中的旧 Python unittest 命令会解析到 Python 标准库 `test` 包，已修正为 discover 形式。

## 主要发现

### P1 静态资源隔离风险

`RunManager._place_required_backpack_item()` 会直接修改 `ItemDatabase` 返回的 `ItemData`，再放入背包。该路径用于旧存档补 `root_dream`，会污染静态资源模板，后续同类物品实例可能继承错误方向或形状。

处理：已改为先深拷贝运行态数据，再写方向和形状；新增回归测试确认数据库资源不被恢复流程修改。

### P1 事件事务保存边界

`apply_event_choice()` 设计为多效果事务，但内部复用 `apply_reward()` 时会提前 `save_current_state()`。如果后续效果失败，内存会回滚，但磁盘短时间内可能已写入部分成功状态。

处理：`apply_reward()` 和 `add_ornament()` 增加 `save_after` 参数；事件效果内部使用 `save_after=false`，由事件整体成功后统一保存。

### P1 重复 game_over 信号

`GameState.current_sanity` 每次被设置到 0 都会广播 `game_over`。多段结算或后续伤害再次写入 0 时会重复触发战斗结束请求。

处理：改为仅在梦值从正数跨到 0 时广播；新增 `test_game_state.gd` 覆盖重复扣减场景。

### P1 随机源不可复现

架构文档要求随机奖励、商店和事件使用 `RunManager` 可序列化随机源，但战斗洗牌、礼盒替换、彩票效果仍使用全局随机。这会导致同一存档和种子下战斗流程不可复现。

处理：`RunManager` 新增公开随机 helper；`BattleManager` 洗牌改走 `RunManager.shuffle_array_for_run()`；`GameContext` 暴露 `random_float()` / `random_index()`；礼盒和彩票效果改走 `GameContext` 随机。新增 run 随机序列化测试。

### P1 存档删除路径

`SaveManager.delete_save()` 使用 `DirAccess.remove_absolute("user://...")`。该 API 语义上要求全局化路径，直接传 `user://` 在不同平台/导出形态下存在失败风险。

处理：删除前通过 `ProjectSettings.globalize_path(SAVE_PATH)` 转换。

### P2 放置接口健壮性

`BackpackManager.can_place_item()` 默认调用方永远传入有效 `ItemData` 和非空形状。工具、事件、坏数据或测试替身传入空对象时会触发空引用或非法空形状放置。

处理：增加 null/空形状拒绝；新增单测覆盖。

### P2 架构膨胀

`run_manager.gd`、`main_game_ui.gd`、`battle_manager.gd` 已分别约 1000、1000、800 行。职责边界仍可工作，但后续继续堆功能会提高回归风险。

本轮处理：补充 `docs/ai/architecture.md`，明确当前所有权边界和静态资源约束。拆分大型控制器属于较高风险变更，建议在下一次独立重构中按测试保护逐步抽出 route/save、battle tools、battle overlay 等子模块。

### P1 Godot 4.6 类型与节点生命周期

真实 Godot 4.6.2 GUT 暴露了两个静态审查不容易发现的问题：`backpack_ui.gd` 的局部变量依赖类型推断会导致解析失败；`GlobalFeedback` 在 `SceneTree.node_added` 同步阶段直接修改按钮属性，会触发 `!is_inside_tree()` 引擎错误。

处理：为背包 UI 的父节点和 cell size 局部变量补显式类型；`GlobalFeedback._on_node_added()` 改为 deferred 绑定，并在 deferred 入口检查实例有效性，避免测试卸载节点后继续强类型调用。

### P2 UI 坐标与场景验证

现有未提交改动集中在 `get_global_transform()` / `get_global_transform_with_canvas()` 的坐标换算。方向是合理的，已通过 headless scene smoke 确认场景加载、初始化和引擎错误基线；真实拖拽、旋转和道具释放仍建议做一次交互 QA。

处理：保留既有坐标修复，不做回退；使用用户提供的 Godot 4.6.2 console binary 完成全量 GUT 与 scene smoke。

### P2 配置读取性能

`RouteConfig`、`StageConfig`、`EconomyConfig` 当前多处静态方法会重复读 JSON。对当前数据量影响不大，但 UI 布局、奖励、商店和经济快照频繁调用时会制造不必要 IO。

处理：已为三类配置增加按 path 缓存；public loader 仍返回深拷贝，避免调用方污染缓存；新增 `clear_cache_for_tests()` 与防御性拷贝测试，保证自定义 path/fallback 用例隔离。

### P2 UI 模式复用边界

`main_game_ui.tscn` 同时承担战斗与 Hub 整理背包浮层。当前通过 overlay mode 避免了输入上下文和战斗状态污染，但该脚本已接近 1000 行，继续堆功能会增加互相影响概率。

处理：本轮不拆 scene。建议下一阶段将整理背包提成独立 scene 或至少抽出 overlay layout/controller。

### P3 运行日志噪声

玩法核心和 UI 中仍有大量 `print()`。这有利于早期调试，但会放大 headless 输出、影响性能观察，并让测试日志解析更脆弱。

本轮处理：未批量替换，避免行为噪声过大。建议后续引入轻量 debug logger 后按模块迁移。

### P3 Headless ObjectDB 退出警告

在当前 Godot 4.6.2 headless/GUT 组合下，即使单跑既有通过测试或 scene smoke，退出期也会输出 `ObjectDB instances leaked at exit`；verbose 仅显示 refcount 为 0 的 `RefCounted` 实例，未定位到具体项目节点泄漏。原测试脚本将该 warning 当成 fatal，导致断言全通过时仍返回失败。

处理：`run_tests_silent.ps1` 保留 `SCRIPT ERROR`、`Parse Error`、`Resource still in use`、崩溃和 `ERROR:` 为 fatal，将该 ObjectDB 退出警告降级为 `NON_FATAL_WARNINGS` 输出，避免掩盖真实测试结果。

## 本轮重构清单

1. 修复 required backpack item 恢复流程污染静态 `ItemData` 的问题。已完成。
2. 让事件选择中的奖励类效果参与整体事务保存。已完成。
3. 防止 `GameState.game_over` 在梦值已为 0 时重复广播。已完成。
4. 为背包放置入口增加 null 和空形状保护。已完成。
5. 统一战斗洗牌、礼盒、彩票的运行随机源。已完成。
6. 修复 `SaveManager.delete_save()` 的 `user://` 删除路径。已完成。
7. 为以上改动补充 GUT 回归测试。已完成。
8. 修正文档中的 Python 工具测试命令。已完成。
9. 更新 AI 架构摘要，记录当前模块边界。已完成。
10. 修复 Godot 4.6.2 下背包 UI 类型推断失败与全局反馈绑定生命周期错误。已完成。
11. 调整 GUT 静默测试脚本，避免 headless ObjectDB 退出 warning 阻断全绿测试。已完成。
12. 为路线、阶段、经济配置增加只读缓存和缓存隔离测试，减少运行期重复 JSON IO。已完成。

## 剩余风险

- headless 验证已通过；拖拽、旋转、道具释放等坐标相关路径仍建议做一次真实交互 QA。
- 大型控制器拆分应独立排期，当前已记录边界但未进行跨模块搬迁。
- Godot 4.6.2 headless 退出期 ObjectDB warning 仍会出现，当前作为非 fatal warning 记录。
