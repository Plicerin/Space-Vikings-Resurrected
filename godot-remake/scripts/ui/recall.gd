extends Control
## Ports RECALL.bas — a thin troop-location-state check, no morale or
## credit effect.

@onready var _body: Label = $VBox/Body
@onready var _continue_btn: Button = $VBox/ContinueButton


func _ready() -> void:
	_continue_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/ground_forces.tscn"))

	var msg: String
	if GameState.troops <= 0.0:
		msg = "WE HAVE NO TROOPS LEFT, SIR!"
		GameState.troop_location = 0
	elif GameState.troops_stationed_at != GameState.current_planet + 1 and GameState.troop_location > 0 and GameState.troop_location < 3:
		msg = "TROOPS ARE NOT ON THIS PLANET, SIR!"
	elif GameState.troop_location == 1 or GameState.troop_location == 2:
		msg = "TROOPS ARE BEING RECALLED, SIR!"
		GameState.troop_location = 0
	elif GameState.troop_location == 3:
		msg = "TROOPS ARE IN CRYOGENIC SLEEP!"
	else:
		msg = "TROOPS ARE ALREADY ON BOARD, SIR!"
	_body.text = msg
