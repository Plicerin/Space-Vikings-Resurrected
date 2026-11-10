extends Node
## Holds scripts/flight/flight_program.gd to the real game: 50 passes of
## the flight loop recorded live in MAME (tools/mame/pass_live.lua,
## analysis/live/pass/). The same script of key presses and stick
## positions is played through the port, and at every pass the machine
## state and both hi-res pages, all 2 x 7680 bytes, are compared with
## what the Apple held at that moment.
##
## The script covers a new game left alone, the stick, the speed keys,
## the four lamp keys, H with no course set, a re-entry, flight in the
## atmosphere and the climb back to orbit.
##
## A scene and not a `-s` script, because it needs the GameState autoload:
##
##   godot --headless --path godot-remake res://tests/check_flight_passes.tscn
##
## Add `-- --dump <directory>` to write the port's pages next to the
## reference names (port_<n>_p1.bin ...) for a look at a difference.

const FlightProgram = preload("res://scripts/flight/flight_program.gd")

const REFERENCE := "../analysis/live/pass/"
const PAGE_BYTES := 7680

var _dir := ""
var _dump := ""
var _bad := 0


func _ready() -> void:
	_dir = ProjectSettings.globalize_path("res://").path_join(REFERENCE)
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--dump":
		_dump = args[1]
	var events := _read_log(_dir.path_join("pass_live.log"))
	if events.is_empty():
		print("no reference in %s" % _dir)
		get_tree().quit(2)
		return

	GameState.start_new_game()
	var program := FlightProgram.new()
	program.instruments()
	program.start(true)
	var compared := 0
	for event in events:
		program.begin_pass()
		_compare(program, event)
		compared += 1
		_act(program, event["acts"])
		program.fly()
		match program.after_view():
			FlightProgram.After.REENTRY:
				program.reentry_show()
				program.reentry_load()
				program.start(true)
				continue
			FlightProgram.After.ORBIT:
				program.orbit_show()
				program.orbit_load()
				program.start(true)
				continue
		match program.keys():
			FlightProgram.Keyed.HYPERDRIVE:
				if not program.hyperdrive_refused():
					print("pass %d: the hyperdrive went, the reference's did not" % event["n"])
					_bad += 1
				program.start(true)
			FlightProgram.Keyed.COM, FlightProgram.Keyed.RADAR:
				print("pass %d: left the flight program" % event["n"])
				_bad += 1

	print("%d passes compared with the live run: %d different" % [compared, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


## One "ev" line and the "act" lines under it.
func _read_log(path: String) -> Array:
	var events: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return events
	while not file.eof_reached():
		var words := file.get_line().split(" ", false)
		if words.size() >= 3 and words[1] == "ev":
			var state := {}
			for word in words.slice(4):
				var pair := word.split("=")
				state[pair[0]] = pair[1]
			events.append({"n": int(words[2]), "state": state, "acts": []})
		elif words.size() >= 2 and words[0] == "act" and not events.is_empty():
			events[-1]["acts"].append(words.slice(1))
	return events


## What the recorder did at this point of the pass (pass_live.lua's SCRIPT).
func _act(program: FlightProgram, acts: Array) -> void:
	for act in acts:
		match act[0]:
			"key":
				program.press(act[1])
			"pdl":
				GameState.paddle_pitch = int(act[1])
				GameState.paddle_bank = int(act[2])
			"auto":
				GameState.autopilot_active = int(act[1]) != 0
			"pos":
				GameState.ship_x = int(act[1])
				GameState.ship_y = int(act[2])
				GameState.ship_z = int(act[3])
			"att":
				GameState.ship_pitch = int(act[1])
				GameState.ship_bank = int(act[2])
				GameState.ship_heading = int(act[3])
			"speed":
				GameState.ship_speed = int(act[1])
			_:
				print("unknown act %s" % [act])
				_bad += 1


func _compare(program: FlightProgram, event: Dictionary) -> void:
	var n: int = event["n"]
	var mine := {
		"it": str(84 + program.oo),
		"X": str(GameState.ship_x), "Y": str(GameState.ship_y), "Z": str(GameState.ship_z),
		"P": str(GameState.ship_pitch), "B": str(GameState.ship_bank), "H": str(GameState.ship_heading),
		"S": str(GameState.ship_speed), "E": str(int(GameState.ship_energy)),
		"pdl": "%d/%d" % [GameState.paddle_pitch, GameState.paddle_bank],
		"auto": str(int(GameState.autopilot_active)),
		"cond": str(GameState.condition),
		"shields": str(int(GameState.shields_up)),
		"weapon": str(int(GameState.missile_mode_active)),
		"atmos": str(int(GameState.in_atmosphere)),
		"dmg": str(int(GameState.damage_alert_active)),
		"flip": str(GameState.loop_flip),
		"b149": "7" if program.first_pass else "0",
		"planet": str(GameState.current_planet + 1),
		"target": str(GameState.target_planet + 1),
		"defender": str(GameState.orbital_defender_tier),
		"c974": "64" if GameState.chargen.page == 1 else "32",
		"shown": str(program.view.shown + 1),
	}
	var theirs: Dictionary = event["state"]
	var wrong: Array = []
	for key in theirs:
		if not mine.has(key):
			wrong.append("%s not compared" % key)
		elif mine[key] != theirs[key]:
			wrong.append("%s=%s (live %s)" % [key, mine[key], theirs[key]])
	var different := not wrong.is_empty()
	if different:
		print("pass %d state: %s" % [n, ", ".join(wrong)])
	for p in range(2):
		var page: PackedByteArray = program.view.pages[p].mem
		if _dump != "":
			var out := FileAccess.open(_dump.path_join("port_%d_p%d.bin" % [n, p + 1]), FileAccess.WRITE)
			out.store_buffer(page)
		var live := FileAccess.get_file_as_bytes(_dir.path_join("ev_%d_p%d.bin" % [n, p + 1]))
		if live.size() != PAGE_BYTES:
			print("pass %d: no page %d in the reference" % [n, p + 1])
			different = true
			continue
		var count := 0
		var rows := {}
		var first: Array = []
		for i in range(PAGE_BYTES):
			if page[i] != live[i]:
				count += 1
				rows[i / 40] = true
				if first.size() < 6:
					first.append("row %d col %d: %02X (live %02X)" % [i / 40, i % 40, page[i], live[i]])
		if count > 0:
			different = true
			var keys := rows.keys()
			keys.sort()
			print("pass %d page %d: %d bytes differ, rows %s" % [n, p + 1, count, _ranges(keys)])
			print("    %s" % "; ".join(first))
	if different:
		_bad += 1


## [3, 4, 5, 9] as "3-5 9".
func _ranges(rows: Array) -> String:
	var parts: Array = []
	var i := 0
	while i < rows.size():
		var j := i
		while j + 1 < rows.size() and rows[j + 1] == rows[j] + 1:
			j += 1
		parts.append(str(rows[i]) if i == j else "%d-%d" % [rows[i], rows[j]])
		i = j + 1
	return " ".join(parts)
