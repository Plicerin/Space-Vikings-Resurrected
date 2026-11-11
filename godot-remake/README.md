# Space Vikings in Godot

A Godot 4 port of *Space Vikings* (Apple II, 1982), built from the
disassembly and analysis in the parent repository. It replaces the
non-functional `js-remake/`.

    godot --path godot-remake

boots to `scenes/start.tscn`: New Game, Load Game, the shape viewer and
the combat demo. Developed and tested on Godot 4.7.

This file says what the port is today. How each fact was found is in the
parent repository's analysis documents (`CALL_SITES.md` first) and in
the git history.

## Three kinds of screen

The original is a dozen BASIC programs that chain to each other and
share one hi-res page, with machine code for the 3D view, the text and
the panel lamps. The port has that game in three states, and is moving
all of it to the first: the same game by the same rules, shown the way
Godot shows things. Anyone after the Apple's own picture, speed and
disk habits has the real disk and an emulator.

**Native, rules held to the real game.** The rules are a class of
their own with no screen in it, played through recordings of the real
game (its keys, the numbers its `RND` gave) and compared with the real
game's memory, variables and printed text at every stop. The screen is
a Godot scene: controls, a theme (`theme/space_vikings.tres`), numbers
that count, waits a key can cut short.

| Original program | Rules | Scene | Held to the real game by |
|---|---|---|---|
| `GROUND FORCES`, `RECALL`, `COLLECT` | `scripts/rules/ground_rules.gd` | `scripts/ui/ground_forces.gd` | `check_ground_rules` (the rules), `drive_ground_forces` (the scene) |
| `SHORE LEAVE` (shore leave, enlisting and weapons, loot, repairs, a base, cryogenics) | `scripts/rules/shore_rules.gd` | `scripts/ui/shore_leave.gd`, one panel over the ground forces menu | `check_shore_rules`, `drive_shore_leave` |
| `GALAXY MAP` (star chart) | `scripts/rules/chart_rules.gd` | `scripts/chart/star_chart.gd` | `check_chart_rules`, `drive_chart` |
| `END` (save, continue, end game) | `scripts/rules/end_rules.gd` | `scripts/end/end_console.gd` | `check_end_rules`, `drive_end` |
| `COM` (command console, central and navigation computers, galaxy directory, damage-control lamps) | `scripts/rules/com_rules.gd` | `scripts/com/com_console.gd` | `check_com_rules`, `drive_com` |
| `STATUS`, `SUPPLY` (the central computer's two reports) | `scripts/rules/report_rules.gd` | `scripts/reports/report_console.gd`, one panel each | `check_report_rules`, `drive_reports` |

**Ported faithfully.** The screen is a software copy of the Apple's
hi-res page, drawn by the original's own statements in the original's
order at the original's speed, and compared byte for byte with the real
game running in MAME.

| Original program | Port | Held to the real game by |
|---|---|---|
| `STARSHIP SIMULATOR` (flight, fighting, keys) | `scripts/flight/flight_program.gd`, `flight_combat.gd`, `flight_loop.gd` | `check_flight_passes`, `check_jump`, `check_flight_core` |
| `INSTRUMENTS`, TRANLIT (panel and lamps) | `flight_program.gd` | the same |
| `RE`, `ORBIT` (into and out of the atmosphere) | `flight_program.gd` | the same |
| `H_D` (hyperdrive) | `flight_program.gd`, `flight_loop.gd` | `check_jump` |
| `EX`, `DMG`, `S/X` (the ends of a fight) | `flight_combat.gd`, `scripts/combat/combat_fx.gd` | `check_jump` |
| A2-3D1 (the 3D view, machine code) | `scripts/shapes/a2_3d1_view.gd`, `a2_3d1_trig.gd` | `check_a2_3d1` |
| `RADAR` | `scripts/radar/radar_program.gd`, `radar_loop.gd` | `check_radar` and the six beside it |
| `SHIP # 0 I.D.`, `# 1`, `# 3`, `# 4` (what is in orbit) | `scripts/radar/ship_id_program.gd`, `ship_id_loop.gd` | `check_radar_ids`, `check_radar_com` |
| Planet record copy, new-game data, save and load | `autoload/game_state.gd` | `check_save`, `check_jump` |
| An old game's way into flight (`START` 3000-3030, `INSTRUMENTS` 210, `GALAXY MAP` 2), and `END`'s CONTINUE | `flight_loop.gd` (`run()`, `lamps()`) | `check_save` |

**Standing in.** The rules are the original's (formulas, gates, order of
effects, quirks) but the screen is Godot buttons and labels, not the
hi-res page, nothing is timed, and nothing holds them to the real
game yet. One is left:

| Original program | Stand-in |
|---|---|
| `START` (title, new or old game) | `start_screen.gd` |

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

Today it covers `GROUND FORCES`, `RECALL`, `COLLECT`, `SHORE LEAVE`,
`STATUS` and `SUPPLY`: no machine-code calls in any of them. The
ledger's open items are the two COLLECT lines no recording runs: 820
(a planet with no technology) and 1090 (the superior one's loot).

## How a faithful port is put together

Three files per program:

- **the program** (`flight_program.gd`,
  `radar_program.gd`): the BASIC
  statements, a function for each stretch between which time passes on
  the real machine. No timing.
- **the loop** (`flight_loop.gd`, `radar_loop.gd`): a
  coroutine that
  calls those in order with the measured waits between, in video frames.
  Everything that takes time goes through one `wait` callable.
- **the scene** (`space_flight.gd`, `radar_console.gd`):
  points `wait` at a
  real clock, shows whichever hi-res page the original would have on
  show, and turns keyboard and mouse into the Apple's keyboard latch,
  paddles and button.

A test points `wait` at nothing and runs the same loop, so what is
played and what is compared with the real game is one piece of code.

Under them, in `scripts/shapes/`:

- `hgr_screen.gd`: one hi-res page, 7680 bytes. `HPLOT`, `HPLOT TO`
  (the ROM's own line routine, which is not Bresenham's), `DRAW`,
  `XDRAW`, `HCOLOR`, `ROT`, `SCALE`, with the palette bit and the
  odd/even column colours behaving as on the Apple.
- `shape_table.gd`: Applesoft shape tables (`ENEMY` is the game's one).
- `char_generator.gd`: the game's hi-res character generator (`$933C`):
  store / inverse / XOR modes, the text window (`POKE 32..35`), `HOME`,
  form feed, wrap and scroll-to-top as the original does them.
- `a2_3d1_view.gd`: the A2-3D1 interpreter, clipper and plotter.
- `hgr_view.gd`: draws a page as a colour monitor would.

The timings come from recordings of the real game:
`tools/mame/*_live.lua` in the parent repository, results in
`analysis/live/`.

## Flight

Keys are the original's: `1` `2` `3` `4` speed, `A` autopilot, `B`
condition, `S` shields, `W` missile or laser, `C` command console, `R`
radar, `H` hyperdrive. The arrow keys are the stick and SPACE is the
button (see "Liberties").

What the original does and a tidy remake would not, all kept; the doc
comments of `flight_program.gd`, `flight_core.gd` and `flight_combat.gd`
have the full lists:

- Two passes alternate between the two hi-res pages, and BASIC's own
  drawing always goes to page 1, so one page shows the gauge markers of
  the pass before.
- A lamp key restarts the program: the frame just drawn is never shown,
  old gauge markers stay until overwritten, the position loses its
  fraction.
- The world wraps at ±20000. Bank does not return to level. Going over
  the top of a loop turns the heading by 126 or 127, not half a turn.
  At two exact angles the ship all but stops along one axis.
- The laser adds `1/(tech+1)` to the defender's damage and the result is
  stored in a byte, so it does nothing to a defender at technology 1 or
  more. It still moves the planet towards surrender.
- Firing on a planet that has surrendered makes it hostile again.
- Once raised shields have taken a hit, every later pass in range wears
  them down whether or not anything is seen to hit.
- The missile is tested against the place the defender would be, whether
  or not one is there.
- The white flashes in a fight are the display switched to the (white)
  lo-res page between two POKEs. `HgrView.flashes_enabled` turns them
  off.
- The hyperdrive goes to whatever star the navigation computer was last
  set to. The energy it costs is meant to be the distance, but `H_D`
  reads the X table three times over, so the two stars' Y and Z do not
  count and it is not the distance the chart gives.

## Star chart

The central computer's "GALAXY MAP", one panel (`scripts/chart/star_chart.gd`
over `scripts/rules/chart_rules.gd`, held to a recording that put the
paddles to fifty places: `check_chart_rules`). Twenty stars by X and Y, a
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
`check_flight_passes` compares the byte on every pass.

## Save and load

`END.bas` and `START.bas`: saving is refused in an atmosphere ("YOU MUST
BE IN ORBIT TO SAVE GAME") and the ship's place is saved with the game.
The file is JSON in `user://`, not the original's three binary files.
`END`'s menu is native (below); the title is still a stand-in. What happens round them is the original's, recorded with
`tools/mame/save_live.lua`:

- **A saved game can be taken up once.** The original's boot loads
  `PLANET FILE`, and if it finds the saved-game mark it clears it and
  writes the file straight back, before it asks "(N)EW GAME OR (O)LD
  GAME?". So the game is there for that boot only, and answering N uses
  it up as well. `GameState.boot()` does the same to the JSON file when
  the title screen first comes up (the mark is the file's `"saved"`;
  the rest of the file is left as it was).
- "O" with nothing saved: "THERE IS NO GAME SAVED" for 170 frames, then
  the question again.
- An old game does not go through TRANLIT. A new game's first
  `INSTRUMENTS` flips all four panel switches (which is how a new game
  comes to have shields down and condition RED); an old game's skips
  that and runs `GALAXY MAP`, which paints the eight lamps as plain
  blocks and goes on to flight. The switches are as they were saved,
  and the lamps stay plain blocks until a lamp key is pressed.
- `END`'s "CONTINUE PRESENT GAME" takes the same road from `GALAXY MAP`
  on.
- When the ship is destroyed the original has to be booted again, so
  the port's way back to the title counts as a boot
  (`GameState.reboot()`).

`check_save` loads the game the real machine saved (the ship where it
was, from the planet's record on the disk) and compares the panel at the
third pass with the real page, every byte.

## END

The console's "4) END" is one panel (`scripts/end/end_console.gd` over
`scripts/rules/end_rules.gd`, held to the recordings by `check_end_rules`):
1) SAVE GAME, 2) CONTINUE PRESENT GAME, 3) END GAME. A save is refused in
an atmosphere (the original's refusal and wording); "2" goes on with the
game by way of the flight scene, the saved-game mark left for it to
take off. Not kept, as they were the machine and not the game:

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

    godot --headless --path . res://tests/check_flight_passes.tscn   # 50 passes of flight, both pages, every byte
    godot --headless --path . res://tests/check_jump.tscn            # 42 passes: fighting, hyperdrive, arrival
    godot --headless --path . res://tests/check_chart_rules.tscn     # GALAXY MAP: 50 recorded paddle positions through the rules, and the 18 stars' marks on the recorded page
    godot --headless --path . res://tests/check_end_rules.tscn       # END: the menu, the refusal and "GAME SAVED." as the real game printed them, the mark after a save
    godot --headless --path . res://tests/check_com_rules.tscn       # COM: 5 recorded routes through the rules, 201 screens rebuilt from the characters it drew
    godot --headless --path . res://tests/check_radar.tscn           # RADAR from flight, and X back to it
    godot --headless --path . res://tests/check_radar_ids.tscn       # RADAR and each of the four I.D. programs, round and round, 14 stops; a type 2
    godot --headless --path . res://tests/check_radar_com.tscn       # RADAR from the console and back to it, and by way of an I.D.
    godot --headless --path . res://tests/check_radar_dead.tscn      # the radar shot away, from flight and from the console
    godot --headless --path . res://tests/check_radar_ship_0.tscn    # the radar's picture with nothing in orbit, and how long it takes
    godot --headless --path . res://tests/check_radar_ship_1.tscn    # with the space lab
    godot --headless --path . res://tests/check_radar_ship_4.tscn    # with the heavy cruiser
    godot --headless --path . res://tests/check_save.tscn            # record copy, save, the boot, an old game's panel
    godot --headless --path . res://tests/check_ground_rules.tscn    # GROUND FORCES, RECALL, COLLECT: 14 recorded routes through the rules, state and text
    godot --headless --path . res://tests/check_report_rules.tscn    # STATUS and SUPPLY: 6 recorded routes, 20 pages as the real game printed them
    godot --headless --path . res://tests/check_shore_rules.tscn     # SHORE LEAVE: 7 recorded routes through the rules, state and text
    godot --headless --path . -s res://tests/check_flight_core.gd    # flight arithmetic against the model
    godot --headless --path . -s res://tests/check_a2_3d1.gd         # 200 views against tools/a2_3d1_view.py
    godot --headless --fixed-fps 60 --path . res://tests/drive_flight.tscn   # the flight scene, by key events
    godot --headless --fixed-fps 60 --path . res://tests/drive_chart.tscn    # the chart scene, by pointer and keys: a click, the question, Y and N, Space, the way to the console and back
    godot --headless --fixed-fps 60 --path . res://tests/drive_com.tscn      # the console scene, by keys: the lamps, every menu, a course, the directory, every way out of it
    godot --headless --fixed-fps 60 --path . res://tests/drive_radar.tscn    # the radar scene, by keys: from flight, from the console, an I.D. and back, no radar
    godot --headless --fixed-fps 60 --path . res://tests/drive_save.tscn     # title, END, save, continue, three boots
    godot --headless --fixed-fps 60 --path . res://tests/drive_ground_forces.tscn   # the ground forces scene, by keys: refusals, recall, a win, a retreat, a loss
    godot --headless --fixed-fps 60 --path . res://tests/drive_end.tscn             # END's menu, by keys: a save, a refused save, continue
    godot --headless --fixed-fps 60 --path . res://tests/drive_reports.tscn         # the two report panels: what is on show, and the way back to the console
    godot --headless --fixed-fps 60 --path . res://tests/drive_shore_leave.tscn     # commands 3 to 8, by keys: every question, every refusal, what each leaves behind

The first sixteen need the recordings in `../analysis/live/`. A compared
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

`RADAR` is the flight program's own picture from somewhere else: the
eye lifted to 20000 above the stars and pointed straight down, A2-3D1
run once, and a violet frame, two diagonals, a cross and a small green
box for the ship drawn over it. What the recordings show that a radar
would not:

- It takes two seconds to draw, every time: the stars come a few to a
  frame, and coming back from an I.D. the whole of it is drawn again.
- A2-3D1 clears all of page 1 for it, so the flight panel is gone while
  the stars come and is copied back afterwards.
- The eye's heading is left alone: the map turns with the ship.
- With the radar shot away (38195 = 0) it draws nothing, says nothing,
  and goes back to whichever program ran it.
- X goes back. Any other key runs the I.D. program of what is in
  orbit: a drawing on a green grid and four or five lines of text, a
  character at a time, and a key from there runs `RADAR` again. With
  nothing in orbit that is a page saying so.
- A defender of type 2 (three planets have one) has no I.D. program of
  its own and gets the light cruiser's.

A2-3D1's call is timed record by record in the port (so much a point,
so much an end of a line, so much a dot), with prices fitted to four
recordings; the whole call comes within a third of a frame of each.

## The look

The native screens share one theme (`theme/space_vikings.tres`) and one
font, `assets/fonts/space_vikings.ttf`, made by `tools/make_font.py` from
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
- **Disk waits.** Every hand-over between programs was a floppy load of
  two to eight seconds. Those waits are kept in proportion and cut to
  15% (`FlightLoop.DISK_WAIT_SCALE`). Nothing the machine computed or
  drew is sped up.
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
- **The title screen** (the stand-in above).

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
- `COLLECT`'s two slips are kept, as they decide what a planet is
  worth: a primitive planet's silver is set to its gold, and titanium
  is never collected.
- The radar's A2-3D1 prices are fitted to four recordings (64 to 144
  frames a call). A picture with far more in it than those had could
  be some frames out.
- `RADAR` pokes 38151 with 5 on its way to an I.D. program. Nothing
  found reads a 5 there, and the port does not keep it.
- The load of `STARSHIP SIMULATOR` after an old game's or CONTINUE's
  lamps (`FlightLoop.LOAD_SIMULATOR_SPINNING`) is worked out from the
  real game's totals with the drive still turning, not timed on its
  own; and the lamps are given the speed measured for them on the way
  out of the chart.
- The save file keeps the byte after the record table
  (`planet_record_overrun`, which planet 20's seventeen-byte copy
  reaches). The original saves `P/F` without it (`L$140`); what an old
  game finds in that byte has not been looked at.
- Open questions about the original's own code are marked ❓ in
  `CALL_SITES.md`.

## Shape viewer and combat demo

Start screen → "Shape Data Viewer" (`scripts/shape_view.gd`): the 26
shapes of `ENEMY` on a hi-res page; LEFT/RIGHT changes `ROT`, UP/DOWN
`SCALE`, ESC goes back. `scenes/contact_sheet.tscn` writes the same
sheet to a PNG headless (`-- --out=sheet.png`). "Combat VFX Demo" plays
each fight effect on its own.

## Convention

No script uses `class_name`: it needs Godot's global class cache, which
only exists once the project has been opened in the editor, and a fresh
clone run from the command line has none. Scripts `preload()` each other
into a local const (see `scripts/shapes/shape_table.gd`). Scripts that
need the `GameState` autoload are run as scenes.
