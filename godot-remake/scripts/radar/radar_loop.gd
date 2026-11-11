extends RefCounted
## RADAR.bas on the clock. radar_program.gd is its statements with no
## time in them; this is the order they run in and how long the real
## machine took over each, from `RUN RADAR` until it runs the next
## program.
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
## Most of the time is A2-3D1's one call: a little under two seconds at
## SOL. The screen is cleared at its start and the picture comes a dot
## at a time, three or four stars to a video frame, so the call is run
## here a record at a time with a price for each (the VIEW_ numbers).
## Those were fitted to four recordings, with nothing, the space lab,
## the light cruiser and the heavy cruiser in orbit: the call comes out
## within a third of a frame of each (64.8, 112.7, 105.5 and 143.9
## frames), and every star is drawn within half a frame of the video
## frame the Apple stored it in. They are not the flight loop's, which
## prices a whole pass and not its parts. As in flight_loop.gd, the
## floppy loads are cut down by DISK_WAIT_SCALE and nothing else is.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const RadarProgram = preload("res://scripts/radar/radar_program.gd")
const FlightLoop = preload("res://scripts/flight/flight_loop.gd")

## How run() ended: the program RADAR ran.
enum Left {
	STOPPED, ## `stop` was set
	FLIGHT, ## line 2059: RUN STARSHIP SIMULATOR
	COM, ## line 2058: RUN COM
	SHIP_ID, ## lines 5002-5005: RUN SHIP # n I.D.
}

# -- floppy --
const LOAD_RADAR := 164.7 # RUN RADAR, from the flight, COM or an I.D.

# -- lines 0-2005 --
const OPEN := 10.0 # lines 0-2000
const OPEN_DEAD := 5.2 # lines 0-10 with no radar
const VIEW_OPEN := 1.2 # line 2005 up to its CALL 24576
const PANEL := 3.6 # CALL 37936
const FRAME := 5.9 # the rest of line 2005

# -- CALL 24576, by the record --
const VIEW_SETUP := 0.207 # before the first record
const VIEW_CLEAR := 2.556 # opcode 8: all of page 1, 3205 bytes to a frame
const VIEW_POINT := 0.2255 # a point brought into view space
const VIEW_POINT_PLOTTED := 0.1058 # and projected and plotted, if it is in view
const VIEW_LINE_END := 0.247 # an end of a line: two for a new line, one for a continued
const VIEW_LINE_PROJECTED := 0.1 # and projected
const VIEW_DOT := 0.0013 # a dot of a line
const VIEW_OTHER := 0.0683 # any other record

# -- lines 2010-2045 --
const BLANK_ROW := 2.37 # line 2010
const EDGE := 1.4 # line 2032
const DIAGONALS := 6.51 # line 2033
const CROSS := 4.67 # line 2040
const BOX := 3.72 # lines 2042-2045, up to the GET

# -- after the key --
const KEY_TAKEN := 1.04 # lines 2052-2056
const IDENTIFY := 1.0 # lines 5000-5002
const MARKER := 1.041 # line 2057, a DRAW
const CLOSE := 0.88 # line 2058
const WIPE_ROW := 2.75 # line 2059, a row
const LORES_FILL := 22.4 # line 2059's HLINs, behind the hi-res screen

var program := RadarProgram.new()

## Waits that many video frames (1/60 s).
var wait: Callable = func(_frames: float) -> void: pass
## Something to watch: called with "radar" before the GET, and with
## "leaving" when the program is about to run another.
var watch: Callable = func(_what: String) -> void: pass
## Set to make run() come back at the GET.
var stop := false
## How long the last CALL 24576 took, for the test to hold against the
## real one.
var view_frames := 0.0
## Which SHIP # n I.D. to run, when run() comes back with SHIP_ID.
var ship_id := 0


func run() -> Left:
	await _disk(LOAD_RADAR)
	program.ran()
	if program.dead(): # 10
		await wait.call(OPEN_DEAD)
		# the drive has not stopped, if it is COM that is run again
		GameState.drive_spinning = true
		var left: Left = await _close()
		if left != Left.COM:
			GameState.drive_spinning = false
		return left
	await wait.call(OPEN)
	program.look_down() # 1500-2000

	# line 2005
	program.view_open()
	await wait.call(VIEW_OPEN)
	await _view()
	program.panel()
	await wait.call(PANEL)
	program.frame()
	await wait.call(FRAME)

	program.blank_row() # 2010
	await wait.call(BLANK_ROW)
	program.lines(RadarProgram.EDGE) # 2032
	await wait.call(EDGE)
	program.lines(RadarProgram.DIAGONALS) # 2033
	await wait.call(DIAGONALS)
	program.lines(RadarProgram.CROSS) # 2040
	await wait.call(CROSS)
	program.box() # 2042-2045
	await wait.call(BOX)
	watch.call("radar")
	var key := await _get_key() # 2050
	if stop:
		return Left.STOPPED
	program.key_taken() # 2052-2055
	await wait.call(KEY_TAKEN)
	if key != "X": # 2056
		ship_id = program.identify()
		await wait.call(IDENTIFY)
		watch.call("leaving")
		return Left.SHIP_ID
	for x: int in RadarProgram.MARKERS: # 2057
		program.marker(x)
		await wait.call(MARKER)
	return await _close()


## CALL 24576, a record at a time.
func _view() -> void:
	var view := program.view
	view_frames = VIEW_SETUP
	await wait.call(VIEW_SETUP)
	var projections := 0
	var dots := 0
	while true:
		var op := program.view_step()
		if op < 0:
			break
		var projected: int = view.projections - projections
		var frames := VIEW_OTHER
		match op:
			0:
				frames = VIEW_POINT + VIEW_POINT_PLOTTED * projected
			1, 2, 3:
				frames = VIEW_LINE_END * (2 if op == 1 else 1) + VIEW_LINE_PROJECTED * projected \
						+ VIEW_DOT * (view.dots_drawn - dots)
			8:
				frames = VIEW_CLEAR
		projections = view.projections
		dots = view.dots_drawn
		view_frames += frames
		await wait.call(frames)


## Lines 2058-2059: back to whichever program ran this one.
func _close() -> Left:
	var com := program.back_to_com()
	await wait.call(CLOSE)
	if com:
		watch.call("leaving")
		return Left.COM
	for row in range(1, RadarProgram.WIPE_ROWS + 1):
		program.wipe_row(row)
		await wait.call(WIPE_ROW)
	await wait.call(LORES_FILL)
	watch.call("leaving")
	return Left.FLIGHT


## `GET A$`
func _get_key() -> String:
	while program.key_latch < 128:
		if stop:
			return ""
		await wait.call(1.0)
	return program.take_key()


func _disk(frames: float) -> void:
	await wait.call(frames * FlightLoop.DISK_WAIT_SCALE)
