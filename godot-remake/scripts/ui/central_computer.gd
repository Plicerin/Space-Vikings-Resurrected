extends Control
## Ports COM.bas's "CENTRAL COMPUTER" sub-menu (lines 200-280),
## reached via the top-level Command Console's "1) COMPUTER". Gated on
## `GameState.ship_computer` (line 215's `IF PEEK(38196)=0 THEN
## "COMPUTER NOT FUNCTIONING."`) — the same field Repair/Restock
## already models and can zero out via ambient combat damage
## (flight_combat.gd).
##
## "6) RETURN" (line 280's `IF C=6 THEN 12`) lands back at the
## top-level Command Console (`com.tscn`) — same real destination
## every sub-screen under this menu uses (see galaxy_directory.gd's
## doc comment).

@onready var _menu: VBoxContainer = $VBox/Menu
@onready var _not_functioning: VBoxContainer = $VBox/NotFunctioning


func _ready() -> void:
	$VBox/NotFunctioning/ContinueButton.pressed.connect(func(): GameState.goto_scene("res://scenes/com.tscn"))

	if GameState.ship_computer <= 0.0:
		_menu.visible = false
		_not_functioning.visible = true
		return

	$VBox/Menu/NavigationButton.pressed.connect(func(): GameState.goto_scene("res://scenes/nav_computer.tscn"))
	$VBox/Menu/DirectoryButton.pressed.connect(func(): GameState.goto_scene("res://scenes/galaxy_directory.tscn"))
	$VBox/Menu/GalaxyMapButton.pressed.connect(func(): GameState.goto_scene("res://scenes/star_chart.tscn"))
	$VBox/Menu/ShipStatusButton.pressed.connect(func(): GameState.goto_scene("res://scenes/status.tscn"))
	$VBox/Menu/SuppliesButton.pressed.connect(func(): GameState.goto_scene("res://scenes/supply_report.tscn"))
	$VBox/Menu/ReturnButton.pressed.connect(func(): GameState.goto_scene("res://scenes/com.tscn"))
