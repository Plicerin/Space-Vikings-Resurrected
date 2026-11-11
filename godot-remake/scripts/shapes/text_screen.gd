extends RefCounted
## The Apple's text screen: 40 by 24 characters at $400, in the
## machine's own character set. The game hardly shows it. Once START.bas
## has hooked the hi-res character generator into the output vector
## every PRINT is drawn on a hi-res page instead, and the text screen
## behind it holds whatever HOME and the flashes left there. It comes
## forward in two places: DOS's error message (system_error.gd), which
## is written straight to it past the hook, and the dead machine END
## GAME leaves (end_loop.gd), where it is blank.
##
## `home()` and `cout()` are the monitor's HOME ($FC58) and COUT1
## ($FDF0), from the ROM. Unlike the character generator's, the
## monitor's column counts from the window's left edge, and a line at
## the bottom of the window scrolls.
##
## The characters are the II+'s, 5 by 7 in a cell of 7 by 8 with the top
## line empty, taken from a snapshot of the live machine with all
## sixty-four on the screen (tools/mame/end_live.lua, route `font`;
## analysis/live/end/apple_text_characters.png). They are not the
## game's CHARACTER TABLE, which the hi-res pages use: only one glyph of
## the fourteen in the error message is the same in both.
##
## A code under $40 is shown inverse. $40-$7F flashes on the real
## machine and is shown inverse here; nothing the game puts on the
## screen flashes.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const COLUMNS := 40
const ROWS := 24
const WIDTH := 280
const HEIGHT := 192
const SPACE := 0xA0
const FONT_PATH := "res://assets/hgr/apple_text_font.json"

## The screen codes, a row after another.
var cells := PackedByteArray()
## CH and CV.
var column: int = 0
var row: int = 0
## WNDLFT, WNDWDTH, WNDTOP, WNDBTM.
var window_left: int = 0
var window_width: int = COLUMNS
var window_top: int = 0
var window_bottom: int = ROWS

var _font := PackedByteArray()
var _image: Image
var _dirty := true


func _init() -> void:
	cells.resize(COLUMNS * ROWS)
	cells.fill(SPACE)
	var data = JSON.parse_string(FileAccess.get_file_as_string(FONT_PATH))
	if data is Dictionary:
		_font = PackedByteArray(data["bytes"])
	_image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)


func set_window(left: int, width: int, top: int, bottom: int) -> void:
	window_left = left
	window_width = width
	window_top = top
	window_bottom = bottom


## HOME: the window to spaces, the cursor to its top left.
func home() -> void:
	for y in range(window_top, window_bottom):
		_clear_row(y)
	column = 0
	row = window_top


## COUT1: a character (bit 7 set, as the monitor has them) at the
## cursor, or a carriage return. The other control characters do
## nothing here.
func cout(code: int) -> void:
	if code == 0x8D:
		_new_line()
		return
	if code < SPACE:
		return
	_store(window_left + column, row, code)
	column += 1
	if column >= window_width:
		_new_line()


func is_dirty() -> bool:
	return _dirty


## The screen as a picture: white on black, a dot a pixel.
func image() -> Image:
	if not _dirty:
		return _image
	for y in range(ROWS):
		for x in range(COLUMNS):
			var code: int = cells[y * COLUMNS + x]
			var six := code & 0x3F
			var glyph_at := ((six + 0x40 if six < 0x20 else six) - 0x20) * 8
			var inverse := 0x7F if code < 0x80 else 0
			for r in range(8):
				var bits: int = (_font[glyph_at + r] if glyph_at + r < _font.size() else 0) ^ inverse
				for dot in range(7):
					_image.set_pixel(x * 7 + dot, y * 8 + r, Color.WHITE if (bits >> dot) & 1 == 1 else Color.BLACK)
	_dirty = false
	return _image


func _store(x: int, y: int, code: int) -> void:
	if x < 0 or x >= COLUMNS or y < 0 or y >= ROWS:
		return
	cells[y * COLUMNS + x] = code
	_dirty = true


func _clear_row(y: int) -> void:
	for x in range(window_left, window_left + window_width):
		_store(x, y, SPACE)


func _new_line() -> void:
	column = 0
	row += 1
	if row < window_bottom:
		return
	row = window_bottom - 1
	for y in range(window_top, window_bottom - 1):
		for x in range(window_left, window_left + window_width):
			if x < COLUMNS and y + 1 < ROWS:
				_store(x, y, cells[(y + 1) * COLUMNS + x])
	_clear_row(window_bottom - 1)
