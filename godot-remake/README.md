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
| Combat VFX: fighter approach/retreat/explosion, laser beam, EX.bas ship destruction, incoming-fire pattern | Real — see "Combat VFX" below | `COMBAT_VFX_ANALYSIS.md` |
| Combat integration (ambient incoming damage, laser fire, orbital defender destruction, player ship destruction) | Real — `scripts/flight/flight_combat.gd`, wired into `space_flight.tscn`; see "Combat integration" below | `COMBAT_VFX_ANALYSIS.md` |

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
  decoupled from the visual) now plays via `AudioManager.play_laser()` —
  see "Sound" below.
- **Ship destruction** (`ship_destruction.gd`): `EX.bas`'s bigger
  screen-centered version of the same flash+debris, plus a genuine
  radiating-line particle burst, plus persistent (stand-in) wreckage —
  now wired to a real trigger, see "Combat integration" below.
- **Incoming fire** (`incoming_fire.gd`): the separate generic
  shape-crosses-the-screen pattern, lines 5000-5251, now spawning on
  its own real independent roll and with its own real shootdown
  sub-mechanic (see "Combat integration" below). Also fixed
  2026-11-09: this port originally hardcoded shape index 2 for the
  whole pattern — wrong. The real source's own shape pick (lines
  5050-5080) depends on which third of the screen the spawn point
  falls in: the right third draws shape **9** (23 real path commands,
  genuinely detailed); the other two both draw shapes **10**/**8**
  (2 commands each, a near-invisible dash — same "odd=detailed,
  even=blank" pattern already confirmed in `fighter_encounter.gd`'s
  own doc comment). Shape 2 was never one of these three.

All four remain reachable standalone from the Start screen's "Combat
VFX Demo" button. Ship Destruction and Incoming Fire are now also
wired into real flight (see "Combat integration" below); the Fighter
Encounter minigame and the Laser Beam cockpit-corner visual specifically
are not yet — see that section for why.

## Combat integration

`scripts/flight/flight_combat.gd`, wired into `space_flight.tscn`'s HUD
layer, ports `STARSHIP SIMULATOR.bas`'s three real combat mechanisms.

**Combat gate** (lines 189/190/192, `_is_combat_eligible()`): current
planet's tech >= 2, the planet NOT surrendered
(`GameState.gf_planet_surrendered`), and an orbital defender present
within range (`orbital_defender_tier != 0` and `COMBAT_RANGE` of the
planet — a liberty standing in for the original's landed-OR-bounding-
box test, since this port's flight scene has no "landed" sub-state).
The surrendered check was missing until 2026-11-09, found by a live
MAME investigation driven by the user pushing back on an earlier wrong
conclusion here — see "Next steps" below for the full story. Without
it, this port's combat could never fire at all, since every automated
test happens to start at the one planet (SOL, the home base) where
`gf_planet_surrendered` is genuinely true from the first frame of a
new game.

- **Ambient incoming damage** (lines 3000-3381, "GOSUB 3000") — runs
  on a tuned timer (the original rolls this every main-loop pass; a
  real-time per-frame roll would land damage far faster than BASIC's
  own effective frame rate, so this is tuned to feel similarly
  occasional rather than ported byte-exact). Per-hit formula is a
  literal port: two independent 40%-chance rolls plus an independent
  30%-chance roll can land a hit; SHIELD drains first, and only
  cascades to RADAR/engines/COMPUTER/LASER/HULL once the shield is
  empty (`$38201`, "shields up," is never toggled anywhere in the
  available BASIC source, so this port treats it as permanently true
  rather than modeling a switch that doesn't exist). HULL reaching 0
  triggers `S_X.bas` — a new screen, `scenes/player_destroyed.tscn`,
  a literal port of its expanding radial-burst algorithm (`X1=5 TO 130
  STEP 8`, 15 random lines per step) plus its exact text. The original
  then `PR#6`s (reboots from the disk's boot sector) after two
  keypresses; this port's closest real equivalent is returning to the
  start screen on any key or Continue.
- **The incoming-fire enemy sprite** (lines 190/192/5000-5251,
  "GOSUB 5000") — this is the actual "findable, shootable ship" the
  Flight Training manual page shows directly in the cockpit view (see
  "Next steps"). Now spawns on its own real independent roll (60%,
  same tick as the ambient check above), gated on
  `GameState.flight_escort_fighters > 0` — a real register confirmed
  live (starts at 30, never written anywhere in BASIC, so like
  `$38205` it must be a machine-code default this port can only match,
  not derive). Its own internal shootdown sub-mechanic (lines
  5200-5251) is ported too: firing a tracer (`incoming_fire.gd`'s
  `tracer_fired` signal) rolls a 30% chance to intercept the raider,
  decrementing `flight_escort_fighters` by 1 and `ship_missile_system`
  by 2 — simplified from the source, which additionally gates this on
  an unresolved status register (`$38165`) this port treats as
  always-eligible instead.
- **Laser fire** (lines 185/1500-1570, "GOSUB 1500") — firing while
  the current planet is already surrendered re-arms its resistance
  instead of doing nothing (line 1500's own quirk, now ported); gated
  on LASER health > 0, always adds to `GameState.gf_victory_progress`
  (the SAME ground-invasion-surrender counter `GROUND FORCES.bas`
  uses — firing from orbit genuinely helps soften a planet toward
  surrender before you ever reach Ground Forces) and to
  `defender_damage_points`/`defender_damage_threshold` (toward
  destroying the current orbital defender ship, `EX.bas` — which also
  halves `flight_escort_fighters`, line 56, now ported). Neither is
  gated on proximity — the original checks the fire button every
  main-loop pass regardless of position, so firing always "counts"
  against whatever system you're currently at.

Found and fixed three real pre-existing gaps while wiring this in:
- `gf_planet_surrendered` defaulted to `false` in this port; the real
  value at new-game start is `true` (confirmed live — SOL,
  `current_planet=0`, is your home base, already "yours"). This was
  the actual root cause of combat never firing in testing, not a
  missing feature.
- `gf_enemy_strength`/`defender_damage_threshold`/`gf_victory_progress`
  reset at system arrival in the real source (`H_D.bas` lines 90-93),
  not at the start of a ground attack — moved from
  `ground_forces.gd`'s `_on_attack_pressed()` to `galaxy_map.gd`'s
  system-selection callback (this port's arrival-equivalent).
  `ground_forces.gd` was also zeroing `gf_victory_progress` on every
  Attack press, which would have silently erased any progress flight
  combat had already made toward the same shared counter.

Not yet wired in, documented rather than silently dropped:
- The two-fighter approach minigame's real trigger (`$38202`, line
  1501). That register is never written anywhere in the available
  BASIC source — unlike `$38205`/`$38207` (both confirmed real and
  load-bearing by live testing), there's no confident analog trigger
  point to port it to yet. `fighter_encounter.gd` stays reachable only
  from the dev-tool Combat VFX Demo for now.
- A proper live, interactive re-entry — see "Next steps" below;
  `RE.bas` turns out not to be a static display at all.

**The orbital defender's own 3D model, rendered in flight next to the
planet** — distinct from everything above. The incoming-fire sprite
resolved earlier (previous bullet list, and the "Next steps" entry
below) is a small raider that crosses the screen and fires tracers;
the user explicitly disambiguated it from *this*, a separate "large
ship in orbit around the planet... it is the ship you see on the
radar" — i.e. the actual `SHIP # N` A2-3D1 model (`GameState.
orbital_defender_tier`), already correctly rendered on the radar
screen (see "Radar" below) but, until now, nowhere in the flight scene
itself. Confirmed live in MAME 2026-11-09 with a genuine hyperdrive
jump (earlier jump tests had silently no-op'd from an off-by-one bug
in the test script itself — the real game is 1-indexed, `S$(1)="SOL"`
— so they never actually left SOL; fixed, then re-run: `current_planet`
genuinely went 1→2 and `orbital_defender_tier` organically changed
3→2 on arrival). Post-jump screenshots show a compact, solid
silhouette near the horizon, absent at SOL and absent during the warp
transit itself — and ruled out as just this scene's own `Planet` node
by checking `PLANET # 0`'s raw data directly: it's a genuine but
*sparse* 195-point field spanning a ±10000-unit volume, which would
read as scattered dots across a wide area, not one small dense blob.
Wired in as `ShipBlip` (`space_flight.tscn`/`space_flight.gd`), reusing
the same `A2_3D1_Model.build_ship_mesh(tier)` the radar screen already
uses, in a slow orbit around the planet; rebuilds itself whenever
`orbital_defender_tier` changes mid-flight (e.g. destroying the
defender) rather than only once at scene load.

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

Wired into every real call site found by grepping the source for
`CALL SG`/`CALL LA`/`CALL NOISE`/`CALL EX`: `laser_beam.gd` and
`flight_combat.gd`'s own `fire_laser()` (the laser sweep — both play
it, since one is the cockpit visual and the other is the actual flight
mechanic, not yet wired to each other — see "Combat integration"
above), `flight_combat.gd`'s ambient damage tick (light/medium presets
per branch, same as the source calling both independently),
`incoming_fire.gd`'s tracer fire (light), `fighter_encounter.gd`'s
approach start and `fighter_slot.gd`'s retreat/explosion (medium —
all three are bare `CALL SG` sites with no preceding `GOSUB 4100/4110/
4120`, so this port just picks MEDIUM for all of them rather than
tracking real leftover state), `ship_destruction.gd` (EX.bas's
explosion), and `player_destroyed.gd` (S_X.bas's destruction — the
longest burst in the game).

Not wired, documented rather than silently dropped: `H_D.bas`'s own
~426-call noise burst during a hyperdrive jump (lines 17-20, the
"warp" sequence) — this port's `galaxy_map.gd` doesn't have a visual
counterpart for that sequence (travel is instant), so adding just the
sound without anything on screen to tie it to would likely read as a
stray, unexplained noise rather than an actual warp effect. Also not
ported: the simpler incoming-fire pattern's own internal
random-shootdown sub-mechanic's sound (line 5230, part of the
already-deferred 5200-5251 mechanic — see "Combat integration" above).

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
  from the real `SHIP no N I.D..bas` text. The original's `$38205` is a
  single transient global register, never once assigned a nonzero
  value anywhere in the detokenized BASIC source (exhaustively
  grepped, 2026-11-09) — only read (`H_D.bas`, `ORBIT.bas`,
  `RADAR.bas`) and reset to 0 after an encounter (`EX.bas`). It must be
  set by machine code the available linear disassembly dumps don't
  resolve either. This port can't reproduce the real trigger point or
  odds, but it does now match the real *shape* of the state — a single
  current-system value, re-rolled by `galaxy_map.gd` on each system
  selection (its closest analog to a hyperdrive jump) — rather than its
  previous shape, a fixed tier picked per planet at new-game time and
  held for the whole game, which was wrong in a way the real source
  rules out directly (a per-planet array implies a persisted property;
  `$38205` demonstrably isn't one).
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
  read `target_planet` (`H_D.bas`, triggered by an in-flight key this
  port hasn't identified) doesn't exist here; `galaxy_map.gd` already
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

- **Re-entry should be live, interactive flight, not a static
  display.** Found 2026-11-09 while re-investigating "does a ship ever
  render during flight" (see "Combat integration" above for the full
  story): `RE.bas` doesn't show a 3-second terrain view and then
  return control — it resets ship position, BLOADs the real per-world
  terrain, sets `$38210=1` (atmosphere), and immediately hands back
  into the SAME live `STARSHIP SIMULATOR.bas` loop. You keep flying,
  now low over real terrain, with the exact same combat (ambient
  damage, the incoming-fire enemy, laser fire) still active — this is
  genuinely where the manual's own cockpit screenshot comes from, not
  a separate mode. This port's `planet_approach.tscn` (a timed
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
  globally. Also reworked `GameState.orbital_defender_tier` from a
  fixed-per-planet array to a transient global re-rolled per system
  arrival, matching the real `$38205`'s actual shape (see "Radar"
  above) — its real trigger point and odds are still unresolved (not
  in BASIC, and not in the available disassembly either). Repair/
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
  (2026-11-09, see "Combat integration" above) — ambient incoming
  damage, laser fire shared with ground-invasion surrender, orbital
  defender destruction, and player-ship destruction (`S_X.bas`, a new
  `player_destroyed.tscn`) are all wired into actual flight; Repair/
  Restock now has something that actually damages the fields it
  repairs. Left for later: a real "weapon fired" flag so the re-entry
  trigger can port the original's full condition instead of proximity
  alone, and the two items noted as deliberately not-yet-wired at the
  end of "Combat integration" above.
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
  "Combat integration"/"Shore Leave" above for what `END.bas` and
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
  static display `planet_approach.tscn` currently is).
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
