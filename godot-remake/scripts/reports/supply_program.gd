extends RefCounted
## SUPPLY.bas, a statement at a time and with no time in it
## (supply_loop.gd has the clock). The central computer's "5) SUPPLY
## STATUS" runs it. Two pages:
##
##            - SUPPLY REPORT -                  - SUPPLY REPORT -
##
##   * PLATINUM       = 0   POUNDS      * ELECTRONIC PART= 0   CRATES
##   * GOLD           = 0   POUNDS      * WEAPONS         = 0   CRATES
##   * SILVER         = 0   POUNDS      * FIGHTER PARTS   = 0   CRATES
##   * TITANIUM       = 0   THOUSAND..  * LUXURY FOODS    = 0   CASES
##   * COLLAPSIUM     = 0   TONS        * WINE/LIQUOR     = 0   CASES
##   * STEEL          = 0   TONS        * ART WORKS       = 0   UNITS
##   * FISSIONABLES   = 0   POUNDS      * CREDITS         = 10000
##
##   HIT SPACE BAR TO CONTINUE.                 HIT SPACE BAR TO RETURN
##                                             (1 TO RETURN TO 1ST PAGE)
##
## Like STATUS it paints the view green and lays a white sheet of
## inverse spaces on it, and prints in inverse. Any key turns the first
## page; on the second "1" goes back to the first and any other key
## runs COM again.
##
## What the listing does and a report would not:
##
##  - The loot is kept a byte each, and what is printed is the byte
##    times what a unit of it is: ten pounds of platinum, gold or art,
##    twenty of silver, a hundred cases of wine. The rest are the byte.
##  - Each line is `PRINT name;: HTAB 19: PRINT "= ";number;: HTAB 24:
##    PRINT unit`, and HTAB moves the cursor with no care for what is
##    there. The number has three cells, and the unit is printed over
##    whatever of it is past them: 255 bytes of platinum are 2550 pounds
##    and read "= 255POUNDS", a hundred of wine are 10000 cases and read
##    "= 100CASES". It happens in play: COLLECT.bas lets a byte grow
##    to 255 (line 915), and ten bytes of wine are a thousand cases.
##  - "* ELECTRONIC PARTS" is a letter too long for the same reason, and
##    reads "* ELECTRONIC PART= 0".
##  - The sheet is fifteen rows of thirty-nine spaces from the second
##    column, one more than fits: the last space of each row is the
##    first of the next, and the last row's is the first row's, since
##    the window ends there (POKE 35,15).
##  - It reads MISC FILE as STATUS does, but before its POKE 973,255
##    and with the cursor where COM left it: three NULs on page 2, row
##    11, not inverse.
##  - It leaves with POKE 974,64: its last `PRINT " "` is on page 2,
##    and COM's first line puts the page back.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const CharGenerator = preload("res://scripts/shapes/char_generator.gd")

## Line 20: `FOR Y = 0 TO 123`.
const FILL_ROWS := 124
const GREEN := 1
## Line 1400: `FOR C = 1 TO 15`, and its thirty-nine spaces.
const WIPE_ROWS := 15
const WIPE := "                                       "
## Lines 1410-1440: the name, the byte of the loot (38171 + index), what
## it is multiplied by, and the unit.
const FIRST_PAGE := [
	["* PLATINUM ", 10, 10, "POUNDS"],
	["* GOLD", 12, 10, "POUNDS"],
	["* SILVER ", 11, 20, "POUNDS"],
	["* TITANIUM ", 9, 1, "THOUSAND POUNDS"],
	["* COLLAPSIUM ", 8, 1, "TONS"],
	["* STEEL ", 7, 1, "TONS"],
	["* FISSIONABLES ", 6, 1, "POUNDS"],
]
## Lines 1470-1490, but for the credits.
const SECOND_PAGE := [
	["* ELECTRONIC PARTS", 5, 1, "CRATES"],
	["* WEAPONS ", 4, 1, "CRATES"],
	["* FIGHTER PARTS", 3, 1, "CRATES"],
	["* LUXURY FOODS", 2, 1, "CASES"],
	["* WINE/LIQUOR", 1, 100, "CASES"],
	["* ART WORKS", 0, 10, "UNITS"],
]

var page: HgrScreen
var text: CharGenerator

## The keyboard latch ($C000): bit 7 is the strobe.
var key_latch: int = 0


func _init() -> void:
	page = GameState.view3d.pages[0]
	text = GameState.chargen


## A key press as the Apple's keyboard would latch it.
func press(character: String) -> void:
	key_latch = (character.to_upper().unicode_at(0) & 0x7F) | 0x80


## `GET C$` once a key is down.
func take_key() -> String:
	var character := String.chr(key_latch & 0x7F)
	key_latch &= 0x7F
	return character


## RUN SUPPLY: DOS's carriage return through the character generator.
func ran() -> void:
	text.new_line()


## Lines 5-18.
func open() -> void:
	text.htab(2)
	text.set_window(1, 39, 0, 15) # POKE 32,1: POKE 33,39: POKE 34,0: POKE 35,15
	page.hcolor = GREEN
	text.page = 1 # POKE 974,64


## Line 5000, one of its three INPUTs: the prompt.
func misc_prompt() -> void:
	text.put(0)


## Line 19 after its GOSUB.
func misc_close() -> void:
	text.page = 0


## Line 20, a row of it: `HPLOT 0,Y TO 279,Y`.
func fill_row(y: int) -> void:
	page.hplot(0, y)
	page.hplot_to(279, y)


## Line 1400 up to its FOR.
func wipe_open() -> void:
	text.vtab(1)
	text.mode = 255


## Line 1400, a row of it (`c` 1 to 15).
func wipe_row(c: int) -> void:
	text.htab(2)
	text.vtab(c)
	text.print_line(WIPE)


## Line 1400 after its NEXT.
func title() -> void:
	text.vtab(1)
	text.htab(11)
	text.print_line("- SUPPLY REPORT -")
	text.new_line()


## Lines 1405 and 1465.
func first_row() -> void:
	text.vtab(3)


## One `PRINT name;: HTAB 19: PRINT "= ";number;: HTAB 24: PRINT unit`
## of lines 1410-1490.
func entry(line: Array) -> void:
	text.print_text(line[0])
	text.htab(19)
	text.print_text("= %d" % (int(GameState.loot[line[1]]) * int(line[2])))
	text.htab(24)
	text.print_line(line[3])


## Line 1490's second half.
func credits() -> void:
	text.print_text("* CREDITS")
	text.htab(19)
	text.print_line("= " + CharGenerator.float_text(floorf(GameState.credits)))


## Line 1450 up to the GET.
func first_prompt() -> void:
	text.new_line()
	text.print_text("HIT SPACE BAR TO CONTINUE.")


## Line 1500.
func second_prompt() -> void:
	text.new_line()
	text.htab(9)
	text.print_line("HIT SPACE BAR TO RETURN")
	text.htab(8)
	text.print_text("(1 TO RETURN TO 1ST PAGE)")


## Lines 1515-1516.
func close() -> void:
	text.mode = 0
	text.page = 1


## Line 1520's `PRINT " "`.
func space() -> void:
	text.print_line(" ")
