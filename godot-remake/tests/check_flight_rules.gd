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
const FlightCore = preload("res://scripts/flight/flight_core.gd")
const A2View = preload("res://scripts/shapes/a2_3d1_view.gd")

var _bad := 0
var _checked := 0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1982
	_matrix(rng)
	_motion(rng)
	_dynamics(rng)
	_stops()
	print("flight rules: %d compared, %d wrong" % [_checked, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


## The engine's own view of a point against this one's. The engine's sines
## and cosines are not quite true: entry 25 of its table is $6779 where the
## curve wants $68A7, and a negative one is built as the table entry's
## complement less its high byte, which is up to 0.4% too far from nothing
## (a2_3d1_trig.gd). So the two agree to within 5% of the distance and
## ten units; a wrong axis or sign is a difference of the distance itself.
func _matrix(rng: RandomNumberGenerator) -> void:
	var view := A2View.new()
	for i in 300:
		var attitude := Vector3(rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255))
		var eye := Vector3(rng.randi_range(-9000, 9000), rng.randi_range(-9000, 9000), rng.randi_range(-9000, 9000))
		var point := eye + Vector3(rng.randi_range(-3000, 3000), rng.randi_range(-3000, 3000), rng.randi_range(-3000, 3000))
		view._eye = [int(eye.x) & 0xFFFF, int(eye.y) & 0xFFFF, int(eye.z) & 0xFFFF]
		view._build_matrix(int(attitude.x), int(attitude.y), int(attitude.z))
		view.poke(A2View.DATABASE, 0)
		view.poke_word(A2View.DATABASE + 1, int(point.x))
		view.poke_word(A2View.DATABASE + 3, int(point.y))
		view.poke_word(A2View.DATABASE + 5, int(point.z))
		var engine = view._transform(A2View.DATABASE)
		var theirs := Vector3(_signed(engine.x), _signed(engine.y), _signed(engine.z))
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


func _signed(v: int) -> int:
	return v - 0x10000 if v & 0x8000 else v


## One step along an attitude (the same slips in the original's table, so
## 2.5% of the speed).
func _motion(rng: RandomNumberGenerator) -> void:
	for i in 400:
		var pitch := rng.randi_range(-61, 59)
		var heading := rng.randi_range(0, 255)
		if [63, 64, 127, 128, 190, 191, 192].has(heading):
			continue # angles at which the original's step does not follow its own cosine: at
			# 63 and 190 the factor is not set at all, and at 64, 128 and 191 the cosine's
			# table entry is read as a negative of nothing, so that the ship all but stops
		var speed := rng.randi_range(1, 120)
		var core := FlightCore.new(1000, 1000, 1000)
		core.step(pitch & 0xFF, heading, speed)
		var rules := FlightRules.new()
		rules.x = 1000.0
		rules.y = 1000.0
		rules.z = 1000.0
		rules.pitch = float(pitch)
		rules.heading = float(heading)
		rules.speed = float(speed)
		rules._move(1.0)
		_checked += 1
		_check("a step at pitch %d heading %d speed %d: the original's (%.2f, %.2f, %.2f), the rules' (%.2f, %.2f, %.2f)" % [
				pitch, heading, speed, core.x, core.y, core.z, rules.x, rules.y, rules.z],
				absf(core.x - rules.x) < 0.025 * speed + 0.05 and absf(core.y - rules.y) < 0.025 * speed + 0.05
				and absf(core.z - rules.z) < 0.025 * speed + 0.05)


## Passes of the original with the stick moved about, against the model
## with the same stick, many frames to a pass. (Held back at the nose-up
## stop the original's stick routine takes the nose past it, turns the
## heading by 126 for the "inverted" flip, and the clamp puts the nose
## back; the model has no such turn, and the heading is not compared in a
## run where that happened.)
func _dynamics(rng: RandomNumberGenerator) -> void:
	for run in 40:
		var core := FlightCore.new(0, 3000, 0)
		var rules := FlightRules.new()
		rules.y = 3000.0
		rules.speed = 60.0
		var pitch := 0
		var bank := 0
		var heading := 0
		var flip := 0
		var over_the_top := false
		for pass_ in 30:
			# a stick position for the pass: a few passes at each setting
			if pass_ % 6 == 0:
				var settings := [-1.0, -0.85, -0.7, -0.55, -0.4, -0.2, 0.0, 0.2, 0.4, 0.55, 0.7, 0.85, 1.0]
				var pitch_stick: float = settings[rng.randi_range(0, 12)]
				var bank_stick: float = settings[rng.randi_range(0, 12)]
				run_sticks = [pitch_stick, bank_stick]
			var paddle_pitch := int(round(128.0 - run_sticks[0] * 127.5))
			var paddle_bank := int(round(128.0 - run_sticks[1] * 127.5))
			var got := FlightCore.stick(pitch, bank, heading, flip, paddle_pitch, paddle_bank)
			if got[0] >= 0x40 and got[0] < 0xC0:
				over_the_top = true # the stick took the nose past the stop: see below
			pitch = FlightCore.pitch_clamp(got[0])
			bank = got[1]
			heading = got[2]
			flip = got[3]
			core.step(pitch, heading, 60)
			for frame in 10:
				rules.fly(0.1, run_sticks[0], run_sticks[1])
		var model_pitch := rules.pitch
		_checked += 1
		_check("run %d: pitch %d (original) and %.1f (rules), bank %d and %.1f, heading %d and %.1f, at (%.0f, %.0f, %.0f) and (%.0f, %.0f, %.0f)" % [
				run, _signed8(pitch), model_pitch, _signed8(bank), rules.bank, heading, rules.heading,
				core.x, core.y, core.z, rules.x, rules.y, rules.z],
				absf(_signed8(pitch) - model_pitch) < 1.5 and absf(_signed8(bank) - rules.bank) < 1.5
				and (over_the_top or absf(_angle_gap(heading, rules.heading)) < 8.0)
				and Vector3(core.x - rules.x, core.y - rules.y, core.z - rules.z).length() < 1800.0)


var run_sticks := [0.0, 0.0]


func _signed8(v: int) -> int:
	return v - 256 if v > 127 else v


func _angle_gap(a: float, b: float) -> float:
	return fposmod(a - b + 128.0, 256.0) - 128.0


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
	var core := FlightCore.new(0, 500, 0)
	for pass_ in 10:
		core.sink(40)
		sinking.fly(1.0, 0.0, 0.0)
	_checked += 1
	_check("ten passes in the atmosphere at 40: y %.1f (original %.1f) less what the speed moved it" % [sinking.y, core.y],
			absf((core.y - 2.0 * 10.0 + 0.0) - (sinking.y - 0.0)) < 40.0 * 10.0 + 1.0 and sinking.y < 500.0 - 10.0 * 2.0 + 1.0
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
