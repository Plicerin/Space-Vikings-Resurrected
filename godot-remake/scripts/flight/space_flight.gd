extends Node3D
## Mode-switch wrapper for the space-flight scene, standing in for
## STARSHIP SIMULATOR.bas's own mode-switch keys (RUNCOM/RUNRADAR/etc,
## line ~150/200-210) — remapped to modern keys via autoload/input_setup.gd
## rather than the original's raw PDL()/key-code checks.

@onready var _debug_label: Label = $HUD/DebugLabel


func _process(_delta: float) -> void:
	_debug_label.text = (
		"PITCH %d   BANK %d   HEADING %d   THROTTLE %.2f\nPOS %s\n\n[C] Command Console   [G] Ground Forces (when in range)"
		% [
			int(GameState.pitch_deg), int(GameState.bank_deg), int(GameState.heading_deg),
			GameState.throttle, GameState.ship_position,
		]
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_com"):
		GameState.goto_scene("res://scenes/com.tscn")
	elif event.is_action_pressed("open_ground_forces"):
		GameState.goto_scene("res://scenes/ground_forces.tscn")
