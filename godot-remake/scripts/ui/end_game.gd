extends Control
## Ports `END.bas` — reached via the Command Console's "4) END" (not a
## mission-end/scoring screen, despite the name; that's what this file
## turned out to actually be once traced, 2026-11-09). Three real
## options: SAVE GAME, CONTINUE PRESENT GAME (line 120's
## `RUN GALAXY MAP`), END GAME (line 100's `FOR J=1 TO 5000:POKE J,0:
## NEXT:END`, a full halt of the Applesoft program).
##
## The original BSAVEs raw memory images straight to the Apple II disk
## (`GameState.save_to_disk()`'s doc comment has the full citation);
## this port serializes the equivalent persistent fields to a JSON file
## instead — same real effect, not a byte-exact format. "END GAME"
## quits the application outright, the closest real equivalent of
## halting the original's BASIC interpreter.
##
## Skips the original's "YOU MUST BE IN ORBIT TO SAVE GAME" gate
## (`$38210`/altitude aren't modeled in this port) — same reasoning
## Repair/Restock's skipped landing gate uses (see repair_ship.gd).

@onready var _status: Label = $VBox/Status
@onready var _save_btn: Button = $VBox/SaveButton
@onready var _continue_btn: Button = $VBox/ContinueButton
@onready var _end_btn: Button = $VBox/EndButton


func _ready() -> void:
	_save_btn.pressed.connect(_on_save)
	_continue_btn.pressed.connect(_on_continue)
	_end_btn.pressed.connect(_on_end)


func _on_save() -> void:
	GameState.save_to_disk()
	_status.text = "GAME SAVED."


func _on_continue() -> void:
	GameState.goto_scene("res://scenes/galaxy_map.tscn")


func _on_end() -> void:
	get_tree().quit()
