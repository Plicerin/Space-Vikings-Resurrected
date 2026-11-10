# Call-site catalog: GOSUB/CALL targets, their real mechanics, and port status

## Why this file exists

Repeated pattern across this project: a BASIC `GOSUB`/`CALL` (or a 6502
`JSR`) gets *noticed* during analysis, summarized in prose in one of the
`*_ANALYSIS.md` docs, and then the actual mechanics the callee implements
quietly don't make it into the Godot port — not because anyone decided to
skip them, but because prose analysis describes *findings*, not *every
call site*, so a call that wasn't the subject of that day's finding slips
through. Confirmed real instances before this file existed: the ship's
position/heading/throttle never got reset on a hyperdrive arrival (no call
site in `game_state.gd`'s reset function was checked against what
`H_D.bas` itself does on arrival); the invisible-sprite bug (a renderer
behavior under a call that *looked* already handled); the never-ported
hyperspace star-burst (a whole `GOSUB`'s visual effect with no Godot
counterpart at all, found only by reading the callee's body directly).

**The rule going forward:** before porting or auditing a scene, list every
real `GOSUB`/`CALL`/`JSR` the relevant BASIC/assembly reaches, and write
what each one *actually does* in pseudocode — not "it's the hyperdrive
scene," but the literal steps — then mark its port status. Prose analysis
docs (`FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md`, `GROUND_COMBAT_ANALYSIS.md`,
etc.) stay as the narrative layer; this file is the checklist layer
underneath them, call by call. Extend it as more files get this pass — it
does not need to cover all 21 `.bas` files before it's useful, and it
isn't a one-time audit: treat "trace every call site before porting" as a
standing habit, with this file as where the resulting pseudocode lives.

**Status legend:** ✅ ported faithfully · 🟡 ported with a documented
liberty · ⚠️ gap found by this pass, not yet fixed · ⬜ infrastructure,
no 1:1 port needed (Godot's own stack covers it) · ❓ mechanics unresolved
(needs more tracing or a live MAME check)

---

## STARSHIP SIMULATOR.bas — the main flight loop

Source: `detokenized/STARSHIP SIMULATOR.bas`. Port: `godot-remake/scripts/flight/{space_flight,ship_controller}.gd`, `scripts/combat/flight_combat.gd`.

| Line | Target | What it actually does | Status |
|---|---|---|---|
| 4 | `GOSUB 6600` ×3 | 16-bit sign-extend helper: combines a PEEKed low/high byte pair into a signed world-position component. | ⬜ Godot stores `ship_position` as a native `Vector3`; no byte-packing needed. |
| 31 | `GOSUB 6000` ×3 | Inverse of 6600 — splits a signed value back into low/high bytes for POKEing back to the position pointers. | ⬜ same reason. |
| 45 | `GOSUB 1500` | **Surrender check.** If the orbital defender's "fire" flag is up (`PEEK(38208)=0`) and in weapons range, rolls for taking a draw-the-laser-crosshair hit animation (lines 1500-1535), then accumulates damage into `$38160`(defender)/`$38152`(?) by `J1/J2` scaled by tech (`TE`); if accumulated damage crosses `$38150` (tech×60 threshold) prints "THE PLANET HAS SURRENDERED" and sets `38208=1`/`38219+planet=1`. | ✅ `flight_combat.gd`'s `defender_damage_points`/`defender_damage_threshold`/surrender text — confirmed in a prior session's MAME trace. |
| 47-48 | `GOSUB 3000` | **Ambient incoming-fire roll.** Only fires if `38205<>0` (a defender exists) or `38210=1` (actively hostile); further gated by position-box checks. Inside: ~40-60% chance of nothing, else a hit-flash VFX (`GOSUB 4110`/`4120` set draw mode, `CALL SG` plays a sound) and a `DMG=1` flag. | ✅ ambient damage in `flight_combat.gd`, confirmed earlier via live MAME. |
| 47-48 | `GOSUB 5000` (conditional, 50-60% within the 3000 branch) | **Missile-visual effect** — draws an incoming missile shape (`XDRAW M AT X1,Y1`) moving across the HUD from a random edge toward center, optionally triggering a hit-flash (`GOSUB 5098`/`5200`) if it's close to the ship's own reticle. | ✅ `missile_strike.gd` — this is the shape/flicker already confirmed authentic against `ENEMY` shape-table point counts. |
| 60-68 | `ON K GOSUB 311,312,313,314` | Speed nudge (±3/±15) from specific raw keycodes, after the 176-offset remap. | ✅ throttle input via `Input.get_axis` in `ship_controller.gd` — modern remap, not byte-exact, already documented as a liberty. |
| 69 | `CALL 38402` | TRANLIT's new-game dispatch entry (per `CATALOG_FINDINGS.md`'s own address table) — re-run on returning from an overlay. | ⬜ no Godot equivalent needed; scene re-entry is Godot's own job. |
| 70-91 | `GOSUB 1200`, `1100` (from `1085`/`1088`) | **Defender destruction sequence** — `1200`/`1220` draw an explosion flip-book (`XDRAW 2` at increasing `SCALE`, then `XDRAW 15-18`), `1100` is the smaller "hit, not destroyed" flash variant. | ✅ `flight_combat.gd`'s destruction VFX, built on the same `vector_shape_2d.gd` the zero-length-segment fix (2026-11-09) applies to. |
| 97 | `GOSUB 3380` (repeated ~8×, lines 99-103) | **Damage-floor clamp** — `IF J<0 THEN J=0:RETURN`, called once per repairable system after subtracting a random damage amount. Not a mechanic on its own, just a shared clamp. | ⬜ Godot's repair system (`repair_ship.gd`) already floors at 0 via `clampf`/`max`; no separate port needed. |
| 104-105 | (inline, not a call) | If hull (`38193`) hits exactly 0, `PRINT "RUNS/X"` — **ship destroyed, straight to the S/X ending**, no further flight. If `38393=0`, sets it and prints `RUNDMG` (damage-control overlay) once. | ❓ confirmed to exist in source; **not checked yet** whether `flight_combat.gd`'s `player_destroyed` signal fires specifically off hull reaching 0 the same way, or off some other accumulated-damage condition. Needs a direct read of `flight_combat.gd`'s destruction trigger against this exact line. |
| 111-126 | `GOSUB 5098`→`3205`, `5200`→`5250`→`1100` | Missile-effect sub-paths: a near-miss triggers a sound+hull-tick (`L=7:GOSUB3205` forces a hull-only damage roll), and (gated on `PEEK(38165)=3`, a mode flag) a full hit draws crosshair lines and, 30% of the time, recurses into the explosion sequence (`GOSUB 1100`) with the missile's own position as the detonation point. | ✅ matches `missile_strike.gd` + `flight_combat.gd`'s hit handling, per the already-confirmed authenticity note in `missile_strike.gd`. |

**Open items from this file:** the hull==0→`RUNS/X` destruction trigger (line 104) needs a direct check against `flight_combat.gd`'s own player-destroyed condition — flagged ❓, not fixed in this pass.

---

## H_D.bas — the hyperdrive jump itself

Source: `detokenized/H_D.bas`. Port: `godot-remake/scripts/ui/hyperspace.gd`, `scripts/ui/galaxy_map.gd`'s arrival callback.

| Line | Target/branch | What it actually does | Status |
|---|---|---|---|
| 2 | (inline) | **Abort gate.** If `38210=1` (actively in combat) OR `38209=38163` (target equals current planet) OR `38163=0` (no course set at all) → `RUN STARSHIP SIMULATOR` instead, i.e. the jump never happens. | ⚠️ **gap.** Nothing in the Godot port enforces any of these three — `galaxy_map.gd`'s callback unconditionally starts the hyperspace sequence for whatever was clicked, including re-clicking the current system. |
| 2-5 | (inline) | **Energy gate.** If ship energy (`PEEK(38199)`) is exactly 0: prints "OUT OF ENERGY" / "ORBIT DECAYING", then `PRINT "RUN S/X"` — **the jump destroys the ship** (`S_X.bas` is the ship-destroyed ending: explosion animation, "YOUR SHIP HAS BEEN DESTROYED!!", reboot). Otherwise falls through to line 5. | ⚠️ **gap, confirmed real.** `ship_energy` already exists in `GameState` (used by the repair system) but nothing gates a jump on it, and there's no zero-energy failure path wired to `player_destroyed.tscn`. |
| 6 | `GOSUB 10000` | **Jump cost.** Computes `D1` = a "distance" between current and target planet, then: opens/rereads/rewrites a save-state block advancing `SD` (stardate) by `D1+0.3`, and at line 14, `P = PEEK(38199) - D1` — **energy is spent proportional to the computed distance.** The distance formula itself (line 10010) is written identically for all three axes — `X1=Y1=Z1 = ABS(PEEK(38366+current)) - ABS(PEEK(38366+target))` — i.e. it only ever reads the *X*-position byte array (`$38366+planet_index`), never the real Y/Z blocks `GALAXY MAP.bas` uses at offsets `-21`/`-42` from the same base. This reads as a genuine formula bug in the original (always `D1 = sqrt(3)·|ΔX|`, not a true 3D distance) — faithful porting means keeping that quirk, not "fixing" it to real 3D distance. | ⚠️ **gap, not yet ported** (no energy/stardate cost on any jump today) — **and blocked on real data**: the per-planet X-position byte array at `$38366+n` was checked against `extracted/PLANET FILE.payload.bin` directly (offsets 147-166 for n=1..20) and came back as a suspiciously regular 4-value repeating pattern (`1,1,255,255` cycling) rather than distinct per-system values — more consistent with an unrandomized master-template default than real per-game galaxy layout. Don't hardcode these as real coordinates without resolving that; see note below. |
| 11 | (inline) | `IF PEEK(38166)=0 OR 3 THEN POKE 38158,PEEK(38163)` — updates "last planet troops are on" tracking only if troops are aboard or in cryo (not mid-transit). | ✅ already the basis of `GameState.troops_stationed_at`, confirmed in the 2026-11-09 troop-tracking fix. |
| 12 | `CALL 38825` | Opaque machine-code "per-ship init" (per `CATALOG_FINDINGS.md`'s address table, `$97C9`) — re-run once for the *old* planet (`PEEK(38163)` mode 0 at line 19) and once implicitly for the new one. Not resolved byte-for-byte; the disassembly dumps checked don't cover this address as executable (`disassembly/TRANLIT.OBJ0.disasm.txt` truncates well before it). | ❓ unresolved — flagged, not blocking: nothing currently observable in BASIC depends on its *side effects* beyond what's already modeled (ship sprite selection, below). |
| 12-13 | (inline) | Landing-morale decrement (`$38170=17` flag → troop morale −1). | ✅ already confirmed and ported — see `FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md`'s "Landing and the troop-morale mechanic" section. |
| 16 | (inline) | `POKE 38240+PEEK(38163),1` — marks the destination scouted. | ✅ `GameState.planet_scouted[index] = true`, `galaxy_map.gd`. |
| 18, 20 | `CALL NOISE` ×250, then ×175 inside the star-burst loop | Continuous engine-whine sound during the "clearing" pause and during the star-burst draw. | 🟡 intentionally silent — `AudioManager` has no continuous-whine cue yet; documented liberty in `hyperspace.gd`. |
| 20 | (inline, the star-burst itself) | 175 lines from screen-center to random points, accumulating, never erased. | ✅ ported 2026-11-09 as the real star-burst — this was the single biggest "entirely unported mechanic" finding before this pass. |
| 25, 30-40 | `CALL 38825` (mode 1, new planet), then the `ET=PEEK(38205)` ship-sprite-select branch | Picks which `SHIP # n` (or `DEBRIS`, or blank) to load for the arrival view, based on `$38205`'s current value — **reads it, never writes a fresh random value here or anywhere else in BASIC** (confirmed again by this pass's own grep — the only write anywhere in `detokenized/*.bas` is `EX.bas`'s `POKE 38205,0` after a destruction). `ET=2` is specifically remapped to load `SHIP # 3`'s art (a real, consistently-applied quirk — the same `IF J=2 THEN J=3` substitution also appears verbatim in `START.bas` line 230 and `ORBIT.bas` line 31, so it's a real convention, not a one-off). | 🟡 **already correctly handled** — `game_state.gd`'s own doc comment for `orbital_defender_tier` independently reached the same conclusion (single transient global, no per-planet array, real set-site unreachable in available disassembly) and documents re-rolling on travel as a deliberate, flagged liberty. The `ET=2→SHIP#3` remap is captured in `a2_3d1_model.gd`'s tier handling — not re-verified line-by-line in this pass, worth a quick confirm but not flagged as broken. |
| 90, 93 | (inline) | Tech-gated threshold reset (`TECH<2` → no threat; else `38150`/`38204` = tech×60). | ✅ `galaxy_map.gd`'s arrival callback, already ported (and already noted there as moved from ground-forces to arrival-time to match this). |
| 53-56 | `GOSUB 10000` body | See line 6 above — same routine. | (see above) |

**Open items from this file:** the abort-gate (line 2) and energy-gate/jump-cost (lines 2-6) are real, currently entirely unported mechanics — not implemented in this pass pending the per-planet-position data question and a product call on whether a run-ending failure mode belongs in the port as-is. See summary below.

---

## GALAXY MAP.bas — the star-chart screen

Source: `detokenized/GALAXY MAP.bas`. Port: `godot-remake/scripts/ui/galaxy_map.gd`.

**Headline finding, not a call-site table entry:** this screen is real, and
it is *not* what `galaxy_map.gd` currently is. The actual `GALAXY MAP.bas`
is a non-committal info browser — move a paddle-controlled cursor over a
2D star chart (`DRAW PL AT X,Y` per system, `X=X(P)*10, Y=Y(P)*5` from the
real per-planet position array), press a button near a system to see its
name/coordinates/distance-from-here (`GOSUB 3300`: real 3D Euclidean
distance, using the *correct* Y/Z blocks — contrast with `H_D.bas`'s own
buggy X-only version above), then optionally jump to its full directory
page (`COM.bas` line 978 territory). **It never sets a course or travels
anywhere.** Setting a course is `COM.bas`'s separate "NAVIGATION
COMPUTER → SET COURSE" numeric-entry screen (see below); actually
traveling is a *third*, still-unresolved step (a specific in-flight key
press reaching `H_D.bas`, gated on a course being set and not being in
combat).

| Line | Target | What it actually does | Status |
|---|---|---|---|
| 2 | `GOSUB 5000` | Redraws the Instruments HUD icon row (repair-state indicators) before handing off — pure visual, not gameplay. | ⬜ Godot's HUD updates reactively; no port needed. |
| 7-18 | (inline) | Real per-system chart: `X(P)/Y(P)/Z(P)` from `$38366` ±21/42 offsets, icon choice by `Z(P)` banding, a highlight box around the current system (`P=PEEK(38209)`), a filled marker for secured systems (`PEEK(38219+P)=1`). | ⚠️ **not ported** — `galaxy_map.gd` is a plain button list, explicitly flagged as such in its own doc comment ("not ported yet, this is list-selection only") from before this pass; this pass didn't change that, just confirmed the real screen's actual mechanics for whenever it is. |
| 37 | `GOSUB 3300` | Real 3D distance from the *current* system to the one under the cursor, for display only. | ⚠️ not ported (no distance display exists at all today). |
| 38 | (inline) | "Y" to further-info → `POKE 38388,P` (store the picked index) + `PRINT "RUN COM"` — hands off to the Galaxy *Directory* page, **not** a travel trigger. | 🟡 `galaxy_map.gd`'s current click-to-travel behavior is a deliberate simplification already flagged in `nav_computer.gd`'s own doc comment (quoted above) — this pass independently confirms that's the real divergence, not a new one. |

---

## COM.bas — the command console hub

Source: `detokenized/COM.bas`. Port: `godot-remake/scripts/ui/{com,central_computer,nav_computer,galaxy_directory}.gd`.

| Line | Target | What it actually does | Status |
|---|---|---|---|
| 5 | `GOSUB 15100` | Loads the 20 star names into `S$()`. | ✅ `GameState.STAR_NAMES`, static data, no runtime call needed. |
| 5 | (inline, `IF PEEK(38388)>0`) | If arriving with a stored directory-page index (set by Galaxy Map's "further info" or by Radar's own ship-ID flow), jump straight to that page instead of the top menu. | ❓ not checked against `com.gd`'s own scene-entry logic in this pass — worth a quick confirm, not flagged broken. |
| 14-15 | `GOSUB 10000` (inside the status-row draw loop) | Per-row flicker/dim logic for the twelve repair-status readouts, keyed on whether the system is the current selection row (`J1=7`) and its live value. Pure display polish. | ⬜ no 1:1 port needed — `repair_ship.gd`'s UI redraws reactively. |
| 40 | `ON C GOTO 800,900,30,1200,20000` | Central Computer menu dispatch: 1 Navigation, 2 Galaxy Directory, 3 Galaxy Map (via a `GOSUB 3000` two lines up, not this dispatch), 4 Ship Status, 5 Supplies. | ✅ `central_computer.gd`'s own menu buttons. |
| 860-897 | (inline, "SET COURSE") | Numeric destination entry (1-20), rejects the current planet ("THAT'S WHERE WE ARE NOW, SIR!"), otherwise `POKE 38163,C` and prints "COURSE SET." **Does not travel.** | 🟡 ported faithfully as data-entry-only in `nav_computer.gd` (`GameState.target_planet = dest`) — already correctly flagged by that script's own doc comment as not yet connected to an actual travel trigger, independently reconfirmed by this pass. |
| 1005-1170 | (inline, Galaxy Directory detail page) | Per-system info: tech-level text, population (`PEEK(38261+C)*35294`), secured/independent status, repair-base presence. | ✅ `galaxy_directory.gd`, not re-audited line-by-line in this pass but no discrepancy surfaced. |

**Net finding for this file:** confirms, independently of `nav_computer.gd`'s
own prior self-assessment, that the real navigation chain is **Navigation
Computer (set course, no travel) → [unresolved in-flight key] → H_D.bas
(energy/abort-gated jump, real cost) → arrival**, a three-stage process
the current port collapses into Galaxy Map's single click. This was
already honestly flagged as a liberty before this pass; what's new here is
confirming *why* that liberty was taken (the actual trigger key was never
identified) and finding the specific line (`STARSHIP SIMULATOR.bas` line
209, `IF K=24 THEN PRINT "RUNH/D"`) that's supposed to be it.

---

## GROUND FORCES.bas

Already has deep line-by-line coverage in `GROUND_COMBAT_ANALYSIS.md` and
`FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md` (landing/morale section) —
not re-walked call-by-call in this pass to avoid duplicating existing,
already-correct work. Flagged here only so this file's index is honest
about what it does and doesn't cover yet.

---

## Summary: what this pass actually changes vs. what it just surfaces

**Not fixed in this pass (flagged for a decision, not silently shipped):**

1. **Hyperdrive abort/energy gates (`H_D.bas` lines 2-6) are entirely
   unported.** Right now every Galaxy Map click travels unconditionally —
   no check for "already here," no check for "in combat," and no energy
   cost or zero-energy failure state. The zero-energy case is a real
   ship-destroyed ending (`S_X.bas` → the port's existing
   `player_destroyed.tscn`), so this is a genuine difficulty/stakes
   mechanic missing from the port, not a cosmetic gap.
2. **The real in-flight hyperdrive trigger key is still unidentified.**
   Hand-tracing `STARSHIP SIMULATOR.bas`'s key-dispatch block (lines
   200-210) against the literal `IF K=24 THEN PRINT "RUNH/D"` check at
   line 209 suggests that check may be unreachable given how `K` gets
   reduced/redirected earlier in the same block — but this is exactly the
   kind of thing that's unsafe to conclude by hand from 8-bit control
   flow alone. Needs a live MAME key-sweep (same technique already used
   this project for the ship-blip cadence and missile timing) rather than
   further manual tracing.
3. **The real per-planet position data (`$38366` ±21/±42 byte arrays,
   used by both `GALAXY MAP.bas`'s real distance display and `H_D.bas`'s
   buggy jump-cost formula) doesn't check out as plausible real galaxy
   coordinates** when read directly from `extracted/PLANET FILE.payload.bin`
   at the expected offsets — a 4-value repeating pattern, not 20 distinct
   positions. Either the offset math here is off by something not yet
   found, or (more likely, consistent with this project's established
   pattern for `$38205`) the live block gets further mutated by machine
   code at new-game time from this master template, unresolved in
   available disassembly. Don't hardcode these bytes as real coordinates.
4. **`GALAXY MAP.bas`'s actual screen (2D star chart with cursor,
   distance display, no travel) is still not what `galaxy_map.gd` is** —
   already known and flagged before this pass, reconfirmed, not rebuilt
   here since it's a real UX/architecture decision (collapse vs. honor
   the three-stage original flow), not a bug.

**Confirmed correct in this pass (no action needed):** the surrender
check, ambient incoming fire, missile visual, defender destruction
sequence, landing-morale decrement, troop-location tracking, scouted-flag
write, tech-gated threshold reset, and the orbital-defender-tier
re-roll-on-travel liberty (`game_state.gd` had already independently
reached the same conclusion this pass did, for the same reason — real
set-site unreachable in available disassembly).

**One unresolved ❓, not a gap by itself:** whether `flight_combat.gd`'s
player-destruction trigger matches `STARSHIP SIMULATOR.bas` line 104's
`hull==0 → RUNS/X` condition exactly, or uses a different accumulated
condition. Worth a direct comparison next time that file is touched.
