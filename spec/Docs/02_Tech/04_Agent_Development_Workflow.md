# Agent 开发工作流

本文档用于让后续 Agent 在新的对话中继续以同一套质量标准开发本项目。除非用户给出更新指令，否则按本文档执行。

## 固定环境

- 仓库路径：当前 Git 工作区根目录。
- Godot 控制台路径：优先读取 `GODOT_BIN` 环境变量；否则使用 PATH 中的 `godot`、`godot4` 或 `Godot_v4.6.2-stable_win64_console.exe`。
- 目标分支：`main`
- 每次完成一个需求或一组明确改动后，必须 commit 并 push。
- `package/`、`.godot/` 属于本地生成目录，不提交。

## 需求来源优先级

1. 用户当前对话中的最新明确指令。
2. `spec/Docs/02_Tech/ImplementationTODO.md` 的优先级和完成状态。
3. `spec/Docs/01_Design` 中的正式策划文档。
4. 现有代码行为、自动化测试和 README。

`spec/Docs/01_Design/temp` 目录下内容不作为当前需求来源，只能在用户明确要求时作为参考材料。道具系统 F1 已恢复并完成基础版本，后续只按 `ImplementationTODO.md` 中的调优项继续迭代。

## 每次接手启动检查

进入仓库后先执行：

```powershell
git status --short --branch
git log --oneline -8
```

随后阅读：

```powershell
Get-Content spec/Docs/02_Tech/ImplementationTODO.md -Encoding utf8
Get-Content spec/Docs/02_Tech/04_Agent_Development_Workflow.md -Encoding utf8
```

如果用户给了本地文件、视频或新文档路径，先确认文件可访问，再把它纳入当前需求分析。

## 标准开发循环

每个需求按以下顺序推进：

1. 梳理需求和当前实现
   - 明确需求来自哪里。
   - 阅读相关设计文档、技术 TODO、代码和已有测试。
   - 如果需求与文档冲突，以用户当前最新指令为准，并把假设写回文档。

2. 设计实现方案
   - 优先沿用现有架构、数据结构和场景组织。
   - 不做无关重构。
   - 共享规则抽到单一入口，避免奖励、商店、事件、UI 等重复维护同一套逻辑。
   - 对素材、美术、外部发布权限等无法由代码直接补齐的部分，记录阻塞边界和替换点。

3. 开发代码
   - 使用 `apply_patch` 做人工编辑。
   - 新增 Godot 脚本后，运行测试或导入流程会生成 `.gd.uid`，需要与脚本一起提交。
   - 不回退用户或其他 Agent 的无关改动。
   - 遇到不明确需求时，先按正式设计文档和现有系统做合理实现；仍不明确但可低风险推进时，记录“实现假设”后继续。

4. 自动化测试
   - 功能逻辑优先补 GUT 单元/集成测试。
   - UI、场景、资源类改动必须跑关键场景 headless smoke。
   - 发布流程类改动优先跑发布 precheck。
   - 测试失败先修复，不带失败提交。

5. 文档更新
   - 更新 `ImplementationTODO.md` 中对应需求的当前状态、完成记录、实现假设和测试范围。
   - 若新增流程、命令或目录规则，同步 README 或本工作流文档。

6. 提交与推送
   - 提交前检查 `git status --short` 和 `git diff --stat`。
   - commit message 使用简洁英文祈使式，例如 `feat: add global button feedback`。
   - `git push` 到远程。
   - 推送后确认 `git rev-parse HEAD` 与 `git rev-parse origin/main` 一致。

## 必跑验证命令

全量 GUT：

```powershell
.\tools\run_tests_silent.ps1
```

严格场景冒烟：

```powershell
python -B scripts\run_scene_smoke_tests.py --fail-on-engine-error
```

策划配置校验：

```powershell
python -B scripts\design_config\validate_design_config.py
```

发布前置检查：

```powershell
.\tools\export_windows_release.ps1 -PrecheckOnly
```

关键场景列表由 `scripts/scene_smoke_scenes.json` 维护，当前固定覆盖：

- `src/ui/main_menu/main_menu.tscn`
- `src/ui/hub/hub_scene.tscn`
- `src/ui/main_game_ui.tscn`
- `src/ui/shop/shop_scene.tscn`
- `src/ui/debug/debug_sandbox.tscn`
- `src/ui/backpack/backpack_ui.tscn`
- `src/ui/event/event_scene.tscn`

## 视频和手工反馈处理

用户提供视频路径时：

1. 用 `Get-Item` 确认文件存在。
2. 用 `ffprobe` 查看时长、分辨率和帧率。
3. 用 `ffmpeg` 抽 contact sheet 和关键帧。
4. 用图片查看工具定位具体 UI/交互现象。
5. 将现象转成可执行的代码问题，再按标准开发循环实现、测试、文档、commit、push。

最近一次视频反馈中的基础问题已处理：Hub 整理背包通过 `main_game_ui.tscn` 的整理背包浮层模式打开，提供鼠标关闭按钮、`UI` 输入上下文保护和居中背包布局。后续若继续扩展整理背包专属功能，再评估是否拆出独立整理背包 scene。

## 当前未完全由代码闭环的事项

- F1 道具系统：基础版本已完成；剩余工作是掉落权重、商店价格、道具联动饰品数值和表现素材调优。
- F7 正式捕梦动画、美术或 CG：当前缺少正式素材，代码替换点是 `MainGameUI._play_dreamcatcher_animation()`。
- GitHub Releases 自动发布：已接入 `v*` tag 触发、内置 `GITHUB_TOKEN` 和 Windows zip 上传；后续按试玩节奏推 tag。

## 最终交付说明

向用户汇报时保持简洁，至少说明：

- 完成了什么。
- 跑了哪些验证。
- commit hash 和 push 状态。
- 如果有阻塞，说明阻塞原因和已记录位置。
