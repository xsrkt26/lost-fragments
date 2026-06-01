# Lost Fragments

Godot 4.6.2 项目，面向 MiniGame 2026 的背包式卡牌连锁游戏原型。

## 项目亮点

- 背包网格、道具连锁、饰品、事件、商店和路线系统已拆成可测试模块。
- 已接入 Story Book 剧情页、固定事件剧情、Act 1 小咪教学对话，以及后续章节的枢纽视觉/捕梦网表现。
- 已接入正式 BGM / SFX、工具图标、Windows release 包署名和发布 manifest。
- 使用 GUT 覆盖核心玩法逻辑，并用 headless scene smoke 覆盖关键场景加载。
- 接入 GitHub Actions：push/PR 自动跑测试和 Windows 导出烟测，`v*` tag 自动导出 Windows release。
- 策划配置可用 Python 工具校验和导出，便于迭代数值与卡牌内容。

## 最新发布

- 最新版本：[`v0.1.18`](https://github.com/xsrkt26/lost-fragments/releases/tag/v0.1.18)
- 本地发布说明：`docs/releases/v0.1.18.md`
- 本版重点：恢复 `beginning` 书页播片，修正 Act 1 小咪对话/教学和固定事件 1-6 的播放顺序，并把 `v0.1.8` 的音频、Story Book、后期章节视觉、工具图标和发布流程更新合并到当前 release 说明中。

## 当前入口

- 主场景：`res://src/ui/main_menu/main_menu.tscn`
- 开场书页剧情：`res://src/ui/story/story_book_scene.tscn`
- 局外路线：`res://src/ui/hub/hub_scene.tscn`
- 局内游戏：`res://src/ui/main_game_ui.tscn`
- 商店：`res://src/ui/shop/shop_scene.tscn`
- 调试沙盒：`res://src/ui/debug/debug_sandbox.tscn`
- 剧情数据：`res://assets/story/story_events.json`

命令行脚本通过 `GODOT_BIN` 环境变量或 PATH 查找 Godot 可执行文件。Windows 示例：

```powershell
$env:GODOT_BIN = "C:\path\to\Godot_v4.6.2-stable_win64_console.exe"
```

## 目录结构

```text
res://
├── addons/        # 第三方插件，目前包含 GUT
├── assets/        # 美术、音频和应用图标
├── data/          # 物品、饰品、事件等数据资源
├── spec/          # 策划文档、技术文档和开发日志
├── src/           # 游戏源码和场景
├── test/          # GUT 自动化测试
├── tools/         # 仓库级工具脚本
├── project.godot  # Godot 项目配置
└── export_presets.cfg
```

`package/` 是本地导出目录，已加入 `.gitignore`，导出的 exe/pck 不进入源码仓库。

## 运行

用 Godot 打开仓库根目录即可。命令行运行主项目：

```powershell
& $env:GODOT_BIN --path .
```

调试时可直接运行 `res://src/ui/debug/debug_sandbox.tscn`，用于快速生成物品、验证背包放置、旋转、丢弃和连锁效果。

## 剧情流程

当前剧情流程以 `assets/story/story_events.json` 为数据源，由 `StoryManager` 统一排队播放：

1. 开始游戏进入 `beginning` 书页播片，一次点击推进一句/一帧。
2. 进入 Act 1 Hub 后播放 `进入场景1`，这是唯一的小咪与主角场景对话。
3. 点击捕梦网进入第一关局内后播放 `进入局内1` 小咪教学。
4. Act 1 完整路线结束后播放 `固定事件1·小咪`，随后进入 Act 2。
5. Act 2-6 不再出现小咪和普通进场对话；每个 Act 的完整路线结束后播放对应固定事件。
6. Act 6 胜利后先播放 `固定事件6·拾忆`，再进入 `end1` 或 `end2` 结局。

固定事件和 `beginning` 都在空白书页中播放；战斗、商店等 Hub 内嵌状态会先完成收尾，再打开待播剧情页。

## 测试

全量 GUT：

```powershell
& $env:GODOT_BIN --headless --rendering-driver opengl3 --path . -s addons/gut/gut_cmdln.gd -gexit -glog=0
```

静默测试脚本：

```powershell
.\tools\run_tests_silent.ps1
```

严格场景冒烟测试：

```powershell
python -B scripts\run_scene_smoke_tests.py --fail-on-engine-error --fail-on-engine-warning
```

该脚本会先执行一次 Godot headless editor 导入，用于生成 `.godot/global_script_class_cache.cfg` 和 `.godot/imported` 资源缓存；隔离副本或 CI 不需要提交 `.godot/`。

策划配置校验：

```powershell
python -B scripts\design_config\validate_design_config.py
```

策划配置导出：

```powershell
python -B scripts\design_config\export_design_config.py --clean
```

导出结果写入 `package/design_config_export/`，包含 schema、道具、饰品、事件、路线、经济配置和从 `.tres` 资源提取的物品目录。

关键场景冒烟测试由 `test/integration/test_scene_smoke.gd` 和 `scripts/scene_smoke_scenes.json` 维护，固定 headless 加载：

- `src/ui/main_menu/main_menu.tscn`
- `src/ui/hub/hub_scene.tscn`
- `src/ui/main_game_ui.tscn`
- `src/ui/shop/shop_scene.tscn`
- `src/ui/debug/debug_sandbox.tscn`
- `src/ui/backpack/backpack_ui.tscn`
- `src/ui/event/event_scene.tscn`

## 开发约定

- 最新需求和实现优先级见 `spec/Docs/02_Tech/ImplementationTODO.md`。
- Agent 接手开发流程见 `spec/Docs/02_Tech/04_Agent_Development_Workflow.md`。
- 策划配置工具说明见 `spec/Docs/02_Tech/05_Design_Config_Tool.md`。
- 新功能完成后需要补自动化测试、跑全量 GUT、更新文档、commit 并 push。
- Godot 路径移动后如出现 class_name 缓存问题，先执行：

```powershell
& $env:GODOT_BIN --headless --rendering-driver opengl3 --editor --quit --path .
```

## 发布导出

发布前置检查会强制运行全量 GUT、Python 工具测试和严格场景冒烟，并在 `package/` 写入构建 manifest：

```powershell
.\tools\export_windows_release.ps1 -PrecheckOnly
```

本地 Windows 正式导出：

```powershell
.\tools\export_windows_release.ps1
```

导出脚本使用 `export_presets.cfg` 中的 `Windows Desktop` preset，输出形如 `package/LostFragments-<构建时间>-<提交号>.exe`，同目录生成 `.manifest.json`，记录版本号、构建时间、分支、提交号、测试结果和导出状态。若 Godot 路径不同，可通过 `GODOT_BIN` 环境变量或 `-GodotBin` 参数覆盖。

GitHub Releases 自动发布已接入。推送 `v*` tag 会触发 `.github/workflows/release.yml`，自动运行发布前检查、导出 Windows 包、生成 zip，并创建 GitHub Release：

```powershell
git tag -a v0.1.19 -m "v0.1.19"
git push origin v0.1.19
```

包含 `alpha`、`beta` 或 `rc` 的 tag 会自动标记为 prerelease。workflow 使用 GitHub Actions 内置 `GITHUB_TOKEN`，正常情况下不需要额外配置 Personal Access Token。
