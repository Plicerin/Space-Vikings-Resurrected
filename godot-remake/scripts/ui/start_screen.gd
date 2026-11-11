extends Control
## The title: a new game, or the game saved from END's menu. CONTINUE is
## there when there is a saved game and stays so until it is saved over
## (the original used a saved game up at the next boot; see the README).

@onready var _new_game_btn: Button = $VBox/NewGameButton
@onready var _continue_btn: Button = $VBox/ContinueButton


func _ready() -> void:
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_continue_btn.disabled = not GameState.has_saved_game()
	(_continue_btn if not _continue_btn.disabled else _new_game_btn).grab_focus()


func _on_new_game_pressed() -> void:
	GameState.start_new_game()
	GameState.goto_scene(GameState.flight_scene)


func _on_continue_pressed() -> void:
	GameState.load_from_disk()
	GameState.goto_scene(GameState.flight_scene)
