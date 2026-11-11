extends Node
## Holds STATUS and SUPPLY (scripts/reports/) to the real game.
## tools/mame/reports_live.lua took a new game from flight into COM, to
## the central computer and into one of the two reports, dumping the
## hi-res pages each time a program stopped for a key
## (analysis/live/reports/); the same keys are played through the port
## here, with no waits, and at every stop page 1, all 7680 bytes of it,
## is compared with the Apple's, and the cursor, the text window and the
## character generator's two switches with what the recording logged.
## At the reports' own stops page 2 is compared as well: both reports
## print MISC FILE's three prompts there.
##
## Six recordings, a scene each:
##
##   godot --headless --path godot-remake res://tests/check_status.tscn
##       a new game's two pages.
##   ... res://tests/check_status_poked.tscn
##       every number on the pages another one, the energy a half, and
##       the two bytes of line 1386 both 0: THE TROOPS ARE ALL DEAD!
##   ... res://tests/check_status_odd.tscn
##       a condition, a morale and a troops' place that have no word,
##       so that each line runs on into the next; the energy over 100%.
##   ... res://tests/check_status_morale.tscn
##       STATUS five times over, for the other words: morale 2 to 6, the
##       troops on board, planetside and on shore leave, condition BLUE.
##   ... res://tests/check_supply.tscn
##       a new game's two pages, "1" for the first again, and out.
##   ... res://tests/check_supply_poked.tscn
##       every byte of loot filled: the numbers that run under the units.
##
## All start as the recordings did: a new game flown for three passes
## with the stick left alone, "C" pressed in the third. The recorder
## poked its bytes when COM first stopped for a key (and in the morale
## run each time it did), and so does this. All but one end back in the
## flight program, page 1 compared once more at the start of its third
## pass. The odd one's energy of 200 is more than the flight program's
## gauge can draw, and the real game stopped there with a SYSTEM ERROR,
## so that one ends at the console.
##
## Add `-- --dump <directory>` to write the port's pages at each stop
## (port_<route>_<name>_p1.bin, _p2.bin) for a look at a difference, or
## `-- --times` to print how long the port took from stop to stop next
## to the recording. The recording has about seven frames of the
## recorder's own in every interval, and the port's floppy is cut down
## by DISK_WAIT_SCALE, so only the intervals with no floppy in them
## (from a report's first page to its second) can be held together.

const FlightLoop = preload("res://scripts/flight/flight_loop.gd")
const ComLoop = preload("res://scripts/com/com_loop.gd")
const StatusLoop = preload("res://scripts/reports/status_loop.gd")
const SupplyLoop = preload("res://scripts/reports/supply_loop.gd")
const CharGenerator = preload("res://scripts/shapes/char_generator.gd")
const CombatFx = preload("res://scripts/combat/combat_fx.gd")

const REFERENCE := "../analysis/live/reports/"
const PAGE_BYTES := 7680
## The pass of the flight program the recorder acted in.
const PASS := 3
## The BASIC line of each GET.
const LINES := {
	"command": 120, "central": 260, "ship": 1315, "troops": 1390, "first": 1450, "second": 1510,
}
## The bytes the recorder poked, as GameState has them. 38171 to 38183
## are the loot, and 38159 and 38167 are only STATUS's (see
## status_program.gd).
const BYTES := {
	38153: "gf_missiles", 38154: "gf_tanks", 38155: "gf_transports", 38156: "gf_fighters",
	38165: "condition", 38166: "troop_location", 38186: "ship_laser", 38187: "ship_missile_system",
	38190: "ship_hyperdrive", 38193: "ship_hull", 38195: "ship_radar", 38196: "ship_computer",
	38197: "ship_engine2", 38198: "ship_engine1", 38199: "ship_energy", 38200: "ship_shield",
	38203: "troop_morale",
}
## What Applesoft prints for a number.
const NUMBERS := [
	[100.3, "100.3"], [10000.0, "10000"], [2000.0, "2000"], [0.5, ".5"], [0.0, "0"],
	[-3.25, "-3.25"], [0.01, ".01"], [0.001, "1E-03"], [999999999.0, "999999999"],
	[1000000000.0, "1E+09"], [1234567890.0, "1.23456789E+09"], [100.4, "100.4"], [0.1, ".1"],
	[1.0, "1"], [99.5, "99.5"], [123456.789, "123456.789"],
]

## reports_<route>.log and <route>_<name>_p1.bin.
@export var route := "status"

## The loop that is running: a ComLoop, a StatusLoop or a SupplyLoop.
var _loop: RefCounted
var _stops: Array = []
var _next := 0
var _compared := 0
var _bad := 0
var _dump := ""
var _times := false
var _frames := 0.0
var _passes := 0
## 38159 and 38167, once poked.
var _status_bytes := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--dump":
		_dump = args[1]
	_times = args.has("--times")
	_stops = _read_log(REFERENCE.path_join("reports_%s.log" % route))
	if _stops.is_empty():
		print("no reference for %s in %s" % [route, REFERENCE])
		get_tree().quit(2)
		return
	for number: Array in NUMBERS:
		var text := CharGenerator.float_text(number[0])
		_check("PRINT %s is %s (here %s)" % [str(number[0]), number[1], text], text == number[1])

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
			flight.program.press("C")
	_check("C leaves the flight program for COM", await flight.run() == FlightLoop.Left.COM)
	_check("in pass %d" % PASS, _passes == PASS)

	# COM and the report it runs, until COM runs the flight program
	var reports := 0
	while true:
		var com := ComLoop.new()
		_run(com)
		var left: ComLoop.Left = await com.run()
		if left == ComLoop.Left.STATUS:
			var status := StatusLoop.new()
			for address: int in _status_bytes:
				status.program.set("byte_%d" % address, _status_bytes[address])
			_run(status)
			_check("STATUS runs COM", await status.run() == StatusLoop.Left.COM)
		elif left == ComLoop.Left.SUPPLY:
			var supply := SupplyLoop.new()
			_run(supply)
			_check("SUPPLY runs COM", await supply.run() == SupplyLoop.Left.COM)
		else:
			_check("COM runs the flight program", left == ComLoop.Left.FLIGHT)
			break
		reports += 1
	_check("every stop was come to (%d of %d)" % [_next, _stops.size()], _next == _stops.size())
	_check("a report was run", reports > 0)

	# And back.
	if FileAccess.file_exists(REFERENCE.path_join("%s_flying_p1.bin" % route)):
		flight = FlightLoop.new()
		flight.setup(fx)
		flight.combat.rnd = func() -> float: return 0.99
		_passes = 0
		flight.pass_started = func() -> void:
			_passes += 1
			if _passes == PASS:
				_compare_page("flying", 0)
				_compared += 1
				flight.stop = true
		await flight.run()
		_check("the flight program flew again", _passes == PASS)

	print("%d stops compared with the live run: %d different" % [_compared, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


func _run(loop: RefCounted) -> void:
	_loop = loop
	loop.watch = _watch
	loop.wait = func(frames: float) -> void: _frames += frames


## A GET: the next stop of the recording, its pokes and its key.
func _watch(what: String) -> void:
	if what == "leaving":
		return
	if _next >= _stops.size():
		_check("a GET (%s) after the recording's last" % what, false)
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
	_check("%s: the GET of line %d, the port is at \"%s\"" % [name_, stop["line"], what],
			LINES[what] == stop["line"])
	_compare_page(name_, 0)
	if FileAccess.file_exists(REFERENCE.path_join("%s_%s_p2.bin" % [route, name_])):
		_compare_page(name_, 1)
	var text: RefCounted = GameState.chargen
	var port := [text.column, text.row, text.window_left, text.window_width, text.window_top,
			text.window_bottom, text.mode, 32 + 32 * text.page]
	var live_state: Array = stop["state"]
	if port != live_state:
		print("WRONG  %s: cursor, window, 973 and 974 are %s, the Apple's %s" % [name_, port, live_state])
		_bad += 1
	_loop.program.press(stop["key"])


func _poke(address: int, value: int) -> void:
	if BYTES.has(address):
		GameState.set(BYTES[address], value)
	elif address >= 38171 and address <= 38183:
		GameState.loot[address - 38171] = float(value)
	elif address == 38159 or address == 38167:
		_status_bytes[address] = value
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


## The stops of a recording: every "-- get" line with the pokes before
## it and the key after it.
func _read_log(path: String) -> Array:
	var stops: Array = []
	var pokes: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return stops
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
				"pokes": pokes, "key": "",
			})
			pokes = []
		elif words.size() == 2 and words[0] == "poke":
			var pair := words[1].split("=")
			pokes.append([int(pair[0]), int(pair[1])])
		elif words.size() >= 2 and words[0] == "key" and not stops.is_empty() and stops[-1]["key"] == "":
			stops[-1]["key"] = line.substr(at + 7).substr(1, 1)
	return stops
