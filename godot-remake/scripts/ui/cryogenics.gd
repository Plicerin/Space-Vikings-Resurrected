extends Control
## Ports `SHORE LEAVE.bas` lines 4000-4020 ("CRYOGENICS", `$38388 = 5`).
## A pure toggle on `troop_location` ($38166) — no credit or morale
## effect modeled in the source itself. Unlike the other Shore Leave
## options, this one is NOT gated on having a base (GROUND FORCES.bas
## line 65's base check only covers COM 3-6; Cryogenics is COM 8).

@onready var _body: Label = $VBox/Body
@onready var _continue_btn: Button = $VBox/ContinueButton


func _ready() -> void:
	_continue_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/ground_forces.tscn"))

	var msg: String
	if GameState.troop_location == 1 or GameState.troop_location == 2:
		msg = "TROOPS NOT ON BOARD, SIR."
	elif GameState.troop_location == 3:
		msg = "TROOPS ARE BEING REVIVED, SIR."
		GameState.troop_location = 0
	else:
		msg = "TROOPS ARE BEING PUT IN CRYOGENICS"
		GameState.troop_location = 3
	_body.text = msg
