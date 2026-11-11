extends RefCounted
## RADAR.bas, a statement at a time and with no time in it
## (radar_loop.gd has the clock). The flight program's "R" runs it, and
## the command console's "3) RADAR".
##
## It is the flight program's own picture from somewhere else. The
## program lifts the eye to 20000 above the plane the stars and the
## defender are in, points it straight down (pitch 63, no bank), has
## A2-3D1 draw its list once on page 1, and puts the ship's height and
## attitude back. So the radar is a map of what is under the ship: the
## star field as dots, and whatever is in orbit here as a small drawing
## where it is. Over that it draws a violet frame, the two diagonals and
## a cross, each stopping short of the middle, and a small green box in
## the middle with a dot in it: the ship.
##
## Then it waits for a key. X goes back to where it was run from; any
## other key runs the SHIP # n I.D. program of what is in orbit
## (ship_id_program.gd), which runs RADAR again.
##
## What the listing does and a radar would not:
##
##  - The eye's heading is left alone, so the map turns with the ship.
##  - The picture is not kept. Coming back from an I.D. the whole of it
##    is drawn again, two seconds of it, stars and all.
##  - A2-3D1 clears all of page 1 for the picture, the flight panel
##    with it, and the panel is copied back from page 2 afterwards
##    (CALL 37936): the lower third of the screen is black while the
##    stars are drawn. The coordinates on the panel's last row are
##    blanked, though the lamps stay.
##  - Line 10: with the radar shot away (38195 = 0) it draws nothing at
##    all and goes straight back, and the player is not told why.
##  - On the way back to the flight it draws black over the two rows of
##    markers on the panel, as COM does on the way in, though only COM
##    has need of it.
##  - Its last PRINT before running a program is a space on page 2, at
##    the top left.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const A2View = preload("res://scripts/shapes/a2_3d1_view.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const CharGenerator = preload("res://scripts/shapes/char_generator.gd")
const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const FlightProgram = preload("res://scripts/flight/flight_program.gd")

## Line 1: YI, P1 and B1.
const EYE_Y := A2View.EYE + 2
const PITCH := A2View.EYE + 6
const BANK := A2View.EYE + 7
## Line 2000: straight down, from 20000 up.
const DOWN := 63
const HEIGHT := 20000
const VIOLET := 2
const GREEN := 1
## Line 2005's frame, and lines 2032 to 2042: each `HPLOT ... TO ...`.
const FRAME := [0, 0, 0, 123, 278, 123, 278, 0, 0, 0]
const EDGE := [[277, 0, 277, 123]]
const DIAGONALS := [
	[1, 0, 131, 59], [279, 0, 151, 59], [151, 67, 279, 123], [1, 123, 131, 67],
]
const CROSS := [
	[140, 1, 140, 55], [140, 71, 140, 123], [1, 63, 131, 63], [151, 63, 279, 63],
]
const BOX := [137, 60, 137, 66, 145, 66, 145, 60, 137, 60]
const BOX_DOT := [141, 63]
## Line 2057: `FOR X = 200 TO 260 STEP 5` and `FOR X = 13 TO 73 STEP 5`.
const MARKERS := [
	200, 205, 210, 215, 220, 225, 230, 235, 240, 245, 250, 255, 260,
	13, 18, 23, 28, 33, 38, 43, 48, 53, 58, 63, 68, 73,
]
const MARKER_SHAPE := 25
const MARKER_ROW := 133
## Line 2059: `FOR J = 1 TO 16`.
const WIPE_ROWS := 16

var view: A2View
var page: HgrScreen
var page_2: HgrScreen
var text: CharGenerator
var shapes := ShapeTable.new()

## The keyboard latch ($C000): bit 7 is the strobe.
var key_latch: int = 0
## L(1), H(1), P(1) and B(1).
var _y_low := 0
var _y_high := 0
var _pitch := 0
var _bank := 0


func _init() -> void:
	view = GameState.view3d
	page = view.pages[0]
	page_2 = view.pages[1]
	text = GameState.chargen
	shapes.load_shapes(FlightProgram.SHAPES_PATH)


## A key press as the Apple's keyboard would latch it.
func press(character: String) -> void:
	key_latch = (character.to_upper().unicode_at(0) & 0x7F) | 0x80


## `GET A$` once a key is down.
func take_key() -> String:
	var character := String.chr(key_latch & 0x7F)
	key_latch &= 0x7F
	return character


## RUN RADAR: DOS's carriage return through the character generator.
func ran() -> void:
	text.new_line()


## Line 10's test.
func dead() -> bool:
	return int(GameState.ship_radar) == 0


## Lines 1500-2000: the eye up and looking down.
func look_down() -> void:
	_y_low = view.peek(EYE_Y)
	_y_high = view.peek(EYE_Y + 1)
	_pitch = view.peek(PITCH)
	view.poke(PITCH, DOWN)
	view.poke_word(EYE_Y, HEIGHT) # GOSUB 6000
	_bank = view.peek(BANK)
	view.poke(BANK, 0)


## Line 2005 up to its CALL 24576: page 1 to clear and to draw on.
## Which page is on show while it draws is 29461's business, and that is
## as the flight program left it.
func view_open() -> void:
	view.poke(A2View.CLEAR_BYTE, 0)
	view.poke(A2View.TARGET_BYTE, 0)
	text.page = 0 # POKE 974,32
	view.begin()


## A record of the list: its opcode, or -1 at the list's end.
func view_step() -> int:
	return view.step()


## `CALL 37936`: the flight panel from page 2.
func panel() -> void:
	page.copy_rows_from(page_2, FlightProgram.PANEL_FIRST_ROW, FlightProgram.PANEL_LAST_ROW)


## The rest of line 2005.
func frame() -> void:
	view.shown = 0 # POKE -16300,0
	page.hcolor = VIOLET
	page.hplot_path(FRAME)


## Line 2010: the panel's coordinates and heading.
func blank_row() -> void:
	text.vtab(24)
	text.htab(1)
	text.print_text(" ".repeat(18))
	text.htab(26)
	text.print_text(" ".repeat(13))


## Lines 2032, 2033 and 2040.
func lines(paths: Array) -> void:
	for path: Array in paths:
		page.hplot_path(path)


## Lines 2042-2045: the ship, and the eye's attitude back.
func box() -> void:
	page.hcolor = GREEN
	page.hplot_path(BOX)
	page.hplot(BOX_DOT[0], BOX_DOT[1])
	view.poke(PITCH, _pitch)
	view.poke(BANK, _bank)


## Lines 2052-2055.
func key_taken() -> void:
	text.vtab(1)
	text.htab(1)
	view.poke(EYE_Y, _y_low)
	view.poke(EYE_Y + 1, _y_high)


## Lines 5000-5005: the number of the I.D. program to run. The data has
## a type 2, which has no program and gets the light cruiser's.
func identify() -> int:
	text.page = 1 # POKE 974,64
	text.print_line(" ")
	var type: int = GameState.orbital_defender_tier
	return 3 if type == 2 else type


## Line 2057, one DRAW of it.
func marker(x: int) -> void:
	page.hcolor = 0
	page.draw(shapes, MARKER_SHAPE, x, MARKER_ROW)


## Line 2058. True if COM ran the program, and is to be run again.
func back_to_com() -> bool:
	text.page = 1 # POKE 974,64
	if GameState.handover == 0:
		return false
	GameState.handover = 0
	text.print_line(" ")
	return true


## Line 2059, a row of it (`row` 1 to 16). The lo-res screen it fills
## afterwards is behind the hi-res one.
func wipe_row(row: int) -> void:
	text.vtab(row)
	text.htab(1)
	text.print_line(" ".repeat(40))
