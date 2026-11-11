extends Node
## Plays the flight scene (scenes/flight/space_flight.tscn) through the
## keyboard, the way a player would: a new game, then key events put into
## Godot's input queue, and a look at what the game did with them. The
## flight program itself is held to the real game elsewhere
## (check_flight_passes.gd); this is for the scene round it, that keys
## and the stick reach the program and the program's ways out lead
## somewhere.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_flight.tscn
##
## Add `-- --shots <directory>` to save the page on show after each step.
##
## The scene under test replaces the current scene when it leaves for the
## command console, so the driver is a node of its own under the root and
## this scene's root only starts it.

const FLIGHT := "res://scenes/flight/space_flight.tscn"
const COM := "res://scenes/com.tscn"
## Passes the program is given to act on a key.
const PATIENCE := 4
## Frames before a step is given up.
const TIMEOUT_FRAMES := 60 * 240

var _driver := false
var _passes := 0
var _bad := 0
var _shots := ""


func _ready() -> void:
	if _driver:
		_drive.call_deferred()
		return
	var driver := Node.new()
	driver.set_script(get_script())
	driver._driver = true
	driver.name = "FlightDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--shots":
		_shots = args[1]
	GameState.start_new_game()
	GameState.goto_scene(FLIGHT)
	await _scene_is(FLIGHT)
	var scene := get_tree().current_scene
	scene._loop.pass_started = func() -> void: _passes += 1

	await _passes_more(3)
	_shot("1_new_game")
	_check("the view is drawn", _lit_bytes(0, 124) > 0)
	_check("the panel is drawn", _lit_bytes(126, 190) > 0)

	var speed := GameState.ship_speed
	_tap(KEY_1, "1")
	await _passes_more(PATIENCE)
	_check("1 takes 3 off the speed (%d -> %d)" % [speed, GameState.ship_speed],
			GameState.ship_speed == speed - 3)

	var pitch := GameState.ship_pitch
	_key(KEY_UP, true)
	await _passes_more(PATIENCE)
	_key(KEY_UP, false)
	_check("Up held turns the nose (%d -> %d)" % [pitch, GameState.ship_pitch],
			GameState.ship_pitch != pitch)
	_shot("2_pitched")
	await _passes_more(2)
	pitch = GameState.ship_pitch
	await _passes_more(2)
	_check("stick let go, the nose stays (%d)" % pitch, GameState.ship_pitch == pitch)

	var shields := GameState.shields_up
	_tap(KEY_S, "s")
	await _passes_more(PATIENCE)
	_check("S switches the shields", GameState.shields_up != shields)
	_shot("3_shields")

	var laser := GameState.ship_laser
	var missiles := GameState.ship_missile_system
	var shown_before := _passes
	_tap(KEY_SPACE, " ")
	await _passes_more(PATIENCE)
	_check("SPACE fires (%d passes on)" % (_passes - shown_before),
			GameState.ship_laser != laser or GameState.ship_missile_system != missiles
			or GameState.gf_victory_progress > 0.0)
	_shot("4_fired")

	_tap(KEY_C, "c")
	await _scene_is(COM)
	_check("C leaves for the command console", _current_path() == COM)

	print("flight scene driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1


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


func _passes_more(n: int) -> void:
	var until := _passes + n
	for i in range(TIMEOUT_FRAMES):
		if _passes >= until:
			return
		await get_tree().process_frame
	print("WRONG  the program stopped making passes (%d)" % _passes)
	_bad += 1
	get_tree().quit(1)


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


func _lit_bytes(first_row: int, last_row: int) -> int:
	var page: RefCounted = GameState.view3d.pages[GameState.view3d.shown]
	var n := 0
	for i in range(first_row * 40, (last_row + 1) * 40):
		if page.mem[i] != 0:
			n += 1
	return n


func _shot(name_: String) -> void:
	if _shots == "":
		return
	var page: RefCounted = GameState.view3d.pages[GameState.view3d.shown]
	var picture := Image.create(280, 192, false, Image.FORMAT_RGBA8)
	picture.fill(Color.BLACK)
	var drawn: Image = page.image()
	picture.blend_rect(drawn, Rect2i(0, 0, 280, 192), Vector2i.ZERO)
	picture.save_png(_shots.path_join("%s.png" % name_))
