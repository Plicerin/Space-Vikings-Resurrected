extends Control
## Generic placeholder for any state-graph node this scaffold hasn't
## built a real screen for yet. GameState.show_stub() populates the
## three fields this reads and routes here instead of a dead end, so
## the full original overlay graph stays navigable from day one.

@onready var _title_label: Label = $VBox/Title
@onready var _note_label: Label = $VBox/Note
@onready var _back_btn: Button = $VBox/BackButton


func _ready() -> void:
	_title_label.text = GameState.stub_title
	_note_label.text = GameState.stub_note
	_back_btn.pressed.connect(func(): GameState.goto_scene(GameState.stub_back_scene))
