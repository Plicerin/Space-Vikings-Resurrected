extends RefCounted
## The arithmetic of one pass of the original flight loop: where the ship
## goes (STARSHIP SIMULATOR.bas lines 20-147) and what the stick does to
## pitch, bank and heading (the machine code of CALL CA, $9023, up to its
## jump into A2-3D1).
##
## Everything is in the original's own units and nothing is smoothed:
## angles are bytes (256 to the circle), the position is three BASIC
## floats that are stored as 16-bit integers, speed is 0..120 units a
## pass. Port of tools/flight_model.py, which replays 146 passes of a
## live run of the real game without a difference;
## tests/check_flight_core.gd holds this file to that model.
##
## Things the original does that a clean flight model would not, all kept:
##
##  - BASIC decides from the angle, not from the sign bit, how to read
##    the 16-bit cosine. Angles 63 and 190 match neither IF, so the
##    factor keeps the previous pass's value and line 129 divides it by
##    32768 a second time: at those two angles the ship all but stops
##    along that axis.
##  - Pitch is applied to Y twice with opposite signs when the nose is
##    within a quarter turn of level (line 129's `Y = Y - 2 * Y1`), which
##    is what makes "stick back" climb on both sides of the loop.
##  - The world wraps at +-20000 on each axis.
##  - Bank does not return to level: the stick moves it, it is held at
##    +-47, and heading turns by 1..4 a pass while it is over 4.
##  - Crossing the top or bottom of a loop adds 126 or subtracts 127 from
##    the heading, not half a turn.
##
## BASIC's floats have a 32-bit mantissa and these are doubles. The live
## replay above shows no pass where that changes a stored position.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const Trig = preload("res://scripts/shapes/a2_3d1_trig.gd")

const WORLD_EDGE := 20000.0

## X, Y, Z as BASIC holds them between passes.
var x: float = 0.0
var y: float = 0.0
var z: float = 0.0
## The four factors as line 129 leaves them (already divided by 32768).
## The missile's flight (lines 1000-1060) reuses them.
var zp: float = 0.0
var zh: float = 0.0
var xh: float = 0.0
var yp: float = 0.0


## Line 8: BASIC starts from the stored integers every time the program
## is (re)started, and every variable, the factors included, is zero.
func _init(start_x: int = 0, start_y: int = 0, start_z: int = 0) -> void:
	x = float(start_x)
	y = float(start_y)
	z = float(start_z)


## Line 8 again without a RUN. The lamp keys leave the loop through
## `CALL 38402: GOTO 1` (line 500): X, Y and Z are read back from the
## stored integers, so the fractions are lost, but no variable is
## cleared and the four factors keep their values.
func reload(start_x: int, start_y: int, start_z: int) -> void:
	x = float(start_x)
	y = float(start_y)
	z = float(start_z)


## Lines 123-128: CALL CSN, read as "minus 256" when the angle is over 127.
static func basic_sin(angle: int) -> float:
	var word := Trig.sin_raw(angle)
	if angle > 127:
		word -= 65536
	return word / 32768.0


## Lines 114-122 and the division of line 129: CALL SN. `stale` is the
## factor the variable still holds from the pass before.
static func basic_cos(angle: int, stale: float) -> float:
	if angle < 63 or angle > 190:
		return Trig.cos_raw(angle) / 32768.0
	if angle > 63 and angle < 190:
		return (Trig.cos_raw(angle) - 65536) / 32768.0
	return stale / 32768.0


## Lines 112-138: one pass's move for the pitch and heading read at line
## 20 and the speed S.
func step(pitch: int, heading: int, speed: int) -> void:
	zp = basic_cos(pitch, zp)
	zh = basic_cos(heading, zh)
	xh = basic_sin(heading)
	yp = basic_sin(pitch)
	x += speed * (zp * xh)
	z += speed * zp * zh
	var y1 := speed * yp
	y += y1
	if pitch > 190 or pitch < 64:
		y -= 2 * y1
	x = _wrap(x)
	y = _wrap(y)
	z = _wrap(z)


static func _wrap(v: float) -> float:
	if v < -WORLD_EDGE:
		v = WORLD_EDGE
	if v > WORLD_EDGE:
		v = -WORLD_EDGE
	return v


## Line 147 in the atmosphere, after the position has been stored: the
## ship loses 6 - S/10 a pass and stops at 20. Returns true when it
## stopped there; BASIC then also zeroes the pitch and bank bytes.
func sink(speed: int) -> bool:
	y -= 6 - (speed / 10.0)
	if y < 20:
		y = 20.0
		return true
	return false


## Line 140: what goes into the three 16-bit words A2-3D1 reads (BV% = X
## rounds down).
func stored() -> Vector3i:
	return Vector3i(floori(x), floori(y), floori(z))


## CALL CA ($9023) up to its JSR $6000. `paddle_pitch` and `paddle_bank`
## are bytes 38397 and 38398 (PDL(1) and PDL(0); 128 is centred).
## Returns [pitch, bank, heading, flip].
static func stick(pitch: int, bank: int, heading: int, flip: int,
		paddle_pitch: int, paddle_bank: int) -> Array[int]:
	if paddle_pitch < 0x5A:
		for limit in [0x5A, 0x46, 0x32, 0x1F]:
			if paddle_pitch < limit:
				pitch = (pitch + 1) & 0xFF
	elif paddle_pitch >= 0xAA:
		for limit in [0xAA, 0xBE, 0xD2, 0xE6]:
			if paddle_pitch >= limit:
				pitch = (pitch - 1) & 0xFF

	if paddle_bank < 0x5A:
		for limit in [0x5A, 0x46, 0x32, 0x1E]:
			if paddle_bank < limit:
				bank = _bank_up(bank)
	elif paddle_bank >= 0xAA:
		for limit in [0xAA, 0xBE, 0xD2, 0xE6]:
			if paddle_bank >= limit:
				bank = _bank_down(bank)

	var inverted := 1 if pitch >= 0x40 and pitch < 0xC0 else 0
	if inverted != flip:
		flip = inverted
		heading = heading + 0x7E if heading < 0x7F else heading - 0x7F

	if bank < 5:
		pass
	elif bank < 0x31:
		heading = (heading - 1) & 0xFF
		for limit in [0x11, 0x21, 0x30]:
			if bank >= limit:
				heading = (heading - 1) & 0xFF
	elif bank < 0xFB:
		heading = (heading + 1) & 0xFF
		for limit in [0xF0, 0xE0, 0xD0]:
			if bank < limit:
				heading = (heading + 1) & 0xFF
	return [pitch, bank, heading, flip]


static func _bank_up(bank: int) -> int:
	if bank == 0xFF:
		return 0
	bank += 1
	if bank >= 0x30 and bank < 0xD0:
		bank -= 1
	return bank


static func _bank_down(bank: int) -> int:
	if bank == 0:
		return 0xFF
	bank -= 1
	if bank >= 0x30 and bank < 0xD0:
		bank += 1
	return bank


## Lines 175/177, after CALL CA: the pitch byte is kept out of 60..194,
## so the nose never passes 59 up or 61 down (and the "inverted" half of
## the stick routine is only reached through these two stops).
static func pitch_clamp(pitch: int) -> int:
	if pitch > 59 and pitch < 127:
		return 59
	if pitch > 127 and pitch < 195:
		return 195
	return pitch
