# Ground combat: full mechanical trace

This documents the ground-invasion subsystem end to end, purely as coded,
from entering `GROUND FORCES.bas` through battle resolution, surrender,
looting, basing, and troop management. Every address and formula below is
quoted directly from the detokenized source; no address is asserted from
a prior guess without being re-checked against an actual read/write site
in this pass.

## Entry and menu gating

`GROUND FORCES.bas` is reached from `COM.bas` (menu option 2, or
automatically when `PEEK(38151)=7`, lines 98/115/127) and from `RECALL.bas`
and `SHORE LEAVE.bas` on their own "back to ground forces" paths.

On entry (line 14): `IF PEEK(29469)=20 AND PEEK(29470)=0 AND PEEK(38170)=0
THEN POKE 38170,17` — a one-shot flag set only when the ship's position
registers ($29469`/`$29470`, the `Y1`/`Z1` world-position bytes used
elsewhere for altitude) read exactly `20`/`0` and the flag hasn't already
fired. This flag is consumed later in `H_D.bas` (see "Entering combat"
below).

The menu (lines 30-50):
```
1) ATTACK PLANET     2) RECALL TROOPS   3) SHORE LEAVE
4) ENLIST TROOPS      5) SELL LOOT       6) REPAIR/RESTOCK
7) ESTABLISH BASE     8) CRYOGENICS       9) RETURN
```
Gating checks before dispatch:
- Line 65: options `3-6` (Shore Leave, Enlist, Sell Loot, Repair/Restock)
  all require `PEEK(38303+PEEK(38209)) <> 0` — a per-planet "base built"
  flag array, indexed by the current planet (`$38209`). No base, no access
  to any of these four.
- Line 66: option `4` (Enlist) additionally requires
  `PEEK(38158)=PEEK(38209)` — `$38158` is a "troops currently stationed
  at planet #" register, separate from `$38209` ("currently orbiting
  planet #"). Mismatch prints "YOU LEFT YOUR TROOPS ON ANOTHER PLANET!"
  and refuses.
- Line 67: option `1` (Attack) has the identical check and refusal text
  for the same reason.

## Launching an attack (lines 170-195)

- Line 172: if `PEEK(38207)=1 AND PEEK(38208)=1` (a flag combination —
  `$38208` is confirmed elsewhere as the "planet surrendered" flag) the
  attack is aborted back to the menu without launching.
- Line 175: if `PEEK(38155)=0` (zero transports) — "THERE ARE NO
  TRANSPORTS AVAILABLE!" and abort.
- Line 177: `POKE 38166,1` — sets troop location state to `1`
  ("planetside"; the full state enum, confirmed from `STATUS.bas` lines
  1380-1384 and `RECALL.bas`/`SHORE LEAVE.bas`'s own checks, is `0`=on
  board, `1`=planetside, `2`=shore leave, `3`=cryogenic sleep).
- Lines 178-179: `T8 = PEEK(38155)*1000` — each transport can carry up to
  1000 troops. If the troop count `TR` exceeds total transport capacity
  `T8`, the excess (`T9 = TR - T8`) is held back aboard ship and `TR` is
  capped at `T8` for the landing force; otherwise all troops go down
  (`T9=0`). `T9` is the "held in reserve" troop count used later to
  restore troops on retreat or loss.
- Lines 180-190: flavor text ("ALL TRANSPORTS AWAY, SIR!", conditionally
  "TRANSPORTS ENTERING ATMOSPHERE!" when `$38210=0`, "FIGHTERS LAUNCHING
  FROM TRANSPORTS!" when fighters `PEEK(38156)>0`) with `FOR...NEXT` delay
  loops, no state changes.

## Pre-battle narrative branch on tech level (lines 200-500)

`C = PEEK(38282+PEEK(38209))` — the planet's tech rating (`0`-`4`,
confirmed independently against `COM.bas` lines 1030-1070, which prints
the same five tech-level strings from the same address). `ON C+1 GOTO`
dispatches to one of five narrative blocks:

| Tech | Text shown | Mechanical effect |
|---|---|---|
| 0 | "NO ENEMY TO RESIST LANDING FORCE" | `GOSUB 740` — instant win, no battle loop at all: `POKE 38208,1` (surrendered), `POKE 38219+planet,1` (secured flag), then straight to looting (`GOTO 310` → menu, loot was already queued) |
| 1 | "LOCAL INHABITANTS ... UNABLE TO RESIST ... MINIMUM OF FIGHTING" | `POKE 38150,0` (enemy strength forced to 0), falls into the battle loop at line 500 anyway but with `SP=0` so it resolves almost immediately |
| 2 | "LIMITED ATOMIC ... ATTACK FORCE IS MEETING RESISTANCE" | normal battle loop |
| 3 | "COMPARABLE TECHNOLOGY ... HEAVY COUNTER ATTACK" | normal battle loop |
| 4 | "SUPERIOR TECHNOLOGY ... VERY HEAVY COUNTER ATTACK" | normal battle loop |

Tech 0 is the only tier that skips the round-based battle loop entirely;
tech 1 still runs the loop but with the enemy's defense strength
(`SP`/`$38150`) zeroed, so it still takes at least one round to resolve
but has no real resistance.

## The battle loop (lines 500-690)

Entered once per round. State read at the top (line 500-510):
```
TECH = PEEK(38282 + PEEK(38209))     ' planet tech rating, 0-4
ET   = PEEK(38206) * 500             ' enemy ground-defense strength
M    = PEEK(38153)                   ' ground missiles (player)
SP   = PEEK(38150)                   ' enemy resistance threshold ("strength")
VP   = PEEK(38160)                   ' player's accumulated victory progress
```
(`P`=fighters/`$38156`, `TP`=transports/`$38155`, `T`=tanks/`$38154` were
already loaded at line 13; `TR` is the troop count, tracked purely as a
BASIC variable loaded from/written to the "MISC FILE" disk file, not a
fixed memory address.)

**Round outcome roll** (line 550): `VIC = RND(1) * (10*TECH)`. If
`VIC < 20`, the round branches "favorable" (line 550's own continuation);
otherwise it falls through to line 555, "unfavorable":

| | Favorable (`VIC<20`) | Unfavorable (`VIC>=20`) |
|---|---|---|
| `T1` | `TECH * 3` | `1` |
| `T2` | `500 + RND(1)*20` | `200 * RND(1) * 5` (0-1000, wide variance) |
| `T3` | `200 + RND(1)*5` | `500 + RND(1)*5` |
| `X` (progress delta) | `+RND(1) * (12/(TECH+.5))` | `-RND(1) * (10/(TECH+.5))` |

Because `VIC`'s range scales with `TECH`, a tech-0/1 planet almost always
rolls favorable (its `10*TECH` ceiling is below or barely above the `20`
cutoff), while a tech-4 planet's `VIC` ranges `0-40`, giving roughly a
50% chance of an unfavorable round. Higher tech both raises the odds of a
bad round and (via the `TECH+.5` divisor) shrinks the magnitude of a good
round's progress and grows the magnitude of a bad round's setback.

**Universal per-round attrition** (lines 560-570), applied regardless of
the favorable/unfavorable roll:
```
T  = T  - RND(1)*RND(1)*5                              ' tanks
P  = P  - RND(1)*RND(1)*5                               ' fighters
M  = M  - RND(1)*RND(1)*5                                ' missiles
TP = TP - RND(1)*1 + .5                                  ' transports (net ~flat)
TR = TR - RND(1)*RND(1)*(TECH * RND(1) * T2)             ' troops
ET = ET - RND(1)*RND(1)*(3 * RND(1) * T3)                ' enemy strength
```
Troop losses scale directly with `TECH` and `T2` — both branches average
a similar `T2` (~500) but the unfavorable branch's `T2` has far higher
variance (0-1000 vs. 500-520), so troop losses are noisier, not
necessarily larger on average, when a round goes badly.

**Orbital-defender penalty** (line 570, same line as the `ET` attrition):
`IF PEEK(38205) > 0 THEN X = X - RND(1)*1` — if an enemy ship is still
present at the planet (`$38205`, confirmed elsewhere as the planet's
orbital-defense-ship presence/type flag), every single round takes an
*additional* penalty to progress on top of whatever the favorable/
unfavorable roll already gave it. This is a flat per-round tax that
applies independently of the round's own outcome.

**Morale's direct effect** (line 575): `X = X + (PEEK(38203) - 3)` —
troop morale (`$38203`, range `1`-`6`, confirmed by label against
`STATUS.bas` line 1340/1350-1360's "AWFUL!!!" through "EXCELLENT!" ladder)
is added to progress every round, centered on `3`. Morale `6` adds `+3`
per round; morale `1` subtracts `-2` per round. This is the single
largest and most consistent progress term in the formula — larger in
magnitude than either the favorable or unfavorable `X` roll at most tech
levels — and it does not reset or decay during the battle; it's
re-applied, unchanged, every round until something else changes `$38203`.

**Clamping** (lines 580-598): `VP = VP + X`, clamped to `0-255`; `T`,
`P`, `M`, `TP`, `TR` all floored at `0`.

**Persist and display** (lines 600, 650): fighters/transports/tanks/
missiles are written back to memory (`38156`/`38155`/`38154`/`38153`);
`GOSUB 4000` refreshes the on-screen counters and the success-probability
readout `PS = (100/(SP+.01)) * VP` (displayed as a `%`, capped at `100`);
`GOSUB 1100` checks for a retreat (see below).

**Round-end checks** (lines 660-690):
- `IF VP >= SP THEN` — surrender: zero `SP`, print "THE PLANET HAS
  SURRENDERED!", `POKE 38208,1`, `POKE 38219+planet,1` (secured flag),
  then fall through to looting.
- `IF TR = 0 THEN` — battle lost: troop location reset to on-board
  (`POKE 38166,0`), the held-in-reserve troops (`T9`) are added back and
  written to the MISC FILE along with current credits, and the game
  returns to `COM`. All deployed troops are destroyed; nothing is looted.
- Otherwise: delay, `GOTO 550` — another round.

Nothing in this loop ever reduces `SP` (the enemy's resistance threshold)
except the tech-1 special case (`SP=0` from the pre-battle branch) — the
enemy doesn't get weaker as the battle progresses, only the player's
accumulated `VP` climbs toward it (or doesn't).

## Retreating mid-battle (lines 1100-1130)

Called every round via `GOSUB 1100`. As written:
```
1100 K = PEEK(-16384): IF K<128 THEN POKE -16368,0: RETURN
1110 POKE -16368,0: K = K - 176
1115 K = 82
1120 IF K=82 THEN ... retreat ...
```
Line `1115` unconditionally overwrites `K` to `82` right after line
`1110` computes it from the actual key pressed — so the `K-176`
computation on line 1110 has no effect on the branch at line 1120, which
always evaluates `K=82` as true once *any* key has been pressed (i.e.
once `PEEK(-16384)` reads `>=128`, meaning the keyboard strobe is set).
As coded, pressing any key at all during an active ground battle triggers
a retreat — there's no key-specific check actually gating it, regardless
of what the `K-176` arithmetic appears to be aiming at (likely comparing
against a specific key code in an earlier draft).

On retreat: "GROUND FORCES RETREATING, SIR! PLANET NOT SECURED!",
`TR = TR + T9` (reserve troops rejoin the count) and written to the MISC
FILE, and `$38203` (morale) is decremented by `1`, floored so it never
goes below `0` via `IF M > -1 THEN POKE 38203,M` (note: this floors at
`0`, not `1` — unlike the Shore Leave pay/no-pay path below, which floors
morale at `1`). Control returns to `COM`.

## Non-habitable planets (line 740, reached only from the tech-0 branch)

```
740 POKE 38208,1: POKE 38219+PEEK(38209),1: FOR J=1 TO 4000: NEXT: RETURN
```
Identical surrender flags to a real victory, with no battle loop, no
troop losses, and (per `COLLECT.bas`'s own tech-0 branch) no loot either
— "THERE IS NO LOOT TO GATHER, SIR."

## Looting: `COLLECT.bas`

Reached via `PRINT "RUN COLLECT"` after any surrender. Branches again on
`TECH = PEEK(38282+PEEK(38209))`:

| Tech | Loot behavior |
|---|---|
| 0 | None — "THERE IS NO LOOT TO GATHER" |
| 1 | Wine/liquor (`$38183`) and food (`$38182`) each `+RND(1)*5` (capped `255`); general goods (`$38173`) `+RND(1)*10` |
| 2 | 12 goods categories (`$38171`-`$38183`) each incremented via a shared subroutine (line 920), with per-category multipliers `J1=0` / `J2=10` — categories weighted by `J1` get **zero** at this tier |
| 3 | Same 12 categories, `J1=10` / `J2=7` — the weighting flips: categories that got nothing at tier 2 now get more than the `J2` categories |
| 4 | Same 12 categories, `J1=15` / `J2=15` — both groups maximized |

A discount flag at `PEEK(301)`: if already set, every category's RND
multiplier is pre-scaled by `.6` before use (line 920), then the flag is
set (line 921) — a one-time-per-visit "already collected once" discount.
(`H_D.bas` line 6 resets this flag, `POKE 301,0`, at the start of each new
orbital engagement, so it re-arms once per fresh encounter.)

**A real, verifiable bug**: line 960, `J = PEEK(38180) + (RND(1)*J1):
GOSUB 915: POKE 31180,J` — reads from `$38180` but writes the result to
`$31180`, not `$38180`. Every other line in this block (950, 970, 980,
...) reads and writes the same address; this one line's write target
doesn't match its read source. As written, whatever goods category lives
at `$38180` never actually accumulates loot from any tier that touches
it — the increment is computed and discarded into an address six
thousand decimal away from where it was read.

These same twelve addresses (`$38171`-`$38183`) are the exact set `SHORE
LEAVE.bas`'s "SELL LOOT" option (lines 2400-2406) reads to compute sale
value — `L = PEEK(38171)*(300*RND(1)) + PEEK(38172)*150 + ... +
(PEEK(38183)*10)*200` — and zeroes after paying out. Loot collected here
and goods sold there are the same inventory block.

## Troop morale outside the battle loop

Three places change `$38203` (range `1`-`6`, display ladder confirmed in
`STATUS.bas`):

| Trigger | Effect | Source |
|---|---|---|
| Landing flag consumed | `-1` (floored at `0`) | `H_D.bas` lines 12-13, gated on the `$38170=17` flag set by `GROUND FORCES.bas` line 14 |
| Retreating mid-battle | `-1` (floored at `0`) | `GROUND FORCES.bas` line 1120 |
| Shore Leave, pay troops ("Y") | `+1` (capped at `6`) | `SHORE LEAVE.bas` lines 2093/2095 |
| Shore Leave, decline to pay ("N") | `-2` (floored at `1`) | `SHORE LEAVE.bas` lines 2088-2089 |

Morale has no other write sites found in this pass. Its only *read* site
with gameplay effect is `GROUND FORCES.bas` line 575, inside the battle
loop's progress formula, where it's added every round as described
above.

## Establishing a base, enlisting, repairing (`SHORE LEAVE.bas`)

All four base-gated menu options (Shore Leave, Enlist, Sell Loot,
Repair/Restock) route into `SHORE LEAVE.bas` via `POKE 38388,<1-5>: PRINT
"RUNSHORE LEAVE"`, which reads `$38388` back out (line 20) to pick a
branch: `1`=shore leave/pay troops, `2`=sell loot, `3`=establish base,
`4`=enlist, `5`=repair/restock.

- **Establish base** (lines 2100-2160): refused if a base already exists
  (`$38303+planet > 0`), if the planet's tech is below `2`
  ("TOO BACKWARD TO BUILD A BASE"), or if `$38149=1` ("ONLY ONE TIME PER
  TRIP" — set by line 2107 the first time any base is built on a given
  trip, regardless of planet). Cost: `C = 20000 + (RND(1)*5000) *
  (RND(1)*10)` credits, confirmed on "Y", deducted, `$38303+planet` set
  to `1`.
- **Enlist** (lines 2200-2300): refused if already used this trip
  (`$38389=1`) or if the planet hasn't surrendered (`$38208=0`). Cost is
  exactly `1` credit per troop, input via the shared numeric-entry
  subroutine at line 5000; capped so total troops (`TR+EN`) can't exceed
  `20000`.
- **Repair/Restock** (lines 2500-2620): refused unless the ship is
  actually landed (`$38210=0 OR PEEK(29469)>22` → "YOU MUST LAND ON
  PLANET FIRST"). Reads a `DATA` table of twelve ship-system labels and
  addresses (shield `$38200`, energy `$38199`, engines `$38198`/`$38197`,
  computer `$38196`, radar `$38195`, environment `$38194`, hull `$38193`,
  hyperdrive `$38190`, missiles `$38187`, laser `$38186`, nav. computer
  `$38184`), repairs each below `100` (or below `63` for the second
  entry, engine #1, which has a different floor) to full, and bills per
  point of damage repaired; declining to pay triggers `POKE 38208,0:
  POKE 38219+planet,0` — the planet's surrendered/secured status is
  **revoked** if you walk away from a repair bill.
- **Buy weapons** (subroutine at line 3000, invoked from the Repair
  screen): fighters/transports/tanks/missiles, priced via
  `C = INT((RND(1)+.2) * 4 * MU(n))` with fixed base multipliers
  `MU = {50, 75, 40, 30}`, capped at `255` per category.
- **Pay troops** (lines 2080-2099, "Y/N?"): see the morale table above;
  also sets `$38158 = $38209` (troops now considered stationed at the
  current planet) and `$38166 = 2` (troop location = "shore leave").

## Recalling troops (`RECALL.bas`)

A thin gate: prints a status message based on `$38166` (troops not on
this planet / none left / being recalled / in cryo sleep / already on
board) and, for the "being recalled" case, sets `$38166 = 0` (on board).
No morale or credit effect — recall is purely a troop-location-state
change, not a combat action.

## Entering combat / orbital engagement (`H_D.bas`)

The orbital "hit and destroy" sequence that precedes and follows ground
combat. Relevant to ground combat specifically:
- Line 11: `IF PEEK(38166)=0 OR PEEK(38166)=3 THEN POKE 38158,PEEK(38163)`
  — if troops are on board or in cryo, the "troops stationed at planet"
  register is synced to the travel-target planet (`$38163`) rather than
  the currently-orbited one, before combat resolves.
- Line 12: `POKE 38823,PEEK(38209): POKE 38824,1: CALL 38825: IF
  PEEK(38170)=17 THEN PL=PEEK(38203):LP=7:PL=PL-1: IF PL<0 THEN PL=0` —
  this is where the landing flag set in `GROUND FORCES.bas` line 14 is
  actually consumed, confirming the one-time `-1` morale cost on landing
  described above.
- Line 90-93: `TECH = PEEK(38282+PEEK(38209)): IF TECH<2 THEN POKE
  38150,0` else `POKE 38150,TECH*60: POKE 38204,TECH*60: POKE
  38160,0: POKE 38161,0` — this is where the ground battle's enemy
  resistance threshold (`SP`/`$38150`, read at `GROUND FORCES.bas` line
  510) and victory-progress accumulator (`VP`/`$38160`) are actually
  initialized, scaled directly by planet tech (`TECH*60` — so a tech-4
  planet's resistance threshold, `240`, is exactly `4x` a tech-1
  planet's, `60`).

## Open items from this pass (not resolved, flagged rather than guessed at)

- **Two different troop counts.** `TR` (the BASIC variable, persisted via
  the "MISC FILE" disk file alongside stardate and credits) is what every
  ground-combat and shore-leave routine actually reads and writes.
  Separately, `STATUS.bas` line 1386 checks `(PEEK(38167)*256) +
  PEEK(38159) = 0` as if it were a 16-bit "troops alive" counter and
  prints "THE TROOPS ARE ALL DEAD!" when zero — but no file read in this
  pass ever writes to `$38159` or `$38167` to keep such a counter in sync
  with `TR`. `STARSHIP SIMULATOR.bas` separately assigns `$38167` to a
  variable named `LT` alongside other space-combat constants (`SG`=sound
  gen, `LA`, `TX`/`TT`), suggesting `$38167` may be reused for an
  unrelated space-combat purpose in that overlay rather than genuinely
  holding half of a troop counter. Not resolved — would need every write
  site to `$38159`/`$38167` traced across all overlays to settle.
- **`$38149`'s dual role.** Used in `SHORE LEAVE.bas` as a "base already
  built this trip" one-shot (set at line 2107, checked at line 2106), and
  separately checked/cleared in `COM.bas` line 1007 (`IF PEEK(38149)=8
  THEN POKE 38149,0`) in an apparently unrelated context (value `8`, not
  `1`). Likely the same general-purpose "one-shot action flag" byte
  reused for different numeric meanings in different overlays (consistent
  with the project's established memory-sharing pattern), but not traced
  further here.

## Source map

| What | Where |
|---|---|
| Menu, gating, attack launch | `detokenized/GROUND FORCES.bas`, lines 12-195 |
| Tech-level narrative branch | `detokenized/GROUND FORCES.bas`, lines 200-500 |
| Battle loop / progress formula | `detokenized/GROUND FORCES.bas`, lines 500-690 |
| Retreat handling (and the always-true key check) | `detokenized/GROUND FORCES.bas`, lines 1100-1130 |
| Non-habitable instant-surrender | `detokenized/GROUND FORCES.bas`, line 740 |
| Looting by tech tier, incl. the `31180` write-target bug | `detokenized/COLLECT.bas`, lines 800-1090 |
| Sell Loot valuation (same addresses as COLLECT) | `detokenized/SHORE LEAVE.bas`, lines 2400-2460 |
| Establish base / enlist / repair / buy weapons / pay troops | `detokenized/SHORE LEAVE.bas`, lines 2080-3110 |
| Troop recall | `detokenized/RECALL.bas` |
| Landing-flag consumption, resistance/progress init | `detokenized/H_D.bas`, lines 11-13, 90-93 |
| Troop/morale/system status readout | `detokenized/STATUS.bas` |
| Tech rating, secured flag, base flag, population display | `detokenized/COM.bas`, lines 1005-1180 |
