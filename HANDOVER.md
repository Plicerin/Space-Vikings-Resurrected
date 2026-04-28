# Space Vikings Reverse-Engineering — Handover

**Project:** Reverse-engineer SubLOGIC's *Space Vikings* (1982, Apple II)
toward a modern remake.
**Status as of handover:** Disk cataloged, file system fully extracted,
boot chain decoded, memory map drafted. Disassembly not yet started.
**Estimated effort to playable port from here:** 3-5 months part-time
(see "Estimate" section).

---

## 1. What you're inheriting

### The bundle

This handover ships with a zip containing everything generated so far:

```
spacevikings_handover.zip
├── README.md                          (this document)
├── CATALOG_FINDINGS.md                (detailed disk analysis)
├── original_uploads/
│   ├── Space_Vikings__4am_crack_.zip       (the 4am crack as received)
│   ├── Space_Vikings__4am_crack__extras.zip (flux dump + screencast)
│   └── Space_Vikings__4am_crack_.txt        (4am's crack notes)
├── disk_image/
│   └── Space Vikings (4am crack).dsk   (140 KB DOS 3.3 image, ready to mount)
├── extracted/                          (all 66 live files from the disk)
│   ├── *.bas                          (Applesoft BASIC, raw bytes)
│   ├── *.bin                          (BIN files including 4-byte DOS header)
│   ├── *.payload.bin                  (BIN files with header stripped — load these in your disassembler)
│   └── MISC FILE.txt                  (the save-state text file)
└── tools/
    ├── dos33_catalog.py               (DOS 3.3 catalog reader, standalone)
    ├── extract_files.py               (full extractor; produces extracted/)
    └── detok.py                       (Applesoft detokenizer)
```

### What's been done

1. **Both upload zips inspected.** The "extras" zip contains a `.edd`
   flux read of the original protected disk (2.3 MB), a 20 MB MP4
   screencast of 4am cracking it, and `Camtasia` project files. The
   main zip contains the cracked `.dsk` plus 4am's crack notes.
2. **Disk fully cataloged.** 66 live + 3 deleted entries, written up
   in `CATALOG_FINDINGS.md`.
3. **Every file extracted to disk** (see `extracted/`). BIN files have
   both header-included and payload-only versions ready for any
   disassembler.
4. **Boot chain traced end-to-end** — `START.bas` is fully detokenized
   and annotated. Real load addresses for every binary harvested from
   the BLOAD calls.
5. **Initial memory map drafted** (see `CATALOG_FINDINGS.md` §"Memory map").
6. **Save-state schema partially mapped** — magic byte at `$95F7`,
   ship/X/Y/Z fields at `$953D`-`$954B`.

### What's NOT been done

- No disassembly of any binary file. (Tools listed below; ready to go.)
- Only 2 of 19 BASIC overlays detokenized (`START`, `INSTRUMENTS`). The
  remaining 17 are extracted as raw bytes ready for `detok.py`.
- A2-3D1 manual not yet read.
- The `.edd` flux dump not yet inspected (would confirm the dossier's
  protection-byte claims).
- Three deleted files not yet recovered (data sectors are intact, but
  the recovery tool hasn't been written).

---

## 2. The asset, in one minute

*Space Vikings* (1982, Mitchell Robbins, SubLOGIC) is a 3D space
combat / trading / planetary conquest game for the Apple II. Single
side, 5.25" floppy, 140 KB DOS 3.3. The 4am crack from 2017 is
already byte-faithful to a clean DOS-3.3-readable version of the disk
— Passport stripped four protection bytes (modified address-prologue
marks on track 0). You can boot the `.dsk` directly in AppleWin /
Virtual ][ / MAME's `apple2ee` driver.

### Architecture

- **66 files**, structured as one BASIC launcher (`START`), one HUD
  drawer (`INSTRUMENTS`), and ~17 BASIC "screen overlays" (one per
  game mode: RADAR, COM, SHORE LEAVE, GALAXY MAP, HYPERDRIVE, etc.).
- **Resident binaries** loaded once at boot: `LO-HI A2-3D1` (the
  SubLOGIC 3D graphics library, 4.75 KB), `SPACE SIMULATOR ASSEMBLY`
  (597 bytes, the inner combat loop), `TRANLIT.OBJ0`, and small
  helpers totaling ~7-8 KB of 6502 code.
- **Swap-loaded data**: 21 planets and 4 ship sprites (3D model data
  consumed by A2-3D1) BLOADed into fixed slots as the player moves.
- **State** lives in `SHIP'S DATA` (`$9506`), `PLANET FILE` (`$954C`),
  `P/F` (`$97E1`), and `MISC FILE` (sequential text on disk).

### Why this is a friendly RE target

- Most gameplay logic is **Applesoft BASIC**, which detokenizes to
  near-readable source. Big head start over a pure-assembly title.
- The 3D engine (A2-3D1) **has a published manual** — see "Resources"
  below. You can identify library entry points by matching observed
  behavior to documented behavior, the easy way.
- The disk volume is **already cracked, no protection in the way**.
- Code is small overall: ~7-8 KB of 6502 + ~20 KB of detokenizable
  BASIC. A typical commercial Apple II game from the era is 20-40 KB
  of pure assembly.

---

## 3. What I'd do next, in order

This is the recommended path. Each step builds on the previous one.

### Step 1: Detokenize the rest of the BASIC overlays (~half a day)

The detokenizer is in `tools/detok.py`. Run it against everything in
`extracted/*.bas`. Files to prioritize, in roughly this order:

```
STARSHIP SIMULATOR  (27 sectors — main game loop, run on new game)
GALAXY MAP          (12 sectors — main game loop, run on resume)
COM                 (23 sectors — master computer / command interface)
SHORE LEAVE         (23 sectors — trading and outfitting)
GROUND FORCES       (20 sectors — planetary invasion)
H/D                 (10 sectors — hyperdrive)
STATUS, COLLECT, RADAR, SUPPLY, ORBIT, RECALL, RE, EX, S/X, END, DMG
SHIP # 0/1/3/4 I.D.
```

After this, you have ~70% of the gameplay logic in human-readable
form. You'll also discover the rest of the game-state addresses (the
`PEEK`/`POKE` calls map directly to memory).

### Step 2: Build the call graph (~1-2 days)

Each BASIC overlay ends with `RUN <NAME>` to transition to the next
mode. Greppable. Build a state machine showing:

- Which screen leads to which (e.g., `STARSHIP SIMULATOR` → `RADAR`
  on a key press, → `H/D` on hyperdrive command, etc.)
- What `CALL` addresses each overlay pokes through to in the assembly
  resident code
- Which game-state addresses each overlay reads vs. writes

This document IS most of the gameplay specification. Once it's done,
the port is mostly transcription.

### Step 3: Read the A2-3D1 manual (~half a day)

URL in the original dossier:
https://archive.org/details/sublogic-a2-3d1-animation-package-photocopy

Take notes on: documented entry points, their parameters, the model
data format (planet/ship files use this format), the matrix and
projection math.

### Step 4: Disassemble A2-3D1 (~3-4 weeks)

Load `extracted/LO-HI A2-3D1.payload.bin` into Ghidra (or your
disassembler of choice) at base address **`$6000`**. Set processor
to MOS 6502.

Strategy:
- Identify the routine table or jump table near the start
- Match each routine against the manual's documented entry points
- Label aggressively as you go
- Cross-reference back to the BASIC overlays — every `CALL <addr>`
  that lands in `$6000-$72FF` is an A2-3D1 call

### Step 5: Disassemble the inner combat loop (~1-2 weeks)

`extracted/SPACE SIMULATOR ASSEMBLY.payload.bin` at base `$9023`.
Only 597 bytes. Mostly glue calling A2-3D1 + per-frame state updates.
Then `TRANLIT.OBJ0.payload.bin` at `$9600` (only the first 481 bytes
are real code — see CATALOG_FINDINGS.md for the overlap quirk),
followed by the small helpers (`MEM TRANSFER A`, `LASER`, `SOUND
GEN`, `HI-RES CHARACTER GENERATOR`).

### Step 6: Parse the data files (~1 week)

Once A2-3D1's model format is understood, the `PLANET # n` and
`SHIP # n` files become trivial to parse. Convert them to JSON or
your remake's native format.

### Step 7: Write the port (~4-6 weeks)

In whatever language and engine. Keep the original memory layout in
mind for debugging — it's much easier to compare against AppleWin
running the original if your data structures are similar.

### Step 8: Test side-by-side (~2-3 weeks)

Boot the original in AppleWin, run your port, compare. Tune.

---

## 4. Key facts to internalize

These are the things I had to learn the hard way; here they are up
front so you don't have to.

### About the disk image

- **Catalog load addresses are LIES.** Almost every BIN file's
  embedded header says `$6000`, but `START.bas` overrides every
  single one with `BLOAD ...,A$xxxx`. **Always trust the BLOAD line
  in `START.bas`, never the BIN header.** The real addresses are
  tabulated in `CATALOG_FINDINGS.md`.
- The 4-byte BIN header (load_lo, load_hi, len_lo, len_hi) is at
  the *start* of `extracted/*.bin`. The `*.payload.bin` versions
  have it stripped — feed those to your disassembler.

### About the memory map

- Several files **deliberately overlap in memory**:
  - `SOUND GEN` (`$9276`) starts 1 byte before `SPACE SIMULATOR
    ASSEMBLY` (`$9023`+`$255` = `$9278`). Either intentional or one
    length is off by one. Verify when disassembling SSA.
  - `P/F` at `$97E1` overwrites the tail of `TRANLIT.OBJ0` at
    `$9600`+`$3SB` = `$995A`. **Only the first 481 bytes of
    TRANLIT.OBJ0 are live code**; the rest is dead weight on disk.
- `EXPL` is loaded somewhere around `$9270` per the catalog header,
  but `START` doesn't BLOAD it explicitly — meaning either some
  *other* BASIC overlay loads it (likely COM or STARSHIP SIMULATOR),
  or it's loaded by `CALL` of a routine that reads it from disk
  on demand. Open question.

### About the boot prompt

`START.bas` line 60 prompts "(N)EW GAME OR (O)LD GAME?" The "old
game" path is gated by reading the magic byte at `$95F7` (= 38391):
if it's `77` decimal (= `$4D` = ASCII 'M' — possibly Mitchell
Robbins' initial), there's a save. Set this byte to anything else
and "old game" pretends no save exists.

### About ship indices

Ships are numbered 0, 1, 3, 4 — **there is no ship 2**. Line 230 of
`START` explicitly maps `J=2 → J=3`. Ship 0 is a 1-byte file
(probably a sentinel for "starter ship, no special model"). Plan
for this in the remake's UI.

### About save state

Two parallel save mechanisms coexist:
- `MISC FILE` (sequential text, DOS-3.3-OPEN/WRITE/CLOSE) — five
  numeric fields plus an `E`. Likely score/credits/fuel summary.
- `PLANET FILE` / `SHIP'S DATA` / `P/F` (binary BSAVEd) — the actual
  game world. Re-saved as live versions, with the magic byte set, on
  game-save.
- The `*-M` "master" versions are read-only templates loaded only
  when starting a new game.

### About 4am's work

The crack was *automated* by Passport. Four bytes were patched on
track 0:

```
T00,S02,$FC: DA -> AD   (address epilogue mark)
T00,S03,$35: ED -> DE   (address prologue mark)
T00,S02,$5D: DA -> AD   (address epilogue mark)
T00,S02,$9E: ED -> DE   (address prologue mark)
```

These are all standard DOS 3.3 sector-marker bytes that SubLOGIC
modified as copy protection. Nothing in the *game logic* was
changed — disassembly findings will reflect Robbins's original
1982 code.

### About the manual's published gameplay terminology

Use the manual as your authoritative naming reference when labeling
disassembled routines. Manual vocabulary: ship, planet, troops,
star, federation, radar, hyperdrive, base, command, space, star
system, shore leave, space bar, light indicators, command mode,
master computer, sell loot. **Most BASIC overlay names map 1:1 to
this vocabulary** — `RADAR`, `H/D`, `GALAXY MAP`, `SHORE LEAVE`,
`COM` (= command mode / master computer), etc.

---

## 5. Tools

### Already written (in `tools/`)

| Tool | What it does |
|---|---|
| `dos33_catalog.py` | Print the VTOC and full catalog of any DOS 3.3 disk image. Standalone, no dependencies. Usage: `python3 dos33_catalog.py <image.dsk>` |
| `extract_files.py` | Extract every file from the disk to a directory, separating BIN headers from payloads. Hard-coded for the Space Vikings disk path; edit if you re-run. |
| `detok.py` | Detokenize Applesoft BASIC files. Usage: `python3 detok.py FILE1.bas FILE2.bas …` (paths relative to the `extracted/` directory). |

These are deliberately minimal and easy to read. Adapt as needed.

### Recommended external tools

- **CiderPress II** (cross-platform CLI): more powerful disk
  inspection, can convert formats, handles `.po` and `.do`
  variations. Not strictly needed since we already have everything
  extracted, but useful for sanity-checking.
- **Ghidra** with the 6502 processor module: best free 6502
  disassembler with cross-references and labeling. Set processor
  to "6502" or "65c02" depending on Apple II target (Apple II Plus
  is plain 6502).
- **AppleWin** (Windows; runs under Wine on Linux/Mac): emulator
  with a built-in debugger. Boot the `.dsk`, then break on memory
  reads/writes to specific addresses to confirm disassembly findings
  empirically. Indispensable.
- **a2rchery**: convert the `.edd` flux dump in `extras.zip` to
  `.woz` if you want to study the original protection scheme
  byte-faithfully. Not needed for the remake.

---

## 6. Resources

| Resource | URL |
|---|---|
| 4am crack landing page | https://archive.org/details/SpaceVikings4amCrack |
| Manual (primary, 600 PPI scan, 20 pages) | https://archive.org/details/space_vikings_manual |
| Manual (alternate, 11 pages) | https://archive.org/details/Space_Vikings_manual_subLOGIC |
| Manual supplement | https://archive.org/details/space_viking_manual_supplement |
| **A2-3D1 graphics package manual** (essential for Phase 4) | https://archive.org/details/sublogic-a2-3d1-animation-package-photocopy |
| Flux reads (for protection analysis) | https://archive.org/details/flux_reads_january_2023 |
| Boot video (visual reference) | https://archive.org/details/A2Video_Space_Vikings |
| MyAbandonware page | https://www.myabandonware.com/game/space-vikings-7nc |
| GameFAQs page | https://gamefaqs.gamespot.com/appleii/216469-space-vikings-1982 |

---

## 7. Estimate to playable port

**Solo, part-time (10-15 hrs/week), with 6502 experience: 3-5 months.**
**Same conditions, no 6502 experience: 6-10 months.**
**Full-time, skilled: 6-10 weeks.**

Phase breakdown (part-time numbers):

| Phase | Duration | What you produce |
|---|---|---|
| 1. Finish detokenizing BASIC + build call graph | 2 weeks | Gameplay rules in prose; state-transition diagram |
| 2. Disassemble A2-3D1 against its manual | 3-4 weeks | Annotated 3D library; planet/ship file format spec |
| 3. Disassemble inner loop + helpers | 1-2 weeks | Annotated SSA, TRANLIT, MEM TRANSFER A, LASER, etc. |
| 4. Write modern reimplementation | 4-6 weeks | Playable port |
| 5. Polish & side-by-side test against original | 2-3 weeks | Released version |

What could blow this up:

- **A2-3D1 turning out to be a customized fork**, not the documented
  library. Doubles Phase 2.
- **Self-modifying code** in the inner loop. Plausible but not yet
  observed.
- **You wanting bit-exact behavior** (vs. "looks and plays the
  same"). Bit-exact roughly doubles total time.

What could shrink it:

- AI-assisted disassembly (working with Claude or similar) saves
  ~30-50% on Phases 2-3.
- Choosing a low-level target language (C, Rust) that mirrors the
  original memory layout, vs. a high-level engine port (Unity,
  Godot) that needs scene-graph reconciliation.
- Skipping the asset-format conversion step and parsing original
  binary files at runtime.

---

## 8. Open questions remaining

These need answers; rough priority order:

1. **Is the A2-3D1 in this disk the stock library, or a customized
   fork?** Compare disassembly to manual entry points. (Phase 2
   finding.)
2. **Where does `EXPL` get loaded?** Not in `START`. Some other
   overlay must BLOAD it on demand. Likely `STARSHIP SIMULATOR` or
   `COM`.
3. **What's `RE` (4 sectors of Applesoft)?** Name suggests a redraw
   helper but unconfirmed. Detokenize it.
4. **What are `EX` and `S/X`?** Probably exit and save-and-exit
   overlays; confirm by detokenizing.
5. **Is there self-modifying code in `SPACE SIMULATOR ASSEMBLY`?**
   The 1-byte overlap with `SOUND GEN` is suspicious.
6. **What are the `MISC FILE` field semantics exactly?** The
   new-game write is `100.3 / 2000 / 10000 / 0 / E`. The `100.3`
   in particular is unusual (a decimal in a save file).
7. **Does the original disk really have only those 4 protection
   bytes?** The `.edd` flux dump in `extras.zip` would let you
   verify against the dossier's claim. Not strictly necessary for
   the remake.
8. **Are the 3 deleted files (`SHIP'S DATA`, `SHIP #0 I.D.`, `HD`)
   meaningfully different from their live counterparts?** Cute but
   probably not gameplay-relevant.

---

## 9. Words of caution for the next person

- **Trust the manual over your intuition** when labeling routines.
  The naming conventions of 1982 SubLOGIC don't always match modern
  expectations.
- **The BASIC overlays will fool you with sloppy code**. Robbins
  uses `PEEK`/`POKE` extensively rather than DEF FN or DATA
  statements. Single-letter variable names are the norm. Read
  carefully.
- **Don't rewrite the 3D math from scratch.** A2-3D1 has subtle
  behaviors (overflow, fixed-point precision) that affect gameplay
  feel. Match the library's behavior, then optimize.
- **The high bits in Applesoft tokens / DOS filenames are
  deliberate**, not corruption. The detokenizer and catalog reader
  already handle this; don't strip them blindly elsewhere.
- **The `.edd` file is NOT a `.dsk`.** It's a flux-style preservation
  format; needs `a2rchery` or similar to convert to `.woz` before any
  emulator will read it.

---

## 10. Sanity check before you start

If you can do all of these, you're ready:

- [ ] Boot `disk_image/Space Vikings (4am crack).dsk` in an Apple II
      emulator and play for at least 10 minutes. Read the manual
      first.
- [ ] Run `python3 tools/dos33_catalog.py disk_image/Space\ Vikings\ \(4am\ crack\).dsk`
      and confirm you see 69 catalog entries.
- [ ] Run `python3 tools/detok.py START.bas` from inside `extracted/`
      (or update the path) and read the boot logic top-to-bottom.
- [ ] Open `extracted/LO-HI A2-3D1.payload.bin` in a hex editor and
      confirm it's 4864 bytes (`$1300`).
- [ ] Read `CATALOG_FINDINGS.md` end-to-end.

After that, start with Step 1 in §3.

Good luck. The asset is small and the structure is unusually friendly.
This is one of the more pleasant RE targets you'll find from the era.
