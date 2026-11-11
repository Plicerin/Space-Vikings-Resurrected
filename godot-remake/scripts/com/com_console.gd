extends Control
## COM, the command console: its menus, the damage-control lamps, the
## navigation computer and the galaxy directory, on one panel. What each
## choice does and what the console says is scripts/rules/com_rules.gd,
## which is held to the real game (tests/check_com_rules.gd); this shows
## it, asks, and goes to whichever program the original ran.
##
## Where it parts from the original, on purpose:
## - a wrong key is not scolded and waited out; only the keys that are
##   offered do anything;
## - the directory's stars are buttons, as well as the number asked for;
## - "2) RETURN" in the directory comes out at the command menu, as the
##   original's does, and not the navigation computer it names;
## - the lamps are always on show, where the original paints them before
##   its menu and leaves them under the other screens.

const ComRules = preload("res://scripts/rules/com_rules.gd")

const FLIGHT := "res://scenes/flight/space_flight.tscn"
const GROUND_FORCES := "res://scenes/ground_forces.tscn"
const RADAR := "res://scenes/radar.tscn"
const END := "res://scenes/end_game.tscn"
const CHART := "res://scenes/star_chart.tscn"
const STATUS := "res://scenes/status.tscn"
const SUPPLY := "res://scenes/supply_report.tscn"

# Seconds.
const SAID := 2.0
const COURSE_SET := 1.5

const LAMP_OK := Color(0.1, 0.12, 0.1)
const LAMP_OUT := Color(0.85, 0.15, 0.1)

## Tests shorten every wait by this.
var pace := 1.0

## What a digit key does now: picks the numbered button.
var _choices: Array[Callable] = []
## What the entry's RETURN does now.
var _entered: Callable

@onready var _hold: Timer = $Hold
@onready var _title: Label = $Center/Columns/Console/VBox/Title
@onready var _said: Label = $Center/Columns/Console/VBox/Said
@onready var _stars: GridContainer = $Center/Columns/Console/VBox/Stars
@onready var _buttons: VBoxContainer = $Center/Columns/Console/VBox/Buttons
@onready var _entry: HBoxContainer = $Center/Columns/Console/VBox/Entry
@onready var _prompt: Label = $Center/Columns/Console/VBox/Entry/Prompt
@onready var _field: LineEdit = $Center/Columns/Console/VBox/Entry/Field
@onready var _lamps: GridContainer = $Center/Columns/Lamps/VBox/Grid


func _ready() -> void:
	_field.text_changed.connect(_keep_digits)
	_field.text_submitted.connect(func(text: String) -> void: _entered.call(text.to_int()))
	_show_lamps()
	if ComRules.ground_forces_due(): # RECALL's and SHORE LEAVE's bounce
		_go.call_deferred(GROUND_FORCES)
		return
	var star := ComRules.chart_star() # the chart's "Y"
	if star > 0:
		_page(star)
	else:
		_command_menu()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _entry.visible:
		return
	var number := key.unicode - 48
	if number >= 1 and number <= _choices.size():
		get_viewport().set_input_as_handled()
		_choices[number - 1].call()


func _go(scene: String) -> void:
	GameState.goto_scene(scene)


# --- the lamps ---


## @witness COM 40-80
func _show_lamps() -> void:
	for cell in _lamps.get_children():
		cell.free()
	for lamp: Array in ComRules.lamps():
		var cell := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = LAMP_OUT if lamp[2] else LAMP_OK
		style.set_content_margin_all(6)
		cell.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = "%s\n%s" % [lamp[0].strip_edges(), lamp[1].strip_edges()]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.x = 64
		cell.add_child(label)
		_lamps.add_child(cell)


# --- the screens ---


## A screen with `title` and a button for each of `items`, numbered;
## `picked` is called with the number chosen.
func _menu(title: String, items: Array, picked: Callable) -> void:
	_screen(title)
	_choices.clear()
	for i in items.size():
		var number := i + 1
		var button := Button.new()
		button.text = "%d) %s" % [number, items[i]]
		button.theme_type_variation = &"OrderButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var chosen := func() -> void: picked.call(number)
		button.pressed.connect(chosen)
		_buttons.add_child(button)
		_choices.append(chosen)
	(_buttons.get_child(0) as Button).grab_focus()


func _screen(title: String, said: Array = []) -> void:
	_hold.stop()
	_title.text = title
	_say(said)
	_choices.clear()
	_entered = Callable()
	# taken out at once, and freed when the button that was pressed is done with
	for button in _buttons.get_children():
		_buttons.remove_child(button)
		button.queue_free()
	for cell in _stars.get_children():
		_stars.remove_child(cell)
		cell.queue_free()
	_stars.hide()
	_entry.hide()


func _say(lines: Array) -> void:
	_said.text = "\n".join(lines)


## `prompt`, and a field for a number of one or two digits.
func _ask(prompt: String, entered: Callable) -> void:
	_prompt.text = prompt
	_field.clear()
	_entry.show()
	_entered = entered
	_field.edit()


func _keep_digits(text: String) -> void:
	var digits := ""
	for character in text:
		if character >= "0" and character <= "9":
			digits += character
	if digits != text:
		_field.text = digits
		_field.caret_column = digits.length()


## `then` after `seconds`, or at once if the player moves on.
func _later(seconds: float, then: Callable) -> void:
	_hold.timeout.connect(then, CONNECT_ONE_SHOT)
	_hold.start(maxf(seconds * pace, 0.001))


func _back_button(label: String, then: Callable, focus := true) -> void:
	var button := Button.new()
	button.text = label
	button.theme_type_variation = &"OrderButton"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(then)
	_buttons.add_child(button)
	if focus:
		button.grab_focus()


# --- the menus ---


## @witness COM 90-135
func _command_menu() -> void:
	_menu("COMMAND MODE", ComRules.COMMANDS, _command_picked)


func _command_picked(choice: int) -> void:
	var goes := ComRules.command(choice)
	if goes == ComRules.Goes.CENTRAL:
		_central()
	elif goes == ComRules.Goes.GROUND_FORCES:
		_go(GROUND_FORCES)
	elif goes == ComRules.Goes.RADAR:
		_go(RADAR)
	elif goes == ComRules.Goes.END:
		_go(END)
	else:
		_go(FLIGHT)


## @witness COM 200-280
func _central() -> void:
	if ComRules.computer_out():
		_screen("CENTRAL COMPUTER", ComRules.SAID_COMPUTER_OUT)
		_later(SAID, _command_menu)
		return
	_menu("CENTRAL COMPUTER", ComRules.CENTRAL, _central_picked)


func _central_picked(choice: int) -> void:
	var goes := ComRules.central(choice)
	if goes == ComRules.Central.NAVIGATION:
		_navigation()
	elif goes == ComRules.Central.DIRECTORY:
		_directory()
	elif goes == ComRules.Central.GALAXY_MAP:
		_go(CHART)
	elif goes == ComRules.Central.STATUS:
		_go(STATUS)
	elif goes == ComRules.Central.SUPPLY:
		_go(SUPPLY)
	else:
		_command_menu()


## @witness COM 800-850
func _navigation() -> void:
	_menu("NAVIGATION COMPUTER", ComRules.NAVIGATION, _navigation_picked)


func _navigation_picked(choice: int) -> void:
	if choice == 1:
		_directory()
	elif choice == 2:
		_course()
	else:
		_command_menu()


## @witness COM 860-897
func _course() -> void:
	_screen("NAVIGATION COMPUTER")
	_ask("ENTER DESIRED DESTINATION (1-20)", _course_entered)


func _course_entered(c: int) -> void:
	var set_ := c >= 1 and c <= ComRules.STARS and c != GameState.current_planet + 1
	_say(ComRules.course(c))
	_entry.hide()
	if set_:
		_later(COURSE_SET, _navigation)
	else:
		_later(SAID, _course)


## @witness COM 900-969
func _directory() -> void:
	_screen("GALAXY DIRECTORY")
	_stars.show()
	for c in range(1, ComRules.STARS + 1):
		var button := Button.new()
		button.text = "%d) %s" % [c, ComRules.NAMES[c - 1]]
		button.theme_type_variation = &"OrderButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_page.bind(c))
		_stars.add_child(button)
	_back_button("RETURN", _command_menu, false)
	_ask("WHICH SYSTEM?", _system_entered) # the field has the keys; Tab goes to the buttons


func _system_entered(c: int) -> void:
	if ComRules.is_star(c):
		_page(c)
	else:
		_say(["TRY AGAIN PLEASE."])
		_field.clear()


## @witness COM 970-1180
func _page(c: int) -> void:
	_screen("%s STAR SYSTEM" % ComRules.NAMES[c - 1], ComRules.star_page(c))
	_back_button("RETURN", _page_closed)


func _page_closed() -> void:
	if ComRules.page_closed():
		_go(CHART)
	else:
		_directory()
