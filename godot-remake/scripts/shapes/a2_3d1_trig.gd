extends RefCounted
## A2-3D1's sine and cosine ($64F8 and $64FB of "LO-HI A2-3D1"), as the
## machine code computes them. Angles are bytes, 256 to the circle; the
## result is a 16-bit word, a fraction of 32768.
##
## Both the 3D view (a2_3d1_view.gd) and the flight step of STARSHIP
## SIMULATOR.bas (flight_core.gd) call these two routines, and both
## depend on their exact output, including the two things a clean
## implementation would not do:
##
##  - the table's entry 25 is $6779 where the curve wants $68A7;
##  - a negative result is built as hi = -hi, lo = -hi - lo - borrow,
##    which is not the two's complement of the table entry.
##
## Port of tools/flight_model.py (cos_raw, sin_raw), which replays 146
## passes of a live run of the real game without a difference.
##
## No `class_name` (see shape_table.gd); preload into a local const.

## The 65 words at $609A: 32767 * cos(i * 90/64 degrees), i = 0..64.
const TABLE: PackedInt32Array = [
	0x7FFF, 0x7FF5, 0x7FD7, 0x7FA6, 0x7F61, 0x7F09, 0x7E9C, 0x7E1C,
	0x7D89, 0x7CE3, 0x7C29, 0x7B5C, 0x7A7C, 0x7989, 0x7883, 0x776B,
	0x7640, 0x7503, 0x73B5, 0x7254, 0x70E1, 0x6F5E, 0x6DC9, 0x6C23,
	0x6A6C, 0x6779, 0x66CE, 0x64E7, 0x62F1, 0x60EB, 0x5ED6, 0x5CB3,
	0x5A81, 0x5842, 0x55F4, 0x539A, 0x5133, 0x4EBF, 0x4C3F, 0x49B3,
	0x471C, 0x447A, 0x41CD, 0x3F16, 0x3C56, 0x398C, 0x36B9, 0x33DE,
	0x30FB, 0x2E10, 0x2B1F, 0x2826, 0x2527, 0x2223, 0x1F19, 0x1C0B,
	0x18F9, 0x15E1, 0x12C7, 0x0FAB, 0x0C8C, 0x096A, 0x0647, 0x0324,
	0x0000,
]


## $64FB. Low byte = what the routine leaves in $600C, high byte = $600D.
static func cos_raw(angle: int) -> int:
	var a := angle & 0xFF
	if a >= 0x80:
		a = (-a) & 0xFF
		if a == 0x80:
			return _negative(0) # ASL of $80 gives index 0
	if a < 0x40:
		return TABLE[a]
	return _negative(0x80 - a)


## $64F8: the cosine of angle - $40.
static func sin_raw(angle: int) -> int:
	return cos_raw((angle - 0x40) & 0xFF)


static func _negative(index: int) -> int:
	var v: int = TABLE[index]
	var lo := v & 0xFF
	var hi := v >> 8
	var x := (0 - hi) & 0xFF
	var borrow := 0 if hi == 0 else 1
	return (x << 8) | ((x - lo - borrow) & 0xFF)
