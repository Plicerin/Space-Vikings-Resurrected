extends Node
## Saves a game and takes it up again through the scenes a player goes
## through: the title's buttons, flight, the command console, END's
## buttons, and the title again after a "reboot". The save itself is
## held to the real game in check_save.gd; this is for the scenes round
## it, and for the original's rule that a saved game is good for one
## boot (START.bas lines 25-26 and 73; GameState.boot()).
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_save.tscn
##
## Saves to a file of its own, not the player's.
##
## The scenes replace one another, so the driver is a node of its own
## under the root (see drive_flight.gd).

const START := "res://scenes/start.tscn"
const FLIGHT := "res://scenes/flight/space_flight.tscn"
const COM := "res://scenes/com.tscn"
const END := "res://scenes/end_game.tscn"
const PATH := "user://drive_save.json"
## Page 1 at the third pass after END's "continue" in the real game
## (tools/mame/save_live.lua).
const LIVE_CONTINUED := "../analysis/live/save/save_continued_p1.bin"
## Frames before a step is given up.
const TIMEOUT_FRAMES := 60 * 240

var _driver := false
var _passes := 0
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

	# a boot with nothing saved
	await _boot()
	await _press("VBox/LoadGameButton")
	_check("O with nothing saved says so", _status() == "THERE IS NO GAME SAVED")
	await _frames(200)
	_check("and the message goes after its three seconds", _status() == "")
	_check("still at the title", _current_path() == START)

	await _press("VBox/NewGameButton")
	await _flight()
	await _passes_more(3)
	var switches := _switches()
	_check("a new game is in flight, switches flipped (%s)" % str(switches),
			switches == [false, true, 3, false])
	await _to_end()
	await _press("VBox/SaveButton")
	_check("1) SAVE GAME saves", _status() == "GAME SAVED." and _saved_mark() == true)

	await _press("VBox/ContinueButton")
	await _flight()
	_check("2) CONTINUE leaves the mark for GALAXY MAP", GameState.saved_marker)
	await _passes_more(3)
	_check("which takes it off", not GameState.saved_marker)
	_check("and touches no switch (%s)" % str(_switches()), _switches() == switches)
	var different := _lamp_rows_different()
	_check("its lamps are the real game's (%d bytes different)" % different, different == 0)

	# the next boot finds the game; the one after does not
	await _to_end()
	await _boot()
	_check("the boot takes the mark off the file", GameState.old_game and _saved_mark() == false)
	await _press("VBox/LoadGameButton")
	await _flight()
	await _passes_more(1)
	_check("O is the saved game, switches as saved (%s)" % str(_switches()),
			_switches() == switches and not GameState.saved_marker)

	await _to_end()
	await _boot()
	await _press("VBox/LoadGameButton")
	_check("a second boot has no game to load", _status() == "THERE IS NO GAME SAVED"
			and _current_path() == START)

	# and a boot answered N uses a saved game up as well
	GameState.save_to_disk()
	await _boot()
	_check("(a game is saved again)", GameState.old_game)
	await _press("VBox/NewGameButton")
	await _flight()
	await _passes_more(1)
	await _to_end()
	await _boot()
	_check("N uses the saved game up too", not GameState.old_game)

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
	await _scene_is(COM)
	await _press("VBox/EndButton")
	await _scene_is(END)


## The machine switched off and on: START.bas from its first line. Only
## from a scene that is not in the middle of a program (END's 3) END
## GAME is where the original stops).
func _boot() -> void:
	GameState.booted = false
	GameState.goto_scene(START)
	await _frames(3)
	await _scene_is(START)


func _flight() -> void:
	await _scene_is(FLIGHT)
	_passes = 0
	get_tree().current_scene._loop.pass_started = func() -> void: _passes += 1


func _switches() -> Array:
	return [GameState.shields_up, GameState.missile_mode_active, GameState.condition,
			GameState.autopilot_active]


func _status() -> String:
	return get_tree().current_scene.get_node("VBox/Status").text


func _saved_mark() -> Variant:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return data.get("saved") if data is Dictionary else null


## The two rows of text cells the eight lamps are in, against the real
## game's page.
func _lamp_rows_different() -> int:
	var live := FileAccess.get_file_as_bytes(LIVE_CONTINUED)
	var page: PackedByteArray = GameState.view3d.pages[0].mem
	if live.size() != page.size():
		return -1
	var different := 0
	for i in range(152 * 40, 168 * 40):
		if page[i] != live[i]:
			different += 1
	return different


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


func _passes_more(n: int) -> void:
	var until := _passes + n
	for i in range(TIMEOUT_FRAMES):
		if _passes >= until:
			return
		await get_tree().process_frame
	print("WRONG  the program stopped making passes (%d)" % _passes)
	_bad += 1
	get_tree().quit(1)


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
