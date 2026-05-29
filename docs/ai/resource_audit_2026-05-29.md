# Resource Audit 2026-05-29

## Findings

- `assets/sourceImage/` is the largest asset directory: 406.51 MB across 320 files. It contains source deliveries, archives, reference videos, BMP sequences, review sheets, and some previously referenced runtime PNGs.
- `assets/fonts/` originally held 152.19 MB. Runtime now keeps only the primary body and display fonts; optional fonts were moved to `assets/sourceImage/fonts/optional/`.
- `assets/ui/` is 50.11 MB and is the correct location for shipped UI art.
- `assets/characters/` is 8.22 MB and `assets/audio/` is 1.40 MB.
- Exact duplicate runtime/source pairs exist for book UI, backpack UI, hub backgrounds, gallery icons, and the new bag reveal frames. These are acceptable in the working tree if `sourceImage` stays source-only and excluded from export.
- The current release preset used `export_filter="all_resources"` without an exclude filter, which made imported source/reference art eligible for release packaging.

## Completed Changes

- Moved the battle intro bag reveal sequence into `assets/ui/battle/intro_bag_reveal/`.
- Updated `MainGameUI` to reference 5 runtime frames:
  - `bag_reveal_01.png`
  - `bag_reveal_02.png`
  - `bag_reveal_03.png`
  - `bag_reveal_04.png`
  - `bag_reveal_05.png`
- Kept `assets/sourceImage/包的变化/` as traceable source material.
- Added `assets/sourceImage/.gdignore` so Godot stops importing source deliveries by default.
- Added export exclusions for source/reference/build/scratch directories and development-only code such as GUT, tests, tools, scripts, and debug scenes.
- Added `.gitignore` entries for local Codex scratch output and transition GIF previews.
- Normalized runtime asset names to ASCII lower snake case for the newly connected bag reveal sequence and bundled fonts.
- Moved the unreferenced story CSV/translation source sheet from `assets/story/` into `assets/sourceImage/story/`.

## Current Policy

- Runtime assets belong under `assets/ui/`, `assets/characters/`, `assets/audio/`, `assets/fonts/`, or `data/`.
- Source deliveries and visual references belong under `assets/sourceImage/` and must not be referenced by runtime resources.
- New runtime paths should use ASCII lower snake case.
- Runtime sequence frames should use two-digit numeric suffixes, such as `bag_reveal_01.png`.
- Shared visuals should be placed once under their shared runtime folder and reused.

## Remaining Size Opportunities

- Font pass: if the retained two font faces still make the package too large, generate subset fonts for the actual shipped glyph set.
- Texture optimization pass: large 1920x1080 UI/background PNGs can be recompressed or split only when visual QA confirms no quality loss.
- Animation pass: several character and merchant frames are exact duplicates; sprite frame timings can often reuse one texture instead of shipping identical frames.
- Source archive cleanup: raw `.zip`, `.rar`, `.mp4`, and BMP deliveries can stay in `sourceImage` for traceability, but should remain excluded from export.
