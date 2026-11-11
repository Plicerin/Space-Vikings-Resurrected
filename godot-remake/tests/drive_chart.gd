extends Node
## Uses the star chart scene (scenes/star_chart.tscn) the way a player
## would: mouse and key events put into Godot's input queue, on the
## scene's own clock, and a look at what came of them. What the chart
## draws is held to the real game in check_chart.gd; this is for the
## scene round it, that the mouse and the keys reach the program as
## paddles, button and keyboard, and that the way out leads somewhere.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_chart.tscn
##
## Add `-- --shots <directory>` to save the page on show after each step.
##
## The chart replaces the current scene when it leaves, so the driver is
## a node of its own under the root (see drive_flight.gd).

const CHART := "res://scenes/star_chart.tscn"
const COM := "res://scenes/com.tscn"
const REFERENCE := "../analysis/live/chart/"
## Where SIRIUS is on the hi-res screen, and a place with no star.
const SIRIUS := Vector2(135, 115)
const NOWHERE := Vector2(30, 30)
## Frames before a step is given up.
const TIMEOUT_FRAMES := 60 * 120

var _driver := false
var _seen := {}
var _bad := 0
var _shots := ""
## The page when the loop last said "turn" (the cross off) and "cross".
var _page_at := {}


func _ready() -> void:
	if _driver:
		_drive.call_deferred()
		return
	var driver := Node.new()
	driver.set_script(get_script())
	driver._driver = true
	driver.name = "ChartDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--shots":
		_shots = args[1]
	GameState.start_new_game()
	# as flight leaves the page: the panel, and TRANLIT's four switches
	var flight: RefCounted = load("res://scripts/flight/flight_program.gd").new()
	flight.instruments()
	GameState.goto_scene(CHART)
	await _scene_is(CHART)
	var scene := get_tree().current_scene
	var view: Node2D = scene.get_node("HGRCanvas/HgrView")
	var theirs: Callable = scene._loop.watch
	scene._loop.watch = func(what: String) -> void:
		theirs.call(what)
		_seen[what] = _seen.get(what, 0) + 1
		if what == "turn" or what == "cross" or what == "question":
			_page_at[what] = GameState.view3d.pages[0].mem.duplicate()

	_check("the picture is dark while GALAXY MAP loads", not view.visible)
	await _seen_more("drawn")
	_check("and on once the chart has cleared the page", view.visible)
	await _seen_more("turn")
	_check("the chart is the real one's", _page_at["turn"] == _live("chart_clean"))

	_mouse_to(view, SIRIUS)
	await _seen_more("cross", 2)
	_check("the mouse on SIRIUS sets the paddles (%s)" % str(scene._paddles),
			scene._paddles == [113, 115])
	_check("and the cross is where the real one's was", _page_at["cross"] == _live("chart_cursor"))
	_shot("1_cross")

	_click()
	await _seen_more("question")
	_check("a click asks about the star", _page_at["question"] == _live("chart_info"))
	_shot("2_sirius")

	var drawn: int = _seen["drawn"]
	_tap(KEY_N, "n")
	await _seen_more("turn")
	_check("N is not a Y: the chart is drawn again", _seen["drawn"] == drawn + 1)

	var before: Array = scene._paddles.duplicate()
	_key(KEY_LEFT, true)
	_key(KEY_UP, true)
	await _seen_more("turn", 3)
	_key(KEY_LEFT, false)
	_key(KEY_UP, false)
	_check("the arrows turn the paddles (%s -> %s)" % [str(before), str(scene._paddles)],
			scene._paddles[0] < before[0] and scene._paddles[1] < before[1])

	_mouse_to(view, NOWHERE)
	await _seen_more("turn", 2)
	_tap(KEY_ENTER, "")
	await _seen_more("message")
	_check("ENTER where there is no star says so", true)
	_shot("3_no_star")
	await _seen_more("turn")
	_check("and the message goes", _page_at["turn"] == _live("chart_clean"))

	_tap(KEY_SPACE, " ")
	await _seen_more("panel")
	_shot("4_panel")
	await _scene_is(COM)
	_check("SPACE leaves for the command console", _current_path() == COM)

	print("chart scene driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1


func _live(name_: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(REFERENCE.path_join("%s_p1.bin" % name_))


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
	print("WRONG  the chart never came to \"%s\"" % what)
	_bad += 1
	get_tree().quit(1)


## Moves the pointer to a dot of the hi-res screen.
func _mouse_to(view: Node2D, dot: Vector2) -> void:
	var at: Vector2 = view.get_global_transform_with_canvas() * dot
	at = get_tree().root.get_final_transform() * at
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)


func _click() -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)


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
