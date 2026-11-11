extends Node
## Uses the vector radar and the ship I.D. (scripts/flight/vector_radar.gd, an
## overlay on the flight) the way a player would: R in the flight and the
## console's 3, I for the I.D., X back, and the radar shot away. What the
## I.D. says and where the radar goes back to is held to the real game in
## check_radar_rules.gd.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_radar.tscn
##
## The scenes replace one another, so the driver is a node of its own
## under the root.

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
	# from the flight: R opens it over the flight, X closes it
	await _go(FLIGHT, func() -> void: pass)
	var radar: Control = _scene().get("_radar")
	_check("the radar is down until asked for", not radar.visible)
	_tap(KEY_R)
	await _frames(3)
	_check("R puts the radar up over the flight", radar.visible and _path() == FLIGHT and not radar.identify)
	_tap(KEY_X)
	await _frames(3)
	_check("X takes it down; still the flight", not radar.visible and _path() == FLIGHT)

	# I: the I.D. of what is in orbit, and I again the radar
	await _go(FLIGHT, func() -> void: GameState.orbital_defender_tier = 2)
	radar = _scene().get("_radar")
	_tap(KEY_R)
	await _frames(2)
	_tap(KEY_I)
	await _frames(3)
	_check("I shows the I.D.", radar.identify)
	var program: int = radar.RadarRules.ship_id_program(GameState.orbital_defender_tier)
	_check("a defender of type 2 gets the light cruiser's: %s" % str(radar.RadarRules.ship_id_text(program)),
			radar.RadarRules.ship_id_text(program)[1] == "LIGHT CRUISER" and radar._model_lines.size() > 0)
	_tap(KEY_I)
	await _frames(3)
	_check("I again is the radar", radar.visible and not radar.identify)
	_tap(KEY_R)
	await _frames(3)
	_check("R closes it too", not radar.visible)

	# no defender: nothing to see
	await _go(FLIGHT, func() -> void: GameState.orbital_defender_tier = 0)
	radar = _scene().get("_radar")
	_tap(KEY_R)
	await _frames(2)
	_tap(KEY_I)
	await _frames(3)
	_check("with no defender the I.D. says so", radar.RadarRules.ship_id_text(0)[1] == "THERE IS NO" and radar.identify)

	# from the console's 3: the flight with the radar up, and X back to the console
	await _go(COM, func() -> void: pass)
	await _frames(3)
	_tap(KEY_3)
	await _scene_is(FLIGHT)
	await _frames(3)
	radar = _scene().get("_radar")
	_check("the console's 3 shows the radar over the flight, and says who did (38388 = 2)",
			radar.visible and GameState.handover == 2)
	_tap(KEY_X)
	await _scene_is(COM)
	_check("X goes back to the console, the mark taken", _path() == COM and GameState.handover == 0)

	# the radar shot away: nothing drawn, nothing asked
	await _go(FLIGHT, func() -> void: GameState.ship_radar = 0.0)
	radar = _scene().get("_radar")
	_tap(KEY_R)
	await _frames(5)
	_check("with no radar R shows nothing", not radar.visible and _path() == FLIGHT)

	print("radar driven: %d wrong" % _bad)
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
