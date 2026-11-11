extends RefCounted
## The star chart on the clock. chart_program.gd is GALAXY MAP.bas's
## statements with no time in them; this is the order they run in and
## how long the real machine took over each, from `RUN GALAXY MAP` until
## the chart hands the machine back to COM.
##
## `run()` is a coroutine. Everything that takes time goes through
## `wait`, which the scene (star_chart.gd) points at a real clock and
## the test (tests/check_chart.gd) at nothing.
##
## The numbers are video frames (1/60 s) of an Apple II+ in MAME, from
## tools/mame/chart_loop_live.lua (every paddle and button read and
## every byte written to the page, to the microsecond) and
## tools/mame/lines_live.lua (when each BASIC line started); the records
## are in analysis/live/chart/.
##
## One turn of the chart's loop (lines 3110-3200) is 82 ms, under five
## frames, and the cross is only on the screen for the two in the
## middle of it: BASIC spends the rest reading the paddles and working
## out where to draw. So the cross flickers, and it moves twelve times a
## second.
##
##     PDL(0)            0 ms
##     PDL(1)           15
##     XDRAW on         39 to 44
##     button read      63
##     XDRAW off        72 to 78
##     PDL(0) again     82
##
## Asking about a star is slow in proportion to how far down the list it
## is: line 3220's FOR tests the stars one after another at 43 ms each,
## so SOL answers in a tenth of a second and SHIVANDA in nine tenths,
## and "there is no star system there" takes the whole list. Working
## out the distance is another quarter of a second, most of it SQR.
##
## As in flight_loop.gd, the floppy loads are cut down by
## DISK_WAIT_SCALE and nothing else is.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const ChartProgram = preload("res://scripts/chart/chart_program.gd")
const FlightLoop = preload("res://scripts/flight/flight_loop.gd")

## How run() ended.
enum Left {
	STOPPED, ## `stop` was set
	COM, ## a key: INSTRUMENTS, the lamps, and `RUN COM`
}

# -- floppy loads --
const LOAD_GALAXY_MAP := FlightLoop.LOAD_GALAXY_MAP
const LOAD_COM := 435.0 # from the chart's question
const LOAD_COM_LEAVING := 380.0 # from line 1, the drive still spinning
const LOAD_INSTRUMENTS := 171.0

# -- drawing the chart, lines 0-3100: 142 frames in all --
const NAMES := 9.5 # lines 0-5 and 15100-15140
const CLEAR := 6.8 # line 3000, the form feed
const BORDER_DOT := 0.0078 # line 3010: 939 dots in 7.3 frames
const POSITIONS := 28.7 # line 3020
const STAR_TO_MARK := 3.1 # lines 3025-3070
const MARK_TO_NEXT := 1.0
const BOX := 2.3 # line 3075, for the star the ship is at
const RULE := 2.2 # line 3090
const CAPTION := 2.5 # lines 3096-3100

# -- one turn of the loop, lines 3110-3200 --
const PADDLE_X_TO_Y := 0.9
const PADDLE_Y_TO_CROSS := 1.58
const CROSS_TO_BUTTON := 1.28
const BUTTON_TO_CROSS_OFF := 0.74
const CROSS_OFF_TO_PADDLE := 0.4

# -- the button, lines 3210-3320 --
const BUTTON_TO_BLACK := 0.9 # line 3210
const BLACK_TO_SEARCH := 0.7 # lines 3215-3220
const SEARCH_STAR := 2.59 # line 3230, a star tested
const FOUND_TO_TEXT := 0.44
const FOUND_CLEAR := 3.3 # line 3250: seven frames in three PRINTs
const FOUND_NAME := 2.0
const FOUND_PLACE := 1.7
const DISTANCE := 14.8 # lines 3300-3310
const FOUND_DISTANCE := 1.9 # line 3320
const QUESTION := 2.3 # line 3260 up to its GET
const QUESTION_CLEAR := 7.2 # line 3270
const NO_STAR_CHARACTER := 2.61 # SPEED= 127
const NO_STAR_HOLD := 29.8 # FOR J = 1 TO 500: NEXT
const NO_STAR_CLEAR := 2.7

# -- COM.bas's directory page --
const COM_MARKERS := 27.0 # line 8
const COM_NAMES := 14.0 # lines 10-12, 15100-15140
const DETAIL_WINDOW := 1.0 # lines 978-979
const DETAIL_ROW := 2.66 # line 980, a row
const DETAIL_TITLE := 1.6 # line 990
## Lines 1005-1160, a PRINT. Measured for line 1005's one line only (51
## ms); the others are taken to be as quick.
const DETAIL_LINE := 1.5

# -- the way out --
## INSTRUMENTS' lines 205-206 fill the lo-res screen behind the hi-res
## one before the program looks at who ran it.
const LAMPS_START := FlightLoop.LAMPS_START # GALAXY MAP line 1 up to GOSUB 5000
const LAMP_BLOCK := FlightLoop.LAMP_BLOCK # lines 5000-5500

var program := ChartProgram.new()

## Waits that many video frames (1/60 s).
var wait: Callable = func(_frames: float) -> void: pass
## Gives the two paddles, 0..255 each, as [PDL(0), PDL(1)].
var read_paddles: Callable = func() -> Array: return [128, 128]
## Is the paddle button down?
var read_button: Callable = func() -> bool: return false
## Something to watch: called with "clear" when line 3000 has cleared
## the page, "drawn" when the chart is up and the loop is about to
## start, "turn" at every paddle read, "cross" when the cross is on and
## the button about to be read, "message" when the no-star message is
## up, "question" and "ready" before the two GETs, "panel" when
## INSTRUMENTS and the lamps are done.
var watch: Callable = func(_what: String) -> void: pass
## Set to make run() come back at the next turn of the loop.
var stop := false


func run() -> Left:
	while true:
		await _run(LOAD_GALAXY_MAP)
		program.open()
		await wait.call(NAMES)
		var left: Left = await _chart()
		if left == Left.COM or stop:
			return left
	return Left.STOPPED


## Lines 3000-3270. Comes back with Left.COM when a key ended it and
## the lamps are repainted, with Left.STOPPED when "Y" went through
## COM's directory page and GALAXY MAP is to be run again.
func _chart() -> Left:
	while true:
		await _draw()
		watch.call("drawn")
		while true:
			if stop:
				return Left.STOPPED
			var turn: Turn = await _turn()
			if turn == Turn.KEY:
				await _leave()
				return Left.COM
			if turn == Turn.BUTTON:
				var asked: Asked = await _button()
				if asked == Asked.REDRAW:
					break
				if asked == Asked.FURTHER:
					await _directory()
					return Left.STOPPED
	return Left.STOPPED


enum Turn { NOTHING, KEY, BUTTON }
enum Asked { NOTHING, REDRAW, FURTHER }


func _draw() -> void:
	program.clear()
	watch.call("clear")
	await wait.call(CLEAR)
	for side in range(4):
		program.border_side(side)
		await wait.call(BORDER_DOT * (189 if side % 2 == 0 else 278))
	await wait.call(POSITIONS)
	for star in range(1, ChartProgram.STARS + 1):
		await wait.call(STAR_TO_MARK)
		program.star(star)
		await wait.call(MARK_TO_NEXT)
		if star == GameState.current_planet + 1:
			await wait.call(BOX)
	program.rule()
	await wait.call(RULE)
	program.caption()
	await wait.call(CAPTION)


func _turn() -> Turn:
	watch.call("turn")
	var paddles: Array = read_paddles.call()
	program.read_paddle_x(paddles[0])
	await wait.call(PADDLE_X_TO_Y)
	paddles = read_paddles.call()
	program.read_paddle_y(paddles[1])
	await wait.call(PADDLE_Y_TO_CROSS)
	program.cross()
	await wait.call(CROSS_TO_BUTTON)
	watch.call("cross")
	if program.key_down():
		return Turn.KEY
	if read_button.call():
		return Turn.BUTTON
	await wait.call(BUTTON_TO_CROSS_OFF)
	program.cross()
	await wait.call(CROSS_OFF_TO_PADDLE)
	return Turn.NOTHING


func _button() -> Asked:
	await wait.call(BUTTON_TO_BLACK)
	program.cross_off()
	await wait.call(BLACK_TO_SEARCH)
	var star := program.find()
	await wait.call(SEARCH_STAR * mini(star, ChartProgram.STARS))
	if star == ChartProgram.NO_STAR:
		for code in ChartProgram.NO_STAR_MESSAGE.to_ascii_buffer():
			program.text.put(code)
			await wait.call(NO_STAR_CHARACTER)
		program.text.new_line()
		watch.call("message")
		await wait.call(NO_STAR_HOLD)
		program.no_star_clear()
		await wait.call(NO_STAR_CLEAR)
		return Asked.NOTHING
	await wait.call(FOUND_TO_TEXT)
	program.found_clear()
	await wait.call(FOUND_CLEAR)
	program.found_name()
	await wait.call(FOUND_NAME)
	program.found_place()
	await wait.call(FOUND_PLACE + DISTANCE)
	program.found_distance()
	await wait.call(FOUND_DISTANCE)
	program.question()
	await wait.call(QUESTION)
	watch.call("question")
	if await _get_key() == "Y":
		program.further()
		return Asked.FURTHER
	program.question_clear()
	await wait.call(QUESTION_CLEAR)
	return Asked.REDRAW


## COM.bas from the chart's "Y": the directory page of the star asked
## about, a key, and back.
func _directory() -> void:
	await _run(LOAD_COM)
	program.com_open()
	await wait.call(COM_MARKERS + COM_NAMES)
	program.detail_window()
	await wait.call(DETAIL_WINDOW)
	for row in range(2, 16):
		program.detail_clear_row(row)
		await wait.call(DETAIL_ROW)
	program.detail_title()
	await wait.call(DETAIL_TITLE)
	for line: Callable in program.detail_lines():
		line.call()
		await wait.call(DETAIL_LINE)
	program.detail_ready()
	watch.call("ready")
	await _get_key()
	program.detail_close()


## Line 3125: INSTRUMENTS draws the panel again and comes straight back
## (its line 220), line 1 paints the lamps and runs COM.
func _leave() -> void:
	await _run(LOAD_INSTRUMENTS)
	program.flight.instruments_clear()
	await wait.call(FlightLoop.INSTRUMENTS_CLEAR)
	program.flight.instruments_frame()
	await wait.call(FlightLoop.INSTRUMENTS_FRAME)
	program.flight.instruments_text()
	await wait.call(FlightLoop.INSTRUMENTS_TEXT)
	await _run(LOAD_GALAXY_MAP)
	await wait.call(LAMPS_START)
	for block: Array in program.lamp_blocks():
		program.lamp_block(block)
		await wait.call(LAMP_BLOCK)
	watch.call("panel")
	await _run(LOAD_COM_LEAVING)


## `GET A$`
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
