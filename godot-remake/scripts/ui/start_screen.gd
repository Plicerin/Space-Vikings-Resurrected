extends Control
## START.bas's "(N)EW GAME OR (O)LD GAME?" prompt (line 60), as buttons.
## Load Game is the "O" path (see GameState.save_to_disk()'s doc comment
## for why this isn't a byte-exact BSAVE/BLOAD port).
##
## The original's rule for a saved game is kept (GameState.boot()): it
## can be taken up at the next boot and at no other, because the boot
## takes the mark off the disk before it asks. Answer N and it is gone
## as well. "O" with nothing saved is line 73's message, which stays up
## for a FOR loop of 3000: 170 frames on the real machine
## (analysis/live/save/save_none.log).

const NO_GAME_SAVED := "THERE IS NO GAME SAVED"
const NO_GAME_SAVED_FRAMES := 170.0 # FOR I = 1 TO 3000: NEXT

@onready var _new_game_btn: Button = $VBox/NewGameButton
@onready var _load_game_btn: Button = $VBox/LoadGameButton
@onready var _shape_viewer_btn: Button = $VBox/ShapeViewerButton
@onready var _combat_demo_btn: Button = $VBox/CombatDemoButton
@onready var _native_flight_btn: Button = $VBox/NativeFlightButton
@onready var _status: Label = $VBox/Status


func _ready() -> void:
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	_load_game_btn.pressed.connect(_on_load_game_pressed)
	_shape_viewer_btn.pressed.connect(_on_shape_viewer_pressed)
	_combat_demo_btn.pressed.connect(_on_combat_demo_pressed)
	_native_flight_btn.pressed.connect(_on_native_flight_pressed)
	if not GameState.booted:
		GameState.boot()


func _on_new_game_pressed() -> void:
	GameState.start_new_game()
	GameState.goto_scene("res://scenes/flight/space_flight.tscn")


func _on_load_game_pressed() -> void:
	if not GameState.old_game: # line 73
		_status.text = NO_GAME_SAVED
		await get_tree().create_timer(NO_GAME_SAVED_FRAMES / 60.0).timeout
		_status.text = ""
		return
	GameState.load_from_disk()
	GameState.goto_scene("res://scenes/flight/space_flight.tscn")


func _on_shape_viewer_pressed() -> void:
	# The pre-existing shape-table debug viewer (see README.md) — kept
	# reachable from here rather than removed, since it's still the tool
	# for visually checking converted Apple II shape data.
	GameState.goto_scene("res://scenes/planet_test.tscn")


func _on_combat_demo_pressed() -> void:
	GameState.goto_scene("res://scenes/combat_demo.tscn")


## The flight in Godot's own 3D, not finished: it has no fighting, no way
## down to the planet and no hyperdrive yet.
func _on_native_flight_pressed() -> void:
	GameState.start_new_game()
	GameState.goto_scene("res://scenes/native_flight.tscn")
