extends Node
## Uses the command console (scripts/flight/command_console_program.gd), the
## reports (reports_program.gd) and END (end_program.gd) the way a player would:
## C in the flight, keys put into Godot's input queue, on the console's own
## clock, and a look at what the display says and where each choice goes. What
## each choice does and says is held to the real game in check_com_rules.gd,
## check_report_rules.gd and check_end_rules.gd; this is for the programs round
## them.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_com.tscn

const FLIGHT := "res://scenes/native_flight.tscn"
const ChartRules = preload("res://scripts/rules/chart_rules.gd")
const QUICK := 0.02
const SAVE := "user://drive_com_save.json"
const TIMEOUT_FRAMES := 60 * 30

var _driver := false
var _bad := 0
var _scene: Node
var _console: Node
var _overlay: Control


## The scenes replace one another, so the driver is a node of its own under the root.
func _ready() -> void:
	if _driver:
		_drive.call_deferred()
		return
	var driver := Node.new()
	driver.set_script(get_script())
	driver._driver = true
	driver.name = "ComDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	GameState.save_path = SAVE
	# the command menu
	await _open(func() -> void: GameState.ship_computer = 0.0)
	_check("C puts the console up: the command menu", _lines() == ["-COMMAND MODE-", "1) COMPUTER", "2) GROUND FORCES", "3) RADAR", "4) END", "5) RETURN"]
			and _overlay.program_open)
	_tap(KEY_X)
	await _frames(3)
	_check("a key that is not a choice is not a choice", _title() == "COMMAND MODE")
	_tap(KEY_1)
	await _frames(3)
	_check("1 with the computer out: said, and the menu again", _title() == "CENTRAL COMPUTER" and _lines()[1] == "COMPUTER NOT FUNCTIONING.")
	await _until(func() -> bool: return _title() == "COMMAND MODE")
	_check("and the command menu is back", _title() == "COMMAND MODE")

	# the central computer, and the navigation computer
	await _open(func() -> void: pass)
	_tap(KEY_1)
	await _frames(3)
	_check("the central computer: five choices (the galaxy map is in the directory)", _lines() == ["-CENTRAL COMPUTER-",
			"1) NAVIGATION COMP.", "2) GALAXY DIRECTORY", "3) SHIP STATUS", "4) SUPPLIES REPORT", "5) RETURN"])
	_tap(KEY_1)
	await _frames(3)
	_check("the navigation computer", _lines() == ["-NAVIGATION COMPUTER-", "1) DIRECTORY", "2) SET COURSE", "3) RETURN"])
	_tap(KEY_2)
	await _frames(3)
	_check("a course is asked for", _console._mode == "number" and _lines().back().begins_with("ENTER DESIRED DESTINATION (1-20) "))
	_tap(KEY_A)
	_tap(KEY_7)
	await _frames(2)
	_check("digits only (and the star typed is named at the foot)", _lines()[-2].begins_with("ENTER DESIRED DESTINATION (1-20) 7"))
	_tap(KEY_ENTER)
	await _until(func() -> bool: return _lines().size() > 1 and _lines()[1] == "SIRIUS COURSE SET.")
	_check("7: SIRIUS, course set", _lines()[1] == "SIRIUS COURSE SET." and GameState.target_planet == 6)
	await _until(func() -> bool: return _title() == "NAVIGATION COMPUTER" and _lines().size() == 4)
	_tap(KEY_2)
	await _frames(3)
	_tap(KEY_2)
	_tap(KEY_1)
	_tap(KEY_ENTER)
	await _frames(3)
	_check("21: <ERROR>, the course as it was", _lines()[1] == "<ERROR>" and GameState.target_planet == 6)
	await _until(func() -> bool: return _console._mode == "number")
	_tap(KEY_1)
	_tap(KEY_ENTER)
	await _frames(3)
	_check("1: where we are", _lines()[1] == "THAT'S WHERE WE ARE NOW, SIR!")
	await _until(func() -> bool: return _console._mode == "number")
	_tap(KEY_ESCAPE)
	await _until(func() -> bool: return _title() == "NAVIGATION COMPUTER")
	_tap(KEY_3)
	await _frames(3)
	_check("RETURN is the command menu", _title() == "COMMAND MODE")

	# the directory
	await _open(func() -> void:
		GameState.planet_scouted[1] = true
		GameState.planet_tech[1] = 3
		GameState.planet_has_base[1] = true)
	_tap(KEY_1)
	await _frames(3)
	_tap(KEY_2)
	await _frames(3)
	_check("the directory: twenty stars in two columns", _title() == "GALAXY DIRECTORY"
			and _lines()[1] == _console.columns("1) SOL", "11) CYGNI") and _lines()[2] == _console.columns("2) ALPHA CENTAURI", "12) PROCYON")
			and _lines()[10] == _console.columns("10) EPSILON ERIDANA", "20) SHIVANDA") and _console._mode == "number")
	var directory_map: Control = _scene.get("_chart")
	_check("the directory has the galaxy map up to click a star on", directory_map.visible and directory_map.picking)
	_tap(KEY_3)
	_tap(KEY_ENTER)
	await _frames(3)
	_check("3: BARNARD'S STAR, of which nothing is known",
			_title() == "BARNARD'S STAR STAR SYSTEM" and _lines()[2] == "NO INFORMATION AVAILABLE AT THIS TIME.")
	_tap(KEY_SPACE)
	await _frames(3)
	_check("a key is the directory again", _title() == "GALAXY DIRECTORY")
	_tap(KEY_2)
	_tap(KEY_ENTER)
	await _frames(3)
	var page := _text()
	_check("2: what is known of ALPHA CENTAURI", _title() == "ALPHA CENTAURI STAR SYSTEM" and page.contains("SOPHISTICATED TECHNOLOGY WITH")
			and page.contains("ORBITING DEFENSE CAPABILITY --") and page.contains("THERE IS AN OPERATIONAL REPAIR BASE"))
	_check("with where it is and how far, as the map says it", _lines()[1].begins_with("LOC. : "))
	_tap(KEY_SPACE)
	await _frames(3)
	var clicked := InputEventMouseButton.new() # a click on LUYTEN, 5, on the map
	clicked.button_index = MOUSE_BUTTON_LEFT
	clicked.pressed = true
	clicked.position = directory_map._map.position + ChartRules.place(5) * directory_map._scale
	directory_map._gui_input(clicked)
	await _frames(3)
	_tap(KEY_ENTER)
	await _frames(3)
	_check("a click on the map then Enter: LUYTEN's page", _title() == "LUYTEN STAR SYSTEM")
	_tap(KEY_SPACE)
	await _frames(3)
	_tap(KEY_3)
	_tap(KEY_0)
	_tap(KEY_ENTER)
	await _frames(3)
	_check("30 is no star: said", _lines().has("TRY AGAIN PLEASE.") and _title() == "GALAXY DIRECTORY")
	await _until(func() -> bool: return _console._mode == "number")
	_check("and still asked", _console._mode == "number")
	_tap(KEY_ESCAPE)
	await _frames(3)
	_check("Escape from the directory: back to the command menu, the map put away", _title() == "COMMAND MODE" and not directory_map.visible)

	# on from the menus
	await _open(func() -> void: pass)
	_tap(KEY_2)
	await _frames(4)
	_check("2: GROUND FORCES, on the console, the globe up", _title() == "GROUND FORCES" and _scene.get("_globe").visible)
	_tap(KEY_9)
	await _frames(4)
	_check("its RETURN is the command menu", _title() == "COMMAND MODE" and not _scene.get("_globe").visible)

	_tap(KEY_3)
	await _frames(4)
	_check("3: the radar, over the flight; told who ran it (38388 = 2)", _scene.get("_radar").visible and GameState.handover == 2 and not _console.active())
	_tap(KEY_X)
	await _frames(4)
	_check("X goes back to the command menu, the mark taken", _title() == "COMMAND MODE" and GameState.handover == 0 and not _scene.get("_radar").visible)

	await _open(func() -> void: GameState.ship_radar = 0.0)
	_tap(KEY_3)
	await _frames(4)
	_check("with no radar: nothing shown, back at the command menu", not _scene.get("_radar").visible and _title() == "COMMAND MODE" and GameState.handover == 0)

	_tap(KEY_5)
	await _frames(4)
	_check("5: RETURN closes the console", not _console.active() and not _overlay.program_open)
	_tap(KEY_C)
	await _frames(4)
	_check("and C brings it up again", _title() == "COMMAND MODE")

	# the two reports
	await _open(func() -> void: pass)
	_tap(KEY_1)
	await _frames(3)
	_tap(KEY_3)
	await _frames(3)
	_check("3: the ship status, its first page", _title() == "SHIP STATUS REPORT" and _lines()[1] == "LOCATION  SOL"
			and _lines().has(_console.columns("ENERGY    100%", "CREDITS   10000")))
	_tap(KEY_SPACE)
	await _frames(3)
	_check("a key: the troops", _title() == "TROOP STATUS" and _lines()[1].begins_with("TROOPS 2000"))
	_tap(KEY_SPACE)
	await _frames(3)
	_check("and a key, the command menu", _title() == "COMMAND MODE")
	_tap(KEY_1)
	await _frames(3)
	_tap(KEY_4)
	await _frames(3)
	_check("4: the supply report, its first page", _title() == "SUPPLY REPORT" and _lines().size() == 9 and _lines()[1].begins_with("PLATINUM"))
	_tap(KEY_SPACE)
	await _frames(3)
	_check("a key: the rest, and the credits", _lines().back() == "ANY KEY  RETURN" and _lines()[-2].begins_with("CREDITS"))
	_tap(KEY_SPACE)
	await _frames(3)
	_check("and a key, the command menu", _title() == "COMMAND MODE")

	# END
	_remove_save()
	await _open(func() -> void: pass)
	_tap(KEY_4)
	await _frames(4)
	_check("4: END, three choices", _lines() == ["-END GAME-", "1) SAVE GAME", "2) CONTINUE PRESENT GAME", "3) END GAME"])
	_tap(KEY_X)
	_tap(KEY_9)
	await _frames(3)
	_check("a key that is no choice is no choice", _title() == "END GAME" and _lines().size() == 4)
	_tap(KEY_1)
	await _frames(4)
	_check("1 saves, and says so", _lines()[1] == "GAME SAVED." and FileAccess.file_exists(SAVE))
	await _until(func() -> bool: return _lines().size() == 4)
	await _open(func() -> void: GameState.in_atmosphere = true)
	_remove_save()
	_tap(KEY_4)
	await _frames(4)
	_tap(KEY_1)
	await _frames(4)
	_check("in the atmosphere a save is refused", _lines()[1] == "YOU MUST BE IN ORBIT TO SAVE GAME" and not FileAccess.file_exists(SAVE))
	await _until(func() -> bool: return _lines().size() == 4)
	_tap(KEY_2)
	await _frames(4)
	_check("2 goes on with the game: the console is closed", not _console.active() and not _overlay.program_open)

	# Escape goes back a screen, and a click on the galaxy map names the destination
	await _open(func() -> void: pass)
	_tap(KEY_1)
	await _frames(3)
	_tap(KEY_1)
	await _frames(3)
	_check("the navigation computer is up", _title() == "NAVIGATION COMPUTER")
	_tap(KEY_ESCAPE)
	await _frames(3)
	_check("Escape is RETURN: back, to the command menu", _title() == "COMMAND MODE")
	_tap(KEY_ESCAPE)
	await _frames(3)
	_check("and Escape in the command menu is RETURN: the console is closed", not _console.active())
	_tap(KEY_C)
	await _frames(4)
	_tap(KEY_1)
	await _frames(3)
	_tap(KEY_1)
	await _frames(3)
	_tap(KEY_2)
	await _until(func() -> bool: return _console._mode == "number")
	var map: Control = _scene.get("_chart")
	_check("setting a course: the galaxy map is up to pick from", map.visible and map.picking)
	await _frames(3)
	var star := 7 # SIRIUS
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map._map.position + ChartRules.place(star) * map._scale
	map._gui_input(click)
	await _frames(3)
	var typed := str(_lines()[-2])
	_check("a click on a star types its number (%s)" % typed, typed.begins_with("ENTER DESIRED DESTINATION (1-20) 7"))
	_check("and its name is at the foot of the console", _lines().back() == "SIRIUS")
	_check("and the star is ringed on the map", map._focus == star)
	_tap(KEY_ENTER)
	await _until(func() -> bool: return GameState.target_planet == star - 1)
	_check("Enter sets the course to it", GameState.target_planet == star - 1)

	_remove_save()
	print("command console driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## A new game, changed by `with`, the flight up, the console opened with C.
func _open(with: Callable) -> void:
	GameState.start_new_game()
	GameState.save_path = SAVE
	with.call()
	GameState.goto_scene(FLIGHT)
	await _frames(4)
	_scene = get_tree().current_scene
	_console = _scene.get("_console")
	_overlay = _scene.get_node("Hud/Overlay")
	_console.pace = QUICK
	_tap(KEY_C)
	await _frames(4)


func _lines() -> Array:
	return _overlay.program


func _title() -> String:
	return str(_lines()[0]).trim_prefix("-").trim_suffix("-") if not _lines().is_empty() else ""


func _text() -> String:
	return "\n".join(_lines().slice(1))


func _until(done: Callable) -> void:
	for i in TIMEOUT_FRAMES:
		if done.call():
			return
		await get_tree().process_frame
	_check("waited for too long", false)


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


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
		if not _lines().is_empty():
			print("   page: ", _lines())
