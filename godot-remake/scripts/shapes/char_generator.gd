extends RefCounted
## `HI-RES CHARACTER GENERATOR` ($9300), the routine every PRINT of the
## game goes through once START.bas line 75 has hooked it into the
## output vector (`POKE 54,0: POKE 55,147`, entry $933C). It draws the
## characters onto a hi-res page instead of the text screen and keeps
## the monitor's cursor (CH, CV) for it.
##
## What it does with a character, from the disassembly:
##
##  - carriage return: column to the window's left edge, row + 1; a row
##    past the bottom of the window goes back to the TOP of the window.
##    Nothing ever scrolls.
##  - form feed (ctrl-L): the whole page to 0 (to $FF in inverse mode),
##    cursor to the top left.
##  - anything else: the 7x8 glyph `(code AND 127) * 8` of `CHARACTER
##    TABLE` into the cell, then column + 1, with the carriage-return
##    logic at the right edge.
##
## Three bytes steer it, all poked from BASIC:
##    972  page of the glyph table (always $88 in the game)
##    973  0 store the glyph, 255 store it inverted, anything else XOR it
##    974  the page it draws on: 32 = hi-res page 1, 64 = page 2
##
## The game never changes the text window, so it is the full 40 x 24.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const COLUMNS := 40
const ROWS := 24

## The two hi-res pages (HgrScreen).
var pages: Array = []
## POKE 974 as an index: 0 = page 1 (32), 1 = page 2 (64).
var page: int = 0
## POKE 973.
var mode: int = 0
## CH and CV, both 0-based.
var column: int = 0
var row: int = 0


func _init(page_1: RefCounted, page_2: RefCounted) -> void:
	pages = [page_1, page_2]


## HTAB n / VTAB n (1-based, as in BASIC).
func htab(n: int) -> void:
	column = n - 1


func vtab(n: int) -> void:
	row = n - 1


## One character through the output hook.
func put(code: int) -> void:
	code &= 0x7F
	if code == 0x0D:
		new_line()
		return
	if code == 0x0C:
		pages[page].clear(0xFF if mode == 0xFF else 0)
		column = 0
		row = 0
		return
	pages[page].put_char(code, column, row, mode)
	column += 1
	if column >= COLUMNS:
		new_line()


## The carriage return on its own (a bare `PRINT`).
func new_line() -> void:
	column = 0
	row += 1
	if row >= ROWS:
		row = 0


## `PRINT text;`
func print_text(text: String) -> void:
	for code in text.to_ascii_buffer():
		put(code)


## `PRINT text`
func print_line(text: String) -> void:
	print_text(text)
	new_line()


## Applesoft's `PRINT` of a whole number: no space before or after it.
static func number_text(value: float) -> String:
	return str(int(floor(value)))
