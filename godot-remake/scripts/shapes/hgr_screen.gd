extends RefCounted
## A software copy of one Apple II hi-res page: 192 rows of 40 bytes,
## seven pixels per byte (bit 0 is the leftmost) plus the "palette" bit
## 7. Drawing here follows the ROM bit for bit, so the port's HGR
## screens (instrument panel, star chart) come out as the original
## drew them, including the things that only exist at the byte level:
##
##  - HCOLOR 1/2/5/6 light only odd or only even columns, so a green
##    vertical line at an even X draws nothing (INSTRUMENTS.bas puts
##    every green vertical on an odd X for that reason).
##  - HPLOT and DRAW also copy the colour's high bit into the byte's
##    palette bit, recolouring the other six pixels of that byte.
##  - XDRAW flips one bit and leaves the palette bit alone
##    ($F49C: `LDA #$7F: AND HMASK: ... EOR (HBASL),Y`).
##  - Text is not the Apple's text screen: `HI-RES CHARACTER GENERATOR`
##    (CSW hook at $933C) copies the 7x8 glyph from `CHARACTER TABLE`
##    into the cell's eight bytes. Mode byte $03CD (POKE 973): 0 stores
##    the glyph, 255 stores it inverted (which also sets the palette
##    bit, hence the blue/orange fringes on the inverse labels), any
##    other value XORs it onto what is there.
##
## `image()` turns the bits into colour the way a colour monitor would
## (two lit neighbours = white, a lone lit pixel = violet/green or
## blue/orange by column parity and palette bit, an unlit pixel between
## two lit ones takes their colour). Checked against MAME's rendering of
## the real panel (tools/mame/shapes_live.lua).
##
## Lines use plain Bresenham, not a port of the ROM's HLIN ($F53A); the
## two agree on horizontal and vertical lines and can differ by a pixel
## on diagonals.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")

const WIDTH := 280
const HEIGHT := 192
const COLUMNS := 40
const FONT_PATH := "res://assets/hgr/character_table.json"

## Applesoft's colour bytes ($F6F6) as they apply to an even byte column.
const COLOR_BYTES: PackedByteArray = [0x00, 0x2A, 0x55, 0x7F, 0x80, 0xAA, 0xD5, 0xFF]

const BLACK := Color(0, 0, 0, 0)
const WHITE := Color(1, 1, 1, 1)
const VIOLET := Color8(255, 68, 253)
const GREEN := Color8(20, 245, 60)
const BLUE := Color8(20, 207, 253)
const ORANGE := Color8(255, 106, 60)

var mem := PackedByteArray()
## HCOLOR= (0..7), ROT= and SCALE= as Applesoft keeps them between statements.
var hcolor: int = 3
var rot: int = 0
var shape_scale: int = 1
## POKE 973 (see above).
var text_mode: int = 0
## XDRAW's collision counter ($EA): how many plotted points were unlit.
var collisions: int = 0

var _font := PackedByteArray()
var _image: Image
var _dirty_rows := PackedByteArray()
var _any_dirty := true
var _last := Vector2i.ZERO


func _init() -> void:
	mem.resize(COLUMNS * HEIGHT)
	_dirty_rows.resize(HEIGHT)
	_dirty_rows.fill(1)
	_image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var file := FileAccess.open(FONT_PATH, FileAccess.READ)
	if file == null:
		push_error("HgrScreen: could not open %s" % FONT_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	for b in parsed.get("bytes", []):
		_font.append(int(b))


func is_dirty() -> bool:
	return _any_dirty


## HGR / the character generator's form feed: every byte to `fill`.
func clear(fill: int = 0) -> void:
	mem.fill(fill)
	_dirty_rows.fill(1)
	_any_dirty = true


## Rows `first`..`last` to black. The flight renderer does this to the 3D
## window (rows 0..123) of the page it is about to draw on, which is what
## finally removes anything BASIC left there.
func clear_rows(first: int, last: int) -> void:
	for y in range(maxi(first, 0), mini(last, HEIGHT - 1) + 1):
		for i in range(y * COLUMNS, (y + 1) * COLUMNS):
			mem[i] = 0
		_touch(y)


func _touch(y: int) -> void:
	_dirty_rows[y] = 1
	_any_dirty = true


## OR `mask` into one byte of the page: how A2-3D1 lights its dots (it
## never erases; it clears the whole page first).
func or_byte(y: int, column: int, mask: int) -> void:
	if y < 0 or y >= HEIGHT or column < 0 or column >= COLUMNS:
		return
	mem[y * COLUMNS + column] |= mask
	_touch(y)


## Store one byte of the page, as machine code does with `STA (page),Y`.
func set_byte(y: int, column: int, value: int) -> void:
	if y < 0 or y >= HEIGHT or column < 0 or column >= COLUMNS:
		return
	mem[y * COLUMNS + column] = value & 0xFF
	_touch(y)


## Rows `first`..`last` copied from another page ("MEM TRANSFER A":
## CALL 37888 and CALL 37936 carry the instrument panel, rows 126..189,
## from the page on show to the page just drawn).
func copy_rows_from(other: RefCounted, first: int, last: int) -> void:
	for y in range(maxi(first, 0), mini(last, HEIGHT - 1) + 1):
		for i in range(y * COLUMNS, (y + 1) * COLUMNS):
			mem[i] = other.mem[i]
		_touch(y)


func is_lit(x: int, y: int) -> bool:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return false
	return (mem[y * COLUMNS + x / 7] >> (x % 7)) & 1 == 1


## The colour byte HPLOT uses in byte column `column`: the two-colour
## patterns swap on odd columns so the stripes line up.
func _color_byte(column: int) -> int:
	var c: int = COLOR_BYTES[hcolor & 7]
	if column & 1 == 1 and (c & 0x7F) != 0 and (c & 0x7F) != 0x7F:
		c = (c & 0x80) | ((c & 0x7F) ^ 0x7F)
	return c


## HPLOT x,y in the current HCOLOR.
func hplot(x: int, y: int) -> void:
	_last = Vector2i(x, y)
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return
	var column := x / 7
	var mask := 0x80 | (1 << (x % 7))
	var i := y * COLUMNS + column
	mem[i] = ((mem[i] ^ _color_byte(column)) & mask) ^ mem[i]
	_touch(y)


## HPLOT TO x,y from the last plotted point: Applesoft's HGLIN ($F53A),
## a step at a time. It never moves diagonally. Each step goes one dot
## across or one row up or down and plots, so a line is a staircase of
## |dx| + |dy| + 1 dots, thicker than the usual one dot a row, and not
## the same line drawn from the other end.
func hplot_to(x: int, y: int) -> void:
	var x0 := _last.x
	var y0 := _last.y
	var dx := absi(x - x0)
	var dy := absi(y - y0)
	var sx := 1 if x >= x0 else -1
	var sy := 1 if y > y0 else -1
	# the error term is 16 bits and the carry of the last sum picks the step
	var e := dx
	var across := e >= dy
	e = (e - dy) & 0xFFFF
	hplot(x0, y0)
	for step in range(dx + dy):
		if across:
			x0 += sx
			across = e >= dy
			e = (e - dy) & 0xFFFF
		else:
			y0 += sy
			e += dx
			across = e > 0xFFFF
			e &= 0xFFFF
		hplot(x0, y0)
	_last = Vector2i(x, y)


## `HPLOT x0,y0 TO x1,y1 TO ...` from a flat list of coordinates.
func hplot_path(coords: Array) -> void:
	hplot(coords[0], coords[1])
	for i in range(2, coords.size(), 2):
		hplot_to(coords[i], coords[i + 1])


## DRAW shape AT x,y with the current HCOLOR, ROT and SCALE.
func draw(table: ShapeTable, shape: int, x: int, y: int) -> void:
	for p in table.plots(shape, rot, shape_scale):
		hplot(x + p.x, y + p.y)


## XDRAW shape AT x,y with the current ROT and SCALE.
func xdraw(table: ShapeTable, shape: int, x: int, y: int) -> void:
	for p in table.plots(shape, rot, shape_scale):
		var px: int = x + p.x
		var py: int = y + p.y
		if px < 0 or px >= WIDTH or py < 0 or py >= HEIGHT:
			continue
		var i := py * COLUMNS + px / 7
		var bit := 1 << (px % 7)
		if mem[i] & bit == 0:
			collisions += 1
		mem[i] = mem[i] ^ bit
		_touch(py)


## One glyph of `CHARACTER TABLE` into the text cell (column, row), both
## 0-based, 40 x 24 cells of 7 x 8 pixels. `mode` is POKE 973: 0 stores
## the glyph, 255 stores it inverted, anything else XORs it. The cursor
## belongs to the caller (char_generator.gd).
func put_char(code: int, column: int, row: int, mode: int) -> void:
	if column < 0 or column >= COLUMNS or row < 0 or row >= 24:
		return
	var glyph_at := (code & 0x7F) * 8
	for r in range(8):
		var glyph: int = _font[glyph_at + r] if glyph_at + r < _font.size() else 0
		var i := (row * 8 + r) * COLUMNS + column
		if mode == 0:
			mem[i] = glyph
		elif mode == 0xFF:
			mem[i] = 0xFF ^ glyph
		else:
			mem[i] = mem[i] ^ glyph
		_touch(row * 8 + r)


## `VTAB vtab: HTAB htab: PRINT text;` through the character generator
## (both 1-based), for a screen that keeps no cursor of its own.
func print_at(text: String, htab: int, vtab: int) -> void:
	var column := htab - 1
	var row := vtab - 1
	for ch in text.to_ascii_buffer():
		if column >= COLUMNS:
			column = 0
			row += 1
		if row < 0 or row >= 24:
			return
		put_char(ch, column, row, text_mode)
		column += 1


## Applesoft's `PRINT number`: no leading space, unlike most BASICs.
static func number_text(value: float) -> String:
	return str(int(floor(value)))


## The page as a 280x192 RGBA image; unlit pixels are transparent.
func image() -> Image:
	if not _any_dirty:
		return _image
	var lit := PackedByteArray()
	lit.resize(WIDTH + 2)
	for y in range(HEIGHT):
		if _dirty_rows[y] == 0:
			continue
		_dirty_rows[y] = 0
		var base := y * COLUMNS
		for x in range(WIDTH):
			lit[x + 1] = (mem[base + x / 7] >> (x % 7)) & 1
		for x in range(WIDTH):
			var left: int = lit[x]
			var right: int = lit[x + 2]
			var color := BLACK
			if lit[x + 1] == 1:
				if left == 1 or right == 1:
					color = WHITE
				else:
					color = _lone_color(x, mem[base + x / 7])
			elif left == 1 and right == 1:
				color = _lone_color(x - 1, mem[base + (x - 1) / 7])
			_image.set_pixel(x, y, color)
	_any_dirty = false
	return _image


static func _lone_color(x: int, byte: int) -> Color:
	if byte & 0x80 != 0:
		return ORANGE if x & 1 == 1 else BLUE
	return GREEN if x & 1 == 1 else VIOLET
