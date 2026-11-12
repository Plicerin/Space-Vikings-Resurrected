extends Node
## Uses the native flight scene (scenes/native_flight.tscn) the way a
## player would: held keys for the stick, keys for the speed and the lamps,
## and a look at what the ship does and what the panel shows. How the ship
## flies is held to the original in check_flight_rules.gd; this is for the
## scene round it.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_native_flight.tscn
##
## The scenes replace one another, so the driver is a node of its own
## under the root (see drive_radar.gd).

const FLIGHT := "res://scenes/native_flight.tscn"
const TIMEOUT_FRAMES := 60 * 20
const WORLD_SCALE := 3.0 # the flight scene's, see native_flight.gd (the atmosphere's)
const PLANET_RADIUS := 450000.0 # the planet's, in the ground's units (Terrain.PLANET_RADIUS)
const ORBIT_SCALE := PLANET_RADIUS / 780.0 # and the orbit's, on top: the planet's radius over the orbit's

var _driver := false
var _bad := 0


func _ready() -> void:
	if _driver:
		_drive.call_deferred()
		return
	var driver := Node.new()
	driver.set_script(get_script())
	driver._driver = true
	driver.name = "NativeFlightDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	await _flight(func() -> void:
		GameState.ship_y = 3000
		GameState.ship_speed = 0)
	var at := Vector3(GameState.ship_x, GameState.ship_y, -GameState.ship_z) * WORLD_SCALE * ORBIT_SCALE # Godot's z is the original's reversed
	_check("a new flight: the camera is at the ship (%s, the game has %s)" % [_camera().global_position, at],
			_camera().global_position.is_equal_approx(at))
	_check("the panel: no speed, full shields", _speed() == 0.0 and GameState.ship_shield == 100.0)

	_tap(KEY_4)
	_tap(KEY_4)
	await _frames(3)
	_check("4 twice: 30 faster", _speed() == 30.0)
	_tap(KEY_1)
	await _frames(2)
	_check("1: 3 slower", _speed() == 27.0)
	for i in 10:
		_tap(KEY_4)
	await _frames(2)
	_check("the speed stops at 120", _speed() == 120.0)
	_tap(KEY_3)
	_tap(KEY_3)
	_tap(KEY_3)
	await _frames(2)
	_check("3: 15 slower each", _speed() == 75.0)

	# a second of the stick forward: the nose goes down by four
	var before := GameState.ship_pitch
	Input.action_press("stick_forward")
	await _frames(60)
	Input.action_release("stick_forward")
	await _frames(2)
	var pitched := _signed(GameState.ship_pitch) - _signed(before)
	_check("a second of stick forward puts the nose down about 4 units (%d)" % pitched, pitched >= 3 and pitched <= 5)
	# and the camera has turned with it
	var forward: Vector3 = -_camera().global_transform.basis.z
	_check("the camera is looking down (%s)" % forward, forward.y < -0.03)

	# bank, and the heading follows
	await _flight(func() -> void:
		GameState.ship_y = 3000
		GameState.ship_speed = 0)
	Input.action_press("stick_left")
	await _frames(60 * 8)
	Input.action_release("stick_left")
	await _frames(2)
	_check("eight seconds of stick left: banked and turned (bank %d, heading %d)" % [_signed(GameState.ship_bank), GameState.ship_heading],
			_signed(GameState.ship_bank) >= 20 and GameState.ship_heading != 0)

	# the lamps
	await _flight(func() -> void: GameState.autopilot_active = false)
	_tap(KEY_A)
	await _frames(2)
	_check("A: the autopilot is on", GameState.autopilot_active)
	_tap(KEY_A)
	await _frames(2)
	_check("A again: manual", not GameState.autopilot_active)
	_tap(KEY_B)
	await _frames(2)
	_check("B: the condition steps", GameState.condition == 3 or GameState.condition == 2 or GameState.condition == 1)

	# the display: N puts up the position and headings, F1 the keys, the same key takes them down
	var panel: Control = _node("Hud/Overlay")
	_check("the display starts idle", panel.mode == panel.Mode.IDLE)
	_tap(KEY_N)
	await _frames(2)
	_check("N: the nav data", panel.mode == panel.Mode.NAV)
	_tap(KEY_F1)
	await _frames(2)
	_check("F1: the keys", panel.mode == panel.Mode.HELP)
	_tap(KEY_F1)
	await _frames(2)
	_check("F1 again: idle", panel.mode == panel.Mode.IDLE)

	# AUTO holds the stick: held left, switched to auto, let go - the ship keeps turning
	await _flight(func() -> void:
		GameState.autopilot_active = false
		GameState.ship_speed = 60)
	Input.action_press("stick_left")
	await _frames(30)
	_tap(KEY_A)
	await _frames(2)
	Input.action_release("stick_left")
	var bank_then := _signed(GameState.ship_bank)
	await _frames(60)
	_check("in AUTO the stick is not read: the bank goes on (%d, then %d)" % [bank_then, _signed(GameState.ship_bank)],
			absi(_signed(GameState.ship_bank)) > absi(bank_then))
	_tap(KEY_A)
	await _frames(60)
	_check("and back in MNL the stick is let go: the bank eases off",
			absi(_signed(GameState.ship_bank)) <= absi(bank_then) + 25)

	# the switches are clickable: the panel's three hot spots do what S, A and W do
	var switches: Control = _node("Hud/Overlay").get("_switches")
	var spots := switches.get_children().filter(func(c: Node) -> bool: return c is Control and c.mouse_filter == Control.MOUSE_FILTER_STOP)
	_check("three switches to click", spots.size() == 3)
	var shields_before := GameState.shields_up
	var auto_before := GameState.autopilot_active
	var weapon_before := GameState.missile_mode_active
	for spot: Control in spots:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		spot.gui_input.emit(click)
	_check("clicking them flips the shields, the autopilot and the weapon",
			GameState.shields_up != shields_before and GameState.autopilot_active != auto_before
			and GameState.missile_mode_active != weapon_before)

	# the fighting: the laser at the defender, a pass a second
	await _flight(func() -> void:
		GameState.gf_planet_surrendered = false
		GameState.gf_enemy_strength = 250.0
		GameState.gf_victory_progress = 0.0
		GameState.ship_x = 400
		GameState.ship_y = -100
		GameState.ship_z = -5800
		GameState.orbital_defender_tier = 3
		GameState.ship_speed = 0
		GameState.missile_mode_active = false
		GameState.shields_up = true)
	var before_progress := GameState.gf_victory_progress
	Input.action_press("fire")
	await _frames(60 * 3)
	Input.action_release("fire")
	_check("three seconds with the fire button down at SOL: the laser scores (%.0f to %.0f)" % [before_progress, GameState.gf_victory_progress],
			GameState.gf_victory_progress > before_progress)
	await _until(func() -> bool: return GameState.ship_shield < 100.0, 60 * 60) # its fire is a matter of chance, a pass in a few
	_check("and the defender's fire wears the shields (%.0f)" % GameState.ship_shield, GameState.ship_shield < 100.0)

	# the defender: only destroying it removes it, and then its wreckage is there
	await _flight(func() -> void:
		GameState.gf_planet_surrendered = false
		GameState.gf_enemy_strength = 250.0
		GameState.defender_damage_threshold = 150.0
		GameState.defender_damage_points = 149.0
		GameState.ship_x = 400
		GameState.ship_y = -100
		GameState.ship_z = -5800
		GameState.orbital_defender_tier = 3
		GameState.ship_speed = 0
		GameState.ship_missile_system = 100.0
		GameState.missile_mode_active = true
		GameState.shields_up = true)
	_check("a defender at its planet to begin with", get_tree().current_scene.get("_defender") != null)
	var box: AABB = get_tree().current_scene.get("_combat").hit_box
	var ship: Node3D = get_tree().current_scene.get("_defender")
	var aabb: AABB = (ship.get_child(0) as MeshInstance3D).mesh.get_aabb()
	_check("the missile's hit box is the ship as drawn: as long as it is (%.0f, drawn %.0f)" % [box.size.x, aabb.size.x * 1.8],
			absf(box.size.x - aabb.size.x * 1.8) < 1.0)
	var fighting := get_tree().current_scene
	var eye: Vector3 = fighting.get("_camera").global_position
	var centre: Vector3 = ship.global_position
	var on_hull: Vector3 = fighting._hull_point(eye, (centre - eye).normalized())
	_check("a missile bursts on the hull, not inside the ship (%.0f of %.0f away)" % [eye.distance_to(on_hull), eye.distance_to(centre)],
			on_hull != Vector3.INF and eye.distance_to(on_hull) < eye.distance_to(centre) - 1000.0)
	await _frames(60 * 3)
	_check("flying on without hitting it leaves it there", get_tree().current_scene.get("_defender") != null)
	Input.action_press("fire")
	await _frames(60 * 3)
	Input.action_release("fire")
	await _frames(10)
	_check("a missile on it at the end of its strength destroys it (tier %d)" % GameState.orbital_defender_tier,
			GameState.orbital_defender_tier == 0 and get_tree().current_scene.get("_defender") == null)
	_check("and its wreckage is in the sky", _wreck_count() == 1)
	await _flight(func() -> void: # back at the planet later: the wreck of it
		GameState.orbital_defender_tier = 0)
	_check("a planet whose defender is gone shows the wreckage, not a ship", get_tree().current_scene.get("_defender") == null and _wreck_count() == 1)

	# a ship with nothing left is lost
	await _flight(func() -> void:
		GameState.gf_planet_surrendered = false
		GameState.ship_x = 400
		GameState.ship_y = -100
		GameState.ship_z = -5800
		GameState.orbital_defender_tier = 3
		GameState.ship_speed = 0
		GameState.ship_hull = 1.0
		GameState.ship_shield = 0.0
		GameState.shields_up = false
		GameState.flight_escort_fighters = 0)
	await _until(func() -> bool: return _node("Hud/Overlay").message.begins_with("YOUR SHIP HAS BEEN"), 60 * 90)
	_check("a hull with nothing left: YOUR SHIP HAS BEEN DESTROYED", _node("Hud/Overlay").message.begins_with("YOUR SHIP HAS BEEN"))

	# the hyperdrive: refused with no course, then a jump
	await _flight(func() -> void:
		GameState.target_planet = -1
		GameState.ship_speed = 0)
	_tap(KEY_H)
	await _frames(3)
	_check("H with no course: refused, said", _node("Hud/Overlay").message == "NO COURSE IS SET.")
	GameState.target_planet = 6
	GameState.ship_energy = 63.0
	var from_planet := GameState.current_planet
	_tap(KEY_H)
	await _frames(30)
	var rays: Control = null
	for child in _node("Hud").get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("hyperspace_effect.gd"):
			rays = child
	_check("H: the hyperspace lines are on the screen, filling it", rays != null and rays.size.x > 1000.0 and rays.size.y > 600.0)
	await _until(func() -> bool: return GameState.current_planet == 6)
	_check("H with a course (SIRIUS): the ship is at the other star", GameState.current_planet == 6 and from_planet == 0)
	await _frames(5)
	_check("with the energy paid (%.0f)" % GameState.ship_energy, GameState.ship_energy < 63.0)
	_check("and the scene begun again there", _path() == FLIGHT)

	# down to the planet and up again: one flight over one planet, the ship never moved by it
	await _flight(func() -> void:
		GameState.ship_x = 0
		GameState.ship_y = 0
		GameState.ship_z = 783 # 783 from the planet's middle: 2000 above its ground
		GameState.ship_speed = 0)
	var scene_before := get_tree().current_scene
	var orbit_spot := Vector3(0.0, 0.0, -783.0) * WORLD_SCALE * ORBIT_SCALE # where the camera is, in Godot's world
	await _until(func() -> bool: return GameState.in_atmosphere, 60 * 8)
	_check("below the top of the atmosphere over the planet: down into it", GameState.in_atmosphere)
	await _frames(10)
	var down := get_tree().current_scene
	_check("it is the same scene: nothing reloaded", down == scene_before)
	_check("and the flight never stopped for it", not down.get("_jumping"))
	var moved: float = down.get("_camera").global_position.distance_to(orbit_spot)
	_check("the ship is where it was in the world: it went down by flying, not by being moved (%.0f)" % moved, moved < 150.0)
	_check("the ground the ship is over is shown, with its clouds (and its cities, where there is land)", down.get("_air_root").visible)
	await _flight(func() -> void:
		GameState.in_atmosphere = true
		GameState.ship_x = 0
		GameState.ship_y = 4500
		GameState.ship_z = 0
		GameState.ship_speed = 0)
	var air_spot: Vector3 = GameState.reentry_site * (PLANET_RADIUS + 4500.0) * WORLD_SCALE # over the frame's middle, 4500 up
	await _until(func() -> bool: return not GameState.in_atmosphere, 60 * 8)
	_check("above 4000 in the atmosphere: up into orbit", not GameState.in_atmosphere)
	await _frames(10)
	var up_moved: float = get_tree().current_scene.get("_camera").global_position.distance_to(air_spot)
	_check("and the ship is where it was in the world (%.0f)" % up_moved, up_moved < 150.0)
	_check("the orbit shows no clouds or cities", not get_tree().current_scene.get("_air_root").visible)

	# the landing: the original's, on the sphere's ground: the ship sinks to 20, level, and is landed
	await _flight(func() -> void:
		GameState.in_atmosphere = true
		GameState.ship_x = 0
		GameState.ship_y = 30
		GameState.ship_z = 0
		GameState.ship_pitch = 5
		GameState.ship_bank = 10
		GameState.ship_speed = 0)
	await _frames(60 * 4)
	_check("sinking to the ground: stopped at 20, level (%d, pitch %d, bank %d)" % [GameState.ship_y, GameState.ship_pitch, GameState.ship_bank],
			GameState.ship_y == 20 and GameState.ship_pitch == 0 and GameState.ship_bank == 0)
	_check("and landed, as the shore leave and the repairs ask", load("res://scripts/rules/shore_rules.gd").new().landed())
	var ship_height: float = (get_tree().current_scene.get("_camera").global_position.length() - PLANET_RADIUS * WORLD_SCALE) / WORLD_SCALE
	_check("with the ship 20 above the ground it is drawn on (%.0f)" % ship_height, absf(ship_height - 20.0) < 1.0)

	# firing at the ground from the atmosphere: the strike lands on the ground, and the
	# display says how much of the planet the strikes have taken
	await _flight(func() -> void:
		GameState.in_atmosphere = true
		GameState.ship_x = 0
		GameState.ship_y = 600
		GameState.ship_z = -3000
		GameState.ship_pitch = 30 # the nose well down
		GameState.ship_speed = 0
		GameState.gf_planet_surrendered = false
		GameState.gf_enemy_strength = 100.0
		GameState.gf_victory_progress = 40.0)
	var flight := get_tree().current_scene
	var struck: Vector3 = flight._ground_ahead(12000.0)
	_check("nose down in the atmosphere: the line of fire meets the ground (%s)" % str(struck),
			struck != Vector3.INF and absf(struck.length() - (PLANET_RADIUS + 20.0) * WORLD_SCALE) < 1.0)
	flight._play({"kind": "missile", "hit": true, "steps": 8, "defender": false})
	await _frames(3)
	_check("a missile that hits says so", _node("Hud/Overlay").message == "DIRECT HIT ON THE PLANET")
	flight._play({"kind": "laser"})
	await _frames(3)
	_check("the display says how much of the planet is taken", _node("Hud/Overlay")._taken() == 40)

	# the way out by the keys: held back (DOWN) in the atmosphere, the nose comes up and the
	# ship climbs past 4000 into orbit
	await _flight(func() -> void:
		GameState.in_atmosphere = true
		GameState.ship_x = 0
		GameState.ship_y = 3700
		GameState.ship_z = -3000
		GameState.ship_pitch = 0
		GameState.ship_speed = 120)
	Input.action_press("stick_back")
	await _until(func() -> bool: return not GameState.in_atmosphere, 60 * 40)
	Input.action_release("stick_back")
	_check("DOWN held in the atmosphere climbs out into orbit (altitude shown to the end)", not GameState.in_atmosphere)

	# on to the console, and the radar
	await _flight(func() -> void:
		GameState.ship_speed = 60) # moving, and with the new game's SOL: its ship is there though the planet is ours
	_check("SOL, surrendered from the start, still has its ship in the flight", get_tree().current_scene.get("_defender") != null)
	var z_before := GameState.ship_z
	await _frames(60)
	_check("flying, the ship moves (z %d, then %d)" % [z_before, GameState.ship_z], GameState.ship_z != z_before)
	_tap(KEY_C)
	await _frames(4)
	_check("C runs the command console", get_tree().current_scene.get("_console").active())
	var z_on := GameState.ship_z
	await _frames(60 * 2)
	_check("and the flight stops while it is on (z %d, then %d)" % [z_on, GameState.ship_z], GameState.ship_z == z_on)
	await _flight(func() -> void: pass)
	_tap(KEY_R)
	await _frames(3)
	_check("R puts the radar up over the flight", get_tree().current_scene.get("_radar").visible and _path() == FLIGHT)

	print("native flight driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## How many fields of wreckage (a multimesh of rocks) the flight scene has.
func _wreck_count() -> int:
	var count := 0
	for child in get_tree().current_scene.get("_space_root").get_children():
		if child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh.instance_count == 50:
			count += 1
	return count


func _flight(with: Callable) -> void:
	GameState.start_new_game()
	with.call()
	GameState.goto_scene(FLIGHT)
	await _scene_is(FLIGHT)
	await _frames(3)


func _camera() -> Camera3D:
	return get_tree().current_scene.get_node("Camera")


func _node(path: String) -> Node:
	return get_tree().current_scene.get_node(path)


func _speed() -> float:
	return _node("Hud/Overlay").speed


func _signed(byte: int) -> int:
	return byte - 256 if byte > 127 else byte


func _until(done: Callable, frames: int = TIMEOUT_FRAMES) -> void:
	for i in frames:
		if done.call():
			return
		await get_tree().process_frame


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
		Input.parse_input_event(event)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1
