extends Node
## Uses the ground forces scene (scenes/ground_forces.tscn) the way a
## player would: keys put into Godot's input queue, on the scene's own
## clock, and a look at what is on show and what became of the game.
## The rules themselves are held to the real game in
## check_ground_rules.gd; this is for the scene round them.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_ground_forces.tscn

const SCENE := "res://scenes/ground_forces.tscn"
const QUICK := 0.02
## Frames before a step is given up.
const TIMEOUT_FRAMES := 60 * 60

var _bad := 0
var _scene: Control
var _heard: Array[String] = [] ## what the battle screen has said, in order


func _ready() -> void:
	_drive.call_deferred()


func _drive() -> void:
	seed(1982)
	var here := 0

	await _fresh(func() -> void: GameState.planet_has_base[here] = false)
	_tap(KEY_3, "3")
	await _frames(3)
	_check("3 with no base: NO BASE, under the menu", _menu().visible and _menu_said() == "NO BASE")

	await _fresh(func() -> void: GameState.troops_stationed_at = here + 2)
	_tap(KEY_1, "1")
	await _frames(3)
	_check("1 with the troops at another star: refused",
			_menu().visible and _menu_said() == "YOU CAN'T ATTACK!\nYOU LEFT\nYOUR TROOPS ON\nANOTHER PLANET!")

	await _fresh(func() -> void:
		GameState.troop_location = 1
		GameState.troops = 1000.0)
	_tap(KEY_2, "2")
	await _frames(3)
	_check("2: the troops are recalled",
			_menu_said() == "TROOPS ARE BEING\nRECALLED, SIR!" and GameState.troop_location == 0)

	await _fresh(func() -> void: GameState.gf_transports = 0.0)
	_tap(KEY_1, "1")
	await _back_at_the_menu()
	_check("1 with no transports: said on the battle screen, then the menu",
			_heard == ["THERE ARE NO TRANSPORTS AVAILABLE!"] and GameState.troop_location != 1)

	await _fresh(func() -> void: GameState.planet_tech[here] = 0)
	_tap(KEY_1, "1")
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
	_tap(KEY_1, "1")
	await _until(func() -> bool: return _retreat().is_visible_in_tree())
	_check("the battle is on: RETREAT is offered", _battle().visible and not _retreat().disabled)
	await _back_at_the_menu()
	_check("the planet surrenders", GameState.gf_planet_surrendered and GameState.planet_secured[here] == 1
			and "THE PLANET HAS SURRENDERED!" in _heard)
	_check("and 100% is on show", _text("Columns/Projection/Success/Percent") == "100%")
	_check("the counts on show are the game's", _text("Columns/Status/Counts/Fighters") == str(int(GameState.gf_fighters))
			and _text("Columns/Status/Counts/Transports") == str(int(GameState.gf_transports)))
	_check("the troops held back are with the rest again", GameState.troops >= 2000.0 and GameState.troops <= 8000.0)
	_check("the loot is collected", _loot() > loot_before and GameState.loot_collected_this_visit
			and _heard.back() == "OPERATION SOL IS A\nSUCCESS, SIR!")

	await _fresh(func() -> void:
		GameState.planet_tech[here] = 4
		GameState.gf_enemy_strength = 255.0
		GameState.troop_morale = 3
		GameState.troops = 6000.0)
	var secured: int = GameState.planet_secured[here]
	_tap(KEY_1, "1")
	await _until(func() -> bool: return _retreat().is_visible_in_tree())
	_tap(KEY_R, "r")
	await _frames(2)
	_check("R: the retreat is ordered", _retreat().disabled and _retreat().text == "RETREAT ORDERED")
	await _back_at_the_menu()
	_check("the troops fall back: morale down one, the planet as it was, the troops still below",
			GameState.troop_morale == 2 and GameState.planet_secured[here] == secured
			and GameState.troop_location == 1 and _heard.back() == "GROUND FORCES RETREATING, SIR!\nPLANET NOT SECURED!")

	await _fresh(func() -> void:
		GameState.planet_tech[here] = 4
		GameState.gf_enemy_strength = 255.0
		GameState.troop_morale = 1
		GameState.troops = 3.0)
	_tap(KEY_1, "1")
	await _back_at_the_menu()
	_check("a battle lost: no troops below, none left",
			GameState.troop_location == 0 and GameState.troops == 0.0
			and _heard.back() == "THE BATTLE IS LOST! ALL TROOPS\nHAVE BEEN DESTROYED!!!")

	# at the game's own pace: a report stays up, and Enter moves on
	await _fresh(func() -> void: GameState.planet_tech[here] = 0, 1.0)
	_tap(KEY_1, "1")
	await _frames(30)
	_check("at full pace the first report stays up", _text("Said") == "ALL TRANSPORTS AWAY, SIR!")
	_tap(KEY_ENTER, "")
	await _frames(3)
	_check("Enter moves on to the next", _battle().visible and _text("Said") != "ALL TRANSPORTS AWAY, SIR!")

	var elsewhere: Dictionary = load("res://scripts/ui/ground_forces.gd").ELSEWHERE
	var missing := []
	for number in range(3, 9):
		if not ResourceLoader.exists("res://scenes/%s.tscn" % elsewhere.get(number, "?")):
			missing.append(number)
	_check("commands 3 to 8 each have a scene to go to", missing.is_empty())

	print("ground forces scene driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## A new game at SOL with its planet still to take, changed by `with`,
## and the scene put up over it.
func _fresh(with: Callable, pace: float = QUICK) -> void:
	if _scene != null:
		_scene.queue_free()
		await _frames(2)
	GameState.start_new_game()
	GameState.gf_planet_surrendered = false
	GameState.planet_has_base[0] = true
	with.call()
	_heard = []
	_scene = load(SCENE).instantiate()
	_scene.pace = pace
	add_child(_scene)
	await _frames(2)


func _back_at_the_menu() -> void:
	await _until(func() -> bool: return _battle().visible)
	await _until(func() -> bool: return _menu().visible)
	await _frames(4) # the numbers run out


func _until(done: Callable) -> void:
	for i in TIMEOUT_FRAMES:
		var said := _text("Said")
		if _battle().visible and said != "" and (_heard.is_empty() or _heard.back() != said):
			_heard.append(said)
		if done.call():
			return
		await get_tree().process_frame
	_check("waited for too long", false)


func _menu() -> Control:
	return _scene.get_node("Center/Menu")


func _battle() -> Control:
	return _scene.get_node("Center/Battle")


func _retreat() -> Button:
	return _scene.get_node("Center/Battle/VBox/Orders/Retreat")


func _menu_said() -> String:
	return (_scene.get_node("Center/Menu/VBox/Said") as Label).text


func _text(path: String) -> String:
	return (_scene.get_node("Center/Battle/VBox/" + path) as Label).text


func _loot() -> float:
	var sum := 0.0
	for amount in GameState.loot:
		sum += amount
	return sum


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
