extends Node
## Holds the command console (scripts/com/com_loop.gd and com_program.gd)
## to the real game. tools/mame/com_live.lua took a new game from flight
## into COM and through every screen it has, dumping hi-res page 1 each
## time the program stopped for a key (analysis/live/com/); the same keys
## are played through the port here, with no waits, and at every stop
## page 1, all 7680 bytes of it, is compared with the Apple's, and the
## cursor, the text window and the character generator's two switches
## with what the recording logged.
##
## Two recordings, a scene each:
##
##   godot --headless --path godot-remake res://tests/check_com.tscn
##       com_menus.log, 34 stops: a wrong key at every menu, a course
##       that is no star, the star we are at, a digit taken back, a
##       course set with two digits and with a digit and RETURN, the
##       directory, a star system that is none, two that are, "2) RETURN"
##       from the directory, and "5) RETURN" to the flight program.
##
##   godot --headless --path godot-remake res://tests/check_com_damaged.tscn
##       com_damaged.log, 2 stops: the computer and the radar out and the
##       power low, for the inverse labels and COMPUTER NOT FUNCTIONING.
##
## Both start as the recordings did: a new game flown for three passes
## with the stick left alone, "C" pressed in the third. And both end as
## they did: back in the flight program, page 1 compared once more at
## the start of its third pass, with the top of the panel that "5)
## RETURN" wiped still gone.
##
## Add `-- --dump <directory>` to write the port's page at each stop
## (port_<route>_<name>_p1.bin) for a look at a difference, or
## `-- --times` to print how long the port took from stop to stop next
## to the recording (which has about seven frames of the recorder's own
## in every interval: the key is typed in, and the stop is only seen
## after three frames of waiting).

const FlightLoop = preload("res://scripts/flight/flight_loop.gd")
const ComLoop = preload("res://scripts/com/com_loop.gd")
const CombatFx = preload("res://scripts/combat/combat_fx.gd")

const REFERENCE := "../analysis/live/com/"
const PAGE_BYTES := 7680
## The pass of the flight program the recorder acted in.
const PASS := 3
## The BASIC line of each GET.
const LINES := {
	"command": 120, "central": 260, "navigation": 830, "course": 871,
	"directory": 950, "which": 971, "page": 1170,
}

## com_<route>.log and <route>_<name>_p1.bin.
@export var route := "menus"
## What the recorder poked before "C": GameState's name for the byte, and
## the value.
@export var pokes: Dictionary = {}

var _com: ComLoop
var _stops: Array = []
var _next := 0
var _compared := 0
var _bad := 0
var _dump := ""
var _times := false
var _frames := 0.0
var _passes := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--dump":
		_dump = args[1]
	_times = args.has("--times")
	_stops = _read_log(REFERENCE.path_join("com_%s.log" % route))
	if _stops.is_empty():
		print("no reference for %s in %s" % [route, REFERENCE])
		get_tree().quit(2)
		return

	GameState.start_new_game()
	var fx := CombatFx.new()
	fx.instant = true
	fx.screen = GameState.view3d.pages[0]
	add_child(fx)

	# The flight program up to its "C".
	var flight := FlightLoop.new()
	flight.setup(fx)
	flight.combat.rnd = func() -> float: return 0.99
	flight.pass_started = func() -> void:
		_passes += 1
		if _passes == PASS:
			for field: String in pokes:
				GameState.set(field, pokes[field])
			flight.program.press("C")
	_check("C leaves the flight program for COM", await flight.run() == FlightLoop.Left.COM)
	_check("in pass %d" % PASS, _passes == PASS)

	_com = ComLoop.new()
	_com.watch = _watch
	_com.wait = func(frames: float) -> void: _frames += frames
	_check("COM runs the flight program", await _com.run() == ComLoop.Left.FLIGHT)
	_check("every stop was come to (%d of %d)" % [_next, _stops.size()], _next == _stops.size())

	# And back.
	flight = FlightLoop.new()
	flight.setup(fx)
	flight.combat.rnd = func() -> float: return 0.99
	_passes = 0
	flight.pass_started = func() -> void:
		_passes += 1
		if _passes == PASS:
			_compare_page("flying")
			_compared += 1
			flight.stop = true
	await flight.run()
	_check("the flight program flew again", _passes == PASS)

	print("%d stops compared with the live run: %d different" % [_compared, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


## A GET: the next stop of the recording, and its key.
func _watch(what: String) -> void:
	if what == "leaving":
		return
	if _next >= _stops.size():
		_check("a GET (%s) after the recording's last" % what, false)
		_com.stop = true
		return
	var stop: Dictionary = _stops[_next]
	_next += 1
	_compared += 1
	var name_: String = stop["name"]
	if _times and _next > 1:
		var live: float = (stop["ms"] - _stops[_next - 2]["ms"]) * 0.06
		print("%-18s %7.1f frames, the recording %7.1f (%+.1f)" % [name_, _frames, live, _frames - live])
	_frames = 0.0

	_check("%s: the GET of line %d, the port is at the %s menu's" % [name_, stop["line"], what],
			LINES[what] == stop["line"])
	_compare_page(name_)
	var text: RefCounted = GameState.chargen
	var port := [text.column, text.row, text.window_left, text.window_width, text.window_top,
			text.window_bottom, text.mode, 32 + 32 * text.page]
	var live_state: Array = stop["state"]
	if port != live_state:
		print("WRONG  %s: cursor, window, 973 and 974 are %s, the Apple's %s" % [name_, port, live_state])
		_bad += 1
	_check("%s: the course is star %d" % [name_, stop["course"]],
			GameState.target_planet + 1 == stop["course"])
	_com.program.press(stop["key"])


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1


func _compare_page(name_: String) -> void:
	var page: RefCounted = GameState.view3d.pages[0]
	if _dump != "":
		var out := FileAccess.open(_dump.path_join("port_%s_%s_p1.bin" % [route, name_]), FileAccess.WRITE)
		out.store_buffer(page.mem)
		out.close()
	var path := REFERENCE.path_join("%s_%s_p1.bin" % [route, name_])
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
	if different > 0:
		var where: Array = rows.keys()
		where.sort()
		print("WRONG  %s: %d bytes differ, rows %d to %d" % [name_, different, where[0], where[-1]])
		_bad += 1


## The stops of a recording: every "-- get" line and the key after it.
func _read_log(path: String) -> Array:
	var stops: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return stops
	# RETURN is in the log as it was typed, so not get_line()
	for line: String in file.get_as_text().split("\n"):
		var at := line.find("-- ")
		if at < 0:
			continue
		var words := line.substr(at + 3).split(" ", false)
		if words.size() >= 8 and words[0] == "get":
			var fields := {}
			for word in words.slice(2):
				var pair := word.split("=")
				fields[pair[0]] = pair[1]
			var window: PackedStringArray = fields["window"].split(",")
			stops.append({
				"name": words[1], "ms": float(line), "line": int(fields["line"]),
				"state": [int(fields["ch"]), int(fields["cv"]), int(window[0]), int(window[1]),
						int(window[2]), int(window[3]), int(fields["c973"]), int(fields["c974"])],
				"course": int(fields["38163"]), "key": "",
			})
		elif words.size() >= 2 and words[0] == "key" and not stops.is_empty() and stops[-1]["key"] == "":
			var typed := line.substr(at + 7)
			stops[-1]["key"] = String.chr(8) if typed == "LEFT" else typed.substr(1, 1)
	return stops
