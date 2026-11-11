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
| `GALAXY MAP` (star chart) | `scripts/chart/chart_program.gd`, `chart_loop.gd` | `check_chart` |
| `COM` (command console, central computer, navigation computer, galaxy directory) | `scripts/com/com_program.gd`, `com_loop.gd` | `check_com`, `check_com_damaged`, `check_chart` |
| `END` (save, continue, end game) | `scripts/end/end_program.gd`, `end_loop.gd` | `check_end`, `check_end_atmosphere` |
| DOS's error routine (SYSTEM ERROR, reboot) | `scripts/dos/system_error.gd`, `scripts/shapes/text_screen.gd` | `check_end` |
| `STATUS` (ship and troop report) | `scripts/reports/status_program.gd`, `status_loop.gd` | `check_status`, `check_status_poked`, `check_status_odd`, `check_status_morale` |
| `SUPPLY` (supply report) | `scripts/reports/supply_program.gd`, `supply_loop.gd` | `check_supply`, `check_supply_poked` |
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

## How a faithful port is put together

Three files per program:

- **the program** (`flight_program.gd`, `chart_program.gd`,
  `com_program.gd`): the BASIC
  statements, a function for each stretch between which time passes on
  the real machine. No timing.
- **the loop** (`flight_loop.gd`, `chart_loop.gd`, `com_loop.gd`): a
  coroutine that
  calls those in order with the measured waits between, in video frames.
  Everything that takes time goes through one `wait` callable.
- **the scene** (`space_flight.gd`, `star_chart.gd`, `com_console.gd`):
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

The central computer's "GALAXY MAP". Twenty stars by X and Y, a
different mark for near, middle and far Z, violet for a secured one, a
box round the star the ship is at. The paddles move a cross; the button
asks about the star under it (name, position, distance from here) and
offers the directory page. It does not set a course: that is the
navigation computer's job.

Kept from the original:

- One turn of the chart's loop takes 82 ms and the cross is on the
  screen for about two fifths of it, so it flickers and moves twelve
  times a second.
- The answer takes longer the further down the list the star is (43 ms a
  star), and "THERE IS NO STAR SYSTEM THERE" takes the whole list.
- The cross is taken off with a black `DRAW`, which takes the star under
  it off too until the chart is drawn again.
- Any key leaves, not only the space the screen asks for.
- Leaving goes through `INSTRUMENTS`, which redraws the panel without
  calling TRANLIT; the chart then paints the eight lamps itself as plain
  blocks. They stay like that until a lamp key is pressed in flight.
- "Y" at the question writes into the byte `SHORE LEAVE` keeps its
  once-a-trip base flag in, and the directory page clears it: asking the
  chart about a star gives the base its turn back.
- Star 16 is "GROOMBRIDGE 168" here and in `COM`, "GROOMBRIDGE 1618" in
  `STATUS` and `COLLECT`.
- Applesoft's `INT(H * 1.19)` puts paddle readings 100 and 200 one dot
  left of where exact arithmetic would.

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
`END`'s screen is the original's (below); the title is still a
stand-in. What happens round them is the original's, recorded with
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

## END, and SYSTEM ERROR

The console's "4) END" is the original's menu on the hi-res page: 1)
SAVE GAME, 2) CONTINUE PRESENT GAME, 3) END GAME. Three things about it
are the original's and are kept, harsh as the first one is:

- **A key that is not a number loses the game in hand.** The choice is
  read with `GET C`, a numeric variable. A digit other than 1-3 (and
  space, `.`, `+`, `-`, `,`, `:`, `E`, which Applesoft reads as 0) draws
  the menu again; a letter, RETURN or ESC is a ?SYNTAX ERROR, which goes
  to the game's error line. Each was pressed on the real game.
- **Every error in the game ends at one screen.** The disk's DOS has
  had its error routine replaced: it clears the text screen, writes
  "SYSTEM ERROR!" and "PRESS ANY KEY TO REBOOT", waits for a key and
  boots the disk. Every program's `ONERR` line runs it (as DOS's `INT`
  command, repointed). The port has that screen, in the Apple's own
  text characters, and its key goes back to the title as a boot, which
  uses a saved game up. A save that cannot be written ends there too
  (on the Apple a DOS error would; that one is from the disassembly,
  not tried).
- **"3) END GAME" hangs the machine.** It pokes zeros up through memory
  from address 1 and never gets to its `END`: half a second later the
  screen is black and the Apple has to be switched off. The port's
  screen goes black at the same frame; a second later it closes the
  application.

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
    godot --headless --path . res://tests/check_chart.tscn           # the chart at 9 stops, page and text cursor
    godot --headless --path . res://tests/check_com.tscn             # the console at 34 stops and back in flight: page, cursor, window
    godot --headless --path . res://tests/check_com_damaged.tscn     # the same with systems out: inverse labels, no computer
    godot --headless --path . res://tests/check_end.tscn             # END at 20 stops and back in flight; its keys; SYSTEM ERROR dot for dot
    godot --headless --path . res://tests/check_end_atmosphere.tscn  # END's refusal in an atmosphere, 6 stops
    godot --headless --path . res://tests/check_status.tscn          # STATUS at 6 stops and back in flight, both pages
    godot --headless --path . res://tests/check_status_poked.tscn    # every number on it changed, and THE TROOPS ARE ALL DEAD!
    godot --headless --path . res://tests/check_status_odd.tscn      # a condition, a morale and a place with no word
    godot --headless --path . res://tests/check_status_morale.tscn   # the other morales, places and conditions, 22 stops
    godot --headless --path . res://tests/check_supply.tscn          # SUPPLY at 8 stops: both pages, "1" and round again
    godot --headless --path . res://tests/check_supply_poked.tscn    # loot of four and five digits, and what the units do to it
    godot --headless --path . res://tests/check_radar.tscn           # RADAR from flight, and X back to it
    godot --headless --path . res://tests/check_radar_ids.tscn       # RADAR and each of the four I.D. programs, round and round, 14 stops; a type 2
    godot --headless --path . res://tests/check_radar_com.tscn       # RADAR from the console and back to it, and by way of an I.D.
    godot --headless --path . res://tests/check_radar_dead.tscn      # the radar shot away, from flight and from the console
    godot --headless --path . res://tests/check_radar_ship_0.tscn    # the radar's picture with nothing in orbit, and how long it takes
    godot --headless --path . res://tests/check_radar_ship_1.tscn    # with the space lab
    godot --headless --path . res://tests/check_radar_ship_4.tscn    # with the heavy cruiser
    godot --headless --path . res://tests/check_save.tscn            # record copy, save, the boot, an old game's panel
    godot --headless --path . res://tests/check_ground_rules.tscn    # GROUND FORCES, RECALL, COLLECT: 14 recorded routes through the rules, state and text
    godot --headless --path . res://tests/check_shore_rules.tscn     # SHORE LEAVE: 7 recorded routes through the rules, state and text
    godot --headless --path . -s res://tests/check_flight_core.gd    # flight arithmetic against the model
    godot --headless --path . -s res://tests/check_a2_3d1.gd         # 200 views against tools/a2_3d1_view.py
    godot --headless --fixed-fps 60 --path . res://tests/drive_flight.tscn   # the flight scene, by key events
    godot --headless --fixed-fps 60 --path . res://tests/drive_chart.tscn    # the chart scene, by mouse and keys
    godot --headless --fixed-fps 60 --path . res://tests/drive_com.tscn      # the console scene, by keys, every way out of it, and both reports through and back
    godot --headless --fixed-fps 60 --path . res://tests/drive_radar.tscn    # the radar scene, by keys: from flight, from the console, an I.D. and back, no radar
    godot --headless --fixed-fps 60 --path . res://tests/drive_save.tscn     # title, END, save, continue, SYSTEM ERROR, three boots, END GAME
    godot --headless --fixed-fps 60 --path . res://tests/drive_ground_forces.tscn   # the ground forces scene, by keys: refusals, recall, a win, a retreat, a loss
    godot --headless --fixed-fps 60 --path . res://tests/drive_shore_leave.tscn     # commands 3 to 8, by keys: every question, every refusal, what each leaves behind

The first twenty-three need the recordings in `../analysis/live/`. A compared
byte is never adjusted to make a test pass: both times a test differed
from the real game by a handful of bytes, the difference was something
the original does that nobody had noticed (the seventeen-byte copy;
`COM` printing through the chart's leftover text window).

`COM`'s recording put right two things the listing had been misread
for: a wrong key at the command menu asks again (it does not fall into
the missing line 30), and the directory's "2) RETURN" comes out at the
command menu, not at the navigation computer its `GOTO` names.

### The two reports

`STATUS` and `SUPPLY` are slow and a little broken, and the port is
both. Each takes some eight seconds to show anything even with the
floppy cut down: it paints the view green a row at a time, then lays a
white sheet on it a row at a time, then prints. What the recordings
show that a tidy report would not:

- `HULL DMG` is the damage, so a whole ship reads 0% between rows that
  read 100%. `ENERGY` is a percentage of 62 and a full ship has 63; the
  listing caps the 101.
- `ENV.` and `NAV.COMP.` are always 100%.
- A condition, morale or place with no word for it prints nothing, not
  even the end of its line, and the next line runs on after it. A
  morale of 0 does this, and the hyperdrive can take morale to 0.
- `THE TROOPS ARE ALL DEAD!` is in the listing and cannot appear: it
  tests two bytes that are neither of them the troops, and one is never
  0. (Poked to 0 on the real machine, it prints; the port's does too.)
- `* ELECTRONIC PARTS` is a letter too wide for its column and reads
  `* ELECTRONIC PART= 0`.
- A number has three cells before its unit. 2550 pounds of platinum
  reads `= 255POUNDS`, and 10000 cases of wine `= 100CASES`. `COLLECT`
  lets loot get that large.
- Both read the stardate, the troops and the credits from `MISC FILE`
  with the output on hi-res page 2, and the three prompts leave three
  marks there.

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
- **Key hints** on the flight, chart, console, report, radar and END screens,
  outside the Apple's picture. END's says what a wrong key costs.
  `STATUS`'s adds the star the troops were left at when they are not
  aboard: the original's report says only PLANETSIDE or SHORE LEAVE,
  never where.
- **END GAME closes the application** a second after the screen goes
  black. The original leaves a dead machine to be switched off.
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

- One of the programs `COM` runs, `GROUND FORCES`, is a Godot scene.
  It leaves the hi-res page as it found it, so on the way back `COM`
  starts over the console's last screen, not over what the original's
  program would have left. Every command of the original's ends by
  running `COM` with a marker (38151 = 7) that sends it straight back
  to `GROUND FORCES`; the scene just stays up.
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
- `STATUS` reads the star's name with one `READ` for each place down
  its list. That was timed at SOL only (2.8 frames), and the port waits
  the same for every star: some fraction of a second short at the far
  end of the list.
- `COM`'s waits are fitted to its recording, not timed statement by
  statement: each stop for a key comes within two frames of the real
  machine's, the stretches between are shared out by the characters
  drawn.
- "2) RETURN" in the galaxy directory leaves a `GOSUB` on BASIC's stack
  each time. Some thirty in one stay should run the original out of
  stack and into its error line, which is the SYSTEM ERROR screen; the
  port's directory has no such end, and it has not been tried on the
  real game.
- SYSTEM ERROR has been seen live from `END` only, where the text
  window is the whole screen. The routine writes inside whatever window
  the program left; from a program with a narrower one the message
  would wrap differently. The port keeps the window but not the old
  text-screen contents that would show round it.
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
