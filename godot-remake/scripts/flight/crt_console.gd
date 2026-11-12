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
signal resolved
## What is typed in a number being asked changed (to the number, or 0 for nothing): for a map to follow.
signal typed_changed(value: int)

const COLUMNS := 40
const BlockFont = preload("res://scripts/flight/block_font.gd")

## The flight's display panel (hud_overlay.gd).
var overlay: Control
## Tests shorten every wait by this.
var pace := 1.0

var _mode := "" ## "", "menu", "yesno", "number", "wait", "key"
var _count := 0 ## items in the menu being asked
var _back := 0 ## the menu's item that goes back (Escape takes it), or 0
var _hint: Callable ## says something of the number being typed, on the line at the foot
var _skippable := true
var _answer: Variant = null
var _typed := ""
var _cancellable := false
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
## what the last command said (if anything) under it, and `header` lines (a list
## the choices are about) between the title and the items. Returns the number. Escape
## takes the item `back` (the one that goes back or leaves), if there is one.
func menu(title: String, items: Array, said: Array = [], header: Array = [], back := 0) -> int:
	var lines: Array = ["-%s-" % title]
	lines.append_array(header)
	var rows := (items.size() + 1) / 2 if items.size() > 5 else items.size()
	for row in rows:
		var left := "%d) %s" % [row + 1, items[row]]
		if items.size() > 5 and row + rows < items.size():
			lines.append(columns(left, "%d) %s" % [row + rows + 1, items[row + rows]]))
		else:
			lines.append(left)
	lines.append_array(flow(said))
	if not said.is_empty():
		AudioManager.play_refuse()
	show(lines)
	_count = items.size()
	_back = back
	_mode = "menu"
	await resolved
	return int(_answer)


func ask_yes_no(lines: Array) -> bool:
	var shown := lines.duplicate()
	shown.append(columns("Y  YES", "N  NO"))
	show(shown)
	_mode = "yesno"
	await resolved
	return bool(_answer)


## A whole number from the digits typed, Enter to end it; nothing typed is 0.
## Escape is 0, or -1 if the question may be given up (`cancellable`). `hint` (a function of
## the number typed so far, giving a line or "") puts a line at the foot of the display, such as
## the name of the star a number is.
func ask_number(lines: Array, prompt := "", cancellable := false, hint := Callable()) -> float:
	_cancellable = cancellable
	_hint = hint
	_fixed = lines
	_prompt = prompt
	_typed = ""
	_mode = "number"
	_show_number()
	await resolved
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
	get_tree().create_timer(maxf(seconds * pace, 0.001)).timeout.connect(_wait_over.bind(mine))
	await resolved
	_mode = ""


func _wait_over(token: int) -> void:
	if _mode == "wait" and _token == token:
		_finish(null)


## Waits for any key; returns its keycode.
func any_key(lines: Array) -> int:
	show(lines)
	_mode = "key"
	await resolved
	return int(_answer)


## Called by the flight for every key while `active()`. Returns whether it took it.
func handle_key(key: InputEventKey) -> bool:
	if not active() or not key.pressed:
		return active()
	key_pressed.emit(key.keycode)
	if key.echo:
		return true
	AudioManager.play_key()
	match _mode:
		"menu":
			var number := _digit(key)
			if number >= 1 and number <= _count:
				AudioManager.play_select()
				_finish(number)
			elif key.keycode == KEY_ESCAPE and _back > 0:
				AudioManager.play_select()
				_finish(_back)
		"yesno":
			if key.keycode == KEY_Y:
				_finish(true)
			elif key.keycode == KEY_N or key.keycode == KEY_ESCAPE:
				_finish(false)
		"number":
			var number := _digit(key)
			if number >= 0 and _typed.length() < 6:
				_typed += str(number)
				typed_changed.emit(int(_typed))
			elif key.keycode == KEY_BACKSPACE:
				_typed = _typed.left(maxi(_typed.length() - 1, 0))
				typed_changed.emit(int(_typed))
			elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
				_finish(float(_typed) if _typed != "" else 0.0)
			elif key.keycode == KEY_ESCAPE:
				_finish(-1.0 if _cancellable else 0.0)
		"wait":
			if _skippable:
				_finish(null)
		"key":
			_finish(key.keycode)
	return true


## A number put into the one being asked, as if typed (a click on a map).
func type_number(value: int) -> void:
	if _mode != "number":
		return
	_typed = str(value)
	typed_changed.emit(value)
	AudioManager.play_select()


func _finish(value: Variant) -> void:
	_answer = value
	_mode = ""
	resolved.emit()


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
	# the prompt wraps at the forty columns, and what is typed goes on the line it
	# fits, or the next: a long question and four digits would run off the display
	var asked := flow([_prompt.strip_edges()])
	var last: String = asked.pop_back() if not asked.is_empty() else ""
	var typed := (" " if last != "" else "") + _typed
	if last.length() + typed.length() + 1 > COLUMNS:
		asked.append(last)
		last = _typed
	else:
		last += typed
	asked.append(last + ("_" if int(_time * 2.0) % 2 == 0 else " "))
	lines.append_array(asked)
	if _hint.is_valid():
		var note: String = _hint.call(int(_typed) if _typed != "" else 0)
		if note != "":
			lines.append(note)
	show(lines)


## Text the original broke into narrow lines, run together and broken again at the
## forty columns; a blank line is a new paragraph. (The pages the programs get
## from the rules were written for a narrow window.)
static func flow(lines: Array) -> Array:
	var out: Array = []
	var paragraph := ""
	for line in lines:
		if str(line).strip_edges() == "":
			if paragraph != "":
				out.append_array(BlockFont.wrap(paragraph, 1.0, COLUMNS * BlockFont.ADVANCE))
				paragraph = ""
			if not out.is_empty() and out.back() != "":
				out.append("")
		else:
			paragraph = str(line).strip_edges() if paragraph == "" else "%s %s" % [paragraph, str(line).strip_edges()]
	if paragraph != "":
		out.append_array(BlockFont.wrap(paragraph, 1.0, COLUMNS * BlockFont.ADVANCE))
	if not out.is_empty() and out.back() == "":
		out.pop_back()
	return out


## Two columns on the forty: `right` starts at the twenty-first.
static func columns(left: String, right: String, width := 20) -> String:
	return left.rpad(width).left(width) + right
