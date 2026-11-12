extends Node
## The console's way of talking to the player: what a program (GROUND FORCES,
## SHORE LEAVE, the command console) says on the CRT display, and the keys it
## asks for. A program is a coroutine that awaits these:
##
##   var choice: int = await console.menu("GROUND FORCES", ["ATTACK PLANET", ...], said)
##   var yes: bool = await console.ask_yes_no(["PAY THEM?"])
##   var how_many: float = await console.ask_number(["HOW MANY TROOPS?"])
##   await console.say(["TROOPS ARE BEING", "RECALLED, SIR!"], 3.0)
##
## While a program is up the display grows upward to show a screenful, and the
## keys belong to it (the flight goes on beneath). Waits are cut short by any
## key; `pace` shortens every wait, for tests.

signal key_pressed(keycode: int)
signal _resolved

const COLUMNS := 40

## The flight's display panel (hud_overlay.gd).
var overlay: Control
## Tests shorten every wait by this.
var pace := 1.0

var _mode := "" ## "", "menu", "yesno", "number", "wait", "key"
var _count := 0 ## items in the menu being asked
var _skippable := true
var _answer: Variant = null
var _typed := ""
var _fixed: Array = [] ## the lines above the prompt of a number being asked
var _prompt := ""
var _token := 0
var _time := 0.0


## True while a program has the display (even between its questions).
func active() -> bool:
	return overlay != null and overlay.program_open


func _process(delta: float) -> void:
	_time += delta
	if _mode == "number":
		_show_number()


## Puts up lines on the display and takes the keys until `close`.
func show(lines: Array) -> void:
	overlay.program_open = true
	overlay.program = lines


func close() -> void:
	_mode = ""
	if overlay != null:
		overlay.program_open = false
		overlay.program = []


## A numbered menu, in two columns when it has more than five items, with
## what the last command said (if anything) under it. Returns the number.
func menu(title: String, items: Array, said: Array = []) -> int:
	var lines: Array = ["-%s-" % title]
	var rows := (items.size() + 1) / 2 if items.size() > 5 else items.size()
	for row in rows:
		var left := "%d) %s" % [row + 1, items[row]]
		if items.size() > 5 and row + rows < items.size():
			lines.append(columns(left, "%d) %s" % [row + rows + 1, items[row + rows]]))
		else:
			lines.append(left)
	if not said.is_empty():
		lines.append("")
		lines.append_array(said)
	show(lines)
	_count = items.size()
	_mode = "menu"
	await _resolved
	return int(_answer)


func ask_yes_no(lines: Array) -> bool:
	var shown := lines.duplicate()
	shown.append(columns("Y  YES", "N  NO"))
	show(shown)
	_mode = "yesno"
	await _resolved
	return bool(_answer)


## A whole number from the digits typed, Enter to end it; nothing typed is 0.
func ask_number(lines: Array, prompt := "") -> float:
	_fixed = lines
	_prompt = prompt
	_typed = ""
	_mode = "number"
	_show_number()
	await _resolved
	return float(_answer)


## Shows `lines` and waits `seconds` (or for a key, if it may be skipped).
## With 0 seconds it only puts them up.
func say(lines: Array, seconds := 0.0, skippable := true) -> void:
	show(lines)
	if seconds <= 0.0:
		return
	await wait(seconds, skippable)


## A wait that a key may cut short.
func wait(seconds: float, skippable := true) -> void:
	_mode = "wait"
	_skippable = skippable
	_token += 1
	var mine := _token
	get_tree().create_timer(maxf(seconds * pace, 0.001)).timeout.connect(func() -> void:
		if _mode == "wait" and _token == mine:
			_finish(null))
	await _resolved
	_mode = ""


## Waits for any key; returns its keycode.
func any_key(lines: Array) -> int:
	show(lines)
	_mode = "key"
	await _resolved
	return int(_answer)


## Called by the flight for every key while `active()`. Returns whether it took it.
func handle_key(key: InputEventKey) -> bool:
	if not active() or not key.pressed:
		return active()
	key_pressed.emit(key.keycode)
	if key.echo:
		return true
	match _mode:
		"menu":
			var number := _digit(key)
			if number >= 1 and number <= _count:
				_finish(number)
		"yesno":
			if key.keycode == KEY_Y:
				_finish(true)
			elif key.keycode == KEY_N or key.keycode == KEY_ESCAPE:
				_finish(false)
		"number":
			var number := _digit(key)
			if number >= 0 and _typed.length() < 6:
				_typed += str(number)
			elif key.keycode == KEY_BACKSPACE:
				_typed = _typed.left(maxi(_typed.length() - 1, 0))
			elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
				_finish(float(_typed) if _typed != "" else 0.0)
			elif key.keycode == KEY_ESCAPE:
				_finish(0.0)
		"wait":
			if _skippable:
				_finish(null)
		"key":
			_finish(key.keycode)
	return true


func _finish(value: Variant) -> void:
	_answer = value
	_mode = ""
	_resolved.emit()


func _digit(key: InputEventKey) -> int:
	if key.unicode >= 48 and key.unicode <= 57:
		return key.unicode - 48
	if key.keycode >= KEY_0 and key.keycode <= KEY_9:
		return key.keycode - KEY_0
	if key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		return key.keycode - KEY_KP_0
	return -1


func _show_number() -> void:
	var lines := _fixed.duplicate()
	lines.append("%s%s%s" % [_prompt, _typed, "_" if int(_time * 2.0) % 2 == 0 else " "])
	show(lines)


## Two columns on the forty: `right` starts at the twenty-first.
static func columns(left: String, right: String, width := 20) -> String:
	return left.rpad(width).left(width) + right
