extends Node
## Uses the two report scenes (scenes/status.tscn, scenes/supply_report.tscn)
## the way a player would: what is on show for a game in a known state,
## and the keys and the button that go back to the console. What the
## reports say is held to the real game in check_report_rules.gd.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_reports.tscn
##
## The scenes replace one another, so the driver is a node of its own
## under the root (see drive_radar.gd).

const STATUS := "res://scenes/status.tscn"
const SUPPLY := "res://scenes/supply_report.tscn"
const COM := "res://scenes/com.tscn"
const PANEL := "Center/Panel/VBox/"
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
	driver.name = "ReportsDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	GameState.start_new_game()
	GameState.troop_location = 2
	GameState.troops_stationed_at = 3
	GameState.ship_hull = 60.0
	GameState.credits = 12345.0
	GameState.loot[12] = 25.0 # gold
	GameState.loot[3] = 255.0 # fighter parts
	GameState.goto_scene(STATUS)
	await _scene_is(STATUS)
	var ship := _cells("Ship")
	_check("the ship: location, stardate, energy, credits", ship.slice(0, 12) ==
			["LOCATION", "SOL", "", "", "STARDATE", "100.3", "", "", "ENERGY", "100%", "CREDITS", "12345"])
	_check("hull damage is what is gone", ship.slice(16, 20) == ["HULL DMG", "40%", "MISSILES", "60"])
	var troops := _cells("Troops")
	_check("the troops, and the star they are at", troops.slice(0, 6) ==
			["NO. OF TROOPS", "2000", "TROOP MORALE", "EXCELLENT!", "TROOP LOCATION", "SHORE LEAVE (BARNARD'S STAR)"])
	_check("the troops are not dead", not _node("Dead").visible)
	GameState.troops = 0.0
	GameState.goto_scene(STATUS)
	await _frames(3)
	await _scene_is(STATUS)
	await _frames(2)
	_check("no troops left: said", _node("Dead").visible)

	_tap(KEY_ENTER)
	await _scene_is(COM)
	_check("Enter goes back to the console", _current_path() == COM)

	GameState.goto_scene(SUPPLY)
	await _scene_is(SUPPLY)
	var supply := _cells("Ship")
	_check("gold is counted in tens of pounds", supply.slice(3, 6) == ["250", "POUNDS"] or supply.slice(4, 6) == ["250", "POUNDS"])
	_check("no byte's worth is cut short", "2550" not in supply and supply.has("255"))
	_check("the credits are last", supply.slice(-3) == ["CREDITS", "12345", ""])
	_check("there are the thirteen kinds and the credits", supply.size() == 14 * 3)
	var button: Button = get_tree().current_scene.get_node(PANEL + "Return")
	button.pressed.emit()
	await _scene_is(COM)
	_check("the button goes back to the console", _current_path() == COM)

	GameState.goto_scene(SUPPLY)
	await _scene_is(SUPPLY)
	_tap(KEY_ESCAPE)
	await _scene_is(COM)
	_check("Escape goes back to the console", _current_path() == COM)

	print("reports driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


func _node(name_: String) -> Control:
	return get_tree().current_scene.get_node(PANEL + name_)


func _cells(grid: String) -> Array:
	var cells := []
	for cell: Label in _node(grid).get_children():
		cells.append(cell.text)
	return cells


func _current_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


func _scene_is(path: String) -> void:
	for i in TIMEOUT_FRAMES:
		if _current_path() == path:
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
