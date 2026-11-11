extends RefCounted
## COM.bas, the command console, a statement at a time and with no time
## in it (com_loop.gd has the clock and the GOTOs). It draws on hi-res
## page 1 with the game's own character generator, as the original does,
## over whatever the last program left there, and leaves the page, the
## cursor and the text window for the next.
##
## The screen: the top of the flight panel stays, the view above it is
## painted blue (orange for the directory), a box on the left holds the
## menu in hand, and on the right twelve labels show the ship's systems,
## inverse for one that is out.
##
## Things in the original that look like slips and are kept:
##
##  - Line 20 prints fourteen single spaces down the left edge "to clear
##    it". Coming from the star chart they land in the four-row window
##    the chart left at the bottom of the screen instead, and wipe the
##    first column of the panel's lower half.
##  - A wrong key at the command menu draws the menu again without line
##    80, so the text window is left 39 wide instead of 21. Nothing in
##    the menu is long enough to show it.
##  - "2) RETURN" in the galaxy directory is `R = 2: GOSUB 20: GOTO 810`,
##    meant to come back to the navigation computer. Line 35 only
##    returns for R = 1, so it falls into the command menu instead, from
##    wherever the directory was asked for.
##  - The two-digit entries (a course, a star system) take RETURN as one
##    of the two characters and print it: "7" and RETURN is 7, RETURN
##    first makes the number 0.
##  - The last label, " COM ", reads 38185. Nothing in the game writes
##    that byte and a new game has 1 there, so it is never out.
##  - "POWER LOW" goes inverse under 16; every other label only at 0.
##  - "2) GROUND FORCES" prints its space on page 2, where the flight
##    program's other view is.
##  - "5) RETURN" wipes text rows 1 to 16, which is dots 0 to 127: the
##    top two rows of the flight panel go with it and stay gone, since
##    INSTRUMENTS is not run again on the way back.
##
## Lines that are never reached: 115 (98 has caught it), 140 (and the
## line 30 it and line 270 point at does not exist), 600, 873, 897,
## 1175, 3010.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const CharGenerator = preload("res://scripts/shapes/char_generator.gd")
const FlightProgram = preload("res://scripts/flight/flight_program.gd")
const ComRules = preload("res://scripts/rules/com_rules.gd")

const STARS := 20
const BLUE := 6
const ORANGE := 5
## The rows lines 20 and 910 paint, 0 to 123.
const FILL_ROWS := 124
## Lines 15000-15030, two to a system, in the order of ST() (line 15140).
const LABELS := [
	"  1  ", " ENG ", "  2  ", " ENG ", " COMP", "NO/GO",
	"RADAR", "NO/GO", " ENV ", "NO/GO", " HULL", " DMG ",
	"POWER", " LOW ", " SHLD", "NO/GO", "HYPER", "DRIVE",
	" MSL ", "NO/GO", "LASER", "NO/GO", " COM ", "NO/GO",
]
const SYSTEMS := 12
const POWER := 7 # J1 of line 10000
const WRONG_KEY := ["", "PLEASE ENTER YOUR", "COMMAND AGAIN."]
const COURSE_ERROR := ["<ERROR>"]
const COURSE_HERE := ["THAT'S WHERE WE", "ARE NOW, SIR!"]
const WHICH_ERROR := ["TRY AGAIN PLEASE."]

## The flight program has the shape table and the pages.
var flight: FlightProgram
var page: HgrScreen
var text: CharGenerator
var shapes: ShapeTable

## The keyboard latch ($C000): bit 7 is the strobe.
var key_latch: int = 0
## BASIC's V() and H(), 1-based.
var v: Array[int] = []
var h: Array[int] = []
## The two-digit entry: C1$, J, and where on the screen it is.
var c1: String = ""
var j: int = 1
var _entry_row: int = 0
var _entry_column: int = 0
var _entry_row_at_get := false


func _init() -> void:
	flight = FlightProgram.new()
	page = flight.page_1
	text = flight.text
	shapes = flight.shapes


## A key press as the Apple's keyboard would latch it.
func press(character: String) -> void:
	key_latch = (character.to_upper().unicode_at(0) & 0x7F) | 0x80


## `GET C$` once a key is down.
func take_key() -> String:
	var character := String.chr(key_latch & 0x7F)
	key_latch &= 0x7F
	return character


## VAL of what the program gives it: a key, or the digits typed with
## perhaps a RETURN among them. Spaces are skipped; anything else that is
## not a digit ends the number.
static func val(typed: String) -> int:
	var digits := ""
	for character in typed:
		if character == " ":
			continue
		if character < "0" or character > "9":
			break
		digits += character
	return int(digits) if digits != "" else 0


## S$(), lines 15100-15130: the same names as the chart's.
static func star_name(star: int) -> String:
	return ComRules.NAMES[star - 1]


## PEEK(ST(J1)), line 15140.
static func system(j1: int) -> int:
	match j1:
		1: return int(GameState.ship_engine1) # 38198
		2: return int(GameState.ship_engine2) # 38197
		3: return int(GameState.ship_computer) # 38196
		4: return int(GameState.ship_radar) # 38195
		5: return int(GameState.ship_env_control) # 38194
		6: return int(GameState.ship_hull) # 38193
		7: return int(GameState.ship_energy) # 38199
		8: return int(GameState.ship_shield) # 38200
		9: return int(GameState.ship_hyperdrive) # 38190
		10: return int(GameState.ship_missile_system) # 38187
		11: return int(GameState.ship_laser) # 38186
	return 1 # 38185, which nothing writes


## RUN <program>: DOS's carriage return through the character generator.
func ran() -> void:
	text.new_line()


## A bare `PRINT`.
func blank() -> void:
	text.new_line()


## `PRINT " "`, which every way out to another program starts with.
func space() -> void:
	text.print_line(" ")


func home() -> void:
	text.home()


# -- lines 8-80: the console ---------------------------------------------


## Line 8: the speed and energy markers painted out, wherever they would
## be. Over anything but the flight panel it only cuts notches in
## whatever is on row 133.
func open() -> void:
	text.page = 0 # POKE 974,32
	text.mode = 0 # POKE 973,0
	flight.view.shown = 0 # POKE -16300,0
	page.hcolor = 0
	for x in range(200, 261, 5):
		page.draw(shapes, 25, x, 133)
	for x in range(13, 74, 5):
		page.draw(shapes, 25, x, 133)


## Lines 20 and 910: `HPLOT 0,Y TO 279,Y`.
func fill_row(color: int, y: int) -> void:
	page.hcolor = color
	page.hplot(0, y)
	page.hplot_to(279, y)


## The rest of line 20.
func fill_end() -> void:
	text.window_left = 0
	text.home()
	for i in range(14):
		text.print_line(" ")


## Lines 21 and 25, the same line twice.
func full_window() -> void:
	text.set_window(0, 40, 0, 23)
	text.new_line()


## Line 29 in its fourteen PRINTs (`row` 0 to 13): the left half of the
## screen's top fourteen rows.
func clear_row(row: int) -> void:
	if row == 0:
		text.home()
		text.print_line(" ".repeat(20))
		text.home()
		text.vtab(2)
	elif row < 13:
		text.print_line(" ".repeat(20))
	else:
		text.print_text(" ".repeat(20))
		text.home()
		text.window_left = 1


## Lines 40-50.
func grid_open() -> void:
	v = [0]
	h = [0]
	for row in [2, 5, 8, 11]:
		for column in [23, 29, 35]:
			v.append(row)
			h.append(column)


## Lines 60-70 for one label (`index` 0 to 23), with the GOSUB 10000
## that picks plain or inverse.
func label(index: int) -> void:
	var j1 := index / 2 + 1
	var t := system(j1)
	if j1 == POWER and t < 16: # 10000
		text.mode = 255
	elif t == 0: # 10005
		text.mode = 255
	else:
		text.mode = 0
	text.vtab(v[j1])
	text.htab(h[j1])
	text.print_line(LABELS[index])
	v[j1] += 1


## Lines 72-80.
func title() -> void:
	text.mode = 0
	text.vtab(15)
	text.htab(1)
	text.print_text("  COMPUTER DISPLAY      DAMAGE CONTROL  ")
	text.window_width = 21
	text.window_left = 1
	text.window_bottom = 14
	text.home()


# -- lines 90-135: the command menu --------------------------------------


## Line 90.
func box() -> void:
	page.hcolor = 1
	page.hplot_path([1, 1, 139, 1, 139, 110, 1, 110, 1, 1])


## Line 98's test: COLLECT and GROUND FORCES run COM with a 7 in 38151
## to have the console drawn and come straight back.
func ground_forces_due() -> bool:
	if not GameState.ground_forces_due:
		return false
	GameState.ground_forces_due = false
	text.page = 1 # POKE 974,64
	return true


## Line 100.
func menu_title() -> void:
	_tab(3)
	text.print_line("COMMAND MODE")
	text.new_line()


## Line 110.
func menu_lines() -> void:
	for line: String in ["1) COMPUTER", "2) GROUND FORCES", "3) RADAR", "4) END", "5) RETURN"]:
		text.print_line(line)
	text.new_line()


## Line 120 up to its GET.
func menu_prompt() -> void:
	text.print_text("COMMAND?")


## Lines 121-127: `POKE 974,64`, and for "2" the space.
func command_taken(command: int) -> void:
	text.page = 1
	if command == 2:
		space()


## Lines 128-129 up to the IF.
func command_window() -> void:
	text.page = 0
	text.set_window(0, 40, 0, 24)
	space()


## Line 129 for "5", a row of it (`row` 1 to 16). The lo-res screen it
## fills afterwards is behind the hi-res one.
func wipe_row(row: int) -> void:
	text.vtab(row)
	text.htab(1)
	text.print_line(" ".repeat(40))


## Lines 130-133, as far as the program run: `VTAB 1`, the page poke,
## and RADAR's 2 in 38388.
func command_leave(command: int) -> void:
	text.vtab(1)
	text.page = 1
	if command == 3:
		GameState.handover = 2


## Line 135.
func command_computer() -> void:
	text.page = 0


# -- lines 200-280: the central computer ---------------------------------


## Line 210.
func central_title() -> void:
	_tab(1)
	text.print_line("CENTRAL COMPUTER")
	text.new_line()


## Line 215.
func computer_out() -> bool:
	return system(3) == 0


func computer_out_message() -> void:
	text.print_line("COMPUTER NOT")
	text.print_line("FUNCTIONING.")


## Line 220.
func central_lines() -> void:
	for line: String in ["1) NAVIGATION COMP.", "2) GALAXY DIRECTORY", "3) GALAXY MAP",
			"4) SHIP STATUS", "5) SUPPLIES REPORT", "6) RETURN"]:
		text.print_line(line)
	text.new_line()


## Lines 260, 830, 950 and 1170 up to the GET.
func ready() -> void:
	text.print_text("READY ")


# -- lines 800-897: the navigation computer ------------------------------


## Line 810.
func navigation_lines() -> void:
	text.print_line("NAVIGATION COMPUTER")
	text.new_line()
	text.new_line()
	for line: String in ["1) DIRECTORY", "2) SET COURSE", "3) RETURN"]:
		text.print_line(line)
	text.new_line()


## Line 860 after its GOSUB.
func course_title() -> void:
	text.print_line("NAVIGATION COMPUTER")
	text.new_line()
	text.new_line()


## Line 870 up to its FOR.
func course_prompt() -> void:
	text.print_line("ENTER DESIRED")
	text.print_text("DESTINATION ")
	text.vtab(6)
	_entry_open(6, 1, false)


## Line 879.
func course_is_here(c: int) -> bool:
	return c == GameState.current_planet + 1


## Lines 880-890 up to the FOR.
func course_set(c: int) -> void:
	GameState.target_planet = c - 1 # POKE 38163,C
	text.print_line(star_name(c))
	text.print_line("COURSE SET.")


# -- the two-digit entry, lines 871-876 and 971-976 ----------------------


func _entry_open(row: int, column: int, row_at_get: bool) -> void:
	c1 = ""
	j = 1
	_entry_row = row
	_entry_column = column
	_entry_row_at_get = row_at_get


## Lines 871 and 971 up to the GET.
func entry_cursor() -> void:
	text.htab(_entry_column + j)
	if _entry_row_at_get:
		text.vtab(_entry_row)


## The rest of lines 871-876 for one key. True when the FOR is through
## and `entry_value()` is the number.
func entry_key(key: String) -> bool:
	var code := key.unicode_at(0)
	if code == 8:
		j = maxi(j - 1, 1)
		text.vtab(_entry_row) # 872
		text.htab(_entry_column + j)
		text.put(0x20)
		if c1.length() == 1:
			c1 = ""
		text.vtab(_entry_row)
		return false
	if code != 13 and (code < 48 or code > 57): # 874-875
		text.vtab(_entry_row)
		return false
	text.vtab(_entry_row) # 876
	text.htab(_entry_column + j)
	text.put(code)
	c1 += key
	j += 1
	return j > 2


func entry_value() -> int:
	var c := val(c1)
	c1 = ""
	return c


# -- lines 900-978: the galaxy directory ---------------------------------


## Line 900.
func directory_open() -> void:
	text.home()
	text.set_window(0, 40, 0, 15)
	text.home()


## Lines 910 (after the rows) to 920.
func directory_title() -> void:
	text.mode = 255
	text.vtab(1)
	text.htab(10)
	text.print_line("** GALAXY DIRECTORY **")
	text.new_line()


## Line 930, one of its thirteen rows; `last` for the VTAB after them.
func directory_clear_row(last: bool) -> void:
	text.htab(2)
	text.print_line(" ".repeat(38))
	if last:
		text.vtab(3)


## Line 940: ten rows of two stars (`row` 0 to 9), then the two choices
## (10 and 11).
func directory_row(row: int) -> void:
	match row:
		10:
			text.htab(7)
			text.print_line("1) DISPLAY PLANETARY DATA")
		11:
			text.htab(7)
			text.print_line("2) RETURN                ")
		_:
			var c := row + 1
			text.htab(2)
			text.print_text("%d)%s" % [c, star_name(c)])
			text.htab(21)
			text.print_line("%d)%s" % [c + 10, star_name(c + 10)])


## Line 950 up to its GET.
func directory_prompt() -> void:
	text.htab(10)
	ready()


## Line 960.
func directory_chosen() -> void:
	text.mode = 0


## Line 970 up to its FOR.
func which_prompt() -> void:
	text.mode = 255
	text.vtab(15)
	text.htab(10)
	text.print_text("WHICH SYSTEM ")
	_entry_open(15, 24, true)


## Line 977.
func which_done() -> void:
	text.vtab(15)
	text.htab(10)


## Line 978 after its message and wait.
func which_clear() -> void:
	text.vtab(15)
	text.htab(10)
	text.print_line(" ".repeat(20))


# -- lines 979-1172: a star system's page --------------------------------


## Line 12: the star the chart asked about, or 0.
func chart_star() -> int:
	return GameState.handover


## Line 979.
func page_window() -> void:
	text.window_left = 1
	text.window_width = 39


## Line 980, a row of it (`row` 2 to 15).
func page_clear_row(row: int) -> void:
	text.vtab(row)
	text.htab(2)
	text.print_line(" ".repeat(38))


## Line 990.
func page_title(c: int) -> void:
	text.htab(2)
	text.vtab(2)
	_tab(5)
	text.print_line(star_name(c) + " STAR SYSTEM")
	text.new_line()


## Lines 1005-1160 as the PRINTs they come to, in order; "" is a bare
## PRINT.
func page_lines(c: int) -> Array[String]:
	var star := c - 1
	if not GameState.planet_scouted[star]: # 1005
		return ["NO INFORMATION AVAILABLE AT THIS TIME.", ""]
	var name_ := star_name(c)
	var tech: int = GameState.planet_tech[star]
	var lines: Array[String] = ["TECHNOLOGICAL DEVELOPMENT:"] # 1010
	match tech: # 1030-1070
		0:
			lines.append("NO INTELLIGENT LIFEFORMS INDICATED.")
		1:
			lines.append("PRIMITIVE PSEUDO SOCIETY ONLY.")
		2:
			lines.append("LIMITED ATOMIC DEVELOPMENT")
		3:
			lines.append("SOPHISTICATED TECHNOLOGY WITH")
			lines.append("STARSHIP CAPABILITY.")
		4:
			lines.append("ADVANCED CAPABILITY-SUPERIOR TO  OURS!")
	lines.append("") # 1080
	if tech >= 2: # 1090
		lines.append("ORBITING DEFENSE CAPABILITY --")
		lines.append("FIGHTER PROTECTION PROBABLE.")
	lines.append("POPULATION = APPROX. %d" % (GameState.planet_population_scale[star] * 35294)) # 1110
	if GameState.planet_secured[star] != 0: # 1120-1140
		lines.append(name_ + " HAS BEEN SECURED")
	else:
		lines.append(name_ + " IS INDEPENDENT.")
	lines.append("") # 1150
	if GameState.planet_has_base[star]: # 1160
		lines.append("THERE IS AN OPERATIONAL REPAIR BASE")
		lines.append("ON THE PLANET.")
	return lines


## One of them.
func page_line(line: String) -> void:
	text.print_line(line)


## Line 1170 up to its GET.
func page_prompt() -> void:
	text.vtab(15)
	ready()


## Line 1172. True when the chart asked for the page and is to be run
## again.
func page_close() -> bool:
	text.mode = 0
	if GameState.handover == 0:
		return false
	GameState.handover = 0
	space()
	return true


## `PRINT TAB(n);`: spaces through the output hook up to column n.
func _tab(n: int) -> void:
	while text.column < n - 1:
		text.put(0x20)
