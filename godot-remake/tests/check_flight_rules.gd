extends Node
## Holds scripts/rules/flight_rules.gd, the continuous flight model, to the
## original's. Four things:
##
##  - the view matrix is the one the A2-3D1 engine builds from the same
##    attitude (the engine's own transform of the same points, from
##    scripts/shapes/a2_3d1_view.gd, which is held to the machine code);
##  - the camera basis in Godot's world sees a point where that view has it;
##  - one step of the model along an attitude is flight_core.gd's step (the
##    original's arithmetic, held to a live run) for the same pitch,
##    heading and speed;
##  - a stretch of flight with the stick moved about ends where the
##    original's passes (flight_core.gd's stick and step, one a pass) end,
##    within what the quantising of the original's angles allows.
##
##   godot --headless --path godot-remake res://tests/check_flight_rules.tscn

const FlightRules = preload("res://scripts/rules/flight_rules.gd")
## The original's answers (the hi-res engine's code, held to the real game
## while it was in the project) are tests/golden/flight_rules.json.
const GOLDEN := "res://tests/golden/flight_rules.json"

var _bad := 0
var _checked := 0
var _golden: Dictionary


func _ready() -> void:
	_golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_matrix()
	_motion()
	_dynamics()
	_stops()
	_down_and_up()
	print("flight rules: %d compared, %d wrong" % [_checked, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


## The engine's own view of a point against this one's. The engine's sines
## and cosines are not quite true: entry 25 of its table is $6779 where the
## curve wants $68A7, and a negative one is built as the table entry's
## complement less its high byte, which is up to 0.4% too far from nothing
## (a2_3d1_trig.gd). So the two agree to within 5% of the distance and
## ten units; a wrong axis or sign is a difference of the distance itself.
func _matrix() -> void:
	for c: Dictionary in _golden.matrix:
		var attitude := _v(c.att)
		var eye := _v(c.eye)
		var point := _v(c.point)
		var theirs := _v(c.engine)
		var mine := FlightRules.to_view(point, eye, attitude)
		_checked += 1
		_check("view of %s from %s at %s: the engine has %s, the rules %s" % [point, eye, attitude, theirs, mine],
				(theirs - mine).length() < 0.05 * (point - eye).length() + 10.0)
		# Godot's camera
		var basis := FlightRules.camera_basis(attitude.x, attitude.y, attitude.z)
		var local := basis.inverse() * (FlightRules.place(point) - FlightRules.place(eye))
		_checked += 1
		_check("the camera sees it at %s, the view has %s" % [local, mine],
				(local - Vector3(mine.x, mine.y, -mine.z)).length() < 0.01)


func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _signed(v: int) -> int:
	return v - 0x10000 if v & 0x8000 else v


## One step along an attitude (the same slips in the original's table, so
## 2.5% of the speed).
func _motion() -> void:
	for c: Dictionary in _golden.motion:
		var pitch: int = c.pitch
		var heading: int = c.heading
		var speed: int = c.speed
		var core := _v(c.core)
		var rules := FlightRules.new()
		rules.x = 1000.0
		rules.y = 1000.0
		rules.z = 1000.0
		rules.pitch = float(pitch)
		rules.heading = float(heading)
		rules.speed = float(speed)
		rules._move(1.0)
		_checked += 1
		_check("a step at pitch %d heading %d speed %d: the original's %s, the rules' (%.2f, %.2f, %.2f)" % [
				pitch, heading, speed, core, rules.x, rules.y, rules.z],
				absf(core.x - rules.x) < 0.025 * speed + 0.05 and absf(core.y - rules.y) < 0.025 * speed + 0.05
				and absf(core.z - rules.z) < 0.025 * speed + 0.05)


## Passes of the original with the stick moved about, against the model
## with the same stick, many frames to a pass. (Held back at the nose-up
## stop the original's stick routine takes the nose past it, turns the
## heading by 126 for the "inverted" flip, and the clamp puts the nose
## back; the model has no such turn, and the heading is not compared in a
## run where that happened.)
func _dynamics() -> void:
	var run := 0
	for c: Dictionary in _golden.dynamics:
		var rules := FlightRules.new()
		rules.y = 3000.0
		rules.speed = 60.0
		for sticks: Array in c.sticks:
			for frame in 10:
				rules.fly(0.1, sticks[0], sticks[1])
		var core := _v(c.core)
		var pitch: int = c.pitch
		var bank: int = c.bank
		var heading: int = c.heading
		_checked += 1
		_check("run %d: pitch %d (original) and %.1f (rules), bank %d and %.1f, heading %d and %.1f, at %s and (%.0f, %.0f, %.0f)" % [
				run, _signed8(pitch), rules.pitch, _signed8(bank), rules.bank, heading, rules.heading,
				core, rules.x, rules.y, rules.z],
				absf(_signed8(pitch) - rules.pitch) < 1.5 and absf(_signed8(bank) - rules.bank) < 1.5
				and (c.over_the_top or absf(_angle_gap(heading, rules.heading)) < 8.0)
				and (core - Vector3(rules.x, rules.y, rules.z)).length() < 1800.0)
		run += 1


func _signed8(v: int) -> int:
	return v - 256 if v > 127 else v


func _angle_gap(a: float, b: float) -> float:
	return fposmod(a - b + 128.0, 256.0) - 128.0


## RE and ORBIT: where the ship comes out, against the original's own
## statements (flight_program.gd's reentry_load and orbit_load).
func _down_and_up() -> void:
	for c: Dictionary in _golden.down_up:
		GameState.start_new_game()
		var from: Array = c.from
		GameState.ship_x = int(from[0])
		GameState.ship_y = int(from[1])
		GameState.ship_z = int(from[2])
		GameState.ship_pitch = int(from[3])
		GameState.ship_bank = int(from[4])
		GameState.ship_heading = int(from[5])
		var rules := FlightRules.new()
		rules.load_state()
		rules.reenter()
		rules.store_state()
		var down: Array = c.down
		var mine := [GameState.ship_x, GameState.ship_y, GameState.ship_z, GameState.ship_heading, GameState.ship_pitch, GameState.ship_bank]
		_checked += 1
		_check("down from %s: the original's %s, the rules' %s" % [str(from), str(down), str(mine)],
				_same(down, mine) and rules.in_atmosphere)
		rules.enter_orbit()
		rules.store_state()
		var up: Array = c.up
		mine = [GameState.ship_x, GameState.ship_y, GameState.ship_z, GameState.ship_heading]
		_checked += 1
		_check("up: the original's %s, the rules' %s" % [str(up), str(mine)], _same(up, mine) and not rules.in_atmosphere)


func _same(a: Array, b: Array) -> bool:
	for i in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true


## The nose and the bank are held where the original holds them.
func _stops() -> void:
	var rules := FlightRules.new()
	for i in 200:
		rules.fly(0.1, 1.0, 1.0)
	_checked += 1
	_check("held hard over, the nose stops at 59 down and the bank at 47 (%.1f, %.1f)" % [rules.pitch, rules.bank],
			rules.pitch == 59.0 and rules.bank == 47.0)
	for i in 400:
		rules.fly(0.1, -1.0, -1.0)
	_checked += 1
	_check("and the other way at 61 up and 48 (%.1f, %.1f)" % [rules.pitch, rules.bank],
			rules.pitch == -61.0 and rules.bank == -48.0)
	# the sink of line 147 against the original's, at a speed
	var sinking := FlightRules.new()
	sinking.in_atmosphere = true
	sinking.y = 500.0
	sinking.speed = 40.0
	var core_y: float = _golden.sink_y
	for pass_ in 10:
		sinking.fly(1.0, 0.0, 0.0)
	_checked += 1
	_check("ten passes in the atmosphere at 40: y %.1f (original %.1f) less what the speed moved it" % [sinking.y, core_y],
			absf((core_y - 2.0 * 10.0 + 0.0) - (sinking.y - 0.0)) < 40.0 * 10.0 + 1.0 and sinking.y < 500.0 - 10.0 * 2.0 + 1.0
			and sinking.y > 500.0 - 10.0 * 2.0 - 1.0 - 0.0)
	# the world's edge
	var edge := FlightRules.new()
	edge.x = -19990.0
	edge.heading = 192.0
	edge.speed = 100.0
	edge.fly(1.0, 0.0, 0.0)
	var other := FlightRules.new()
	other.x = 19990.0
	other.heading = 64.0
	other.speed = 100.0
	other.fly(1.0, 0.0, 0.0)
	_checked += 1
	_check("the world wraps at -20000 to 20000 and 20000 to -20000 (%.0f, %.0f)" % [edge.x, other.x],
			edge.x == 20000.0 and other.x == -20000.0)
	var ground := FlightRules.new()
	ground.in_atmosphere = true
	ground.y = 30.0
	ground.speed = 0.0
	ground.pitch = 5.0
	ground.bank = 10.0
	var landed := false
	for i in 50:
		landed = ground.fly(0.1, 0.0, 0.0) or landed
	_checked += 1
	_check("in the atmosphere the ship sinks to 20, and on the ground pitch and bank go (y %.1f, %.1f, %.1f)" % [ground.y, ground.pitch, ground.bank],
			landed and ground.y == 20.0 and ground.pitch == 0.0 and ground.bank == 0.0)


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1
