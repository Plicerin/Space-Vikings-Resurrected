extends RefCounted
## END: save the game, go on with it, or end it, on the CRT console. What each
## does and says is scripts/rules/end_rules.gd, held to the real game
## (tests/check_end_rules.gd).
##
## Where it parts from the original, on purpose: three choices and nothing else
## is a choice, where any other key was a SYSTEM ERROR and a reboot; "3) END
## GAME" closes the application cleanly instead of zeroing the machine's zero
## page.

const EndRules = preload("res://scripts/rules/end_rules.gd")

const SAID := 3.0 ## seconds a message stays

var rules := EndRules.new()


## Runs the menu until "2) CONTINUE PRESENT GAME" (returns true); "3) END GAME"
## quits through `quit`.
## @witness END 70-100
func run(console: Node, quit: Callable) -> bool:
	while true:
		var choice: int = await console.menu("END GAME", EndRules.CHOICES, [], [], 2) # Escape: CONTINUE PRESENT GAME
		match choice:
			1:
				await console.say(["-END GAME-"] + console.flow(rules.save()), SAID)
			2:
				return true
			3:
				console.close()
				quit.call()
				return false
	return false
