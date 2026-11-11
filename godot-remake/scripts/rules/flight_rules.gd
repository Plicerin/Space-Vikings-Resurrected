extends RefCounted
## The rules of flight in STARSHIP SIMULATOR.bas (lines 20-147) and the
## stick routine CALL CA ($9023), as a continuous model: where the ship
## goes and how the stick turns it, per frame instead of once a pass.
## No screen in it (scripts/flight/native_flight.gd shows it).
## tests/check_flight_rules.gd holds it to flight_core.gd, which is the
## original's arithmetic one pass at a time and itself is held to a live
## run of the real game (tests/check_flight_core.gd).
##
## A "pass" of the original is one turn of its main loop, about two
## seconds of an Apple drawing; here it is PASS seconds, and everything
## the original does once a pass is done at that rate a second: the
## stick's turn, the bank's turn of the heading, the ship's move, the
## sink in the atmosphere. Angles are the original's, 256 to the circle,
## but signed and not whole: pitch from -61 (nose up) to 59 (nose down),
## bank from -48 to 47, heading round the circle.
##
## What is kept, as it decides how the ship flies:
##  - the stick turns pitch and bank at 1 to 4 a pass by how far over it
##    is, and bank is not brought back to level; heading turns by how
##    far the ship is banked, 1 to 3 a pass, and not at all within 4;
##  - the nose is held between 59 down and 61 up, so there are no loops;
##  - a pass moves the ship `speed` units along its heading, climbing
##    or diving by the pitch: x by cos(pitch) sin(heading), z by cos(pitch)
##    cos(heading), y by -sin(pitch);
##  - the world wraps at +-20000 on each axis;
##  - in the atmosphere the ship sinks 6 - speed/10 a pass, and on the
##    ground (y = 20) pitch and bank are put to nothing.
##
## What is not: that the stick is read and the ship moves once a pass
## (the quantised angles, the 1-in-256 slips at two angles: with a
## continuous model they have nothing to be), and the drawing time that
## made a pass.

const PASS := 1.0 ## seconds a pass of the original is here
const WORLD_EDGE := 20000.0
const ANGLE := TAU / 256.0 ## radians to a unit of angle

const PITCH_DOWN := 59.0
const PITCH_UP := -61.0
const BANK_RIGHT := 47.0
const BANK_LEFT := -48.0
const GROUND := 20.0

const FASTEST := 120.0 ## the most speed, units a pass

## Where the ship is, in the original's units.
var x := 0.0
var y := 0.0
var z := 0.0
var pitch := 0.0 ## signed, 256 to the circle: positive is nose down
var bank := 0.0
var heading := 0.0 ## 0 to 256
var speed := 0.0
var in_atmosphere := false


## From what GameState holds (bytes for the angles).
func load_state() -> void:
	x = float(GameState.ship_x)
	y = float(GameState.ship_y)
	z = float(GameState.ship_z)
	pitch = _signed(GameState.ship_pitch)
	bank = _signed(GameState.ship_bank)
	heading = float(GameState.ship_heading)
	speed = float(GameState.ship_speed)
	in_atmosphere = GameState.in_atmosphere


## Back into GameState, as the original keeps them: whole numbers, the
## angles as bytes.
func store_state() -> void:
	GameState.ship_x = floori(x)
	GameState.ship_y = floori(y)
	GameState.ship_z = floori(z)
	GameState.ship_pitch = roundi(pitch) & 0xFF
	GameState.ship_bank = roundi(bank) & 0xFF
	GameState.ship_heading = roundi(heading) & 0xFF
	GameState.ship_speed = roundi(speed)
	GameState.in_atmosphere = in_atmosphere


## @witness STARSHIP SIMULATOR 15-19, 21, 133-138
## One frame of flight: `dt` seconds with the stick at `pitch_stick` and
## `bank_stick`, each from -1 to 1, 0 centred: positive turns pitch up the
## scale (nose down: the stick forward) and bank up the scale (the paddle
## low). Returns true if the ship has touched the ground.
func fly(dt: float, pitch_stick: float, bank_stick: float) -> bool:
	var passes := dt / PASS
	_stick(passes, pitch_stick, bank_stick)
	_turn(passes)
	_move(passes)
	return _sink(passes)


## @witness STARSHIP SIMULATOR 201-208
## The speed keys: `change` units, kept from 0 to 120.
func change_speed(change: float) -> void:
	speed = clampf(speed + change, 0.0, FASTEST)


## @witness STARSHIP SIMULATOR 170
## The row of the pitch gauge's marker, which a missile's height is
## compared with in the atmosphere (line 1010: `Y0 < VV`): 167 and a
## quarter of the pitch, down the scale for the nose up.
static func pitch_marker(pitch_units: float) -> float:
	return floorf(167.0 + (pitch_units if pitch_units >= 0.0 else pitch_units + 1.0) / 4.0)


## @witness STARSHIP SIMULATOR 156-158
## Within 900 of the planet on every axis and not in the atmosphere: the
## ship goes down (RE).
func is_over_planet() -> bool:
	return not in_atmosphere and absf(x) < 900.0 and absf(y) < 900.0 and absf(z) < 900.0


## @witness STARSHIP SIMULATOR 158
## In the atmosphere and above 4000: the ship goes up into orbit (ORBIT).
func is_leaving_atmosphere() -> bool:
	return in_atmosphere and y > 4000.0


## @witness RE 25-37
## RE.bas: the ship goes down into the atmosphere. It comes out at 188 on
## the x it was at (the low byte of the word is replaced, the high byte
## kept), 1024 up and 7000 short of the planet along z, heading 20, with
## its pitch and bank as they were.
func reenter() -> void:
	in_atmosphere = true # 25  POKE 38210,1
	x = float(((floori(x) >> 8) << 8) + 188) # 27, 29, 35
	y = 1024.0
	z = -7000.0
	heading = 20.0 # 28


## @witness ORBIT 25-37
## ORBIT.bas: the ship goes up into orbit, at (700, 200, 2000), heading 190,
## with its pitch and bank as they were.
func enter_orbit() -> void:
	in_atmosphere = false # 25  POKE 38210,0
	x = 700.0 # 27
	y = 200.0
	z = 2000.0
	heading = 190.0 # 29


## @witness STARSHIP SIMULATOR 21, 112-129
## What the stick does to pitch and bank a pass: how far over it is, from
## 0 to 4 steps. The original reads a paddle (128 centred) against four
## thresholds a side ($5A, $46, $32, $1F below and $AA, $BE, $D2, $E6 above):
## inside 0.31 of the way over it does nothing, and 0.47, 0.63 and 0.78 are
## the next steps.
const STICK_STEPS: Array[float] = [0.31, 0.47, 0.63, 0.78]


static func steps(stick: float) -> float:
	var over := absf(stick)
	var n := 0.0
	for limit in STICK_STEPS:
		if over >= limit:
			n += 1.0
	return signf(stick) * n


func _stick(passes: float, pitch_stick: float, bank_stick: float) -> void:
	pitch = clampf(pitch + steps(pitch_stick) * passes, PITCH_UP, PITCH_DOWN)
	bank = clampf(bank + steps(bank_stick) * passes, BANK_LEFT, BANK_RIGHT)


## Heading turns by how far over the ship is banked: 1, 2 and 3 a pass
## from 5 (6 to the left), 17 and 33 (the 4th step of the original's
## table is at a bank that cannot be reached); right bank turns the
## heading down.
func _turn(passes: float) -> void:
	var over := absf(bank)
	var rate := 0.0
	if over >= 33.0:
		rate = 3.0
	elif over >= 17.0:
		rate = 2.0
	elif over >= (5.0 if bank > 0.0 else 6.0):
		rate = 1.0
	heading = fposmod(heading - signf(bank) * rate * passes, 256.0)


func _move(passes: float) -> void:
	var p := pitch * ANGLE
	var h := heading * ANGLE
	var step := speed * passes
	x += step * cos(p) * sin(h)
	z += step * cos(p) * cos(h)
	y -= step * sin(p)
	x = _wrap(x)
	y = _wrap(y)
	z = _wrap(z)


## Line 147: sinking in the atmosphere, and the ground at 20.
func _sink(passes: float) -> bool:
	if not in_atmosphere:
		return false
	y -= (6.0 - speed / 10.0) * passes
	if y < GROUND:
		y = GROUND
		pitch = 0.0
		bank = 0.0
		return true
	return false


static func _wrap(v: float) -> float:
	if v < -WORLD_EDGE:
		return WORLD_EDGE
	if v > WORLD_EDGE:
		return -WORLD_EDGE
	return v


static func _signed(byte: int) -> float:
	return float(byte - 256 if byte > 127 else byte)


## The 3x3 the original builds from the three attitude angles ($654E):
## view = sum over world axes of (point - eye)[i] * m[3 * i + axis]. The
## view looks along +z with x to the right and y up, in the original's
## world (x, y, z); heading 0 looks along +z and positive pitch is nose down.
static func view_matrix(pitch_units: float, bank_units: float, heading_units: float) -> Array[float]:
	var sp := sin(pitch_units * ANGLE)
	var cp := cos(pitch_units * ANGLE)
	var sb := sin(bank_units * ANGLE)
	var cb := cos(bank_units * ANGLE)
	var sh := sin(heading_units * ANGLE)
	var ch := cos(heading_units * ANGLE)
	return [
		ch * cb + sp * sh * sb, sp * sh * cb - ch * sb, sh * cp,
		sb * cp, cp * cb, -sp,
		ch * sb * sp - sh * cb, sh * sb + sp * ch * cb, ch * cp,
	]


## Where a point is in the view, from an eye and an attitude, in the
## original's world: x right, y up, z ahead.
static func to_view(point: Vector3, eye: Vector3, attitude: Vector3) -> Vector3:
	var m := view_matrix(attitude.x, attitude.y, attitude.z)
	var d := point - eye
	return Vector3(
		d.x * m[0] + d.y * m[3] + d.z * m[6],
		d.x * m[1] + d.y * m[4] + d.z * m[7],
		d.x * m[2] + d.y * m[5] + d.z * m[8])


## @witness STARSHIP SIMULATOR 140-150
## Godot's world has the original's x and y and its z the other way up
## (the original's is left-handed); this is a position there.
static func place(point: Vector3) -> Vector3:
	return Vector3(point.x, point.y, -point.z)


## The camera's basis in Godot's world for an attitude, so that what a
## Camera3D there sees is what the original's view would show.
static func camera_basis(pitch_units: float, bank_units: float, heading_units: float) -> Basis:
	var m := view_matrix(pitch_units, bank_units, heading_units)
	var right := Vector3(m[0], m[3], m[6])
	var up := Vector3(m[1], m[4], m[7])
	var ahead := Vector3(m[2], m[5], m[8])
	return Basis(place(right), place(up), -place(ahead))
