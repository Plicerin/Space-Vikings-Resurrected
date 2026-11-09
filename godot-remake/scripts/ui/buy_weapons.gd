extends Control
## `SHORE LEAVE.bas` lines 3000-3110, "BUY WEAPONS" — a genuinely
## surprising find: this subroutine is reached ONLY via `GOSUB 3000` at
## the end of a successful Enlist (line 2290), never from Repair/
## Restock despite that menu option's name. Confirmed directly from
## source, not a guess: Repair/Restock's own flow (lines 2500-2620)
## never calls it. Traced here, not invented.
##
## Steps through all four categories in a fixed order — FIGHTERS,
## TRANSPORTS, TANKS, MISSILES — no skipping to a specific one; each
## category's unit cost is re-rolled fresh every visit
## (`INT((RND(1)+0.2) * 4 * multiplier)`), entering 0 just moves on.
## Buying is capped at 255 total per category (a raw byte in the
## original) and gated on credits.

const LABELS := ["FIGHTERS", "TRANSPORTS", "TANKS", "MISSILES"]
const MULTIPLIERS := [50.0, 75.0, 40.0, 30.0]
const MAX_COUNT := 255.0

@onready var _summary: Label = $VBox/Summary
@onready var _body: Label = $VBox/Body
@onready var _input_row: HBoxContainer = $VBox/InputRow
@onready var _spin: SpinBox = $VBox/InputRow/SpinBox
@onready var _buy_btn: Button = $VBox/InputRow/BuyButton
@onready var _continue_btn: Button = $VBox/ContinueButton

var _category: int = 0
var _cost: float = 0.0


func _ready() -> void:
	_buy_btn.pressed.connect(_on_buy)
	_continue_btn.pressed.connect(_return)
	_continue_btn.visible = false
	_show_category()


func _get_count(index: int) -> float:
	match index:
		0: return GameState.gf_fighters
		1: return GameState.gf_transports
		2: return GameState.gf_tanks
		_: return GameState.gf_missiles


func _set_count(index: int, value: float) -> void:
	match index:
		0: GameState.gf_fighters = value
		1: GameState.gf_transports = value
		2: GameState.gf_tanks = value
		_: GameState.gf_missiles = value


func _refresh_summary() -> void:
	_summary.text = "CREDITS: %d\nFIGHTERS: %d   TRANSPORTS: %d   TANKS: %d   MISSILES: %d" % [
		int(GameState.credits), int(GameState.gf_fighters), int(GameState.gf_transports),
		int(GameState.gf_tanks), int(GameState.gf_missiles),
	]


func _show_category() -> void:
	_refresh_summary()
	# Line 3060: `C = INT((RND(1)+.2) * 4 * MU(J1+1))`.
	_cost = floor((randf() + 0.2) * 4.0 * MULTIPLIERS[_category])
	_spin.min_value = 0
	_spin.max_value = MAX_COUNT
	_spin.value = 0
	_body.text = "BUY WEAPONS\n\n%s COST %d\n\nBUY HOW MANY?" % [LABELS[_category], int(_cost)]


func _on_buy() -> void:
	var b := _spin.value
	var current := _get_count(_category)
	if current + b > MAX_COUNT:
		_body.text = "255 MAX."
		return
	if b * _cost > GameState.credits:
		_body.text = "NOT ENOUGH CREDITS"
		return
	GameState.credits -= b * _cost
	_set_count(_category, minf(current + b, MAX_COUNT))
	_category += 1
	if _category < LABELS.size():
		_show_category()
	else:
		_refresh_summary()
		_body.text = "BUY WEAPONS\n\nALL PURCHASES COMPLETE."
		_input_row.visible = false
		_continue_btn.visible = true


func _return() -> void:
	GameState.goto_scene("res://scenes/ground_forces.tscn")
