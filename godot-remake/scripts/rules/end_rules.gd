extends RefCounted
## The rules of END.bas, the command console's "4) END": save the game,
## go on with it, or end it. No screen in it (scripts/end/end_console.gd
## shows it). tests/check_end_rules.gd holds it to what the real game
## printed and kept, from the recordings in analysis/live/end/. Line
## numbers are the original's.
##
## Not kept, as they are the machine and not the game: the choice is
## made by a key read as a number, so a letter, RETURN or ESC lost the
## game in hand to a SYSTEM ERROR screen and a reboot, and a digit that
## is no choice drew the menu again (the buttons offer three choices);
## and "3) END GAME" zeroed the zero page, so that BASIC and the machine
## went with it (the application closes).

const TITLE := "END GAME"
const CHOICES := ["SAVE GAME", "CONTINUE PRESENT GAME", "END GAME"] # 50-60
const PROMPT := "ENTER CHOICE."
const SAID_ORBIT: Array[String] = ["YOU MUST BE IN ORBIT TO SAVE GAME"] # 190
const SAID_SAVED: Array[String] = ["GAME SAVED."] # 210
const SAID_NOT_SAVED: Array[String] = ["THE GAME COULD NOT BE SAVED."]

## Puts the game away: GameState.save_to_disk, which is true if it could
## be written. A test points it at nothing.
var writer: Callable = GameState.save_to_disk


## @witness END 190
## A game cannot be saved in the atmosphere.
func in_atmosphere() -> bool:
	return GameState.in_atmosphere


## @witness END 190-220
## "1) SAVE GAME": what is said. The ship's place goes into the planet's
## record, the saved-game mark is set (204) and the record is written out
## (200-210): that is the writer's.
func save() -> Array[String]:
	if in_atmosphere():
		return SAID_ORBIT
	GameState.saved_marker = true # 204  POKE 38391,77
	if not writer.call():
		GameState.saved_marker = false
		return SAID_NOT_SAVED
	return SAID_SAVED


## @witness END 110-120
## "2) CONTINUE PRESENT GAME": the saved-game mark is left for GALAXY MAP
## (the flight loop's own way in, flight_loop.gd run()) to take off.
func continue_game() -> void:
	GameState.saved_marker = true # 120  POKE 38391,77
