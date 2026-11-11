extends Control
## Ports `END.bas` — reached via the Command Console's "4) END" (not a
## mission-end/scoring screen, despite the name; that's what this file
## turned out to actually be once traced, 2026-11-09). Three real
## options: SAVE GAME, CONTINUE PRESENT GAME, END GAME (line 100's
## `FOR J=1 TO 5000:POKE J,0: NEXT:END`, a full halt of the Applesoft
## program).
##
## CONTINUE is line 120's `POKE 38391,77: RUN GALAXY MAP`, and it is not
## the chart that comes up: with that 77, GALAXY MAP.bas's line 2 paints
## the eight panel lamps as plain blocks (its GOSUB 5000) and runs
## STARSHIP SIMULATOR. So it is here: the blocks, then flight.
##
## The original BSAVEs raw memory images straight to the Apple II disk
## (`GameState.save_to_disk()`'s doc comment has the full citation);
## this port serializes the equivalent persistent fields to a JSON file
## instead — same real effect, not a byte-exact format. "END GAME"
## quits the application outright, the closest real equivalent of
## halting the original's BASIC interpreter.
##
## Line 190: no saving in the atmosphere (`$38210`).

const ChartProgram = preload("res://scripts/chart/chart_program.gd")

@onready var _status: Label = $VBox/Status
@onready var _save_btn: Button = $VBox/SaveButton
@onready var _continue_btn: Button = $VBox/ContinueButton
@onready var _end_btn: Button = $VBox/EndButton


func _ready() -> void:
	_save_btn.pressed.connect(_on_save)
	_continue_btn.pressed.connect(_on_continue)
	_end_btn.pressed.connect(_on_end)


func _on_save() -> void:
	if GameState.in_atmosphere: # line 190
		_status.text = "YOU MUST BE IN ORBIT TO SAVE GAME"
		return
	GameState.save_to_disk()
	_status.text = "GAME SAVED."


func _on_continue() -> void:
	var chart := ChartProgram.new()
	for block: Array in chart.lamp_blocks():
		chart.lamp_block(block)
	GameState.view3d.shown = 0 # GALAXY MAP.bas line 2: POKE -16300,0
	GameState.goto_scene("res://scenes/flight/space_flight.tscn")


func _on_end() -> void:
	get_tree().quit()
