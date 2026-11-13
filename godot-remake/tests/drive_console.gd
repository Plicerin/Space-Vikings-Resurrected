extends Node
## The CRT console's way of asking (scripts/flight/crt_console.gd): a numbered
## menu, yes and no, a number typed in, a wait a key may cut short, and the
## display growing while a program has it.
##
##   godot --headless --fixed-fps 60 --path godot-remake res://tests/drive_console.tscn

const FLIGHT := "res://scenes/native_flight.tscn"
const TIMEOUT_FRAMES := 60 * 20

var _bad := 0
var _console: Node
var _overlay: Control
var _got: Variant = null
var _done := false
var _driver := false


## The scenes replace one another, so the driver is a node of its own under the root.
func _ready() -> void:
	if _driver:
		_drive.call_deferred()
		return
	var driver := Node.new()
	driver.set_script(get_script())
	driver._driver = true
	driver.name = "ConsoleDriver"
	get_tree().root.add_child.call_deferred(driver)


func _drive() -> void:
	GameState.start_new_game()
	GameState.goto_scene(FLIGHT)
	await _frames(5)
	var scene := get_tree().current_scene
	_console = scene.get("_console")
	_overlay = scene.get_node("Hud/Overlay")
	_check("no program has the display to begin with", not _console.active() and not _overlay.program_open)

	# a menu of nine: two columns, a number picks
	_run(func() -> Variant: return await _console.menu("GROUND FORCES",
			["ATTACK PLANET", "RECALL TROOPS", "SHORE LEAVE", "ENLIST TROOPS", "SELL LOOT", "REPAIR/RESTOCK",
			"ESTABLISH BASE", "CRYOGENICS", "RETURN"], ["NO BASE"]))
	await _frames(3)
	_check("a program has the display, grown", _console.active() and _overlay.program_open)
	_check("the menu is titled and in two columns: %s" % str(_overlay.program.slice(0, 3)),
			_overlay.program[0] == "-GROUND FORCES-" and _overlay.program[1] == _console.columns("1) ATTACK PLANET", "6) REPAIR/RESTOCK"))
	_check("what the last command said is under it", _overlay.program.back() == "NO BASE")
	_tap(KEY_0)
	_tap(KEY_A)
	await _frames(2)
	_check("a key that is no choice does nothing", not _done)
	_tap(KEY_7)
	await _until_done()
	_check("7 is command 7", _got == 7)

	# yes and no
	_run(func() -> Variant: return await _console.ask_yes_no(["PAY THEM?"]))
	await _frames(3)
	_check("the question has Y and N under it", _overlay.program.back().begins_with("Y  YES"))
	_tap(KEY_X)
	await _frames(2)
	_check("a key that is neither does nothing", not _done)
	_tap(KEY_Y)
	await _until_done()
	_check("Y is yes", _got == true)
	_run(func() -> Variant: return await _console.ask_yes_no(["PAY?"]))
	await _frames(2)
	_tap(KEY_N)
	await _until_done()
	_check("N is no", _got == false)

	# a number: digits, a backspace, Enter
	_run(func() -> Variant: return await _console.ask_number(["ENLIST?"], "HOW MANY? "))
	await _frames(3)
	for key in [KEY_1, KEY_2, KEY_3]:
		_tap(key)
	_tap(KEY_BACKSPACE)
	_tap(KEY_4)
	_tap(KEY_X)
	await _frames(3)
	_check("the digits typed are shown (%s)" % _overlay.program.back(), _overlay.program.back().begins_with("HOW MANY? 124"))
	_tap(KEY_ENTER)
	await _until_done()
	_check("Enter ends the number: 124", _got == 124.0)
	_run(func() -> Variant: return await _console.ask_number([], ""))
	await _frames(2)
	_tap(KEY_ENTER)
	await _until_done()
	_check("nothing typed is 0", _got == 0.0)

	# a wait, cut short by a key; and one that runs out
	_console.pace = 1.0
	_run(func() -> Variant: return await _console.say(["TROOPS ARE", "RECALLED."], 30.0))
	await _frames(5)
	_check("a say shows its lines", _overlay.program == ["TROOPS ARE", "RECALLED."] and not _done)
	_tap(KEY_SPACE)
	await _until_done()
	_check("a key cuts the wait short", _done)
	_console.pace = 0.01
	_run(func() -> Variant: return await _console.say(["BRIEF"], 1.0, false))
	await _until_done()
	_check("a wait that is not to be skipped ends by itself", _done)

	_console.close()
	await _frames(3)
	_check("closing gives the display back", not _overlay.program_open and not _console.active())

	print("console driven: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## Runs a program's coroutine and keeps what it returns.
func _run(program: Callable) -> void:
	_done = false
	_got = null
	var coroutine := func() -> void:
		_got = await program.call()
		_done = true
	coroutine.call()


func _until_done() -> void:
	for i in TIMEOUT_FRAMES:
		if _done:
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
		if keycode >= KEY_0 and keycode <= KEY_9:
			event.unicode = keycode
		Input.parse_input_event(event)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1
