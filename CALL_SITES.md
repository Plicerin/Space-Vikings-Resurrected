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

**Line numbers** in every table are BASIC line numbers. (Until the
2026-11-10 reconcile the flight-loop table used each line's position in
the detokenized text file instead, so its "69" was BASIC line 500.)
A ✅ with no date carries over from an earlier pass and was not
re-checked against the port in the reconcile.

---

## Layers, and the 2026-11-10 reconcile

This file is hand-written interpretation. Underneath it now sits a
machine-generated structural map that covers all 23 programs:

| What | Where |
|---|---|
| Every DOS command, `CALL` site, vector install, PEEK/POKE address and branch | `analysis/BASIC_CALL_MAP.md` (+ `basic_callmap.json`), written by `tools/basic_callmap.py` from the tokenized programs in `extracted/*.bas` |
| Independent re-count of that map, and the key-dispatch block run once per key through a small Applesoft interpreter | `tools/verify_callmap.py` |
| 6502 disassembler used for the machine-code side | `tools/dis6502.py` (`tools/disassemble_simple.py` gets instruction lengths wrong; listings made with it are not reliable) |
| Live check in MAME of the keys and the record copy | `tools/mame/keys_live.lua`, reference log `analysis/keys_live.log` |
| The new-game data tables | `tools/newgame_data.py` |

The map was built without reading this file, then compared with it.
Five things earlier versions of this file stated as settled were wrong:

| Earlier claim here | What is true | How it was checked |
|---|---|---|
| The in-flight hyperdrive key (line 209) is dead code, so having no such key in the port is faithful | **`H` is a live key.** `IF K<34 THEN 207` sends it to line 207, and 209 is two lines *after* 207, not skipped by it | interpreter run per key; live: `H` with a course set spends energy and changes planet; manual p. 8 ("Use the H key to engage the hyperdrive engines") |
| `CALL 38402` is a cosmetic HUD flicker with six chained modes | It is the **A / B / S / W key handler**: four gameplay toggles (autopilot, condition, shields, weapon) that also draw their panel lights. Nothing chains | full disassembly; live: each key flips its own byte; manual p. 8 |
| `CALL 38825`'s callee is unresolved (guessed: a ship-sprite init) | It **copies one planet's record** between the `P/F` table and the working registers 38204-38219 | full disassembly; live: registers change to the new planet's record on arrival |
| `$38205` (defender type) is a transient global nothing sets, so re-rolling it on travel is the right port | It is **byte 1 of the per-planet record**: fixed per planet, persistent between visits | same as above; the data in `P/F-M` |
| The planet coordinates don't look real (`1,1,255,255` repeating) | That was `PLANET FILE`, this disk's **saved-game slot**. The new-game galaxy is in the `-M` master files and is ordinary data | `START.bas` 2000-2020 loads the `-M` files; `tools/newgame_data.py` |

Also corrected: `38210` is the **in-atmosphere flag** (`RE.bas` sets it,
`ORBIT.bas` clears it; it drives the panel's ORBIT light), not an
"in combat" flag.

---

## 6502/DOS asm-level call tricks — mechanisms the surface syntax hides

Applesoft's own call keywords (`GOSUB`, `CALL`, `ON...GOTO`) are only
part of how these programs hand control around. A 1 MHz 6502 running a
real-time flight loop has every reason to use something cheaper than a
general call, and the game does, in four ways. None of them is spelled
as a call, so a reader following `GOSUB`s and `CALL`s misses them.

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
63999* (not Integer BASIC: this disk's DOS has `INT` pointed at its own
"SYSTEM ERROR! / PRESS ANY KEY TO REBOOT" screen, see the END.bas
section) all go through this exact convention. None of it is a real Applesoft
statement underneath — it's BASIC code typing at DOS through the
character-output hook, disguised as print statements. A line-by-line
read that doesn't know this convention misreads every one of these as
inert text, which is exactly how `H_D.bas`'s own star-burst went
unnoticed for so long.

**This is the real scene-transition graph** — nothing in Applesoft's
own `GOTO`/`GOSUB` reaches across file boundaries, so this hidden
chain-load convention *is* the entire state machine the game runs on.
Extracted mechanically from every file's hidden-byte strings, the two
hubs:

| From | `RUN`s to |
|---|---|
| `STARSHIP SIMULATOR.bas` (main flight) | `RE` (re-entry, 156), `ORBIT` (158), `H/D` (209, the `H` key), `COM` (319), `RADAR` (320), `EX` (explosion/destroyed, 1560), `S/X` (ship destroyed, 3350), `DMG` (damage-control overlay, 3360) |
| `COM.bas` (command console hub) | `GROUND FORCES` (98/115/127), `STARSHIP SIMULATOR` (130), `END` (132), `RADAR` (133), `GALAXY MAP` (1172/3000), `STATUS` (1200), `SUPPLY` (20000) |

Plus a ground-campaign loop (`GROUND FORCES` ↔ `COLLECT`/`RECALL`/
`SHORE LEAVE`), a boot chain (`START` → `INSTRUMENTS` → `STARSHIP
SIMULATOR`), and `GALAXY MAP`/`RADAR`/`H_D` each chaining back to
`COM`/`STARSHIP SIMULATOR` on exit. This is infrastructure Godot's own
scene tree replaces (`GameState.goto_scene`). The chain is not free of
effects, though: each `RUN` is a disk load of several seconds during
which the last picture stays up, and the next program starts from
whatever the last one left on the page and in the text window. The
faithful ports keep both (measured loads, shared page and window); the
stand-in screens do not.

Two more spellings of the same thing, both tracked by the mapper:
five programs (`COLLECT`, `GROUND FORCES`, `H_D`, `RECALL`, `SHORE
LEAVE`) set `D$ = CHR$(4)` and write `PRINT D$;"RUN COM"`, with no
Ctrl-D in the string at all; and `RADAR.bas` 5005 builds the name at
run time (`"RUN SHIP # ";J;" I.D."`). The whole corpus holds 169 DOS
commands. The non-`RUN` ones are in section 2 of the generated map;
the ones that matter for state are the `MISC FILE` reads and writes
(stardate, troops, credits as three text lines): written by `START`
2050, `H_D` 6, `GROUND FORCES` 670/800/1120 and `SHORE LEAVE`
2096/2160/2290/2460/2620, read by `GROUND FORCES` 11, `RECALL` 11,
`SHORE LEAVE` 11, `STATUS` 5000, `SUPPLY` 5000 and `H_D` 6.

**The flight loop's key dispatch** (`STARSHIP SIMULATOR.bas` lines
200-210, 311-321, 500). This table is computed, not traced by eye:
`tools/verify_callmap.py` runs those lines once for each of the 128
key codes and groups the outcomes.

| Key | Lines taken | Effect | Port |
|---|---|---|---|
| `1` `2` `3` `4` | 201 → `GOSUB` 311-314 → 207-210 | speed −3 / +3 / −15 / +15, clamped to 0..120 | ✅ the same keys, `flight_program.gd::keys()` (the stick is the arrow keys, so that W, S, A and B keep their original meanings) |
| `A` | 203 → 317 → 500 | `POKE LT,4: CALL 38402` — autopilot on/off | ✅ `keys()` → `tranlit(4)` |
| `B` | 203 → 318 → 500 | `POKE LT,3: CALL 38402` — step the condition | ✅ `keys()` → `tranlit(3)` |
| `C` | 203 → 319 | `RUN COM` | ✅ leaves flight for the command console (see `COM.bas` below) |
| `H` | 204 → 207 → 208 → 209 | `RUN H/D` — hyperdrive | ✅ `flight_loop.gd::_hyperdrive()`, held to a live recording (`tests/check_jump.gd`) |
| `R` | 206 → 320 | `RUN RADAR` | ✅ leaves flight for the radar (see `RADAR.bas` below) |
| `S` | 206 → 321 → 500 | `POKE LT,1: CALL 38402` — shields on/off | ✅ `keys()` → `tranlit(1)` |
| `W` | 205 → 500 | `POKE LT,2: CALL 38402` — missile/laser | ✅ `keys()` → `tranlit(2)` |
| any other key | … → 210 | nothing | ⬜ |

Line 500 is `CALL 38402: GOTO 1`, so each of the four toggles also
restarts the flight program from its first line (ported:
`flight_program.gd::_restart()`).

The real navigation flow is therefore three steps, all working in the
original: set a course in the Navigation Computer (`COM.bas` 860-897,
`POKE 38163,n`), return to flight, press `H`. `H_D.bas` line 1 sends
you straight back to flight if you are in the atmosphere, have no
course, or are already there. Live: `H` with no course changed nothing;
after `38163=2`, `H` took energy 63 → 59, marked planet 2 scouted and
changed the current planet 1 → 2.

### 2. `POKE 38167,n` (`LT`) then `CALL 38402` — the panel-toggle handler

`CALL 38402` always enters `TRANLIT.OBJ0` at `$9602`. Which of four
routines runs is chosen by a byte BASIC pokes first, so a reader who
only follows `CALL` targets sees one opaque call where there are four
different actions. Disassembled in full with `tools/dis6502.py`
(`tools/dis6502.py extracted/TRANLIT.OBJ0.payload.bin 9600`):

```
TRANLIT($9602):
    if PEEK(38189) == 10:              # $952D, "redraw everything"
        POKE 38189, 0
        mode1(); mode2(); mode3(); mode4(); orbit_light(); damage_light()
        return
    match PEEK(38167):                 # $9517 = LT
        1: mode1()                     # $9643
        2: mode2()                     # $966A
        3: mode3()                     # $96A5
        4: mode4()                     # $96DF

mode1():  shields   $9539 (38201):  0 -> 1, 1 -> 0;       draw SHIELD light
mode2():  weapon    $953A (38202):  0 -> 1, 1 -> 0;       draw MISSILE and LASER lights
mode3():  condition $9515 (38165):  2 -> 3, 3 -> 1, else -> 2;  draw COND light
mode4():  autopilot $9514 (38164):  0 -> 1, 1 -> 0;       draw MANUAL and AUTO lights
orbit_light():   draw ORBIT light from $9542 (38210), no state change
damage_light():  draw DAMAGE light from $95F9 (38393), no state change
```

The four `CMP`/`BNE` tests run one after another without reloading
the mode, which is what an earlier decompile read as "chaining"; no
routine returns a value that matches a later test. The shared drawer
at `$9754` writes a 2-byte-wide, 5-row colour bar straight into hi-res
page 1 through a self-modified `STA` operand (`$9773/$9774`), taking
bar patterns from `$9793-$97A6`. The lights sit in the two panel rows
the manual's screenshot shows: MANUAL, AUTO, ORBIT, DAMAGE at y ≈
153-157 and MISSILE, LASER, COND, SHIELD at y ≈ 161-165. `GALAXY
MAP.bas` 5000-5160 paints the same lights in BASIC without touching
the flags, as plain 10-dot blocks (`HPLOT LX,J TO LX+9,J` for five
rows) and not TRANLIT's 14-dot bars, so the panel looks slightly
different after the star chart or a loaded game until a key redraws a
light (ported: `chart_program.gd::lamp_blocks()`).

What each flag gates in the flight program:

| Flag | Values | Read at | Effect | Port |
|---|---|---|---|---|
| shields `38201` | 1 = up | 3205 | a hit always wears the shield (`38200`) down; with shields up and shield strength above 10 it stops there, otherwise the other systems and the hull take damage | ✅ `GameState.shields_up`, `flight_combat.gd::_wear()`, `_shield_holds()` |
| weapon `38202` | 1 = missile | 1501 | the fire button launches a missile (line 1000) instead of the laser | ✅ `missile_mode_active` |
| condition `38165` | 1 GREEN, 2 BLUE, 3 RED | 5200; `STATUS.bas` 1280-1294 | only at RED do the turrets shoot at an incoming fighter attack (5200-5251: 30% to destroy it, costing the enemy one fighter) | ✅ `GameState.condition`, `combat_fx.gd::fighter_pass(turrets_armed)` |
| autopilot `38164` | 1 = auto | 15 | skips line 19, so the paddles are not read and `38397/38398` keep their last values | ✅ `GameState.autopilot_active`, `flight_program.gd::fly()` |

**The redraw-all path changes state.** `INSTRUMENTS.bas` 210 pokes the
sentinel and calls once on a new game (`PEEK(38391)<>77`; a loaded
game and the return from the star chart go through `GALAXY MAP.bas`
5000 instead, which only draws). Because that path runs the four toggle routines, it
flips all four flags as it draws them. Live on a fresh boot:
autopilot 1 → 0, condition 2 → 3, shields 1 → 0, weapon 0 → 1. So a
new game enters flight under manual control, at condition RED, with
**shields down** and **missile selected**. Whether that was intended or
is a side effect of reusing the toggles to draw, it is what the game
does. Port: ✅ all four start states (`start_new_game()`).

`STATUS.bas` 1386 reads `38167` (the mode byte) as the high byte of
what looks like a troop count. Settled live: it is no count, and the
line cannot print (the STATUS table below).

### 3. `POKE 38823,<planet>: POKE 38824,<mode>: CALL 38825` — the per-planet record copy

Applesoft's `CALL` takes no parameters; this routine takes two through
fixed bytes poked just before the call. Disassembled (`$97A9`-`$97E0`):

```
PLANET_RECORD(planet = PEEK(38823), mode = PEEK(38824)):
    record = table[planet - 1]           # 21 pointers at $9931: $97E1, $97F1, ... 16 apart
    for i in 0..16:                      # 17 bytes, one more than a record holds
        if mode == 0: POKE 38204 + i, record[i]      # load
        else:         record[i] = PEEK(38204 + i)    # store
```

The table is the `P/F` file (`BLOAD ...,A$97E1`). Four call sites:

| Site | Planet | Mode | Meaning |
|---|---|---|---|
| `START.bas` 220 | `PEEK(38392)` | 0 | load the planet the game starts or resumes at |
| `H_D.bas` 12 | `PEEK(38209)` (current) | 1 | store the planet being left |
| `H_D.bas` 25 | `PEEK(38163)` (target) | 0 | load the planet being entered |
| `END.bas` 210 | `PEEK(38209)` | 1 | store before the three `BSAVE`s |

The record, by the register each byte lands in:

| Byte | Register | Meaning |
|---|---|---|
| 0 | 38204 | defender destruction threshold (line 1560: `DP > PEEK(38204)` → `RUN EX`). `H_D.bas` 93 replaces it with tech × 60 on arrival when tech > 1 |
| 1 | 38205 | orbital defender type: 0 none, 1 space lab, 3 light cruiser, 4 heavy cruiser. A stored 2 is drawn and described as 3 everywhere (`START` 230, `H_D` 38, `ORBIT` 31, `RADAR` 5002). `EX.bas` 30 zeroes it when the ship is destroyed |
| 2 | 38206 | × 500 = enemy ground troops (`GROUND FORCES.bas` 500). `H_D.bas` 105 zeroes it after every arrival, so the stored values only apply at the starting planet ❓ |
| 3 | 38207 | enemy fighters (gates incoming attacks at 190/192; `EX.bas` 56 halves it; 5250 takes one) |
| 4 | 38208 | planet has surrendered |
| 5 | 38209 | planet number (`H_D.bas` 26 pokes it as well) |
| 6 | 38210 | in-atmosphere flag |
| 7-15 | 38211-38219 | ship position and attitude (`29467-29475`), filled only by `END.bas` 200-202 before a save and read back by `START.bas` 225 |

**So the defender, its fighters and the surrendered state belong to the
planet**, and come back as you left them. Live: arriving at planet 2
changed the defender 3 → 2, the threshold 150 → 100 (then 180 from
line 93) and surrendered 1 → 0. Port: ✅ 2026-11-10,
`GameState.store_planet_record()` / `load_planet_record()` for bytes
0, 1, 3 and 4, called from the hyperdrive (`flight_program.gd`,
`jump_ready()` and `jump_arrive()`), `start_new_game()`,
`save_to_disk()` and `load_from_disk()`; the random re-roll is gone.

**An original bug, ported:** the 17th byte copied is 38220, which
is `38219+1` — planet 1's entry in the secured array — and on the
record side it is byte 0 of the *next* planet's record (at planet 20,
the byte after the table, `$9921`, 255 in `P/F-M`). Every load
overwrites SOL's secured flag with the next planet's threshold, and
every store writes it back over that threshold. Live: SOL's flag went
1 → 100 the moment `START` loaded record 1, and 100 → 150 on arrival
at planet 2. `GALAXY MAP.bas` 3066 tests `= 1` and `COM.bas` 1120
tests `= 0`, so SOL is white (not secured) on the chart and "HAS BEEN
SECURED" in the directory. The saved-game slot on this disk shows the
store side: record 2's byte 0 is 1. Port: ✅ 2026-11-10,
`GameState.planet_secured` holds the byte and the two functions carry
the seventeenth (`planet_record_overrun` past the table). It was
ported after the star chart's page differed from the live one by five
bytes, SOL's mark; `check_flight_passes` and `check_jump` now compare
the byte on every pass, and `check_save` the store side.

**New-game data** (`tools/newgame_data.py`; `PLANET FILE-M` arrays are
read as base + planet number, `P/F-M` is the record table):

```
 P name              tech  pop  sec  sct base    x    y    z  def  thr  gnd  ftr surr
 1 SOL                  3  125    1    1    1   15   15   15    3  150  100   30    1
 2 ALPHA CENTAURI       3   70    0    0    0   13   13   12    2  100   50   20    0
 3 BARNARD'S STAR       3  175    0    0    0   14    9   15    3  150  120   22    0
 4 WOLF 359             0    0    0    0    0    8   16   12    0    0    0    0    1
 5 LUYTEN               2   90    0    0    0   22   14   19    1   20   20    0    0
 6 LALANDE 21185        1    3    0    0    0   13   22   19    0    0    5    0    0
 7 SIRIUS               4  200    0    0    0   17   23   12    4  200  150   20    0
 8 VARCAR               2  150    0    0    0   14    8    9    1   20  100    0    0
 9 XANADON              3   85    0    0    0   19   13   25    2  100  100   40    0
10 EPSILON ERIDANA      4  157    0    0    0   20   22   10    3  150  120   25    0
11 CYGNI                0    0    0    0    0    9   23   20    0    0    0    0    1
12 PROCYON              1    1    0    0    0    7   23   14    0    0    0    0    1
13 TAU CETI             4  165    0    0    0   25   21   13    4  200  200   50    0
14 LACAILLE 9352        2    6    0    0    0   25   15   21    1   20    7    0    0
15 LARSEN-C             0    0    0    0    0    9   21   19    0    0    0    0    1
16 GROOMBRIDGE 1618     3   80    0    0    0   25    5   11    2  100   95   20    0
17 KRUGER 60            3  130    0    0    0   24   10   10    3  150  100   40    0
18 EPSILON INDI         3  155    0    0    0   11   18   27    3  150  115   26    0
19 ARGO                 1    2    0    0    0   18   27   11    0    0    5    0    0
20 SHIVANDA             2    7    0    0    0   11   11   25    1   20   15    0    0
```

tech `38282+P`, pop `38261+P` (× 35294 for display), sec(ured)
`38219+P`, sc(ou)t(ed) `38240+P`, base `38303+P`, x/y/z `38366+P` /
`38345+P` / `38324+P`; def, thr, gnd, ftr, surr are record bytes 1, 0,
2, 3, 4. Port: ✅ 2026-11-10 as `GameState.NEW_GAME_*` and
`PLANET_X/Y/Z`. **Before this the port had no galaxy data at all**:
every planet was tech 0 with population 1, which made every planet
"non habitable" to Ground Forces and ineligible for flight combat.

### 4. A `POKE`d vector — installing a routine with no `CALL` at all

Two sites hand control to machine code or data by writing a two-byte
pointer the firmware follows from then on:

| Site | Vector | Points at | Effect |
|---|---|---|---|
| `START.bas` 75 (`POKE 54,0: POKE 55,147`) | CSW, the character-output hook | `$9300`, `HI-RES CHARACTER GENERATOR` | from here on every `PRINT` in every program is drawn on the hi-res screen by that routine. `POKE 973/974` are its mode bytes |
| `STARSHIP SIMULATOR.bas` 2 (`POKE 232/233`) | shape-table pointer | `$7FFF`, the `ENEMY` table | `DRAW`/`XDRAW` use it |

✅ both ported: `scripts/shapes/char_generator.gd` is the character
generator (its modes, text window, form feed and wrap), and
`shape_table.gd` with `hgr_screen.gd` the ROM's `DRAW`/`XDRAW`. The
Godot UI stand-ins (GROUND FORCES and the programs under it) do not use
them yet.
The mapper checks for the other vectors too (KSW, `&`, `USR`, RESET);
none is used.

---

## STARSHIP SIMULATOR.bas — the main flight loop

Source: `detokenized/STARSHIP SIMULATOR.bas`. Port: `godot-remake/scripts/flight/flight_program.gd` (the statements), `flight_core.gd` (lines 20-147's arithmetic and `CALL CA`'s stick handling), `flight_combat.gd` (lines 185-192 and their subroutines), `flight_loop.gd` (the order and the measured time), `space_flight.gd` (the scene).

**Status 2026-11-10: the whole program is ported, a statement at a
time, in the original's units and on software copies of the two hi-res
pages.** `tests/check_flight_passes.tscn` and `check_jump.tscn` run it
against 92 passes of the real game recorded in MAME
(`analysis/live/pass/`, `analysis/live/jump/`) and compare both pages,
all 7680 bytes of each, and the registers after every pass: no
difference. The Status column says where each line lives.

The loop is lines 15-210: `FOR OO = 0 TO 1` draws alternately into the
two hi-res pages, and every pass ends at the keyboard check in line
200.

| Line | Target | What it actually does | Status |
|---|---|---|---|
| 2 | `POKE 232/233` | Points the shape-table vector at `$7FFF` (§4). | ✅ `shape_table.gd` loads `ENEMY`. |
| 8 | `GOSUB 6600` ×3 | Joins a low/high byte pair into a signed position component. | ✅ `GameState.ship_x/y/z` are the original's 16-bit values; `flight_core.gd::reload()`. |
| 9, 182 | `POKE 38149,7` … `IF PEEK(38149)=7 THEN POKE 38149,0: GOTO 200` | The first pass after the program starts (or restarts through line 500's `GOTO 1`) skips the fire button and incoming fire and goes straight to the keyboard. | ✅ `flight_program.gd::start()`, `after_view()`. The byte is also `SHORE LEAVE`'s once-a-trip base flag. |
| 15, 19 | (inline) | **Autopilot.** `IF PEEK(38164)=1 THEN 20` skips the paddle read and the `POKE 38397/38398` that passes it to the flight-control routine, so the ship holds its last stick input. | ✅ `flight_program.gd::begin_pass()`. |
| 21-128 | `CALL CSN` (24582), `CALL SN` (24585) | A2-3D1's cosine and sine entries. The angle goes in by `POKE M1` (24588) and the 16-bit result comes back in `M1/M2` — the same poke-then-call convention as §3. Eight calls a pass turn pitch and heading into the movement vector of line 129. | ✅ `flight_core.gd::step()`, with BASIC's reading of the 16-bit result (`basic_sin`, `basic_cos`) and its stale value at angles 63 and 190. |
| 133-138 | (inline) | Position wraps at ±20000 on each axis. | ✅ `flight_core.gd::_wrap()`. |
| 140 | `GOSUB 6000` ×3 | Inverse of 6600, for poking the position back. | ✅ `flight_core.gd::stored()`. |
| 147 | (inline) | In the atmosphere (`38210=1`) the ship sinks by `6 − S/10` a pass, floored at 20 with pitch and bank zeroed. | ✅ `flight_core.gd::sink()`. |
| 150-153 | `CALL CA` (36899), `CALL 37936` / `CALL 37888` | The per-frame flight-control and render call, then the page flip for whichever page was just drawn. | ✅ `flight_program.gd::fly()`: `flight_core.gd::stick()` for `$9023`, `a2_3d1_view.gd` for the view (held to the machine code by `tests/check_a2_3d1.gd`), then the panel copy. |
| 156 | (inline) | Within 900 units of the origin on all axes and not in atmosphere → `RUN RE` (re-entry). | ✅ `flight_program.gd::after_view()` → `flight_loop.gd::_reentry()` (`RE.bas`): the per-world terrain is loaded and flight goes on in the atmosphere. |
| 158 | (inline) | In atmosphere and `Y > 4000` → `RUN ORBIT` (back to orbit). | ✅ `flight_loop.gd::_orbit()` (`ORBIT.bas`). |
| 185 | `GOSUB 1500` | Fire button. 1500: firing at a surrendered planet re-arms it (`POKE 38208,0: POKE 38150,100`). 1501: missile selected (`38202=1`) → 1000. Otherwise the laser, if `38186 > 0`: draws the beams, then 1535 adds `10/(TE+1)` to the surrender counter `38160` and, in orbit, `1/(TE+1)` to the defender damage `38152`. Both sums are POKEd, so they are cut to whole numbers: at tech 1 or more the laser's `1/(TE+1)` is always lost and **the laser never damages a defender** (live at tech 3: three volleys took `38160` 1 → 3 → 5 → 7 and left `38152` at 0). 1550: counter ≥ `38150` → "THE PLANET HAS SURRENDERED", `38208=1`, planet marked secured. 1560: defender damage > `38204` with a defender present → `RUN EX`. | ✅ `flight_combat.gd`. |
| 1000-1090 | missile | Needs stock (`38187 > 0`), costs 2 per shot (line 1090) — except the shot that destroys the defender, because 1560's `RUN EX` leaves from inside the `GOSUB` and 1090 is never reached. The shot flies 16 steps; a hit is the defender's box around `X9,Y9,Z9` in orbit, or the ground in atmosphere. Hit → explosion (1200) and 1535 with `J2=120`, so at tech 0 one missile hit is worth 120 laser volleys on the defender, and above tech 0 the missile is the only thing that hurts it. Miss → the small burst (1100). | ✅ `flight_combat.gd::_missile()`: the 16 steps and line 1050's box, and the ground test in atmosphere. Drawing in `combat_fx.gd`. |
| 189-192 | `GOSUB 3000`, `GOSUB 5000` | Incoming fire, only at tech ≥ 2 planets that have not surrendered: every pass while in atmosphere (190), or while inside a box around the defender (192). Each calls the damage roll (3000) and then, 50% / 60% of the time and only while the planet has fighters (`38207 > 0`), the fighter attack (5000). In atmosphere and inside the box both lines run, so the ship is rolled against twice a pass (live, `analysis/fight_live_shields_down.log`: that run drifted into the re-entry box, came back in atmosphere, and from there took 36 damage cascades in 45 passes — 8 passes outside the box and 37 inside it are 82 rolls at 0.41, about 34; one roll a pass would give about 19. The log does not record `38210` itself). | ✅ `flight_combat.gd::fight()`, both lines. |
| 3000-3032 | damage roll | Returns at once if there is no defender and the ship is in orbit. Otherwise two independent rolls, 16% (40% × 40%) and 30%, each setting `DMG=1` with a screen flash and sound. | ✅ `flight_combat.gd::_defender_fire()`, `combat_fx.gd::damage()`. |
| 3200-3350 | damage | `DMG=1`: shield strength `38200` loses up to 1.1. **If shields are up (`38201=1`) and strength is above 10, that is all.** Otherwise five systems lose up to 5 each and the hull (`38193`) up to 4. Hull 0 → `RUN S/X`. **`DMG` is only cleared at 3350**, so after one hit has been absorbed by raised shields every later `GOSUB 3000` wears the shield again, hit or no hit (live, `analysis/fight_live_shields_up_laser.log`: 14 passes in a row, one shield point each). The death test is on `J` before the POKE cuts it down, so a hull of 0.4 is stored as 0 and the ship lives until the next hit. | ✅ `flight_combat.gd::_apply_damage()`, including both quirks. |
| 3360 | (inline) | First damage of a visit: `POKE 38393,1` (the DAMAGE light) and `RUN DMG`. | ✅ `GameState.damage_alert_active`. |
| 200-321 | key dispatch | See §1's table. | see §1 |
| 500 | `CALL 38402: GOTO 1` | The panel toggle (§2), then the program restarts from line 1. | ✅ `flight_program.gd::tranlit()` and `_restart()`: the restart is kept with what it loses (the frame, the marker positions, the position's fraction). |
| 5000-5096 | fighter attack | A fighter shape crosses the view from a random edge. Each step has a 30% chance of `GOSUB 5098` then `GOSUB 5200`. | ✅ `combat_fx.gd::fighter_pass()`. |
| 5098 | `GOSUB 3205` with `L=7` | A strafing hit that only wears the shield (`3207 IF L=7 THEN RETURN`), whatever the shields switch says. | ✅ `flight_combat.gd::_wear_shield()`. |
| 5200-5251 | point defence | **Only at condition RED** (`38165=3`): the turrets fire at the fighter; 30% of the time it is destroyed (`38207 − 1`, explosion 1100) at a cost of 2 missile stock (1090). | ✅ `combat_fx.gd`, `flight_combat.gd::_on_fighter_shot_down()`. |

---

## H_D.bas — the hyperdrive jump itself

Source: `detokenized/H_D.bas`. Port: `godot-remake/scripts/flight/flight_program.gd` (`hyperdrive_refused()` to `jump_finish()`), timed by `flight_loop.gd::_hyperdrive()`. Reached only from the flight loop's `H` key. ✅ ported whole 2026-11-10 and compared with a live jump pass by pass (`tests/check_jump.tscn`).

| Line | Target/branch | What it actually does | Status |
|---|---|---|---|
| 1 | (inline) | **Abort gate.** In atmosphere (`38210=1`), or target = current planet, or no course set (`38163=0`) → `RUN STARSHIP SIMULATOR`; nothing happens. Live: `H` with no course changed nothing. | ✅ `hyperdrive_refused()`. |
| 2-4 | (inline) | **Energy gate.** Energy (`38199`) exactly 0: "OUT OF ENERGY", "ORBIT DECAYING", `RUN S/X` — the ship is lost. | ✅ `jump_has_energy()`, then `S/X`. |
| 5, 10000-10020 | `GOSUB 10000` | **Distance.** `D1 = INT(SQR(X1² + Y1² + Z1²) + .6)`, but all three terms read the X array (`38366+planet`), so `D1 = INT(√3·|ΔX| + .6)`. Two systems with the same X are distance 0 apart. `GALAXY MAP.bas` 3300 shows the true 3-D distance, so the chart and the drive disagree. Then `POKE 301,0`. | ✅ `jump_distance()`, X only as the original has it. |
| 6 | `MISC FILE` read, write | Stardate `+= D1 + .3`. | ✅ `jump_log()`, with the three NUL prompts the `INPUT`s draw on the page. |
| 11 | (inline) | Troops aboard or in cryo → `POKE 38158,` target (their location follows the ship). | ✅ `GameState.troops_stationed_at`. |
| 12 | `CALL 38825`, mode 1 | Store the working registers into the record of the planet being left (§3). | ✅ 2026-11-10 `store_planet_record()`. |
| 12-13 | (inline) | Landing-morale decrement (`38170=17` → troop morale − 1). | ✅ |
| 14-15 | (inline) | **Energy `−= D1`**, floored at 0. Live: SOL → Alpha Centauri (ΔX = 2, D1 = 4) took energy 63 → 59. | ✅ `jump_ready()`. |
| 16 | (inline) | `POKE 38152,0` (defender damage), destination marked scouted. | ✅ `jump_ready()`. |
| 18, 20 | `CALL NOISE` | Engine noise through the pause and the star-burst. | ✅ `AudioManager.play_jump()` and a tick a ray. |
| 20, 76-80 | star-burst | 175 lines from screen centre to random points. It runs twice: line 80 loops back with `R=2` after the arrival work, and the second pass draws in black (line 76), wiping most of the first. | ✅ both bursts, the second in black (`jump_ray()`, `flight_loop.gd::_rays()`). |
| 25-26 | `CALL 38825`, mode 0 | Load the destination's record into the working registers (§3), set the current planet. | ✅ 2026-11-10 `load_planet_record()`. |
| 30-40 | `BLOAD … ,A30841` | Model for the thing in orbit: tech ≥ 2 with defender 0 → `DEBRIS`; defender 0 otherwise → an empty model; 2 → `SHIP # 3`; else `SHIP # n`. | ✅ `jump_arrive()`: `DEBRIS`, nothing, or the ship, in the A2-3D1 view. |
| 50-75 | `GOSUB 6000` | Random arrival position: X ±10000, Y ±5000, Z ±10000 with \|Z\| ≥ 7000, random heading, level pitch and bank. | ✅ `jump_arrive()`. |
| 90-93 | (inline) | Tech < 2: `38150 = 0`. Tech ≥ 2: `38150` and `38204` = tech × 60, surrender counter zeroed. | ✅ `jump_finish()`. |
| 105 | (inline) | `POKE 38206,0` (ground strength), `38389`, `38149`. | ✅ the two once-a-trip flags (`jump_finish()`). ⬜ record byte 2 is not modelled (§3). |

---

## GALAXY MAP.bas — the star-chart screen

Source: `detokenized/GALAXY MAP.bas`. Port: `godot-remake/scripts/chart/chart_program.gd` (the statements), `chart_loop.gd` (the order and the measured time), `star_chart.gd` (the scene). ✅ ported whole 2026-11-10: `tests/check_chart.tscn` compares hi-res page 1 and the text cursor with the real game's at nine stops of a route through every branch (`analysis/live/chart/`), no difference.

This screen is an information browser. A paddle-driven cursor moves
over a 2-D chart; the button on a star shows its name, coordinates and
distance and offers its directory page. **It never sets a course or
travels.** Setting a course is `COM.bas`'s Navigation Computer;
travelling is the `H` key in flight. The port now has the three steps
apart, as the original does.

Measured live (`tools/mame/chart_loop_live.lua`, `lines_live.lua`): one
turn of the cursor loop is 82 ms, with the cross on the screen for
about two fifths of it; line 3220's search takes 43 ms a star, so the
answer comes sooner for SOL than for SHIVANDA and "no star there" takes
the whole list; the distance takes a quarter of a second, most of it
`SQR`. Applesoft's `INT(H * 1.19)` is exact for every paddle value but
100 and 200, which come out one lower (118, 237).

| Line | Target | What it actually does | Status |
|---|---|---|---|
| 1-2 | `GOSUB 5000` | Entered from `INSTRUMENTS` with `38391=77` (a loaded game, or the way back out of this chart, which had to redraw the whole panel): redraw the six panel lights in BASIC from the flags, with no toggling, then go to flight or back to `COM`. | ✅ `chart_program.gd::lamp_blocks()`, `chart_loop.gd::_leave()`. There are eight blocks (one each for shields, condition, orbit and damage, two each for the missile/laser and manual/auto pairs; nine `GOSUB 5500`s at condition BLUE, which lines 5065 and 5080 both paint), plain `HPLOT` rows and not TRANLIT's lamp pictures, so the panel looks different until a lamp key is pressed in flight. `END.bas` 120 comes the same way (`end_program.gd::continue_game()`). |
| 3020 | (inline) | Reads the coordinates: X `38366+P`, Y `38345+P`, Z `38324+P`. | ✅ 2026-11-10 data ported (`PLANET_X/Y/Z`). |
| 3025-3080 | (inline) | The chart: each star at `X·10−35, Y·5`, one of three sizes by Z, a different colour when secured (`38219+P = 1`), a box round the current system. | ✅ `chart_program.gd::star()`. SOL is white at SOL in a new game: its flag holds 100 (§3). |
| 3110-3200 | (inline) | Cursor from the two paddles; any key returns through `INSTRUMENTS`. | ✅ `chart_loop.gd::_turn()`. Any key leaves, not only the space asked for. The cross is taken off with a black `DRAW` (3210), which takes the star under it off too. |
| 3250-3320 | `GOSUB 3300` | Name, coordinates, and the true 3-D distance from the current system in light-years. | ✅ `found_name()`, `found_place()`, `distance()`. |
| 3260 | (inline) | "Y" → `POKE 38388,P`, `RUN COM`: opens that system's directory page. | ✅ `further()`, then the scene hands over to COM (`GameState.handover`), which draws its directory page over what is left of the chart (`com_program.gd::page_*()`). The line also pokes 8 into 38149, the once-a-trip base flag's byte; `COM.bas` 1007 zeroes it. |

---

## COM.bas — the command console hub

Source: `detokenized/COM.bas`. Port: `godot-remake/scripts/com/com_program.gd`
(the statements, drawn on hi-res page 1 with the game's character
generator), `com_loop.gd` (the GOTOs and the measured time) and
`com_console.gd` (the scene: a clock, the page and the keyboard).
Recorded live with `tools/mame/com_live.lua` (`analysis/live/com/`):
35 stops for a key over two routes, every one compared byte for byte
with the port's page, cursor, text window and the 973/974 switches by
`tests/check_com.tscn` and `check_com_damaged.tscn`, and the page once
more when each route is back in flight.

Found while matching the chart's way out: line 20 (`POKE 32,0: HOME:
FOR J = 1 TO 14: PRINT " ": NEXT`) runs with whatever text window the
last program left. After the chart that is rows 19-23, so the fourteen
spaces wipe the first column of the instrument panel's lower half
(live: `analysis/live/chart/leaving_6000_p1.bin`).

| Line | Target | What it actually does | Status |
|---|---|---|---|
| 8 | (inline) | Page 1 on show and drawn on; the speed and energy markers painted out with black `DRAW 25`s. | ✅ `open()`. |
| 12 | `GOSUB 15100` | Loads the 20 star names. | ✅ `star_name()`. |
| 12 | (inline) | `38388 > 0` on entry → straight to that system's directory page (line 978), over whatever is on the screen. | ✅ `chart_star()` (`GameState.handover`), compared live from the chart (`com_detail`). |
| 20-80 | `GOSUB 10000` | The console: rows 0-123 painted blue an `HPLOT` at a time (four seconds), the left half cleared, twelve two-line labels read from `DATA`, each plain or inverse by its system's byte (`ST()`, line 15140). Power goes inverse under 16, the others at 0; the last label reads 38185, which nothing writes. | ✅ `fill_row()`, `clear_row()`, `label()`, `title()`; the inverse labels compared live (`damaged`). |
| 21-35 | `GOSUB 21` | Text window full, the left half's fourteen rows cleared; returns only when `R = 1`. | ✅ `full_window()`, `clear_row()`. |
| 98, 115 | (inline) | `38151 = 7` → `RUN GROUND FORCES`: the return half of a hand-off `GROUND FORCES.bas` 1130 starts. Line 115 is the same test again and never true. | ✅ `ground_forces_due()`. ⚠️ nothing in the port sets the flag yet (GROUND FORCES and COLLECT are still Godot screens). |
| 120 | `GOSUB 21`, `GOSUB 390` | "COMMAND?" and a `GET`. Any key but 1-5: "PLEASE ENTER YOUR / COMMAND AGAIN." at `SPEED= 127`, a 3000-count wait, the left half cleared and back to line 90. The menu comes back without line 80, so the text window is left 39 wide. | ✅ compared live (`menu_wrong`). Line 140's `GOTO 30` (a line that does not exist) is never reached: an earlier reading here that a wrong key falls into it was wrong. |
| 121-135 | (inline) | 1 → line 200. 2 → `RUN GROUND FORCES` (its `PRINT " "` goes to page 2). 3 → `POKE 38388,2`, `RUN RADAR`. 4 → `RUN END`. 5 → text rows 1-16 wiped (dots 0-127: the top two rows of the panel go with the view), the lo-res screen filled behind it, `RUN STARSHIP SIMULATOR`. | ✅ `command_taken()`, `command_window()`, `wipe_row()`, `command_leave()`; "5" compared live to three passes into flight (`flying`). The radar stand-in now honours 38388 (`RADAR.bas` 2058: back to COM, not to flight). |
| 200-280 | `GOSUB 21`, `GOSUB 3000` | Central computer. `38196 = 0` → "COMPUTER NOT FUNCTIONING.", a 4000-count wait, back to line 12. Else six choices: 1 → 800, 2 → 900, 3 → `RUN GALAXY MAP`, 4 → `RUN STATUS`, 5 → `RUN SUPPLY`, 6 → line 12. `ON C GOTO`'s third target is the missing line 30, never taken because line 265 has caught 3. | ✅ `_central()`; compared live (`central`, `central_wrong`, `damaged_menu_again`). |
| 800-850 | `GOSUB 21` | Navigation computer: 1 → 900, 2 → 860, 3 → line 20. | ✅ `_navigation()`. |
| 860-897 | `GOSUB 21` | Set course. Two characters, each a digit or RETURN (RETURN is printed and counts as a place: "7", RETURN is 7), the left arrow takes one back. 0 or over 20 → "<ERROR>" and a 5000-count wait; the star we are at → "THAT'S WHERE WE / ARE NOW, SIR!"; else `POKE 38163,C`, the name, "COURSE SET." Lines 873 and 897 are never reached. | ✅ `_course()`, `entry_key()`; sets `GameState.target_planet`, which `H` in flight reads. Compared live: 25, 01, a digit taken back, 05, and 7 with RETURN. |
| 900-969 | `GOSUB 20` | Galaxy directory: orange, the twenty names in inverse, 1 → line 970, 2 → `R = 2: GOSUB 20: GOTO 810`. Line 35 only returns for `R = 1`, so "2) RETURN" never gets to its `GOTO 810`: it falls through into the command menu, whether the directory was asked for from the central or the navigation computer. Any other key paints the whole directory again. | ✅ `_list()`; compared live (`after_directory` is the command menu). ❓ each such return leaves a `GOSUB` on the stack; some thirty of them in one stay in COM should end in `?OUT OF MEMORY` and the `ONERR` line 63999 (`INT`). Not run live, not ported. |
| 970-978 | (inline) | "WHICH SYSTEM" and the same two-character entry. Out of 1-20: "TRY AGAIN PLEASE." | ✅ `_which()`; compared live (30, then 02 and 01). |
| 979-1180 | (inline) | A star system's page: nothing known until scouted (`38240+C`); else tech text, defenders for tech 2 and up, population (`PEEK(38261+C)·35294`), secured or independent, base. Any key: back to the chart if it asked (`38388 > 0`, zeroed), else to line 900. Line 1175 is never reached (`R` is 0 again by then). | ✅ `page_lines()`, `page_close()`; compared live for a scouted and an unscouted system and from the chart. |
| 63999 | `ONERR` | Any error runs DOS's `INT`, which on this disk is the SYSTEM ERROR screen and a reboot (see END.bas below). | ⬜ no error is known to be reachable but the stack one above. The screen itself is ported (`system_error.gd`). |

Measured, in video frames, and in `com_loop.gd`: from the flight's "C" to
the command menu's `GET` is 14 s on the real machine, 7.2 of them the
floppy; every return to the command menu costs the blue fill again
(124 rows × 1.91). `tests/check_com.tscn -- --times` prints the port's
time from stop to stop next to the recording's: all within two frames
once the recorder's own seven are taken off (its RETURN key takes ten
more to arrive than a digit does).

---

## GROUND FORCES.bas

Covered line by line in `GROUND_COMBAT_ANALYSIS.md` and
`FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md`; not re-walked here. The
generated map (`analysis/BASIC_CALL_MAP.md` §6) has its call sites.
Two things the fresh map re-found that those documents already hold:
line 1115's `K = 82` makes any key a retreat, and line 500 takes the
enemy troop count from record byte 2 (`38206`), which `H_D.bas` 105
has always zeroed by then except at the starting planet.

---

## START.bas, END.bas — the saved game (live 2026-11-10)

Recorded with `tools/mame/save_live.lua` on copies of the disk: a new
game, `C`, `4` (END), `1` (save), `2` (continue); then three more boots
of the written disk.

| Line(s) | What it does | Seen live | Port |
|---|---|---|---|
| `END` 200-210 | the ship's place (29467-29475) into 38211-38219, which are bytes 7-15 of the planet record's working copy; `POKE 38391,77: POKE 38392,PEEK(38209)`; the record stored (`CALL 38825`); three `BSAVE`s | `PLANET FILE` on the disk afterwards holds 38391 = 77, 38392 = 1. **The ship's place is in `P/F`, inside the record of the planet it is at**: SOL's record on the saved disk is `150 3 100 30 1 1 0 188 2 200 0 15 230 0 0 0 100`, x = 700, y = 200, z = -6641 | ✅ as a JSON file (`GameState.save_to_disk()`); the screen is `end_program.gd` (the table below) |
| `END` 120 | `POKE 38391,77: RUN GALAXY MAP` (continue) | line 2 clears the 77 after 237 frames; no `CALL 38402`, the four switches unchanged; the third pass of flight 791 frames after the clear | ✅ `end_program.gd::continue_game()` sets `GameState.saved_marker`; `flight_loop.gd::run()` does the rest, timed (`LOAD_GALAXY_MAP`, `lamps()`, `LOAD_SIMULATOR_SPINNING`). `drive_save` compares the lamps with the live page |
| `START` 25-26 | `BLOAD PLANET FILE`, `OG = PEEK(38391): POKE 38391,0`, and if it was 77 `BSAVE PLANET FILE` straight back | **A saved game can be resumed once.** The boot itself clears the marker on the disk, before the question is asked: after a boot answered `O` and after one answered `N` the file holds 38391 = 0 both times. The title takes about 180 frames longer when it has that write to do. | ✅ `GameState.boot()`, called when the title first comes up and again after the ship is destroyed: the file's `"saved"` is the mark (`check_save`, `drive_save`) |
| `START` 73 | `O` with `OG <> 77` | a second boot of the same disk answered `O`, and a boot of the untouched disk: "THERE IS NO GAME SAVED" for 170 frames (looked at every frame, three times: `analysis/live/save/save_none.log`), the screen cleared, the question again | ✅ `start_screen.gd` (`NO_GAME_SAVED_FRAMES`); the screen is a stand-in |
| `START` 3000-3030, `INSTRUMENTS` 210-220, `GALAXY MAP` 2 | an old game: the three saved files, `POKE 38391,77`, so `INSTRUMENTS` skips TRANLIT and runs `GALAXY MAP`, whose line 2 paints the lamp blocks and runs the flight program | no `CALL 38402` between the load and flight; shields 0, weapon 1, condition 3, autopilot 0 came back exactly as saved; 38391 = 77 for 613 frames | ✅ `flight_loop.gd::run()`: `instruments(false)`, the wait for `GALAXY MAP`, `lamps()` (`flight_program.gd::lamp_blocks()`, shared with the chart), the wait for the flight program. `check_save` loads the game the real machine saved and compares the whole panel at the third pass with the live page: 0 bytes different. A new game's panel differs from it in 57 bytes, so the comparison tells the two roads apart |

### END.bas on the hi-res page (live 2026-11-10)

Recorded with `tools/mame/end_live.lua` (routes `menu`, `atmosphere`,
`quit`, `font` and ten `key_*`); the records are in `analysis/live/end/`.
Ported as `scripts/end/end_program.gd` (statements), `end_loop.gd`
(order and frames) and `end_console.gd` (the scene). `check_end`
compares page 1, the text cursor and window, 973/974 and 38391 at every
stop of the `menu` route (20 stops) and `check_end_atmosphere` at the
`atmosphere` route's (6): 0 bytes different, and back in flight after
CONTINUE as well.

| Line(s) | What it does | Seen live | Port |
|---|---|---|---|
| 0-20 | `ONERR GOTO 63999`, `POKE 974,32` (the generator back on page 1; COM left it on page 2) | the load is 150 frames, COM's console on show meanwhile | ✅ `ran()`, `open()`, `LOAD_END` |
| 30 | `POKE 33,40: FOR J = 1 TO 16: VTAB J: PRINT "<40 spaces>": NEXT: HOME` | text rows 1-16 wiped (the view and the top two rows of the panel), 2.6 frames a row. **There is no `HTAB`**: the forty spaces start in whatever column the cursor was in, so after a key that is not 1-3 the first fifteen cells of row 1 are left | ✅ `wipe_open()`, `wipe_row()`, `home()`; the menu after a 9, a 0 and a 4 is compared |
| 31-70 | the title, three choices, "ENTER CHOICE.  ", `GET C` | the menu is up 50 frames after the program starts; the cursor waits at column 15, row 9 | ✅ `title()` … `prompt()` |
| 70 | **`GET C` reads a number.** | A digit is itself. Space, `.`, `+`, `-`, `,`, `:` and `E` are 0, and like any digit not 1-3 the menu is drawn again. **Any other key (a letter, RETURN, ESC) is a ?SYNTAX ERROR**, which `ONERR` sends to line 63999: the SYSTEM ERROR screen 4.2 frames later, and the game in hand is gone. Ten keys pressed live, one run each (`end_key_*.log`) | ✅ `EndProgram.number()`, held to all ten logs; `Left.ERROR` |
| 75-90, 190 | 1 in an atmosphere (`PEEK(38210) = 1`): `SPEED= 128`, "YOU MUST BE IN ORBIT TO SAVE GAME", a `FOR` of 2000, the menu | 2.57 frames a character, the carriage returns too; held 111 frames | ✅ `_save()`, `_slow()`; `check_end_atmosphere` |
| 200-220 | 1 otherwise: the save (the table above), `PRINT : PRINT "GAME SAVED."`, a `FOR` of 2000, the menu | 8 frames of pokes, 600 of floppy (the `BSAVE`s print no carriage return, so the message is on row 11), held 113 frames. The 77 stays in memory until CONTINUE pokes it again | ✅ `save()`, `saved_message()`; the floppy cut by `DISK_WAIT_SCALE` |
| 110-120 | 2: `POKE 38391,77: RUN GALAXY MAP` | as in the table above | ✅ `continue_game()`, `Left.CONTINUE` |
| 100 | 3: `FOR J = 1 TO 5000: POKE J,0: NEXT : END` | **It never reaches its `END`.** Zeroing the zero page takes BASIC's own pointers with it: 32.7 frames after the key the display is the blank text screen and the machine is hung (`quit_after_20.png`, twenty seconds on) | ✅ `Left.QUIT`: the picture goes black at that frame. The scene then closes the application a second later, which is the port's liberty (the Apple has to be switched off) |
| 63999 | `PRINT : PRINT CHR$(4)"INT"` | see below | ✅ `error()`, `scenes/system_error.tscn` |

**SYSTEM ERROR.** The disk's DOS 3.3 has been patched (disassembled from
a memory dump, `analysis/live/end/dos_9d00.bin`, load `$9D00`). Its error
handler at `$A6D2` no longer prints a message and returns to BASIC: it
does `HOME`, writes a table at `$A971` through `COUT1` (`$FDF0`, the text
screen, past the game's hi-res character generator; a byte under `$80`
is that many spaces), switches the display to text page 1, clears the
key strobe, waits for a key with no cursor (`$FD1B`) and jumps through
the reset vector, which boots the disk. The table is 413 spaces, "SYSTEM
ERROR!", a carriage return, 48 spaces, "PRESS ANY KEY TO REBOOT", where
DOS's own error messages used to be. The `INT` command's entry at
`$A59E` is `JMP $A6D5`, the same routine. So:

- every program's line 63999 ends there, whatever the error was;
- so does every DOS error that `ONERR` does not get first (a
  write-protected disk during the `BSAVE`s, for one: derived from the
  disassembly, not tried);
- the only one a player can reach from the keyboard, as far as is
  known, is the letter at END's menu.

Ported as `scripts/dos/system_error.gd` on a text screen of its own
(`text_screen.gd`, with the Apple II+ character ROM's glyphs captured
live: `apple_text_characters.png`, `apple_text_font.json`). Its picture
is the live snapshot's dot for dot (`check_end`, against
`system_error.png`). A key there is `GameState.reboot()`: the title
again, and the boot that uses a saved game up. A write that fails in
`save_to_disk()` goes the same way.

Timing of the road through `GALAXY MAP` line 2, in frames: the 77 poked
by `START` 3030 at 4913, `INSTRUMENTS` starts at 5201, its last glyph at
5268, line 2 clears the 77 at 5526 (258 after that glyph, the same as on
the way out of the chart), third pass of flight at 6318. From the clear
to the third pass is 792 for an old game and 791 after CONTINUE; a new
game's TRANLIT-to-third-pass is 824 with a cold load of 400, so the load
here is taken as 400 − 66 = 334 (`LOAD_SIMULATOR_SPINNING`). That one is
derived, not timed on its own.

## STATUS.bas, SUPPLY.bas — the two reports (live 2026-11-10)

Recorded with `tools/mame/reports_live.lua` (routes `status`,
`status_poked`, `status_odd`, `status_morale`, `supply`,
`supply_poked`): a new game, `C`, `1` (the central computer), `4` or
`5`, a key a page, and `5` back to flight. The records are in
`analysis/live/reports/`. Ported as `scripts/reports/status_program.gd`
and `supply_program.gd` (statements), `status_loop.gd` and
`supply_loop.gd` (order and frames) and `report_console.gd` (the scene
for both). `check_status*` and `check_supply*` compare page 1, the text
cursor and window and 973/974 at every stop of every route, page 2 at
the reports' own stops, and page 1 back in flight: 53 stops, 0 bytes
different.

Both paint the view green a row at a time (`HCOLOR= 1`, 124 `HPLOT`s,
four seconds), lay a white sheet of inverse spaces on it and print in
inverse; both read `SD`, `TR` and `CR` from `MISC FILE` first, and both
end with `RUN COM`, which starts the console from its top.

| Line(s) | What it does | Seen live | Port |
|---|---|---|---|
| `STATUS` 10-20 | `VTAB 1: HTAB 2: POKE 32,1: POKE 33,39`, the green fill | load 203 frames with COM's menu on show; 1.90 frames a row | ✅ `open()`, `fill_row()` |
| `STATUS` 30-60, 5000 | `POKE 973,255: POKE 974,64`, the three `INPUT`s from `MISC FILE`, `POKE 974,32` | **Each `INPUT`'s prompt is a NUL, and the character generator draws it**: three inverse glyph-0 cells at columns 1-3 of row 0 on page 2, 108, 122 and 123 frames after the `OPEN`. Nothing else of the file shows | ✅ `misc_open()`, `misc_prompt()`, `misc_close()`; page 2 is compared |
| `STATUS` 1230 | fifteen rows of 38 inverse spaces from column 1 | 2.67 frames a row; the left column and the last four dots of the view stay green | ✅ `wipe_row()` |
| `STATUS` 1235-1310, 5100-5120 | the ship's page | `ENERGY` is `INT(PEEK(38199) / 62 * 100)`, capped at 100: a full ship (63) is 101 before the cap, 31 is 50%. `HULL DMG` is 100 less the byte (a whole hull reads 0%). `ENV.` and `NAV.COMP.` are the constant 100. `MISSILES` is 38187 | ✅ `title()` … `engines()`; held with every number poked (`status_poked`) |
| `STATUS` 1290-1294, 1350-1360, 1380-1384 | the words for condition, morale and the troops' place, an `IF` each | **A value with no word prints nothing, not even the end of the line**, and the next `PRINT` carries on from there round the edge of the sheet (`status_odd`: condition 0, morale 0, place 4). Morale 0 is reachable: `H_D.bas` 12 takes it down to 0 | ✅ `_word()`; all five other morales, three places and BLUE in `status_morale` |
| `STATUS` 1386 | `IF PEEK(38167) * 256 + PEEK(38159) = 0 THEN PRINT "THE TROOPS ARE ALL DEAD!";` | **It cannot print.** 38167 is `LT`, the lamp TRANLIT last flipped (3 at the console of a new game), and 38159 is 20 from `SHIP'S DATA-M` and written by nothing: no BASIC line and no machine code stores there. Neither is the troop count (`TR`, in `MISC FILE`). With both poked to 0 it prints on the row under GROUND MISSILES (`status_poked`) | ✅ `all_dead()`, with the two bytes as fields of the program that only the test changes |
| `STATUS` 1390-1400 | `GET`, `PRINT " "`, `POKE 973,0`, `RUN COM` | COM's load is 434 frames | ✅ `close()`, `Left.COM` |
| `SUPPLY` 5-19 | `HTAB 2`, the window (`POKE 34,0: POKE 35,15` as well), `POKE 974,64`, `MISC FILE` | load 155 frames. The NULs are at columns 1-3 of row 11 on page 2 and **not** inverse: this program reads the file before its `POKE 973,255`, with the cursor on the row COM left it. The read is 58 frames to the first prompt, the drive still turning | ✅ `open()`, `misc_prompt()`, `misc_close()` |
| `SUPPLY` 1400 | fifteen rows of **39** spaces from column 1, the title | one more than fits: each row's last space is the first of the next row, and the fifteenth's is the first row's (the window ends at 15). 2.79 frames a row | ✅ `wipe_row()`, `title()` |
| `SUPPLY` 1410-1490 | `PRINT name;: HTAB 19: PRINT "= ";n;: HTAB 24: PRINT unit` for the thirteen bytes of loot, some times 10, 20 or 100 | `HTAB` does not clear. **A number of four digits or more loses what is past its third under the unit**: byte 255 of platinum (2550 pounds) reads `= 255POUNDS`, 100 of wine (10000 cases) `= 100CASES` (`supply_poked`). `COLLECT.bas` 915 lets a byte reach 255, so this happens in play. And `* ELECTRONIC PARTS` is a letter too wide: it reads `* ELECTRONIC PART= 0` in every game | ✅ `entry()`, `credits()` |
| `SUPPLY` 1450-1520 | a key for the second page; there `1` is the first page again, any other key `POKE 973,0: POKE 974,64: PRINT " ": RUN COM` | the last `PRINT " "` is on page 2 (column 32, row 11); COM's line 8 puts the generator back on page 1 | ✅ `Left.COM`; `1` and the second round in the `supply` route |

Numbers: `SD`, `TR` and `CR` are printed as Applesoft prints any number
(`CharGenerator.float_text()`: nine digits, no leading zero, `E` form
from a thousand million up and under a hundredth); the rest are bytes.

Not measured: the `READ`s of STATUS line 1235 for a star other than SOL
(one more `READ` for each place down the `DATA`; the port waits SOL's
2.8 frames for all of them).

A thing seen on the way: the `status_odd` route poked the energy to 200.
STATUS capped it to 100% as the listing says, and the flight program
then died of it: `STARSHIP SIMULATOR` 173-180 draws the gauge's marker
at `199 + E`, off the screen, an ILLEGAL QUANTITY and so the SYSTEM
ERROR screen. Nothing in the game takes the energy past 63.

## RADAR.bas, SHIP # n I.D. — the radar (live 2026-11-10)

Recorded with `tools/mame/radar_live.lua`, seven routes: `radar` (R in
flight, X), `radar_ids` (R, and a key at the radar and a key at the
I.D. six times over with 38205 poked to 1, 2, 3, 4 and 0), `radar_com`
(COM's "3", an I.D. and back, X, COM again), `radar_dead` (38195 poked
to 0, from the console and from flight) and `radar_ship_0`, `_1`, `_4`
(another `SHIP # n` loaded at `$7879` and the ship put right over it).
The records are in `analysis/live/radar/`. Ported as
`scripts/radar/radar_program.gd` and `ship_id_program.gd` (statements),
`radar_loop.gd` and `ship_id_loop.gd` (order and frames) and
`radar_console.gd` (one scene for both). `check_radar*` compare pages 1
and 2, the text cursor and window, 973/974, A2-3D1's bytes 29461-29475
and 38388 at every stop of every route, and page 1 back in flight: 38
stops, 0 bytes different.

| Line(s) | What it does | Seen live | Port |
|---|---|---|---|
| `RADAR` 10 | `IF PEEK(38195) = 0 THEN 2058` | **With the radar shot away nothing is drawn and nothing is said**: the program loads (165 frames), wipes the text rows and runs whichever program ran it. From flight that skips line 2057 as well | ✅ `dead()`; route `radar_dead` |
| `RADAR` 1500-2000 | the eye's height and pitch and bank kept, then `POKE P1,63`, height 20000 (`GOSUB 6000` splits it into bytes), `POKE B1,0` | the eye straight down from 20000 up. **The heading (29475) is not touched: the map turns with the ship** | ✅ `look_down()` |
| `RADAR` 2005 | `POKE 29463,0: POKE 29465,0: POKE 974,32: CALL 24576: CALL 37936: POKE -16300,0`, the violet frame | A2-3D1 draws its whole list on page 1: opcode 8 clears all 8192 bytes of the page, **the flight panel with them**, in 2.6 frames; then the star field's 195 points, three or four a frame, and whatever `SHIP # n` is loaded. `CALL 37936` copies the panel back from page 2 (3.6 frames). The call took 64.8 frames with nothing in orbit, 105.5 over SOL's light cruiser from the game's starting place, 112.7 right over the space lab, 143.9 right over the heavy cruiser | ✅ `view_open()`, `view_step()`, `panel()`, `frame()`; the picture comes record by record, as the Apple's does |
| `RADAR` 2010 | `VTAB 24`, eighteen spaces, `HTAB 26`, thirteen spaces | the panel's coordinates and heading blanked; the lamps stay | ✅ `blank_row()` |
| `RADAR` 2032-2045 | the frame's inner edge, two diagonals and a cross that stop short of the middle, `HCOLOR= 1` and a box with a dot in it; pitch and bank put back | 18.7 frames for lines 2010 to 2050 | ✅ `lines()`, `box()` |
| `RADAR` 2050-2056 | `GET A$`, `VTAB 1: HTAB 1`, the height put back; X or anything else | | ✅ `key_taken()` |
| `RADAR` 2057 | `HCOLOR= 0` and `DRAW 25` over the two rows of gauge markers | on the way back to flight as well as to COM | ✅ `marker()` |
| `RADAR` 2058 | `POKE 974,64: IF PEEK(38388) > 0 THEN POKE 38388,0: PRINT " ": RUN COM` | 38388 is 2 when COM ran it (COM line 133). The space goes on page 2 | ✅ `back_to_com()`, `Left.COM` |
| `RADAR` 2059 | sixteen rows of forty spaces (on page 2: 974 is 64), `COLOR= 15` and 47 `HLIN`s on the lo-res screen behind, `RUN STARSHIP SIMULATOR` | 2.75 frames a row, 22.4 for the lo-res fill; the flight program's line 0 comes 414 frames after | ✅ `wipe_row()`, `Left.FLIGHT`. The lo-res screen is not kept: nothing ever shows it |
| `RADAR` 5000-5005 | `POKE 974,64: PRINT " "`; `IF PEEK(38205) = 2 THEN RUN SHIP # 3 I.D.`; `POKE 38151,5: RUN SHIP # n I.D.` | a type 2 gets the light cruiser's page (`radar_ids`). **The poke of 38205 changes which I.D. runs and not what the radar draws**: that is whatever `SHIP # n` `H_D` or `START` last loaded at `$7879` | ✅ `identify()`, `Left.SHIP_ID`. 38151 = 5 is read by nothing found, and is not kept |
| `SHIP # n I.D.` 10-14 | sixteen rows of spaces over the radar's picture, `POKE 35,16`, a green frame and a grid on the left 160 dots | 2.6 to 2.75 frames a row, 1.2 an upright and 1.3 a level line. **Green is the odd dots only, and the uprights are five dots apart: every other one is at an even dot and is not there** | ✅ `clear_row()`, `frame()`, `grid_column()`, `grid_row()` |
| `SHIP # n I.D.` 20-50 | `READ` a code and two numbers: 1 moves, 2 draws a line to there, 77 moves the centre down for the side view, 127 ends | two frames a point: the space lab's drawing is three seconds coming and the heavy cruiser's five. `# 0` has no DATA and no drawing | ✅ `ShipIdProgram`'s DATA and `read()` |
| `SHIP # n I.D.` text | a title and four or five lines, at `HTAB 25` | **four copies that are not alike**: the title is ` -SHIP I.D.-`, `-SHIP I.D.-` or `  -SHIP I.D.-`; rows 4, 6, 8, 10 for `# 0` and `# 1`, 3, 5, 7, 9 for the cruisers; the heavy cruiser's fifth line is printed where the others wait, so it waits a row lower and a column to the left; the light cruiser's `GET` is on line 1060 and the others' on 1070 | ✅ `texts()`, `prompt()`; `GET_LINE` |
| `SHIP # n I.D.` end | `GET`, `PRINT " "`, `RUN RADAR` | the whole radar is drawn again, stars and all. The text window is left sixteen rows high, and RADAR and the flight program after it print in that | ✅ `Left.RADAR` |

A2-3D1's call is priced by the record in the port (`radar_loop.gd`'s
`VIEW_` constants: a point brought into view space, the same projected
and plotted, an end of a line, a dot of a line, the page clear), fitted
to the four calls above and to the video frame each star's bytes were
stored in. All four come within a third of a frame, and every star
within half a frame of the frame the Apple drew it in. These are not
the flight loop's prices for the same routine, which were fitted to the
flight's own pictures and are 7% short on the radar's.

Not held: the stretch between one stop for a key and the next as a
whole. The recorder notices a `GET` some five frames late and a key
takes four more to be seen, and two loads of the same program differ by
up to nine frames, so only the lines' own times and the call are
compared.

## Summary

**Ported in the 2026-11-10 reconcile**

- The new-game galaxy: tech, population, coordinates, secured, scouted
  and base flags for all 20 systems (`GameState.NEW_GAME_*`,
  `PLANET_X/Y/Z`). The port previously started every system at tech 0.
- The per-planet record (defender type, defender threshold, fighters,
  surrendered) with store-on-leave and load-on-arrival, replacing the
  random defender re-roll. Saved games carry the records.
- New game starts with the missile selected, as the original does.

**Ported after it (the user's decision: keep fidelity with the original)**

- The four panel switches on their real keys: shields (`S`, down on a
  new game), condition (`B`, RED on a new game), weapon (`W`), autopilot
  (`A`). The stick moved to the arrow keys to free the letters.
- Flight combat rebuilt on the loop-iteration model with the POKE
  truncation, the shields branch, RED-only turrets and the sticky `DMG`
  flag (`flight_combat.gd`), and its drawing rebuilt on a software
  hi-res page from the real shape table (`combat_fx.gd`). See the
  STARSHIP SIMULATOR table above.

**Ported since, each held to a live recording**

- The instrument panel and its lamps (`INSTRUMENTS.bas`, TRANLIT,
  `DMG.bas`), the original's coordinate frame and A2-3D1 view, flight
  in the atmosphere (`RE`, `ORBIT`), the `H` key with `H_D.bas`'s gates
  and costs: the STARSHIP SIMULATOR and H_D tables above.
- The star chart: the GALAXY MAP table above.
- The 17-byte record copy and SOL's secured byte (§3).
- Save and load as `END.bas` and `START.bas` do them: refused in an
  atmosphere, the ship's place kept, the record stored first; a saved
  game good for one boot; an old game and CONTINUE into flight by way
  of `GALAXY MAP` line 2, with no TRANLIT (the START/END table above).
- The command console (the COM table above).
- `END.bas` on the hi-res page, its numeric `GET`, its dead machine,
  and the SYSTEM ERROR screen every error in the game ends at (the END
  table above).
- `STATUS.bas` and `SUPPLY.bas` on the hi-res page (the table above).
- `RADAR.bas` and the four `SHIP # n I.D.` programs (the table above).

**Not ported yet**

1. **The programs under `COM.bas` on the hi-res page** (`GROUND
   FORCES`, `COLLECT`, `SHORE LEAVE`) and `START`'s title on the text
   screen. Their rules are in the port as Godot UI; their screens and
   timing are not. (`COM`, `END`, `STATUS`, `SUPPLY` and `RADAR` are
   ported: their tables above.)
2. `GROUND FORCES.bas` setting `38170 = 17`, which `H_D.bas` 12-13
   reads.
3. Record byte 2 (`38206`).

**Open ❓:** record byte 2's stored ground strengths being zeroed before
use; `COM.bas` line 140's `GOTO 30`, a line that does not exist, not
yet run live.

**Still to do on the machine-code side:** the same treatment for
A2-3D1 itself (`$6000` jump table, the zero-page save/restore thunk,
its poked-argument entries). `tools/dis6502.py --calls` lists the
entry points.
