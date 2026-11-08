extends Control
## Ports `SHORE LEAVE.bas`'s "ESTABLISH BASE" option (lines 2100-2160).
##
## Quirk kept as-is, not a bug introduced here: the original marks the
## once-per-trip flag (`$38149`, `base_built_this_trip`) the moment you
## reach the cost quote (line 2107), *before* the Y/N prompt — so
## declining on cost, or saying "N", still uses up your one
## base-building attempt for this trip. Confirmed directly from the
## source, not an assumption.

const MIN_TECH_TO_BUILD := 2

@onready var _body: Label = $VBox/Body
@onready var _button_row: HBoxContainer = $VBox/ButtonRow
@onready var _continue_btn: Button = $VBox/ButtonRow/ContinueButton
@onready var _yes_btn: Button = $VBox/ButtonRow/YesButton
@onready var _no_btn: Button = $VBox/ButtonRow/NoButton

var _cost: float = 0.0


func _ready() -> void:
	_continue_btn.pressed.connect(_return)
	_yes_btn.pressed.connect(_on_yes)
	_no_btn.pressed.connect(_return)

	var planet := GameState.current_planet
	if GameState.planet_has_base[planet]:
		_show_refusal("THERE IS ALREADY\nA BASE ON THIS\nPLANET, SIR!")
		return
	if GameState.planet_tech[planet] < MIN_TECH_TO_BUILD:
		_show_refusal("THIS PLANET IS TOO\nBACKWARD TO BUILD\nA BASE, SIR!")
		return
	if GameState.base_built_this_trip:
		_show_refusal("ONLY ONE TIME PER\nTRIP, SIR.")
		return

	# Line 2107: the attempt is consumed here, before the Y/N prompt —
	# see doc comment above.
	GameState.base_built_this_trip = true
	_cost = GameState.roll_base_cost()

	if GameState.credits < _cost:
		_show_refusal(
			"SIR! IT WILL COST %d TO BUILD A BASE HERE.\n\nYOU DON'T HAVE ENOUGH CREDITS TO BUILD A BASE HERE."
			% int(_cost)
		)
		return

	_body.text = (
		"SIR! IT WILL COST %d TO BUILD A BASE HERE.\n\nYOU HAVE %d CREDITS NOW.\n\nBUILD A BASE? (Y/N)"
		% [int(_cost), int(GameState.credits)]
	)
	_yes_btn.visible = true
	_no_btn.visible = true
	_continue_btn.visible = false


func _show_refusal(message: String) -> void:
	_body.text = message
	_yes_btn.visible = false
	_no_btn.visible = false
	_continue_btn.visible = true


func _on_yes() -> void:
	GameState.credits -= _cost
	GameState.planet_has_base[GameState.current_planet] = true
	_body.text = "CONSTRUCTION IS\nUNDER WAY, SIR."
	_yes_btn.visible = false
	_no_btn.visible = false
	_continue_btn.visible = true


func _return() -> void:
	GameState.goto_scene("res://scenes/ground_forces.tscn")
