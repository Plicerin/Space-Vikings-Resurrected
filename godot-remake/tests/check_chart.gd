extends Node
## Holds the star chart (scripts/chart/chart_loop.gd and chart_program.gd)
## to the real game. tools/mame/chart_live.lua took a new game to the
## chart and through every way round it, dumping hi-res page 1 at each
## stop (analysis/live/chart/); the same route is played through the
## port here, with no waits, and page 1, all 7680 bytes of it, is
## compared with the Apple's at the same stops, and the text cursor with
## the CH and CV the recording logged.
##
##   godot --headless --path godot-remake res://tests/check_chart.tscn
##
## The route: the chart drawn; the cross on SIRIUS; the button (name,
## position, distance, the question); N (drawn again); the cross in the
## corner and the button (no star there); SIRIUS again and Y, which runs
## COM (scripts/com/com_loop.gd) for its directory page over what is left
## of the chart; a key, and COM runs the chart again; SPACE (INSTRUMENTS,
## the lamps repainted by GALAXY MAP's line 1) and COM once more, up to
## its command menu.
##
## Add `-- --dump <directory>` to write the port's page at each stop
## (port_<name>_p1.bin) for a look at a difference.

const ChartLoop = preload("res://scripts/chart/chart_loop.gd")
const ComLoop = preload("res://scripts/com/com_loop.gd")

const REFERENCE := "../analysis/live/chart/"
## Paddle readings of the recording.
const SIRIUS := [113, 115]
const CORNER := [20, 20]
const PAGE_BYTES := 7680
const STEPS := 14

var _loop: ChartLoop
var _com: ComLoop
var _paddles: Array = SIRIUS
var _button := false
var _step := 0
var _stops := 0
var _bad := 0
var _dump := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--dump":
		_dump = args[1]
	GameState.start_new_game()
	_chart()
	# The recording came to the chart from flight: INSTRUMENTS has run
	# and TRANLIT has flipped the four switches (flight_loop.gd, run()).
	_loop.program.flight.instruments()
	_check("Y leaves the chart for COM", await _loop.run() == ChartLoop.Left.COM)
	_check("with SIRIUS to show", GameState.handover == 7)
	_console()
	_check("a key at COM's page runs the chart", await _com.run() == ComLoop.Left.GALAXY_MAP)
	_chart()
	_check("a key leaves the chart for COM", await _loop.run() == ChartLoop.Left.COM)
	_check("with no star to show", GameState.handover == 0)
	_console()
	await _com.run()
	_check("the whole route was gone through (%d of %d steps)" % [_step, STEPS], _step == STEPS)
	print("%d stops compared with the live run: %d different" % [_stops, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


## GALAXY MAP run.
func _chart() -> void:
	_loop = ChartLoop.new()
	_loop.read_paddles = func() -> Array: return _paddles
	_loop.read_button = func() -> bool:
		var down := _button
		_button = false
		return down
	_loop.watch = _watch


## COM run.
func _console() -> void:
	_com = ComLoop.new()
	_com.watch = _watch


## The route, a step for every thing waited for.
func _watch(what: String) -> void:
	match [_step, what]:
		[0, "drawn"]:
			_compare("chart_clean", 1, 21)
		[1, "cross"]:
			_compare("chart_cursor", 1, 21)
			_button = true
		[2, "question"]:
			_compare("chart_info", 33, 22)
			_loop.program.press("N")
		[3, "drawn"]:
			_compare("chart_clean", 1, 21) # the recording's chart_redrawn, the same bytes
			_paddles = CORNER
		[4, "cross"]:
			_compare("chart_corner", 1, 21)
			_button = true
		[5, "message"]:
			pass
		[6, "turn"]:
			_compare("chart_nostar_600", 1, 21)
			_paddles = SIRIUS
		[7, "cross"]:
			_button = true
		[8, "question"]:
			_loop.program.press("Y")
		[9, "page"]:
			_compare("com_detail", 7, 14)
			_com.program.press("X")
		[10, "drawn"]:
			_compare("chart_clean", 1, 21) # the recording's chart_back, the same bytes
		[11, "cross"]:
			_loop.program.press(" ")
		[12, "panel"]:
			pass
		[13, "command"]:
			# The recording's last dump, 6000 frames after the key: COM
			# at its command menu. Its line 20 has printed its fourteen
			# spaces inside the four-row window the chart left behind,
			# which wipes the first column of the panel's lower half.
			_compare("leaving_6000", 9, 9)
			_com.stop = true
		_:
			return
	_step += 1


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1


func _compare(name_: String, column: int, row: int) -> void:
	_stops += 1
	var page: RefCounted = GameState.view3d.pages[0]
	if _dump != "":
		var out := FileAccess.open(_dump.path_join("port_%s_p1.bin" % name_), FileAccess.WRITE)
		out.store_buffer(page.mem)
		out.close()
	var path := REFERENCE.path_join("%s_p1.bin" % name_)
	var live := FileAccess.get_file_as_bytes(path)
	if live.size() != PAGE_BYTES:
		print("WRONG  %s: cannot read %s" % [name_, path])
		_bad += 1
		return
	var different := 0
	var rows := {}
	for i in range(PAGE_BYTES):
		if page.mem[i] != live[i]:
			different += 1
			rows[i / 40] = true
	var text: RefCounted = GameState.chargen
	var cursor_ok: bool = text.column == column and text.row == row
	if different == 0 and cursor_ok:
		return
	_bad += 1
	if different > 0:
		var where: Array = rows.keys()
		where.sort()
		print("WRONG  %s: %d bytes differ, rows %d to %d" % [name_, different, where[0], where[-1]])
	if not cursor_ok:
		print("WRONG  %s: the cursor is at column %d row %d, the Apple's at %d, %d" % [
				name_, text.column, text.row, column, row])
