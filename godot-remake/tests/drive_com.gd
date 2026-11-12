extends Node
## Uses the command console (scenes/com.tscn) the way a player would:
## keys put into Godot's input queue, and a look at what is on show and
## where each choice goes. What the console says and does is held to the
## real game in check_com_rules.gd; this is for the scene round it.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_com.tscn
##
## The scenes replace one another, so the driver is a node of its own
## under the root (see drive_radar.gd).

const COM := "res://scenes/com.tscn"
const FLIGHT := "res://scenes/native_flight.tscn"
const END := "res://scenes/end_game.tscn"
const STATUS := "res://scenes/status.tscn"
const SUPPLY := "res://scenes/supply_report.tscn"
const CONSOLE := "Center/Columns/Console/VBox/"
const TIMEOUT_FRAMES := 60 * 30

var _driver := false
var _bad := 0


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
	# the command menu and the lamps
	await _console(func() -> void: GameState.ship_computer = 0.0; GameState.ship_energy = 10.0)
	_check("the command menu", _title() == "COMMAND MODE" and _buttons() == [
			"1) COMPUTER", "2) GROUND FORCES", "3) RADAR", "4) END", "5) RETURN"])
	var lamps: Array = _scene().get_node("Center/Columns/Lamps/VBox/Grid").get_children()
	_check("twelve lamps, the computer's and the power's out", lamps.size() == 12 and _out(lamps) == [2, 6])
	_tap(KEY_X)
	await _frames(3)
	_check("a key that is not a choice is not a choice", _title() == "COMMAND MODE")

	_tap(KEY_1)
	await _frames(3)
	_check("1 with the computer out: said, and the menu again", _title() == "CENTRAL COMPUTER" and _said() == "COMPUTER NOT\nFUNCTIONING.")
	await _until(func() -> bool: return _title() == "COMMAND MODE")
	_check("and the command menu is back", _title() == "COMMAND MODE")

	# the central computer, and the navigation computer
	await _console(func() -> void: pass)
	_tap(KEY_1)
	await _frames(3)
	_check("the central computer", _buttons() == ["1) NAVIGATION COMP.", "2) GALAXY DIRECTORY", "3) GALAXY MAP",
			"4) SHIP STATUS", "5) SUPPLIES REPORT", "6) RETURN"])
	_tap(KEY_1)
	await _frames(3)
	_check("the navigation computer", _title() == "NAVIGATION COMPUTER" and _buttons() == ["1) DIRECTORY", "2) SET COURSE", "3) RETURN"])
	_tap(KEY_2)
	await _frames(3)
	_check("a course is asked for", _entry().visible and _entry_field().has_focus())
	_tap(KEY_A)
	_tap(KEY_7)
	await _frames(2)
	_check("digits only", _entry_field().text == "7")
	_tap(KEY_ENTER)
	await _frames(3)
	_check("7: SIRIUS, course set", _said() == "SIRIUS\nCOURSE SET." and GameState.target_planet == 6)
	await _until(func() -> bool: return _title() == "NAVIGATION COMPUTER" and _buttons().size() == 3)
	_tap(KEY_2)
	await _frames(3)
	_tap(KEY_2)
	_tap(KEY_1)
	_tap(KEY_ENTER)
	await _frames(3)
	_check("21: <ERROR>, the course as it was", _said() == "<ERROR>" and GameState.target_planet == 6)
	await _until(func() -> bool: return _entry().visible and _entry_field().text == "")
	_tap(KEY_1)
	_tap(KEY_ENTER)
	await _frames(3)
	_check("1: where we are", _said() == "THAT'S WHERE WE\nARE NOW, SIR!")
	await _until(func() -> bool: return _entry().visible and _said() == "")

	# the directory
	await _console(func() -> void:
		GameState.planet_scouted[1] = true
		GameState.planet_tech[1] = 3
		GameState.planet_has_base[1] = true)
	_tap(KEY_1)
	await _frames(3)
	_tap(KEY_2)
	await _frames(3)
	_check("the directory: twenty stars", _title() == "GALAXY DIRECTORY" and _node("Stars").get_child_count() == 20
			and (_node("Stars").get_child(1) as Button).text == "2) ALPHA CENTAURI")
	_tap(KEY_3)
	_tap(KEY_ENTER)
	await _frames(3)
	_check("3: BARNARD'S STAR, of which nothing is known",
			_title() == "BARNARD'S STAR STAR SYSTEM" and _said() == "NO INFORMATION AVAILABLE AT THIS TIME.\n")
	(_node("Buttons").get_child(0) as Button).pressed.emit()
	await _frames(3)
	_check("RETURN is the directory", _title() == "GALAXY DIRECTORY")
	(_node("Stars").get_child(1) as Button).pressed.emit()
	await _frames(3)
	_check("a star's button: what is known of ALPHA CENTAURI", _title() == "ALPHA CENTAURI STAR SYSTEM"
			and _said().contains("SOPHISTICATED TECHNOLOGY WITH") and _said().contains("ORBITING DEFENSE CAPABILITY --")
			and _said().contains("THERE IS AN OPERATIONAL REPAIR BASE"))
	(_node("Buttons").get_child(0) as Button).pressed.emit()
	await _frames(3)
	_tap(KEY_3)
	_tap(KEY_0)
	_tap(KEY_ENTER)
	await _frames(3)
	_check("30 is no star: said, and still asked", _said() == "TRY AGAIN PLEASE." and _title() == "GALAXY DIRECTORY")
	(_node("Buttons").get_child(0) as Button).pressed.emit()
	await _frames(3)
	_check("the directory's RETURN is the command menu", _title() == "COMMAND MODE")

	# on from the menus
	for case: Array in [[KEY_2, FLIGHT], [KEY_3, FLIGHT], [KEY_4, END], [KEY_5, FLIGHT]]:
		await _console(func() -> void: pass)
		_tap(case[0])
		await _scene_is(case[1])
		_check("command %d goes to %s" % [case[0] - KEY_0, case[1]], _path() == case[1])
		if case[0] == KEY_2:
			await _frames(5)
			_check("GROUND FORCES is the console's program over the flight", _scene().get("_console").active())
		if case[0] == KEY_3:
			_check("RADAR is told who ran it (38388 = 2)", GameState.handover == 2)
	for case: Array in [[KEY_3, FLIGHT], [KEY_4, STATUS], [KEY_5, SUPPLY]]:
		await _console(func() -> void: pass)
		_tap(KEY_1)
		await _frames(3)
		_tap(case[0])
		await _scene_is(case[1])
		_check("the central computer's %d goes to %s" % [case[0] - KEY_0, case[1]], _path() == case[1])

	# run by the others: the chart's question, and RECALL's and SHORE LEAVE's bounce
	await _console(func() -> void:
		GameState.handover = 5
		GameState.planet_scouted[4] = true)
	_check("the chart's Y: LUYTEN's page, straight away", _title() == "LUYTEN STAR SYSTEM")
	(_node("Buttons").get_child(0) as Button).pressed.emit()
	await _scene_is(FLIGHT)
	await _frames(3)
	_check("and RETURN runs the chart again, the mark taken", _scene().get("_chart").visible and GameState.handover == 0)
	GameState.start_new_game()
	GameState.ground_forces_due = true
	GameState.goto_scene(COM)
	await _scene_is(FLIGHT)
	await _frames(5)
	_check("the bounce goes straight back to GROUND FORCES (its menu up over the flight)",
			_scene().get("_console").active() and _scene().get_node("Hud/Overlay").program[0] == "-GROUND FORCES-" and not GameState.ground_forces_due)

	print("com scene driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## A new game with `with` done to it, and the console up.
func _console(with: Callable) -> void:
	GameState.start_new_game()
	with.call()
	GameState.goto_scene(COM)
	await _scene_is(COM)
	await _frames(3)
	_scene().pace = 0.15


func _scene() -> Node:
	return get_tree().current_scene


func _node(path: String) -> Control:
	return _scene().get_node(CONSOLE + path)


func _title() -> String:
	return (_node("Title") as Label).text


func _said() -> String:
	return (_node("Said") as Label).text


func _entry() -> Control:
	return _node("Entry")


func _entry_field() -> LineEdit:
	return _node("Entry/Field")


func _buttons() -> Array:
	var out := []
	for button: Button in _node("Buttons").get_children():
		out.append(button.text)
	return out


func _out(lamps: Array) -> Array:
	var out := []
	for i in lamps.size():
		var style := (lamps[i] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		if style.bg_color.r > 0.5:
			out.append(i)
	return out


func _path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


func _scene_is(path: String) -> void:
	for i in TIMEOUT_FRAMES:
		if _path() == path:
			return
		await get_tree().process_frame
	_check("never reached %s" % path, false)


func _until(done: Callable) -> void:
	for i in TIMEOUT_FRAMES:
		if done.call():
			return
		await get_tree().process_frame
	_check("waited for too long", false)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _tap(keycode: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = down
		if down and keycode >= KEY_0 and keycode <= KEY_9:
			event.unicode = keycode
		elif down and keycode >= KEY_A and keycode <= KEY_Z:
			event.unicode = keycode + 32
		Input.parse_input_event(event)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1
