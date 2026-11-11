extends Control
## END: save the game, go on with it, or end it. What each does and says
## is scripts/rules/end_rules.gd, held to the real game
## (tests/check_end_rules.gd); this shows it and goes where the original
## went: on with the game is the flight scene, ending it closes the
## application.
##
## Where it parts from the original, on purpose: three buttons (or the
## keys 1 to 3) and nothing else is a choice, where any other key was a
## SYSTEM ERROR and a reboot; "3) END GAME" closes the application
## cleanly instead of zeroing the machine's zero page.

const EndRules = preload("res://scripts/rules/end_rules.gd")

const SAID := 3.0 ## seconds a message stays

## Tests shorten every wait by this.
var pace := 1.0

var _rules := EndRules.new()

@onready var _hold: Timer = $Hold
@onready var _said: Label = $Center/Panel/VBox/Said
@onready var _buttons: VBoxContainer = $Center/Panel/VBox/Buttons


func _ready() -> void:
	_hold.timeout.connect(func() -> void: _said.text = "")
	for i in EndRules.CHOICES.size():
		var button := Button.new()
		button.text = "%d) %s" % [i + 1, EndRules.CHOICES[i]]
		button.theme_type_variation = &"OrderButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_choose.bind(i + 1))
		_buttons.add_child(button)
	(_buttons.get_child(0) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var number := key.unicode - 48
		if number >= 1 and number <= EndRules.CHOICES.size():
			get_viewport().set_input_as_handled()
			_choose(number)


## @witness END 70-100
func _choose(number: int) -> void:
	match number:
		1:
			_said.text = "\n".join(_rules.save())
			_hold.start(maxf(SAID * pace, 0.001))
		2:
			_rules.continue_game()
			GameState.goto_scene(GameState.flight_scene)
		3:
			get_tree().quit()
