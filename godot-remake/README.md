# Space Vikings — Godot scaffold

A Godot 4.x project to replace the non-functional `js-remake/` port. Two
layers so far:

- **The shape-table viewer** (`scenes/planet_test.tscn`,
  `scripts/shape_view.gd`) — the original proof-of-concept: load a
  converted Apple II shape-table file and draw it as plain lines and dots,
  to confirm the reverse-engineered shape data
  (`modern/shapes_json/*.payload.json` in the main repo, copied into
  `assets/shapes/` here) renders correctly in an actual engine. Still
  reachable from the Start screen.
- **The actual game scaffold** (everything under `autoload/`, the rest of
  `scenes/`, `scripts/ui/`, `scripts/flight/`) — a real, playable-today
  skeleton wiring up the state machine and mechanics traced in the parent
  repo's analysis docs. See "What's real vs. stubbed" below.

Run `godot --path godot-remake` (or open `project.godot` in the editor) —
it boots to `scenes/start.tscn`.

## What's real vs. stubbed

| Area | Status | Source doc |
|---|---|---|
| Shared game state (`autoload/game_state.gd`) | Real — named fields replacing every address this investigation confirmed | all four `*_ANALYSIS.md` docs |
| Space flight attitude model (pitch/bank/heading) | Real — ports the documented coordinated-turn behavior; rates/limits are feel-tuned for modern input, not byte-matched | `FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md` |
| Ground invasion battle loop | Real — the full per-round formula, tech-tier branching, retreat, surrender | `GROUND_COMBAT_ANALYSIS.md` |
| Loot collection by tech tier | Real | `GROUND_COMBAT_ANALYSIS.md` |
| Shore Leave: pay troops (morale) | Real | `GROUND_COMBAT_ANALYSIS.md` |
| Troop recall | Real (thin — no morale/credit effect in the original either) | `GROUND_COMBAT_ANALYSIS.md` |
| Galaxy map, Command console, Status screen | Real navigation/readout, no original visuals (starmap chart, bezel HUD) ported yet | — |
| Enlist / Sell Loot / Repair-Restock / Establish Base / Cryogenics / Radar / End | Stubs (`GameState.show_stub(...)`) — menu options exist and are gated correctly, but each just shows a note citing where its real logic lives | `GROUND_COMBAT_ANALYSIS.md` |
| A2-3D1's own 3D math (VM, clipping, perspective, plotter) | Not ported, by design — Godot's native 3D replaces it | `A2-3D1_ENGINE_ANALYSIS.md` |
| Starfield during flight | Placeholder (`MultiMeshInstance3D`) standing in for whatever A2-3D1's confirmed per-frame call actually drew | `FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md` |
| Combat (fighters/lasers/explosions), atmosphere/reentry mode, 2D shape-table rendering in-engine | Not started | `COMBAT_VFX_ANALYSIS.md` |

Every stub was deliberately kept navigable (not a dead end) so the full
original overlay graph — Start → Galaxy Map → Command Console → Ground
Forces → {Shore Leave, Recall, Collect} and back — can be walked end to
end today, even where a given screen's real behavior isn't built yet.

One deliberate deviation from faithful porting: the original's ground-
battle retreat trigger is a verified bug (any keypress fires it, not a
specific key — see `GROUND_COMBAT_ANALYSIS.md`'s "Retreating mid-battle"
section). This port uses an explicit Retreat button instead of
reproducing that bug as if it were a design choice.

Validated by instantiating every scene and running the ground-combat
battle loop headlessly (`godot --headless --path . res://scenes/<x>.tscn
--quit-after N`); no editor install was available to click through it by
hand, so give the flight controls and menus a manual pass before trusting
the feel of anything.

## The shape-table viewer

Only the 21 `PLANET no N`/`SHIP no N` files are included — `PLANET FILE`
and `PLANET FILE-M` are save-state data (the undeciphered `FF FF 01 01`
pattern noted in `README_COMPLETE.md`), not shape tables; the original
converter ran them through the shape parser anyway and produced 256
garbage "shapes," so they're deliberately left out here.

## Opening

Requires Godot 4.3+. `godot --path godot-remake` or open `project.godot`
from the editor's project manager; the project now boots to
`scenes/start.tscn`, with a button through to the shape viewer rather
than opening directly into it.

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
- Fill in the remaining stubs in the "What's real vs. stubbed" table
  above, starting with whichever matters most for a playable loop
  (Enlist Troops and Sell Loot are the two that gate finishing an
  invasion cleanly).
- Hook the converted shape data up to actual sprites/meshes in the flight
  and combat scenes — it's only ever been rendered in the standalone
  viewer so far.
- Decide a real starting troop/transport count (`GameState.troops`,
  `gf_transports`) once START.bas's MISC FILE initialization is traced;
  both are placeholders right now, flagged as such in `game_state.gd`.
