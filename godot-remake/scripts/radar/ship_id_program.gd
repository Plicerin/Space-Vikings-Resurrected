extends RefCounted
## The four SHIP # n I.D. programs, a statement at a time and with no
## time in them (ship_id_loop.gd has the clock). RADAR.bas runs the one
## for what is in orbit here when any key but X is pressed, and each
## runs RADAR again at a key.
##
## They are one program four times over with the DATA changed. The top
## of page 1, the radar's picture, is wiped with sixteen rows of spaces;
## a green frame and a grid of five-dot squares are drawn on the left
## 160 dots of it; the ship is drawn on the grid in white, from above
## and then from the side, out of DATA statements (1,x,y moves and 2,x,y
## draws a line, in fifths of a square from a centre the code 77 moves
## down for the second drawing); and four or five lines of text go to
## the right of it:
##
##   0  THERE IS NO / STARSHIP IN / THIS SYSTEM.         (no drawing)
##   1  SMALL SPACE LAB / AND OBSERVATORY / MINIMUM WEAPONS / AND ARMOR.
##   3  LIGHT CRUISER / WITH LASERS, / MISSILES AND / FIGHTER COVER.
##   4  HEAVY CRUISER / WITH PHOTON / MISSILES AND / HEAVY LASERS. /
##      20-40 FIGHTERS
##
## The flight panel underneath stays as RADAR left it.
##
## What the listings do and four copies of one program would not:
##
##  - The title is " -SHIP I.D.-" for 0 and 1, "-SHIP I.D.-" for the
##    light cruiser and "  -SHIP I.D.-" for the heavy one, and the text
##    is on rows 4, 6, 8 and 10 for 0 and 1 and on 3, 5, 7 and 9 for the
##    cruisers.
##  - The grid is drawn in green (HCOLOR= 1), which on the Apple is only
##    the odd dots. Its upright lines are five dots apart, so every
##    other one is at an even dot and is not there: the squares are ten
##    dots wide and five high.
##  - The heavy cruiser's last line is printed where the others wait
##    for the key, so it waits a row lower and a column to the left.
##  - Each leaves the text window sixteen rows high (POKE 35,16), and
##    RADAR and the flight program after it print in that.
##  - The `PRINT " "` after the key goes on page 1, where the cursor
##    was waiting: nothing to see, the cell is blank already.
##  - There is a type 2 in the planets' data and no SHIP # 2 I.D.;
##    RADAR runs the light cruiser's for it.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const CharGenerator = preload("res://scripts/shapes/char_generator.gd")

const GREEN := 1
const WHITE := 3
## Line 10 or 11: `FOR J = 1 TO 16`.
const CLEAR_ROWS := 16
## Line 12's frame, and the FORs of lines 13 and 14.
const FRAME := [1, 1, 161, 1, 161, 123, 1, 123, 1, 1]
const GRID_FIRST_COLUMN := 7
const GRID_LAST_COLUMN := 161
const GRID_FIRST_ROW := 5
const GRID_LAST_ROW := 123
const GRID_STEP := 5
const GRID_TOP := 1
const GRID_BOTTOM := 123
const GRID_LEFT := 1
const GRID_RIGHT := 161
## Line 20: X1 and Y1, and line 1003's Y1 for each program.
const CENTRE := [80, 40]
const SIDE_VIEW := {1: 80, 3: 100, 4: 90}
## The DATA's codes.
const MOVE := 1
const LINE := 2
const SIDE := 77
const END := 127
## Lines 1060-1061: the VTAB and the text of each PRINT, all at HTAB 25.
const TEXT_COLUMN := 25
const TEXTS := {
	0: [[1, " -SHIP I.D.-"], [4, "THERE IS NO"], [6, "STARSHIP IN"], [8, "THIS SYSTEM."]],
	1: [[1, " -SHIP I.D.-"], [4, "SMALL SPACE LAB"], [6, "AND OBSERVATORY"], [8, "MINIMUM WEAPONS"],
		[10, "AND ARMOR."]],
	3: [[1, "-SHIP I.D.-"], [3, "LIGHT CRUISER"], [5, "WITH LASERS,"], [7, "MISSILES AND"],
		[9, "FIGHTER COVER."]],
	4: [[1, "  -SHIP I.D.-"], [3, "HEAVY CRUISER"], [5, "WITH PHOTON"], [7, "MISSILES AND"],
		[9, "HEAVY LASERS."], [11, "20-40 FIGHTERS"]],
}
## The VTAB and HTAB before each program's GET, and the line it is on.
const PROMPT := {0: [11, 25], 1: [11, 25], 3: [10, 25], 4: [12, 24]}
const GET_LINE := {0: 1070, 1: 1070, 3: 1060, 4: 1070}

## SHIP # 1 I.D.'s DATA: 77 points, in READ's order.
const DATA_1 := [
	1, -13, 0, 2, -11, 0, 1, -10, 0.5, 2, -11, 0.5, 2, -11, -0.5, 2, -10, -0.5, 1, -10, 1.5,
	2, -10, -1.5, 2, -5, -1.5, 2, -5, 1.5, 2, -10, 1.5, 1, -10, 0, 2, -5, 0, 1, -5, 2.5,
	2, -5, -2.5, 2, 5, -2.5, 2, 5, 2.5, 2, -5, 2.5, 1, 5, 1.5, 2, 6, 1.5, 2, 6, -1.5, 2, 5, -1.5,
	1, 6, 0, 2, 6, -7.5, 2, 16, -7.5, 2, 16, -4.5, 2, 6, -4.5, 1, -2, 2.5, 2, -2, 3.5, 2, 2, 3.5,
	2, 2, 2.5, 1, -2, 0.5, 2, 2, 0.5, 2, 2, -0.5, 2, -2, -0.5, 2, -2, 0.5, 1, -2, -2.5,
	2, -2, -3.5, 2, 2, -3.5, 2, 2, -2.5, 77, 1, -13, 0, 2, -11, 0, 1, -10, 0.5, 2, -11, 0.5,
	2, -11, -0.5, 2, -10, -0.5, 1, -10, 1.5, 2, -10, -1.5, 2, -5, -1.5, 2, -5, 1.5, 2, -10, 1.5,
	1, -10, 0, 2, -5, 0, 1, -5, 2.5, 2, -5, -2.5, 2, 5, -2.5, 2, 5, 2.5, 2, -5, 2.5, 1, 5, 1.5,
	2, 6, 1.5, 2, 6, -1.5, 2, 5, -1.5, 1, -2, 2.5, 2, -2, 3.5, 2, 2, 3.5, 2, 2, 2.5, 1, -2, 0.5,
	2, 2, 0.5, 2, 2, -0.5, 2, -2, -0.5, 2, -2, 0.5, 1, -2, -2.5, 2, -2, -3.5, 2, 2, -3.5,
	2, 2, -2.5, 1, 6, 0, 2, 16, 0, 127,
]
## SHIP # 3 I.D.'s DATA: 78 points, in READ's order.
const DATA_3 := [
	1, -25, 0, 2, 20, 15, 2, 20, -15, 2, -25, 0, 2, 5, 0, 2, 20, 15, 1, 5, 0, 2, 20, -15, 1, 5, 0,
	2, 15, 4, 1, 5, 0, 2, 15, -4, 1, 20, -5, 2, 15, -5, 2, 15, 5, 2, 20, 5, 1, 15, 1, 2, 18, 1,
	1, 15, -1, 2, 18, -1, 2, 18, -4, 2, 20, -4, 1, 20, 4, 2, 18, 4, 2, 18, -4, 2, 20, -4,
	1, 19, -3, 2, 19, -1, 1, 16, 4, 2, 17, 4, 2, 17, 3, 2, 16, 3, 2, 16, 4, 1, 16, -2, 2, 16, -4,
	2, 18, -4, 2, 18, -3, 2, 17, -3, 2, 17, -2, 2, 16, -2, 1, -5, 3, 2, -5, -3, 2, 1, -3, 2, 1, 3,
	2, -5, 3, 77, 1, -25, 0, 2, 5, 1, 2, 15, 4, 2, 20, 4, 2, 20, 2, 2, 5, 1, 1, 15, 4, 2, 15, 2,
	1, 15, 4, 2, 18, 7, 2, 20, 7, 2, 20, 4, 1, 18, 7, 2, 18, 9, 2, 20, 9, 2, 20, 7, 1, 19, 9,
	2, 19, 10, 1, 19, 8, 1, 17, 4, 2, 17, 5, 2, 19, 5, 2, 19, 4, 1, -25, 0, 2, 20, 0, 1, 20, 2,
	2, 20, -2, 2, -25, -0.5, 1, -5, -0.5, 2, 2, -0.5, 2, 2, -1, 1, -5, -0.5, 2, -5, -1, 127,
]
## SHIP # 4 I.D.'s DATA: 142 points, in READ's order.
const DATA_4 := [
	1, -23, 1, 2, -23, -1, 2, -15, -4, 2, -11, -4, 2, -10, -3, 2, -10, 3, 2, -11, 4, 2, -15, 4,
	2, -23, 1, 1, -23, 0, 2, -10, 0, 1, -15, 4, 2, -15, -4, 1, -10, 2, 2, -6, 2, 2, -6, -2,
	2, -10, -2, 1, -6, 2, 2, -5, 4, 2, -5, 1, 2, -6, 0, 2, -5, -1, 2, -5, -4, 2, -6, -2, 1, -5, 4,
	2, 23, 4, 2, 23, -4, 2, -5, -4, 1, -5, -1, 2, 20, -1, 1, -5, 1, 2, 20, 1, 1, 0, 3, 2, 5, 3,
	1, 10, 3, 2, 15, 3, 1, 0, -3, 2, 5, -3, 1, 10, -3, 2, 15, -3, 1, 20, -4, 2, 20, 4, 1, 2, 4,
	2, 2, 6, 1, 4, 4, 2, 4, 6, 1, 13, 4, 2, 13, 6, 1, 15, 4, 2, 15, 6, 1, -2, 6, 2, 20, 6,
	2, 20, 10, 2, -2, 10, 2, -2, 6, 1, -2, 7, 2, -3, 7, 2, -3, 9, 2, -2, 9, 1, 19, 10, 2, 19, 6,
	1, 2, -4, 2, 2, -6, 1, 4, -4, 2, 4, -6, 1, 13, -4, 2, 13, -6, 1, -2, -6, 2, -2, -10,
	2, 20, -10, 2, 20, -6, 2, -2, -6, 1, -2, -7, 2, -3, -7, 2, -3, -9, 2, -2, -9, 1, 19, -6,
	2, 19, -10, 1, 15, -6, 2, 15, -4, 77, 1, -23, 0, 2, -23, 1, 2, -15, 1, 2, -15, 0, 2, -23, 0,
	2, -15, -1, 2, -15, 4, 2, -23, 1, 1, -15, 4, 2, -10, 4, 2, -10, -1, 2, -15, -1, 1, -11, 4,
	2, -11, -1, 1, -10, 3, 2, -6, 3, 2, -6, 0, 2, -10, 0, 1, -6, 3, 2, -5, 4, 2, -5, 0, 2, -6, 0,
	1, -6, 2, 2, 20, 2, 1, -5, 4, 2, 20, 4, 2, 20, 0, 2, -5, 0, 1, 2, 2, 2, 2, -1, 1, 4, 2,
	2, 4, -1, 1, 13, 2, 2, 13, -1, 1, 15, 2, 2, 15, -1, 1, 20, 3, 2, 23, 3, 2, 23, 0, 2, 20, 0,
	1, -2, -1, 2, 20, -1, 2, 20, -3, 2, -2, -3, 2, -2, -1, 1, -1, -1, 2, -1, -3, 1, 1, -2,
	2, 6, -2, 1, 13, -2, 2, 19, -2, 1, -2, 4, 2, -2, 5, 2, 0, 5, 2, 0, 4, 1, -1, 5, 2, -1, 8,
	2, 0, 7, 2, 1, 6, 2, -0.5, 5, 1, -1, 7, 2, -2, 7, 127,
]

const DATA := {1: DATA_1, 3: DATA_3, 4: DATA_4}

## Which of the four this is: 0, 1, 3 or 4.
var ship: int = 0
var page: HgrScreen
var text: CharGenerator

## The keyboard latch ($C000): bit 7 is the strobe.
var key_latch: int = 0
## BASIC's X1 and Y1, and where READ is in the DATA.
var x1: int = 0
var y1: int = 0
var _next := 0
## How many dots the last `HPLOT TO` went over, and where it ended.
var line_dots := 0
var _last := Vector2i.ZERO


func _init(number: int = 0) -> void:
	ship = number if TEXTS.has(number) else 0
	page = GameState.view3d.pages[0]
	text = GameState.chargen


## A key press as the Apple's keyboard would latch it.
func press(character: String) -> void:
	key_latch = (character.to_upper().unicode_at(0) & 0x7F) | 0x80


## `GET A$` once a key is down.
func take_key() -> String:
	var character := String.chr(key_latch & 0x7F)
	key_latch &= 0x7F
	return character


## RUN SHIP # n I.D.: DOS's carriage return through the character
## generator.
func ran() -> void:
	text.new_line()


## Lines 2-11 up to the FOR. The heavy cruiser's has no HOME. `POKE
## 38151,0` undoes RADAR's 5, which nothing reads.
func open() -> void:
	text.page = 0 # POKE 974,32
	if ship != 4:
		text.home()
	text.set_window(0, 40, 0, 16) # POKE 32,0: POKE 33,40: POKE 34,0: POKE 35,16


## A row of the FOR (`j` 1 to 16). The cruisers' have an HTAB 1 in it
## and the other two have not, which comes to the same.
func clear_row(j: int) -> void:
	text.vtab(j)
	if ship >= 3:
		text.htab(1)
	text.print_line(" ".repeat(40))


## After its NEXT.
func clear_end() -> void:
	text.vtab(1)


## Line 12.
func frame() -> void:
	page.hcolor = GREEN
	page.hplot_path(FRAME)


## Line 13, one of its HPLOTs.
func grid_column(j: int) -> void:
	page.hplot_path([j, GRID_TOP, j, GRID_BOTTOM])


## Line 14, one of its HPLOTs.
func grid_row(j: int) -> void:
	page.hplot_path([GRID_LEFT, j, GRID_RIGHT, j])


## Line 20.
func data_open() -> void:
	page.hcolor = WHITE
	x1 = CENTRE[0]
	y1 = CENTRE[1]
	_next = 0


## True if the program has a drawing: all but SHIP # 0 I.D.
func has_data() -> bool:
	return DATA.has(ship)


## Lines 1000-1050 once round: the code that was read.
func read() -> int:
	var data: Array = DATA[ship]
	var c: int = data[_next]
	_next += 1
	if c == SIDE: # 1003
		y1 = SIDE_VIEW[ship]
		return c
	if c == END: # 1005
		return c
	var x := int(x1 - data[_next] * 2) # 1010-1020
	var y := int(y1 - data[_next + 1] * 2)
	_next += 2
	if c == MOVE:
		page.hplot(x, y)
	elif c == LINE:
		line_dots = absi(x - _last.x) + absi(y - _last.y)
		page.hplot_to(x, y)
	_last = Vector2i(x, y)
	return c


## Lines 1060-1061.
func texts() -> void:
	for line: Array in TEXTS[ship]:
		text.vtab(line[0])
		text.htab(TEXT_COLUMN)
		text.print_line(line[1])


## The VTAB and HTAB before the GET.
func prompt() -> void:
	text.vtab(PROMPT[ship][0])
	text.htab(PROMPT[ship][1])


## `PRINT " "` after the GET.
func key_taken() -> void:
	text.print_line(" ")
