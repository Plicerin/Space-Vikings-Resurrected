extends RefCounted
## STARSHIP SIMULATOR.bas, the flight program, a statement at a time,
## together with what the small programs it chains to and back from
## leave behind: INSTRUMENTS.bas (draws the panel), RE.bas and ORBIT.bas
## (entering and leaving the atmosphere), H_D.bas (the hyperdrive),
## EX.bas, DMG.bas and S_X.bas (the ends of a fight) and TRANLIT (the
## panel lamps, machine code at $9600).
##
## There is no timing in here. One pass of the original's main loop is
## cut into the pieces between which time passes on the real machine,
## and flight_loop.gd calls them with the measured waits in between:
##
##     begin_pass()   lines 15-147: read the stick, move the ship, tell
##                    A2-3D1 which page to show and which to draw on
##     fly()          line 150's CALL CA: the stick turns the ship, the
##                    3D view is drawn on the hidden page
##     after_view()   lines 150-182: panel copy, read-outs, gunsight,
##                    gauge markers
##     (lines 185-192, the fighting: flight_combat.gd)
##     keys()         lines 200-210
##
## tests/check_flight_passes.gd runs flight_loop.gd with no waits against
## the real game, recorded pass by pass in MAME (tools/mame/pass_live.lua,
## jump_live.lua), and compares both hi-res pages byte for byte after
## every pass.
##
## How the original's display works, since nothing here makes sense
## without it. `FOR OO = 0 TO 1` alternates two passes:
##
##     OO = 0   show page 1, clear and draw page 2, copy the panel (rows
##              126-189) from page 1 to page 2, print on page 2
##     OO = 1   show page 2, clear and draw page 1, copy the panel from
##              page 2 to page 1, print on page 1
##
## BASIC's own graphics (DRAW, HPLOT: the gauge markers) always go to
## page 1, whichever page is on show. On OO = 0 the panel is copied
## before the markers move, so page 2 always shows the markers of the
## pass before. Those are the original's, not this port's; the port only
## does the same things in the same order.
##
## More of the same kind, all kept:
##
##  - The lamp keys (A, B, W, S) do `CALL 38402: GOTO 1`. The program
##    starts over without clearing its variables: the frame just drawn
##    is never shown, the marker positions it remembered are reset (so
##    the old markers are not erased where they are and stay until a
##    panel copy overwrites them) and the position loses its fraction.
##  - Line 9 marks the first pass after any start with `POKE 38149,7`,
##    and line 182 skips the fighting on that pass. 38149 is also the
##    "base built on this trip" flag.
##  - The speed keys change S; the byte other programs read (38157) is
##    only written at the end of line 210, which a lamp key never
##    reaches.
##  - Only a key above "0" clears the keyboard strobe (line 201). A
##    space, RETURN or an arrow stays in the latch and is looked at
##    again every pass until another key replaces it.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const A2View = preload("res://scripts/shapes/a2_3d1_view.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const CharGenerator = preload("res://scripts/shapes/char_generator.gd")
const FlightCore = preload("res://scripts/flight/flight_core.gd")

const SHAPES_PATH := "res://assets/shapes/ENEMY I.A24580.L68.payload.json"

## What after_view() found.
enum After {
	FIGHT, ## carry on with lines 185-192
	FIRST_PASS, ## line 182: straight to the keys
	REENTRY, ## line 156: RUN RE
	ORBIT, ## line 158: RUN ORBIT
}

## What keys() found.
enum Keyed {
	NONE, ## next pass
	RESTART, ## a lamp key: the lamp is drawn and the program has started over
	HYPERDRIVE, ## H: RUN H/D
	COM, ## C: RUN COM
	RADAR, ## R: RUN RADAR
}

## TRANLIT's lamp pictures: two bytes side by side, five rows high.
const LAMP_WHITE_LEFT := [0x7F, 0x07]
const LAMP_GREEN_LEFT := [0x55, 0x02]
const LAMP_GREEN_MID := [0x28, 0x15]
const LAMP_WHITE_MID := [0x7C, 0x1F]
const LAMP_GREEN_ORBIT := [0x20, 0x55]
const LAMP_WHITE_ORBIT := [0x70, 0x7F]
const LAMP_ORANGE_COND := [0xA0, 0xD5]
const LAMP_GREEN_RIGHT := [0x50, 0x2A]
const LAMP_BLUE_RIGHT := [0xD0, 0xAA]
const LAMP_WHITE_RIGHT := [0x78, 0x3F]
## The panel has two rows of lamps.
const LAMP_ROW_TOP := 153
const LAMP_ROW_BOTTOM := 161

const PANEL_FIRST_ROW := 126
const PANEL_LAST_ROW := 189

var view: A2View
var page_1: HgrScreen
var page_2: HgrScreen
var text: CharGenerator
var shapes := ShapeTable.new()

## BASIC's X, Y, Z and the four factors.
var core := FlightCore.new()
## OO: 0 or 1, see above.
var oo: int = 0
## S and E: speed and energy as BASIC holds them.
var speed: int = 0
var energy: int = 0
## P, B, H: the attitude bytes as read at line 20, before the stick moves
## them. The read-outs and the markers of a pass show these.
var pitch: int = 0
var bank: int = 0
var heading: int = 0
## Where the four markers were drawn last (TT, VV, EE, SS) and where
## they go now (TX, VY, EX, SX).
var tt: float = 141.0
var tx: float = 141.0
var vv: int = 160
var vy: int = 0
var ee: int = 199
var ex: int = 199
var ss: float = 13.0
var sx: float = 0.0
## Byte 38149 = 7.
var first_pass: bool = true

## The keyboard latch ($C000): the key's ASCII code, bit 7 set until the
## strobe is cleared.
var key_latch: int = 0
## What PDL(1) and PDL(0) would read: 0, 128 (centred) or 255.
var input_pitch: int = 128
var input_bank: int = 128


func _init() -> void:
	view = GameState.view3d
	page_1 = view.pages[0]
	page_2 = view.pages[1]
	text = GameState.chargen
	shapes.load_shapes(SHAPES_PATH)


## A key press as the Apple's keyboard would latch it.
func press(character: String) -> void:
	key_latch = (character.to_upper().unicode_at(0) & 0x7F) | 0x80


# -- INSTRUMENTS.bas ----------------------------------------------------


## The whole program: the panel on page 1, then TRANLIT's redraw of every
## lamp (line 210).
func instruments() -> void:
	text.page = 0 # 3
	page_1.clear() # 5  HGR: POKE -16302,0
	view.shown = 0
	page_1.hcolor = 1 # 10-60: the frame, in green
	page_1.hplot_path([123, 145, 1, 145, 1, 128, 279, 128, 279, 145, 157, 145])
	page_1.hplot_path([123, 128, 123, 183, 133, 183, 133, 189, 147, 189, 147, 183, 157, 183, 157, 128])
	page_1.hplot_path([13, 131, 13, 130, 77, 130, 77, 131])
	page_1.hplot(45, 131)
	page_1.hplot_path([261, 131, 261, 130, 199, 130, 199, 131])
	page_1.hplot(231, 131)
	page_1.hplot_path([129, 131, 129, 130, 151, 130, 151, 131])
	page_1.hplot_path([139, 131, 141, 131])
	page_1.hplot_path([139, 152, 141, 152, 141, 184, 139, 184])
	page_1.hplot(139, 167)
	page_1.hcolor = 5 # 70
	page_1.hplot_path([5, 177, 117, 177])
	page_1.hplot_path([163, 177, 277, 177])
	page_1.hcolor = 3 # 80-160: the eight lamp frames
	for corner in [[6, 152], [71, 152], [6, 160], [71, 160], [200, 152], [261, 152], [200, 160], [261, 160]]:
		var x: int = corner[0]
		var y: int = corner[1]
		page_1.hplot_path([x, y, x + 11, y, x + 11, y + 5, x, y + 5, x, y])
	text.mode = 0xFF # 165
	text.vtab(18) # 170
	text.htab(4)
	text.print_text(" SPEED ")
	text.htab(19)
	text.print_text("TURN")
	text.htab(30)
	text.print_line(" ENERGY ")
	text.vtab(20) # 175
	text.htab(22)
	text.print_text("V")
	text.vtab(21)
	text.htab(22)
	text.print_text("E")
	text.vtab(22)
	text.htab(22)
	text.print_line("R")
	text.vtab(23)
	text.htab(22)
	text.print_line("T")
	text.vtab(20) # 177
	text.htab(19)
	text.print_text("C")
	text.vtab(23)
	text.htab(19)
	text.print_text("D")
	text.mode = 0
	text.vtab(20) # 180
	text.htab(4)
	text.print_text("MANUAL")
	text.htab(13)
	text.print_text("AUTO")
	text.htab(24)
	text.print_text("ORBIT")
	text.htab(32)
	text.print_line("DAMAGE")
	text.vtab(21) # 190
	text.htab(4)
	text.print_text("MISSILE")
	text.htab(13)
	text.print_text("LASER")
	text.htab(24)
	text.print_text("COND")
	text.htab(32)
	text.print_line("SHIELD")
	text.vtab(23) # 200
	text.htab(3)
	text.print_text("X")
	text.htab(9)
	text.print_text("Y")
	text.htab(15)
	text.print_text("Z")
	text.htab(25)
	text.print_text("XHDNG")
	text.htab(34)
	text.print_line("YHDNG")
	GameState.instruments_due = false
	tranlit_all() # 210  POKE 38189,10: CALL 38402


# -- TRANLIT ($9600, CALL 38402) ----------------------------------------


## `POKE 38167,mode: CALL 38402`: flip one switch and redraw its lamp.
## 1 shields, 2 weapon, 3 condition, 4 autopilot. The lamp is stored as
## raw bytes on page 1, whichever page is on show.
func tranlit(mode: int) -> void:
	match mode:
		1:
			if not GameState.shields_up:
				_lamp(LAMP_ROW_BOTTOM, 37, LAMP_GREEN_RIGHT)
				GameState.shields_up = true
			else:
				_lamp(LAMP_ROW_BOTTOM, 37, LAMP_WHITE_RIGHT)
				GameState.shields_up = false
		2:
			if not GameState.missile_mode_active:
				_lamp(LAMP_ROW_BOTTOM, 1, LAMP_GREEN_LEFT)
				_lamp(LAMP_ROW_BOTTOM, 10, LAMP_WHITE_MID)
				GameState.missile_mode_active = true
			else:
				_lamp(LAMP_ROW_BOTTOM, 1, LAMP_WHITE_LEFT)
				_lamp(LAMP_ROW_BOTTOM, 10, LAMP_GREEN_MID)
				GameState.missile_mode_active = false
		3:
			if GameState.condition == 2:
				_lamp(LAMP_ROW_BOTTOM, 28, LAMP_ORANGE_COND)
				GameState.condition = 3
			elif GameState.condition == 3:
				_lamp(LAMP_ROW_BOTTOM, 28, LAMP_GREEN_ORBIT)
				GameState.condition = 1
			else:
				_lamp(LAMP_ROW_BOTTOM, 28, LAMP_BLUE_RIGHT)
				GameState.condition = 2
		4:
			if not GameState.autopilot_active:
				_lamp(LAMP_ROW_TOP, 1, LAMP_WHITE_LEFT)
				_lamp(LAMP_ROW_TOP, 10, LAMP_GREEN_MID)
				GameState.autopilot_active = true
			else:
				_lamp(LAMP_ROW_TOP, 1, LAMP_GREEN_LEFT)
				_lamp(LAMP_ROW_TOP, 10, LAMP_WHITE_MID)
				GameState.autopilot_active = false


## `POKE 38189,10: CALL 38402`: every lamp. The four switches go through
## the same code as a key press, so each one is flipped on the way; the
## ORBIT and DAMAGE lamps only show their flags.
func tranlit_all() -> void:
	for mode in range(1, 5):
		tranlit(mode)
	_lamp(LAMP_ROW_TOP, 28, LAMP_WHITE_ORBIT if GameState.in_atmosphere else LAMP_GREEN_ORBIT)
	_lamp(LAMP_ROW_TOP, 37, LAMP_BLUE_RIGHT if GameState.damage_alert_active else LAMP_GREEN_RIGHT)


func _lamp(first_row: int, column: int, bytes: Array) -> void:
	for y in range(first_row, first_row + 5):
		page_1.set_byte(y, column, bytes[0])
		page_1.set_byte(y, column + 1, bytes[1])


# -- STARSHIP SIMULATOR.bas ---------------------------------------------


## RUN <program>, the DOS command: when the program is loaded and about
## to start, one carriage return goes through the character generator
## (a BLOAD sends none). Seen live, tools/mame/print_live.lua.
func ran() -> void:
	text.new_line()


## Lines 1-9. `run` is true for RUN STARSHIP SIMULATOR (every variable
## starts at zero) and false for line 500's GOTO 1 (they keep their
## values).
func start(run: bool) -> void:
	if run:
		core = FlightCore.new()
		pitch = 0
		bank = 0
		heading = 0
		vy = 0
		sx = 0.0
	ee = 199 # 2
	ss = 13.0
	ex = ee
	vv = 160
	tx = 141.0
	tt = tx
	core.reload(GameState.ship_x, GameState.ship_y, GameState.ship_z) # 8
	speed = GameState.ship_speed
	energy = int(GameState.ship_energy)
	first_pass = true # 9  POKE 38149,7
	GameState.base_built_this_trip = false
	oo = 0 # 15


## Lines 15-147, up to the three POKEs that tell A2-3D1 what to do.
func begin_pass() -> void:
	if not GameState.autopilot_active: # 15-19
		GameState.paddle_pitch = input_pitch
		GameState.paddle_bank = input_bank
	pitch = GameState.ship_pitch # 20
	bank = GameState.ship_bank
	heading = GameState.ship_heading
	core.step(pitch, heading, speed) # 112-138
	var stored := core.stored() # 140
	GameState.ship_x = stored.x
	GameState.ship_y = stored.y
	GameState.ship_z = stored.z
	view.poke(A2View.SHOWN_BYTE, 84 + oo) # 147
	view.poke(A2View.CLEAR_BYTE, 1 - oo)
	view.poke(A2View.TARGET_BYTE, 1 - oo)


## The rest of line 147 and CALL CA ($9023): in the atmosphere the ship
## sinks; the stick turns the ship; A2-3D1 switches the display to the
## page finished a pass ago and draws the new view on the other one.
func fly() -> void:
	if GameState.in_atmosphere and core.sink(speed):
		GameState.ship_pitch = 0
		GameState.ship_bank = 0
	var turned := FlightCore.stick(GameState.ship_pitch, GameState.ship_bank, GameState.ship_heading,
		GameState.loop_flip, GameState.paddle_pitch, GameState.paddle_bank)
	GameState.ship_pitch = turned[0]
	GameState.ship_bank = turned[1]
	GameState.ship_heading = turned[2]
	GameState.loop_flip = turned[3]
	view.run()


## Lines 150-182.
func after_view() -> After:
	if oo == 1: # 150
		text.page = 0
		page_1.copy_rows_from(page_2, PANEL_FIRST_ROW, PANEL_LAST_ROW) # CALL 37936
	else: # 153
		text.page = 1
		page_2.copy_rows_from(page_1, PANEL_FIRST_ROW, PANEL_LAST_ROW) # CALL 37888
	text.vtab(24) # 155
	text.htab(1)
	text.print_text(CharGenerator.number_text(core.x / 2) + " ")
	text.htab(7)
	text.print_text(CharGenerator.number_text(core.y / 2) + " ")
	text.htab(13)
	text.print_text(CharGenerator.number_text(core.z / 2) + " ")
	text.htab(26)
	text.print_text(CharGenerator.number_text(heading * 1.41) + "  ")
	text.htab(35)
	text.print_text(CharGenerator.number_text(pitch * 1.41) + "  ")
	text.mode = 1 # 156: the gunsight, XORed onto the new view
	text.vtab(8)
	text.htab(18)
	text.print_line("-[  ]-")
	text.mode = 0
	if absf(core.x) < 900 and absf(core.y) < 900 and absf(core.z) < 900 and not GameState.in_atmosphere:
		return After.REENTRY
	if GameState.in_atmosphere and core.y > 4000: # 158
		return After.ORBIT
	page_1.hcolor = 0 # 159: the old markers off
	page_1.draw(shapes, 25, int(tt), 133)
	page_1.draw(shapes, 26, 136, vv)
	page_1.draw(shapes, 25, ee, 133)
	page_1.draw(shapes, 25, int(ss), 133)
	tx = 140 + ((255 - bank) / 5.7)
	if bank < 127:
		tx = 140 - (bank / 5.7)
	vy = floori(167 - ((255 - pitch) / 4.0)) # 170
	if pitch < 127:
		vy = floori(167 + (pitch / 4.0))
	sx = 13 + (speed / 2.0) # 173
	ex = 199 + energy
	page_1.hcolor = 3 # 175
	GameState.ship_pitch = FlightCore.pitch_clamp(GameState.ship_pitch) # 175-177
	page_1.draw(shapes, 13, int(tx), 133) # 180: and on again
	page_1.draw(shapes, 14, 136, vy)
	page_1.draw(shapes, 13, int(sx), 133)
	page_1.draw(shapes, 13, ex, 133)
	if oo == 1:
		tt = tx
		vv = vy
		ee = ex
		ss = sx
	if first_pass: # 182
		first_pass = false
		return After.FIRST_PASS
	return After.FIGHT


## Lines 200-210.
func keys() -> Keyed:
	var k := key_latch # 200
	if k < 128:
		_next()
		return Keyed.NONE
	if k - 176 > 0: # 201
		k -= 176
		key_latch &= 0x7F # POKE -16368,0
		match k:
			1: speed -= 3 # 311
			2: speed += 3
			3: speed -= 15
			4: speed += 15
	if k >= 17: # 202
		match k - 16: # 203
			1: return _restart(4) # A
			2: return _restart(3) # B
			3: return Keyed.COM # C
		if k >= 34: # 204
			if k == 39: # 205
				return _restart(2) # W
			match k - 33: # 206
				1: return Keyed.RADAR # R
				2: return _restart(1) # S
	speed = clampi(speed, 0, 120) # 207-208
	if k == 24: # 209
		return Keyed.HYPERDRIVE # H
	GameState.ship_speed = speed # 210
	_next()
	return Keyed.NONE


## NEXT: GOTO 15.
func _next() -> void:
	oo = 1 - oo


## Line 500: CALL 38402: GOTO 1.
func _restart(lamp: int) -> Keyed:
	tranlit(lamp)
	start(false)
	return Keyed.RESTART


# -- RE.bas -------------------------------------------------------------

## Rows of the window RE.bas, ORBIT.bas and the rest fill, one HPLOT each.
const OVERLAY_ROWS := 126


## Lines 1-10: gauges and read-outs off, ready for the window to be
## filled with orange a row at a time (overlay_row) and the message put
## on it (overlay_message). flight_loop.gd has the order and the waits.
func reentry_open() -> void:
	text.page = 0 # 1
	_overlay_open(5)


## Lines 21-26.
func reentry_close() -> void:
	page_1.hcolor = 3 # 21
	text.page = 1
	for j in range(153, 158): # 22
		page_1.hplot_path([200, j, 209, j])
	GameState.in_atmosphere = true # 25
	text.mode = 0 # 26


## Lines 27-40: the planet's terrain replaces the star field and the ship
## starts at 1024 up, heading 20. X keeps its high byte.
##
## The two `PRINT " "` put a blank on page 2, in the first column of
## text rows 10 and 11, over whatever the last view drew there. The DOS
## commands between them (`PRINT "<ctrl-D>BLOAD ..."`) print nothing and
## do not move the cursor: in the live run a star one row further down
## is still there afterwards.
func reentry_load() -> void:
	var x_high := view.peek(A2View.EYE + 1) # 27
	var kept_pitch := GameState.ship_pitch # 28
	var kept_bank := GameState.ship_bank
	text.print_line(" ") # 30
	view.load_planet(GameState.current_planet + 1)
	view.poke(A2View.EYE, 188) # 29, 35
	view.poke(A2View.EYE + 1, x_high)
	GameState.ship_y = 1024
	GameState.ship_z = -7000
	GameState.ship_pitch = kept_pitch # 37
	GameState.ship_bank = kept_bank
	GameState.ship_heading = 20
	text.print_line(" ") # 40


# -- ORBIT.bas ----------------------------------------------------------


## Lines 1-10, RE's in green.
func orbit_open() -> void:
	page_1.hcolor = 0 # 1
	text.page = 0 # 2
	_overlay_open(6)


func orbit_close() -> void:
	page_1.hcolor = 1 # 21
	text.page = 1
	for j in range(153, 158): # 22
		page_1.hplot_path([200, j, 209, j])
	GameState.in_atmosphere = false # 25
	text.mode = 0 # 26


## Lines 27-40: the star field again, with whatever is in orbit, and the
## ship at 700, 200, 2000 heading 190. True when a ship was loaded.
func orbit_load() -> bool:
	var kept_pitch := GameState.ship_pitch # 28
	var kept_bank := GameState.ship_bank
	text.print_line(" ") # 30
	view.load_planet(0)
	if GameState.orbital_defender_tier != 0: # 30-32
		view.load_ship(GameState.orbital_defender_tier)
	GameState.ship_x = 700 # 27, 35
	GameState.ship_y = 200
	GameState.ship_z = 2000
	GameState.ship_pitch = kept_pitch # 37
	GameState.ship_bank = kept_bank
	GameState.ship_heading = 190
	text.print_line(" ") # 40
	return GameState.orbital_defender_tier != 0


## Line 2 of RE.bas and ORBIT.bas, line 8 of H_D.bas and of COM.bas: the
## speed and energy markers off, wherever they are, and the read-outs
## blanked.
func markers_off() -> void:
	page_1.hcolor = 0
	for x in range(200, 261, 5):
		page_1.draw(shapes, 25, x, 133)
	for x in range(13, 74, 5):
		page_1.draw(shapes, 25, x, 133)
	text.vtab(24)
	text.htab(1)
	text.print_text(" ".repeat(17))
	text.htab(24)
	text.print_line(" ".repeat(16))


## Lines 2-10 of RE.bas and ORBIT.bas, the same but for the colour.
func _overlay_open(fill_color: int) -> void:
	markers_off() # 2
	view.shown = 0 # 5  POKE -16300,0
	text.page = 0
	text.mode = 0xFF
	page_1.hcolor = fill_color # 10


## Line 10: one row of the fill.
func overlay_row(y: int) -> void:
	page_1.hplot_path([0, y, 279, y])


## Line 20: the words, in inverse, with a blank line above and below.
func overlay_message(message: String) -> void:
	text.vtab(7)
	text.htab(10)
	text.print_line(" ".repeat(message.length()))
	text.htab(10)
	text.print_line(message)
	text.htab(10)
	text.print_line(" ".repeat(message.length()))


# -- H_D.bas ------------------------------------------------------------
#
# The hyperdrive, watched live from the key press to the first pass at
# the other star (tools/mame/jump_live.lua, analysis/live/jump/). The
# pieces are in the order flight_loop.gd calls them.

## Where every ray of line 20 starts (C1, C2).
const JUMP_CENTRE := [140, 63]
## Line 17 blanks text rows 1 to 16: the window and two rows of the panel.
const JUMP_CLEAR_ROWS := 16
## Line 18: calls of the noise routine before the first ray.
const JUMP_NOISE_CALLS := 251
## Line 20: rays per burst. The first burst is white, the second black.
const JUMP_RAYS := 175


## Line 1: page 1 on show, and no jump from inside an atmosphere, to the
## planet the ship is at, or with no course set. A refusal costs nothing
## but the two program loads: RUN STARSHIP SIMULATOR.
func hyperdrive_refused() -> bool:
	view.shown = 0 # POKE -16300,0
	return GameState.in_atmosphere or GameState.target_planet == GameState.current_planet \
		or GameState.target_planet < 0


## Line 2. With no energy at all the ship is lost instead (lines 3-4).
func jump_has_energy() -> bool:
	return int(GameState.ship_energy) != 0


## Line 3: where "OUT OF ENERGY" and then "ORBIT DECAYING" are printed,
## on page 1. flight_loop.gd prints them a letter at a time.
func jump_no_energy_message() -> void:
	view.shown = 0
	text.page = 0
	text.htab(15)
	text.vtab(15)


## Lines 10000-10020: light-years to the course's star, which is also the
## energy the jump costs. The original takes the difference of the two
## stars' chart X three times over (X1, Y1 and Z1 are all read from the
## X table), so the chart's Y and Z do not count.
func jump_distance() -> int:
	var d: int = absi(GameState.PLANET_X[GameState.current_planet]) \
		- absi(GameState.PLANET_X[GameState.target_planet])
	return int(sqrt(3.0 * d * d) + 0.6)


## Lines 5-6: the read-outs go to page 2, the loot of the star being left
## is forgotten, the star date moves on.
func jump_log(distance: int) -> void:
	text.page = 1 # 5  POKE 974,64
	GameState.loot_collected_this_visit = false # POKE 301,0
	# 6: three INPUTs from MISC FILE. Each one's prompt is a NUL, which
	# the character generator draws (glyph 0, a dot) and steps past; the
	# line read from the file never reaches it.
	for i in range(3):
		text.put(0)
	GameState.stardate += distance + 0.3


## Lines 7-16: gauges off, troops and the planet's record put away, the
## energy paid.
func jump_ready(distance: int) -> void:
	text.page = 0 # 7
	markers_off() # 8
	if GameState.troop_location == 0 or GameState.troop_location == 3: # 11
		GameState.troops_stationed_at = GameState.target_planet + 1
	GameState.store_planet_record(GameState.current_planet) # 12
	if GameState.morale_flag == 17: # 12-13: troops that fought and were not paid off
		GameState.troop_morale = maxi(GameState.troop_morale - 1, 0)
		GameState.morale_flag = 0
	page_1.hcolor = 3 # 14
	GameState.ship_energy = maxf(int(GameState.ship_energy) - distance, 0.0)
	text.mode = 0 # 15
	text.page = 0 # 16
	GameState.defender_damage_points = 0.0
	GameState.planet_scouted[GameState.target_planet] = true


## Line 17, one turn of the loop (l from 1 to JUMP_CLEAR_ROWS).
func jump_clear_row(l: int) -> void:
	text.vtab(l)
	text.print_line(" ".repeat(40))
	if l == JUMP_CLEAR_ROWS:
		text.vtab(1)


## Line 20, one ray, in whatever colour is set.
func jump_ray() -> void:
	page_1.hplot_path([JUMP_CENTRE[0], JUMP_CENTRE[1], int(randf() * 279.0), int(randf() * 125.0)])


## Lines 25-76: the other star's record, what is in orbit there, and the
## ship somewhere around it, level, on any heading. True when a file was
## loaded for what is in orbit.
func jump_arrive() -> bool:
	GameState.load_planet_record(GameState.target_planet) # 25
	GameState.current_planet = GameState.target_planet # 26
	var tier: int = GameState.orbital_defender_tier
	if GameState.planet_tech[GameState.current_planet] > 1 and tier == 0: # 30
		view.load_debris()
	elif tier == 0: # 37
		view.remove_ship()
	else: # 38-40
		view.load_ship(tier)
	GameState.ship_x = floori(10000.0 - randf() * 20000.0) # 50
	GameState.ship_y = floori(5000.0 - randf() * 10000.0) # 60
	var z := 0
	while absi(z) < 7000: # 70: never close in
		z = floori(10000.0 - randf() * 20000.0)
	GameState.ship_z = z
	GameState.ship_pitch = 0 # 73-75
	GameState.ship_heading = int(randf() * 255.0)
	GameState.ship_bank = 0
	page_1.hcolor = 0 # 76: the second burst of rays rubs the first out
	return tier != 0 or GameState.planet_tech[GameState.current_planet] > 1


## Lines 90-105: what the planet can stand, from its technology. The
## target stays set: a second H here is refused by line 1.
func jump_finish() -> void:
	var tech: int = GameState.planet_tech[GameState.current_planet]
	if tech < 2: # 90
		GameState.gf_enemy_strength = 0.0
	else: # 93
		GameState.gf_enemy_strength = tech * 60.0
		GameState.defender_damage_threshold = tech * 60.0
		GameState.gf_victory_progress = 0.0
	GameState.enlisted_this_trip = false # 105
	GameState.base_built_this_trip = false


# -- EX.bas, DMG.bas, S_X.bas -------------------------------------------
#
# What these three leave behind. Their pictures are combat_fx.gd's.


## EX.bas lines 30-56: nothing in orbit but the wreck, and half the
## fighters gone with the defender.
func ex_finish() -> void:
	GameState.orbital_defender_tier = 0 # 30
	view.remove_ship()
	view.load_debris() # 40
	GameState.flight_escort_fighters = GameState.flight_escort_fighters / 2 # 56


## DMG.bas line 10: the DAMAGE lamp, orange, on page 1; and a blank
## through the character generator wherever its cursor was left.
func dmg_show() -> void:
	page_1.hcolor = 5
	for j in range(153, 158):
		page_1.hplot_path([262, j, 271, j])
	text.print_line(" ")


## S_X.bas lines 2-5: page 1, inverse text, black lines.
func sx_open() -> void:
	view.shown = 0 # 2
	text.page = 0 # 4
	page_1.hcolor = 0 # 5
	text.mode = 0xFF
	text.new_line()


## S_X.bas line 40: where the last message goes.
func sx_message() -> void:
	text.vtab(22)
	text.htab(5)
