extends RefCounted
## STATUS.bas on the clock. status_program.gd is its statements with no
## time in them; this is the order they run in and how long the real
## machine took over each, from `RUN STATUS` until it runs COM again.
##
## `run()` is a coroutine. Everything that takes time goes through
## `wait`, which the scene (report_console.gd) points at a real clock
## and the test (tests/check_reports.gd) at a counter.
##
## The numbers are video frames (1/60 s) of an Apple II+ in MAME, from
## tools/mame/reports_live.lua (when each BASIC line started and when
## each character was drawn); the records are in analysis/live/reports/.
##
## It is a slow report. The program loads for three seconds and a half,
## paints the view green for four more, reads three numbers off the
## floppy for two, and only then lays its white sheet and prints. As in
## flight_loop.gd, the floppy is cut down by DISK_WAIT_SCALE and nothing
## else is.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const StatusProgram = preload("res://scripts/reports/status_program.gd")
const FlightLoop = preload("res://scripts/flight/flight_loop.gd")

## How run() ended.
enum Left {
	STOPPED, ## `stop` was set
	COM, ## line 1400: RUN COM
}

# -- floppy --
const LOAD_STATUS := 203.4 # RUN STATUS, from COM's line 1200
const MISC_FIRST := 107.5 # line 5000: OPEN and READ, up to the first INPUT's prompt
const MISC_SECOND := 14.0 # the first number read, up to the second prompt
const MISC_THIRD := 1.16 # and the third, out of the same sector
const MISC_CLOSE := 2.2

# -- lines 0-60 --
const OPEN := 1.23 # lines 0-15
const FILL_ROW := 1.9027 # line 20, a row
const MISC_OPEN := 0.97 # lines 30-50
const MISC_END := 0.38 # line 60

# -- GOSUB 1230 --
const WIPE_START := 0.52 # up to the first space
const WIPE_ROW := 2.669 # a row of it

# -- the ship, lines 1232-1315 --
## The READs. Measured at SOL, which is the first name; a star further
## down the DATA takes a READ more for each, and that was not measured.
const READ_NAME := 2.82
const TITLE := 1.44 # line 1240
const PLACE := 2.45 # line 1250
const ENERGY_SUM := 1.41 # lines 1255-1256
const ENERGY_CAPPED := 0.21 # line 1256's THEN
const ENERGY := 3.39 # line 1260
const SHIELDS := 4.04 # lines 1270-1294
const HULL := 3.81 # lines 1300-1305
const COMPUTER := 3.54 # line 5100
const RADAR := 2.76 # line 5110
const LASER := 3.39 # lines 5120-5130
const ENGINES := 3.97 # line 1310 up to the GET

# -- the troops, lines 1315-1400 --
const KEY_TAKEN := 0.2 # line 1315 after the GET
const WIPED := 0.29 # line 1232
const TROOPS_TITLE := 1.78 # line 1320
const TROOPS := 2.44 # line 1330
const MORALE := 3.9 # lines 1340-1360
const TROOPS_PLACE := 3.99 # lines 1370-1385
const FIGHTERS := 3.92 # line 5200
const TANKS := 3.14 # lines 5210-5220
const ALL_DEAD_NOT := 1.18 # line 1386 when it prints nothing
const ALL_DEAD := 2.6 # and when it prints
const CLOSE := 0.42 # lines 1390-1400 after the GET

var program := StatusProgram.new()

## Waits that many video frames (1/60 s).
var wait: Callable = func(_frames: float) -> void: pass
## Something to watch: called with "ship" and "troops" before the GET of
## each page, and with "leaving" when the program is about to run COM.
var watch: Callable = func(_what: String) -> void: pass
## Set to make run() come back at the next GET.
var stop := false


func run() -> Left:
	await _disk(LOAD_STATUS)
	program.ran()
	program.open()
	await wait.call(OPEN)
	for y in range(StatusProgram.FILL_ROWS):
		program.fill_row(y)
		await wait.call(FILL_ROW)
	program.misc_open()
	await wait.call(MISC_OPEN)
	for frames: float in [MISC_FIRST, MISC_SECOND, MISC_THIRD]:
		await _disk(frames)
		program.misc_prompt()
	await _disk(MISC_CLOSE)
	program.misc_close()
	await wait.call(MISC_END)

	# the ship
	await _wipe()
	await wait.call(READ_NAME)
	program.title()
	await wait.call(TITLE)
	program.place()
	await wait.call(PLACE)
	await wait.call(ENERGY_SUM + (ENERGY_CAPPED if program.energy_capped() else 0.0))
	program.energy()
	await wait.call(ENERGY)
	program.shields()
	await wait.call(SHIELDS)
	program.hull()
	await wait.call(HULL)
	program.computer()
	await wait.call(COMPUTER)
	program.radar()
	await wait.call(RADAR)
	program.laser()
	await wait.call(LASER)
	program.engines()
	await wait.call(ENGINES)
	watch.call("ship")
	await _get_key()
	if stop:
		return Left.STOPPED
	await wait.call(KEY_TAKEN)

	# the troops
	await _wipe()
	await wait.call(WIPED)
	program.troops_title()
	await wait.call(TROOPS_TITLE)
	program.troops()
	await wait.call(TROOPS)
	program.morale()
	await wait.call(MORALE)
	program.troops_place()
	await wait.call(TROOPS_PLACE)
	program.fighters()
	await wait.call(FIGHTERS)
	program.tanks()
	await wait.call(TANKS)
	await wait.call(ALL_DEAD if program.all_dead() else ALL_DEAD_NOT)
	watch.call("troops")
	await _get_key()
	if stop:
		return Left.STOPPED
	program.close()
	await wait.call(CLOSE)
	watch.call("leaving")
	return Left.COM


## GOSUB 1230: the white sheet.
func _wipe() -> void:
	await wait.call(WIPE_START)
	for c in range(1, StatusProgram.WIPE_ROWS + 1):
		program.wipe_row(c)
		await wait.call(WIPE_ROW)
	program.wipe_end()


## `GET I$`
func _get_key() -> String:
	while program.key_latch < 128:
		if stop:
			return ""
		await wait.call(1.0)
	return program.take_key()


func _disk(frames: float) -> void:
	await wait.call(frames * FlightLoop.DISK_WAIT_SCALE)
