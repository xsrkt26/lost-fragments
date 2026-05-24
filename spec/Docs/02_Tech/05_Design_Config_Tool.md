# 策划配置工具

本文记录策划配置工具的开发边界、第一版 schema 和使用流程。目标是让策划后续可以安全调整难度、投放、价格、事件和路线配置，而不是直接修改游戏脚本。

## 一、当前阶段

当前完成第一阶段：配置 schema、校验脚本、导出脚本和经济曲线 JSON 化。

暂不开发可视化 UI。原因是先保证配置数据结构、校验规则和导出流程稳定，后续 Web 工具或 Godot 内置编辑界面都可以复用这套底层。

## 二、配置来源

第一版工具覆盖当前真实运行入口：

| 类型 | 配置源 | 当前用途 |
| --- | --- | --- |
| 物品 | `data/items/*.tres` | 生成只读物品目录，校验 id、名称、标签、形状、方向和传动模式 |
| 道具 | `data/tools/tools.json` | 调整道具价格、稀有度、目标类型、标签和描述 |
| 饰品 | `data/ornaments/ornaments.json` | 调整饰品价格、最早出现层、稀有度、标签、启用状态和描述 |
| 事件 | `data/events/events.json` | 调整事件权重、风险收益、选项、成本和效果 |
| 路线 | `data/routes/routes.json` | 调整节点顺序、节点类型、场景映射和 Boss 分数目标 |
| 场景层 | `data/stages/stages.json` | 调整六大关路线、视觉、Boss 目标、战斗修正、奖励权重和商店权重 |
| 经济 | `data/economy/economy.json` | 调整碎片产出、商店刷新费用和价格倍率 |
| Schema | `data/config/design_config_schema.json` | 记录策划可编辑字段、数据源和枚举值 |

`src/core/rewards/economy_config.gd` 现在优先读取 `data/economy/economy.json`，读取失败时回退到代码内默认值，避免配置文件损坏直接阻塞启动。

## 三、校验命令

```powershell
python -B scripts\design_config\validate_design_config.py
```

校验范围：

- JSON 格式是否有效。
- 数据源路径是否存在。
- 物品、道具、饰品、事件、路线和场景层 id 是否重复。
- 道具目标类型、道具稀有度、饰品稀有度、事件效果类型、路线节点类型是否在 schema 枚举内。
- 事件效果引用的物品、饰品和道具 id 是否存在。
- 价格、权重、层数、风险收益、经济曲线等数值是否落在基础合法范围内。
- 路线默认 id、节点 scene、Boss 分数目标结构是否有效。
- 场景层是否覆盖 1 到 `max_act`，引用的路线是否存在，战斗修正、Boss 目标和权重修正结构是否有效。

校验通过会输出 `DESIGN_CONFIG_VALIDATION: PASS`。出现 `ERROR` 时不能把配置交给游戏或发布流程。

## 四、导出命令

```powershell
python -B scripts\design_config\export_design_config.py --clean
```

默认输出目录：

```text
package/design_config_export/
```

导出内容：

- `schema.json`
- `tools.json`
- `ornaments.json`
- `events.json`
- `routes.json`
- `stages.json`
- `economy.json`
- `item_catalog.json`
- `manifest.json`

`item_catalog.json` 是从 Godot `.tres` 物品资源提取的策划可读目录，方便后续 Web 工具或表格工具展示物品池。`package/` 已被 `.gitignore` 忽略，导出包不提交。

## 五、开发边界

第一版只允许策划安全调整“数据和数值”，不允许通过配置新增任意脚本逻辑。

推荐规则：

- 能用枚举表达的字段必须进入 schema，例如道具目标、事件效果、路线节点类型。
- 新效果应先由程序实现 `effect_id` 或 `type`，再开放给配置。
- 脚本校验必须先于导出。
- 配置改动进入仓库前仍需跑全量 GUT 和严格场景冒烟。

## 六、后续迭代

建议顺序：

1. 增加 Excel/CSV 到 JSON 的导入脚本。
2. 将奖励池、商店权重和道具出现概率从代码常量迁入 JSON。
3. 为事件、路线和场景层增加更细的 schema 校验，例如节点内容模板、风险事件预览和关卡差异预览要求。
4. 开发本地 Web 配置界面，复用当前校验与导出脚本。
5. 增加战斗模拟和经济曲线预览。
