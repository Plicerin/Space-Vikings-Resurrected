# The A2-3D1 engine: how Space Vikings does real 3D on a 1MHz 6502

`LO-HI A2-3D1` (BLOADed at `$6000`, see `HANDOVER.md`/`CATALOG_FINDINGS.md`) is not
game logic — it's a small, general-purpose **3D rendering library**, built from
scratch in 6502 assembly, with no compiler and no hardware multiply or divide to
lean on. This document traces its pipeline end to end, straight from REA's Ghidra
decompile in `rea-disassembly/LO-HI A2-3D1 (0x6000)/functions/`, cross-checked
against the project's own hand-written disassembler output where useful.

Every claim below cites the specific decompiled function it came from, so it can
be re-verified by opening that file directly. Treat the C-shaped pseudocode as a
reading aid, not ground truth — see the caveat in `rea-disassembly/README.md`.

Note: combat visuals (fighters, lasers, explosions) turn out *not* to use this
engine at all — it's too slow for interactive BASIC gameplay. See
`COMBAT_VFX_ANALYSIS.md` for the cheaper tricks actually used there.

## Why this is worth writing down

The headline fact: this is a *real* 3D engine — translate, rotate via an actual
3×3 matrix, clip against the view frustum, and divide by depth for perspective —
not a faked or simplified approximation. It predates Doom and Wolfenstein 3D by
roughly a decade, on hardware with no multiply or divide instruction at all,
and the code shows real engineering discipline: a tiny bytecode interpreter to
separate scene description from rendering, a sine/cosine lookup table for
rotation, and exactly two hand-written arithmetic primitives (one multiply, one
divide) that every other piece of math in the library is built from and reuses.

## The public API: four entry points

The file opens with a 4-entry jump table (confirmed from the raw bytes — `JMP`
operands are absolute addresses, so they read correctly regardless of what base
address a disassembler assumes they're loaded at, even in the project's own
`disassembly/LO-HI A2-3D1.disasm.txt`, which used the wrong base and is garbage
everywhere except these four opcodes):

| Address | Target | Role |
|---|---|---|
| `$6000` | `$611C` | Entry 1 — save/restore caller's zero-page state around a call into the interpreter (`rea-disassembly/.../functions/0x611c.c`) |
| `$6003` | `$6140` | Entry 2 — the bytecode interpreter itself, unprotected (`0x6140.c`) |
| `$6006` | `$6526` | Entry 3 — folds into the sine/cosine table lookup (`0x64f8.c`'s header notes Ghidra removed an unreachable block at `0x6526`); likely a standalone "give me sin/cos of this angle" utility call |
| `$6009` | `$653F` | Entry 4 — not yet traced; falls in a small gap Ghidra didn't resolve to a named function |

## The bytecode VM

`FUN_6140` (`0x6140.c`) is a small threaded interpreter. A zero-page pointer
(`DAT_009b`) acts as a program counter into a command stream; each iteration
fetches one opcode byte and dispatches through an 18-case switch (opcodes
`0`–`0x11`). After handling a case, `FUN_6184` advances the program counter by
that opcode's instruction length (1–10 bytes depending on the opcode) and the
loop repeats.

Notable opcodes:

- **`0`** (7 bytes: opcode + 3×16-bit vertex) — transform and plot a single
  vertex. Calls `FUN_61a9` → `FUN_672b` (transform) → clip test → plot.
- **`1`/`2`/`3`** — transform a *second* vertex and draw the line from the
  previous one to it (`FUN_618e`), i.e. connected polyline drawing — matches
  the `move`/`line` structure already seen in the converted shape-table JSON
  in `modern/shapes_json/`.
- **`5`** (10 bytes: opcode + 9 params) — **rebuild the rotation matrix** from
  3 angle bytes; see below. Calls `FUN_654e`.
- **`7`** — zeroes `$C054` (hi-res page-1 soft switch) and sets a parameter —
  page selection.
- **`8`, `9`, `12`** — **self-modifying code**: patch the operand bytes of
  dozens of addresses scattered through `$62F6`–`$7120` (24+ sites in case 8
  alone). This is the standard Apple II hi-res trick: pixel color depends on
  which half of a screen byte a pixel falls in, so the fast path is to patch
  the plotting routine's own instruction operands at runtime (draw/erase mode,
  color pattern) rather than branch on every pixel.
- **`11`** — an explicit jump: reads a 16-bit address out of the bytecode
  stream and sets the program counter to it. The VM has its own `JMP`.
- **`13`** — set the output-vertex-list pointer (for query/readback mode,
  `DAT_007d` acts as a "report instead of draw" flag).
- **`15`** (7 bytes: opcode + 6 params) — load a 6-byte **secondary rotation**
  used later by the matrix-update routine (see below).
- **`16`** — resets `$C050`/`$C053`/`$C054`/`$C057` to 0: text-off,
  mixed-off, page-1, hi-res-on. Full-screen hi-res graphics mode init.

## Building the rotation matrix: a real sine/cosine table

Opcode `5` triggers `FUN_654e` (`0x654e.c`), which rebuilds the full 3×3
rotation matrix from three input angle bytes (the last 3 of its 9-byte
parameter block):

1. Each angle byte is run through **`FUN_64f8`** (`0x64f8.c`) and
   **`FUN_64fb`** — confirmed table lookups into a 2-byte-wide table starting
   at **`$609A`**, using the standard quarter-wave trick: store roughly a
   90° slice and use sign/mirror folding (seen directly in `FUN_64f8`'s
   branching logic) to cover the full 256-value angle range without needing
   four redundant copies of the table. These are sine and cosine.
2. The six resulting sin/cos values are combined using the standard
   combined-Euler-angle rotation formula (products and sums of the six
   terms, via repeated calls to the shared multiply primitive — see below)
   to produce the 9 matrix coefficients.
3. The result is then **conditionally composed with a second, separately-set
   6-byte "reference" rotation** (loaded earlier by opcode `15`, into
   `$600E`–`$6013`) — three guarded blocks, each skipped if that reference's
   relevant pair of bytes equals the fixed-point "~1.0" sentinel `$7F/$FF`
   (the same sentinel used to initialize the matrix to identity at VM
   startup — see `FUN_6140`'s prologue). That's a genuine optimization:
   don't pay for a second matrix multiply when the reference rotation is
   identity.

This was the open question from earlier in this investigation — is the
rotation incremental (cheap, approximate) or recomputed from trig each time
(expensive, exact)? The answer is: genuinely recomputed from a real
sine/cosine table every time opcode `5` runs, then optionally composed with
a second stored rotation. Not a shortcut.

## Per-vertex transform

`FUN_672b` (`0x672b.c`), called once per vertex via `FUN_61a9`/`FUN_618e`:

1. **Translate**: subtract the object's origin (`$90`–`$95`, three 16-bit
   values) from the raw vertex coordinates, using full signed 16-bit
   subtraction with correct overflow/borrow handling (the classic 6502
   `SBC`-with-signed-overflow idiom, visible directly in the decompiled
   bit logic).
2. **Rotate**: multiply the translated `(dx, dy, dz)` by the 3×3 matrix —
   three dot products, nine multiply-accumulates total, each going through
   the shared multiply primitive.

```
X' = R00·dx + R01·dy + R02·dz
Y' = R10·dx + R11·dy + R12·dz
Z' = R20·dx + R21·dy + R22·dz
```

The result is written to an output buffer whose address is itself a
parameter (`$60` for a line's first vertex, `$68` for its second) — so the
same transform code serves both endpoints of a line.

## The shared multiply: `FUN_635c`

`FUN_635c` (`0x635c.c`) is a textbook **signed shift-and-add multiplier**:
handle the sign separately (XOR of the two operands' sign bits), convert both
operands to absolute value, then 15 rounds of "shift the accumulator right,
conditionally add the multiplicand" based on each bit of the multiplier,
finishing with a sign correction. The 6502 has no multiply instruction; every
single one of the nine rotation terms above costs this entire loop. This is
the most expensive, most-reused piece of code in the whole library — called
from the rotation-matrix build, the per-vertex transform, and the line-plane
clipping math.

## Clipping: 6-plane outcode + real parametric clipping

After transform, `FUN_67ef` (`0x67ef.c`) computes a 6-bit **Cohen-Sutherland
style outcode** for the vertex — one bit per violated frustum plane
(left/right/top/bottom/near/far), via repeated signed compares against bounds
stored at `$60`–`$65`. The VM checks this outcode (`DAT_0066`/`DAT_006e` for
the line's two endpoints) before deciding whether to plot anything at all —
fully-outside geometry gets rejected cheaply before it reaches the rasterizer.

When a line crosses exactly one violated plane, `FUN_6979` (`0x6979.c`) does
genuine **parametric line-plane clipping** — computing the intersection point
along the edge using the plane-crossing ratio, branching on which specific
plane(s) were violated (three near-identical code paths depending on the
outcode bits) and calling the shared divide routine to compute the ratio.
This is not nearest-edge clamping; it's the real Liang-Barsky-style
intersection math.

## Perspective: a genuine divide, not a lookup cheat

`FUN_68a1` (`0x68a1.c`), called right after transform+clip, is the projection
step. Given a pointer to a camera-space `(X, Y, Z)` triple:

1. Loads `Z` as the divisor.
2. **`FUN_6468(X_hi, X_lo)`** — divides `X` by `Z`.
3. Feeds the quotient into **`FUN_691e`** along with the constant `0x45` (69)
   — a fixed-point scale into pixel coordinates — producing the final screen
   X byte.
4. Repeats for `Y / Z`, with constant `0x5E` (94), producing screen Y.

`screenX = scale(X/Z, 69)`, `screenY = scale(Y/Z, 94)` — honest perspective
division. The two constants are most likely the half-width/half-height in
pixels of the cockpit's 3D viewport (smaller than the full 280×192 hi-res
screen — `STARSHIP SIMULATOR.bas`'s HUD gauge positions live around column
130–160, outside this window).

## The shared divide: `FUN_6468`

`FUN_6468` (`0x6468.c`) is the multiply's mirror image: a signed **15-round
restoring binary long division**, same sign-handling pattern (absolute value,
shift-and-subtract, sign-correct the result). It's reused for both the
clip-intersection ratio and the perspective divide — the second of the
library's exactly two hand-written arithmetic primitives, and everything
numeric in this engine is built from just these two routines.

## The plotter: a real Bresenham line drawer, confirmed by execution trace

The project's own `modern/web/public/data/debug/` directory already contained
a real AppleWin CPU execution trace (`a2-3d1-trace.json`) and a live memory
snapshot (`applewin-space-vikings-state.json`) from earlier work — neither
had been mined for this question before. Together they turn "the plotter is
somewhere in `$62F6`-`$7120`" into a confirmed, specific account.

**Finding the real write sites.** The trace's `hgrWrites` array records every
store to hi-res screen memory during a captured run: 187 writes, all landing
at exactly three program counters — `$6F13`, `$6FAC`, `$6FE8` — writing mask
values (`0x7C`, `0x7E`, `0x3F`, `0x7F`, `0x0F`, ...) that match constants
already visible in the decompiled pseudocode below. That pins the actual
pixel-plotting instructions precisely, instead of guessing from the self-mod
patch list alone.

**The shallow-slope octant — `FUN_6f03`/`FUN_6f9c`** (`0x6f03.c`/`0x6f9c.c`,
plus helpers `FUN_6f35`/`FUN_6f49`/`FUN_6fd5`): used when `|dx| >= |dy|`.
Steps the X byte-column every iteration, accumulating horizontal run-fill
masks (`0x30, 0x40, 0x60, 0x70, 0x78, 0x7C, 0x7E, 0x7F` — each one "fill from
bit N through bit 6"), and only advances the scanline pointer when the
Bresenham error term (`$B8`/`$B9`/`$BA`) overflows.

**The steep-slope octant — `FUN_7044`** (`0x7044.c`, 390 bytes, the single
largest function in the file): used when `|dy| > |dx|`. Mirror image of the
above — advances the scanline pointer every iteration, only moves X on
overflow, and walks the per-pixel color mask with `DAT_00b7 = (DAT_00b7<<2) |
(DAT_00b7>>7)`, an 8-bit rotate-left-by-2 that cycles `0xC0 -> 0x03 -> 0x0C ->
0x30 -> 0xC0 -> ...`.

**The shared "plot and step" primitive — `FUN_6fe6`** (`0x6fe6.c`, 4 bytes):
ORs a mask into the current screen byte, then advances the zero-page screen
pointer (`DAT_0099`) to the next scanline down. Its pointer math is the
classic Apple II hi-res scanline-address discontinuity, hand-coded directly
in zero-page arithmetic: add 4 to the pointer's high byte each line, and
correct by `-0x1B` or `-0x1F` whenever an 8-line or 64-line block boundary is
crossed. (Any Apple II hi-res tutorial covers why consecutive scanlines
aren't at consecutive addresses; this routine is that algorithm, written as
raw byte math with no comments, in 1982.)

**`FUN_6cda`** (`0x6cda.c`): straight-line clear of `$2000`-`$3FFF` — all of
hi-res page 1, 8KB, unrolled 32-bytes-at-a-time. The other half of a
double-buffered render loop.

**The data Ghidra never named.** Between `FUN_6979` (ends `$6B91`, a `JMP
$6848`) and `FUN_6cda` (starts `$6CDA`) sits 328 bytes Ghidra's auto-analysis
never resolved into a function, because it isn't code — three back-to-back
lookup tables, read directly from `extracted/LO-HI A2-3D1.payload.bin`:

| Range | Bytes | Content |
|---|---|---|
| `$6B92`-`$6BC1` | 48 | 24 little-endian 16-bit addresses: `$2000, $2080, $2100, ... $23D0` — the textbook Apple II hi-res "scanline group base address" table (3 groups of 8, offsets `+0, +0x28, +0x50`) |
| `$6BC2`-`$6C49` | 136 | Monotonic ramp, 0-39, period alternating 3/4 (`floor(2*i/7)`) — a byte-column lookup, almost certainly converting a half-pixel-precision X coordinate down to a hi-res byte column |
| `$6C4A`-`$6CD9` | 144 | The 7-value cycle `03 0C 30 C0 06 18 60` repeated ~20× — exactly the rotate sequence `FUN_7044` walks for its per-pixel color mask |

**Self-modification, confirmed, not guessed.** The live memory snapshot names
a `shipOpcode09Handler` at `$7148` — inside `FUN_7044`'s own address range.
Disassembling it by hand (`A2 2E C8 B1 9B F0 02 A9 20 18 69 20 85 A3 BD 93 6B
29 0F 05 A3 9D 93 6B CA CA 10 F2 ...`) shows a 23-iteration loop over the
24-entry address table above: `LDA $6B93,X` / `AND #$0F` / `ORA $A3` / `STA
$6B93,X` — reading and rewriting each entry's **high byte**, keeping its low
nibble and ORing in either `$00` or `$40` depending on an operand byte read
from the bytecode stream. That flips every table entry between `$20xx` (hi-res
page 1) and `$40xx` (hi-res page 2) in one pass — a double-buffer page-select
patch, not the per-pixel color-fringing patch this doc originally guessed
opcode 8/9/12 were doing (that guess came from the operand-patch *count*
alone, before any execution evidence existed). The trace backs this up
directly: all 187 of its captured writes land in `$4xxx` (page 2) in that
run, while `FUN_6cda` clears page 1 in parallel — a genuine page-flipped
double buffer. (Opcodes 8 and 12 are not yet confirmed to do the same thing
as opcode 9 — only 9 was directly named and disassembled here.)

This also explains something that looked like noise earlier: Ghidra's
decompile of `FUN_7044` and neighboring functions carries ~90 "Removing
unreachable block" warnings, clustered almost exactly over this plotter
region (`$61B7`-`$632A`, `$62BE`-`$62ED`, `$6D44`-`$6D89`, `$690F`-`$6919`,
`$70C6`-`$7143`). Static analysis can't resolve control flow that depends on
operands the program patches at runtime — so those warnings are, in effect,
independent corroboration from the decompiler's own confusion that
self-modification is real and concentrated right here.

## The full pipeline

```
bytecode opcode 5 (per-frame, 3 angle bytes)
  -> sin/cos table lookup ($609A, quarter-wave folded)
  -> combined Euler-angle rotation matrix
  -> optionally composed with a stored secondary rotation
       (skipped if ~identity -- real optimization)

bytecode opcode 0/1/2/3 (per vertex)
  -> translate (subtract object origin, signed 16-bit)
  -> rotate (3x3 matrix multiply, 9 terms, shift-and-add multiplier)
  -> 6-plane frustum clip test (Cohen-Sutherland outcode)
       -> parametric line-plane clip if partially visible
            (shift-and-subtract divide for the intersection ratio)
  -> perspective divide X/Z, Y/Z (same divide routine)
  -> fixed-point scale to viewport pixel coordinates
  -> hand off to the self-modifying hi-res line plotter
       (octant-selected Bresenham: FUN_6f03/FUN_6f9c shallow, FUN_7044 steep;
        FUN_6fe6 steps scanlines; opcode 9 page-flips the address table
        at $6B92 between hi-res page 1/2 for double buffering)
```

## What's confirmed vs. still open

**Confirmed, with specific function evidence:**
- The 4-entry public jump table and what each entry reaches.
- The bytecode VM structure and all 18 opcodes' general role.
- Real translate + 3×3 rotation per vertex.
- A genuine sine/cosine lookup table at `$609A` driving Euler-angle matrix
  construction, with optional composition against a second stored rotation.
- Real 6-plane frustum clipping with parametric line-plane intersection.
- Real perspective division (not a lookup-table shortcut).
- The two shared arithmetic primitives (`FUN_635c` multiply, `FUN_6468`
  divide) and that literally everything numeric reuses them.
- The hi-res line plotter itself: octant-selected Bresenham (`FUN_6f03`/
  `FUN_6f9c` shallow-slope, `FUN_7044` steep-slope), the shared scanline-step
  primitive (`FUN_6fe6`), the 328-byte unnamed data region at `$6B92`-`$6CD9`
  (scanline-address table, byte-column lookup, pixel-mask cycle), and the
  specific thing opcode `9`'s self-mod patch does — flip that address
  table's high bytes between hi-res page 1 and page 2 for double buffering
  — confirmed via a real AppleWin execution trace and live memory snapshot
  already in `modern/web/public/data/debug/`, not just static guesswork.

**Not yet traced:**
- Opcodes `8` and `12`'s self-modifying patches specifically — only opcode
  `9`'s target (`$7148`, the page-flip patch above) was directly named and
  disassembled; 8 and 12 are not yet confirmed to do the same thing.
- Jump-table entry 4 (`$653F`).
- Which BASIC/assembly caller actually feeds this VM a bytecode stream per
  frame, and where that stream is built — i.e., what in `SPACE SIMULATOR
  ASSEMBLY` or the BASIC overlays constructs the "draw this object" command
  list consumed here. (`STARSHIP SIMULATOR.bas`'s `P`/`B`/`H` variables —
  pitch/bank/heading, PEEKed from `$7321`–`$7323`, a region
  `analysis/comprehensive_memory_layout.md` currently lists as "unknown
  purpose" — are a strong candidate for the 3 angle bytes opcode `5`
  consumes; not yet directly confirmed by tracing the actual call site.)
- Exact relationship between this library and the 21 `PLANET # N` /
  `SHIP # N` shape files — whether they're consumed as this bytecode format
  directly, or converted into it by another routine.

## Source map

All function files referenced above live under
`rea-disassembly/LO-HI A2-3D1 (0x6000)/functions/`:

| Function | File | Role |
|---|---|---|
| `thunk_FUN_611c` | `0x6000` (thunk) | Entry 1 |
| `FUN_611c` | `0x611c.c` | Save/restore wrapper around the interpreter |
| `FUN_6140` | `0x6140.c` | Bytecode VM / opcode dispatch |
| `FUN_61a9` | `0x61a9.c` | Transform + plot first vertex |
| `FUN_618e` | `0x618e.c` | Transform + clip second vertex, shift line buffer |
| `FUN_672b` | `0x672b.c` | Translate + rotate a vertex |
| `FUN_633d` | `0x633d.c` | Multiply wrapper (loads two operand addresses, calls `FUN_635c`) |
| `FUN_635c` | `0x635c.c` | Shared signed shift-and-add multiply |
| `FUN_67ef` | `0x67ef.c` | Frustum outcode for point A |
| `FUN_6848` | (same cluster) | Frustum outcode for point B |
| `FUN_6979` | `0x6979.c` | Parametric line-plane clipping |
| `FUN_6468` | `0x6468.c` | Shared signed shift-and-subtract divide |
| `FUN_68a1` | `0x68a1.c` | Perspective projection (X/Z, Y/Z) |
| `FUN_691e` | `0x691e.c` | Fixed-point scale to viewport pixels |
| `FUN_654e` | `0x654e.c` | Rotation matrix rebuild from 3 angles |
| `FUN_64f8` | `0x64f8.c` | Sine/cosine table lookup (`$609A`) |
| `FUN_6cda` | `0x6cda.c` | Clear hi-res page 1 (`$2000`-`$3FFF`) |
| `FUN_6f03`, `FUN_6f9c` | `0x6f03.c`, `0x6f9c.c` | Shallow-slope line octant (plus helpers `FUN_6f35`/`FUN_6f49`/`FUN_6fd5`) |
| `FUN_6fe6` | `0x6fe6.c` | Shared "OR mask, step scanline" primitive |
| `FUN_7044` | `0x7044.c` | Steep-slope line octant; also houses opcode 9's self-mod patch (`$7148`) |
| (unnamed, data) | n/a — `$6B92`-`$6CD9` in `extracted/LO-HI A2-3D1.payload.bin` | Scanline-address table, byte-column lookup, pixel-mask cycle |

Generated via REA (Ghidra 12.1.2 backend) against
`extracted/LO-HI A2-3D1.payload.bin`, entry point `$6000`. See
`rea-disassembly/README.md` for regeneration instructions. The plotter
section above also used two pre-existing debug artifacts not generated by
this investigation: `modern/web/public/data/debug/a2-3d1-trace.json` (a real
AppleWin CPU execution trace, with `hgrWrites`/`flow`/`hotspots`) and
`modern/web/public/data/debug/applewin-space-vikings-state.json` (a live
memory snapshot with named key ranges including `shipOpcode09Handler`).
