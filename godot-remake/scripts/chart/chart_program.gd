extends RefCounted
## GALAXY MAP.bas, the star chart, a statement at a time and with no time
## in it (chart_loop.gd has the clock). It draws on hi-res page 1 with the
## game's own character generator, as the original does, so what is on
## the page afterwards is what the next program finds there.
##
## The chart is a picture and a question, nothing more: the twenty stars
## by their X and Y, a different mark for near, middle and far Z, violet
## for a secured one, a box round the star the ship is at. The paddles
## move a cross, the button asks about the star under it (its name, its
## position, the distance from here) and offers the directory page. It
## does not set a course: that is the navigation computer's job.
##
## Things in the original that look like slips and are kept:
##
##  - The cross is taken off with a black DRAW (line 3210), which takes
##    the star under it off as well until the chart is drawn again.
##  - Star 16 is "GROOMBRIDGE 168" here and in COM.bas, "GROOMBRIDGE
##    1618" in STATUS.bas and COLLECT.bas.
##  - "Y" at the question pokes 8 into 38149, the byte SHORE LEAVE keeps
##    its once-a-trip flag in.
##  - Any key leaves, not only the space the screen asks for.
##  - The way out is `RUN INSTRUMENTS`, which sees the chart's flag and
##    comes straight back without calling TRANLIT; line 1 here then
##    paints the eight lamps itself as plain HPLOT blocks (lines
##    5000-5500), not TRANLIT's lamp pictures, and no switch is flipped.
##    They stay like that until a lamp key is pressed in flight.
##
## The directory page that "Y" leads to is COM.bas's (lines 8, 12 and
## 978-1172). It is here until COM itself is on the hi-res page.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const CharGenerator = preload("res://scripts/shapes/char_generator.gd")
const FlightProgram = preload("res://scripts/flight/flight_program.gd")

const STARS := 20
## What line 3220's FOR leaves in P when no star was under the cross.
const NO_STAR := STARS + 1
## Shapes of `ENEMY I`: the cross, and the three star marks by depth.
const SHAPE_CROSS := 12
const SHAPE_NEAR := 6 # Z under 12
const SHAPE_MIDDLE := 5 # Z 12 to 15
const SHAPE_FAR := 1 # Z over 15
## Applesoft's 1.19 is a little under 1.19, and its `PDL(0) * 1.19` comes
## out a hair under the whole number where there is one (118.99999997
## for 100). XDRAW cuts PX down, so these two paddle readings put the
## cross one dot further left than exact arithmetic would. Read off a
## real Applesoft: tools/mame/chart_float_live.lua, whose record
## (analysis/live/chart/chart_float_live.txt) also has all 400 distances
## of lines 3300-3320, and those come out as exact arithmetic has them.
const PX_ONE_LESS: Array[int] = [100, 200]

const NO_STAR_MESSAGE := "THERE IS NO STAR SYSTEM THERE, SIR."
const QUESTION := "DO YOU WISH FURTHER INFORMATION?"

## INSTRUMENTS.bas is in the flight program.
var flight: FlightProgram
var page: HgrScreen
var text: CharGenerator
var shapes: ShapeTable

## BASIC's PX, PY and P.
var px: float = 0.0
var py: float = 0.0
var p: int = NO_STAR
## The keyboard latch ($C000): bit 7 is the strobe.
var key_latch: int = 0


func _init() -> void:
	flight = FlightProgram.new()
	page = flight.page_1
	text = flight.text
	shapes = flight.shapes


## A key press as the Apple's keyboard would latch it.
func press(character: String) -> void:
	key_latch = (character.to_upper().unicode_at(0) & 0x7F) | 0x80


## `GET A$` once a key is down.
func take_key() -> String:
	var character := String.chr(key_latch & 0x7F)
	key_latch &= 0x7F
	return character


## S$(P), lines 15100-15130.
static func star_name(star: int) -> String:
	if star == 16:
		return "GROOMBRIDGE 168"
	return GameState.STAR_NAMES[star - 1]


static func star_x(star: int) -> int:
	return GameState.PLANET_X[star - 1]


static func star_y(star: int) -> int:
	return GameState.PLANET_Y[star - 1]


static func star_z(star: int) -> int:
	return GameState.PLANET_Z[star - 1]


## RUN <program>: DOS's carriage return through the character generator.
func ran() -> void:
	text.new_line()


# -- lines 5 and 3000-3100: the chart ------------------------------------


## Line 5.
func open() -> void:
	text.page = 0 # POKE 974,32
	flight.view.shown = 0 # POKE -16300,0


## Lines 3000-3002: a text window of four rows under the chart, and a
## form feed, which clears the whole page.
func clear() -> void:
	text.set_window(0, 39, 19, 23)
	text.put(0x0C)
	text.new_line()
	text.htab(1)
	text.vtab(20)
	text.window_left = 1


## Line 3010, `HPLOT 1,1 TO 1,190 TO 279,190 TO 279,1 TO 1,1`, a side
## at a time (0 to 3).
const BORDER := [[1, 1], [1, 190], [279, 190], [279, 1], [1, 1]]


func border_side(side: int) -> void:
	page.hcolor = 1
	if side == 0:
		page.hplot(BORDER[0][0], BORDER[0][1])
	page.hplot_to(BORDER[side + 1][0], BORDER[side + 1][1])


## Lines 3025-3080 for one star (1-based). SCALE is whatever the last
## program left: line 3096 sets it after the stars, not before.
func star(star: int) -> void:
	page.hcolor = 3
	var z := star_z(star)
	var mark := SHAPE_FAR
	if z < 12:
		mark = SHAPE_NEAR
	elif z < 16:
		mark = SHAPE_MIDDLE
	var x := star_x(star) * 10 - 35
	var y := star_y(star) * 5
	if GameState.planet_secured[star - 1] == 1: # 3066
		page.hcolor = 2
	page.draw(shapes, mark, x, y)
	if star == GameState.current_planet + 1:
		page.hcolor = 2
		page.hplot_path([x - 5, y + 5, x + 5, y + 5, x + 5, y - 5, x - 5, y - 5, x - 5, y + 5])


## Line 3090.
func rule() -> void:
	page.hcolor = 5
	page.hplot_path([1, 150, 279, 150])


## Lines 3096-3100.
func caption() -> void:
	page.shape_scale = 1
	text.htab(15)
	text.print_line("GALAXY MAP")
	text.htab(8)
	text.print_line("--PRESS SPACE TO RETURN--")


# -- lines 3110-3200: the cross ------------------------------------------


## `PX = PDL(0) * 1.19`
func read_paddle_x(paddle: int) -> void:
	px = paddle * 1.19
	if PX_ONE_LESS.has(paddle):
		px -= 0.0000001


## The rest of lines 3110-3117.
func read_paddle_y(paddle: int) -> void:
	py = paddle
	if py > 145:
		py = 145
	if px < 10:
		px = 10
	if px > 270:
		px = 270
	if py < 10:
		py = 10


## Lines 3120 and 3200: `XDRAW 12 AT PX,PY`, on and off again.
func cross() -> void:
	page.xdraw(shapes, SHAPE_CROSS, int(px), int(py))


## Line 3125's test, and what it does before `RUN INSTRUMENTS`.
func key_down() -> bool:
	if key_latch < 128:
		return false
	key_latch &= 0x7F # POKE -16368,0
	return true # POKE 38391,77: POKE 38388,7


# -- lines 3210-3320: the button -----------------------------------------


## Line 3210. Black, not XDRAW: whatever was under the cross goes too.
func cross_off() -> void:
	page.hcolor = 0
	page.draw(shapes, SHAPE_CROSS, int(px), int(py))


## Lines 3215-3240's search: the first star whose cell the cross is in,
## or NO_STAR. A star's cell is three columns of ten dots wide and two
## rows of five high.
func find() -> int:
	px += 35
	var column := int(px / 10)
	var row := int(py / 5)
	p = NO_STAR
	for star in range(1, STARS + 1):
		if column <= star_x(star) + 1 and column >= star_x(star) - 1 \
				and row <= star_y(star) and row >= star_y(star) - 1:
			p = star
			break
	return p


## The rest of line 3240, after the message and its wait.
func no_star_clear() -> void:
	text.vtab(22)
	text.print_line(" ".repeat(38))
	text.vtab(22)


## Line 3250 in its three PRINTs.
func found_clear() -> void:
	text.vtab(21)
	text.print_line(" ".repeat(39))
	text.vtab(21)


func found_name() -> void:
	text.print_line("STAR SYSTEM : " + star_name(p))


func found_place() -> void:
	text.print_text("LOC. : %d %d %d" % [star_x(p), star_y(p), star_z(p)])


## Lines 3300-3310: INT(D1), light-years from the star the ship is at.
func distance() -> int:
	var here := GameState.current_planet + 1
	var x1 := absi(star_x(here) - star_x(p))
	var x2 := absi(star_y(here) - star_y(p))
	var x3 := absi(star_z(here) - star_z(p))
	return int(sqrt(float(x1 * x1 + x2 * x2 + x3 * x3)))


## Line 3320.
func found_distance() -> void:
	text.print_line(" : DISTANCE = %d L/Y" % distance())


## Line 3260 up to its GET.
func question() -> void:
	text.print_text(QUESTION)


## Line 3260 after a "Y": `POKE 38388,P: POKE 38149,8: PRINT " "`. The
## 8 goes into the byte that is SHORE LEAVE's once-a-trip flag when it
## holds a 1.
func further() -> void:
	GameState.base_built_this_trip = false
	text.print_line(" ")


## Line 3270, any other key; line 3000 follows.
func question_clear() -> void:
	text.vtab(21)
	text.print_line(" ".repeat(115))


# -- lines 1 and 5000-5500: back from INSTRUMENTS ------------------------


## GOSUB 5000 as the blocks it paints, in order: [HCOLOR, LX, LY].
func lamp_blocks() -> Array:
	var blocks: Array = []
	blocks.append([1 if GameState.shields_up else 3, 262, 161]) # 5000-5020
	if not GameState.missile_mode_active: # 5030
		blocks.append([3, 7, 161])
		blocks.append([1, 72, 161])
	else: # 5040
		blocks.append([3, 72, 161])
		blocks.append([1, 7, 161])
	match GameState.condition: # 5050-5080
		1:
			blocks.append([1, 200, 161])
		2:
			blocks.append([6, 200, 161])
			blocks.append([6, 200, 161])
		3:
			blocks.append([5, 200, 161])
	if not GameState.autopilot_active: # 5090
		blocks.append([3, 72, 153])
		blocks.append([1, 7, 153])
	else: # 5100
		blocks.append([3, 7, 153])
		blocks.append([1, 72, 153])
	blocks.append([3 if GameState.in_atmosphere else 1, 200, 153]) # 5110-5130
	blocks.append([5 if GameState.damage_alert_active else 1, 262, 153]) # 5140-5160
	return blocks


## Line 5500.
func lamp_block(block: Array) -> void:
	page.hcolor = block[0]
	var lx: int = block[1]
	var ly: int = block[2]
	for j in range(ly, ly + 5):
		page.hplot_path([lx, j, lx + 9, j])


# -- COM.bas lines 8, 12 and 978-1172: the directory page ----------------


## COM.bas line 8: the speed and energy markers painted out, wherever
## they would be. Over the chart it only cuts notches in whatever is on
## row 133.
func com_open() -> void:
	text.page = 0
	text.mode = 0
	flight.view.shown = 0
	page.hcolor = 0
	for x in range(200, 261, 5):
		page.draw(shapes, 25, x, 133)
	for x in range(13, 74, 5):
		page.draw(shapes, 25, x, 133)


## Lines 979-980, one row of it (`row` 2 to 15), then the cursor home.
func detail_window() -> void:
	text.window_left = 1
	text.window_width = 39


func detail_clear_row(row: int) -> void:
	text.vtab(row)
	text.htab(2)
	text.print_line(" ".repeat(38))


## Line 990.
func detail_title() -> void:
	text.htab(2)
	text.vtab(2)
	_tab(5)
	text.print_line(star_name(p) + " STAR SYSTEM")
	text.new_line()


## Lines 1005-1160 as the PRINTs they come to, each a Callable.
func detail_lines() -> Array:
	var star := p - 1
	if not GameState.planet_scouted[star]: # 1005
		return [
			func() -> void: text.print_line("NO INFORMATION AVAILABLE AT THIS TIME."),
			func() -> void: text.new_line(),
		]
	var name_ := star_name(p)
	var tech: int = GameState.planet_tech[star]
	var lines: Array = []
	var say := func(line: String) -> void:
		lines.append(func() -> void: text.print_line(line))
	say.call("TECHNOLOGICAL DEVELOPMENT:") # 1010
	match tech: # 1030-1070
		0:
			say.call("NO INTELLIGENT LIFEFORMS INDICATED.")
		1:
			say.call("PRIMITIVE PSEUDO SOCIETY ONLY.")
		2:
			say.call("LIMITED ATOMIC DEVELOPMENT")
		3:
			say.call("SOPHISTICATED TECHNOLOGY WITH")
			say.call("STARSHIP CAPABILITY.")
		4:
			say.call("ADVANCED CAPABILITY-SUPERIOR TO  OURS!")
	say.call("") # 1080
	if tech >= 2: # 1090
		say.call("ORBITING DEFENSE CAPABILITY --")
		say.call("FIGHTER PROTECTION PROBABLE.")
	say.call("POPULATION = APPROX. %d" % (GameState.planet_population_scale[star] * 35294)) # 1110
	if GameState.planet_secured[star] != 0: # 1120-1140
		say.call(name_ + " HAS BEEN SECURED")
	else:
		say.call(name_ + " IS INDEPENDENT.")
	say.call("") # 1150
	if GameState.planet_has_base[star]: # 1160
		say.call("THERE IS AN OPERATIONAL REPAIR BASE")
		say.call("ON THE PLANET.")
	return lines


## Line 1170 up to its GET.
func detail_ready() -> void:
	text.vtab(15)
	text.print_text("READY ")


## Line 1172, with the chart's flag set: back to the chart.
func detail_close() -> void:
	text.mode = 0
	text.print_line(" ")


## `PRINT TAB(n);`: spaces through the output hook up to column n.
func _tab(n: int) -> void:
	while text.column < n - 1:
		text.put(0x20)
