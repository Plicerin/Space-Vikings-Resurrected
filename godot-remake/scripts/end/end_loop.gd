extends RefCounted
## END.bas on the clock. end_program.gd is its statements with no time
## in them; this is the order they run in and how long the real machine
## took over each, from `RUN END` until the program is left.
##
## `run()` is a coroutine. Everything that takes time goes through
## `wait`, which the scene (end_console.gd) points at a real clock and
## the test (tests/check_end.gd) at a counter.
##
## The numbers are video frames (1/60 s) of an Apple II+ in MAME, from
## tools/mame/end_live.lua (when each BASIC line started and when each
## character was drawn); the records are in analysis/live/end/.
##
## The menu takes most of a second to come up, nearly all of it line
## 30's sixteen rows of forty spaces. A save is ten seconds of floppy
## (the planet's record, then three BSAVEs) and the message is held for
## two more. As in flight_loop.gd, the floppy is cut down by
## DISK_WAIT_SCALE and nothing else is.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const EndProgram = preload("res://scripts/end/end_program.gd")
const FlightLoop = preload("res://scripts/flight/flight_loop.gd")

## How run() ended.
enum Left {
	STOPPED, ## `stop` was set
	CONTINUE, ## 2: GALAXY MAP, which runs STARSHIP SIMULATOR
	QUIT, ## 3: the machine dead, its screen black
	ERROR, ## a key that is no number, or a disk that cannot be written: SYSTEM ERROR
}

# -- floppy --
const LOAD_END := 150.0 # RUN END, from COM's line 132
const SAVE := 599.5 # line 210: CALL 38825 and three BSAVEs

# -- the menu, lines 20-70 --
const OPEN := 0.4 # lines 0-20
const WIPE_START := 0.73 # line 30 up to its first space
const WIPE_ROW := 2.595 # a row of it
const WIPE_END := 1.04 # its HOME
const TITLE := 1.12 # lines 31-40
const SAVE_LINE := 1.25 # line 50
const OTHER_LINES := 3.22 # line 60
const PROMPT := 1.05 # line 70 up to the GET

# -- a choice --
const KEY_TAKEN := 0.3 # line 70's IF
const SPACE := 0.4 # lines 75-90, or as far as line 190
const CONTINUE := 1.0 # lines 110-120 up to the RUN
## 3) END GAME: the display goes to the blank text screen 32.7 frames
## after the key, with J at 105 or so.
const QUIT_BLANK := 32.0
## Line 63999: the display goes to text 4.2 frames after it starts.
const ERROR_SCREEN := 4.2

# -- 1) SAVE GAME, lines 190-220 --
const REFUSED_START := 0.76 # line 190 up to its bare PRINT
const SLOW_CHARACTER := 2.566 # SPEED= 128, the carriage return too
const HOLD_REFUSED := 111.4 # FOR J = 1 TO 2000 and the RETURN
const SAVE_POKES := 8.45 # lines 190-204
const SAVED_MESSAGE := 0.62 # line 210's two PRINTs
const HOLD_SAVED := 112.6 # FOR J = 1 TO 2000, lines 220 and 80

var program := EndProgram.new()

## Waits that many video frames (1/60 s).
var wait: Callable = func(_frames: float) -> void: pass
## Something to watch: called with "menu" before the GET, with "saved"
## and "refused" when those messages are up, and with "leaving" when
## the program is about to be left.
var watch: Callable = func(_what: String) -> void: pass
## Set to make run() come back at the next GET.
var stop := false


func run() -> Left:
	await _disk(LOAD_END)
	program.ran()
	program.open()
	await wait.call(OPEN)
	while not stop:
		await _menu()
		watch.call("menu")
		var key := await _get_key()
		if stop:
			break
		var c := EndProgram.number(key)
		if c < 0:
			return await _error()
		await wait.call(KEY_TAKEN)
		if c < 1 or c > 3:
			continue
		program.space()
		await wait.call(SPACE)
		match c:
			1:
				if not await _save():
					# DOS's own error: its handler, not line 63999
					watch.call("leaving")
					return Left.ERROR
			2:
				program.continue_game()
				await wait.call(CONTINUE)
				watch.call("leaving")
				return Left.CONTINUE
			3:
				await wait.call(QUIT_BLANK)
				watch.call("leaving")
				return Left.QUIT
	return Left.STOPPED


## Lines 30-70 up to the GET.
func _menu() -> void:
	program.wipe_open()
	await wait.call(WIPE_START)
	for j in range(1, EndProgram.WIPE_ROWS + 1):
		program.wipe_row(j)
		await wait.call(WIPE_ROW)
	program.home()
	await wait.call(WIPE_END)
	program.title()
	await wait.call(TITLE)
	program.save_line()
	await wait.call(SAVE_LINE)
	program.other_lines()
	await wait.call(OTHER_LINES)
	program.prompt()
	await wait.call(PROMPT)


## GOSUB 190. False for a disk that could not be written.
func _save() -> bool:
	if program.in_atmosphere():
		await wait.call(REFUSED_START)
		await _slow(EndProgram.REFUSED)
		watch.call("refused")
		await wait.call(HOLD_REFUSED)
		return true
	await wait.call(SAVE_POKES)
	await _disk(SAVE)
	if not program.save():
		return false
	program.saved_message()
	await wait.call(SAVED_MESSAGE)
	watch.call("saved")
	await wait.call(HOLD_SAVED)
	return true


## Line 63999.
func _error() -> Left:
	program.error()
	await wait.call(ERROR_SCREEN)
	watch.call("leaving")
	return Left.ERROR


## PRINTs at SPEED= 128: the wait comes after each character, the
## carriage return included.
func _slow(lines: Array) -> void:
	for line: String in lines:
		for code in line.to_ascii_buffer():
			program.text.put(code)
			await wait.call(SLOW_CHARACTER)
		program.text.new_line()
		await wait.call(SLOW_CHARACTER)


## `GET C`
func _get_key() -> String:
	while program.key_latch < 128:
		if stop:
			return ""
		await wait.call(1.0)
	return program.take_key()


func _disk(frames: float) -> void:
	await wait.call(frames * FlightLoop.DISK_WAIT_SCALE)
