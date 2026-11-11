extends RefCounted
## STATUS.bas, a statement at a time and with no time in it
## (status_loop.gd has the clock). The central computer's "4) SHIP
## STATUS" runs it. Two pages, a key each:
##
##          -SHIP STATUS REPORT-             -TROOP STATUS-
##
##   LOCATION :SOL                   NO. OF TROOPS    -     2000
##                                   TROOP MORALE     -     EXCELLENT!
##   STARDATE :100.3                 TROOP LOCATION   -     CRYOGENIC SLEEP
##                                   FIGHTERS         -     75
##   ENERGY  :100%   CREDITS  :10000 TRANSPORTS       -     6
##   SHIELDS :100%   CONDITION:RED   TANKS            -     0
##   HULL DMG:0%     MISSILES :60    GROUND MISSILES  -     0
##   COMPUTER:100%   H-DRIVE  :100%
##   RADAR   :100%   ENV.     :100%
##   LASER   :100%   NAV.COMP.:100%
##   ENGINE#1:100%   ENGINE#2 :100%
##
## It draws on hi-res page 1 with the game's character generator: the
## view is painted green a row at a time, then fifteen rows of inverse
## spaces make a white sheet on it (one cell in from the left, which
## leaves a green edge, and four dots short of the bottom), and the
## report is printed on that in inverse, black on white. The flight
## panel below stays. Then COM is run again, from its top.
##
## What the listing does and a report would not:
##
##  - The energy is a percentage of 62, and a full ship has 63: `INT
##    (63 / 62 * 100)` is 101, and line 1256 makes 100 of it.
##  - "HULL DMG" is 100 less the hull's byte, which counts the hull that
##    is left: a whole ship reads 0%. Every other system reads its byte.
##  - ENV. and NAV.COMP. are the number 100, whatever their bytes hold.
##  - "MISSILES" is 38187, the byte COM's " MSL " lamp goes by.
##  - The words for the condition, the morale and the troops' place
##    each end their line. A byte with no word (a condition 0, a morale
##    0 or 7, a place 4) leaves the cursor where it is and the next line
##    carries on from there, round the edge of the sheet. Morale 0 is
##    reachable: H_D.bas takes a point off troops that fought and were
##    not paid, down to 0.
##  - Line 1386 prints THE TROOPS ARE ALL DEAD! when two bytes are both
##    0: 38159 and 38167. Neither is a count of troops (that is TR, in
##    MISC FILE). 38167 is the lamp the flight program last had TRANLIT
##    flip, and nothing in the game writes 38159, which SHIP'S DATA-M
##    loads as 20. So the line cannot print. With both bytes poked to 0
##    on the live machine it does, on the row under the last.
##  - STARDATE, the troops and the credits are read from MISC FILE on
##    the way in, with page 2 as the place to print. Each INPUT's prompt
##    is a NUL, which the character generator draws: three dots in the
##    corner of the flight program's other view.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const CharGenerator = preload("res://scripts/shapes/char_generator.gd")

## Line 20: `FOR Y = 0 TO 123`.
const FILL_ROWS := 124
const GREEN := 1
## Line 1230: `FOR C = 1 TO 15`, and its thirty-eight spaces.
const WIPE_ROWS := 15
const WIPE := "                                      "
## Line 10000's DATA.
const STARS := [
	"SOL", "ALPHA CENTAURI", "BARNARD'S STAR", "WOLF 359", "LUYTEN",
	"LALANDE 21185", "SIRIUS", "VARCAR", "XANADON", "EPSILON ERIDANA",
	"CYGNI", "PROCYON", "TAU CETI", "LACAILLE 9352", "LARSEN-C",
	"GROOMBRIDGE 1618", "KRUGER 60", "EPSILON INDI", "ARGO", "SHIVANDA",
]
## Lines 1290-1294, 1350-1360 and 1380-1384.
const CONDITIONS := {1: "GREEN", 2: "BLUE", 3: "RED"}
const MORALES := {1: "AWFUL!!!", 2: "POOR", 3: "SO-SO", 4: "FAIR", 5: "GOOD", 6: "EXCELLENT!"}
const PLACES := {3: "CRYOGENIC SLEEP", 0: "ON BOARD", 1: "PLANETSIDE", 2: "SHORE LEAVE"}

var page: HgrScreen
var text: CharGenerator

## The keyboard latch ($C000): bit 7 is the strobe.
var key_latch: int = 0
## The two bytes line 1386 reads. 38159 is SHIP'S DATA-M's, and 38167
## the last lamp flipped: nothing here keeps that one, and with 38159
## never 0 it does not matter which it was.
var byte_38159: int = 20
var byte_38167: int = 3


func _init() -> void:
	page = GameState.view3d.pages[0]
	text = GameState.chargen


## A key press as the Apple's keyboard would latch it.
func press(character: String) -> void:
	key_latch = (character.to_upper().unicode_at(0) & 0x7F) | 0x80


## `GET I$` once a key is down.
func take_key() -> String:
	var character := String.chr(key_latch & 0x7F)
	key_latch &= 0x7F
	return character


## RUN STATUS: DOS's carriage return through the character generator.
func ran() -> void:
	text.new_line()


## Lines 10-15.
func open() -> void:
	text.vtab(1)
	text.htab(2)
	text.window_left = 1 # POKE 32,1
	text.window_width = 39 # POKE 33,39
	page.hcolor = GREEN


## Line 20, a row of it: `HPLOT 0,Y TO 279,Y`.
func fill_row(y: int) -> void:
	page.hplot(0, y)
	page.hplot_to(279, y)


## Lines 30-40: inverse from here on, and page 2 for the file's prompts.
func misc_open() -> void:
	text.mode = 255
	text.page = 1


## Line 5000, one of its three INPUTs: the prompt.
func misc_prompt() -> void:
	text.put(0)


## Line 60.
func misc_close() -> void:
	text.page = 0


## Line 1230, a row of it (`c` 1 to 15).
func wipe_row(c: int) -> void:
	text.vtab(c)
	text.htab(2)
	text.print_line(WIPE)


## Line 1230 after its NEXT.
func wipe_end() -> void:
	text.vtab(1)
	text.htab(2)


# -- the ship, lines 1235-1310 ---------------------------------------------


## Lines 1235-1240. The FOR that reads the star's name goes round once
## even for a 0.
func title() -> void:
	text.htab(9)
	text.print_line("-SHIP STATUS REPORT-")
	text.new_line()


## Line 1250.
func place() -> void:
	text.print_line("LOCATION :" + STARS[clampi(GameState.current_planet, 0, STARS.size() - 1)])
	text.new_line()
	text.print_line("STARDATE :" + CharGenerator.float_text(GameState.stardate))
	text.new_line()


## Line 1255's sum: the energy as a percentage of 62.
func energy_percent() -> int:
	return int(floor(int(GameState.ship_energy) / 62.0 * 100.0))


## Line 1256's IF.
func energy_capped() -> bool:
	return energy_percent() > 100


## Lines 1256-1260.
func energy() -> void:
	text.print_text("ENERGY  :%d%%" % mini(energy_percent(), 100))
	_tab(22)
	text.print_line("CREDITS  :" + CharGenerator.float_text(floorf(GameState.credits)))


## Lines 1270-1294.
func shields() -> void:
	text.print_text("SHIELDS :%d%%" % int(GameState.ship_shield))
	_tab(22)
	text.print_text("CONDITION:")
	_word(CONDITIONS, int(GameState.condition))


## Line 1300.
func hull() -> void:
	text.print_text("HULL DMG:%d%%" % (100 - int(GameState.ship_hull)))
	_tab(22)
	text.print_line("MISSILES :%d" % int(GameState.ship_missile_system))


## Line 5100.
func computer() -> void:
	text.print_text("COMPUTER:%d%%" % int(GameState.ship_computer))
	text.htab(22)
	text.print_line("H-DRIVE  :%d%%" % int(GameState.ship_hyperdrive))


## Line 5110.
func radar() -> void:
	text.print_text("RADAR   :%d%%" % int(GameState.ship_radar))
	text.htab(22)
	text.print_line("ENV.     :100%")


## Line 5120.
func laser() -> void:
	text.print_text("LASER   :%d%%" % int(GameState.ship_laser))
	text.htab(22)
	text.print_line("NAV.COMP.:100%")


## Line 1310.
func engines() -> void:
	text.print_text("ENGINE#1:%d%%" % int(GameState.ship_engine1))
	_tab(22)
	text.print_line("ENGINE#2 :%d%%" % int(GameState.ship_engine2))


# -- the troops, lines 1320-1386 -------------------------------------------


## Line 1320.
func troops_title() -> void:
	text.new_line()
	_tab(12)
	text.print_line("-TROOP STATUS-")
	text.new_line()


## Line 1330.
func troops() -> void:
	_entry("NO. OF TROOPS")
	text.print_line(CharGenerator.float_text(GameState.troops))


## Lines 1340-1360.
func morale() -> void:
	_entry("TROOP MORALE")
	_word(MORALES, int(GameState.troop_morale))


## Lines 1370-1384.
func troops_place() -> void:
	_entry("TROOP LOCATION")
	_word(PLACES, int(GameState.troop_location))


## Line 5200.
func fighters() -> void:
	_count("FIGHTERS", GameState.gf_fighters)
	_count("TRANSPORTS", GameState.gf_transports)


## Line 5210.
func tanks() -> void:
	_count("TANKS", GameState.gf_tanks)
	_count("GROUND MISSILES", GameState.gf_missiles)


## Line 1386. True if it printed.
func all_dead() -> bool:
	if byte_38167 * 256 + byte_38159 != 0:
		return false
	text.print_text("THE TROOPS ARE ALL DEAD!")
	return true


## Lines 1395-1396.
func close() -> void:
	text.print_line(" ")
	text.mode = 0


## `PRINT name; TAB( 18);"-"; TAB( 24);`
func _entry(name_: String) -> void:
	text.print_text(name_)
	_tab(18)
	text.print_text("-")
	_tab(24)


## `PRINT name;: HTAB 18: PRINT "-";: HTAB 24: PRINT PEEK (byte)`
func _count(name_: String, byte: float) -> void:
	text.print_text(name_)
	text.htab(18)
	text.print_text("-")
	text.htab(24)
	text.print_line(str(int(byte)))


## One of the `IF C = n THEN PRINT word` runs: the word and the end of
## the line, or for a value with no word nothing at all.
func _word(words: Dictionary, value: int) -> void:
	if words.has(value):
		text.print_line(words[value])


## `PRINT TAB( n);`: spaces up to column n.
func _tab(n: int) -> void:
	while text.column < n - 1:
		text.put(32)
