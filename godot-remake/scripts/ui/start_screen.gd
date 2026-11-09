extends Control
## START.bas's "(N)EW GAME OR (O)LD GAME?" prompt (line 60). Load Game
## is this port's equivalent of the "O" path — real persistence added
## alongside END.bas's "SAVE GAME" (see end_game.gd / GameState.
## save_to_disk()'s doc comment for why this isn't a byte-exact
## BSAVE/BLOAD port).

@onready var _new_game_btn: Button = $VBox/NewGameButton
@onready var _load_game_btn: Button = $VBox/LoadGameButton
@onready var _shape_viewer_btn: Button = $VBox/ShapeViewerButton
@onready var _combat_demo_btn: Button = $VBox/CombatDemoButton


func _ready() -> void:
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	_load_game_btn.pressed.connect(_on_load_game_pressed)
	_shape_viewer_btn.pressed.connect(_on_shape_viewer_pressed)
	_combat_demo_btn.pressed.connect(_on_combat_demo_pressed)
	_load_game_btn.disabled = not GameState.has_save_file()


func _on_new_game_pressed() -> void:
	GameState.start_new_game()
	GameState.goto_scene("res://scenes/galaxy_map.tscn")


func _on_load_game_pressed() -> void:
	GameState.load_from_disk()
	GameState.goto_scene("res://scenes/galaxy_map.tscn")


func _on_shape_viewer_pressed() -> void:
	# The pre-existing shape-table debug viewer (see README.md) — kept
	# reachable from here rather than removed, since it's still the tool
	# for visually checking converted Apple II shape data.
	GameState.goto_scene("res://scenes/planet_test.tscn")


func _on_combat_demo_pressed() -> void:
	GameState.goto_scene("res://scenes/combat_demo.tscn")
