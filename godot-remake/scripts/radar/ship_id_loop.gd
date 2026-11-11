extends RefCounted
## A SHIP # n I.D. program on the clock. ship_id_program.gd is the
## statements of the four with no time in them; this is the order they
## run in and how long the real machine took over each, from `RUN SHIP
## # n I.D.` until it runs RADAR again.
##
## `run()` is a coroutine. Everything that takes time goes through
## `wait`, which the scene (radar_console.gd) points at a real clock and
## the test (tests/check_radar.gd) at a counter.
##
## The numbers are video frames (1/60 s) of an Apple II+ in MAME, from
## tools/mame/radar_live.lua (when each BASIC line started and when each
## byte of the pages was written); the records are in
## analysis/live/radar/.
##
## They are slow programs: three quarters of a second to wipe the
## radar's picture, a second and a quarter for the grid, and then two
## frames for every point of the drawing, READ by READ. The heavy
## cruiser is five seconds in the drawing. As in flight_loop.gd, the
## floppy loads are cut down by DISK_WAIT_SCALE and nothing else is.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const ShipIdProgram = preload("res://scripts/radar/ship_id_program.gd")
const FlightLoop = preload("res://scripts/flight/flight_loop.gd")

## How run() ended.
enum Left {
	STOPPED, ## `stop` was set
	RADAR, ## line 1070: RUN RADAR
}

# -- floppy: RUN SHIP # n I.D. from RADAR's line 5005, by program --
const LOAD := {0: 119.2, 1: 170.2, 3: 165.2, 4: 198.1}

# -- lines 2-25 --
const OPEN := {0: 1.5, 1: 1.5, 3: 1.4, 4: 0.5} # up to the FOR
const CLEAR_ROW := 2.63 # a row of spaces
const CLEAR_ROW_HTAB := 2.75 # and with the cruisers' HTAB 1
const CLEAR_END := 1.1
const FRAME := 4.45 # line 12
const GRID_COLUMN := 1.155 # line 13, an HPLOT
const GRID_ROW := 1.33 # line 14, an HPLOT
const DATA_OPEN := 0.48 # lines 20-25

# -- the drawing, lines 1000-1050 once round --
const POINT := 2.04 # a point read and plotted
const LINE_DOT := 0.0054 # and each dot of an HPLOT TO
const SIDE := 0.66 # code 77
const END := 0.8 # code 127

# -- lines 1060-1070 --
const TEXTS := {0: 4.04, 1: 5.68, 3: 5.6, 4: 6.56}
const PROMPT := 0.2
const KEY_TAKEN := 0.13

var program: ShipIdProgram

## Waits that many video frames (1/60 s).
var wait: Callable = func(_frames: float) -> void: pass
## Something to watch: called with "id" before the GET, and with
## "leaving" when the program is about to run RADAR.
var watch: Callable = func(_what: String) -> void: pass
## Set to make run() come back at the GET.
var stop := false


## `ship` is the number RADAR ran: 0, 1, 3 or 4.
func _init(ship: int = 0) -> void:
	program = ShipIdProgram.new(ship)


func run() -> Left:
	var ship := program.ship
	await _disk(LOAD[ship])
	program.ran()
	program.open()
	await wait.call(OPEN[ship])
	for j in range(1, ShipIdProgram.CLEAR_ROWS + 1):
		program.clear_row(j)
		await wait.call(CLEAR_ROW_HTAB if ship >= 3 else CLEAR_ROW)
	program.clear_end()
	await wait.call(CLEAR_END)

	program.frame() # 12
	await wait.call(FRAME)
	for j in range(ShipIdProgram.GRID_FIRST_COLUMN, ShipIdProgram.GRID_LAST_COLUMN + 1,
			ShipIdProgram.GRID_STEP): # 13
		program.grid_column(j)
		await wait.call(GRID_COLUMN)
	for j in range(ShipIdProgram.GRID_FIRST_ROW, ShipIdProgram.GRID_LAST_ROW + 1,
			ShipIdProgram.GRID_STEP): # 14
		program.grid_row(j)
		await wait.call(GRID_ROW)
	program.data_open() # 20
	await wait.call(DATA_OPEN)

	while program.has_data(): # 1000-1050
		var code := program.read()
		if code == ShipIdProgram.END:
			await wait.call(END)
			break
		if code == ShipIdProgram.SIDE:
			await wait.call(SIDE)
		elif code == ShipIdProgram.LINE:
			await wait.call(POINT + LINE_DOT * program.line_dots)
		else:
			await wait.call(POINT)

	program.texts() # 1060
	await wait.call(TEXTS[ship])
	program.prompt()
	await wait.call(PROMPT)
	watch.call("id")
	await _get_key()
	if stop:
		return Left.STOPPED
	program.key_taken()
	await wait.call(KEY_TAKEN)
	watch.call("leaving")
	return Left.RADAR


## `GET A$`
func _get_key() -> String:
	while program.key_latch < 128:
		if stop:
			return ""
		await wait.call(1.0)
	return program.take_key()


func _disk(frames: float) -> void:
	await wait.call(frames * FlightLoop.DISK_WAIT_SCALE)
