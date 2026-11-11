extends Node
## Uses END's menu (scenes/end_game.tscn) the way a player would: keys put
## into Godot's input queue and the buttons, and a look at what it says
## and where it goes. What it says and keeps is held to the real game in
## check_end_rules.gd. "3) END GAME" closes the application and is not
## driven here.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_end.tscn
##
## Saves to a file of its own, not the player's. The scenes replace one
## another, so the driver is a node of its own under the root.

const END := "res://scenes/end_game.tscn"
const FLIGHT := "res://scenes/flight/space_flight.tscn"
const PATH := "user://drive_end.json"
const PANEL := "Center/Panel/VBox/"
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
	driver.name = "EndDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	GameState.save_path = PATH
	_remove()
	await _end(func() -> void: pass)
	_check("the three choices", _buttons() == ["1) SAVE GAME", "2) CONTINUE PRESENT GAME", "3) END GAME"])
	_tap(KEY_X)
	_tap(KEY_9)
	await _frames(3)
	_check("a key that is no choice is no choice (nothing said, no error)", _said() == "" and _path() == END)
	_tap(KEY_1)
	await _frames(3)
	_check("1 saves, and says so", _said() == "GAME SAVED." and FileAccess.file_exists(PATH) and GameState.saved_marker)
	await _until(func() -> bool: return _said() == "")
	_check("and the message goes", _said() == "")

	await _end(func() -> void: GameState.in_atmosphere = true)
	_tap(KEY_1)
	await _frames(3)
	_check("in the atmosphere a save is refused", _said() == "YOU MUST BE IN ORBIT TO SAVE GAME" and not FileAccess.file_exists(PATH)
			and not GameState.saved_marker)

	await _end(func() -> void: pass)
	(_scene().get_node(PANEL + "Buttons").get_child(1) as Button).pressed.emit()
	await _scene_is(FLIGHT)
	_check("2 goes on with the game: the flight, the saved-game mark left", _path() == FLIGHT and GameState.saved_marker)

	_remove()
	print("end scene driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


func _end(with: Callable) -> void:
	_remove()
	GameState.start_new_game()
	with.call()
	GameState.goto_scene(END)
	await _scene_is(END)
	await _frames(3)
	_scene().pace = 0.1


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _scene() -> Control:
	return get_tree().current_scene


func _said() -> String:
	return (_scene().get_node(PANEL + "Said") as Label).text


func _buttons() -> Array:
	var out := []
	for button: Button in _scene().get_node(PANEL + "Buttons").get_children():
		out.append(button.text)
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
		Input.parse_input_event(event)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1
