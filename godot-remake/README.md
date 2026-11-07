# Space Vikings — Godot scaffold

A minimal Godot 4.x project to replace the non-functional `js-remake/` port.
Right now this does exactly one thing: load a converted Apple II shape-table
file and draw it as plain lines and dots, to confirm the reverse-engineered
shape data (`modern/shapes_json/*.payload.json` in the main repo, copied
into `assets/shapes/` here) renders correctly in an actual engine.

Only the 21 `PLANET no N`/`SHIP no N` files are included — `PLANET FILE`
and `PLANET FILE-M` are save-state data (the undeciphered `FF FF 01 01`
pattern noted in `README_COMPLETE.md`), not shape tables; the original
converter ran them through the shape parser anyway and produced 256
garbage "shapes," so they're deliberately left out here.

## Opening

Requires Godot 4.3+ (not installed in this environment — install it
yourself, then `godot --path godot-remake` or open `project.godot` from
the editor's project manager). Running the project opens `scenes/planet_test.tscn`,
which draws `assets/shapes/PLANET no 0.payload.json`.

## How it works

`scripts/shape_view.gd` parses the shape JSON directly (no Godot-native
resource conversion yet) and draws each shape's `path_commands` as a
polyline — `move` starts a new subpath (pen up), `line` extends the current
one (pen down) — via `_draw()`. Shapes with a single point and no
`path_commands` are drawn as dots; these are the texture/crater detail
scattered across planet surfaces. A few shapes in the source data have
multiple points but no `path_commands` breakdown (a quirk of the original
converter) — those are drawn as one continuous polyline.

By default it draws one shape at a time (`shape_index`, starting at 0) —
use the arrow keys while the scene is running to step through every shape
in the file. Apple II shape tables are usually a set of independently-drawn
elements rather than pieces of one combined image, so overlaying all of
them (`shape_index = -1`) is mostly noise; stepping through them one at a
time is how you actually tell what each one is.

Swap to a different shape file at runtime or in the inspector via the
`shape_file_path` export on the `PlanetTest` node, or call
`load_shape_file(path)` on it from code.

## Known unknown: vertical orientation

The `flip_y` export defaults to `false` (render the JSON's y values as-is).
Godot's 2D coordinate system is y-down, same as the Apple II's, so this
*should* be correct without inversion — but the original shape-SVG
converter inverted y for its SVG output, specifically because Apple II y
increases downward. Verify visually once you can actually open the editor:
if a planet circle renders upside down or a ship's nose points the wrong
way, flip `flip_y` to `true`.

## Next steps

- Visually verify orientation/scale against the original game's screenshots
  or the converted SVGs in `modern/shapes_json/*.svg`.
- Convert `assets/shapes/*.json` to native Godot resources (or at least an
  import step) instead of parsing raw JSON at runtime, once the format is
  confirmed correct.
- Wire up actual game state (ship, planets, navigation) per
  `HANDOVER.md` / `GAME_MECHANICS_DOCUMENTATION.md` in the parent repo —
  this scaffold only proves the graphics pipeline, nothing else yet.
