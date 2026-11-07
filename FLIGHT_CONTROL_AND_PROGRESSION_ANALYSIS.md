# Flight control, landing, and the BASIC overlay state graph

This covers three things that sit outside the A2-3D1 engine itself
(`A2-3D1_ENGINE_ANALYSIS.md`) and outside combat VFX
(`COMBAT_VFX_ANALYSIS.md`): how the ship actually responds to the paddles
during normal flight, what landing before a ground invasion really does,
and how the ~20 BASIC overlay files hand off to each other. All three were
traced to settle "is anything still ambiguous before the Godot port starts,"
and the answer that came out of this is **no — the remaining items are
product decisions, not research gaps.** The explicit decision made on the
product question (port the numbers as-coded, don't redesign the feel) is
recorded at the end.

## Flight control: a real coordinated-turn model, not stick-to-axis

The joystick→attitude logic is **not** in any BASIC file — it's compiled
6502 in `SPACE SIMULATOR ASSEMBLY` ($9023), called once per frame from
`STARSHIP SIMULATOR.bas` as `CALL CA` (line 150/153). `entry()`
(`rea-disassembly/SPACE SIMULATOR ASSEMBLY (0x9023)/functions/0x9023.c`)
reads `DAT_95fd`/`DAT_95fe` — `$95FD`/`$95FE` = decimal `38397`/`38398`,
the exact addresses `STARSHIP SIMULATOR.bas` POKEs from `J=PDL(1):K=PDL(0)`
— and dispatches into a chain of small helper functions:

- **Pitch** (`$7321`, matches `RE.bas`'s own `P1=29473` constant — `7321`
  hex = `29473` decimal): paddle 1 (`J`) drives it with **direct rate
  control** via `FUN_918c`/`FUN_91c5` — each call steps pitch by 1, and
  `entry()` re-calls the same stepper up to 4 times in a frame as `J` gets
  further from center (threshold ladder at `0x46`/`0x32`/`0x1f` and
  `0xa9`/`0xbd`/`0xd1`/`0xe5`). No spring-back: pitch holds wherever you
  leave it, like elevator trim.
- **Bank** (`$7322`, `B1=29474`): paddle 0 (`K`) drives it the same
  escalating way via `FUN_91d7`/`FUN_919e`, but each call is immediately
  followed by `FUN_91fe`/`FUN_920e`, which actively pull bank back toward
  level (`0`) every single frame whenever it's outside a `±0x2f`-ish dead
  zone. Release the stick and bank un-banks on its own.
- **Heading** (`$7323`, `H1=29475`): never touched directly by either
  paddle. `FUN_912e` reads the *current* bank angle and calls `FUN_91b3`
  (shallow bank, up to the dead zone) or `FUN_91ec` (deep/wrapped bank) 1-4
  times, escalating with bank steepness — a real coordinated turn: bank
  is the cause, turning is the effect, exactly like a plane and not like a
  tank-steering twin-stick model.
- A one-shot correction in `FUN_90f2` detects pitch crossing the
  inverted/vertical threshold (`<0x40` or `>0xbf`) and adds `±0x7e`/`0x81`
  to heading — flipping heading correctly after looping over the top.

This is a deliberate, non-trivial flight model for 1982 and isn't
recoverable from the BASIC source alone — it only exists in the compiled
assembly. Worth preserving if the goal is the original's actual handling.

**One more finding from this trace, not yet fully chased down:** `entry()`
ends by calling `FUN_921e`, which is just:
```c
void FUN_921e(void) { func_0x6000(); return; }
```
`func_0x6000` is A2-3D1's own entry point 1 (`$6000`) — the same engine
analyzed in `A2-3D1_ENGINE_ANALYSIS.md`. Earlier investigation (grepping
the BASIC files for `CALL 24576`) found only `RADAR.bas` calling into
A2-3D1 and concluded the engine was radar-only. That's now known to be
incomplete: the engine actually runs **every single frame** during normal
flight too, from this assembly routine, not just when the radar screen is
up. What it draws there (most likely a 3D starfield, given the engine's
"transform and plot a point" primitive is a natural fit, but not
confirmed) is still open — but it doesn't block the Godot port either way,
since Godot's own particle/Node3D systems can reproduce whatever the
visual turns out to be far more cheaply than re-hosting the original VM.

## Landing and the troop-morale mechanic

Traced to check a specific memory: "landing before deploying troops got a
buff in the battle — the secret to beating higher-tech planets." The code
does something related but **not what's remembered**:

- `GROUND FORCES.bas` line 14: `IF PEEK(29469)=20 AND PEEK(29470)=0 AND
  PEEK(38170)=0 THEN POKE 38170,17` — a one-shot "just landed" flag.
- `H_D.bas` lines 12-13: when that flag is set, troop morale
  (`$38203`, confirmed via `STATUS.bas` line 30: `PRINT "TROOP
  MORALE"...:M=PEEK(38203)`) is **decremented by 1**, then the flag is
  cleared. Landing costs morale; it does not grant a combat buff.
- The actual lever that matters for beating higher-tech planets is in the
  ground-battle RNG itself (`GROUND FORCES.bas` lines 500-598):
  `TECH=PEEK(38282+PEEK(38209))` (per-planet tech rating, confirmed
  read-only, 0-4, from `COM.bas`'s tech-level text strings),
  `VIC=RND(1)*(10*TECH)`, and `X=X+(PEEK(38203)-3)` — so **troop morale**
  (not landing itself) is what shifts the battle roll, and the strongest
  separate lever is `PEEK(38205)` (enemy orbital-defense-ship presence) —
  clearing that ship in space *before* landing removes a penalty term from
  the same formula. So the real "secret" the memory is pointing at is
  likely "clear the defending ship first, then land" — landing itself is
  a minor cost, not a buff, and morale is better built via `SHORE
  LEAVE.bas`'s pay-troops mechanic (`Y` → `+1` morale, capped at 6; `N` →
  `-2`, floor 1) than via the act of landing.

**Decision made on this: port it as-coded, not as remembered.** Faithful
replication means the modern port should keep landing as a small morale
cost and keep "clear the orbital defender first" as the actual winning
play — not retrofit a landing buff that was never in the original.

## The BASIC overlay state graph

Compiled by grepping every `detokenized/*.bas` file for `RUN ` strings —
this is the game's actual scene/state machine, equivalent to what a
modern engine would call scene transitions:

```
START ──────────────────────────────▶ INSTRUMENTS ──▶ GALAXY MAP / STARSHIP SIMULATOR
STARSHIP SIMULATOR ◀──────────────▶ RE / ORBIT / H_D / COM / RADAR / EX / S_X / DMG
COM ◀────────────▶ GROUND FORCES / RADAR / STARSHIP SIMULATOR / END / GALAXY MAP / STATUS / SUPPLY
GROUND FORCES ◀──▶ COLLECT / RECALL / SHORE LEAVE
GALAXY MAP ◀─────▶ COM / STARSHIP SIMULATOR / INSTRUMENTS
RADAR ◀──────────▶ COM / STARSHIP SIMULATOR / SHIP #n I.D.
```

State is shared across these transitions purely through fixed PEEK/POKE
memory addresses (pitch/bank/heading at `$7321-$7323`, the economy/flag
block from `$38xxx` on) — there is no save/restore step, each overlay
just trusts memory left behind by whichever overlay ran before it. This
maps cleanly onto a Godot state machine / scene-tree swap: each `.bas`
file becomes one scene or state, and the shared-memory addresses above
become whatever single global/autoload game-state resource replaces them.

`RE.bas` (reentry/atmosphere) also confirmed the other half of the user's
memory independently of the above: it forces pitch to a fixed value
(`POKE P1,63`), zeroes bank, and hands off to `STARSHIP SIMULATOR` — this
is the "straightens out as you get close" atmosphere-approach mode,
matching the recollection closely.

## Net effect on "ready for Godot?"

- A2-3D1's hand-rolled 3D math (VM, clipping, perspective, the
  self-modifying plotter) does not need to survive the port — Godot's own
  3D stack replaces all of it. See `A2-3D1_ENGINE_ANALYSIS.md`.
- The flight-control model above was the one piece of core gameplay logic
  that lived only in compiled assembly and hadn't been traced anywhere
  before this; it now is, fully.
- The landing/morale mechanic is confirmed as-coded and the decision is to
  port it faithfully rather than match the remembered-but-incorrect buff.
- The overlay state graph is fully derivable and maps directly onto a
  Godot scene/state-machine design.
- Remaining open items are cosmetic/non-blocking: exactly what A2-3D1
  draws every frame during normal flight (`FUN_921e`), opcodes 8/12's
  self-modifying patch targets, and `FUN_91ec`'s exact behavior (presumed
  symmetric to `FUN_91b3`, not yet individually confirmed). None of these
  change any decision needed to start building.

## Source map

| What | Where |
|---|---|
| Per-frame flight-control dispatch | `rea-disassembly/SPACE SIMULATOR ASSEMBLY (0x9023)/functions/0x9023.c` |
| Pitch stepper | `.../0x918c.c`, `.../0x91c5.c` |
| Bank stepper + spring-back | `.../0x91d7.c`, `.../0x919e.c`, `.../0x91fe.c`, `.../0x920e.c` |
| Vertical-loop heading flip | `.../0x90f2.c` |
| Bank-driven heading turn rate | `.../0x912e.c`, `.../0x91b3.c`, `.../0x91ec.c` (unconfirmed) |
| Per-frame call into A2-3D1 | `.../0x921e.c` |
| Landing flag set | `detokenized/GROUND FORCES.bas`, line 14 |
| Landing flag consumed (morale -1) | `detokenized/H_D.bas`, lines 12-13 |
| Troop morale label confirmed | `detokenized/STATUS.bas`, line 30 |
| Ground-battle RNG formula | `detokenized/GROUND FORCES.bas`, lines 500-598 |
| Pay-troops morale mechanic | `detokenized/SHORE LEAVE.bas`, lines 1-30 |
| Per-planet tech rating | `detokenized/COM.bas` (read-only everywhere) |
| Atmosphere/reentry sequence | `detokenized/RE.bas` |
| Overlay transition graph | `grep -n "RUN " detokenized/*.bas` |
