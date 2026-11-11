extends Node
## Uses GROUND FORCES' commands 3 to 8 (scenes/shore_leave.tscn, put up
## by scenes/ground_forces.tscn) the way a player would: keys put into
## Godot's input queue, on the scene's own clock, and a look at what is
## on show and what became of the game. The rules themselves are held
## to the real game in check_shore_rules.gd; this is for the scene
## round them.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_shore_leave.tscn

const SCENE := "res://scenes/ground_forces.tscn"
const PANEL := "ShoreLeave/Center/Panel/VBox/"
const QUICK := 0.02
## Frames before a step is given up.
const TIMEOUT_FRAMES := 60 * 60

var _bad := 0
var _scene: Control
var _heard: Array[String] = [] ## what the panel now or last up has said, in order
var _panel := 0 ## and which panel that is


func _ready() -> void:
	_drive.call_deferred()


func _drive() -> void:
	seed(1982)
	var here := 0

	# 3) SHORE LEAVE
	await _fresh(func() -> void: GameState.troop_morale = 4)
	_tap(KEY_3, "3")
	await _until(_asked_yes_or_no)
	_check("3: the back pay is put, and Y or N asked",
			_said() == "TROOPS READY FOR\nSHORE LEAVE, SIR.\nBACK PAY COMES TO\n2000 CREDITS.\n\nYOU HAVE 10000\nCREDITS."
			and _label("Asked/Question") == "PAY THEM?")
	_tap(KEY_X, "x")
	await _frames(3)
	_check("a key that is neither is not an answer", _asked_yes_or_no())
	_tap(KEY_Y, "y")
	await _back_at_the_menu()
	_check("Y: paid, in better heart, and ashore here", GameState.credits == 8000.0 and GameState.troop_morale == 5
			and GameState.troop_location == 2 and GameState.troops_stationed_at == here + 1)

	await _fresh(func() -> void: GameState.troop_morale = 4)
	_tap(KEY_3, "3")
	await _until(_asked_yes_or_no)
	_tap(KEY_N, "n")
	await _back_at_the_menu()
	_check("N: unpaid and the worse for it", GameState.credits == 10000.0 and GameState.troop_morale == 2
			and GameState.troop_location == 2)

	await _fresh(func() -> void:
		GameState.credits = 100.0
		GameState.troop_morale = 5)
	_tap(KEY_3, "3")
	await _until(_asked_yes_or_no)
	_tap(KEY_Y, "y")
	await _back_at_the_menu()
	_check("Y without the credits: said, and as N", _heard.back() == "YOU DON'T HAVE\nENOUGH CREDITS, SIR!"
			and GameState.credits == 100.0 and GameState.troop_morale == 3)

	# 5) SELL LOOT
	await _fresh(func() -> void: GameState.loot[1] = 2.0)
	_tap(KEY_5, "5")
	await _back_at_the_menu()
	_check("5: the loot is sold", GameState.credits == 10600.0 and GameState.loot[1] == 0.0 and _heard.back() ==
			"YOU HAD 10000\nCREDITS.\nYOUR LOOT IS WORTH\n600 CREDITS.\n\nTHAT GIVES YOU A\nTOTAL OF 10600\nCREDITS!")

	# 8) CRYOGENICS
	await _fresh(func() -> void: pass)
	_tap(KEY_8, "8")
	await _back_at_the_menu()
	_check("8: the troops are woken", GameState.troop_location == 0 and _heard == ["TROOPS ARE BEING\nREVIVED, SIR."])

	# 7) ESTABLISH BASE
	var to_build := func() -> void:
		GameState.planet_has_base[here] = false
		GameState.credits = 100000.0
	await _fresh(to_build)
	_tap(KEY_7, "7")
	await _until(_asked_yes_or_no)
	_check("7: the price is put", _said().begins_with("SIR! IT WILL COST\n") and _label("Asked/Question") == "BUILD A BASE?")
	_tap(KEY_N, "n")
	await _back_at_the_menu()
	_check("N: no base, and the trip's one try gone",
			not GameState.planet_has_base[here] and GameState.credits == 100000.0 and GameState.base_built_this_trip)
	_tap(KEY_7, "7")
	await _back_at_the_menu()
	_check("7 again: only one time a trip", _heard.back() == "ONLY ONE TIME PER\nTRIP, SIR.")

	await _fresh(to_build)
	_tap(KEY_7, "7")
	await _until(_asked_yes_or_no)
	var cost := _said().split("\n")[1].to_float()
	_tap(KEY_Y, "y")
	await _back_at_the_menu()
	_check("Y: the base is built and paid for", GameState.planet_has_base[here] and cost >= 20000.0
			and GameState.credits == 100000.0 - cost and _heard.back() == "CONSTRUCTION IS\nUNDER WAY, SIR.")

	# 4) ENLIST TROOPS, and the weapons
	await _fresh(func() -> void: pass)
	_tap(KEY_4, "4")
	await _until(_asked_a_number)
	_check("4: the terms are put and a number asked", _said().ends_with("YOU HAVE 10000\nCREDITS, SIR.\nTROOPS= 2000")
			and _label("Title") == "ENLIST TROOPS")
	_tap(KEY_A, "a")
	_tap(KEY_MINUS, "-")
	_tap(KEY_5, "5")
	_tap(KEY_PERIOD, ".")
	await _frames(3)
	_check("only digits are taken", _entry().text == "5")
	await _type("00")
	await _until(func() -> bool: return _label("Title") == "BUY WEAPONS" and _asked_a_number())
	_check("500 enlisted", GameState.troops == 2500.0 and GameState.credits == 9500.0 and GameState.enlisted_this_trip)
	var price := _said().trim_prefix("FIGHTERS COST ").to_float()
	_check("the fighters are priced, and what there is is on show", _said().begins_with("FIGHTERS COST ") and price >= 40.0
			and _table() == ["CREDITS", "9500", "FIGHTERS", "75", "TRANSPORTS", "6", "TANKS", "0", "MISSILES", "0"])
	await _type("300")
	await _until(_asked_a_number)
	_check("300 fighters: BUY 255 MAX., and asked again", "BUY 255 MAX." in _heard and _said() == "FIGHTERS COST %d" % price)
	await _type("200")
	await _until(_asked_a_number)
	_check("200 more than there is room for: 255 MAX", "255 MAX" in _heard and GameState.gf_fighters == 75.0)
	await _type("2")
	await _until(func() -> bool: return _said().begins_with("TRANSPORTS COST ") and _asked_a_number())
	_check("2 fighters bought", GameState.gf_fighters == 77.0 and GameState.credits == 9500.0 - 2 * price
			and _table().slice(0, 4) == ["CREDITS", "%d" % GameState.credits, "FIGHTERS", "77"])
	await _type("249")
	await _until(_asked_a_number)
	_check("249 transports: NOT ENOUGH CREDITS", "NOT ENOUGH CREDITS" in _heard and GameState.gf_transports == 6.0)
	await _type("")
	await _until(func() -> bool: return _said().begins_with("TANKS COST ") and _asked_a_number())
	await _type("0")
	await _until(func() -> bool: return _said().begins_with("MISSILES COST ") and _asked_a_number())
	var before := GameState.credits
	price = _said().trim_prefix("MISSILES COST ").to_float()
	await _type("1")
	await _back_at_the_menu()
	_check("no transports, no tanks and a missile", GameState.gf_transports == 6.0 and GameState.gf_tanks == 0.0
			and GameState.gf_missiles == 1.0 and GameState.credits == before - price)
	_tap(KEY_4, "4")
	await _back_at_the_menu()
	_check("4 again: one time a trip", _heard == ["ONE TIME PER TRIP."] and GameState.troops == 2500.0)

	await _fresh(func() -> void: GameState.credits = 30000.0)
	_tap(KEY_4, "4")
	await _until(_asked_a_number)
	await _type("18001")
	await _until(_asked_a_number)
	_check("more troops than can be had: said, and asked again",
			"TOO MANY TROOPS." in _heard and GameState.troops == 2000.0 and _said().ends_with("TROOPS= 2000"))
	await _type("99999")
	await _until(func() -> bool: return _asked_a_number() and "YOU DON'T HAVE\n99999 CREDITS!" in _heard)
	await _type("18000")
	await _until(func() -> bool: return _label("Title") == "BUY WEAPONS")
	_check("as many as can be had", GameState.troops == 20000.0 and GameState.credits == 12000.0)

	# 6) REPAIR
	var landed := func() -> void:
		GameState.in_atmosphere = true
		GameState.ship_y = 20
		GameState.credits = 100000.0
		GameState.ship_hull = 40.0
		GameState.ship_energy = 10.0
		GameState.damage_alert_active = true
	await _fresh(func() -> void: GameState.ship_hull = 40.0)
	_tap(KEY_6, "6")
	await _back_at_the_menu()
	_check("6 in space: land first", _heard == ["YOU MUST LAND ON\nPLANET FIRST."] and GameState.ship_hull == 40.0)

	await _fresh(landed)
	_tap(KEY_6, "6")
	await _until(func() -> bool: return not _table().is_empty())
	_check("6 on the ground: what is mended, and what it was at",
			_table() == ["ENERGY", "10%", "HULL DMG.", "40%", "MISSILES", "60%"])
	await _until(_asked_yes_or_no)
	var bill := _said().split("\n")[4].to_float()
	_check("the bill is put", _said().begins_with("ALL REPAIRS ARE\nCOMPLETE, SIR.\nTHE TOTAL REPAIR\nBILL COMES TO\n")
			and _said().ends_with("YOU HAVE 100000\nCREDITS.") and _label("Asked/Question") == "ARE YOU GOING TO PAY, SIR?")
	_tap(KEY_Y, "y")
	await _back_at_the_menu()
	_check("Y: mended and paid for", GameState.ship_hull == 100.0 and GameState.ship_energy == 63.0
			and GameState.ship_missile_system == 100.0 and GameState.credits == 100000.0 - bill
			and not GameState.damage_alert_active and GameState.gf_planet_surrendered)
	_tap(KEY_6, "6")
	await _back_at_the_menu()
	_check("6 again: nothing to mend, nothing asked",
			_heard == ["ALL REPAIRS ARE\nCOMPLETE, SIR.\nTHE TOTAL REPAIR\nBILL COMES TO\n0 CREDITS.\nYOU HAVE %d\nCREDITS." % GameState.credits]
			and GameState.credits == 100000.0 - bill and GameState.gf_planet_surrendered)

	await _fresh(landed)
	_tap(KEY_6, "6")
	await _until(_asked_yes_or_no)
	_tap(KEY_N, "n")
	await _back_at_the_menu()
	_check("N: mended all the same, the credits kept and the planet lost",
			GameState.ship_hull == 100.0 and GameState.credits == 100000.0 and not GameState.gf_planet_surrendered
			and GameState.planet_secured[here] == 0 and _heard.back() == "I'M AFRAID YOU'VE\nMADE THE LOCAL\nGOVERNMENT ANGRY!")
	_tap(KEY_6, "6")
	await _frames(3)
	_check("and nothing more to be had of it", _scene.get_node("Center/Menu").visible
			and (_scene.get_node("Center/Menu/VBox/Said") as Label).text == "SIR! THE PLANET\nHASN'T SURRENDERED!")

	await _fresh(func() -> void:
		landed.call()
		GameState.credits = 3.0
		GameState.ship_hull = 0.0
		GameState.ship_shield = 0.0)
	_tap(KEY_6, "6")
	await _back_at_the_menu()
	_check("a bill that cannot be met: every credit and the planet",
			GameState.credits == 0.0 and not GameState.gf_planet_surrendered and _heard.back() ==
			"YOU DON'T HAVE\nENOUGH CREDITS!\nYOU HAVE 0 CREDITS\nLEFT!\nI'M AFRAID YOU'VE\nMADE THE LOCAL\nGOVERNMENT ANGRY!")

	# at the game's own pace: what is said stays up, and Enter moves on
	await _fresh(func() -> void: pass, 1.0)
	_tap(KEY_8, "8")
	await _frames(30)
	_check("at full pace the panel stays up", _scene.has_node("ShoreLeave") and _said() == "TROOPS ARE BEING\nREVIVED, SIR.")
	_tap(KEY_ENTER, "")
	await _frames(4)
	_check("Enter moves on to the menu", not _scene.has_node("ShoreLeave") and _scene.get_node("Center/Menu").visible)

	print("shore leave scene driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## A new game at SOL, its planet taken and with a base, changed by
## `with`, and the ground forces scene put up over it.
func _fresh(with: Callable, pace: float = QUICK) -> void:
	if _scene != null:
		_scene.queue_free()
		await _frames(2)
	GameState.start_new_game()
	GameState.gf_planet_surrendered = true
	GameState.planet_has_base[0] = true
	with.call()
	_scene = load(SCENE).instantiate()
	_scene.pace = pace
	add_child(_scene)
	await _frames(2)


func _back_at_the_menu() -> void:
	await _until(func() -> bool: return _scene.has_node("ShoreLeave"))
	await _until(func() -> bool: return not _scene.has_node("ShoreLeave"))
	await _frames(2)


## Waits for `done`, taking down what the panel says meanwhile. `_heard`
## starts afresh with every command.
func _until(done: Callable) -> void:
	for i in TIMEOUT_FRAMES:
		if _scene.has_node("ShoreLeave"):
			var panel := _scene.get_node("ShoreLeave").get_instance_id()
			if panel != _panel:
				_panel = panel
				_heard = []
			var said := _said()
			if said != "" and (_heard.is_empty() or _heard.back() != said):
				_heard.append(said)
		if done.call():
			return
		await get_tree().process_frame
	_check("waited for too long", false)


func _asked_yes_or_no() -> bool:
	return _scene.has_node("ShoreLeave") and (_scene.get_node(PANEL + "Asked/Answers") as Control).is_visible_in_tree()


func _asked_a_number() -> bool:
	return _scene.has_node("ShoreLeave") and _entry().is_visible_in_tree() and _entry().has_focus()


func _entry() -> LineEdit:
	return _scene.get_node(PANEL + "Asked/Entry")


func _said() -> String:
	return _label("Said")


func _label(path: String) -> String:
	return (_scene.get_node(PANEL + path) as Label).text


## The table's cells, row by row; none when it is not on show.
func _table() -> Array:
	var cells := []
	if _scene.has_node("ShoreLeave") and (_scene.get_node(PANEL + "Table") as Control).is_visible_in_tree():
		for cell: Label in _scene.get_node(PANEL + "Table").get_children():
			cells.append(cell.text)
	return cells


## Types `digits` and RETURN.
func _type(digits: String) -> void:
	for digit in digits:
		_tap(KEY_0 + digit.to_int(), digit)
	_tap(KEY_ENTER, "")
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _tap(keycode: Key, character: String) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = down
		if down and character != "":
			event.unicode = character.unicode_at(0)
		Input.parse_input_event(event)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1
