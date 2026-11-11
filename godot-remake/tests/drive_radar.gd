extends Node
## Uses the radar and the ship I.D. (scenes/radar.tscn, scenes/ship_id.tscn)
## the way a player would: from the flight and from the console's 3, keys
## and buttons, and a look at where each goes. What the I.D. says and where
## the radar goes back to is held to the real game in check_radar_rules.gd.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_radar.tscn
##
## The scenes replace one another, so the driver is a node of its own
## under the root (see drive_flight.gd).

const RADAR := "res://scenes/radar.tscn"
const SHIP_ID := "res://scenes/ship_id.tscn"
const COM := "res://scenes/com.tscn"
const FLIGHT := "res://scenes/native_flight.tscn"
const TIMEOUT_FRAMES := 60 * 20

var _driver := false
var _bad := 0


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
	# from the flight: R, and X back
	await _go(FLIGHT, func() -> void: pass)
	_tap(KEY_R)
	await _scene_is(RADAR)
	_check("R in flight runs the radar", _path() == RADAR)
	var readout := (_scene().get_node("Center/Columns/Info/VBox/Readout") as Label).text
	_check("which says where the ship is (%s)" % readout.replace("\n", " "), readout.begins_with("X "))
	_tap(KEY_X)
	await _scene_is(FLIGHT)
	_check("X goes back to the flight", _path() == FLIGHT)

	# any other key: the I.D. of what is in orbit, and any key back
	await _go(RADAR, func() -> void: GameState.orbital_defender_tier = 2; GameState.flight_scene = FLIGHT)
	_tap(KEY_SPACE)
	await _scene_is(SHIP_ID)
	_check("another key runs the I.D.", _path() == SHIP_ID)
	var said := (_scene().get_node("Center/Columns/Info/VBox/Said") as Label).text
	_check("a defender of type 2 gets the light cruiser's (%s)" % said.replace("\n", " / "),
			said == "LIGHT CRUISER\nWITH LASERS,\nMISSILES AND\nFIGHTER COVER.")
	_check("and a ship turning on a turntable", _scene()._turntable != null)
	_tap(KEY_Q)
	await _scene_is(RADAR)
	_check("a key there is the radar again", _path() == RADAR)

	await _go(SHIP_ID, func() -> void: GameState.orbital_defender_tier = 0)
	_check("with no defender: there is no starship in this system",
			(_scene().get_node("Center/Columns/Info/VBox/Said") as Label).text == "THERE IS NO\nSTARSHIP IN\nTHIS SYSTEM." and _scene()._turntable == null)
	await _go(SHIP_ID, func() -> void: GameState.orbital_defender_tier = 4)
	_check("a heavy cruiser's has the fighters line too",
			(_scene().get_node("Center/Columns/Info/VBox/Said") as Label).text.ends_with("20-40 FIGHTERS"))

	# from the console's 3: X goes back to the console
	await _go(COM, func() -> void: pass)
	await _frames(3)
	_tap(KEY_3)
	await _scene_is(RADAR)
	_check("the console's 3 runs the radar, and says who did (38388 = 2)", _path() == RADAR and GameState.handover == 2)
	_tap(KEY_X)
	await _scene_is(COM)
	_check("X goes back to the console, the mark taken", _path() == COM and GameState.handover == 0)

	# the radar shot away: nothing drawn, nothing asked
	await _go(FLIGHT, func() -> void: GameState.ship_radar = 0.0)
	_tap(KEY_R)
	await _frames(30) # the radar scene is up for a frame and gone
	await _scene_is(FLIGHT)
	_check("with no radar R comes straight back to the flight", _path() == FLIGHT)

	print("radar scene driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


func _go(scene: String, with: Callable) -> void:
	GameState.start_new_game()
	with.call()
	GameState.goto_scene(scene)
	await _scene_is(scene)
	await _frames(3)


func _scene() -> Node:
	return get_tree().current_scene


func _path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


func _scene_is(path: String) -> void:
	for i in TIMEOUT_FRAMES:
		if _path() == path:
			return
		await get_tree().process_frame
	_check("never reached %s" % path, false)


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
