extends RefCounted
## END.bas, a statement at a time and with no time in it (end_loop.gd
## has the clock and the GOTOs). The command console's "4) END" runs it;
## despite the name it is where a game is saved:
##
##         END GAME
##
##   1) SAVE GAME
##   2) CONTINUE PRESENT GAME
##   3) END GAME
##
##   ENTER CHOICE.
##
## It draws on hi-res page 1 with the game's character generator, over
## the console COM left there: line 30 wipes text rows 1 to 16 (the
## whole view and the top two rows of the flight panel) and the menu
## goes on top of the black. The bottom of the panel stays.
##
## Things in the original that look like slips and are kept:
##
##  - The choice is read with `GET C`, a number. Applesoft makes a
##    number of the key the way VAL would not: a digit is itself, and a
##    space, ".", "+", "-", ",", ":" and "E" are 0 (so the menu is drawn
##    again, like any digit that is not 1 to 3). Every other key is a
##    ?SYNTAX ERROR, which `ONERR GOTO 63999` catches, and line 63999
##    is the SYSTEM ERROR screen and a reboot (scripts/dos/
##    system_error.gd). A letter, RETURN or ESC at this menu loses the
##    game in hand. Each of those keys was pressed on the live machine
##    (tools/mame/end_live.lua, the routes key_*).
##  - "3) END GAME" is `FOR J = 1 TO 5000: POKE J,0: NEXT : END`. It
##    never reaches its END: zeroing the zero page takes BASIC's own
##    pointers with it, and at J = 105 or so the machine is gone, the
##    display switched to the (blank) text screen. It stays like that
##    until it is switched off.
##  - Line 30 has a VTAB for each row it wipes and no HTAB. Its forty
##    spaces start in whatever column the cursor was left in and wrap
##    round to the next row, so after a key that is not 1 to 3 (the
##    cursor still after "ENTER CHOICE.") the first fifteen cells of row
##    1 are not wiped. There is nothing in them but the space line 40
##    prints.
##  - After a save the 77 that marks a saved game (38391) is still in
##    memory as well as on the disk. Nothing reads it before "2)
##    CONTINUE" pokes it again.
##
## The save itself is GameState.save_to_disk(): lines 200-202 (the
## ship's place, from the flight program's bytes into SHIP'S DATA), 204
## (the mark), 210 (the planet's record put away with CALL 38825, and
## the three BSAVEs). The BSAVEs print nothing: the message is on the
## row under the one line 75's space went on.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const CharGenerator = preload("res://scripts/shapes/char_generator.gd")

## Line 30: `FOR J = 1 TO 16`.
const WIPE_ROWS := 16
## Line 190, as PRINTs: the bare one first.
const REFUSED := ["", "YOU MUST BE IN ORBIT TO SAVE GAME"]
## What `GET C` makes 0 of.
const ZERO_KEYS := " .+-,:E"

var text: CharGenerator

## The keyboard latch ($C000): bit 7 is the strobe.
var key_latch: int = 0


func _init() -> void:
	text = GameState.chargen


## A key press as the Apple's keyboard would latch it.
func press(character: String) -> void:
	key_latch = (character.to_upper().unicode_at(0) & 0x7F) | 0x80


## `GET C` once a key is down.
func take_key() -> String:
	var character := String.chr(key_latch & 0x7F)
	key_latch &= 0x7F
	return character


## The number `GET C` makes of a key, or -1 for the ?SYNTAX ERROR.
static func number(key: String) -> int:
	if key.length() == 1 and key >= "0" and key <= "9":
		return int(key)
	if key.length() == 1 and ZERO_KEYS.contains(key):
		return 0
	return -1


## RUN END: DOS's carriage return through the character generator.
func ran() -> void:
	text.new_line()


## Line 20: `POKE 974,32`. COM left the generator on page 2.
func open() -> void:
	text.page = 0


## Line 30 up to its FOR: `POKE 33,40`.
func wipe_open() -> void:
	text.window_width = 40


## Line 30, a row of it (`j` 1 to 16).
func wipe_row(j: int) -> void:
	text.vtab(j)
	text.print_line(" ".repeat(40))


## Line 30's HOME.
func home() -> void:
	text.home()


## Lines 31-40.
func title() -> void:
	text.print_line(" ")
	text.htab(16)
	text.print_line("END GAME")
	text.new_line()
	text.new_line()


## Line 50.
func save_line() -> void:
	_tab(7)
	text.print_line("1) SAVE GAME")


## Line 60.
func other_lines() -> void:
	_tab(7)
	text.print_line("2) CONTINUE PRESENT GAME")
	_tab(7)
	text.print_line("3) END GAME")
	text.new_line()
	text.new_line()


## Line 70 up to its GET.
func prompt() -> void:
	text.print_text("ENTER CHOICE.  ")


## Line 75: `PRINT " "`.
func space() -> void:
	text.print_line(" ")


## Line 190: `PEEK (38210) = 1`.
func in_atmosphere() -> bool:
	return GameState.in_atmosphere


## Lines 200-210 up to the message. False if the disk could not be
## written, which on the Apple is a DOS error.
func save() -> bool:
	GameState.saved_marker = true # 204  POKE 38391,77
	return GameState.save_to_disk()


## Line 210: `PRINT : PRINT "GAME SAVED."`
func saved_message() -> void:
	text.new_line()
	text.print_line("GAME SAVED.")


## Line 120: `POKE 38391,77`. The RUN GALAXY MAP after it is the flight
## loop's (flight_loop.gd, run()): with the 77 there GALAXY MAP paints
## the panel's lamps and runs STARSHIP SIMULATOR.
func continue_game() -> void:
	GameState.saved_marker = true


## Line 63999's `PRINT`.
func error() -> void:
	text.new_line()


## `PRINT TAB( n);`: spaces up to column n.
func _tab(n: int) -> void:
	while text.column < n - 1:
		text.put(32)
