extends Control
## Ports `SHORE LEAVE.bas`'s "ENLIST TROOPS" option (lines 2200-2300).
## 1 credit per troop; input via a SpinBox standing in for the
## original's digit-by-digit numeric-entry subroutine (line 5000) —
## same ultimate effect, not a byte-exact port of that subroutine.
##
## Quirk kept as-is: like Establish Base, the once-per-trip flag
## (`$38389`, `enlisted_this_trip`) is consumed the moment you reach
## this screen (line 2220), before you've entered a number at all —
## confirmed directly from the source. Simplified, not ported exactly:
## the original additionally *clears* that same flag and restarts the
## whole screen if your requested amount would push total troops over
## 20000 (line 2285) — this port just lets you pick a smaller number
## without the restart, since nothing else on this screen can change
## in between to make that distinction observable.

const MAX_TOTAL_TROOPS := 20000.0

@onready var _body: Label = $VBox/Body
@onready var _input_row: HBoxContainer = $VBox/InputRow
@onready var _spin: SpinBox = $VBox/InputRow/SpinBox
@onready var _enlist_btn: Button = $VBox/InputRow/EnlistButton
@onready var _continue_btn: Button = $VBox/ContinueButton


func _ready() -> void:
	_enlist_btn.pressed.connect(_on_enlist)
	_continue_btn.pressed.connect(_return)

	if GameState.enlisted_this_trip:
		_show_refusal("ONE TIME PER TRIP.")
		return
	if not GameState.gf_planet_surrendered:
		_show_refusal("THE PLANET HAS NOT\nSURRENDERED YET!!")
		return

	# Line 2220: consumed here, before any number is entered — see doc
	# comment above.
	GameState.enlisted_this_trip = true
	_spin.max_value = MAX_TOTAL_TROOPS - GameState.troops
	_refresh_prompt()


func _refresh_prompt() -> void:
	_body.text = (
		"ENLIST TROOPS\n\nEACH NEW TROOP MUST BE PAID ONE CREDIT IN ADVANCE.\n\nYOU HAVE %d CREDITS, SIR.\nTROOPS = %d"
		% [int(GameState.credits), int(GameState.troops)]
	)


func _show_refusal(message: String) -> void:
	_body.text = "ENLIST TROOPS\n\n" + message
	_input_row.visible = false
	_continue_btn.visible = true


func _on_enlist() -> void:
	var requested := _spin.value
	if requested > GameState.credits:
		_body.text = "YOU DON'T HAVE %d CREDITS!" % int(requested)
		return
	if GameState.troops + requested > MAX_TOTAL_TROOPS:
		_body.text = "TOO MANY TROOPS."
		return
	GameState.troops += requested
	GameState.credits -= requested
	_input_row.visible = false
	_continue_btn.visible = true
	_body.text = "ENLISTED %d TROOPS.\nYOU NOW HAVE %d TROOPS\nAND %d CREDITS." % [
		int(requested), int(GameState.troops), int(GameState.credits),
	]


func _return() -> void:
	GameState.goto_scene("res://scenes/ground_forces.tscn")
