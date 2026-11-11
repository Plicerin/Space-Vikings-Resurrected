extends RefCounted
## A2-3D1, the game's 3D engine ("LO-HI A2-3D1", CALL 24576), ported
## step for step from tools/a2_3d1_view.py. That file is the readable
## form of the disassembly; it draws 1000 random views of every display
## database the game uses byte-identical to the machine code, and the
## machine code run on its own reproduces 18 pages dumped from the live
## game. tests/check_a2_3d1.gd holds this port to the same pictures.
##
## The engine is an interpreter. The "display database" at $7300 is a
## list of records; the first byte of a record is its opcode:
##
##      0  x y z        a point                                      7 bytes
##      1  x y z        start of a line; the next record is its end  7 bytes
##      2  x y z        line from the last end point to here         7 bytes
##      3  x y z        line from here to the last end point         7 bytes
##      4  n            n <> 0: do not clip, drop lines that leave   2 bytes
##                      the view
##      5  x y z p b h  eye position and attitude; builds the matrix 10 bytes
##      7  n            soft switch $C000+n (graphics mode, page)    2 bytes
##      8  n            clear page 1 (n=0) or page 2 (n=1)           2 bytes
##      9  n            draw on page 1 (n=0) or page 2 (n<>0)        2 bytes
##     14  w h cx cy    window: size and centre                      5 bytes
##     15  sx sy sz     scale factors for the three view axes        7 bytes
##     anything from $12 up ends the list
##
## x, y, z are 16-bit, low byte first. Opcodes 6, 10, 11, 12, 13, 16 and
## 17 exist in the engine but no file of the game uses them.
##
## The game's files are used as they are on the disk (assets/a2_3d1/):
## PLANET # 0 is the star field of the space view, PLANET # 1-20 are the
## terrain maps of the atmosphere view, SHIP # n and DEBRIS are loaded
## behind PLANET # 0 at $7879. BASIC pokes the eye, the attitude and the
## page bytes into the first records of the list before each call.
##
## All arithmetic is 16-bit and wraps. Numbers are fractions of 32768:
## the multiply returns about a*b/32768 and the divide about 32768*n/d,
## each with its own rounding, copied bit for bit because the rounding
## decides which dot lights up.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const Trig = preload("res://scripts/shapes/a2_3d1_trig.gd")

const DATABASE := 0x7300
const SHIP := 0x7879 # where SHIP # n or DEBRIS is loaded, right after PLANET # 0
const EYE := 0x731B # 29467: X, Y, Z (16-bit), then pitch, bank, heading
const SHOWN_BYTE := DATABASE + 0x15 # 29461: opcode 7's operand, $54 or $55
const CLEAR_BYTE := DATABASE + 0x17 # 29463: opcode 8's operand
const TARGET_BYTE := DATABASE + 0x19 # 29465: opcode 9's operand
const NO_SHIP := 127 # POKE 30841,127: the list ends where the ship would be

const ASSETS := "res://assets/a2_3d1/"

const WORD := 0xFFFF

## Outcode bits: which side of the view pyramid a point is beyond.
const LEFT := 0x40
const RIGHT := 0x20
const BELOW := 0x10
const ABOVE := 0x08

## The dot at half-resolution column x is hi-res pixels 2x and 2x+1: byte
## column 2x/7 and this mask. Column 3 of every 7 straddles two bytes; its
## mask also has bit 7, the colour-shift bit of the byte, which the point
## and steep-line code sets and the shallow-line code does not.
const MASKS: PackedByteArray = [0x03, 0x0C, 0x30, 0xC0, 0x06, 0x18, 0x60]


## A point in view space with its outcode.
class Point:
	var x := 0
	var y := 0
	var z := 0
	var out := 0

	func copy() -> Point:
		var p := Point.new()
		p.x = x
		p.y = y
		p.z = z
		p.out = out
		return p

	## $67EF/$6848: the view pyramid is |x| <= z and |y| <= z.
	func classify() -> void:
		var sx := x - 0x10000 if x & 0x8000 else x
		var sy := y - 0x10000 if y & 0x8000 else y
		var sz := z - 0x10000 if z & 0x8000 else z
		out = 0
		if sx + sz < 0:
			out |= LEFT
		if sz - sx < 0:
			out |= RIGHT
		if sy + sz < 0:
			out |= BELOW
		if sz - sy < 0:
			out |= ABOVE


## 64K, as the Apple has it; only $7300 up to the end of the list is used.
var memory := PackedByteArray()
## Hi-res page 1 and page 2.
var pages: Array = []
## The page the last soft switch (opcode 7) put on show: 0 or 1.
var shown := 0
## What the last run() did, for timing the pass (space_flight.gd): dots
## and line dots lit, records of the list run, perspective divides and
## clipping steps.
var dots_drawn := 0
var records_run := 0
var projections := 0
var clip_steps := 0

# These outlive a call: the engine keeps them in its own code.
var _window := [69, 94, 0, 0] # as the file is on disk
var _axis_scale := [0x7FFF, 0x7FFF, 0x7FFF]
var _target := 0

var _no_clip := 0
var _eye := [0, 0, 0]
var _matrix := [0x7FFD, 0, 0, 0, 0x7FFD, 0, 0, 0, 0x7FFD]
var _last_end := Point.new() # the end point of the last line, unclipped
var _screen_a := Vector2i.ZERO # where the last line's ends were drawn
var _screen_b := Vector2i.ZERO
var _at := DATABASE # the record step() is at


func _init(page_1: HgrScreen = null, page_2: HgrScreen = null) -> void:
	memory.resize(0x10000)
	pages = [page_1 if page_1 != null else HgrScreen.new(), page_2 if page_2 != null else HgrScreen.new()]


# -- the game's display databases (BLOAD) ------------------------------


func bload(path: String, address: int) -> bool:
	var data := FileAccess.get_file_as_bytes(path)
	if data.is_empty():
		push_error("A2-3D1: could not read %s" % path)
		return false
	for i in range(data.size()):
		memory[address + i] = data[i]
	return true


## BLOAD PLANET # n,A$7300. 0 is the star field, 1-20 the terrain maps.
func load_planet(number: int) -> bool:
	return bload("%splanet_%d.bin" % [ASSETS, number], DATABASE)


## BLOAD SHIP # n,A$7879 (n = 0, 1, 3 or 4).
func load_ship(number: int) -> bool:
	return bload("%sship_%d.bin" % [ASSETS, number], SHIP)


## BLOAD DEBRIS,A$7879.
func load_debris() -> bool:
	return bload(ASSETS + "debris.bin", SHIP)


## POKE 30841,127.
func remove_ship() -> void:
	memory[SHIP] = NO_SHIP


func peek(address: int) -> int:
	return memory[address]


func poke(address: int, value: int) -> void:
	memory[address] = value & 0xFF


## Two bytes, low first, as a signed number (BASIC's GOSUB 6600).
func peek_signed(address: int) -> int:
	var v := memory[address] | (memory[address + 1] << 8)
	return v - 0x10000 if v & 0x8000 else v


## A signed number as two bytes, low first (BASIC's GOSUB 6000).
func poke_word(address: int, value: int) -> void:
	memory[address] = value & 0xFF
	memory[address + 1] = (value >> 8) & 0xFF


# -- 16-bit arithmetic -------------------------------------------------


## $635C: about a*b/32768. The first operand is taken bit by bit, the
## second is added; the low byte of the sum is dropped for the first six
## bits, so mul(a, b) and mul(b, a) are not always equal.
static func mul(a: int, b: int) -> int:
	var negative := (a ^ b) & 0x8000
	if a & 0x8000:
		a = (-a) & WORD
	if b & 0x8000:
		b = (-b) & WORD
	var high := b >> 8
	var total := high if a & 1 else 0
	for bit in range(1, 6):
		total >>= 1
		if (a >> bit) & 1:
			total += high
	total = (total >> 1) << 8
	for bit in range(6, 15):
		if (a >> bit) & 1:
			total = (total + b) & WORD
		total >>= 1
	return (-total) & WORD if negative else total


## $6468: about 32768*n/d (n smaller than d), non-restoring, 15 bits.
## A quotient of exactly 1.0 comes out as $7FFF.
static func div(n: int, d: int) -> int:
	var negative := (n ^ d) & 0x8000
	if n & 0x8000:
		n = (-n) & WORD
	if d & 0x8000:
		d = (-d) & WORD
	var quotient := 0
	var rest := (n - d) & WORD
	for step in range(15):
		var below := rest & 0x8000
		quotient = ((quotient << 1) | (0 if below else 1)) & WORD
		rest = (rest << 1) & WORD
		if step < 14:
			rest = (rest + d) & WORD if below else (rest - d) & WORD
	quotient = (quotient << 1) & WORD
	if quotient & 0x8000:
		quotient = ((((quotient >> 8) - 1) & 0xFF) << 8) | (((quotient & 0xFF) - 1) & 0xFF)
	return (-quotient) & WORD if negative else quotient


## $691E: size * fraction / 128, fraction a signed byte.
static func scale(fraction: int, size: int) -> int:
	var total := size if fraction & 1 else 0
	for bit in range(1, 7):
		total >>= 1
		if (fraction >> bit) & 1:
			total += size
	total >>= 1
	if fraction & 0x80:
		total = (total - size) & 0xFF
	return total


## $6979: move `b` (outside) along the line towards `a` (inside), onto
## one of the planes it is beyond. One plane per call; the caller repeats.
static func clip(a: Point, b: Point) -> void:
	var dz := (a.z - b.z) & WORD
	var t: int
	if (b.out & ~LEFT) == 0:
		t = div((b.z + b.x) & WORD, (b.x - a.x - dz) & WORD)
		b.y = (b.y + mul(t, (a.y - b.y) & WORD)) & WORD
		b.z = (b.z + mul(t, dz)) & WORD
		b.x = (-b.z) & WORD
	elif (b.out & ~(LEFT | RIGHT)) == 0:
		t = div((b.z - b.x) & WORD, (a.x - b.x - dz) & WORD)
		b.z = (b.z + mul(t, dz)) & WORD
		b.x = b.z
		b.y = (b.y + mul(t, (a.y - b.y) & WORD)) & WORD
	elif (b.out & ~(LEFT | RIGHT | BELOW)) == 0:
		t = div((b.z + b.y) & WORD, (b.y - a.y - dz) & WORD)
		b.x = (b.x + mul(t, (a.x - b.x) & WORD)) & WORD
		b.z = (b.z + mul(t, dz)) & WORD
		b.y = (-b.z) & WORD
	else:
		t = div((b.z - b.y) & WORD, (a.y - b.y - dz) & WORD)
		b.x = (b.x + mul(t, (a.x - b.x) & WORD)) & WORD
		b.z = (b.z + mul(t, dz)) & WORD
		b.y = b.z
	b.classify()


# -- the interpreter ($6140) -------------------------------------------


## CALL 24576: run the list at $7300 once.
func run() -> void:
	begin()
	while step() >= 0:
		pass


## The call a record at a time, for a caller that wants to show the
## picture growing as the Apple's does (radar_loop.gd): begin(), then
## step() until it returns -1.
func begin() -> void:
	_no_clip = 0
	_eye = [0, 0, 0]
	_matrix = [0x7FFD, 0, 0, 0, 0x7FFD, 0, 0, 0, 0x7FFD]
	_last_end = Point.new()
	_screen_a = Vector2i.ZERO
	_screen_b = Vector2i.ZERO
	dots_drawn = 0
	records_run = 0
	projections = 0
	clip_steps = 0
	_at = DATABASE


## The next record of the list. Returns its opcode, or -1 at the end of
## the list, where nothing is done.
func step() -> int:
	var m := memory
	var at := _at
	if at >= 0xFFF0:
		return -1
	var op: int = m[at]
	if op >= 0x12:
		return -1
	records_run += 1
	match op:
		0:
			var p := _transform(at)
			at += 7
			if p.out == 0:
				_screen_a = _project(p)
				_plot(_screen_a.x, _screen_a.y)
		1:
			var a := _transform(at)
			var b := _transform(at + 7)
			_last_end = b.copy()
			at += 14
			_line(a, b, 0)
		2:
			var a := _last_end.copy()
			var b := _transform(at)
			_last_end = b.copy()
			at += 7
			_line(a, b, 1)
		3:
			var b := _last_end.copy()
			var a := _transform(at)
			at += 7
			_line(a, b, 2)
		4:
			_no_clip = m[at + 1]
			at += 2
		5:
			_eye = [m[at + 1] | (m[at + 2] << 8), m[at + 3] | (m[at + 4] << 8), m[at + 5] | (m[at + 6] << 8)]
			_build_matrix(m[at + 7], m[at + 8], m[at + 9])
			at += 10
		7:
			if m[at + 1] == 0x54 or m[at + 1] == 0x55:
				shown = m[at + 1] - 0x54
			at += 2
		8:
			# the whole page, all 192 rows
			pages[1 if m[at + 1] == 1 else 0].clear()
			at += 2
		9:
			_target = 1 if m[at + 1] != 0 else 0
			at += 2
		14:
			_window = [((m[at + 1] >> 1) - 1) & 0xFF, ((m[at + 2] >> 1) - 1) & 0xFF, m[at + 3], m[at + 4]]
			at += 5
		15:
			_axis_scale = [m[at + 1] | (m[at + 2] << 8), m[at + 3] | (m[at + 4] << 8), m[at + 5] | (m[at + 6] << 8)]
			at += 7
		_:
			push_error("A2-3D1: opcode %d at $%04X is not modelled" % [op, at])
			return -1
	_at = at
	return op


## Forget what a call leaves behind in the engine's own code (window,
## scale factors, target page), as a fresh BLOAD of the engine would.
func reset_engine() -> void:
	_window = [69, 94, 0, 0]
	_axis_scale = [0x7FFF, 0x7FFF, 0x7FFF]
	_target = 0
	shown = 0


## $61B7-$62A0: clip the line a-b to the view pyramid and draw it. A
## line gets at most ten clipping steps, then it is dropped.
##
## Opcodes 2 and 3 save a projection. Opcode 2 (reuse 1): when the first
## end is in view it is not projected again. Opcode 3 (reuse 2): when
## both ends are in view the second is not projected again. In both
## cases the code takes whatever screen position the previous line's
## second end had, also when that line was dropped and never got one.
func _line(a: Point, b: Point, reuse: int) -> void:
	if a.out & b.out:
		return
	var budget := 10
	var project_first := true
	var project_second := true
	if a.out:
		if _no_clip:
			return
		while true:
			clip(b, a)
			clip_steps += 1
			if a.out == 0:
				break
			if a.out & b.out:
				return
			budget -= 1
			if budget == 0:
				return
	elif reuse == 1:
		project_first = false
	elif reuse == 2 and b.out == 0:
		project_second = false
	while b.out:
		if _no_clip:
			return
		clip(a, b)
		clip_steps += 1
		budget -= 1
		if budget == 0:
			return
	if project_first:
		_screen_a = _project(a)
	else:
		_screen_a = _screen_b
	if project_second:
		_screen_b = _project(b)
	_draw_line(_screen_a, _screen_b)


# -- matrix and transform ----------------------------------------------


## $654E. Angles are bytes, 256 to the circle. The view looks along +Z
## at heading 0; positive pitch is nose down.
##
## matrix[0..2] are the X, Y, Z view axes' weights of the world X
## difference, [3..5] of the Y difference, [6..8] of the Z difference.
func _build_matrix(pitch: int, bank: int, heading: int) -> void:
	var sp := Trig.sin_raw(pitch)
	var sb := Trig.sin_raw(bank)
	var sh := Trig.sin_raw(heading)
	var cp := Trig.cos_raw(pitch)
	var cb := Trig.cos_raw(bank)
	var ch := Trig.cos_raw(heading)
	var ch_cb := mul(ch, cb)
	var sh_sb := mul(sh, sb)
	var ch_sb := mul(ch, sb)
	var sh_cb := mul(sh, cb)
	var m := [
		(ch_cb + mul(sp, sh_sb)) & WORD, (mul(sp, sh_cb) - ch_sb) & WORD, mul(sh, cp),
		mul(sb, cp), mul(cp, cb), (-sp) & WORD,
		(mul(ch_sb, sp) - sh_cb) & WORD, (sh_sb + mul(sp, ch_cb)) & WORD, mul(ch, cp),
	]
	# opcode 15's scale factors, one per view axis; $7FFF means 1.
	# A slip in the code: it loads the factor's low byte only when the
	# high byte is $7F (to test for $7FFF). Otherwise the first of the
	# three products uses the factor's high byte with whatever is in
	# the A register: the low byte of the last product, or of the
	# previous axis's factor if that one was tested and skipped.
	var register_a: int = m[8] & 0xFF
	for axis in range(3):
		var factor: int = _axis_scale[axis]
		if factor >> 8 == 0x7F:
			register_a = factor & 0xFF
			if register_a == 0xFF:
				continue
		m[axis] = mul((factor & 0xFF00) | register_a, m[axis])
		if axis == 0:
			m[3] = mul(m[3], factor)
			m[6] = mul(m[6], factor)
		else:
			m[3 + axis] = mul(factor, m[3 + axis])
			m[6 + axis] = mul(factor, m[6 + axis])
		register_a = m[6 + axis] & 0xFF
	_matrix = m


## $672B: the record's x, y, z, relative to the eye, in view space.
func _transform(at: int) -> Point:
	var mem := memory
	var m := _matrix
	var d0: int = ((mem[at + 1] | (mem[at + 2] << 8)) - _eye[0]) & WORD
	var d1: int = ((mem[at + 3] | (mem[at + 4] << 8)) - _eye[1]) & WORD
	var d2: int = ((mem[at + 5] | (mem[at + 6] << 8)) - _eye[2]) & WORD
	var p := Point.new()
	p.x = (mul(d0, m[0]) + mul(d1, m[3]) + mul(d2, m[6])) & WORD
	p.y = (mul(d0, m[1]) + mul(d1, m[4]) + mul(d2, m[7])) & WORD
	p.z = (mul(d0, m[2]) + mul(d1, m[5]) + mul(d2, m[8])) & WORD
	p.classify()
	return p


## $68A1: perspective divide, then the window. Returns the two bytes the
## plot routines take: x from the window centre to the right, y from it
## upwards.
func _project(p: Point) -> Vector2i:
	projections += 1
	var x: int = (scale(div(p.x, p.z) >> 8, _window[0]) + _window[2]) & 0xFF
	var y: int = (scale(div(p.y, p.z) >> 8, _window[1]) + _window[3]) & 0xFF
	return Vector2i(x, y)


# -- dots ($6D8F) and lines ($6DD5) --------------------------------------


## x: half-resolution column (0-139), two hi-res pixels wide.
func _dot(x: int, row: int, mask_bit7: bool) -> void:
	var page: HgrScreen = pages[_target]
	var column := (2 * x) / 7
	var mask: int = MASKS[x % 7]
	page.or_byte(row, column, mask if mask_bit7 else mask & 0x7F)
	if x % 7 == 3:
		page.or_byte(row, column + 1, 0x01)
	dots_drawn += 1


func _plot(x: int, y: int) -> void:
	_dot((x + 70) & 0xFF, (95 - y) & 0xFF, true)


func _draw_line(a: Vector2i, b: Vector2i) -> void:
	var x1 := (a.x + 70) & 0xFF
	var y1 := (95 - a.y) & 0xFF
	var x2 := (b.x + 70) & 0xFF
	var y2 := (95 - b.y) & 0xFF
	if x2 < x1:
		var t := x1
		x1 = x2
		x2 = t
		t = y1
		y1 = y2
		y2 = t
	var dx := x2 - x1
	var dy := absi(y2 - y1)
	var step := 1 if y2 >= y1 else -1
	var x := x1
	var y := y1
	if dy < dx:
		# shallow: one dot per column
		var error := -((dx + 1) / 2)
		for i in range(dx + 1):
			_dot(x, y, false)
			error += dy
			if error >= 0:
				error -= dx
				y += step
			x += 1
	else:
		# steep: one dot per row
		var error := dy >> 1
		for i in range(dy + 1):
			_dot(x, y, true)
			y += step
			error -= dx
			if error < 0:
				error += dy
				x += 1
