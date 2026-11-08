extends Control
## Ports `SHORE LEAVE.bas`'s "SELL LOOT" option (lines 2400-2460).
## Unlike Shore Leave's pay-troops flow, this one has no Y/N gate at
## all — the original computes the sale value and applies it
## immediately on entering the screen, just displaying the result
## before returning. `GameState.compute_loot_value()` carries the
## exact per-category multiplier table (index 0 alone re-rolls its own
## multiplier every sale; the whole sum doubles at the end — both from
## the original source, not guesses).

@onready var _body: Label = $VBox/Body
@onready var _continue_btn: Button = $VBox/ContinueButton


func _ready() -> void:
	_continue_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/ground_forces.tscn"))

	var before := GameState.credits
	var sale_value := GameState.compute_loot_value()
	GameState.credits = before + sale_value
	# Line 2460: `FOR C=38171 TO 38183: POKE C,0: NEXT` — loot is
	# entirely spent, not partially.
	for i in range(GameState.loot.size()):
		GameState.loot[i] = 0.0

	_body.text = (
		"SELL LOOT\n\nYOU HAD %d CREDITS.\nYOUR LOOT IS WORTH %d CREDITS.\n\nTHAT GIVES YOU A TOTAL OF %d CREDITS!"
		% [int(before), int(sale_value), int(GameState.credits)]
	)
