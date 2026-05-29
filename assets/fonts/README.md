# UI Fonts

Drop UI font files in this folder. `GlobalTheme` will load them automatically at runtime.

Runtime font filenames use ASCII lower snake case:

- `chill_huosong_f_regular.otf` for regular UI/body text.
- `chill_huosong_f_ex_bold.otf` for titles and display labels.

Bundled files:

- `chill_huosong_f_regular.otf`: primary body UI font.
- `chill_huosong_f_ex_bold.otf`: primary display/title font.

Optional fonts and source deliveries live under `assets/sourceImage/fonts/optional/`.
See `sources.md` and `licenses/` for source links and bundled license files.

Scene nodes can opt into the display font by setting `theme_type_variation` to:

- `DisplayLabel` for title labels.
- `DisplayButton` for prominent buttons.

Regular `Button` nodes use the display font automatically. Other controls use the body font.

If none of these files exist, the game keeps using Godot's default font.
