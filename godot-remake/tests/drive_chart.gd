extends Node
## Uses the vector galaxy map (scripts/flight/vector_chart.gd, an overlay on
## the flight) the way a player would: the pointer moved over the map and
## clicked, keys put into Godot's input queue, and a look at what the console
## display says and where the chart goes. What a click finds and what is said
## is held to the real game in check_chart_rules.gd; this is for the overlay.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_chart.tscn
##
## The scenes replace one another, so the driver is a node of its own
## under the root (see drive_radar.gd).

const FLIGHT := "res://scenes/native_flight.tscn"
const COM := "res://scenes/com.tscn"
const ChartRules = preload("res://scripts/rules/chart_rules.gd")
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
	var chart: Control = await _chart()
	_check("the chart is down until asked for", true)
	_check("a new chart says to click a star", _page().has("CLICK A STAR.") and chart.visible)
	chart.point_at(ChartRules.place(SIRIUS))
	chart.select()
	await _frames(2)
	var said: Array = ChartRules.said(SIRIUS)
	_check("a click on SIRIUS: its name, place and distance", _page().has(said[0]) and _page().has(said[1]) and said[0] == "STAR SYSTEM : SIRIUS")
	_check("and the question, with Y and N", _page().has(ChartRules.QUESTION) and chart._asking == SIRIUS)
	chart.select()
	await _frames(2)
	_check("another click while asked changes nothing", chart._asking == SIRIUS and _page().has(said[0]))
	_tap(KEY_N)
	await _frames(2)
	_check("N: the question goes", chart._asking == 0 and _page().has("STAR: SIRIUS") and not _page().has(ChartRules.QUESTION))

	chart.point_at(Vector2(20, 20))
	chart.select()
	await _frames(2)
	_check("a click on nothing: no star there", _page().has(ChartRules.SAID_NO_STAR))
	await _until(func() -> bool: return not _page().has(ChartRules.SAID_NO_STAR))
	_check("and it goes by itself", not _page().has(ChartRules.SAID_NO_STAR))

	# the keys: an arrow goes to the next star that way, Enter asks
	chart = await _chart()
	chart.point_at(ChartRules.place(SIRIUS))
	var before := ChartRules.star_at(chart._cursor)
	_tap(KEY_RIGHT)
	await _frames(2)
	var after := ChartRules.star_at(chart._cursor)
	_check("an arrow right goes to a star to the right of SIRIUS (star %d to star %d)" % [before, after],
			after != before and chart._cursor.x > ChartRules.place(SIRIUS).x and chart._cursor == ChartRules.place(after).clamp(Vector2(10, 10), Vector2(270, 145)))
	_tap(KEY_LEFT)
	await _frames(2)
	_check("and left comes back to SIRIUS", ChartRules.star_at(chart._cursor) == before)
	_tap(KEY_ENTER)
	await _frames(2)
	_check("Enter asks about it", _page().has("STAR SYSTEM : " + ChartRules.NAMES[before - 1]))
	_tap(KEY_Y)
	await _scene_is(COM)
	_check("Y runs the console with that star's page", _path() == COM and GameState.handover == before)
	await _frames(3)
	_check("which has it up", (_scene().get_node("Center/Columns/Console/VBox/Title") as Label).text == "%s STAR SYSTEM" % ChartRules.NAMES[before - 1])
	(_scene().get_node("Center/Columns/Console/VBox/Buttons").get_child(0) as Button).pressed.emit()
	await _scene_is(FLIGHT)
	await _frames(3)
	_check("and its RETURN runs the chart again, the mark taken", _scene().get("_chart").visible and GameState.handover == 0)

	chart = await _chart()
	GameState.base_built_this_trip = true
	chart.point_at(ChartRules.place(SIRIUS))
	chart.select()
	await _frames(2)
	_tap(KEY_Y)
	await _scene_is(COM)
	_check("Y gives the once-a-trip base flag back", not GameState.base_built_this_trip)

	# opened from the flight, Space just closes it
	chart = await _chart()
	_tap(KEY_SPACE)
	await _frames(3)
	_check("Space closes it, over the flight, nothing asked", not chart.visible and _path() == FLIGHT and GameState.handover == 0)
	_tap(KEY_G)
	await _frames(3)
	_check("G puts it up again", chart.visible)
	_tap(KEY_G)
	await _frames(3)
	_check("and takes it down", not chart.visible)

	# run by the console, Space goes back to the console
	GameState.start_new_game()
	GameState.show_chart_on_arrival = true
	GameState.goto_scene(FLIGHT)
	await _scene_is(FLIGHT)
	await _frames(3)
	chart = _scene().get("_chart")
	_check("the console's GALAXY MAP shows the chart over the flight", chart.visible)
	_tap(KEY_SPACE)
	await _scene_is(COM)
	_check("Space goes to the console, nothing asked", _path() == COM and GameState.handover == 0)
	await _frames(3)
	_check("which is at its command menu", (_scene().get_node("Center/Columns/Console/VBox/Title") as Label).text == "COMMAND MODE")

	print("chart driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## A new game, the flight up, the chart opened by G.
func _chart() -> Control:
	GameState.start_new_game()
	GameState.goto_scene(FLIGHT)
	await _scene_is(FLIGHT)
	await _frames(3)
	_tap(KEY_G)
	await _frames(3)
	return _scene().get("_chart")


func _scene() -> Node:
	return get_tree().current_scene


## The lines the chart has written on the console's display.
func _page() -> Array:
	return _scene().get_node("Hud/Overlay").page


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
