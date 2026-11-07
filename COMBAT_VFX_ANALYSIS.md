# Combat visuals: fighters, lasers, and explosions

This traces how Space Vikings actually renders its space-combat effects —
fighter attacks, laser fire, and explosions. Short answer: **none of it uses
the A2-3D1 3D engine** (see `A2-3D1_ENGINE_ANALYSIS.md`). That engine is too
slow for interactive, moment-to-moment BASIC gameplay; combat instead uses
three cheaper, completely different tricks, all driven straight from
`STARSHIP SIMULATOR.bas` and `EX.bas`. Every claim below cites a specific
line number or decompiled function, re-checkable directly.

## Fighter approach: a fake-perspective flip-book, not real 3D

`STARSHIP SIMULATOR.bas` lines 1000–1090. Two fighters are drawn
symmetrically (`XDRAW M3 AT M1+M2,M` and `...AT M1-M2,M`) inside a loop over
`M` (screen Y, `124` down to `62` step `-4`, 16 iterations). Each iteration:

- Erase the previous frame (re-`XDRAW` the same shape/position — Apple II's
  `XDRAW` toggles pixels via XOR, so drawing twice erases).
- `M3 = M3 + .32` — the shape *index* creeps up by a fraction each frame.
  Applesoft truncates this to an integer when used in `XDRAW`, so over 16
  steps starting at `M3 = 3` it walks through shapes `3` → `~8`: a genuine
  multi-frame flip-book, not a single static sprite.
- `M2 = M2 - 2` — the horizontal gap between the two fighters shrinks every
  frame, faking "converging as they approach" perspective cheaply, with
  none of the matrix/clip/divide math from the real 3D engine.
- `X0,Y0,Z0` (the fighter's 3D world position) are updated by a velocity
  vector (`X2,Y2,Z2`) every frame — real incremental motion simulation, just
  not fed through A2-3D1's rendering pipeline.
- A hit check runs mid-loop: `PEEK(38210)=1 AND Y0<VV` (weapon fired and
  target in range) or a 3D bounding-box test against the player's position
  (`X9,Y9,Z9`, line 1050) sets `HIT=1`.

**The shapes themselves** (decoded from `extracted/ENEMY I.A24580.L68.payload.bin`
via `tools/shape_table_decoder.py` — see below) confirm this: shapes `3` and
`7` are genuine minimalist wedge/delta-wing silhouettes, visibly different
from each other, consistent with a tumbling-as-it-approaches look.

## Fighter retreat/flyby: a different, simpler treatment

Line 1100, reached when the fighter isn't hit. Uses a *fixed* shape `2`
(not the incrementing `M3`), cycling Applesoft's native `ROT=` parameter
(`0`, `25`) instead of swapping shapes, with a `CALL SG` (sound) after each
draw. Shape `2` itself decoded to just a tiny single-segment dash —
surprisingly minimal, but plausible for something only ever shown spinning
and shrinking away, where fine detail wouldn't read anyway.

## Fighter explosion: scale-flash + stamped debris, not a shape-table "boom"

Lines 1200–1222, reached when `HIT=1`. For each of the two fighters:

1. `SCALE=1` then `SCALE=2`, redrawing shape `2` — a quick "grow" flash.
2. `XDRAW` shapes `15`, `16`, `17`, `18` in sequence, all at the *same*
   screen position — these are part of the **same `ENEMY` shape table** as
   the fighter, not a separate explosion asset.

Rendered (individually and combined, since the BASIC draws all four at one
shared anchor point), shapes `15`–`18` are **not** a tidy radial starburst —
they're scattered, disconnected line fragments pointing in different
directions. On reflection that's a reasonable way to depict debris flying
apart; the dramatic effect in-game is likely carried more by the rapid
XOR-flicker redraw and the scale-up flash than by any single frame's detail.

## Laser beam: pure BASIC vector graphics, no shape table at all

Lines 1505–1530. The beam itself is two `HPLOT` triangles from the cockpit
corners converging on the target reticle (`(90,123)→(136,60)→(94,123)` and
mirrored), flickered 3 times via a `FOR LX=1 TO 3` loop, erased each time by
redrawing in `HCOLOR=0`. `CALL LA` runs alongside each flicker.

`LASER`'s decompile (`rea-disassembly/LASER (0x92D1)/functions/0x92d1.c`)
confirms it is **pure sound, zero graphics**: a nested countdown loop (outer
14 iterations, inner 140) hitting the speaker toggle `$C030` on every
decrement — a frequency-sweep tone, nothing else touched. The visual and
the sound are completely decoupled code paths that just happen to run back
to back in the same `FOR` loop.

## Ship destruction: `EX.bas`, and a naming coincidence worth knowing

Triggered via `PRINT "RUNEX"` (`STARSHIP SIMULATOR.bas` line 1560) when an
enemy's hull depletes. `EX.bas` line 5 sets `EX = 37494` — **the exact same
address as `SG`** (`SOUND GEN`, `$9276` = `37494` decimal) used everywhere
else in the game. `CALL EX` is not a distinct "explosion" routine; it's
just `SOUND GEN`, called 75 times in a row (50, then 25 more) for the boom.

The visual: `XDRAW` shapes `2`+`15`-`18` again (the same fighter + burst
shapes), this time at `SCALE=2` centered on screen (`140,65`), followed by
a genuine particle-style effect — a nested loop drawing random `HPLOT`
lines radiating outward from center, clamped to screen bounds (lines
7–10). No shape table involved in the debris scatter at all. Only
*afterward* does it `BLOAD` the real `DEBRIS` file (`$7879`), for
persistent floating wreckage in the next scene — a different, later visual
from the explosion itself.

## Incoming fire (a second, separate enemy pattern)

Lines 5000–5251. A generic shape `M` moves across the screen along a 2D
trajectory from a random edge position, with a chance each step
(`RND(1)<.3`) to "fire": fading `HPLOT` tracer lines from the firing point
toward the player's position (`HCOLOR` decreasing each iteration — a
fade-out), plus a chance to reuse the retreat-flicker animation from line
1100. A separate, simpler pattern from the main two-fighter approach above.

## `EXPL`: still an open question

`EXPL` was already shown (`rea-disassembly/README.md`) to be graphics data,
not code. Decoding it (`tools/shape_table_decoder.py`) gives 21 real shapes
(indices `0`–`20`). But its only textual reference anywhere in the codebase,
`H_D.bas` line 8 (`PRINT "BLOADEXPL": ... DRAW 25 AT X,133 ...`), draws
shape index **`25`** — physically impossible from a 21-shape table. `H_D.bas`
also never `POKE`s the Applesoft shape-table pointer (`$232`/`$233`)
anywhere, so `BLOAD`ing `EXPL` loads its bytes into memory but never
actually makes it the active drawing table. Shape `25` is almost certainly
coming from whichever table was active before (`ENEMY`, 27 shapes, `0`–`26`
— `25` is valid there) left over from `STARSHIP SIMULATOR.bas`.

So `EXPL` may never actually get drawn anywhere in the code examined so
far. Not resolved — a candidate for further digging if it matters (e.g.
tracing every overlay transition into `H_D.bas` to see if any of them sets
the shape pointer to `EXPL`'s load address first).

## Decoding ENEMY and EXPL

The project's own `apple2-shape-table-converter.py` has a hardcoded file
list and a hardcoded Windows path baked into `main()` — it ignores command-
line arguments entirely, so it silently did nothing for files outside its
original list. `tools/shape_table_decoder.py` is a fresh implementation
written to actually take a file argument. (2026-11-07: both scripts'
*byte-decode* logic was also wrong at the time this was first written —
"verified against that script's own already-correct output" below just
meant the two scripts agreed with each other, not that either was right.
Both have since been corrected against the real ship/planet art in the
game's manual; see `tools/shape_table_decoder.py`'s docstring. The
`ENEMY`/`EXPL` shapes the combat VFX scripts below were built against
came from the *old*, wrong decode and have been regenerated — the
specific shape indices (2, 15-18, etc.) referenced in `scripts/combat/`
still exist in the new data, but their exact visual content, scale, and
screen-position assumptions haven't been re-verified against it yet.)

```bash
python3 tools/shape_table_decoder.py "extracted/ENEMY I.A24580.L68.payload.bin" \
  "modern/shapes_json/ENEMY I.A24580.L68.payload.json"
python3 tools/shape_table_decoder.py "extracted/EXPL.payload.bin" \
  "modern/shapes_json/EXPL.payload.json"
```

Both outputs are now in `modern/shapes_json/` and copied into
`godot-remake/assets/shapes/` for visual inspection via
`godot-remake/scripts/contact_sheet.gd` (see `godot-remake/README.md`).

## Source map

| What | Where |
|---|---|
| Fighter approach/retreat/explosion logic | `detokenized/STARSHIP SIMULATOR.bas`, lines 1000–1222 |
| Incoming-fire pattern | `detokenized/STARSHIP SIMULATOR.bas`, lines 5000–5251 |
| Laser beam visual | `detokenized/STARSHIP SIMULATOR.bas`, lines 1505–1530 |
| `LASER` decompile (confirms pure sound) | `rea-disassembly/LASER (0x92D1)/functions/0x92d1.c` |
| Ship destruction sequence | `detokenized/EX.bas` |
| `EXPL`'s only reference (and the shape-25 contradiction) | `detokenized/H_D.bas`, line 8 |
| Fighter/burst shape data | `modern/shapes_json/ENEMY I.A24580.L68.payload.json` |
| `EXPL` shape data | `modern/shapes_json/EXPL.payload.json` |
| Decoder used | `tools/shape_table_decoder.py` |
