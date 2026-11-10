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

## 6502/DOS asm-level call tricks — mechanisms the surface syntax hides

Everything above still only covers Applesoft's own explicit call
keywords (`GOSUB`, `CALL`, `ON...GOTO`). This pass went looking
specifically for calls that *aren't spelled that way* — the kind of
thing a 1MHz 6502 running a real-time flight loop has every reason to
use instead of a generic call: no spare cycles for "dispatch on type"
when a raw memory convention does the same job for free. Found three,
and they explain several things the rest of this file had marked ❓.

### 1. `PRINT CHR$(4)"<cmd>"` — DOS 3.3 command injection as a chain-load "call"

Every line in every `.bas` file that looks like `PRINT "RUNCOM"` or
`PRINT "RUNH/D"` is not a debug print. Hexdumping the raw bytes (not
just reading the detokenized text) shows each one actually starts with
an invisible `\004` byte — Ctrl-D — that the detokenizer preserved
faithfully but that renders as *nothing* in a terminal, an editor, or
a plain-text read of the file:

```
$ sed -n '58p' "STARSHIP SIMULATOR.bas" | od -c
...  "  004   R   U   N   H   /   D   "
```

`CHR$(4)` is DOS 3.3's own command-prefix byte. Printing it mid-stream
hands the rest of that line to DOS's command interpreter instead of
the screen — `PRINT CHR$(4)"RUN COM"` really does **chain-load and run
`COM.bas`**, exactly like typing `RUN COM` at the DOS prompt by hand
(DOS 3.3 doesn't require a space between a command word and its
argument, so `"RUNCOM"` and `"RUN COM"` are the same command). Every
`BLOAD`, `BSAVE`, `OPEN`/`WRITE`/`CLOSE MISC FILE`, and the identical
`PRINT CHR$(4)"INT"` that ends *every single `.bas` file at line
63999* (DOS's "drop to interactive BASIC on any runtime error" trap)
all go through this exact convention. None of it is a real Applesoft
statement underneath — it's BASIC code typing at DOS through the
character-output hook, disguised as print statements. A line-by-line
read that doesn't know this convention misreads every one of these as
inert text, which is exactly how `H_D.bas`'s own star-burst went
unnoticed for so long, and exactly what's going on with line 209
below.

**This is the real scene-transition graph** — nothing in Applesoft's
own `GOTO`/`GOSUB` reaches across file boundaries, so this hidden
chain-load convention *is* the entire state machine the game runs on.
Extracted mechanically from every file's hidden-byte strings, the two
hubs:

| From | `RUN`s to |
|---|---|
| `STARSHIP SIMULATOR.bas` (main flight) | `RE` (re-entry, 156), `ORBIT` (158), `H/D` (209 — **see below, unreachable**), `COM` (319), `RADAR` (320), `EX` (explosion/destroyed, 1560), `S/X` (ship destroyed, 3350), `DMG` (damage-control overlay, 3360) |
| `COM.bas` (command console hub) | `GROUND FORCES` (98/115/127), `STARSHIP SIMULATOR` (130), `END` (132), `RADAR` (133), `GALAXY MAP` (1172/3000), `STATUS` (1200), `SUPPLY` (20000) |

Plus a ground-campaign loop (`GROUND FORCES` ↔ `COLLECT`/`RECALL`/
`SHORE LEAVE`), a boot chain (`START` → `INSTRUMENTS` → `STARSHIP
SIMULATOR`), and `GALAXY MAP`/`RADAR`/`H_D` each chaining back to
`COM`/`STARSHIP SIMULATOR` on exit. This is infrastructure Godot's own
scene tree already replaces 1:1 (`GameState.goto_scene`) — ⬜, no
action needed — but it's worth having the real graph written down once
rather than re-deriving it piecemeal per file.

**Resolves the H_D.bas trigger-key question with much higher
confidence than the earlier hand-trace** (previously ❓ in this file):
line 209's `PRINT CHR$(4)"RUNH/D"` is real, working chain-load code,
not dead text — but it's still unreachable in practice. Tracing the
*entire* key-dispatch block (`STARSHIP SIMULATOR.bas` lines 200-210,
traced exhaustively this time, not just spot-checked around line 209)
end to end:

```
K = raw keycode (PEEK(-16384), high bit set, 128-255) or exit if no key
IF K-176 > 0:                        # digit keys 1-9 after the +128/+176 offset
    K -= 176; clear keyboard strobe
    ON K GOSUB [throttle -3,+3,-15,+15][K]   # only K=1..4 valid, else no-op
IF K < 17: GOTO clamp                # (reduced K from above, or raw K<17 — never happens, raw is >=128)
ON K-16 GOTO ['A'->mode4, 'B'->mode3, 'C'->RUN COM][K-16]   # K=17,18,19 only
IF K < 34: GOTO clamp                # <-- catches K=20..33 UNCONDITIONALLY
IF K == 39: POKE LT,2: CALL TRANLIT  # 'W'
ON K-33 GOTO ['S'->mode1, (nothing)][K-33]
clamp:
IF K == 24: PRINT CHR$(4)"RUNH/D"    # <-- K=24 is 'H' (176+24=200=ASCII 72), but
                                      #     K=24 satisfies "K<34" two lines above,
                                      #     so execution already left for `clamp`
                                      #     before this line is ever reached.
```

'H' (K=24) always gets intercepted by the `IF K<34 THEN 207` guard
several lines *before* reaching the `IF K=24` check — this is a
genuine shipped bug in the original, not an unidentified-but-working
key: **the hyperdrive in-flight trigger key is dead code in the real
game.** That also means the Godot port's current choice to have *no*
flight-triggered hyperdrive key at all (`space_flight.gd`'s
`_unhandled_input` wires `C`→Command Console and `R`→Radar, matching
the two live `ON K-16 GOTO`/`ON K-33 GOTO` targets exactly, and
nothing for hyperdrive) is **already the faithful port**, not a gap —
confirmed checked against `space_flight.gd` this pass. Worth one live
MAME keypress sweep to rule out an interrupt-driven secondary key
reader this static trace can't see, but confidence is now high, not
speculative. Downgrade this item from "needs a live MAME check" to
"nice-to-have confirmation, not blocking."

### 2. `POKE 38167,n` (`LT`) then `CALL 38402` — one fixed address standing in for up to 6 real routines

`CALL 38402` always jumps to the same machine address
(`TRANLIT.OBJ0`'s entry point, confirmed via Ghidra decompile). What it
actually *does* depends entirely on two bytes BASIC pokes first — the
call address never changes; the "which function" selection happens
through shared memory, which is the part a reader tracking only
`CALL`/`GOSUB` targets will never see:

```
TRANLIT_DISPATCH():                      # CALL 38402/38400, always this one address
    if PEEK(38189) == 10:                # one-time cold-init sentinel ('\n')
        POKE 38189, 0                    # self-clearing, so it only fires once
        mode1(); mode2(); mode3(); mode4(); mode5(); mode6()   # run the whole chain
        return
    mode = PEEK(38167)                   # LT -- the real "argument"
    next = mode
    if next == 1: next = mode1()         # FUN_9643, may chain into mode2
    if next == 2: next = mode2()         # FUN_966a, may chain into mode3
    if next == 3: next = mode3()         # FUN_96a5, may chain into mode4
    if next == 4: mode4()                # FUN_96df, terminal, no further chain
```

Each `modeN()` toggles a small flag byte of its own (`$9539`, `$953A`,
`$9515` — 3-valued, `$9514`) and calls a shared 5-byte table-copy
routine (`FUN_9754`) with a small constant, which blits one of two
parallel 5-entry tables (`$9789-$978D` vs `$978E-$9792`) depending on
the flag — reads as a small HUD/character-cell flicker toggle (which
of two glyph variants to show), not a gameplay mechanic. `FUN_9754`
itself writes into `$9773`, an address Ghidra's own decompile flags as
"read-only (code) being written" — self-modifying code again,
consistent with this project's already-confirmed self-modifying-opcode
pattern in `LO-HI A2-3D1` (see
[[space_vikings_a2_3d1_opcodes_8_9_12_confirmed]]) — not re-disassembled
byte-for-byte this pass, flagged ❓ only on the exact visual effect, not
on the dispatch mechanism itself, which is now fully traced.

**Who actually calls this, and with what mode** (all in `STARSHIP
SIMULATOR.bas`'s key-dispatch block above): `'A'`→mode 4 (line 317),
`'B'`→mode 3 (318), `'S'`→mode 1 (321, no `GOTO 500` — relies on
fall-through), `'W'`→mode 2 (205). Plus `INSTRUMENTS.bas` line 210
pokes the cold-init sentinel directly (`PEEK(38391)<>77`, i.e. "has
this boot run TRANLIT's init yet") rather than a mode number, forcing
the full six-step chain once per fresh boot before handing off to
`STARSHIP SIMULATOR`. | ⬜ — reads as cosmetic HUD-icon flicker, not a
gameplay system; no 1:1 port needed, consistent with this project's
"A2-3D1 internals don't need to survive the port" precedent. Noted here
mainly so the *existing* catalog row for `CALL 38402` (below) isn't
read as "one opaque call" when it's actually a 6-routine dispatch keyed
on a side-channel byte — the thing this whole file exists to prevent.

### 3. `POKE 38823,<arg>: POKE 38824,<mode>: CALL 38825` — the 2-argument calling convention

Applesoft's `CALL` takes no parameters, so wherever the original needs
to pass arguments into a shared machine routine, the convention is:
poke them into two fixed scratch bytes immediately before the call.
`CALL 38825` ($97A9) is used this way from **four** sites, not the two
this file previously tracked under `H_D.bas` alone:

| Site | `POKE 38823,` (arg0) | `POKE 38824,` (mode) |
|---|---|---|
| `START.bas` line 220 (new game) | `PEEK(38392)` | `0` |
| `H_D.bas` line 25 (arrival, new planet) | `PEEK(38163)` (target/current planet) | `0` |
| `H_D.bas` line 12 (arrival, old planet) | `PEEK(38209)` | `1` |
| `END.bas` line 210 (game-save, right before the `BSAVE`s) | `PEEK(38209)` | `1` |

Mode `0` sites always pass a *planet index about to become current*;
mode `1` sites always pass the *outgoing* planet right before a
BSAVE/departure. Reads as a `SHIP_SPRITE_INIT(planet_index, mode)` —
mode 0 = load/select for arrival, mode 1 = flush/commit before leaving
or saving — which matches this file's existing guess for the two
`H_D.bas` sites, but the `END.bas` site is new: **the save-game flow
also depends on this routine's side effects**, not just hyperdrive
arrival. The callee's exact bytecode is still unresolved (`$97A9` falls
inside `TRANLIT.OBJ0`'s last decompiled function, `FUN_9754`, per
Ghidra's function-boundary detection, but that's a heuristic, not a
confirmed deliberate secondary entry point — not treated as settled).
| ❓ unresolved on exact effect, but the **calling convention and full
site list are now settled**, upgrading this from "two call sites,
opaque" to "four call sites, known argument shapes, opaque callee."

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
| 69 | `CALL 38402` | **Not one routine — a 6-routine dispatch keyed on `PEEK(38167)`/`PEEK(38189)`, set by `POKE LT,n` a few lines above.** See "6502/DOS asm-level call tricks" §2 above for the full mechanism; reads as cosmetic HUD-icon flicker, not gameplay. | ⬜ no Godot equivalent needed — confirmed cosmetic, not just assumed. |
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
| 12 | `CALL 38825` | **2-argument call, not opaque on convention anymore** — `POKE 38823,<planet>: POKE 38824,<mode>` immediately before every call site. Four real sites, not two: here (mode 1, outgoing planet), line 25 below (mode 0, arrival planet), plus `START.bas` (new game, mode 0) and `END.bas` (game-save, mode 1, right before the `BSAVE`s). See "6502/DOS asm-level call tricks" §3 above. | ❓ exact callee bytecode still unresolved, but the calling convention and full site list (incl. the save-game dependency) are now settled — upgraded from a 2-site to a 4-site, known-argument-shape finding. |
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
209, `IF K=24 THEN PRINT CHR$(4)"RUNH/D"`) that's supposed to be it — a
follow-up pass (see "6502/DOS asm-level call tricks" §1) traced the full
key-dispatch block end to end and confirmed that line is genuinely
unreachable in the shipped original, not just unidentified.

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
2. **RESOLVED, not just hand-traced:** the real in-flight hyperdrive
   trigger key (`STARSHIP SIMULATOR.bas` line 209, `IF K=24 THEN PRINT
   CHR$(4)"RUNH/D"`) is dead code in the original — a full trace of the
   key-dispatch block (lines 200-210, see "6502/DOS asm-level call
   tricks" §1) shows `IF K<34 THEN 207` unconditionally redirects K=24
   ('H') away before line 209 is ever reached. The Godot port's current
   choice to have no flight-triggered hyperdrive key at all is already
   the faithful port (confirmed against `space_flight.gd`'s
   `_unhandled_input`), not a gap. A live MAME key-sweep would still be
   nice to rule out an interrupt-driven secondary key reader, but this
   is no longer blocking or speculative.
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
