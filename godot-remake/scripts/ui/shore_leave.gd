extends Control
## Ports SHORE LEAVE.bas's "PAY THEM (Y/N)?" pay-troops flow only (lines
## 2080-2099). The original dispatches five different screens (pay
## troops, sell loot, build base, enlist, repair) through this one
## overlay via $38388; the port splits those into separate destinations
## instead (see ground_forces.gd), so this scene covers pay-troops alone.

@onready var _body: Label = $VBox/Body
@onready var _yes_btn: Button = $VBox/ButtonRow/YesButton
@onready var _no_btn: Button = $VBox/ButtonRow/NoButton


func _ready() -> void:
	_refresh_prompt()
	_yes_btn.pressed.connect(_on_pay)
	_no_btn.pressed.connect(_on_refuse)


func _refresh_prompt() -> void:
	_body.text = (
		"TROOPS READY FOR SHORE LEAVE, SIR.\nBACK PAY COMES TO %d CREDITS.\n\nYOU HAVE %d CREDITS.\n\nPAY THEM (Y/N)?"
		% [int(GameState.troops), int(GameState.credits)]
	)


func _on_pay() -> void:
	# Line 2090: refusing on insufficient credits is forced server-side
	# in the original (P$="N": GOTO 2088) rather than disabling the
	# button; same effect either way.
	if GameState.troops > GameState.credits:
		_body.text = "YOU DON'T HAVE ENOUGH CREDITS, SIR!"
		_on_refuse()
		return
	# Lines 2093/2095: +1 morale, capped at 6; pay cost = troop count.
	GameState.troop_morale = mini(GameState.troop_morale + 1, 6)
	GameState.credits -= GameState.troops
	_after_shore_leave()


func _on_refuse() -> void:
	# Lines 2088-2089: -2 morale, floored at 1 (not 0 — distinct from
	# the landing/retreat penalties elsewhere, which floor at 0).
	GameState.troop_morale = maxi(GameState.troop_morale - 2, 1)
	_after_shore_leave()


func _after_shore_leave() -> void:
	# Line 2098: troops are now considered stationed at this planet,
	# location = shore leave.
	GameState.troops_stationed_at = GameState.current_planet
	GameState.troop_location = 2
	GameState.goto_scene("res://scenes/ground_forces.tscn")
