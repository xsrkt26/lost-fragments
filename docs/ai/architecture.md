# Project Architecture

This Godot project uses a data-driven run loop with thin scene entry points and several long-lived autoload services.

Detailed large-module split planning is tracked in `spec/Docs/02_Tech/06_Refactor_Split_Plan_2026-05-28.md`.

## Scene Entries

- Main menu: `res://src/ui/main_menu/main_menu.tscn`
- Hub route scene: `res://src/ui/hub/hub_scene.tscn`
- Battle scene: `res://src/ui/main_game_ui.tscn`
- Shop scene: `res://src/ui/shop/shop_scene.tscn`
- Event scene: `res://src/ui/event/event_scene.tscn`
- Backpack page: `res://src/ui/backpack/backpack_page.tscn`; book navigation configures it through `configure_for_backpack_overlay()`.

## Runtime Ownership

- `RunManager` is the source of truth for the current run: route progress, deck, shards, ornaments, tools, backpack persistence, random state, shop/event cache, and save data.
- `BattleManager` owns battle state, draw resolution, backpack runtime state, impact queueing, tool usage, and battle-finish requests.
- `BackpackManager` owns grid placement rules, runtime item instances, blocked cells, seed growth, and item replacement.
- `ImpactResolver` converts one impact source into ordered `GameAction` results.
- `SequencePlayer` applies `GameAction` values and plays UI feedback.
- `ItemDrawPool` owns capture draw rules. It generates the battle draw sequence from the current act, item category weights, role weights, and implemented `ItemData` resources.
- UI scripts should request actions from managers and render state; they should not directly mutate long-term run data except through `RunManager` APIs.

## Data Sources

- Items: `data/items/*.tres` through `ItemDatabase`
- Ornaments: `data/ornaments/ornaments.json` through `OrnamentDatabase`
- Tools: `data/tools/tools.json` through `ToolDatabase`
- Events: `data/events/events.json` through `EventDatabase`
- Routes: `data/routes/routes.json` through `RouteConfig`
- Stages: `data/stages/stages.json` through `StageConfig`
- Economy: `data/economy/economy.json` through `EconomyConfig`
- Story sequences: `assets/story/story_events.json` through `StoryManager`

## Current Design Constraints

- `ItemData` resources are static templates. Runtime state must live in duplicated item data or `BackpackManager.ItemInstance`, never by mutating database resources.
- Gameplay random choices should use `RunManager` random helpers or `GameContext.random_*()` so RNG state can be serialized with the run.
- Capture draws should go through `RunManager.build_current_draw_deck()` / `ItemDrawPool`, not by directly shuffling `RunManager.current_deck`.
- Config loader classes cache normalized JSON by path and return defensive copies; tests that write custom config paths should call `clear_cache_for_tests()`.
- Route, stage, reward, shop, event, and economy values should stay out of UI scripts.
- Battle completion goes through `BattleManager.request_finish_battle()` and is resolved by the UI only after the current draw/impact sequence settles.
- New features should include focused GUT coverage and, for scene/UI changes, strict scene smoke coverage.
