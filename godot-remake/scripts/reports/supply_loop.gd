extends RefCounted
## SUPPLY.bas on the clock. supply_program.gd is its statements with no
## time in them; this is the order they run in and how long the real
## machine took over each, from `RUN SUPPLY` until it runs COM again.
##
## `run()` is a coroutine. Everything that takes time goes through
## `wait`, which the scene (report_console.gd) points at a real clock
## and the test (tests/check_reports.gd) at a counter.
##
## The numbers are video frames (1/60 s) of an Apple II+ in MAME, from
## tools/mame/reports_live.lua (when each BASIC line started and when
## each character was drawn); the records are in analysis/live/reports/.
##
## SUPPLY reads MISC FILE before it paints, where STATUS paints first:
## the drive is still turning from the load, and the read is a second
## shorter for it. As in flight_loop.gd, the floppy is cut down by
## DISK_WAIT_SCALE and nothing else is.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const SupplyProgram = preload("res://scripts/reports/supply_program.gd")
const FlightLoop = preload("res://scripts/flight/flight_loop.gd")

## How run() ended.
enum Left {
	STOPPED, ## `stop` was set
	COM, ## line 1520: RUN COM
}

# -- floppy --
const LOAD_SUPPLY := 155.05 # RUN SUPPLY, from COM's line 20000
const MISC_FIRST := 58.1 # line 5000: OPEN and READ, up to the first INPUT's prompt
const MISC_SECOND := 14.0 # the first number read, up to the second prompt
const MISC_THIRD := 1.15 # and the third, out of the same sector
const MISC_CLOSE := 2.2

# -- lines 0-20 --
const OPEN := 2.06 # lines 0-18
const MISC_END := 0.38 # line 19 after its GOSUB
const FILL_ROW := 1.911 # line 20, a row

# -- line 1400 --
const WIPE_START := 1.08 # up to the first space
const WIPE_ROW := 2.793 # a row of it
const WIPE_END := 0.4 # the title, and on to line 1405
const WIPE_RETURN := 0.52 # the title and the RETURN

# -- the first page, lines 1405-1450 --
const FIRST_ROW := 0.1 # line 1405, and 1465
## Lines 1410-1440: how many of the page's entries each line of BASIC
## prints, and how long the line takes.
const FIRST_PAGE := [[2, 4.12], [2, 4.71], [2, 3.86], [1, 2.34]]
const FIRST_PROMPT := 1.75 # line 1450 up to the GET

# -- the second page, lines 1460-1510 --
const KEY_TAKEN := 0.19 # line 1460
const SECOND_PAGE := [[2, 4.55], [2, 4.56], [1, 2.33]] # lines 1470-1485
const LAST_LINE := 3.87 # line 1490: the art works and the credits
const SECOND_PROMPT := 3.32 # line 1500 up to the GET
const AGAIN := 0.2 # line 1510's THEN
const CLOSE := 0.8 # lines 1510-1516

var program := SupplyProgram.new()

## Waits that many video frames (1/60 s).
var wait: Callable = func(_frames: float) -> void: pass
## Something to watch: called with "first" and "second" before the GET
## of each page, and with "leaving" when the program is about to run
## COM.
var watch: Callable = func(_what: String) -> void: pass
## Set to make run() come back at the next GET.
var stop := false


func run() -> Left:
	await _disk(LOAD_SUPPLY)
	program.ran()
	program.open()
	await wait.call(OPEN)
	for frames: float in [MISC_FIRST, MISC_SECOND, MISC_THIRD]:
		await _disk(frames)
		program.misc_prompt()
	await _disk(MISC_CLOSE)
	program.misc_close()
	await wait.call(MISC_END)
	for y in range(SupplyProgram.FILL_ROWS):
		program.fill_row(y)
		await wait.call(FILL_ROW)

	while not stop:
		# line 1400
		await _sheet(WIPE_END)
		program.first_row()
		await wait.call(FIRST_ROW)
		await _lines(SupplyProgram.FIRST_PAGE, FIRST_PAGE)
		program.first_prompt()
		await wait.call(FIRST_PROMPT)
		watch.call("first")
		await _get_key()
		if stop:
			break
		await wait.call(KEY_TAKEN)

		# line 1460
		await _sheet(WIPE_RETURN)
		program.first_row()
		await wait.call(FIRST_ROW)
		await _lines(SupplyProgram.SECOND_PAGE, SECOND_PAGE)
		program.entry(SupplyProgram.SECOND_PAGE[-1])
		program.credits()
		await wait.call(LAST_LINE)
		program.second_prompt()
		await wait.call(SECOND_PROMPT)
		watch.call("second")
		var key := await _get_key()
		if stop:
			break
		if key == "1":
			await wait.call(AGAIN)
			continue
		program.close()
		await wait.call(CLOSE)
		program.space()
		watch.call("leaving")
		return Left.COM
	return Left.STOPPED


## Line 1400: the white sheet and the title.
func _sheet(end: float) -> void:
	program.wipe_open()
	await wait.call(WIPE_START)
	for c in range(1, SupplyProgram.WIPE_ROWS + 1):
		program.wipe_row(c)
		await wait.call(WIPE_ROW)
	program.title()
	await wait.call(end)


## Lines of BASIC that print one or two of a page's entries each.
func _lines(entries: Array, lines: Array) -> void:
	var next := 0
	for line: Array in lines:
		for i in range(line[0]):
			program.entry(entries[next])
			next += 1
		await wait.call(line[1])


## `GET C$`
func _get_key() -> String:
	while program.key_latch < 128:
		if stop:
			return ""
		await wait.call(1.0)
	return program.take_key()


func _disk(frames: float) -> void:
	await wait.call(frames * FlightLoop.DISK_WAIT_SCALE)
