extends Control
## Ports COM.bas's main menu (lines 20-127): Computer / Ground Forces /
## Radar / End / Return.

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
	GameState.show_stub(
		"COMPUTER",
		"Per-planet tech/population/secured/base readout — COM.bas lines 990-1180.",
		"res://scenes/com.tscn"
	)


func _on_ground_forces_pressed() -> void:
	GameState.goto_scene("res://scenes/ground_forces.tscn")


func _on_radar_pressed() -> void:
	GameState.goto_scene("res://scenes/radar.tscn")


func _on_end_pressed() -> void:
	GameState.show_stub("END", "Mission end/scoring sequence — not yet traced.", "res://scenes/com.tscn")


func _on_status_pressed() -> void:
	GameState.goto_scene("res://scenes/status.tscn")


func _on_return_pressed() -> void:
	GameState.goto_scene("res://scenes/flight/space_flight.tscn")
