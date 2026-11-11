extends RefCounted
## The command console on the clock. com_program.gd is COM.bas's
## statements with no time in them; this is the order they run in, GOTO
## for GOTO, and how long the real machine took over each, from `RUN
## COM` until COM runs another program.
##
## `run()` is a coroutine. Everything that takes time goes through
## `wait`, which the scene (com_console.gd) points at a real clock and
## the test (tests/check_com.gd) at a counter.
##
## The numbers are video frames (1/60 s) of an Apple II+ in MAME, from
## tools/mame/com_live.lua (when each BASIC line started and when each
## character was drawn); the records are in analysis/live/com/.
##
## COM is slow the way BASIC is slow. Painting the view blue is 124
## HPLOTs at two frames each, four seconds, and every way back to the
## command menu goes through it. A menu's left half is cleared with
## fourteen PRINTs of twenty spaces, a third of a second. The messages
## for a wrong key are printed at SPEED= 127, 43 ms a character, and
## then held with an empty FOR loop.
##
## As in flight_loop.gd, the floppy loads are cut down by
## DISK_WAIT_SCALE and nothing else is.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const ComProgram = preload("res://tests/legacy/com_program.gd")
const FlightLoop = preload("res://scripts/flight/flight_loop.gd")

## How run() ended: the program COM ran.
enum Left {
	STOPPED, ## `stop` was set
	FLIGHT, ## STARSHIP SIMULATOR
	GROUND_FORCES,
	RADAR,
	END,
	GALAXY_MAP,
	STATUS,
	SUPPLY,
}

# -- floppy loads --
const LOAD_COM := 435.0 # from the flight's C and the chart's question
const LOAD_COM_SPINNING := 380.0 # from the chart's line 1, the drive still spinning

# -- the console, lines 8-80 --
const MARKERS := 26.9 # line 8
const NAMES := 13.1 # lines 10-12 and 15100-15140
const FILL_START := 0.84 # line 20 up to its first HPLOT
const FILL_ROW_BLUE := 1.91 # line 20
const FILL_ROW_ORANGE := 1.95 # line 910
const FILL_END := 2.5 # line 20's HOME and fourteen PRINTs
const FULL_WINDOW := 1.04 # line 21, and line 25
const CLEAR_ROW := 1.56 # line 29, one of its fourteen PRINTs
const CLEAR_END := 0.25 # line 35
const GRID_OPEN := 8.8 # lines 40-50
const GRID_FIRST := 9.8 # line 60 up to the first label: READ looks for the DATA
const LABEL := 3.25 # lines 65-70
const GRID_END := 0.4
const TITLE := 4.2 # lines 72-80

# -- the command menu, lines 90-135 --
const BOX := 4.1 # line 90
const MENU_TITLE := 1.5 # lines 95-100
const MENU_LINES := 3.4 # line 110
const MENU_PROMPT := 1.1 # lines 115-120
const COMMAND_TAKEN := 4.8 # lines 120-135
const WIPE_ROW := 2.75 # line 129, a row
const LORES_FILL := 21.7 # line 129's HLINs, behind the hi-res screen

# -- the menus under it --
const KEY_TAKEN := 1.0 # VAL and the IFs after a GET
const CENTRAL_TITLE := 1.1 # line 210
const CENTRAL_LINES := 6.0 # lines 215-220
const READY := 0.4 # lines 260, 830, 950, 1170
const NAVIGATION_LINES := 3.6 # line 810
const COURSE_TITLE := 1.3 # line 860
const COURSE_PROMPT := 1.9 # line 870
const ENTRY_DIGIT := 2.7 # lines 871-876 up to the digit
const ENTRY_BACKSPACE := 1.1 # lines 871-872 up to the space
const COURSE_SET := 1.5 # lines 877-890 up to the FOR

# -- the galaxy directory, lines 900-978 --
const DIRECTORY_OPEN := 2.5 # line 900
const DIRECTORY_TITLE := 1.6 # lines 915-920
const DIRECTORY_CLEAR_ROW := 2.6 # line 930, a row
const DIRECTORY_ROW := 3.25 # line 940, a row
const WHICH_PROMPT := 1.8 # line 970
const WHICH_CLEAR := 1.5

# -- a star system's page, lines 979-1172 --
const PAGE_WINDOW := 0.5 # lines 977-979
const PAGE_CLEAR_ROW := 2.7 # line 980, a row
const PAGE_TITLE := 2.2 # line 990
## Lines 1005-1160: a PRINT is about 10 ms and 1 ms a character.
const PAGE_LINE := 0.6
const PAGE_CHARACTER := 0.06
const PAGE_KEY := 1.2 # line 1172

# -- the slow messages --
const SLOW_CHARACTER := 2.604 # SPEED= 127, the carriage return too
## The empty FOR loops that hold a message on the screen.
const HOLD_3000_NEXT_X := 217.2 # line 120, `NEXT X`
const HOLD_2000 := 111.6 # line 260
const HOLD_3000 := 169.8 # lines 830, 890, 895 and 978
const HOLD_4000 := 228.7 # line 215
const HOLD_5000 := 289.1 # line 878

var program := ComProgram.new()

## Waits that many video frames (1/60 s).
var wait: Callable = func(_frames: float) -> void: pass
## Something to watch: called before every GET with which one it is
## ("command", "central", "navigation", "course", "directory", "which",
## "page"), and with "leaving" when COM is about to run another program.
var watch: Callable = func(_what: String) -> void: pass
## Set to make run() come back at the next GET.
var stop := false

## Where the program is: the lines a GOTO goes to.
enum At {
	NAMES, ## 12
	CONSOLE, ## 20
	MENU, ## 90
	CENTRAL, ## 200
	NAVIGATION, ## 800
	COURSE, ## 860
	DIRECTORY, ## 900
	LIST, ## 910
	WHICH, ## 970
	PAGE, ## 978
	LEFT,
}

var _left := Left.STOPPED
## BASIC's C where it is carried from one line to another.
var _c := 0


func run() -> Left:
	await _run(LOAD_COM_SPINNING if GameState.drive_spinning else LOAD_COM)
	GameState.drive_spinning = false
	program.open()
	await wait.call(MARKERS)
	var at := At.NAMES
	while not stop:
		match at:
			At.NAMES: at = await _names()
			At.CONSOLE: at = await _console()
			At.MENU: at = await _menu()
			At.CENTRAL: at = await _central()
			At.NAVIGATION: at = await _navigation()
			At.COURSE: at = await _course()
			At.DIRECTORY: at = await _directory()
			At.LIST: at = await _list()
			At.WHICH: at = await _which()
			At.PAGE: at = await _page()
			At.LEFT:
				watch.call("leaving")
				return _left
	return Left.STOPPED


func _leave(left: Left) -> At:
	_left = left
	return At.LEFT


## Lines 10-12.
func _names() -> At:
	await wait.call(NAMES)
	_c = program.chart_star()
	return At.PAGE if _c > 0 else At.CONSOLE


## Lines 20-80: the view painted blue, the left half cleared, the
## twelve labels.
func _console() -> At:
	await wait.call(FILL_START)
	for y in range(ComProgram.FILL_ROWS):
		program.fill_row(ComProgram.BLUE, y)
		await wait.call(FILL_ROW_BLUE)
	program.fill_end()
	await wait.call(FILL_END)
	await _clear()
	program.grid_open()
	await wait.call(GRID_OPEN + GRID_FIRST)
	for index in range(ComProgram.LABELS.size()):
		program.label(index)
		await wait.call(LABEL if index < ComProgram.LABELS.size() - 1 else GRID_END)
	program.title()
	await wait.call(TITLE)
	return At.MENU


## GOSUB 21 with R = 1: lines 21-35.
func _clear() -> void:
	program.full_window()
	await wait.call(FULL_WINDOW)
	program.full_window()
	await wait.call(FULL_WINDOW)
	for row in range(14):
		program.clear_row(row)
		await wait.call(CLEAR_ROW)
	await wait.call(CLEAR_END)


## Lines 90-135.
func _menu() -> At:
	program.box()
	await wait.call(BOX)
	program.blank() # 95
	if program.ground_forces_due(): # 98
		return _leave(Left.GROUND_FORCES)
	program.menu_title()
	await wait.call(MENU_TITLE)
	program.menu_lines()
	await wait.call(MENU_LINES)
	program.menu_prompt()
	await wait.call(MENU_PROMPT)
	watch.call("command")
	var command := ComProgram.val(await _get_key())
	if stop:
		return At.LEFT
	if command < 1 or command > 5:
		await wait.call(KEY_TAKEN)
		await _slow(ComProgram.WRONG_KEY)
		await wait.call(HOLD_3000_NEXT_X)
		program.home()
		await _clear()
		return At.MENU
	await wait.call(COMMAND_TAKEN)
	program.command_taken(command) # 121-127
	if command == 2:
		return _leave(Left.GROUND_FORCES)
	program.command_window() # 128-129
	if command == 5:
		for row in range(1, 17):
			program.wipe_row(row)
			await wait.call(WIPE_ROW)
		await wait.call(LORES_FILL)
	program.command_leave(command) # 130-133
	match command:
		5: return _leave(Left.FLIGHT)
		4: return _leave(Left.END)
		3: return _leave(Left.RADAR)
	program.command_computer() # 135
	return At.CENTRAL


## Lines 200-280.
func _central() -> At:
	await _clear()
	program.home()
	program.central_title()
	await wait.call(CENTRAL_TITLE)
	if program.computer_out(): # 215
		program.computer_out_message()
		await wait.call(HOLD_4000)
		return At.NAMES
	program.central_lines()
	await wait.call(CENTRAL_LINES)
	program.ready()
	await wait.call(READY)
	watch.call("central")
	var c := ComProgram.val(await _get_key())
	if stop:
		return At.LEFT
	await wait.call(KEY_TAKEN)
	match c:
		1:
			return At.NAVIGATION
		2:
			return At.DIRECTORY
		3: # 265, 3000
			program.space()
			return _leave(Left.GALAXY_MAP)
		4: # 1200
			program.space()
			return _leave(Left.STATUS)
		5: # 20000
			program.space()
			return _leave(Left.SUPPLY)
		6: # 280
			return At.NAMES
	await _slow(ComProgram.WRONG_KEY)
	await wait.call(HOLD_2000)
	return At.CENTRAL


## Lines 800-850.
func _navigation() -> At:
	await _clear()
	program.home()
	program.navigation_lines()
	await wait.call(NAVIGATION_LINES)
	program.ready()
	await wait.call(READY)
	watch.call("navigation")
	var c := ComProgram.val(await _get_key())
	if stop:
		return At.LEFT
	await wait.call(KEY_TAKEN)
	match c:
		1:
			return At.DIRECTORY
		2:
			return At.COURSE
		3:
			return At.CONSOLE
	await _slow(ComProgram.WRONG_KEY)
	await wait.call(HOLD_3000)
	return At.NAVIGATION


## Lines 860-897.
func _course() -> At:
	await _clear()
	program.course_title()
	await wait.call(COURSE_TITLE)
	program.course_prompt()
	await wait.call(COURSE_PROMPT)
	var c := await _entry("course")
	if stop:
		return At.LEFT
	program.blank() # 877
	if c > ComProgram.STARS or c == 0: # 878
		await _slow(ComProgram.COURSE_ERROR)
		await wait.call(HOLD_5000)
		return At.COURSE
	if program.course_is_here(c): # 879, 895
		await _slow(ComProgram.COURSE_HERE)
		await wait.call(HOLD_3000)
		return At.COURSE
	program.course_set(c)
	await wait.call(COURSE_SET + HOLD_3000)
	return At.NAVIGATION


## Line 900.
func _directory() -> At:
	program.directory_open()
	await wait.call(DIRECTORY_OPEN)
	return At.LIST


## Lines 910-969.
func _list() -> At:
	await wait.call(FILL_START)
	for y in range(ComProgram.FILL_ROWS):
		program.fill_row(ComProgram.ORANGE, y)
		await wait.call(FILL_ROW_ORANGE)
	program.directory_title()
	await wait.call(DIRECTORY_TITLE)
	for row in range(13):
		program.directory_clear_row(row == 12)
		await wait.call(DIRECTORY_CLEAR_ROW)
	for row in range(12):
		program.directory_row(row)
		await wait.call(DIRECTORY_ROW)
	program.directory_prompt()
	await wait.call(READY)
	watch.call("directory")
	var c := ComProgram.val(await _get_key())
	if stop:
		return At.LEFT
	await wait.call(KEY_TAKEN)
	if c < 1 or c > 2:
		return At.LIST
	program.directory_chosen()
	if c == 2: # 969: R = 2: GOSUB 20, which never returns
		return At.CONSOLE
	return At.WHICH


## Lines 970-977.
func _which() -> At:
	program.which_prompt()
	await wait.call(WHICH_PROMPT)
	_c = await _entry("which")
	if stop:
		return At.LEFT
	program.which_done()
	return At.PAGE


## Lines 978-1180, for star `_c`.
func _page() -> At:
	if _c < 1 or _c > ComProgram.STARS:
		await _slow(ComProgram.WHICH_ERROR)
		await wait.call(HOLD_3000)
		program.which_clear()
		await wait.call(WHICH_CLEAR)
		return At.WHICH
	program.page_window()
	await wait.call(PAGE_WINDOW)
	for row in range(2, 16):
		program.page_clear_row(row)
		await wait.call(PAGE_CLEAR_ROW)
	program.page_title(_c)
	await wait.call(PAGE_TITLE)
	for line: String in program.page_lines(_c):
		program.page_line(line)
		await wait.call(PAGE_LINE + PAGE_CHARACTER * (line.length() + 1))
	program.page_prompt()
	await wait.call(READY)
	watch.call("page")
	await _get_key()
	if stop:
		return At.LEFT
	await wait.call(PAGE_KEY)
	if program.page_close(): # 1172
		return _leave(Left.GALAXY_MAP)
	return At.DIRECTORY


## The two-digit entry, lines 871-876 and 971-976.
func _entry(what: String) -> int:
	while true:
		program.entry_cursor()
		watch.call(what)
		var key := await _get_key()
		if stop:
			return 0
		await wait.call(ENTRY_BACKSPACE if key == String.chr(8) else ENTRY_DIGIT)
		if program.entry_key(key):
			break
	return program.entry_value()


## PRINTs at SPEED= 127: the wait comes after each character, the
## carriage return included.
func _slow(lines: Array) -> void:
	for line: String in lines:
		for code in line.to_ascii_buffer():
			program.text.put(code)
			await wait.call(SLOW_CHARACTER)
		program.text.new_line()
		await wait.call(SLOW_CHARACTER)


## `GET C$`
func _get_key() -> String:
	while program.key_latch < 128:
		if stop:
			return ""
		await wait.call(1.0)
	return program.take_key()


func _disk(frames: float) -> void:
	await wait.call(frames * FlightLoop.DISK_WAIT_SCALE)


## RUN <program>: the load, then DOS's carriage return.
func _run(frames: float) -> void:
	await _disk(frames)
	program.ran()
