extends Node
## Holds END (scripts/end/end_loop.gd and end_program.gd) to the real
## game. tools/mame/end_live.lua took a new game from flight through
## COM's "4) END" and round END's menu, dumping hi-res page 1 each time
## the program stopped for a key and each time a message was up
## (analysis/live/end/); the same keys are played through the port
## here, with no waits, and at every stop page 1, all 7680 bytes of it,
## is compared with the Apple's, and the cursor, the text window and
## the character generator's two switches with what the recording
## logged.
##
## Two recordings, a scene each:
##
##   godot --headless --path godot-remake res://tests/check_end.tscn
##       end_menu.log: three digits that are no choice (9, 0, 4), a
##       save with GAME SAVED. up, and "2) CONTINUE".
##
##   godot --headless --path godot-remake res://tests/check_end_atmosphere.tscn
##       end_atmosphere.log: a save refused in the atmosphere (38210
##       poked to 1) with the message up, a wrong digit, and "2)
##       CONTINUE".
##
## Both start as the recordings did: a new game flown for three passes
## with the stick left alone, "C" pressed in the third, and "4" at the
## console. And both end as they did: back in the flight program by way
## of GALAXY MAP, page 1 compared once more at the start of its third
## pass.
##
## The rest of END needs no page: what `GET C` makes of a key
## (end_key_*.log), and where "3) END GAME" and an error go.
##
## Saves to a file of its own, not the player's.
##
## Add `-- --dump <directory>` to write the port's page at each stop
## (port_<route>_<name>_p1.bin) for a look at a difference, or
## `-- --times` to print how long the port took from stop to stop next
## to the recording (which has about four frames of the recorder's own
## after every key, and four more before a message is seen).

const FlightLoop = preload("res://scripts/flight/flight_loop.gd")
const ComLoop = preload("res://scripts/com/com_loop.gd")
const EndLoop = preload("res://scripts/end/end_loop.gd")
const EndProgram = preload("res://scripts/end/end_program.gd")
const CombatFx = preload("res://scripts/combat/combat_fx.gd")
const TextScreen = preload("res://scripts/shapes/text_screen.gd")
const SystemError = preload("res://scripts/dos/system_error.gd")

const REFERENCE := "../analysis/live/end/"
const PATH := "user://check_end.json"
const PAGE_BYTES := 7680
## The pass of the flight program the recorder acted in.
const PASS := 3
## The BASIC line a stop is at.
const LINES := {"menu": 70, "saved": 210, "refused": 190}
## The bytes the recorder poked, as GameState has them.
const POKES := {"38210": "in_atmosphere"}
## What each key the live machine was given at the menu came to
## (end_key_<name>.log): 0 and the menu again, or line 63999.
const KEYS := {
	"space": [" ", 0], "dot": [".", 0], "plus": ["+", 0], "minus": ["-", 0],
	"comma": [",", 0], "colon": [":", 0], "e": ["E", 0],
	"return": ["\r", -1], "letter": ["A", -1], "escape": ["\u001b", -1],
}

## end_<route>.log and <route>_<name>_p1.bin.
@export var route := "menu"

var _com: ComLoop
var _end: EndLoop
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
	_stops = _read_log(REFERENCE.path_join("end_%s.log" % route))
	if _stops.size() < 2:
		print("no reference for %s in %s" % [route, REFERENCE])
		get_tree().quit(2)
		return

	GameState.save_path = PATH
	_remove_file()
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

	# COM up to its "4": the recording's first stop.
	_com = ComLoop.new()
	_com.watch = _watch_com
	_check("4 leaves COM for END", await _com.run() == ComLoop.Left.END)

	_end = EndLoop.new()
	_end.watch = _watch
	_end.wait = func(frames: float) -> void: _frames += frames
	_check("2 leaves END for the flight program", await _end.run() == EndLoop.Left.CONTINUE)
	_check("every stop was come to (%d of %d)" % [_next, _stops.size()], _next == _stops.size())
	_check("with the mark for GALAXY MAP", GameState.saved_marker)
	if route == "menu":
		_check("and a game saved", _saved_mark() == true)
	else:
		_check("and no game saved", not FileAccess.file_exists(PATH))

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
	_check("GALAXY MAP took the mark off", not GameState.saved_marker)

	if route == "menu":
		await _keys()
		await _ways_out()

	_remove_file()
	print("%d stops compared with the live run: %d different" % [_compared, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


## COM's command menu: "4".
func _watch_com(what: String) -> void:
	if what != "command":
		return
	var stop: Dictionary = _stops[0]
	_next = 1
	_poke(stop)
	_compare_page(stop["name"])
	_compared += 1
	_com.program.press(stop["key"])


## A stop of END's: the next of the recording, and its key if it is a GET.
func _watch(what: String) -> void:
	if what == "leaving":
		return
	if _next >= _stops.size():
		_check("a stop (%s) after the recording's last" % what, false)
		_end.stop = true
		return
	var stop: Dictionary = _stops[_next]
	_next += 1
	_compared += 1
	var name_: String = stop["name"]
	if _times and _next > 2:
		var live: float = (stop["ms"] - _stops[_next - 2]["ms"]) * 0.06
		print("%-14s %7.1f frames, the recording %7.1f (%+.1f)" % [name_, _frames, live, _frames - live])
	_frames = 0.0

	_check("%s: line %d, the port is at %s" % [name_, stop["line"], what], LINES[what] == stop["line"])
	_check("%s: a GET" % name_, stop["get"] == (what == "menu"))
	_compare_page(name_)
	var text: RefCounted = GameState.chargen
	var port := [text.column, text.row, text.window_left, text.window_width, text.window_top,
			text.window_bottom, text.mode, 32 + 32 * text.page]
	var live_state: Array = stop["state"]
	if port != live_state:
		print("WRONG  %s: cursor, window, 973 and 974 are %s, the Apple's %s" % [name_, port, live_state])
		_bad += 1
	_check("%s: 38391 is %d" % [name_, stop["38391"]], GameState.saved_marker == (stop["38391"] == 77))
	_poke(stop)
	if stop["get"]:
		_end.program.press(stop["key"])


## What the recorder poked before this stop.
func _poke(stop: Dictionary) -> void:
	for address: String in stop["pokes"]:
		GameState.set(POKES[address], stop["pokes"][address] != 0)


## `GET C` with the keys the live machine was given, each on a menu of
## its own.
func _keys() -> void:
	for name_: String in KEYS:
		var key: String = KEYS[name_][0]
		var expected: int = KEYS[name_][1]
		var log_ := FileAccess.get_file_as_string(REFERENCE.path_join("end_key_%s.log" % name_))
		var after := log_.find("-- get menu ")
		_check("end_key_%s.log is there" % name_, after >= 0)
		# on the Apple: line 63999 next, or line 30
		var at_error := log_.find("line 63999", after)
		var at_menu := log_.find("line 30 ", after)
		var live := -1 if at_error >= 0 and (at_menu < 0 or at_error < at_menu) else 0
		_check("%s was %s on the Apple" % [name_, "an error" if expected < 0 else "0"], live == expected)
		_check("%s is %s here" % [name_, "an error" if expected < 0 else "0"],
				EndProgram.number(key) == expected)
		_compared += 1
	for digit in range(10):
		_check("%d is %d" % [digit, digit], EndProgram.number(str(digit)) == digit)


## The two ways out that end the game in hand.
func _ways_out() -> void:
	# a letter: SYSTEM ERROR
	var end := EndLoop.new()
	var frames := [0.0]
	end.wait = func(n: float) -> void: frames[0] += n
	end.watch = func(what: String) -> void:
		if what == "menu":
			frames[0] = 0.0
			end.program.press("a")
	_check("a letter is the SYSTEM ERROR screen", await end.run() == EndLoop.Left.ERROR)
	_check("4.2 frames after it (%.1f)" % frames[0], is_equal_approx(frames[0], 4.2))
	var screen := TextScreen.new()
	SystemError.write(screen)
	var rows := _text_rows(screen)
	_check("which reads SYSTEM ERROR! on row 10 from column 13",
			rows[10] == " ".repeat(13) + "SYSTEM ERROR!" + " ".repeat(14))
	_check("and PRESS ANY KEY TO REBOOT on row 12 from column 8",
			rows[12] == " ".repeat(8) + "PRESS ANY KEY TO REBOOT" + " ".repeat(9))
	var others := 0
	for y in range(TextScreen.ROWS):
		if y != 10 and y != 12 and rows[y] != " ".repeat(40):
			others += 1
	_check("and nothing else", others == 0)
	# the live machine sat in KEYIN with CH = 31, CV = 12
	_check("the cursor after it, as the Apple's (%d, %d)" % [screen.column, screen.row],
			screen.column == 31 and screen.row == 12)
	_check("the picture of it is the Apple's", _picture_different(screen, "system_error.png") == 0)
	_compared += 1

	# 3: the dead machine
	end = EndLoop.new()
	end.wait = func(n: float) -> void: frames[0] += n
	end.watch = func(what: String) -> void:
		if what == "menu":
			frames[0] = 0.0
			end.program.press("3")
	_check("3 is the end", await end.run() == EndLoop.Left.QUIT)
	_check("the screen black 32.7 frames after it (%.1f)" % frames[0], is_equal_approx(frames[0], 32.7))
	_compared += 1


func _text_rows(screen: TextScreen) -> PackedStringArray:
	var rows := PackedStringArray()
	for y in range(TextScreen.ROWS):
		var row := ""
		for x in range(TextScreen.COLUMNS):
			row += String.chr(screen.cells[y * TextScreen.COLUMNS + x] & 0x7F)
		rows.append(row)
	return rows


## The text screen's picture against a snapshot of the live machine's
## (560 by 192, each dot two wide): the dots that differ.
func _picture_different(screen: TextScreen, snapshot: String) -> int:
	var live := Image.load_from_file(REFERENCE.path_join(snapshot))
	if live == null or live.get_width() != 2 * TextScreen.WIDTH or live.get_height() != TextScreen.HEIGHT:
		return -1
	var port := screen.image()
	var different := 0
	for y in range(TextScreen.HEIGHT):
		for x in range(TextScreen.WIDTH):
			var lit := port.get_pixel(x, y).r > 0.5
			if (live.get_pixel(2 * x, y).r > 0.5) != lit or (live.get_pixel(2 * x + 1, y).r > 0.5) != lit:
				different += 1
	return different


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1


func _saved_mark() -> Variant:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return data.get("saved") if data is Dictionary else null


func _remove_file() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


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


## The stops of a recording: every "-- get" line with the key after it,
## every "-- shown" line, and with each the pokes made since the stop
## before.
func _read_log(path: String) -> Array:
	var stops: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return stops
	var pokes := {}
	for line: String in file.get_as_text().split("\n"):
		var at := line.find("-- ")
		if at < 0:
			continue
		var words := line.substr(at + 3).split(" ", false)
		if words.size() >= 8 and (words[0] == "get" or words[0] == "shown"):
			var fields := {}
			for word in words.slice(2):
				var pair := word.split("=")
				fields[pair[0]] = pair[1]
			var window: PackedStringArray = fields["window"].split(",")
			stops.append({
				"name": words[1], "get": words[0] == "get", "ms": float(line), "line": int(fields["line"]),
				"state": [int(fields["ch"]), int(fields["cv"]), int(window[0]), int(window[1]),
						int(window[2]), int(window[3]), int(fields["c973"]), int(fields["c974"])],
				"38391": int(fields["38391"]), "key": "", "pokes": pokes,
			})
			pokes = {}
		elif words.size() == 2 and words[0] == "poke":
			var pair := words[1].split("=")
			pokes[pair[0]] = int(pair[1])
		elif words.size() >= 2 and words[0] == "key" and not stops.is_empty() and stops[-1]["key"] == "":
			stops[-1]["key"] = line.substr(at + 7).substr(1, 1)
	return stops
