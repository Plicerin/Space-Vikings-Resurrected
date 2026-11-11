extends Node
## Uses the star chart (scenes/star_chart.tscn) the way a player would:
## the pointer moved over the map and clicked, keys put into Godot's
## input queue, and a look at what the chart says and where it goes. What
## a click finds and what is said is held to the real game in
## check_chart_rules.gd; this is for the scene round it.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_chart.tscn
##
## The scenes replace one another, so the driver is a node of its own
## under the root (see drive_radar.gd).

const CHART := "res://scenes/star_chart.tscn"
const COM := "res://scenes/com.tscn"
const ChartRules = preload("res://scripts/rules/chart_rules.gd")
const INFO := "Center/Columns/Info/VBox/"
const SIRIUS := 7
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
	driver.name = "ChartDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	await _chart()
	_check("a new chart says to click a star", _said() == "CLICK A STAR." and not _answers().visible)
	_point(ChartRules.place(SIRIUS))
	_click()
	await _frames(2)
	var said: Array = ChartRules.said(SIRIUS)
	_check("a click on SIRIUS: its name, place and distance", _said() == "\n".join(said) and said[0] == "STAR SYSTEM : SIRIUS")
	_check("and the question, with Y and N", _question().visible and _answers().visible and _question().text == ChartRules.QUESTION)
	_click()
	await _frames(2)
	_check("another click while asked changes nothing", _said() == "\n".join(said))
	_tap(KEY_N)
	await _frames(2)
	_check("N: the question goes", _said() == "CLICK A STAR." and not _question().visible and not _answers().visible)

	_point(Vector2(20, 20))
	_click()
	await _frames(2)
	_check("a click on nothing: no star there", _said() == ChartRules.SAID_NO_STAR and not _answers().visible)
	await _until(func() -> bool: return _said() == "CLICK A STAR.")
	_check("and it goes by itself", _said() == "CLICK A STAR.")

	# the keys: the cursor moves, Enter asks
	await _chart()
	_point(ChartRules.place(SIRIUS) - Vector2(10, 0))
	_tap(KEY_RIGHT)
	_tap(KEY_RIGHT)
	await _frames(2)
	_tap(KEY_ENTER)
	await _frames(2)
	_check("two arrows right and Enter ask about SIRIUS", _said().begins_with("STAR SYSTEM : SIRIUS"))
	_tap(KEY_Y)
	await _scene_is(COM)
	_check("Y runs the console with SIRIUS's page", _path() == COM and GameState.handover == SIRIUS)
	await _frames(3)
	_check("which has it up", (_scene().get_node("Center/Columns/Console/VBox/Title") as Label).text == "SIRIUS STAR SYSTEM")
	(_scene().get_node("Center/Columns/Console/VBox/Buttons").get_child(0) as Button).pressed.emit()
	await _scene_is(CHART)
	_check("and its RETURN runs the chart again, the mark taken", _path() == CHART and GameState.handover == 0)

	await _chart()
	GameState.base_built_this_trip = true
	_point(ChartRules.place(SIRIUS))
	_click()
	await _frames(2)
	_tap(KEY_Y)
	await _scene_is(COM)
	_check("Y gives the once-a-trip base flag back", not GameState.base_built_this_trip)

	await _chart()
	_tap(KEY_SPACE)
	await _scene_is(COM)
	_check("Space goes to the console, nothing asked", _path() == COM and GameState.handover == 0)
	await _frames(3)
	_check("which is at its command menu", (_scene().get_node("Center/Columns/Console/VBox/Title") as Label).text == "COMMAND MODE")

	await _chart()
	(_scene().get_node(INFO + "Return") as Button).pressed.emit()
	await _scene_is(COM)
	_check("the button goes to the console", _path() == COM)

	print("chart scene driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## A new game, the chart up.
func _chart() -> void:
	GameState.start_new_game()
	GameState.goto_scene(CHART)
	await _scene_is(CHART)
	await _frames(3)
	_scene().pace = 0.1


func _scene() -> Control:
	return get_tree().current_scene


func _said() -> String:
	return (_scene().get_node(INFO + "Said") as Label).text


func _question() -> Label:
	return _scene().get_node(INFO + "Question")


func _answers() -> Control:
	return _scene().get_node(INFO + "Answers")


## The pointer at a place in the chart's dots.
func _point(dots: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = dots * 3.0
	_scene()._map_input(event)


func _click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = _scene()._cursor * 3.0
	_scene()._map_input(event)


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
		Input.parse_input_event(event)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1
