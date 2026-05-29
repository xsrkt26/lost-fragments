# Resource Management

This project separates runtime assets from source/reference art.

## Directory Roles

- `assets/ui/`: runtime UI textures, grouped by feature.
- `assets/ui/battle/`: battle screen art and effects.
- `assets/ui/battle/intro_bag_reveal/`: battle intro bag reveal frame sequence.
- `assets/ui/book/`: shared book/page/tab textures reused by hub, gallery, settings, and backpack overlay.
- `assets/ui/backpack/`: backpack-specific runtime UI pieces.
- `assets/ui/items/`: item icons used by item resources.
- `assets/characters/`: runtime character animation frames and sprite resources.
- `assets/audio/bgm/` and `assets/audio/sfx/`: runtime audio.
- `assets/fonts/`: runtime fonts only.
- `assets/sourceImage/`: source art, references, compressed deliveries, videos, and review material only. Runtime code must not reference this path.

## Naming

- Runtime filenames use ASCII `lower_snake_case`.
- Numbered frames use two digits: `name_01.png`, `name_02.png`.
- Keep source-delivery filenames unchanged in `assets/sourceImage/` when needed for traceability.
- Do not add new runtime references to Chinese source filenames or delivery archive names.

## Import Rules

- Copy curated runtime art from `assets/sourceImage/` into the correct runtime folder before referencing it.
- Reuse shared textures from `assets/ui/book/`, `assets/ui/backpack/`, and `assets/ui/gallery/` instead of duplicating the same visual in feature folders.
- Do not reference `res://assets/sourceImage/...` from `.gd`, `.tscn`, `.tres`, or `.json`.
- `assets/sourceImage/.gdignore` prevents Godot from importing source deliveries by default.

## Export Rules

`export_presets.cfg` excludes source/reference/build directories from release exports:

- `assets/sourceImage/**`
- `addons/**`
- `test/**`
- `tools/**`
- `scripts/**`
- `src/debug/**`
- `src/ui/debug/**`
- `src/ui/ui_demo_scene.*`
- `data/items_legacy/**`
- `archive/**`
- `docs/**`
- `spec/**`
- `tmp/**`
- `package/**`
- `assets/fonts/*.md`
- `assets/fonts/licenses/**`
- local AI scratch folders and transition GIF previews

Before release, run:

```powershell
rg -n "res://assets/sourceImage" src data assets test --glob "*.gd" --glob "*.tscn" --glob "*.tres" --glob "*.json"
```

Any non-`.import` hit means a source asset leaked into runtime.

## Intake Checklist

1. Put raw deliveries, zips, videos, and previews under `assets/sourceImage/`.
2. Choose only the required runtime files.
3. Rename them to ASCII lower snake case.
4. Place them in the matching runtime directory.
5. Update code/scenes/resources to reference runtime paths.
6. Run Godot import and GUT tests.
7. Check duplicate large files before committing.
