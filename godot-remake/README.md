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

## Two kinds of screen

The original is a dozen BASIC programs that chain to each other and
share one hi-res page, with machine code for the 3D view, the text and
the panel lamps. The port has that game in two states.

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
| Planet record copy, new-game data, save and load | `autoload/game_state.gd` | `check_save`, `check_jump` |

**Standing in.** The rules are the original's (formulas, gates, order of
effects, quirks) but the screen is Godot buttons and labels, not the
hi-res page, and nothing is timed. These are next in line to be ported
the first way:

| Original program | Stand-in |
|---|---|
| `COM` (command console, central computer, navigation computer, directory) | `scripts/ui/com_menu.gd`, `central_computer.gd`, `nav_computer.gd`, `galaxy_directory.gd` |
| `STATUS`, `SUPPLY` | `status_screen.gd`, `supply_report.gd` |
| `RADAR`, `SHIP # N I.D.` | `radar_screen.gd` (a Godot 3D camera on the real model), `ship_id_screen.gd` |
| `GROUND FORCES`, `COLLECT`, recall | `ground_forces.gd`, `collect.gd`, `recall.gd` |
| `SHORE LEAVE` | `shore_leave.gd`, `enlist.gd`, `buy_weapons.gd`, `sell_loot.gd`, `establish_base.gd`, `cryogenics.gd`, `repair_ship.gd` |
| `END` | `end_game.gd` |
| `START` (title, new or old game) | `start_screen.gd` |

Each stand-in's doc comment lists the BASIC lines it follows.

## How a faithful port is put together

Three files per program:

- **the program** (`flight_program.gd`, `chart_program.gd`): the BASIC
  statements, a function for each stretch between which time passes on
  the real machine. No timing.
- **the loop** (`flight_loop.gd`, `chart_loop.gd`): a coroutine that
  calls those in order with the measured waits between, in video frames.
  Everything that takes time goes through one `wait` callable.
- **the scene** (`space_flight.gd`, `star_chart.gd`): points `wait` at a
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
BE IN ORBIT TO SAVE GAME"), the ship's place is saved with the game, and
a loaded game starts in orbit with the instruments redrawn. The file is
JSON in `user://`, not the original's three binary files.

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
    godot --headless --path . res://tests/check_save.tscn            # record copy, save, load
    godot --headless --path . -s res://tests/check_flight_core.gd    # flight arithmetic against the model
    godot --headless --path . -s res://tests/check_a2_3d1.gd         # 200 views against tools/a2_3d1_view.py
    godot --headless --fixed-fps 60 --path . res://tests/drive_flight.tscn   # the flight scene, by key events
    godot --headless --fixed-fps 60 --path . res://tests/drive_chart.tscn    # the chart scene, by mouse and keys

The first four need the recordings in `../analysis/live/`. A compared
byte is never adjusted to make a test pass: both times a test differed
from the real game by a handful of bytes, the difference was something
the original does that nobody had noticed (the seventeen-byte copy;
`COM` printing through the chart's leftover text window).

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
- **Key hints** on the flight screen, outside the Apple's picture.
- **Ground battle retreat.** In the original any key at all retreats.
  The stand-in has a Retreat button.
- **Radar** shows the defender's real A2-3D1 model through a Godot
  camera, slowly turning; the original's is still.
- **Shore leave numbers** are typed into a spin box, not the original's
  digit-by-digit entry.
- **The stand-in screens** (above) in general.

## Not ported, estimated, or unverified

- `COM` and everything under it on the hi-res page, with its timing.
  Until then the chart starts dark where the original still shows
  `COM`'s screen while `GALAXY MAP` loads, and the lamps `END`'s
  CONTINUE paints are not timed.
- The time each line of the directory page takes to print is measured
  for one line and assumed for the rest.
- The navigation computer's stand-in numbers stars from 0; the
  original's from 1.
- `GROUND FORCES` never sets the "fought and not paid" marker
  (`morale_flag`) that `H_D` punishes on the next jump.
- Whether a loaded game's first `INSTRUMENTS` flips the lamp switches
  the way a new game's does is assumed, not recorded.
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
