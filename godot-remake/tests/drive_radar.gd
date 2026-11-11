extends Node
## Uses the radar scene (scenes/radar.tscn) the way a player would: key
## events put into Godot's input queue, on the scene's own clock, and a
## look at what came of them. What RADAR and the I.D. programs draw is
## held to the real game in check_radar.gd; this is for the scene round
## them, that the picture is seen coming as the Apple's does, that the
## keys reach whichever of the two programs is running, and that the
## scene leaves for the program the original ran: the flight if the
## flight ran it, the console if the console did.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_radar.tscn
##
## Add `-- --shots <directory>` to save the page on show after each step.
##
## The scenes replace one another, so the driver is a node of its own
## under the root (see drive_flight.gd).

const RADAR := "res://scenes/radar.tscn"
const FLIGHT := "res://scenes/flight/space_flight.tscn"
const COM := "res://scenes/com.tscn"
const ShipIdLoop = preload("res://scripts/radar/ship_id_loop.gd")
## Frames before a step is given up.
const TIMEOUT_FRAMES := 60 * 120
## The rows of the view, above the flight panel.
const VIEW_ROWS := 124
const PANEL_ROW := 126

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
	driver.name = "RadarDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--shots":
		_shots = args[1]
	GameState.start_new_game()
	GameState.goto_scene(FLIGHT)
	await _scene_is(FLIGHT)
	var text: RefCounted = GameState.chargen
	var page: RefCounted = GameState.view3d.pages[0]

	# from the flight
	await _passes(3)
	_tap(KEY_R, "r")
	await _scene_is(RADAR)
	_check("R in flight runs RADAR", _current_path() == RADAR)
	_watch()
	# the picture comes a few stars to a frame
	var pictures := {}
	var no_panel := 0
	var until: int = _seen.get("radar", 0) + 1
	for i in range(TIMEOUT_FRAMES):
		if _seen.get("radar", 0) >= until:
			break
		var stars := _lit_bytes(0, VIEW_ROWS - 1)
		pictures[stars] = true
		if stars > 0 and _lit_bytes(PANEL_ROW, 191) == 0:
			no_panel += 1
		await get_tree().process_frame
	_check("RADAR asks for a key", [text.column, text.row] == [38, 23])
	_check("the picture was seen coming (%d different pictures on the way)" % pictures.size(),
			pictures.size() > 20)
	_check("with nothing under it where the flight panel was (%d frames)" % no_panel, no_panel > 20)
	_check("the ship's box is in the middle", page.mem[63 * 40 + 20] & 0x02 != 0)
	_check("the flight panel is back under it", _lit_bytes(PANEL_ROW, 191) > 0)
	_shot("1_radar")

	_tap(KEY_SPACE, " ")
	await _seen_more("id")
	var scene := get_tree().current_scene
	_check("any key but X runs an I.D. program, in the same scene",
			_current_path() == RADAR and scene._loop is ShipIdLoop)
	_check("SOL's is the light cruiser's (SHIP # 3 I.D.)", scene._loop.program.ship == 3
			and [text.column, text.row] == [24, 9])
	_shot("2_id")
	_tap(KEY_ENTER, "")
	await _seen_more("radar")
	_check("a key there runs RADAR again", _current_path() == RADAR and not scene._loop is ShipIdLoop)
	_tap(KEY_X, "x")
	await _scene_is(FLIGHT)
	_check("X goes back to the flight", _current_path() == FLIGHT and GameState.handover == 0)
	await _passes(2)
	_shot("3_flight")

	# from the console
	_tap(KEY_C, "c")
	await _scene_is(COM)
	await _command()
	_tap(KEY_3, "3")
	await _scene_is(RADAR)
	_check("COM's 3 runs RADAR, and tells it who did (38388 = 2)",
			_current_path() == RADAR and GameState.handover == 2)
	_watch()
	await _seen_more("radar")
	_tap(KEY_X, "x")
	await _scene_is(COM)
	_check("X goes back to the console", _current_path() == COM and GameState.handover == 0)

	# with the radar shot away
	await _command()
	GameState.ship_radar = 0
	var asked: int = _seen.get("radar", 0)
	_tap(KEY_3, "3")
	await _scene_is(RADAR)
	_watch()
	await _scene_is(COM)
	_check("with no radar COM's 3 comes straight back to the console",
			_current_path() == COM and _seen.get("radar", 0) == asked)
	await _command()
	_tap(KEY_5, "5")
	await _scene_is(FLIGHT)
	await _passes(2)
	_tap(KEY_R, "r")
	await _scene_is(RADAR)
	_watch()
	await _scene_is(FLIGHT)
	_check("and R in flight straight back to the flight",
			_current_path() == FLIGHT and _seen.get("radar", 0) == asked)
	await _passes(2)
	_check("which flies on", true)

	print("radar scene driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## Listens in on the radar scene's loops.
func _watch() -> void:
	get_tree().current_scene.watch = func(what: String) -> void:
		_seen[what] = _seen.get(what, 0) + 1


## Waits for the console to ask for a command.
func _command() -> void:
	var scene := get_tree().current_scene
	var theirs: Callable = scene._loop.watch
	scene._loop.watch = func(what: String) -> void:
		theirs.call(what)
		_seen[what] = _seen.get(what, 0) + 1
	await _seen_more("command")


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


## Waits until a loop has said `what` that many more times.
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
