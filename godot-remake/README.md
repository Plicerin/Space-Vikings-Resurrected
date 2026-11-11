# Space Vikings in Godot

A Godot 4 port of *Space Vikings* (Apple II, 1982), built from the
disassembly and analysis in the parent repository. It replaces the
non-functional `js-remake/`.

    godot --path godot-remake

boots to `scenes/start.tscn`: NEW GAME, and CONTINUE when a game has been
saved. Developed and tested on Godot 4.7.

The aim is a small, simple Godot game with the original's rules and
experience, none of the Apple's hardware to fight with. Anyone after the
Apple's own picture, speed and disk habits has the real disk and an
emulator. The test of whether one of the original's bugs, quirks or
mechanics is kept is whether keeping it leaves the Godot game simpler
(see "Liberties").

This file says what the port is. How each fact was found is in the
parent repository's analysis documents (`CALL_SITES.md` first), the
witness ledgers and the git history.

## How it is put together

Every program of the original is a **rules class** with no screen in it
(`scripts/rules/`) and a **Godot scene** that shows it (controls, the
theme `theme/space_vikings.tres`, numbers that count, waits a key can cut
short). The rules were played through recordings of the real game, made
in MAME (`tools/mame/*_live.lua`, results in `analysis/live/`): its keys,
the numbers its `RND` gave, compared with its memory, variables and
printed text at every stop. Where the recording could not reach, the
rules were compared with the verified code of the earlier port, kept as
data in `tests/golden/`.

| Original program | Rules | Scene | Held to the real game by |
|---|---|---|---|
| `GROUND FORCES`, `RECALL`, `COLLECT` | `scripts/rules/ground_rules.gd` | `scripts/ui/ground_forces.gd` | `check_ground_rules` (the rules), `drive_ground_forces` (the scene) |
| `SHORE LEAVE` (shore leave, enlisting and weapons, loot, repairs, a base, cryogenics) | `scripts/rules/shore_rules.gd` | `scripts/ui/shore_leave.gd`, one panel over the ground forces menu | `check_shore_rules`, `drive_shore_leave` |
| `GALAXY MAP` (star chart) | `scripts/rules/chart_rules.gd` | `scripts/flight/vector_chart.gd` (a vector overlay on the flight) | `check_chart_rules`, `drive_chart` |
| `END` (save, continue, end game) | `scripts/rules/end_rules.gd` | `scripts/end/end_console.gd` | `check_end_rules`, `drive_end` |
| `COM` (command console, central and navigation computers, galaxy directory, damage-control lamps) | `scripts/rules/com_rules.gd` | `scripts/com/com_console.gd` | `check_com_rules`, `drive_com` |
| `STATUS`, `SUPPLY` (the central computer's two reports) | `scripts/rules/report_rules.gd` | `scripts/reports/report_console.gd`, one panel each | `check_report_rules`, `drive_reports` |
| `STARSHIP SIMULATOR` (flight, fighting, keys) | `scripts/rules/flight_rules.gd`, `combat_rules.gd` | `scripts/flight/native_flight.gd` (3D), `fight_effects.gd` | `check_flight_rules`, `check_combat_rules`, `drive_native_flight` |
| `H_D` (hyperdrive), `RE`, `ORBIT` (into and out of the atmosphere) | `hyperdrive_rules.gd`, `flight_rules.gd` | `native_flight.gd`, `hyperspace_effect.gd` | `check_hyperdrive_rules`, `check_flight_rules` |
| `EX`, `DMG`, `S/X` (the ends of a fight) | `combat_rules.gd` | `native_flight.gd` | `check_combat_rules` |
| `RADAR`, `SHIP # 0 I.D.`, `# 1`, `# 3`, `# 4` | `radar_rules.gd` | `scripts/flight/vector_radar.gd` (a vector overlay on the flight) | `check_radar_rules`, `drive_radar` |
| `START` (title), save and load, planet records, new-game data | `autoload/game_state.gd` | `scripts/ui/start_screen.gd` | `check_save`, `drive_save` |

## The code witness

The rules are held to the real game twice: by what it does (the
recordings, replayed through them) and by what its code says. A rule
cites the BASIC lines it follows with a comment, `## @witness SHORE LEAVE
2087-2098`, and `tools/witness.py` sets that against the listing, line
by line, in `analysis/witness/<PROGRAM>.md`: every line is logic,
presentation or waived (with a reason), and the tool fails for a line
that changes or decides something and that no rule cites, for a cited
line that is not there, and for a `CALL` into machine code that no
`@witness-asm <address>` tag accounts for. It also says which cited
lines no recording ever ran, the ones the rules rest on the listing
alone for. `python3 tools/witness.py --check` is part of the suite.

It covers every program the rules came from (the ledgers are in
`analysis/witness/`); `STARSHIP SIMULATOR` is still listed as in
progress. COLLECT lines 820 (a planet with no technology) and 1090 (the
superior one's loot) are the ones no recording runs.

## Flight

`scenes/native_flight.tscn` is the flight in Godot's own 3D. The ship
flies by `scripts/rules/flight_rules.gd`, the original's rules as a
continuous model (the same turn rates, stops, climb, world edge and sink,
a pass of the original being one second), held to the original's own
arithmetic by `check_flight_rules`. The view is a camera with the
original's attitude convention, the planet a shaded sphere (the game's
cluster of points round its planet are the lights of its cities, more lit
the more advanced the planet), the rest of the game's points stars, and
solid low-poly craft made from the original's wireframes
(`assets/models/`, by `tools_make_models.gd`). Below the atmosphere there
is a ground and a sky.

Keys are the original's: `1` `2` `3` `4` speed, `A` autopilot, `B`
condition, `S` shields, `W` missile or laser, `C` command console, `R`
radar, `H` hyperdrive. The arrow keys are the stick (or a joystick axis
mapped to the stick actions) and SPACE is the button.

The panel (`scripts/flight/hud_overlay.gd`, `switch_panel.gd`): SPEED,
a green CRT display on the Apple's text screen (40 columns across, six rows, two-column printing) that is written to (`N` puts up the position and headings in seven-segment digits, `F1` or `?` the keys, the same key takes them down; messages such as "THE DEFENDER IS DESTROYED" appear on it); SPEED and ENERGY bars, TURN and VERT dials; three switches in a small
3D scene of their own, which can be clicked as well as keyed: a push
button for the shields, a rocker AUTO / MNL and a rocker missile / laser;
the damage-control panel (dark plastic, raised amber lettering, twelve
LED bulbs, a scanner of LEDs that sweeps while the damage alert is on);
the attitude ball (a shaded sphere, with the orbit ring and pointers to
the enemy and the planet); a target bracket on the defender; and a
yellow or red line round the screen for condition 2 or 3. **AUTO** is as
the original had it: the stick is not read, so the ship keeps the stick
position it had when AUTO went on; a new game starts in manual.

What the original does that is kept (the rules files have the full
lists):

- The world wraps at ±20000. Bank does not return to level.
- The laser adds `1/(tech+1)` to the defender's damage and the result is
  stored in a byte, so it does nothing to a defender at technology 1 or
  more. It still moves the planet towards surrender.
- Firing on a planet that has surrendered makes it hostile again.
- Once raised shields have taken a hit, every later pass in range wears
  them down whether or not anything is seen to hit.
- The missile is tested against the place the defender would be, whether
  or not one is there.
- The hyperdrive goes to whatever star the navigation computer was last
  set to. The energy it costs is meant to be the distance, but `H_D`
  reads the X table three times over, so the two stars' Y and Z do not
  count and it is not the distance the chart gives.

Not kept: the 3D engine's sine table slips (entry 25 is wrong, and
negative results are a little too negative), the factor that stays unset
at two angles, the cosines read as nothing at 64, 128 and 191, the turn
the heading takes when the stick holds the nose past its stop, the
alternating hi-res pages and their stale gauge markers, and the white
flashes (the screen flashes in Godot's way).

## Star chart

The central computer's "GALAXY MAP", a vector display over the front
window, like the radar (`scripts/flight/vector_chart.gd` over
`scripts/rules/chart_rules.gd`, held to a recording that put the paddles to
fifty places: `check_chart_rules`). `G` puts it up in the flight; the
console's GALAXY MAP shows it too, and Space then goes back to the console.
What it says is written on the console's display, not on the glass. Twenty stars by X and Y, a
different mark for near, middle and far Z, violet for a secured one, a
box round the star the ship is at. Point at a star and click (or the
arrow keys and Enter) and it says what the star is called, where it is
and how far from here; "Y" to the question runs the console with that
star's page. It does not set a course: that is the navigation
computer's job.

Kept from the original (and what the recording confirms):

- A star's cell is three columns of ten dots and two rows of five, and
  the first star in the list whose cell the cursor is in wins: aiming at
  VARCAR finds BARNARD'S STAR, which is a row below it and earlier, and
  aiming at CYGNI finds PROCYON.
- The cursor is held between 10 and 270 across and 10 and 145 down.
- "Y" at the question gives the once-a-trip base flag back (the original
  writes an 8 into the byte `SHORE LEAVE` keeps it in).
- Star 16 is "GROOMBRIDGE 168" here and in `COM`, "GROOMBRIDGE 1618" in
  `STATUS` (and the port's reports) and `COLLECT`.
- Applesoft's `INT(H * 1.19)` puts paddle readings 100 and 200 one dot
  left of where exact arithmetic would.

Not kept: the flickering cross and the black `DRAW` that took the star
under it off, the search taking longer the further down the list a star
is, any key at all leaving (Space and Escape do), any key but Y meaning
no (N and Escape do), and the eight flight-panel lamps the original
paints on the way out (the flight scene does its own).

## The planet record and SOL's flag

`CALL 38825` swaps a planet's 16-byte record (defender, fighters,
strength, …) between the table and the working bytes on every arrival,
departure and save. It copies seventeen bytes. The seventeenth working
byte is SOL's "secured" flag, so that flag always holds the first byte
of the record *after* the current planet's: 100 at SOL in a new game.

The chart tests the flag for `= 1` and draws SOL white (not secured);
`COM`'s directory tests it for `<> 0` and says SOL HAS BEEN SECURED.
Storing a record writes the byte back, into the next planet's defender
threshold.

Ported as it is: `GameState.planet_secured` holds bytes, not flags, and
`store_planet_record()` / `load_planet_record()` carry the seventeenth.
The real game's log shows the 100 (`analysis/live/jump/`), and
`check_save` and the jump recordings show it.

## Save and load

`END.bas` and `START.bas`: saving is refused in an atmosphere ("YOU MUST
BE IN ORBIT TO SAVE GAME") and the ship's place is saved with the game.
The file is JSON in `user://`, not the original's three binary files. The
title's CONTINUE is there when a game is saved and loads it; the file
stays until it is saved over.

Not kept: the original's saved game could be taken up once, at the next
boot, and no other (the boot cleared the mark before it asked "(N)EW
GAME OR (O)LD GAME?"; `analysis/live/save/` has the recordings), the old
game skipping the panel's lamp routine, and the reboot after a lost
ship, which is the way back to the title.

`check_save` saves, loads and compares every field and the planet
record's seventeenth byte; `drive_save` goes through the title, flight,
the console and END's menu.

## END

The console's "4) END" is one panel (`scripts/end/end_console.gd` over
`scripts/rules/end_rules.gd`, held to the recordings by `check_end_rules`):
1) SAVE GAME, 2) CONTINUE PRESENT GAME, 3) END GAME. A save is refused in
an atmosphere (the original's refusal and wording); "2" goes on with the
game by way of the flight scene. Not kept, as they were the machine and not the game:

- **A key that was not a number lost the game in hand.** The original's
  choice was read with `GET C`, a numeric variable: a letter, RETURN or
  ESC was a ?SYNTAX ERROR, which went to the one error screen of the
  disk's DOS ("SYSTEM ERROR!" and "PRESS ANY KEY TO REBOOT", then a
  boot, which used a saved game up). Here only the three choices (the
  keys 1 to 3 or the buttons) do anything. The recordings of those keys
  are in `analysis/live/end/end_key_*.log`.
- **"3) END GAME" hung the machine,** poking zeros up through memory
  until the screen went black. The application closes.

A save that cannot be written says so (THE GAME COULD NOT BE SAVED.);
that is the port's own, where the Apple would have had a DOS error.

## Sound

Every sound in the game is one of two machine-code routines: LASER
(`$92D1`, fourteen falling chirps) and SOUND GEN (`$9276`, shift-register
noise with a duration set by two POKEs). `autoload/audio_manager.gd`
synthesises both from their disassembly; it is the shape of the sound,
not a cycle-exact speaker. They are played where the original calls
them.

## Tests

From `godot-remake/`. Each prints one summary line and exits non-zero on
a difference.

    godot --headless --path . res://tests/check_chart_rules.tscn     # GALAXY MAP: 50 recorded paddle positions through the rules, and the 18 stars' marks on the recorded page
    godot --headless --path . res://tests/check_end_rules.tscn       # END: the menu, the refusal and "GAME SAVED." as the real game printed them
    godot --headless --path . res://tests/check_com_rules.tscn       # COM: 5 recorded routes through the rules, 201 screens rebuilt from the characters it drew
    godot --headless --path . res://tests/check_radar_rules.tscn     # RADAR and the I.D. texts against the recordings
    godot --headless --path . res://tests/check_combat_rules.tscn    # fighting (missile, lasers, damage, fighters, EX/DMG/S-X) against analysis/live/combat
    godot --headless --path . res://tests/check_hyperdrive_rules.tscn # hyperdrive cost, refusals, re-entry and orbit against the verified legacy code
    godot --headless --path . res://tests/check_save.tscn            # save and load, the planet record's byte
    godot --headless --path . res://tests/check_ground_rules.tscn    # GROUND FORCES, RECALL, COLLECT: 14 recorded routes through the rules, state and text
    godot --headless --path . res://tests/check_flight_rules.tscn    # the continuous flight model against the original's arithmetic, the engine's matrix and the camera
    godot --headless --path . res://tests/check_report_rules.tscn    # STATUS and SUPPLY: 6 recorded routes, 20 pages as the real game printed them
    godot --headless --path . res://tests/check_shore_rules.tscn     # SHORE LEAVE: 7 recorded routes through the rules, state and text
    godot --headless --fixed-fps 60 --path . res://tests/drive_chart.tscn    # the vector chart, by pointer and keys: a click, the question, Y and N, Space, the way to the console and back
    godot --headless --fixed-fps 60 --path . res://tests/drive_com.tscn      # the console scene, by keys: the lamps, every menu, a course, the directory, every way out of it
    godot --headless --fixed-fps 60 --path . res://tests/drive_radar.tscn    # the vector radar and I.D. over the flight, by keys
    godot --headless --fixed-fps 60 --path . res://tests/drive_save.tscn     # title, END, save, CONTINUE
    godot --headless --fixed-fps 60 --path . res://tests/drive_ground_forces.tscn   # the ground forces scene, by keys: refusals, recall, a win, a retreat, a loss
    godot --headless --fixed-fps 60 --path . res://tests/drive_end.tscn             # END's menu, by keys: a save, a refused save, continue
    godot --headless --fixed-fps 60 --path . res://tests/drive_native_flight.tscn   # the native flight scene: the stick, the speed keys, the lamps, C and R
    godot --headless --fixed-fps 60 --path . res://tests/drive_reports.tscn         # the two report panels: what is on show, and the way back to the console
    godot --headless --fixed-fps 60 --path . res://tests/drive_shore_leave.tscn     # commands 3 to 8, by keys: every question, every refusal, what each leaves behind

The `check_*_rules` tests need the recordings in `../analysis/live/` (and `tests/golden/`). A compared
byte is never adjusted to make a test pass: both times a test differed
from the real game by a handful of bytes, the difference was something
the original does that nobody had noticed (the seventeen-byte copy;
`COM` printing through the chart's leftover text window).

`COM`'s recording put right two things the listing had been misread
for: a wrong key at the command menu asks again (it does not fall into
the missing line 30), and the directory's "2) RETURN" comes out at the
command menu, not at the navigation computer its `GOTO` names.

### The two reports

`STATUS` and `SUPPLY` are one panel each, not two screens a key apart,
and nothing is painted or waited for. What the real game printed is the
rules' (`scripts/rules/report_rules.gd`, held to the recordings by
`check_report_rules`), but for what the machine got in the way of:

- `HULL DMG` is the damage, so a whole ship reads 0%. `ENERGY` is a
  percentage of 62 and a full ship has 63; the listing caps the 101.
  `ENV.` and `NAV.COMP.` are always 100%. All as the original.
- A condition, morale or place with no word for it prints no word. The
  original prints nothing, not even the end of its line, and the next
  line runs on after it.
- `THE TROOPS ARE ALL DEAD!` is in the original's listing and cannot
  appear (it tests two bytes that are neither of them the troops). Here
  it appears when the troops are 0.
- `* ELECTRONIC PARTS` is not cut short, and 2550 pounds of platinum
  are not `= 255POUNDS`: the original's numbers have three cells before
  its unit.

### The radar

`RADAR` is a vector display over the front window, in the manner of an early
arcade game (`scripts/flight/vector_radar.gd`): thin glowing lines, nothing
filled, drawn live while the flight goes on behind it. A plan of the world
from above shows the planet as a wire sphere, the stars, the dashed box the
defender fires from, the defender as its own wire-frame (the original's
model data), and the ship as an arrow along its heading, with a sweep turning
round the planet. `I` shows the SHIP I.D.: the defender's wire-frame, large,
turning slowly beside the plan. All the writing is on the console's display
(the numbers and keys for the radar, what the original's I.D. program says of
the ship for the I.D.).
`R`, `X` or Escape close it; the console's RADAR shows it over the flight and
X goes back to the console. With the radar shot away it shows nothing. Whether
it works, which I.D. text a defender gets (type 2 gets the light cruiser's) and
where it goes back to are `radar_rules.gd`, held to the recordings by
`check_radar_rules`; `drive_radar` goes through it by keys.

### Fighting, hyperdrive, the atmosphere

`scripts/rules/combat_rules.gd` is a fight pass by pass (missile box,
firing box, lasers, shields, damage, fighters, the ends EX/DMG/S-X),
compared with `analysis/live/combat/combat.log` (dice count and every
byte). `hyperdrive_rules.gd` and the re-entry/orbit helpers in
`flight_rules.gd` are compared with the byte-verified legacy code.
`scripts/flight/native_flight.gd` shows them: beams, missile, explosion,
a hyperspace burst, a ground plane and sky below the atmosphere.

## The look

The native screens share one theme (`theme/space_vikings.tres`) and one
font, `assets/fonts/space_vikings.res` (from `font_source/space_vikings.ttf`, made by `tools/make_font.py`; the `.res` holds the data so a fresh clone needs no import) from
the game's own character table (the 7x8 glyphs `HI-RES CHARACTER
GENERATOR` draws from). The lit dots of each glyph are followed as
lines, eased into curves and drawn with a round pen, then set wide and
monospaced, so the letters are the game's (slanted, a little uneven) and
smooth at any size, in the manner of an early-80s display face. The
accents are the Apple hi-res colours.

## Liberties

Where the port departs from the original on purpose:

- **Stick and button.** The Apple has two paddles and a button. In
  flight the arrow keys are the stick hard over while held, or a little
  off centre for one pass when tapped; SPACE is the button, and a tap
  between two passes is remembered. On the chart the mouse is the
  paddles (the cross goes to the pointer), the arrow keys turn them, and
  a click or ENTER is the button.
- **Key hints** on the flight, chart, console, radar and END screens,
  outside the Apple's picture.
- **The console** is one panel with the lamps always beside it, not a
  screen painted over the flight panel a row at a time. A wrong key is
  not scolded and waited out; only the keys offered do anything. The
  directory's stars are buttons as well as the number asked for. As in
  the original, "2) RETURN" there comes out at the command menu, not at
  the navigation computer its `GOTO` names. The original's `GOSUB` it
  leaves on BASIC's stack each time (thirty would end in SYSTEM ERROR)
  is not kept.
- **The reports** (above) show both pages at once, and `STATUS` adds the
  star the troops were left at when they are not aboard: the original's
  says only PLANETSIDE or SHORE LEAVE, never where.
- **Ground battle retreat.** In the original any key at all retreats.
  The scene has a RETREAT button (and R). As in the original, the order
  is obeyed after the round in hand, which is fought and paid for.
- **Ground battle reports** wait about as long as the original's, but
  a key or a click moves on; a refusal is said under the menu, which
  stays up; the numbers are on show from the start.
- **Shore leave, enlisting, weapons, repairs, base.** A number is typed
  into a field that takes digits only; the original made what it could
  of any characters, so a number below zero or a part of a troop could
  be enlisted. Y and N are asked for by name; the original took any key
  but N as yes to the repair bill, and asked it even of a bill of
  nothing. TOO MANY TROOPS asks again where the original began the
  command again. What is said stays up about as long as the original's,
  and a key or a click moves on.
- **COLLECT's two slips are fixed** (below), and likewise the other
  quirks of the machine: the keys that were not a number losing the game
  in hand, the saved game used up at one boot, hung machines.

## Not ported, estimated, or unverified

- `GROUND FORCES`: two rules rest on the listing alone, as no
  recording reaches them (a retreat with morale already 0; a primitive
  planet whose strength was not 0 already). Line 172 (one escort
  fighter, a planet that has given in) puts the battle screen up and
  takes it down with nothing said, as the original does.
- `SHORE LEAVE`: the cost of mending anything but the energy is worked
  from `100 - D`, where Applesoft's `100 - ((D / 100) * 100)` is off by
  about one part in 10^8 for some D (`../analysis/live/shore/`); a cost
  could be one credit out where the product falls that close to a whole
  number. Every bill in the recordings comes out the same.
- `COLLECT`'s two slips are fixed, not ported: a primitive planet's
  silver is its own sum (the original set it to the gold), and titanium
  is collected (the original poked the wrong address). Simpler Godot
  decides what of the original's quirks stay.
- `RADAR` pokes 38151 with 5 on its way to an I.D. program. Nothing
  found reads a 5 there, and the port does not keep it.
- The save file keeps the byte after the record table
  (`planet_record_overrun`, which planet 20's seventeen-byte copy
  reaches). The original saves `P/F` without it (`L$140`); what an old
  game finds in that byte has not been looked at.
- Open questions about the original's own code are marked ❓ in
  `CALL_SITES.md`.

## Convention

No script uses `class_name`: it needs Godot's global class cache, which
only exists once the project has been opened in the editor, and a fresh
clone run from the command line has none. Scripts `preload()` each other
into a local const (see `scripts/rules/combat_rules.gd`). Scripts that
need the `GameState` autoload are run as scenes.
