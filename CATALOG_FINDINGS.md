# Space Vikings — Disk Catalog & Initial Memory Map

Findings from inspecting the 4am-cracked DSK image extracted from
`Space_Vikings__4am_crack_.zip`. Disk image is a standard 140 KB DOS 3.3
volume (35 tracks × 16 sectors × 256 bytes), volume number 254.

## What's on the disk

The disk holds **66 live files plus 3 deleted entries** (still
recoverable). Files break into clear groups.

### Boot chain (Applesoft BASIC)

| File | Sectors | Role |
|---|---|---|
| `START` | 19 | Main loader. ONERR-guarded, sets HIMEM, draws title screen, prompts (N)ew/(O)ld, BLOADs all binaries, RUNs `INSTRUMENTS`. |
| `INSTRUMENTS` | 6 | Draws cockpit HUD (speed/turn/energy panels, indicator labels), then either `RUN STARSHIP SIMULATOR` (new game) or `RUN GALAXY MAP` (old game). |
| `STARSHIP SIMULATOR` | 27 | Largest BASIC file. The main combat / piloting loop. **Disassembly priority #1.** |
| `GALAXY MAP` | 12 | Star-system selection screen on game resume. |
| `RADAR` | 6 | Radar overlay logic. |
| `COM` | 23 | "Master computer" / command-mode interface. Second-largest BASIC file. |
| `SHORE LEAVE` | 23 | Trading / loot-selling / outfitting screen. Tied with COM for second-largest. |
| `GROUND FORCES` | 20 | Planetary invasion / troop combat. |
| `H/D` | 10 | Hyperdrive (interstellar travel). |
| `SUPPLY` | 6 | Supply / inventory management. |
| `STATUS` | 9 | Status display (ship, faction, finances). |
| `COLLECT` | 9 | Loot / debris collection. |
| `ORBIT` | 5 | Orbital mechanics screen. |
| `RECALL` | 4 | Recall (transport beam-up?) screen. |
| `RE` | 4 | Unidentified — short, may be a redraw helper. |
| `DMG` | 2 | Damage report. |
| `EX` | 3 | Unidentified, possibly "exit" flow. |
| `S/X` | 3 | Unidentified, possibly "save/exit". |
| `END` | 5 | End-game / game-over. |
| `SHIP # 0/1/3/4 I.D.` | 3–8 | Per-ship identification text/screens. (Ship #2 is missing — possibly skipped intentionally; line 230 of START maps `J=2 → J=3`.) |

### Resident binaries (loaded at boot, stay in memory)

These are the files `START` BLOADs into specific addresses. The
catalog's stored load address for most of these is `$6000`, but every
single one is overridden via `BLOAD ...,A$xxxx` at runtime. The real
runtime addresses, harvested from `START.bas`:

| File | Real load addr | Length | End | Notes |
|---|---|---|---|---|
| `LO-HI A2-3D1` | `$6000` | `$1300` | `$72FF` | **SubLOGIC's A2-3D1 graphics library.** Disassembly priority #2. |
| `MEM DATA` | `$8BEC` | `$0352` | `$8F3D` | Lookup tables / constants for the engine. |
| `SPACE SIMULATOR ASSEMBLY` | `$9023` | `$0255` | `$9277` | Inner combat / 3D-render loop. **Disassembly priority #3** (small, hot). |
| `SOUND GEN` | `$9276` | `$004A` | `$92BF` | Sound-effect generator. *Note: starts 1 byte before SSA's nominal end (`$9277`). Either SSA's last byte is a sentinel that SOUND GEN overwrites, or one of the lengths is off by one.* |
| `LASER` | `$92D1` | `$001A` | `$92EA` | Laser-beam draw routine (very small, 26 bytes). |
| `HI-RES CHARACTER GENERATOR` | `$9300` | `$0100` | `$93FF` | Glyph plotter for in-game text overlays. |
| `MEM TRANSFER A` | `$9400` | `$0070` | `$946F` | Memory-block copy helper. |
| `SHIP'S DATA` (or `-M`) | `$9506` | `$0036` | `$953B` | Live ship state. Mutated during play. |
| `PLANET FILE` (or `-M`) | `$954C` | `$00AF` | `$95FA` | Live galactic state. Magic byte at `$95F7` (= 38391) — value `77` ($4D) means "saved game exists". |
| `TRANLIT.OBJ0` | `$9600` | `$035B` *on disk* | `$995A` *if fully loaded* | A2-3D1 transformation+lit (transform/literal/translation) helper. **Effective code is only `$9600`–`$97E0` (~481 bytes); the rest gets overwritten by P/F.** |
| `P/F` (or `-M`) | `$97E1` | `$0140` | `$9920` | Player-file: extended save state. **Overwrites the tail of TRANLIT.OBJ0.** |
| `CHARACTER TABLE` | `$8800` | `$0400` | `$8BFF` | 1 KB of 8×8 character bitmaps. |

### Per-frame swap binaries (loaded into the same buffer as needed)

`$7300` is reused as a sprite/scene buffer:

| File | Length | Purpose |
|---|---|---|
| `PLANET # 0` … `PLANET # 20` | `$021D`–`$05DC` each | One per planet. Loaded into `$7300` when the player approaches. **21 distinct planets.** |
| `DEBRIS` | `$0162` | Debris-field record, also at `$7300`. |

`$7879` is reused as the player's-ship sprite buffer:

| File | Length | Purpose |
|---|---|---|
| `SHIP # 1`, `SHIP # 3`, `SHIP # 4` | `$03C2`–`$0638` | 3D model data for the player's chosen ship. (Indices 0 and 2 absent — see note above.) |
| `SHIP # 0` | `$0001` | One-byte file at the same slot. Likely a placeholder/marker since ship 0 is also referenced by `SHIP # 0 I.D.` text. |

`$7FFF` is the enemy-data slot:

| File | Length | Purpose |
|---|---|---|
| `ENEMY I.A24580.L68` | `$0453` | Enemy definitions / sprites. The filename's `A24580.L68` is a vestigial label — `24580 = $6004`, `68 = $44`, suggesting an earlier development load address and a much smaller (initial?) length. The current file is 1107 bytes long. |

`$9270` slot:

| File | Length | Purpose |
|---|---|---|
| `EXPL` | `$0022` | Explosion sprite/animation (34 bytes). Catalog load addr `$9270` agrees here, but SSA/SOUND GEN sit nearby — needs verification when SSA is disassembled. |

`$954C` master copy used at new-game time:

| File | Length | Purpose |
|---|---|---|
| `PLANET FILE-M` | `$00AF` | Master planet table (read-only template loaded for new games). |
| `P/F-M` | `$0150` | Master player-file template. |
| `SHIP'S DATA-M` | `$0036` | Master ship-data template. |

### Save state

| File | Type | Purpose |
|---|---|---|
| `MISC FILE` | DOS 3.3 sequential text | Persistent save metadata. New-game contents (line 2050 of START): `100.3\r2000\r10000\r0\r\rE\r\r\r\r`. Likely fields: starting credits or position fraction, fuel, score-or-quota, plus an empty slot that becomes 'E'. |

### Deleted entries (recoverable)

- `SHIP #0 I.D.` (Applesoft) — older version of ship 0's ID screen.
- `SHIP'S DATA` (binary) — older ship-data file. *Note: a live `SHIP'S DATA` is also present, so the deleted one is genuinely a previous version.*
- `HD` (Applesoft) — possibly an older hyperdrive screen (renamed to `H/D` in current build).

These can be recovered if needed: their data sectors aren't yet
overwritten because all 70 files together fit comfortably on the disk.

## Memory map (post-boot, new game)

```
$0800-$1FFF   Applesoft BASIC program area (HIMEM=$2000)
$2000-$3FFF   Hi-res page 1 (the cockpit display)
$4000-$5FFF   Hi-res page 2
$6000-$72FF   A2-3D1 graphics library (LO-HI A2-3D1)
$7300-$78xx   Current planet record OR debris field (swap)
$7879-$7Exx   Player ship sprite (SHIP # n) — overwritten by DEBRIS if destroyed
$7FFF-$8442   ENEMY I.A24580.L68
$8800-$8BFF   CHARACTER TABLE
$8BEC-$8F3D   MEM DATA
$9023-$9277   SPACE SIMULATOR ASSEMBLY (the inner combat loop)
$9276-$92BF   SOUND GEN
$92D1-$92EA   LASER
$9300-$93FF   HI-RES CHARACTER GENERATOR
$9400-$946F   MEM TRANSFER A
$9506-$953B   SHIP'S DATA (live)
$954C-$95FA   PLANET FILE (live)
$9600-$97E0   TRANLIT.OBJ0 (effective code only)
$97E1-$9920   P/F (overwrites TRANLIT tail)
$9921-$95FF?  ...DOS 3.3 RWTS lives at $B700-$BFFF; hi-res page 2 above is $4000-$5FFF
```

(Ranges are tight: `$9920` to DOS 3.3 (`$9D00`+) leaves only ~1 KB of
free RAM at the top end, consistent with a 48 KB system fully packed.)

## Boot sequence (verified from `START.bas`)

1. `MAXFILES 1` — reduce DOS file buffers to maximize free RAM.
2. BLOAD `HI-RES CHARACTER GENERATOR` ($9300), `CHARACTER TABLE` ($8800), `PLANET FILE` ($954C).
3. Read magic byte `$95F7` (PEEK 38391). If `77` → saved game present.
4. Set ROT=1, SCALE=1, HGR, TEXT, HOME, draw title screen.
5. Prompt (N)ew/(O)ld game.
6. Set HIMEM `$2000`, define a slew of pointer constants (`XI=$7325`, `YI=$7327`, `ZI=$7329`, `P1=$732B`, `B1=$732C`, `H1=$732D`, `CSN=$6004`, `SN=$6007`, `M1=$600A`, `M2=$600B`, `DI=$8000`, `CA=$9023` — yes, `CA` points at `SPACE SIMULATOR ASSEMBLY`'s entry).
7. BLOAD `LO-HI A2-3D1` ($6000), `PLANET # 0` ($7300), `SPACE SIMULATOR ASSEMBLY` ($9023).
8. BLOAD `MEM TRANSFER A` ($9400), `MEM DATA` ($8BEC), `SOUND GEN` ($9276).
9. BLOAD `LASER` ($92D1), `ENEMY I.A24580.L68` ($7FFF), `TRANLIT.OBJ0` ($9600).
10. Set initial Z=−7000, X=700, Y=200 in the A2-3D1 origin pointers ($7325/27/29) — that's the player's starting position in 3D space.
11. New game: BLOAD `*-M` master files into live slots, POKE initial state, write `MISC FILE`. Old game: BLOAD live files, set magic byte.
12. POKE 38823 = (PEEK 38392 = saved-J), POKE 38824=0, CALL 38825 (= `$97C9`, inside what was TRANLIT but is now P/F territory — this CALL is the per-ship init).
13. Pick ship sprite: J = PEEK 38205 (in SHIP'S DATA); if J=2 then J=3 (ships 2 swapped with 3). If shields/condition allow, BLOAD `SHIP # n` at `$7879`; else BLOAD `DEBRIS` (player is wrecked).
14. `RUN INSTRUMENTS` → draws HUD → `RUN STARSHIP SIMULATOR` (new) or `RUN GALAXY MAP` (old).

## Verified game-state addresses

From the POKE/PEEK pattern in `START.bas`:

| Addr (hex) | Addr (dec) | Meaning |
|---|---|---|
| `$7325`/`$7326` | 29467/29468 | XI — player's X position (16-bit) |
| `$7327`/`$7328` | 29469/29470 | YI — player's Y position |
| `$7329`/`$732A` | 29471/29472 | ZI — player's Z position |
| `$732B` | 29473 | P1 — possibly pitch / phase 1 |
| `$732C` | 29474 | B1 — possibly bank / heading byte 1 |
| `$732D` | 29475 | H1 — heading low byte (poked to 0 in line 195) |
| `$6004` / `$6007` | 24580 / 24585 | CSN / SN — cosine / sine table base (A2-3D1 area) |
| `$600A` / `$600B` | 24588 / 24589 | M1 / M2 — matrix slots |
| `$8000` | 32768 | DI — pointer? (lives between hi-res page 2 and CHARACTER TABLE — possibly a free-RAM scratch) |
| `$9023` | 36899 | CA — entry to SPACE SIMULATOR ASSEMBLY |
| `$9543` | 38211 | Saved X (loaded into XI on resume) |
| `$9544` | 38212 | Saved X high |
| `$9545–$954B` | 38213–38219 | Saved Y, Z, P, B, H |
| `$953D` | 38205 | Saved ship index J (1, 3, or 4) |
| `$954A`–wards | 38209+ | Damage/condition flags array |
| `$95F7` | 38391 | Save-magic byte (`$4D` = 'M' = 77 dec — initial of "Mitchell"? a designer's signature) |
| `$95F8` | 38392 | Saved J for ship init |
| `$97C9` | 38825 | Per-ship init routine entry (in P/F area) |
| `$9602` | 38402 | TRANLIT entry called by INSTRUMENTS for new-game setup |
| `$9244` | 38188 | (Line 50: `POKE 38148,1` — actually $9504, inside SHIP'S DATA — flag byte) |
| `$95B4` | 38388 | Some flag, zeroed at 7500 |
| `$95B8` | 38392 | (already listed) |
| `$95BB` | 38395 | … (more state to be mapped) |

## Disassembly priority

1. **`SPACE SIMULATOR ASSEMBLY`** — only 597 bytes, called from BASIC, the heart of combat. Quick win.
2. **`LO-HI A2-3D1`** — 4864 bytes. Cross-reference against the published A2-3D1 manual to identify entry points (perspective transform, rotation, line-clip, hidden-line removal, etc.).
3. **`TRANLIT.OBJ0` (first 481 bytes)** — dispatch table at `$9600`–`$9602`, with sub-routines at `$9643`, `$966A`, `$96A5`, …
4. **`MEM TRANSFER A`** — 112 bytes. Block-copy primitive; will appear all over.
5. **`HI-RES CHARACTER GENERATOR`** — 256 bytes. Standalone glyph plotter.

The DATA-only files (`PLANET # n`, `SHIP # n`, `MEM DATA`, `CHARACTER TABLE`, `ENEMY`)
should be parsed *after* the engine code is understood — their format
will be revealed by the routines that consume them.

## Open questions remaining

- The "two-disk" question from the original dossier: **the cracked image is one disk, contains the full game including saves.** If a second disk exists physically, it's almost certainly a user-made backup or a save-disk with `MISC FILE` / `*-live` versions overwritten. Confirm only by inspecting the actual second disk image.
- Why is `SHIP # 0` only 1 byte? Possibly the player's starting "no special ship" sentinel, or a hangover from removed content (matches the deleted `SHIP #0 I.D.`).
- What's `RE` (4 sectors of Applesoft)? Loaded from where? Need to grep all BASIC for `RUN RE` / `CHAIN RE`.
- Is `EX` truly "exit" and `S/X` "save/exit"? Confirm by detokenizing.
- Does the game write back `PLANET FILE` on quit (the `BSAVE PLANET FILE,A$954C,L$AF` in line 26 only happens at boot if magic-byte check fails)? The save logic appears spread across multiple BASIC overlays.

## Source disk image vs. dossier expectations

| Dossier said | Reality |
|---|---|
| Single-sided 5.25" floppy | ✅ Confirmed: 140 KB DOS 3.3 image. |
| 4 protection-byte patches by Passport (T0/S2/$FC, T0/S3/$35, T0/S2/$5D, T0/S2/$9E) | The cracked DSK has standard `D5 AA 96` / `DE AA EB` marks — patches in place. The original `.edd` flux-style read in `extras.zip` (2.3 MB) preserves the protected version. |
| Built on A2-3D1 graphics library | ✅ Confirmed: file `LO-HI A2-3D1` exists and is BLOADed at `$6000`. |
