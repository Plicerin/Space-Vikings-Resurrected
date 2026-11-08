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

**Convention:** no script in this project uses `class_name`. A `class_name`
requires Godot's global script-class cache, which only gets built the
first time the project is opened in the full editor — not guaranteed on
a fresh clone run straight from the command line (a real bug found this
way: the shape viewer worked for whoever built it, then broke on a fresh
clone elsewhere). Scripts that need to reference each other's types
`preload()` the script into a local const instead — see
`scripts/shapes/shape_table.gd` for the pattern. Keep doing this for any
new script that needs a type name.

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
| Radar screen | Real — see "Radar" below | `A2-3D1_ENGINE_ANALYSIS.md` |
| Ship I.D. screen (press X on radar) | Real — see "Ship I.D." below | — |
| Enlist / Sell Loot / Establish Base | Real — `scripts/ui/{enlist,sell_loot,establish_base}.gd`, exact formulas from `SHORE LEAVE.bas` | `GROUND_COMBAT_ANALYSIS.md` |
| Repair/Restock / Cryogenics / End | Stubs (`GameState.show_stub(...)`) — menu options exist and are gated correctly, but each just shows a note citing where its real logic lives. Repair specifically needs ship-system damage values this port doesn't model yet | `GROUND_COMBAT_ANALYSIS.md` |
| A2-3D1's own 3D math (VM, clipping, perspective, plotter) | Not ported, by design — Godot's native 3D replaces it | `A2-3D1_ENGINE_ANALYSIS.md` |
| Starfield during flight | Placeholder (`MultiMeshInstance3D`), deliberately finite — the original's own starfield is a bounded sphere you can fly through, not infinite/regenerating, so this isn't a bug to fix | `FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md` |
| Planet during flight (deep-space view) | Real — `PLANET # 0`'s actual 195-point field, same file `ORBIT.bas` loads for this view | `A2-3D1_ENGINE_ANALYSIS.md` |
| Planet during re-entry (per-world terrain map) | Real — `scenes/planet_approach.tscn`, triggered automatically by proximity to the planet during flight | `A2-3D1_ENGINE_ANALYSIS.md` |
| Combat VFX: fighter approach/retreat/explosion, laser beam, EX.bas ship destruction, incoming-fire pattern | Real — see "Combat VFX" below | `COMBAT_VFX_ANALYSIS.md` |
| Combat integration (when an encounter actually starts during flight) | Not started | `COMBAT_VFX_ANALYSIS.md` |

Every stub was deliberately kept navigable (not a dead end) so the full
original overlay graph — Start → Galaxy Map → Command Console → Ground
Forces → {Shore Leave, Recall, Collect} and back — can be walked end to
end today, even where a given screen's real behavior isn't built yet.

One deliberate deviation from faithful porting: the original's ground-
battle retreat trigger is a verified bug (any keypress fires it, not a
specific key — see `GROUND_COMBAT_ANALYSIS.md`'s "Retreating mid-battle"
section). This port uses an explicit Retreat button instead of
reproducing that bug as if it were a design choice.

Validated two ways, since no GUI/editor automation is available in this
environment: every scene is instantiated headlessly
(`godot --headless --path . res://scenes/<x>.tscn --quit-after N`) to
catch script/scene errors, and the flight controller and combat VFX were
additionally driven through a real render pass (an automated input
sequence under `cage`'s headless Wayland backend, with screenshots
captured and visually inspected) to confirm they actually look right, not
just that they run without erroring. Still worth a manual pass in a real
windowed session before trusting the feel of anything.

## Combat VFX

`scripts/combat/` ports `COMBAT_VFX_ANALYSIS.md`'s trace of
`STARSHIP SIMULATOR.bas`/`EX.bas` — none of which uses the A2-3D1 3D
engine, all of it flat 2D vector/sprite drawing over the cockpit view in
the original. `scripts/shapes/hgr_canvas.gd` reproduces the Apple II's
280x192 hi-res coordinate space (scaled up) so the ported code can use the
BASIC source's literal pixel coordinates (reticle corners, `M`-loop screen
Y, etc.) directly instead of re-deriving new ones.

- **Fighter encounter** (`fighter_encounter.gd` + `fighter_slot.gd`): the
  two-fighter flip-book approach, the fixed-shape retreat/flyby, and the
  scale-flash + debris-stamp explosion — lines 1000-1222.
- **Laser beam** (`laser_beam.gd`): the two converging cockpit-corner
  triangles, flickered 3x — lines 1505-1530. Sound (`CALL LA`, confirmed
  pure frequency-sweep speaker tone, decoupled from the visual) isn't
  ported; audio is a separate, not-yet-started task.
- **Ship destruction** (`ship_destruction.gd`): `EX.bas`'s bigger
  screen-centered version of the same flash+debris, plus a genuine
  radiating-line particle burst, plus persistent (stand-in) wreckage —
  not wired to any hull/health system, since none has been traced yet.
- **Incoming fire** (`incoming_fire.gd`): the separate generic
  shape-crosses-the-screen-and-sometimes-fires pattern, lines 5000-5251.

All four are reachable standalone from the Start screen's "Combat VFX
Demo" button — not yet wired into an actual spawn trigger inside
`space_flight.tscn`, since no "when does a fighter encounter start"
condition has been traced in the analysis docs.

## Radar

Press `R` during flight (`space_flight.gd`'s `open_radar` action,
matching the real `ON K-... GOTO` key-dispatch chain in `STARSHIP
SIMULATOR.bas` lines 200-206 — confirmed live in MAME, see
`A2-3D1_ENGINE_ANALYSIS.md`'s "Live-verified 2026-11-07" section) or
choose Radar from the Command Console. This is **not** the Applesoft
shape-table system the rest of the shape viewer uses — `SHIP # N` is
real `A2-3D1` 3D-engine bytecode (vertex/line-draw opcodes), a genuinely
different binary format, decoded by `tools/a2_3d1_model_decoder.py` and
loaded by `scripts/shapes/a2_3d1_model.gd`.

- `radar_hud.gd`: the border/crosshair/reticle overlay, literal HPLOT
  coordinates from `RADAR.bas` lines 2005-2042, drawn through
  `HgrCanvas` same as the combat VFX.
- `radar_screen.gd` + `a2_3d1_model.gd`: the actual 3D wireframe ship
  blip. Idiomatic-Godot choice, not a port: the model is built as a
  real `ArrayMesh` (`Mesh.PRIMITIVE_LINES`) and rendered through a real
  `Camera3D` — Godot's own 3D pipeline replaces the original's
  hand-rolled 6502 rotate/clip/perspective-divide math, same spirit as
  the flight scene's `Camera3D`/`MeshInstance3D` use (see the "A2-3D1's
  own 3D math" row in the table above). The camera auto-frames each
  model from its own bounding radius, since the four real ship files
  span very different absolute sizes. A slow constant spin on the model
  is also new — the original's view is static while its own blocking
  `GET A$` waits for a keypress; the spin is purely to make "this is a
  real rotating 3D model" legible at a glance. Both are flagged in
  `radar_screen.gd`'s own doc comment if either reads as inauthentic
  rather than additive once more of the original is ported.
- Tier → ship mapping (`GameState.planet_orbital_defender_tier`, values
  0/1/3/4) and each tier's on-screen description are pulled directly
  from the real `SHIP no N I.D..bas` text. Which real planet gets which
  tier is a placeholder (random at new-game time) — the original's real
  assignment formula hasn't been traced yet.
- Pressing `X` goes to the real `SHIP # N I.D.` screen now — see
  "Ship I.D." below.

## Ship I.D.

`scenes/ship_id.tscn` + `scripts/ui/ship_id_screen.gd` — the *third*
ship-rendering system in this game (see "Radar" above for the other
two): `SHIP no N I.D..bas`'s own inline `DATA`-point 2D point-plotter,
decoded by `tools/decode_ship_id.py`. Draws the bordered 5px-grid box
from the original's lines 12-14 (literal `HPLOT` coordinates, same
convention as `radar_hud.gd`) plus the silhouette itself — confirmed
visually against all three real ships before wiring in: each one
genuinely draws *two* views (a top-down and a side profile, at two
different Y origins the original's own code switches between
mid-stream), not a decode artifact. Tier 0 correctly shows just the
empty grid (`SHIP no 0 I.D..bas` has no `DATA` at all — "THERE IS NO
STARSHIP IN THIS SYSTEM").

Layout liberty, not in the original: the description text goes below
the drawing instead of beside it (`HTAB 25`, the right ~40% of the
screen in the original), matching this port's own other new screens'
layout instead. Any key returns to radar, matching every one of the
four real files' own unconditional `RUN RADAR`.

## Re-entry

`scenes/planet_approach.tscn` + `scripts/ui/planet_approach.gd` — ports
`RE.bas` ("REENTRY SEQUENCE START", confirmed from its own on-screen
text). `space_flight.gd` triggers it automatically on proximity to the
planet, standing in for the original's `ABS(X)<900 AND ABS(Y)<900 AND
ABS(Z)<900` world-position box test (`STARSHIP SIMULATOR.bas` line
156) with a plain distance check — this port's flight model doesn't
track position in the original's units, and has no "weapon fired"
flag yet to port that condition's other half.

Shows the *real* per-world terrain map (`PLANET # <current_planet>`,
selected the same way `RE.bas` does it — `PEEK(38209)`) — genuinely
modeled, line-connected data, a different visual from the generic
point-field `Planet` seen during ordinary flight. After a few seconds
(or any keypress), returns to flight. Liberty, not in the original:
the ship gets nudged back away from the planet first, since nothing
else in this port's flight loop would otherwise move it out of range
before the very next frame re-triggered the same sequence — the
original's own position variables keep evolving every frame
regardless of this transition, so it never needed an explicit reset.

Also fixed along the way: `[G] Ground Forces`'s HUD text has said
"(when in range)" since this scene was scaffolded, but nothing actually
enforced it until this same proximity check went in.

## Shore Leave

Three of the five base-gated menu options in `ground_forces.gd` are
real now, each its own scene (the original routes all five through one
shared `SHORE LEAVE.bas` overlay, dispatched by `$38388`; this port
keeps them separate, same as the already-existing pay-troops flow):

- **Enlist** (`scripts/ui/enlist.gd`) — 1 credit/troop, capped so total
  troops can't exceed 20000. Input is a `SpinBox`, standing in for the
  original's digit-by-digit numeric-entry subroutine — same ultimate
  effect, not a byte-exact port of that subroutine.
- **Sell Loot** (`scripts/ui/sell_loot.gd`) — the exact 13-category
  multiplier table from `SHORE LEAVE.bas` lines 2400-2406
  (`GameState.compute_loot_value()`), including the one category whose
  multiplier is itself re-rolled every sale and the final ×2 on the
  whole sum. No Y/N gate in the original — it applies immediately on
  entering the screen, this port does too.
- **Establish Base** (`scripts/ui/establish_base.gd`) —
  `GameState.roll_base_cost()` is the original's exact
  `20000 + (RND(1)*5000)*(RND(1)*10)` formula. Keeps a genuine quirk
  from the source as-is: the once-per-trip flag is consumed the moment
  you reach the cost quote, *before* the Y/N prompt — declining on cost
  or saying "N" still uses up the attempt.

Both Enlist and Establish Base's once-per-trip flags
(`GameState.enlisted_this_trip`/`base_built_this_trip`) reset where the
original does (`H_D.bas` line 105, the start of a fresh orbital
engagement) — this port's nearest equivalent moment is re-entry
(`planet_approach.gd`).

Found and fixed two real pre-existing gaps while wiring this up, both
in `ground_forces.gd`:
- `_finish_battle()` was clearing `gf_planet_surrendered` right after a
  win to trigger the Collect transition — but the original's `$38208`
  never resets there, and Enlist's gate needs it to actually stay true
  afterward. Now a separate one-shot `just_won` parameter drives the
  transition instead of reading-and-clearing the persistent flag.
- Attack and Enlist were both missing the original's
  `troops_stationed_at == current_planet` check (`GROUND FORCES.bas`
  lines 66-67, "YOU LEFT YOUR TROOPS ON ANOTHER PLANET!") — documented
  in this file's own doc comment as something the original has, never
  actually wired in until now.

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
one (pen down) — via `_draw()`. A shape with no `path_commands` at all
(it never actually plots anything) is drawn as a single debug dot so the
viewer can tell "exists but draws nothing" apart from "doesn't exist" —
this is common and correct for planet files specifically: planets are
drawn as a deliberately abstract scatter of short dash shapes, not a
circle (confirmed against the real game's manual — see
`tools/shape_table_decoder.py`'s docstring).

By default it draws one shape at a time (`shape_index`, starting at 0) —
use the arrow keys while the scene is running to step through every shape
in the file. Apple II shape tables are usually a set of independently-drawn
elements rather than pieces of one combined image, so overlaying all of
them (`shape_index = -1`) is mostly noise; stepping through them one at a
time is how you actually tell what each one is.

Swap to a different shape file at runtime or in the inspector via the
`shape_file_path` export on the `PlanetTest` node, or call
`load_shape_file(path)` on it from code.

## Vertical orientation

The `flip_y` export defaults to `false` (render the JSON's y values as-is).
Godot's 2D coordinate system is y-down, same as the Apple II's, so this
is correct without inversion.

(Correction, 2026-11-07, same day: the original version of this note
cited decoding `SHIP no 1`'s shape 2 under *this* shape-table viewer
and comparing it to the manual's cockpit-view screenshot as the
confirming evidence. That comparison is no longer trustworthy as
stated — `SHIP # N` turned out not to be shape-table data at all, it's
real `A2-3D1` 3D-engine bytecode (see the "Radar" section above); the
match was a coincidental alternate parse, the same pattern that also
tripped up `PLANET # N` — see `A2-3D1_ENGINE_ANALYSIS.md`'s "Resolved"
sections. The `flip_y=false` conclusion itself is still believed
correct — it's confirmed independently via `ENEMY`'s live SHTAB memory
match in MAME, which genuinely is this shape-table format — just not
on the SHIP-vs-manual evidence this note originally cited.)

## Next steps

- Radar, flight's planet, re-entry, the Ship I.D. screen, and three of
  the five Shore Leave options are all real now (2026-11-07) — see
  "Radar"/"Re-entry"/"Ship I.D."/"Shore Leave" above. Also fixed
  project-wide: every pure-2D scene (this project has quite a few) was
  rendering against the engine's default gray clear color instead of
  black, since nothing had set one — `project.godot` now sets it
  globally. Left for later: Repair/Restock and Cryogenics (Repair
  needs ship-system damage values this port doesn't model yet — a
  natural pairing with the still-not-started combat-integration work),
  the real per-planet tier-assignment formula (currently random at
  new-game time), and a real "weapon fired" flag so the re-entry
  trigger can port the original's full condition instead of proximity
  alone.
- Re-verified against the corrected `ENEMY`/`EXPL` data (2026-11-07): the
  explosion and EX.bas destruction sequences still look solid (shape 15
  carries the debris, 16-18 are blank in the real data — that's fine,
  the flash+flicker is what sells it). The approach flip-book is
  different: it now visibly strobes between detailed and near-blank
  shapes every couple of frames as a direct consequence of which indices
  the real table has content at (see `fighter_encounter.gd`'s doc
  comment). Kept as-is deliberately, but not yet confirmed to be
  correct — worth another look once there's more confidence in the
  format (or real footage of this exact moment to compare against).
- Convert `assets/shapes/*.json` to native Godot resources (or at least an
  import step) instead of parsing raw JSON at runtime.
- Fill in the remaining stubs in the "What's real vs. stubbed" table
  above, starting with whichever matters most for a playable loop
  (Enlist Troops and Sell Loot are the two that gate finishing an
  invasion cleanly).
- Hook the converted shape data up to actual sprites/meshes for the
  player's own ship and planet surfaces in the flight scene — combat VFX
  now uses real shape data (see above), but flight still uses a plain
  mesh placeholder.
- Wire the combat VFX into an actual encounter — needs tracing when/why a
  fighter encounter or incoming-fire pattern starts during flight, and
  (for `ship_destruction.gd`) a real hull/health system to trigger off.
- Decide a real starting troop/transport count (`GameState.troops`,
  `gf_transports`) once START.bas's MISC FILE initialization is traced;
  both are placeholders right now, flagged as such in `game_state.gd`.
- Sound — nothing emits audio yet. Every effect that has one in the
  original (laser, explosions) notes exactly what's missing in its own
  script.
