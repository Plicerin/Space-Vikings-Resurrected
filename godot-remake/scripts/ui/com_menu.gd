extends Control
## Ports COM.bas's main menu (lines 20-127): Computer / Ground Forces /
## Radar / End / Return. "End" isn't a mission-end/scoring screen
## despite the name — it's Save/Continue/Quit (see end_game.gd).
## "Computer" leads to its own 5-option sub-menu (see
## central_computer.gd).

@onready var _computer_btn: Button = $VBox/ComputerButton
@onready var _ground_forces_btn: Button = $VBox/GroundForcesButton
@onready var _radar_btn: Button = $VBox/RadarButton
@onready var _end_btn: Button = $VBox/EndButton
@onready var _return_btn: Button = $VBox/ReturnButton
@onready var _status_btn: Button = $VBox/StatusButton


func _ready() -> void:
	_computer_btn.pressed.connect(_on_computer_pressed)
	_ground_forces_btn.pressed.connect(_on_ground_forces_pressed)
	_radar_btn.pressed.connect(_on_radar_pressed)
	_end_btn.pressed.connect(_on_end_pressed)
	_return_btn.pressed.connect(_on_return_pressed)
	_status_btn.pressed.connect(_on_status_pressed)


func _on_computer_pressed() -> void:
	GameState.goto_scene("res://scenes/central_computer.tscn")


func _on_ground_forces_pressed() -> void:
	GameState.goto_scene("res://scenes/ground_forces.tscn")


func _on_radar_pressed() -> void:
	GameState.goto_scene("res://scenes/radar.tscn")


func _on_end_pressed() -> void:
	# Not a mission-end/scoring sequence, despite the name — turned out
	# to be Save/Continue/Quit once traced (END.bas). See end_game.gd.
	GameState.goto_scene("res://scenes/end_game.tscn")


func _on_status_pressed() -> void:
	GameState.goto_scene("res://scenes/status.tscn")


func _on_return_pressed() -> void:
	GameState.goto_scene("res://scenes/flight/space_flight.tscn")
