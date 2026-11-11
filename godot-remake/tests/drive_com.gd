extends Node
## Uses the command console scene (scenes/com.tscn) the way a player
## would: key events put into Godot's input queue, on the scene's own
## clock, and a look at what came of them. What COM draws is held to the
## real game in check_com.gd; this is for the scene round it, that the
## keys reach the program as the Apple's keyboard would have given them,
## and that every way out of it leads to the scene of the program the
## original ran.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_com.tscn
##
## Add `-- --shots <directory>` to save the page on show after each step.
##
## COM replaces the current scene when it leaves, so the driver is a node
## of its own under the root (see drive_flight.gd).

const COM := "res://scenes/com.tscn"
const FLIGHT := "res://scenes/flight/space_flight.tscn"
const SCENES := "res://scenes/%s.tscn"
## Frames before a step is given up.
const TIMEOUT_FRAMES := 60 * 120

var _driver := false
var _seen := {}
var _bad := 0
var _shots := ""


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
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--shots":
		_shots = args[1]
	GameState.start_new_game()
	# as flight leaves the page: the panel, and TRANLIT's four switches
	var flight: RefCounted = load("res://scripts/flight/flight_program.gd").new()
	flight.instruments()
	var text: RefCounted = GameState.chargen

	await _com()
	await _seen_more("command")
	_check("COM asks for a command", [text.column, text.row] == [9, 9])
	_shot("1_command")

	_tap(KEY_Q, "q")
	await _seen_more("command")
	_check("a key that is no command: asked again", true)

	_tap(KEY_1, "1")
	await _seen_more("central")
	_shot("2_central")
	_tap(KEY_1, "1")
	await _seen_more("navigation")
	_shot("3_navigation")

	_tap(KEY_2, "2")
	await _seen_more("course")
	_tap(KEY_1, "1")
	await _seen_more("course")
	_tap(KEY_BACKSPACE, "")
	await _seen_more("course")
	_check("BACKSPACE takes the digit back", [text.column, text.row] == [1, 5])
	_tap(KEY_0, "0")
	await _seen_more("course")
	_tap(KEY_5, "5")
	await _seen_more("navigation")
	_check("05 sets the course for LUYTEN", GameState.target_planet == 4)
	_shot("4_course_set")

	_tap(KEY_2, "2")
	await _seen_more("course")
	_tap(KEY_7, "7")
	await _seen_more("course")
	_tap(KEY_ENTER, "")
	await _seen_more("navigation")
	_check("7 and ENTER for SIRIUS", GameState.target_planet == 6)

	_tap(KEY_1, "1")
	await _seen_more("directory")
	_shot("5_directory")
	_tap(KEY_1, "1")
	await _seen_more("which")
	_tap(KEY_0, "0")
	await _seen_more("which")
	_tap(KEY_2, "2")
	await _seen_more("page")
	_shot("6_page")
	_tap(KEY_SPACE, " ")
	await _seen_more("directory")
	_check("a star's page, and any key for the directory again", true)
	_tap(KEY_2, "2")
	await _seen_more("command")
	_check("the directory's RETURN comes out at the command menu", true)

	# the ways out
	_tap(KEY_5, "5")
	await _scene_is(FLIGHT)
	_check("5 runs the flight program", _current_path() == FLIGHT)
	_shot("7_flight")
	# from the title a game starts in flight, with INSTRUMENTS still to
	# run; here it has
	await _passes(2)
	_tap(KEY_C, "c")
	await _scene_is(COM)
	_check("and C there the console", _current_path() == COM)
	_hook()

	await _seen_more("command")
	_tap(KEY_3, "3")
	await _left_for("3", "radar")
	_check("RADAR is told who ran it (38388 = 2)", GameState.handover == 2)
	_tap(KEY_SPACE, " ")
	await _scene_is(COM)
	_check("and comes back to the console, not to flight",
			_current_path() == COM and GameState.handover == 0)
	_hook()

	for way: Array in [["4", KEY_4, "end_game"], ["2", KEY_2, "ground_forces"]]:
		await _seen_more("command")
		_tap(way[1], way[0])
		await _left_for(way[0], way[2])
		await _com()

	for way: Array in [["3", KEY_3, "star_chart"], ["4", KEY_4, "status"], ["5", KEY_5, "supply_report"]]:
		await _seen_more("command")
		_tap(KEY_1, "1")
		await _seen_more("central")
		_tap(way[1], way[0])
		await _left_for("1 and " + way[0], way[2])
		if way[2] == "star_chart":
			# its loop is running: out by its own door
			await _frames(30)
			_tap(KEY_SPACE, " ")
			await _scene_is(COM)
			_hook()
		else:
			await _com()

	print("com scene driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## The console run, as the programs under it run it.
func _com() -> void:
	GameState.goto_scene(COM)
	await _frames(3)
	await _scene_is(COM)
	_hook()


func _left_for(keys: String, scene: String) -> void:
	var path := SCENES % scene
	await _scene_is(path)
	_check("%s runs %s" % [keys, scene], _current_path() == path)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## Waits for the flight scene to have made that many passes.
func _passes(n: int) -> void:
	var made := [0]
	get_tree().current_scene._loop.pass_started = func() -> void: made[0] += 1
	for i in range(TIMEOUT_FRAMES):
		if made[0] >= n:
			return
		await get_tree().process_frame
	print("WRONG  the flight program made %d passes" % made[0])
	_bad += 1


## Listens in on the current scene's loop.
func _hook() -> Node:
	var scene := get_tree().current_scene
	var theirs: Callable = scene._loop.watch
	scene._loop.watch = func(what: String) -> void:
		theirs.call(what)
		_seen[what] = _seen.get(what, 0) + 1
	return scene


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


## Waits until the loop has said `what` that many more times.
func _seen_more(what: String, times: int = 1) -> void:
	var until: int = _seen.get(what, 0) + times
	for i in range(TIMEOUT_FRAMES):
		if _seen.get(what, 0) >= until:
			return
		await get_tree().process_frame
	print("WRONG  the program never came to \"%s\"" % what)
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


func _shot(name_: String) -> void:
	if _shots == "":
		return
	var page: RefCounted = GameState.view3d.pages[GameState.view3d.shown]
	var picture := Image.create(280, 192, false, Image.FORMAT_RGBA8)
	picture.fill(Color.BLACK)
	var drawn: Image = page.image()
	picture.blend_rect(drawn, Rect2i(0, 0, 280, 192), Vector2i.ZERO)
	picture.save_png(_shots.path_join("%s.png" % name_))
