extends Node
## Saves a game and takes it up again through the scenes a player goes
## through: the title's buttons, flight, the command console, END's menu,
## and the title again. The save itself is held in check_save.gd and END's
## rules in check_end_rules.gd; this is for the scenes round them, and for
## CONTINUE: it is there when a game is saved, loads that game, and stays
## after it is used.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_save.tscn
##
## Saves to a file of its own, not the player's.
##
## The scenes replace one another, so the driver is a node of its own
## under the root (see drive_radar.gd).

const START := "res://scenes/start.tscn"
const FLIGHT := "res://scenes/native_flight.tscn"
const PATH := "user://drive_save.json"
## Frames before a step is given up.
const TIMEOUT_FRAMES := 60 * 240

var _driver := false
var _bad := 0


func _ready() -> void:
	if _driver:
		_drive.call_deferred()
		return
	var driver := Node.new()
	driver.set_script(get_script())
	driver._driver = true
	driver.name = "SaveDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	GameState.save_path = PATH
	_remove_file()
	# headless, the window is 64 dots square and the buttons are off it
	get_tree().root.size = Vector2i(1152, 648)

	# nothing saved
	await _title()
	_check("CONTINUE is off with nothing saved", not get_tree().current_scene.can_continue)
	var title := get_tree().current_scene
	_check("the first choice is NEW GAME", title._selected == 0)
	_tap(KEY_DOWN, "")
	await _frames(2)
	_check("DOWN skips CONTINUE (it is off) to QUIT", title._selected == 2)
	_tap(KEY_UP, "")
	await _frames(2)
	_check("UP comes back to NEW GAME", title._selected == 0)

	_tap(KEY_1, "1")
	await _scene_is(FLIGHT)
	GameState.credits = 1234.0
	await _to_end()
	_tap(KEY_1, "1")
	await _frames(3)
	_check("1) SAVE GAME saves, and says so", FileAccess.file_exists(PATH) and _end_said() == "GAME SAVED.")

	_tap(KEY_SPACE, "") # a key cuts the "GAME SAVED." message short
	await _frames(3)
	_tap(KEY_2, "2")
	await _frames(5) # the key is the console's before the scene is changed
	_check("2) CONTINUE goes back to the flight", _current_path() == FLIGHT and not get_tree().current_scene.get("_console").active())

	# the title offers the game, and keeps offering it
	GameState.credits = 0.0
	await _title()
	_check("CONTINUE is on with a game saved", get_tree().current_scene.can_continue)
	_tap(KEY_2, "2")
	await _scene_is(FLIGHT)
	_check("it is the saved game (credits %s)" % GameState.credits, GameState.credits == 1234.0)
	await _title()
	_check("and is still there afterwards", get_tree().current_scene.can_continue)

	_remove_file()
	print("save driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1


func _remove_file() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## The command console's 4) END, from flight.
func _to_end() -> void:
	_tap(KEY_C, "c")
	await _frames(5)
	var overlay: Control = get_tree().current_scene.get_node("Hud/Overlay")
	_check("the command console asks for a command", overlay.program[0] == "-COMMAND MODE-")
	_tap(KEY_4, "4")
	await _frames(4)


func _end_said() -> String:
	return str(get_tree().current_scene.get_node("Hud/Overlay").program[1])


## The title scene started afresh.
func _title() -> void:
	GameState.goto_scene(START)
	await _frames(3)
	await _scene_is(START)


func _continue() -> Button:
	return get_tree().current_scene.get_node("VBox/ContinueButton")


func _current_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


func _scene_is(path: String) -> void:
	for i in range(TIMEOUT_FRAMES):
		if _current_path() == path:
			return
		await get_tree().process_frame
	print("WRONG  never reached %s" % path)
	_bad += 1


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## A click of the mouse on one of the current scene's buttons.
func _press(path: String) -> void:
	var button: Button = get_tree().current_scene.get_node(path)
	var at: Vector2 = button.get_global_rect().get_center()
	at = get_tree().root.get_final_transform() * at
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await _frames(2)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await _frames(2)


func _key(keycode: Key, down: bool, character: String = "") -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = down
	if down and character != "":
		event.unicode = character.unicode_at(0)
	Input.parse_input_event(event)


func _tap(keycode: Key, character: String) -> void:
	_key(keycode, true, character)
	_key(keycode, false)
