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
| Galaxy map, Command console, Status screen, COMPUTER sub-menu (Navigation Computer, Galaxy Directory, Supplies Report) | Real navigation/readout, no original visuals (starmap chart, bezel HUD) ported yet — see "COMPUTER sub-menu" below | — |
| Radar screen | Real — see "Radar" below | `A2-3D1_ENGINE_ANALYSIS.md` |
| Ship I.D. screen (press X on radar) | Real — see "Ship I.D." below | — |
| Enlist / Sell Loot / Establish Base / Cryogenics / Repair/Restock / Buy Weapons | Real — `scripts/ui/{enlist,sell_loot,establish_base,cryogenics,repair_ship,buy_weapons}.gd`, exact formulas/state machine from `SHORE LEAVE.bas` | `GROUND_COMBAT_ANALYSIS.md` |
| End (Save/Continue/Quit) | Real — `scripts/ui/end_game.gd`. Turned out NOT to be a mission-end/scoring sequence despite the name — `END.bas` is Save Game/Continue Present Game/End Game. Real JSON save/load added alongside it (`GameState.save_to_disk()`/`load_from_disk()`), plus a Load Game option on the start screen | — |
| A2-3D1's own 3D math (VM, clipping, perspective, plotter) | Not ported, by design — Godot's native 3D replaces it | `A2-3D1_ENGINE_ANALYSIS.md` |
| Starfield during flight | Placeholder (`MultiMeshInstance3D`), deliberately finite — the original's own starfield is a bounded sphere you can fly through, not infinite/regenerating, so this isn't a bug to fix | `FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md` |
| Planet during flight (deep-space view) | Real — `PLANET # 0`'s actual 195-point field, same file `ORBIT.bas` loads for this view | `A2-3D1_ENGINE_ANALYSIS.md` |
| Planet during re-entry (per-world terrain map) | Real — `scenes/planet_approach.tscn`, triggered automatically by proximity to the planet during flight | `A2-3D1_ENGINE_ANALYSIS.md` |
| Flight combat (laser, missile, defender fire, fighter passes, turrets, shields / condition / weapon / autopilot switches, defender and player destruction) | Real — rules in `scripts/flight/flight_combat.gd`, drawing in `scripts/combat/combat_fx.gd` on a software hi-res page; see "Flight combat" below | `CALL_SITES.md` |

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

## Flight combat

Two scripts, split the way the original's BASIC is not:

- `scripts/flight/flight_combat.gd` — the rules of `STARSHIP
  SIMULATOR.bas` lines 185-192, 1500-1570, 3000-3381 and 5200-5251.
- `scripts/combat/combat_fx.gd` — what those lines draw, on a software
  copy of the hi-res page (`scripts/shapes/hgr_screen.gd`, shown by
  `hgr_view.gd`): the same `XDRAW`/`HPLOT` calls at the same
  coordinates in the same order, through a port of the ROM's shape
  drawing (`shape_table.gd`), with the pauses taken from the real
  machine.

Each script's doc comment lists its lines and quirks; `CALL_SITES.md`
has the line-by-line table. The short version:

**One loop iteration is the unit of time.** The original is a single
BASIC loop: about 130 frames of flight rendering, then the fire button
(line 185), then the enemy's turn (line 192: the defender's fire, then
a fighter pass 60% of the time). Every effect stops the loop while it
runs. The port keeps that order and those lengths. One liberty: a fire
press during the quiet part starts the iteration at once instead of
waiting up to two seconds for the loop to come round; the enemy's turn
still follows every shot.

**Panel switches** (`CALL 38402`, keys as in the original):

| Key | Switch | New game |
|---|---|---|
| `S` | shields up / down | down |
| `B` | condition BLUE → RED → GREEN → BLUE | RED |
| `W` | missile / laser | missile |
| `A` | autopilot (the stick is not read) | manual |

The stick is the arrow keys and the throttle is `Q`/`E`, so that these
four letters stay free. The panel lights are not drawn yet; the debug
line at the top of the flight view shows the four states.

**Rules that are easy to get wrong**, all ported and all checked either
live in MAME (`tools/mame/fight_live.lua`, logs in
`analysis/fight_live_*.log`) or against the source:

- Every result is POKEd, so it is cut down to a whole number. The laser
  adds `1/(tech+1)` to the defender's damage, which is lost at tech 1
  or more: **the laser never damages a defender there** (live at tech
  3: victory points 1 → 3 → 5 → 7, damage 0). It still moves the planet
  towards surrender. A missile hit adds `120/(tech+1)`.
- A missile costs 2 points of the missile system, except the one that
  destroys the defender (`RUN EX` leaves before line 1090).
- With shields down (the new-game state) every hit goes through to
  radar, engines, computer, laser and hull. With shields up and above
  10 a hit only wears the shield.
- BASIC's `DMG` flag is only cleared when damage goes through. Once
  raised shields have absorbed one hit, every later iteration in range
  wears them by another point whether or not anything is seen to hit
  (live: 14 iterations in a row).
- The turrets answer a strafing fighter only at condition RED.
- Fighters keep attacking after the defender is destroyed; the
  defender's own fire stops.
- Hull 0 is not death by itself: the test is made before the value is
  cut down, so a hull of 0.4 is stored as 0 and the next hit kills.

**The white flashes are real.** `POKE -16298,0` ... `POKE -16297,0`
switches the display to lo-res for as long as BASIC takes between the
two, and the lo-res page is all white during flight. They are
full-screen and fast; `HgrView.flashes_enabled` turns them off (the
Combat demo has the switch).

**Measured and estimated timing.** Measured on the real machine:
iteration length, fighter pass, turret fire, the line-1100 burst, the
laser, the missile's flight, hi-res text speed. Estimated from those
costs, not captured yet: the missile's direct hit (1200-1222), the
damage flashes (3019/3032) and `EX.bas`.

**Still approximate**, waiting on the flight model's own port: the
combat box of line 192 is a distance from the planet, the missile's
hit test (line 1050) is a forward cone, and there is no flight in
atmosphere (line 190, where the ship is rolled against twice per
iteration).

**The orbital defender** is the `SHIP # N` A2-3D1 model
(`GameState.orbital_defender_tier`), the ship the radar shows. It is
drawn in flight as `ShipBlip` (`space_flight.tscn`) with the same
`A2_3D1_Model.build_ship_mesh(tier)` the radar uses, and is rebuilt
when the tier changes (destroying it removes it). The small ships that
cross the view and strafe are the planet's fighters
(`flight_escort_fighters`, `$38207`), shapes 8-10 of the `ENEMY` table.

**Checked headless**, not only read: every effect run to its end with
the page dumped along the way, and the flight scene run against a
forced hostile planet with shields down, with shields up and the laser
held, and with the missile lined up (two hits at tech 3: damage 0 → 30
→ 60, defender destroyed, fighters halved, no missile cost on the
kill). The combat demo (Start screen → "Combat VFX Demo") plays each
effect on its own.

## Sound

Every real sound cue in the whole game turns out to reduce to exactly
two machine-code routines — confirmed by reading their disassembly
(`disassembly/LASER.disasm.txt` and `disassembly/SOUND GEN.disasm.txt`)
rather than guessing, since the BASIC source only ever says `CALL SG`/
`CALL LA`/`CALL NOISE`/`CALL EX` with no hint of what those actually
sound like:

- **LASER** ($92D1-$92E6) — a tight loop: 14 repetitions, each toggling
  the speaker 140 times with a per-toggle delay that grows every
  toggle. A growing delay between toggles means a falling toggle rate,
  i.e. falling pitch, so each of the 14 reps is a quick descending
  chirp back-to-back — the classic "pew" laser-zap shape. Used for
  every laser-fire visual (`CALL LA`, line 1505).
- **SOUND GEN** ($9276-$92BF, aliased `SG`/`NOISE`/`EX` under different
  BASIC variable names — confirmed the same routine by address, all
  three resolve to $9276) — a 16-bit shift register toggling the
  speaker in a pseudo-random pattern, wrapped in a nested duration
  loop set via `POKE 37490/37491` before most calls — a noise burst,
  not a tone. Used for every hit, miss, retreat-flicker, and explosion
  sound. Three real parameter presets found cited in `STARSHIP
  SIMULATOR.bas` (subroutines 4100/4110/4120, 10x10/5x5/7x7 loop
  counts) became the NOISE_HEAVY/LIGHT/MEDIUM presets.

Neither is cycle-exact — that would mean emulating real 6502 timing
against the speaker toggle, not just the routine's algorithmic shape —
each sound is synthesized from the real shape (chirp vs. noise,
relative durations) via `AudioManager` (`autoload/audio_manager.gd`),
not reproduced bit-for-bit. Same "faithful shape, feel-tuned constants"
approach this port already uses for non-byte-exact timing elsewhere.

`EX.bas` (75 calls) and `S_X.bas` (500 calls) call the noise routine
directly in a loop, with whatever duration-loop parameters happened to
be left over from whatever ran before — genuinely unknowable, not just
unported — so their much longer call counts (not a specific leftover
parameter state) are what this port actually reproduces, as the
NOISE_EXPLOSION/NOISE_DESTRUCTION presets, scaled up proportionally.

Wired into the call sites of `CALL SG`/`CALL LA`/`CALL NOISE`/`CALL
EX`: all the flight-combat ones are in `combat_fx.gd` (the laser's
`CALL LA`; heavy for the missile's burst and direct hit; light for the
light damage flashes and a fighter's strafing hit; medium for the
heavier damage flash; the explosion for `EX.bas`), and
`player_destroyed.gd` plays S_X.bas's destruction, the longest burst
in the game. Measured live, the first `CALL SG` after a `GOSUB
4100/4110` preset lasts 13 / 11 frames and later calls without a new
preset only 1-2 frames (the routine counts its duration bytes down).
The port plays the first and leaves the ticks out: the missile's
launch (line 1010), the repeats inside the burst and the turrets'
(line 5230).

Not wired, documented rather than silently dropped: `H_D.bas`'s own
~426-call noise burst during a hyperdrive jump (lines 17-20, the
"warp" sequence) — this port's `galaxy_map.gd` doesn't have a visual
counterpart for that sequence (travel is instant), so adding just the
sound without anything on screen to tie it to would likely read as a
stray, unexplained noise rather than an actual warp effect.

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
- Tier → ship mapping (`GameState.orbital_defender_tier`, values
  0/1/3/4) and each tier's on-screen description are pulled directly
  from the real `SHIP no N I.D..bas` text. The original's `$38205` is
  byte 1 of the current planet's 16-byte record: `CALL 38825` copies
  the record into the working registers on arrival and back out on
  departure (`H_D.bas` lines 12 and 25), so each planet has its own
  fixed defender and a destroyed one stays destroyed. Ported 2026-11-10
  as `GameState.planet_defender_type` with `store_planet_record()` /
  `load_planet_record()`, using the real new-game values from `P/F-M`
  (`tools/newgame_data.py`). An earlier version of this port re-rolled
  the tier at random on every arrival, on the mistaken reading that
  nothing ever sets `$38205`; see `CALL_SITES.md` §3.
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

All five base-gated menu options in `ground_forces.gd` are real now
(Cryogenics isn't actually base-gated in the original — see below),
each its own scene (the original routes all five through one shared
`SHORE LEAVE.bas` overlay, dispatched by `$38388`; this port keeps
them separate, same as the already-existing pay-troops flow):

- **Enlist** (`scripts/ui/enlist.gd`) — 1 credit/troop, capped so total
  troops can't exceed 20000. Input is a `SpinBox`, standing in for the
  original's digit-by-digit numeric-entry subroutine — same ultimate
  effect, not a byte-exact port of that subroutine. Genuinely
  surprising find confirmed directly from source: line 2290's
  `GOSUB 3000` means a successful enlist always continues straight into
  **Buy Weapons** (`scripts/ui/buy_weapons.gd`, `SHORE LEAVE.bas` lines
  3000-3110) before returning to the menu — not Repair/Restock, despite
  that other menu option's name; Repair/Restock's own flow never calls
  it. Buy Weapons steps through FIGHTERS/TRANSPORTS/TANKS/MISSILES in
  that fixed order, re-rolling each category's unit cost fresh
  (`INT((RND(1)+.2) * 4 * multiplier)`, multipliers 50/75/40/30),
  capped at 255 per category and gated on credits; entering 0 just
  moves on to the next category.
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
- **Cryogenics** (`scripts/ui/cryogenics.gd`) — a pure three-state
  toggle on `GameState.troop_location` ($38166: 0=aboard/awake,
  1=planetside, 2=paid shore leave, 3=cryo), exactly
  `SHORE LEAVE.bas` lines 4000-4020. Not actually gated on having a
  base in the original — `GROUND FORCES.bas` line 65's base check only
  covers menu options 3-6 (Shore Leave/Enlist/Sell Loot/Repair), and
  Cryogenics is option 8, so `ground_forces.gd` doesn't disable its
  button when `has_base` is false, matching the source. (An earlier
  version of this port's own doc comment cited the wrong source file
  for this screen — `GROUND FORCES.bas` lines 4000-4020, which is
  actually that file's unrelated stat-display subroutine; the real
  Cryogenics logic lives in `SHORE LEAVE.bas`.)
- **Repair/Restock** (`scripts/ui/repair_ship.gd`, `SHORE LEAVE.bas`
  lines 2500-2620) — twelve real ship-system health fields
  (`GameState.ship_shield`, `ship_energy`, etc.), driven generically by
  `GameState.REPAIR_LABELS`/`REPAIR_MULTIPLIERS`/`REPAIR_MAX_HEALTH` in
  the original's exact DATA order. Per-system cost is
  `INT(RND(1)*multiplier * (100-health))`; ENERGY alone caps at 63
  health instead of 100 (line 2524's distinct formula — independently
  confirmed by its own real starting value, see below). Genuine quirk
  kept as-is: every damaged system is repaired immediately on entering
  the screen, *before* the Y/N payment prompt — your ship gets fixed
  regardless of whether you can or choose to pay. A real consequence
  asymmetry is also preserved: being unable to afford the bill zeroes
  your credits entirely and angers the local government (un-secures
  the current planet); voluntarily declining a bill you could afford
  only angers the government, credits untouched; a 0-credit bill never
  triggers either even if declined. Skips the original's "YOU MUST
  LAND ON PLANET FIRST" gate (`$38210`/altitude aren't modeled) —
  reaching `ground_forces.tscn` at all already implies you're at this
  planet in this port's scene graph, same reasoning the other four
  Shore Leave screens use.

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

## COMPUTER sub-menu

The Command Console's "1) COMPUTER" option (`COM.bas` lines 200-280)
is real now instead of a stub, gated on `GameState.ship_computer`
(line 215's "COMPUTER NOT FUNCTIONING" if it's 0 — the same field
Repair/Restock models and ambient combat damage can zero out):

- **Navigation Computer** (`nav_computer.gd`) — Directory (same
  destination as the Central Computer's own "2) GALAXY DIRECTORY"
  button, confirmed the same in source too) and Set Course. Set Course
  is real data entry (sets `GameState.target_planet`, same 1-20
  range/"THAT'S WHERE WE ARE NOW" gate as the original's numeric-entry
  subroutine) but has no further mechanical effect in this port yet —
  the real source's separate hyperdrive-jump step that would later
  read `target_planet` (`H_D.bas`, run by the `H` key in flight — not
  wired in this port) doesn't exist here; `galaxy_map.gd` already
  collapses "pick a destination" and "arrive there" into one click, an
  architecture decision from well before this screen existed.
- **Galaxy Directory** (`galaxy_directory.gd`) — a system list, gated
  per-system on `GameState.planet_scouted` ("NO INFORMATION AVAILABLE"
  if unscouted). Found and fixed a real gap while tracing this:
  nothing had ever set `planet_scouted` to true anywhere — `H_D.bas`
  line 16 does it on arrival (`POKE 38240+target,1`), now ported in
  `galaxy_map.gd` alongside its other per-arrival resets. Genuine
  quirk kept as-is: the list's own "RETURN" goes to Navigation
  Computer's menu specifically (`COM.bas` line 969), regardless of
  which of the two real entry points you used to reach this screen.
- **Supplies Report** (`supply_report.gd`, `SUPPLY.bas`) — a real find
  while scoping this: it directly and unambiguously labels all
  thirteen loot categories by address, which turned out to disagree
  with `GameState.LOOT_LABELS`'s previous guesses at several indices
  (two of the three it claimed were "confirmed" were actually wrong —
  $38182 was labeled "food," it's really SILVER; $38183 was labeled
  "wine/liquor," it's really GOLD). Fixed the whole table from this
  screen's own source, including real per-category display units
  (`LOOT_UNIT_SCALE`/`LOOT_UNIT_NAMES` — e.g. Platinum displays as
  `loot[10] * 10` POUNDS). Tracing `COLLECT.bas` for the same fix
  also surfaced a real, previously-unported mechanic: a second loot
  collection within the same system visit gets cut to 60%
  (`$301`/`GameState.loot_collected_this_visit`, reset at the same
  arrival point as the label fix above) — now ported in `collect.gd`.
- **Galaxy Map** / **Ship Status** aliases — "3) GALAXY MAP" and
  "4) SHIP STATUS" just go to the already-real `galaxy_map.tscn`/
  `status.tscn`, exactly matching the original's own `RUN` targets.

Every sub-screen under this menu returns straight to the top-level
Command Console (`com.tscn`) on exit, never back to the Central
Computer menu itself — a real, consistent pattern in the source, not
a simplification.

## The shape-table viewer

Start screen → "Shape Data Viewer". `scripts/shape_view.gd` draws all
26 shapes of the game's one Applesoft shape table (`ENEMY`, loaded at
`$7FFF`) on a hi-res page, numbered as BASIC numbers them. LEFT/RIGHT
changes `ROT`, UP/DOWN changes `SCALE`, ESC goes back.
`scripts/contact_sheet.gd` writes the same sheet to a PNG headless
(`godot --headless --path . res://scenes/contact_sheet.tscn -- --out=sheet.png`).

`ENEMY` is an ordinary Applesoft shape table and is drawn by a port of
the ROM's `DRAW`/`XDRAW` (`scripts/shapes/shape_table.gd`). Earlier
versions of this project decoded it with an invented "custom" format
and also ran the `PLANET # N` and `SHIP # N` files through it; those
files are A2-3D1 data, not shape tables, and their JSONs are gone.

## Opening

Requires Godot 4.3+. `godot --path godot-remake` or open `project.godot`
from the editor's project manager; the project now boots to
`scenes/start.tscn`, with a button through to the shape viewer rather
than opening directly into it.

## Next steps

- **Re-entry should be live, interactive flight, not a static
  display.** Found 2026-11-09 while re-investigating "does a ship ever
  render during flight"): `RE.bas` doesn't show a 3-second terrain view and then
  return control — it resets ship position, BLOADs the real per-world
  terrain, sets `$38210=1` (atmosphere), and immediately hands back
  into the SAME live `STARSHIP SIMULATOR.bas` loop. You keep flying,
  now low over real terrain, with the exact same combat (ambient
  damage, the incoming-fire enemy, laser fire) still active. CORRECTION
  (2026-11-09): this bullet used to claim the manual's own cockpit
  screenshot (page 7/front cover) comes from this re-entry view — on a
  direct re-read of the manual, that's wrong. The screenshot's
  background is open starfield with no terrain at all, matching deep-
  space flight near a hostile system, not re-entry — see "Missile
  strike" above; it almost certainly shows the orbital defender
  (`ShipBlip`), consistent with the manual's own "Missile/Laser" and
  "Tactical Considerations" sections being about that exact ship.
  This port's `planet_approach.tscn` (a timed
  3-second display, `scripts/ui/planet_approach.gd`) doesn't match
  that shape at all. Fixing it properly means either merging it into
  `space_flight.tscn` with a terrain-swap and an "atmosphere" flag, or
  giving the flight scene its own atmosphere sub-state directly — a
  real redesign of that screen, not a quick patch, so it's recorded
  here rather than attempted inside the combat-gating fix that found
  it.
- Radar, flight's planet, re-entry, the Ship I.D. screen, and all five
  Shore Leave options are all real now (2026-11-07/09) — see
  "Radar"/"Re-entry"/"Ship I.D."/"Shore Leave" above. Also fixed
  project-wide: every pure-2D scene (this project has quite a few) was
  rendering against the engine's default gray clear color instead of
  black, since nothing had set one — `project.godot` now sets it
  globally. `GameState.orbital_defender_tier` was reworked here from a
  fixed-per-planet array to a value re-rolled per arrival; that was a
  mistake, reversed 2026-11-10 (it is per planet in the original, see
  "Radar" above). Repair/
  Restock and Buy Weapons are also real now (2026-11-09, see "Shore
  Leave" above), which closed out all six Shore Leave options and also
  surfaced the real starting values for several previously-placeholder
  `GameState` fields (troops/credits/stardate/fighters/transports/
  troop_location, all twelve ship-system health fields). Also traced
  `END.bas` (Command Console's "4) END") — not a mission-end/scoring
  sequence despite the name, it's Save/Continue/Quit — and added this
  port's first real persistence (`end_game.gd`,
  `GameState.save_to_disk()`/`load_from_disk()`, a Load Game option on
  the start screen) alongside it. Combat integration is also real now
  (2026-11-09, see "Flight combat" above) — ambient incoming
  damage, laser fire shared with ground-invasion surrender, orbital
  defender destruction, and player-ship destruction (`S_X.bas`, a new
  `player_destroyed.tscn`) are all wired into actual flight; Repair/
  Restock now has something that actually damages the fields it
  repairs. Left for later: a real "weapon fired" flag so the re-entry
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
- The Command Console's "COMPUTER" sub-menu is real now too
  (2026-11-09, see "COMPUTER sub-menu" above) — Navigation Computer,
  Galaxy Directory, Supplies Report, plus Galaxy Map/Ship Status
  aliases. Tracing it also fixed a real, previously-wrong
  `GameState.LOOT_LABELS` table (`SUPPLY.bas` unambiguously labels all
  thirteen categories by address; the old table had two of its three
  "confirmed" labels at the wrong indices) and added a previously-
  unported loot diminishing-returns mechanic (`COLLECT.bas` lines
  920-921). The "What's real vs. stubbed" table above is now fully
  real except End/scoring's own non-existence (there wasn't one — see
  "Shore Leave" above for what `END.bas` and
  `SHORE LEAVE.bas`'s "BUY WEAPONS" actually turned out to be instead).
  Sound is real now too (2026-11-09, see "Sound" above) — every real
  sound cue in the game reduces to exactly two machine-code routines
  (a laser sweep and a noise burst, confirmed from their disassembly),
  synthesized procedurally and wired into every real call site.
- ~~Hook the converted shape data up to actual sprites/meshes for the
  player's own ship and planet surfaces in the flight scene~~ —
  resolved (2026-11-09). The planet half was already done earlier in
  this same investigation (`space_flight.gd`'s `Planet` node has used
  real `PLANET # 0` data since the "Radar" work above — this bullet
  was just never updated).

  The "ship" half took two live-MAME passes to get right, and the
  first pass reached the wrong conclusion — worth recording exactly
  how, since it's a real methodology lesson for this investigation,
  not just a correction. Booted the real game and captured flight
  screenshots at SOL (the home planet, `current_planet=0`) on a fresh
  game: no ship ever appeared, across deep space, a real re-entry
  (`RE.bas`), manual `$7879`/`$7300` buffer pokes, and a full attitude
  sweep. That looked conclusive, so this file briefly claimed there
  was no ship-rendering gap at all. The user pushed back from direct
  memory of the game, which prompted finding the actual manual
  (`abandonware/.../Space Vikings/- Documenattion/space_vikings.pdf`,
  11 pages, sitting in the project's own abandonware archive) — its
  cover/Flight-Training screenshot shows a 3D ship silhouette directly
  in the cockpit view. Re-tested with that concretely in hand: `PEEK
  (38208)` ("surrendered") reads **true** at SOL from the moment a new
  game starts, confirmed live — because SOL is your home base, already
  "yours." The real combat gate (`STARSHIP SIMULATOR.bas` line 190:
  `IF PEEK(38208)=0 AND ... THEN GOSUB 3000: IF RND(1)<.5 AND
  PEEK(38207)>0 THEN GOSUB 5000`) requires it **false** — so every
  previous test, run at the one planet that structurally can never
  pass that gate, was guaranteed to show nothing no matter how long it
  ran or what was loaded into which buffer. Forced `$38208=0` for one
  more test and the real incoming-fire enemy sprite (`GOSUB 5000`)
  showed up immediately, fired back, and visibly reduced a real
  escort-fighter-count register (`$38207`) as the exchange continued —
  genuinely findable and shootable, exactly as described. See "Combat
  integration" above for what this port now does with that (the gate
  it was missing, the new `GameState.flight_escort_fighters` field,
  and the real architecture gap this same investigation surfaced:
  `RE.bas` is live interactive flight over real terrain, not the timed
  static display `planet_approach.tscn` currently is). This bullet's
  own "exactly as described" turned out to be only half the picture —
  a follow-up session (same day) found the real orbital-defender ship
  itself also renders in flight (`ShipBlip`) and is the target of a
  second, genuinely aimable weapon (missile strike); see "Radar"'s
  `ShipBlip` paragraph and "Missile strike" above.
- ~~Decide a real starting troop/transport count~~ — done (2026-11-09):
  traced both `START.bas`'s new-game MISC FILE write (line 2050:
  `PRINT 100.3: PRINT 2000: PRINT 10000`, i.e. real
  `stardate`/`troops`/`credits` = 100.3/2000/10000, not the old
  placeholders 0/50/1000) and the `SHIP'S DATA-M.payload.bin` binary
  blob `START.bas` BLOADs to $9506 (=38150, the base of the whole
  shared-register range) on every new game — real
  `gf_fighters`/`gf_transports` = 75/6 (not 0/10), plus all twelve
  Repair/Restock ship-system health fields' real starting values (see
  "Shore Leave" above) and a genuinely surprising one:
  `troop_location` really does start at 3 (cryo sleep), confirmed
  directly from the blob, not the 0 (awake aboard) this port assumed
  before.
