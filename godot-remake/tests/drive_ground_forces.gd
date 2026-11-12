extends Node
## Uses the ground forces program (scripts/flight/ground_forces_program.gd) and
## SHORE LEAVE's six commands (shore_leave_program.gd) the way a player would:
## keys put into Godot's input queue, on the console's own clock, and a look at
## what the console display says and what became of the game. The rules
## themselves are held to the real game in check_ground_rules.gd and
## check_shore_rules.gd; this is for the programs round them.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_ground_forces.tscn
##
## The flight scene is the stage: the program runs over it.

const FLIGHT := "res://scenes/native_flight.tscn"
const GroundForcesProgram = preload("res://scripts/flight/ground_forces_program.gd")
const QUICK := 0.02
## Frames before a step is given up.
const TIMEOUT_FRAMES := 60 * 60

var _bad := 0
var _driver := false
var _console: Node
var _overlay: Control
var _globe: Control
var _program: RefCounted
var _running := false
var _heard: Array = [] ## what the console has said on a page that is not the menu, in order


## The scenes replace one another, so the driver is a node of its own under the root.
func _ready() -> void:
	if _driver:
		_drive.call_deferred()
		return
	var driver := Node.new()
	driver.set_script(get_script())
	driver._driver = true
	driver.name = "GroundDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	seed(1982)
	var here := 0

	# the menu and its refusals
	await _fresh(func() -> void: GameState.planet_has_base[here] = false)
	_check("the menu is up, nine commands in two columns", _at_menu() and _lines()[0] == "-GROUND FORCES-"
			and _lines()[1] == _console.columns("1) ATTACK PLANET", "6) REPAIR/RESTOCK") and _globe.visible)
	_tap(KEY_3)
	await _frames(3)
	_check("3 with no base: NO BASE, under the menu", _at_menu() and _menu_said() == "NO BASE")

	await _fresh(func() -> void: GameState.troops_stationed_at = here + 2)
	_tap(KEY_1)
	await _frames(3)
	_check("1 with the troops at another star: refused",
			_at_menu() and _menu_said() == "YOU CAN'T ATTACK!\nYOU LEFT\nYOUR TROOPS ON\nANOTHER PLANET!")

	await _fresh(func() -> void:
		GameState.troop_location = 1
		GameState.troops = 1000.0)
	_tap(KEY_2)
	await _frames(3)
	_check("2: the troops are recalled", _menu_said() == "TROOPS ARE BEING\nRECALLED, SIR!" and GameState.troop_location == 0)

	await _fresh(func() -> void: GameState.gf_transports = 0.0)
	_tap(KEY_1)
	await _back_at_the_menu()
	_check("1 with no transports: said on the battle screen, then the menu",
			_heard == ["THERE ARE NO TRANSPORTS AVAILABLE!"] and GameState.troop_location != 1)

	await _fresh(func() -> void: GameState.planet_tech[here] = 0)
	_tap(KEY_1)
	await _back_at_the_menu()
	_check("a lifeless planet: landed on and secured without a round",
			GameState.gf_planet_surrendered and GameState.planet_secured[here] == 1
			and _heard.back() == "PLANET IS NON HABITABLE. THERE IS NO\nENEMY TO RESIST LANDING FORCE."
			and not GameState.loot_collected_this_visit)

	await _fresh(func() -> void:
		GameState.planet_tech[here] = 2
		GameState.gf_enemy_strength = 30.0
		GameState.troop_morale = 6
		GameState.troops = 8000.0)
	var loot_before := _loot()
	_tap(KEY_1)
	await _until(func() -> bool: return _text().contains("R  RETREAT"))
	_check("the battle is on: RETREAT is offered, and the globe up", _globe.visible and not _text().contains("RETREAT ORDERED"))
	await _back_at_the_menu()
	_check("the planet surrenders", GameState.gf_planet_surrendered and GameState.planet_secured[here] == 1
			and "THE PLANET HAS SURRENDERED!" in _heard)
	_check("and the globe is all ours", _globe.capture == 1.0 or not _globe.visible)
	_check("the troops held back are with the rest again", GameState.troops >= 2000.0 and GameState.troops <= 8000.0)
	_check("the loot is collected", _loot() > loot_before and GameState.loot_collected_this_visit
			and _heard.back() == "OPERATION SOL IS A\nSUCCESS, SIR!")
	_check("the battle screen had the game's counts", _saw_counts)

	await _fresh(func() -> void:
		GameState.planet_tech[here] = 4
		GameState.gf_enemy_strength = 255.0
		GameState.troop_morale = 3
		GameState.troops = 6000.0)
	var secured: int = GameState.planet_secured[here]
	_tap(KEY_1)
	await _until(func() -> bool: return _text().contains("R  RETREAT"))
	_tap(KEY_R)
	await _frames(2)
	_check("R: the retreat is ordered", _text().contains("RETREAT ORDERED"))
	await _back_at_the_menu()
	_check("the troops fall back: morale down one, the planet as it was, the troops still below",
			GameState.troop_morale == 2 and GameState.planet_secured[here] == secured
			and GameState.troop_location == 1 and _heard.back() == "GROUND FORCES RETREATING, SIR!\nPLANET NOT SECURED!")

	await _fresh(func() -> void:
		GameState.planet_tech[here] = 4
		GameState.gf_enemy_strength = 255.0
		GameState.troop_morale = 1
		GameState.troops = 3.0)
	_tap(KEY_1)
	await _back_at_the_menu()
	_check("a battle lost: no troops below, none left",
			GameState.troop_location == 0 and GameState.troops == 0.0
			and _heard.back() == "THE BATTLE IS LOST! ALL TROOPS\nHAVE BEEN DESTROYED!!!")

	# at the game's own pace: a report stays up, and a key moves on
	await _fresh(func() -> void: GameState.planet_tech[here] = 0, 1.0)
	_tap(KEY_1)
	await _frames(30)
	_check("at full pace the first report stays up", _text().contains("ALL TRANSPORTS AWAY, SIR!"))
	_tap(KEY_ENTER)
	await _frames(3)
	_check("a key moves on to the next", not _text().contains("ALL TRANSPORTS AWAY, SIR!") and not _at_menu())

	# commands 3 to 8 are SHORE LEAVE's
	await _fresh(func() -> void: pass)
	_tap(KEY_3)
	await _frames(3)
	_check("3 before the planet has surrendered: said under the menu",
			_at_menu() and _menu_said() == "SIR! THE PLANET\nHASN'T SURRENDERED!")
	await _shore_leave(here)

	print("ground forces driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


func _shore_leave(here: int) -> void:
	# 3) SHORE LEAVE
	await _fresh(func() -> void: GameState.troop_morale = 4, QUICK, true)
	_tap(KEY_3)
	await _until(_asked_yes_or_no)
	_check("3: the back pay is put, and Y or N asked",
			_said() == "TROOPS READY FOR\nSHORE LEAVE, SIR.\nBACK PAY COMES TO\n2000 CREDITS.\n\nYOU HAVE 10000\nCREDITS.\nPAY THEM?"
			and _title() == "-SHORE LEAVE-")
	_tap(KEY_X)
	await _frames(3)
	_check("a key that is neither is not an answer", _asked_yes_or_no())
	_tap(KEY_Y)
	await _back_at_the_menu()
	_check("Y: paid, in better heart, and ashore here", GameState.credits == 8000.0 and GameState.troop_morale == 5
			and GameState.troop_location == 2 and GameState.troops_stationed_at == here + 1)

	await _fresh(func() -> void: GameState.troop_morale = 4, QUICK, true)
	_tap(KEY_3)
	await _until(_asked_yes_or_no)
	_tap(KEY_N)
	await _back_at_the_menu()
	_check("N: unpaid and the worse for it", GameState.credits == 10000.0 and GameState.troop_morale == 2
			and GameState.troop_location == 2)

	await _fresh(func() -> void:
		GameState.credits = 100.0
		GameState.troop_morale = 5, QUICK, true)
	_tap(KEY_3)
	await _until(_asked_yes_or_no)
	_tap(KEY_Y)
	await _back_at_the_menu()
	_check("Y without the credits: said, and as N", _heard.back() == "YOU DON'T HAVE\nENOUGH CREDITS, SIR!"
			and GameState.credits == 100.0 and GameState.troop_morale == 3)

	# 5) SELL LOOT
	await _fresh(func() -> void: GameState.loot[1] = 2.0, QUICK, true)
	_tap(KEY_5)
	await _back_at_the_menu()
	_check("5: the loot is sold", GameState.credits == 10600.0 and GameState.loot[1] == 0.0 and _heard.back() ==
			"YOU HAD 10000\nCREDITS.\nYOUR LOOT IS WORTH\n600 CREDITS.\n\nTHAT GIVES YOU A\nTOTAL OF 10600\nCREDITS!")

	# 8) CRYOGENICS
	await _fresh(func() -> void: pass, QUICK, true)
	_tap(KEY_8)
	await _back_at_the_menu()
	_check("8: the troops are woken", GameState.troop_location == 0 and _heard == ["TROOPS ARE BEING\nREVIVED, SIR."])

	# 7) ESTABLISH BASE
	var to_build := func() -> void:
		GameState.planet_has_base[here] = false
		GameState.credits = 100000.0
	await _fresh(to_build, QUICK, true)
	_tap(KEY_7)
	await _until(_asked_yes_or_no)
	_check("7: the price is put", _said().begins_with("SIR! IT WILL COST\n") and _said().ends_with("BUILD A BASE?"))
	_tap(KEY_N)
	await _back_at_the_menu()
	_check("N: no base, and the trip's one try gone",
			not GameState.planet_has_base[here] and GameState.credits == 100000.0 and GameState.base_built_this_trip)
	_tap(KEY_7)
	await _back_at_the_menu()
	_check("7 again: only one time a trip", _heard.back() == "ONLY ONE TIME PER\nTRIP, SIR.")

	await _fresh(to_build, QUICK, true)
	_tap(KEY_7)
	await _until(_asked_yes_or_no)
	var cost := _said().split("\n")[1].to_float()
	_tap(KEY_Y)
	await _back_at_the_menu()
	_check("Y: the base is built and paid for", GameState.planet_has_base[here] and cost >= 20000.0
			and GameState.credits == 100000.0 - cost and _heard.back() == "CONSTRUCTION IS\nUNDER WAY, SIR.")

	# 4) ENLIST TROOPS, and the weapons
	await _fresh(func() -> void: pass, QUICK, true)
	_tap(KEY_4)
	await _until(_asked_a_number)
	_check("4: the terms are put and a number asked", _said().ends_with("YOU HAVE 10000\nCREDITS, SIR.\nTROOPS= 2000")
			and _title() == "-ENLIST TROOPS-")
	_tap(KEY_A)
	_tap(KEY_MINUS)
	_tap(KEY_5)
	_tap(KEY_PERIOD)
	await _frames(3)
	_check("only digits are taken", _lines().back().begins_with("HOW MANY TROOPS DO YOU WANT TO ENLIST? 5"))
	await _type("00")
	await _until(func() -> bool: return _title() == "-BUY WEAPONS-" and _asked_a_number())
	_check("500 enlisted", GameState.troops == 2500.0 and GameState.credits == 9500.0 and GameState.enlisted_this_trip)
	var price := _said().split("\n")[-1].trim_prefix("FIGHTERS COST ").to_float()
	_check("the fighters are priced, and what there is is on show", _said().contains("FIGHTERS COST ") and price >= 40.0
			and _lines()[1] == _console.columns("CREDITS", "9500")
			and _lines()[2] == _console.columns("FIGHTERS 75", "TRANSPORTS 6")
			and _lines()[3] == _console.columns("TANKS 0", "MISSILES 0"))
	await _type("300")
	await _until(_asked_a_number)
	_check("300 fighters: BUY 255 MAX., and asked again", "BUY 255 MAX." in _all_said() and _said().ends_with("FIGHTERS COST %d" % price))
	await _type("200")
	await _until(_asked_a_number)
	_check("200 more than there is room for: 255 MAX", "255 MAX" in _all_said() and GameState.gf_fighters == 75.0)
	await _type("2")
	await _until(func() -> bool: return _said().contains("TRANSPORTS COST ") and _asked_a_number())
	_check("2 fighters bought", GameState.gf_fighters == 77.0 and GameState.credits == 9500.0 - 2 * price
			and _lines()[1] == _console.columns("CREDITS", "%d" % GameState.credits)
			and _lines()[2] == _console.columns("FIGHTERS 77", "TRANSPORTS 6"))
	await _type("249")
	await _until(_asked_a_number)
	_check("249 transports: NOT ENOUGH CREDITS", "NOT ENOUGH CREDITS" in _all_said() and GameState.gf_transports == 6.0)
	await _type("")
	await _until(func() -> bool: return _said().contains("TANKS COST ") and _asked_a_number())
	await _type("0")
	await _until(func() -> bool: return _said().contains("MISSILES COST ") and _asked_a_number())
	var before := GameState.credits
	price = _said().split("\n")[-1].trim_prefix("MISSILES COST ").to_float()
	await _type("1")
	await _back_at_the_menu()
	_check("no transports, no tanks and a missile", GameState.gf_transports == 6.0 and GameState.gf_tanks == 0.0
			and GameState.gf_missiles == 1.0 and GameState.credits == before - price)
	_tap(KEY_4)
	await _back_at_the_menu()
	_check("4 again: one time a trip", _heard == ["ONE TIME PER TRIP."] and GameState.troops == 2500.0)

	await _fresh(func() -> void: GameState.credits = 30000.0, QUICK, true)
	_tap(KEY_4)
	await _until(_asked_a_number)
	await _type("18001")
	await _until(_asked_a_number)
	_check("more troops than can be had: said, and asked again",
			"TOO MANY TROOPS." in _all_said() and GameState.troops == 2000.0 and _said().ends_with("TROOPS= 2000"))
	await _type("99999")
	await _until(func() -> bool: return _asked_a_number() and "YOU DON'T HAVE\n99999 CREDITS!" in _all_said())
	await _type("18000")
	await _until(func() -> bool: return _title() == "-BUY WEAPONS-")
	_check("as many as can be had", GameState.troops == 20000.0 and GameState.credits == 12000.0)

	# 6) REPAIR
	var landed := func() -> void:
		GameState.in_atmosphere = true
		GameState.ship_y = 20
		GameState.ship_speed = 0 # the flight beneath stays on the ground
		GameState.credits = 100000.0
		GameState.ship_hull = 40.0
		GameState.ship_energy = 10.0
		GameState.damage_alert_active = true
	await _fresh(func() -> void: GameState.ship_hull = 40.0, QUICK, true)
	_tap(KEY_6)
	await _back_at_the_menu()
	_check("6 in space: land first", _heard == ["YOU MUST LAND ON\nPLANET FIRST."] and GameState.ship_hull == 40.0)

	await _fresh(landed, QUICK, true)
	_tap(KEY_6)
	await _until(func() -> bool: return _lines().size() > 1 and _lines()[1].begins_with("ENERGY"))
	_check("6 on the ground: what is mended, and what it was at",
			_lines()[1] == _console.columns("ENERGY 10%", "HULL DMG. 40%") and _lines()[2].strip_edges() == "MISSILES 60%")
	await _until(_asked_yes_or_no)
	var bill := _said().split("\n")[4].to_float()
	_check("the bill is put", _said().begins_with("ALL REPAIRS ARE\nCOMPLETE, SIR.\nTHE TOTAL REPAIR\nBILL COMES TO\n")
			and _said().contains("YOU HAVE 100000\nCREDITS.") and _said().ends_with("ARE YOU GOING TO PAY, SIR?"))
	_tap(KEY_Y)
	await _back_at_the_menu()
	_check("Y: mended and paid for", GameState.ship_hull == 100.0 and GameState.ship_energy == 63.0
			and GameState.ship_missile_system == 100.0 and GameState.credits == 100000.0 - bill
			and not GameState.damage_alert_active and GameState.gf_planet_surrendered)
	_tap(KEY_6)
	await _back_at_the_menu()
	_check("6 again: nothing to mend, nothing asked",
			_heard == ["ALL REPAIRS ARE\nCOMPLETE, SIR.\nTHE TOTAL REPAIR\nBILL COMES TO\n0 CREDITS.\nYOU HAVE %d\nCREDITS." % GameState.credits]
			and GameState.credits == 100000.0 - bill and GameState.gf_planet_surrendered)

	await _fresh(landed, QUICK, true)
	_tap(KEY_6)
	await _until(_asked_yes_or_no)
	_tap(KEY_N)
	await _back_at_the_menu()
	_check("N: mended all the same, the credits kept and the planet lost",
			GameState.ship_hull == 100.0 and GameState.credits == 100000.0 and not GameState.gf_planet_surrendered
			and GameState.planet_secured[here] == 0 and _heard.back() == "I'M AFRAID YOU'VE\nMADE THE LOCAL\nGOVERNMENT ANGRY!")
	_tap(KEY_6)
	await _frames(3)
	_check("and nothing more to be had of it", _at_menu() and _menu_said() == "SIR! THE PLANET\nHASN'T SURRENDERED!")

	await _fresh(func() -> void:
		landed.call()
		GameState.credits = 3.0
		GameState.ship_hull = 0.0
		GameState.ship_shield = 0.0, QUICK, true)
	_tap(KEY_6)
	await _back_at_the_menu()
	_check("a bill that cannot be met: every credit and the planet",
			GameState.credits == 0.0 and not GameState.gf_planet_surrendered and _heard.back() ==
			"YOU DON'T HAVE\nENOUGH CREDITS!\nYOU HAVE 0 CREDITS\nLEFT!\nI'M AFRAID YOU'VE\nMADE THE LOCAL\nGOVERNMENT ANGRY!")

	# at the game's own pace: what is said stays up, and a key moves on
	await _fresh(func() -> void: pass, 1.0, true)
	_tap(KEY_8)
	await _frames(30)
	_check("at full pace the page stays up", _said() == "TROOPS ARE BEING\nREVIVED, SIR.")
	_tap(KEY_ENTER)
	await _frames(4)
	_check("a key moves on to the menu", _at_menu())

	# RETURN
	await _fresh(func() -> void: pass)
	_tap(KEY_9)
	await _until(func() -> bool: return not _running)
	_check("9 ends the program and gives the display back", not _overlay.program_open and not _globe.visible)


## A new game at SOL with its planet still to take (taken, with a base, for the shore
## leave commands), changed by `with`, the flight up and the program running over it.
func _fresh(with: Callable, pace: float = QUICK, taken := false) -> void:
	_saw_counts = false
	if _console != null and _running:
		_console.close()
		_running = false
	GameState.start_new_game()
	GameState.gf_planet_surrendered = taken
	GameState.planet_has_base[0] = true
	with.call()
	GameState.goto_scene(FLIGHT)
	await _frames(4)
	var scene := get_tree().current_scene
	_console = scene.get("_console")
	_overlay = scene.get_node("Hud/Overlay")
	_globe = scene.get("_globe")
	_console.pace = pace
	_heard = []
	_last_page = ""
	_program = GroundForcesProgram.new()
	_running = true
	_start()
	await _frames(3)


func _start() -> void:
	await _program.run(_console, _globe)
	_running = false


var _saw_counts := false
var _last_page := ""
var _was_menu := false


func _lines() -> Array:
	return _overlay.program


## The page after its title.
func _text() -> String:
	return "\n".join(_lines().slice(1))


func _title() -> String:
	return _lines()[0] if not _lines().is_empty() else ""


func _at_menu() -> bool:
	return _lines().size() > 1 and _lines()[1] == _console.columns("1) ATTACK PLANET", "6) REPAIR/RESTOCK")


## What is said under the menu.
func _menu_said() -> String:
	var at := _lines().find("")
	return "\n".join(_lines().slice(at + 1)) if at >= 0 else ""


func _asked_yes_or_no() -> bool:
	return not _lines().is_empty() and _lines().back().begins_with("Y  YES")


func _asked_a_number() -> bool:
	return _console._mode == "number"


## What a page says, without the question's last line or the Y/N or the typed line.
func _said() -> String:
	var lines: Array = _lines().slice(1)
	if _asked_yes_or_no():
		lines = lines.slice(0, lines.size() - 1)
	elif _asked_a_number():
		lines = lines.slice(0, lines.size() - 1)
	return "\\n".join(lines).replace("\\\\n", "\\n") if false else "\n".join(lines)


## All the pages said so far, joined.
func _all_said() -> String:
	return "\n".join(_heard)


func _back_at_the_menu() -> void:
	await _until(func() -> bool: return not _at_menu())
	await _until(func() -> bool: return _at_menu() or not _running)
	await _frames(2)


## Waits for `done`, taking down what the console says meanwhile.
func _until(done: Callable) -> void:
	for i in TIMEOUT_FRAMES:
		_note()
		if done.call():
			return
		await get_tree().process_frame
	_check("waited for too long", false)


func _note() -> void:
	if _lines().is_empty():
		return
	if _at_menu():
		_was_menu = true
		return
	if _was_menu: # a command was chosen: what it says is afresh
		_was_menu = false
		_heard = []
		_last_page = ""
	var said := _text() if not _asked_yes_or_no() and not _asked_a_number() else _said()
	# the battle screen: its counts are the game's
	if _lines()[0] == "-GROUND FORCES-" and _lines().size() > 2 and _lines()[1].begins_with("FIGHTERS "):
		_saw_counts = _lines()[1].begins_with("FIGHTERS %d" % int(GameState.gf_fighters))
		said = "\n".join(_lines().slice(5)).strip_edges().trim_suffix("\nR  RETREAT").trim_suffix("RETREAT ORDERED").strip_edges()
		# a battle page's report is the lines after the counts' blank row
	if said == "" or said == _last_page:
		return
	_last_page = said
	_heard.append(said)


func _loot() -> float:
	var sum := 0.0
	for amount in GameState.loot:
		sum += amount
	return sum


## Types `digits` and Enter.
func _type(digits: String) -> void:
	for digit in digits:
		_tap(KEY_0 + digit.to_int())
	_tap(KEY_ENTER)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _tap(keycode: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = down
		if keycode >= KEY_0 and keycode <= KEY_9:
			event.unicode = keycode
		elif keycode >= KEY_A and keycode <= KEY_Z:
			event.unicode = keycode + 32
		Input.parse_input_event(event)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1
