# UI Fonts

Drop UI font files in this folder. `GlobalTheme` will load them automatically at runtime.

Preferred filenames:

- `ChillHuoSong_F_Regular.otf` for regular UI/body text.
- `ChillHuoSong_F_ExBold.otf` or `ChillHuoSong_F_Bold.otf` for titles and display labels.
- `LXGWWenKaiLite-Regular.ttf` or `.otf` for regular UI/body text.
- `LXGWWenKai-Regular.ttf` or `.otf` for regular UI/body text.
- `SmileySans-Oblique.ttf` or `.otf` for titles and display labels.
- `NotoSansCJKsc-Regular.otf` or `.ttf` as a broad Simplified Chinese fallback.
- `NotoSansSC-Regular.ttf` or `.otf` as a broad fallback.
- `NotoSerifSC-Regular.ttf` or `.otf` as an alternate fallback/body font.

Bundled files:

- `ChillHuoSong_F_Regular.otf`: primary body UI font.
- `ChillHuoSong_F_ConRegular.otf`: alternate condensed body UI font.
- `ChillHuoSong_F_ExBold.otf`: primary display/title font.
- `ChillHuoSong_F_Bold.otf`: alternate display/title font.
- `LXGWWenKaiLite-Regular.ttf`: body UI font.
- `SmileySans-Oblique.ttf`: display/title font.
- `NotoSansCJKsc-Regular.otf`: fallback font for missing CJK glyphs.

See `SOURCES.md` and `licenses/` for source links and bundled license files.

Scene nodes can opt into the display font by setting `theme_type_variation` to:

- `DisplayLabel` for title labels.
- `DisplayButton` for prominent buttons.

Regular `Button` nodes use the display font automatically. Other controls use the body font.

If none of these files exist, the game keeps using Godot's default font.
