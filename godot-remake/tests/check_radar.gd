extends Node
## Holds RADAR and the four SHIP # n I.D. programs (scripts/radar/) to
## the real game. tools/mame/radar_live.lua took a new game from flight
## into RADAR, by the flight program's R or by COM's "3", and on into the
## I.D. programs, dumping both hi-res pages each time a program stopped
## for a key (analysis/live/radar/); the same keys are played through
## the port here, with no waits, and at every stop pages 1 and 2, all
## 7680 bytes of each, are compared with the Apple's, and the cursor,
## the text window and the character generator's two switches with what
## the recording logged.
##
## Seven recordings, a scene each:
##
##   godot --headless --path godot-remake res://tests/check_radar.tscn
##       R in flight, X at the radar, the flight again.
##   ... res://tests/check_radar_ids.tscn
##       R, and then round and round: a key at the radar for the I.D.
##       and a key there for the radar, with the defender's type poked
##       to 1, 2, 3, 4 and 0 on the way, so that every I.D. program is
##       run and the light cruiser's twice more (for a type 2, which
##       has no program of its own). The poke changes which program is
##       run and not what is in orbit: the radar goes on drawing the
##       light cruiser.
##   ... res://tests/check_radar_com.tscn
##       C, COM's "3", a key for the I.D., a key back, X: COM again,
##       and its "5" for the flight.
##   ... res://tests/check_radar_dead.tscn
##       the radar's byte poked to 0. COM's "3" comes straight back to
##       COM; then "5", and the flight program's R comes straight back
##       to the flight.
##   ... res://tests/check_radar_ship_0.tscn, _ship_1, _ship_4
##       C, and at the console another SHIP # n loaded behind the stars
##       (none, the space lab, the heavy cruiser) and the ship put at
##       the middle of the system, right over it; "3", X, "5". These
##       are for the picture A2-3D1 makes of each and for how long it
##       takes.
##
## All start as the recordings did: a new game flown for three passes
## with the stick left alone, the key pressed in the third. Every time
## the flight program is come back to, page 1 is compared once more at
## the start of its third pass.
##
## Add `-- --dump <directory>` to write the port's pages at each stop
## (port_<route>_<name>_p1.bin, _p2.bin) for a look at a difference, or
## `-- --times` to print how long the port took from stop to stop next
## to the recording. The recording has a few frames of the recorder's
## own in every interval, and the port's floppy is cut down by
## DISK_WAIT_SCALE, so the port's intervals are the shorter by most of
## each program's load. What is held to the recording is A2-3D1's one
## call, which is most of RADAR's time and is logged by itself: the
## port's is to be within half a frame of it, every time.

const FlightLoop = preload("res://scripts/flight/flight_loop.gd")
const ComLoop = preload("res://tests/legacy/com_loop.gd")
const RadarLoop = preload("res://scripts/radar/radar_loop.gd")
const ShipIdLoop = preload("res://scripts/radar/ship_id_loop.gd")
const ShipIdProgram = preload("res://scripts/radar/ship_id_program.gd")
const CombatFx = preload("res://scripts/combat/combat_fx.gd")

const REFERENCE := "../analysis/live/radar/"
const PAGE_BYTES := 7680
## The pass of the flight program the recorder acted in.
const PASS := 3
## The BASIC line of COM's GET and RADAR's; the I.D. programs' are
## ShipIdProgram.GET_LINE.
const LINES := {"command": 120, "radar": 2050}
## The bytes the recorder poked, as GameState has them. 29461 to 29475
## are A2-3D1's, and are poked as they are.
const BYTES := {38195: "ship_radar", 38205: "orbital_defender_tier"}
## A poke that is no byte: SHIP # n loaded at $7879.
const LOAD_SHIP := -1
## How far from the recording's the port's CALL 24576 may be, in frames.
const CALL_SLACK := 0.5
## The programs.
enum Run { FLIGHT, COM, RADAR, SHIP_ID, DONE }

## radar_<route>.log and <route>_<name>_p1.bin.
@export var route := "radar"

## The loop that is running.
var _loop: RefCounted
var _stops: Array = []
## Each return to the flight program: the name of its page, and the key
## pressed there if one was.
var _flights: Array = []
var _first_key := ""
## How long each CALL 24576 of the recording took, in frames.
var _calls: Array = []
var _called := 0
var _next := 0
var _compared := 0
var _bad := 0
var _dump := ""
var _times := false
var _frames := 0.0
var _passes := 0
var _fx: CombatFx


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--dump":
		_dump = args[1]
	_times = args.has("--times")
	_read_log(REFERENCE.path_join("radar_%s.log" % route))
	if _stops.is_empty() and _flights.is_empty():
		print("no reference for %s in %s" % [route, REFERENCE])
		get_tree().quit(2)
		return

	GameState.start_new_game()
	_fx = CombatFx.new()
	_fx.instant = true
	_fx.screen = GameState.view3d.pages[0]
	add_child(_fx)

	var radars := 0
	var ids := 0
	var ship := 0
	var flown := -1 # which of _flights the flight program is at
	var at := Run.FLIGHT
	while at != Run.DONE:
		match at:
			Run.FLIGHT:
				var key := _first_key
				var page := ""
				if flown >= 0:
					if flown >= _flights.size():
						_check("the flight program is come back to %d times" % _flights.size(), false)
						break
					key = _flights[flown]["key"]
					page = _flights[flown]["name"]
				flown += 1
				var left: FlightLoop.Left = await _fly(page, key)
				if key == "":
					at = Run.DONE
				elif left == FlightLoop.Left.COM:
					at = Run.COM
				elif left == FlightLoop.Left.RADAR:
					at = Run.RADAR
				else:
					_check("%s leaves the flight program for COM or RADAR" % key, false)
					at = Run.DONE
			Run.COM:
				var com := ComLoop.new()
				_run(com)
				var left: ComLoop.Left = await com.run()
				if left == ComLoop.Left.RADAR:
					at = Run.RADAR
				else:
					_check("COM runs RADAR or the flight program", left == ComLoop.Left.FLIGHT)
					at = Run.FLIGHT if left == ComLoop.Left.FLIGHT else Run.DONE
			Run.RADAR:
				var radar := RadarLoop.new()
				_run(radar)
				radars += 1
				var left: RadarLoop.Left = await radar.run()
				if radar.view_frames > 0.0:
					_check_call(radar.view_frames)
				match left:
					RadarLoop.Left.FLIGHT: at = Run.FLIGHT
					RadarLoop.Left.COM: at = Run.COM
					RadarLoop.Left.SHIP_ID:
						ship = radar.ship_id
						at = Run.SHIP_ID
					_:
						_check("RADAR runs another program", false)
						at = Run.DONE
			Run.SHIP_ID:
				var id := ShipIdLoop.new(ship)
				_run(id)
				ids += 1
				var left: ShipIdLoop.Left = await id.run()
				_check("SHIP # %d I.D. runs RADAR" % ship, left == ShipIdLoop.Left.RADAR)
				at = Run.RADAR if left == ShipIdLoop.Left.RADAR else Run.DONE
	_check("every stop was come to (%d of %d)" % [_next, _stops.size()], _next == _stops.size())
	_check("the flight program was come back to %d times (%d)" % [_flights.size(), flown],
			flown == _flights.size())
	_check("RADAR was run", radars > 0)
	_check("the radar was drawn %d times (%d)" % [_calls.size(), _called], _called == _calls.size())

	print("%d stops compared with the live run: %d different (RADAR %d times, an I.D. %d)" % [
			_compared, _bad, radars, ids])
	get_tree().quit(1 if _bad > 0 else 0)


## The flight program for three passes: its page compared at the third
## if `page` is the name of one, and `key` pressed there if there is
## one; with no key it is stopped there.
func _fly(page: String, key: String) -> FlightLoop.Left:
	var flight := FlightLoop.new()
	flight.setup(_fx)
	flight.combat.rnd = func() -> float: return 0.99
	_passes = 0
	flight.pass_started = func() -> void:
		_passes += 1
		if _passes != PASS:
			return
		if page != "":
			_compare_page(page, 0)
			_compared += 1
		if key == "":
			flight.stop = true
		else:
			flight.program.press(key)
	var left: FlightLoop.Left = await flight.run()
	_check("the flight program flew %d passes (%d)" % [PASS, _passes], _passes == PASS)
	_frames = 0.0
	return left


func _run(loop: RefCounted) -> void:
	_loop = loop
	loop.watch = _watch
	loop.wait = func(frames: float) -> void: _frames += frames


## A2-3D1's call, against the next of the recording's.
func _check_call(frames: float) -> void:
	if _called >= _calls.size():
		_check("the radar drawn %d times" % _calls.size(), false)
		return
	var live: float = _calls[_called]
	_called += 1
	if _times:
		print("    A2-3D1's call   %7.2f frames, the recording %7.2f" % [frames, live])
	_check("A2-3D1's call takes %.2f frames (%.2f)" % [live, frames], absf(frames - live) <= CALL_SLACK)


## A GET: the next stop of the recording, its pokes and its key.
func _watch(what: String) -> void:
	if what == "leaving":
		return
	if _next >= _stops.size():
		_check("a GET (%s) after the recording's last" % what, false)
		_loop.stop = true
		return
	if what != "id" and not LINES.has(what):
		_check("a GET the recordings have none of (%s)" % what, false)
		_loop.stop = true
		return
	var stop: Dictionary = _stops[_next]
	_next += 1
	_compared += 1
	var name_: String = stop["name"]
	if _times and _next > 1:
		var live: float = (stop["ms"] - _stops[_next - 2]["ms"]) * 0.06
		print("%-18s %7.1f frames, the recording %7.1f (%+.1f)" % [name_, _frames, live, _frames - live])
	_frames = 0.0

	for poke: Array in stop["pokes"]:
		_poke(poke[0], poke[1])
	var line: int = ShipIdProgram.GET_LINE[_loop.program.ship] if what == "id" else LINES[what]
	_check("%s: the GET of line %d, the port is at \"%s\" (line %d)" % [name_, stop["line"], what, line],
			line == stop["line"])
	_compare_page(name_, 0)
	_compare_page(name_, 1)
	var text: RefCounted = GameState.chargen
	var port := [text.column, text.row, text.window_left, text.window_width, text.window_top,
			text.window_bottom, text.mode, 32 + 32 * text.page]
	var live_state: Array = stop["state"]
	if port != live_state:
		print("WRONG  %s: cursor, window, 973 and 974 are %s, the Apple's %s" % [name_, port, live_state])
		_bad += 1
	# the bytes of A2-3D1's the recording logged: the eye, and the pages
	var view: RefCounted = GameState.view3d
	for address: int in stop["bytes"]:
		if view.peek(address) != stop["bytes"][address]:
			print("WRONG  %s: %d is %d, the Apple's %d" % [name_, address, view.peek(address),
					stop["bytes"][address]])
			_bad += 1
	_check("%s: 38388 is %d (%d)" % [name_, stop["handover"], GameState.handover],
			GameState.handover == stop["handover"])
	_loop.program.press(stop["key"])


func _poke(address: int, value: int) -> void:
	if address == LOAD_SHIP:
		if value == 0:
			GameState.view3d.remove_ship()
		else:
			_check("SHIP # %d loaded" % value, GameState.view3d.load_ship(value))
	elif BYTES.has(address):
		GameState.set(BYTES[address], value)
	elif address >= 29461 and address <= 29475:
		GameState.view3d.poke(address, value)
	else:
		_check("a poke of %d, which the test has no name for" % address, false)


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1


func _compare_page(name_: String, index: int) -> void:
	var page: RefCounted = GameState.view3d.pages[index]
	var file := "%s_%s_p%d.bin" % [route, name_, index + 1]
	if _dump != "":
		var out := FileAccess.open(_dump.path_join("port_" + file), FileAccess.WRITE)
		out.store_buffer(page.mem)
		out.close()
	var live := FileAccess.get_file_as_bytes(REFERENCE.path_join(file))
	if live.size() != PAGE_BYTES:
		print("WRONG  %s: cannot read %s" % [name_, file])
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
		print("WRONG  %s, page %d: %d bytes differ, rows %d to %d" % [name_, index + 1, different,
				where[0], where[-1]])
		_bad += 1


## The recording: every "-- get" line with the pokes before it and the
## key after it, and every "-- flying" line with the key after it.
func _read_log(path: String) -> void:
	var pokes: Array = []
	var last: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var view_line := false
	for line: String in file.get_as_text().split("\n"):
		var at := line.find("-- ")
		if at < 0:
			# line 2005 and under it when each of its statements began, in
			# milliseconds: the fourth is the call
			if view_line and line.begins_with("    at "):
				var began := line.split(" ", false)
				_calls.append((float(began[5]) - float(began[4])) * 0.06)
			view_line = line.contains(" line 2005 ")
			continue
		var words := line.substr(at + 3).split(" ", false)
		if words.size() >= 8 and words[0] == "get":
			var fields := {}
			for word in words.slice(2):
				var pair := word.split("=")
				if pair.size() == 2:
					fields[pair[0]] = pair[1]
			var window: PackedStringArray = fields["window"].split(",")
			var bytes := {}
			for address in range(29461, 29476):
				if fields.has(str(address)):
					bytes[address] = int(fields[str(address)])
			last = {
				"name": words[1], "ms": float(line), "line": int(fields["line"]),
				"state": [int(fields["ch"]), int(fields["cv"]), int(window[0]), int(window[1]),
						int(window[2]), int(window[3]), int(fields["c973"]), int(fields["c974"])],
				"bytes": bytes, "handover": int(fields["38388"]),
				"pokes": pokes, "key": "",
			}
			_stops.append(last)
			pokes = []
		elif words.size() >= 3 and words[0].begins_with("flying") and words[1] == "(after":
			last = {"name": words[0], "key": ""}
			_flights.append(last)
		elif words.size() >= 4 and words[0] == "ship" and words[2] == "written":
			pokes.append([LOAD_SHIP, int(words[1])])
		elif words.size() == 2 and words[0] == "poke":
			var pair := words[1].split("=")
			pokes.append([int(pair[0]), int(pair[1])])
		elif words.size() >= 2 and words[0] == "key":
			var key := line.substr(at + 7).substr(1, 1)
			if last.is_empty():
				_first_key = key
			elif last["key"] == "":
				last["key"] = key
