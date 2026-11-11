extends Node
## Holds the flight program (scripts/flight/flight_loop.gd and what it
## runs: flight_program.gd, flight_combat.gd, combat_fx.gd) to the real
## game, recorded pass by pass in MAME. The recording's script of key
## presses, stick positions and pokes is played through the port, and at
## every pass the machine state and both hi-res pages, all 2 x 7680
## bytes, are compared with what the Apple held at that moment.
##
## Two recordings, a scene each (scenes and not `-s` scripts, because
## they need the GameState autoload):
##
##   godot --headless --path godot-remake res://tests/check_flight_passes.tscn
##       analysis/live/pass/ (tools/mame/pass_live.lua), 50 passes: a new
##       game left alone, the stick, the speed keys, the four lamp keys,
##       H with no course set, a re-entry, flight in the atmosphere and
##       the climb back to orbit.
##
##   godot --headless --path godot-remake res://tests/check_jump.tscn
##       analysis/live/jump/ (tools/mame/jump_live.lua), 42 passes: a
##       hyperdrive jump, a missile that hits, one that misses, the
##       laser, the defender's hits on the shields and on the ship, the
##       defender destroyed, the planet's surrender, the ship lost.
##
## The loop is run with no waits and the dice loaded: every roll comes
## up 0.99, on which no fighter comes and the defender never hits,
## except in the passes where the recording shows the defender did, which
## get the rolls that give what was recorded (`dice_at`). What cannot be
## reproduced that way is left out of the comparison and said so below.
##
## Add `-- --dump <directory>` to write the port's pages next to the
## reference names (port_<n>_p1.bin ...) for a look at a difference, or
## `-- --counts` to print how much each view drew (what flight_loop.gd's
## view_frames() was fitted on).

const FlightLoop = preload("res://scripts/flight/flight_loop.gd")
const FlightCore = preload("res://scripts/flight/flight_core.gd")
const CombatFx = preload("res://scripts/combat/combat_fx.gd")

const PAGE_BYTES := 7680
## Rows of the 3D window.
const WINDOW_ROWS := 126

## The recording, from the project directory.
@export var reference := "../analysis/live/pass/"
@export var log_name := "pass_live.log"
## Stop after this event (0 = play them all).
@export var last_event := 0
## State fields the dice decided in the recording.
@export var ignored: PackedStringArray = []
## Events at which page 1's window holds random lines (the hyperdrive's
## rays, the pieces of the defender) and is not compared.
@export var window_random_at: PackedInt32Array = []
## The event that is the first pass after a hyperdrive jump. The ship
## comes out at a random place on a random heading; the port's ship is
## put where the recording's was.
@export var arrival_event := 0
## RND(1) for the fight of a pass, by event: the values in the order
## flight_combat.gd asks for them. Every other roll is 0.99.
@export var dice_at: Dictionary = {}
## The recording ends with the ship destroyed in its last pass.
@export var ends_destroyed := false

var _dir := ""
var _dump := ""
var _counts := false
var _bad := 0
var _loop := FlightLoop.new()
var _events: Array = []
var _next := 0
var _compared := 0
var _fire := false
var _dice: Array = []


func _ready() -> void:
	_dir = ProjectSettings.globalize_path("res://").path_join(reference)
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--dump":
		_dump = args[1]
	_counts = args.has("--counts")
	_events = _read_log(_dir.path_join(log_name))
	if _events.is_empty():
		print("no reference in %s" % _dir)
		get_tree().quit(2)
		return

	GameState.start_new_game()
	var fx := CombatFx.new()
	fx.instant = true
	fx.screen = GameState.view3d.pages[0]
	add_child(fx)
	_loop.setup(fx)
	_loop.combat.rnd = _rnd
	_loop.pass_started = _pass_started
	_loop.read_button = _read_button
	var left: int = await _loop.run()
	var expected := FlightLoop.Left.DESTROYED if ends_destroyed else FlightLoop.Left.STOPPED
	if left != expected or (ends_destroyed and _next < _events.size()):
		print("left the flight program (%d) after pass %d" % [left, _compared])
		_bad += 1
	if ends_destroyed:
		_compare_end()

	print("%d passes compared with the live run: %d different" % [_compared, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


## S_X.bas's last screen (sx_end_p1.bin, sx_end_p2.bin: the pages 2400
## frames into S/X). The rays of the explosion are random and stay above
## the instrument panel's rows, so page 1 is compared from there down:
## the white page and the message. Page 2 is compared whole.
func _compare_end() -> void:
	for p in range(2):
		var live := FileAccess.get_file_as_bytes(_dir.path_join("sx_end_p%d.bin" % (p + 1)))
		var port: PackedByteArray = GameState.view3d.pages[p].mem
		if _dump != "":
			var out := FileAccess.open(_dump.path_join("port_sx_end_p%d.bin" % (p + 1)), FileAccess.WRITE)
			out.store_buffer(port)
		if live.size() != PAGE_BYTES:
			print("no sx_end_p%d.bin in %s" % [p + 1, _dir])
			_bad += 1
			continue
		var different := 0
		for i in range(WINDOW_ROWS * 40 if p == 0 else 0, PAGE_BYTES):
			if live[i] != port[i]:
				different += 1
		if different > 0:
			print("S/X's last screen: page %d differs in %d bytes" % [p + 1, different])
			_bad += 1


## Line 147 of a pass: where the recorder wrote its "ev" line and dumped
## the pages, and then did what its script said.
func _pass_started() -> void:
	var program := _loop.program
	if _counts and _compared > 0:
		print("counts %d records=%d dots=%d atmos=%d projections=%d clips=%d" % [
			_events[_next - 1]["n"], program.view.records_run, program.view.dots_drawn,
			int(GameState.in_atmosphere), program.view.projections, program.view.clip_steps])
	if _next >= _events.size() or (last_event > 0 and _events[_next]["n"] > last_event):
		_loop.stop = true
		return
	var event: Dictionary = _events[_next]
	_next += 1
	if event["n"] == arrival_event:
		_arrive(event["state"])
	_compare(event)
	_compared += 1
	_dice = (dice_at.get(event["n"], []) as Array).duplicate()
	_act(event["acts"])


func _rnd() -> float:
	return 0.99 if _dice.is_empty() else float(_dice.pop_front())


func _read_button() -> bool:
	var down := _fire
	_fire = false
	return down


## Puts the ship where the recording's came out of hyperspace: the start
## whose first step gives the recorded position, on the recorded heading.
func _arrive(state: Dictionary) -> void:
	var program := _loop.program
	var want := Vector3i(int(state["X"]), int(state["Y"]), int(state["Z"]))
	var heading := int(state["H"])
	var probe := FlightCore.new()
	probe.reload(0, 0, 0)
	probe.step(0, heading, program.speed)
	var guess := want - Vector3i(roundi(probe.x), roundi(probe.y), roundi(probe.z))
	var found := false
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			if found:
				break
			probe.reload(guess.x + dx, guess.y, guess.z + dz)
			probe.step(0, heading, program.speed)
			var stored := probe.stored()
			if stored.x == want.x and stored.y == want.y and stored.z == want.z:
				guess += Vector3i(dx, 0, dz)
				found = true
	if not found:
		print("pass %d: no start gives the recorded arrival" % arrival_event)
		_bad += 1
	GameState.ship_x = guess.x
	GameState.ship_y = guess.y
	GameState.ship_z = guess.z
	GameState.ship_pitch = 0
	GameState.ship_bank = 0
	GameState.ship_heading = heading
	program.start(true)
	_loop.combat.start(true)
	program.begin_pass()


## One "ev" line and the "act" lines under it. Where the recording has
## "sw" lines (every touch of a display switch), the page on show is
## taken from those: jump_live.lua's first recording read it from a
## switch the Apple II+ does not have, and its "shown" is always 1.
func _read_log(path: String) -> Array:
	var events: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return events
	var shown := ""
	while not file.eof_reached():
		var words := file.get_line().split(" ", false)
		if words.size() >= 3 and words[1] == "ev":
			var state := {}
			for word in words.slice(4):
				var pair := word.split("=")
				state[pair[0]] = pair[1]
			if shown != "":
				state["shown"] = shown
			events.append({"n": int(words[2]), "state": state, "acts": []})
		elif words.size() >= 3 and words[1] == "sw" and words[2].begins_with("page"):
			shown = words[2].trim_prefix("page")
		elif words.size() >= 2 and words[0] == "act" and not events.is_empty():
			events[-1]["acts"].append(words.slice(1))
	return events


## What the recorder did at this point of the pass (the SCRIPT tables of
## pass_live.lua and jump_live.lua).
func _act(acts: Array) -> void:
	for act in acts:
		match act[0]:
			"key":
				_loop.program.press(act[1])
			"fire":
				_fire = true
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
			"poke":
				_poke(int(act[1]), int(act[2]))
			_:
				print("unknown act %s" % [act])
				_bad += 1


## A byte of the original's memory, as the port keeps it.
func _poke(address: int, value: int) -> void:
	match address:
		38150: GameState.gf_enemy_strength = float(value)
		38152: GameState.defender_damage_points = float(value)
		38163: GameState.target_planet = value - 1
		38193: GameState.ship_hull = float(value)
		38205: GameState.orbital_defender_tier = _tier(value)
		38207: GameState.flight_escort_fighters = value
		38208: GameState.gf_planet_surrendered = value != 0
		_:
			print("poke %d: no such byte in the port" % address)
			_bad += 1


## Defender type 2 flies ship 3: every program that loads a ship for it
## says `IF J = 2 THEN J = 3`, and the port keeps the 3.
func _tier(type: int) -> int:
	return 3 if type == 2 else type


func _compare(event: Dictionary) -> void:
	var program := _loop.program
	var n: int = event["n"]
	var here: int = GameState.current_planet
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
		"planet": str(here + 1),
		"target": str(GameState.target_planet + 1),
		"defender": str(GameState.orbital_defender_tier),
		"c974": "64" if GameState.chargen.page == 1 else "32",
		"shown": str(program.view.shown + 1),
		"tech": str(GameState.planet_tech[here]),
		"surrendered": str(int(GameState.gf_planet_surrendered)),
		"fighters": str(GameState.flight_escort_fighters),
		"strength": str(int(GameState.gf_enemy_strength)),
		"vp": str(int(GameState.gf_victory_progress)),
		"dp": str(int(GameState.defender_damage_points)),
		"threshold": str(int(GameState.defender_damage_threshold)),
		"shield": str(int(GameState.ship_shield)),
		"hull": str(int(GameState.ship_hull)),
		"missiles": str(int(GameState.ship_missile_system)),
		"laser": str(int(GameState.ship_laser)),
		"radar": str(int(GameState.ship_radar)),
		"eng1": str(int(GameState.ship_engine1)),
		"eng2": str(int(GameState.ship_engine2)),
		"computer": str(int(GameState.ship_computer)),
		"secured": str(int(GameState.planet_secured[here])),
		"scouted": str(int(GameState.planet_scouted[here])),
		"stationed": str(GameState.troops_stationed_at),
		"morale": str(GameState.troop_morale),
		"loot": str(int(GameState.loot_collected_this_visit)),
		"c973": str(GameState.chargen.mode),
	}
	var theirs: Dictionary = event["state"].duplicate()
	# Bytes the port keeps as something narrower.
	if theirs.has("defender"):
		theirs["defender"] = str(_tier(int(theirs["defender"])))
	if theirs.has("secured"): # any value but 0 is "secured" to every reader
		theirs["secured"] = str(int(theirs["secured"] != "0"))
	if theirs.has("loot"): # only 1 counts (a new game has 255)
		theirs["loot"] = str(int(theirs["loot"] == "1"))
	var wrong: Array = []
	for key in theirs:
		if ignored.has(key):
			continue
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
		var from := WINDOW_ROWS * 40 if p == 0 and window_random_at.has(n) else 0
		var count := 0
		var rows := {}
		var first: Array = []
		for i in range(from, PAGE_BYTES):
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
