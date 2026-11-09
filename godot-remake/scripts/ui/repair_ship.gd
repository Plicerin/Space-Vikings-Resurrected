extends Control
## Ports `SHORE LEAVE.bas` lines 2500-2620, "REPAIR SHIP" (the first
## half of the "REPAIR/RESTOCK" menu option — "BUY WEAPONS" is the
## other real half, but it's actually reached from Enlist instead, see
## `buy_weapons.gd`'s doc comment).
##
## Genuine quirk kept as-is: every damaged system is repaired
## immediately on entering this screen (`POKE LO,100`/`,63` happens in
## the same loop that computes the bill, well before the Y/N payment
## prompt) — your ship gets fixed regardless of whether you can or
## choose to pay. Only the credits/consequences differ afterward.
##
## Per-system cost: `INT(RND(1)*mult * (100-health))`, immediate full
## repair to `GameState.REPAIR_MAX_HEALTH[i]` (100 for eleven systems,
## 63 for ENERGY specifically — line 2524's distinct formula). A
## system already at or above its max is silently skipped (no line,
## no cost). Nothing in this port damages these systems yet (combat
## isn't wired into flight), but the bill still isn't 0 by default:
## MISSILES' real starting health is 60/100 (see
## GameState.ship_missile_system's doc comment), so a fresh game
## always shows at least that one line until repaired once.
##
## Consequence asymmetry, confirmed directly from source and kept
## faithfully: being UNABLE to afford the bill (line 2600's fallthrough
## to 2602) zeroes your credits entirely AND angers the local
## government (un-secures the current planet); voluntarily DECLINING a
## bill you could afford only angers the government, credits
## untouched. A zero-credit bill (nothing was damaged) never triggers
## either consequence even if declined (line 2580's `AND P>0` guard).
##
## Liberty, not in the original: this port doesn't model `$38210`
## ("landed on planet") or altitude, so it skips line 2505's "YOU MUST
## LAND ON PLANET FIRST" gate — reaching `ground_forces.tscn` at all
## already implies you're at this planet's ground-combat theater in
## this port's scene graph, same reasoning the other four Shore Leave
## screens already use.

@onready var _body: Label = $VBox/Body
@onready var _yn_row: HBoxContainer = $VBox/YesNoRow
@onready var _yes_btn: Button = $VBox/YesNoRow/YesButton
@onready var _no_btn: Button = $VBox/YesNoRow/NoButton
@onready var _continue_btn: Button = $VBox/ContinueButton

var _bill: float = 0.0


func _ready() -> void:
	_yes_btn.pressed.connect(_on_yes)
	_no_btn.pressed.connect(_on_no)
	_continue_btn.pressed.connect(_return)
	_continue_btn.visible = false

	var lines: Array[String] = []
	for i in range(GameState.REPAIR_LABELS.size()):
		var health: float = GameState.get_ship_system_health(i)
		var max_health: float = GameState.REPAIR_MAX_HEALTH[i]
		if health < max_health:
			var cost: float = floor(randf() * GameState.REPAIR_MULTIPLIERS[i] * (100.0 - health))
			_bill += cost
			lines.append("%s: %d%%" % [GameState.REPAIR_LABELS[i], int(health)])
			GameState.set_ship_system_health(i, max_health)

	var repaired_text := "\n".join(lines) if not lines.is_empty() else "NOTHING WAS DAMAGED."
	var header := "  REPAIR SHIP\n\nALL REPAIRS ARE\nCOMPLETE, SIR.\n\n%s\n\n" % repaired_text

	# Line 2555: cleared unconditionally once repairs complete, before
	# the billing/payment branch below — not tied to whether you can
	# or choose to pay.
	GameState.damage_alert_active = false

	if GameState.credits < _bill:
		GameState.credits = 0.0
		_anger_government()
		_body.text = header + "THE TOTAL REPAIR\nBILL COMES TO\n%d CREDITS.\n\nYOU DON'T HAVE\nENOUGH CREDITS!\nYOU HAVE 0 CREDITS\nLEFT!\n\nI'M AFRAID YOU'VE\nMADE THE LOCAL\nGOVERNMENT ANGRY!" % int(_bill)
		_continue_btn.visible = true
	else:
		_body.text = header + "THE TOTAL REPAIR\nBILL COMES TO\n%d CREDITS.\nYOU HAVE %d\nCREDITS.\n\nARE YOU GOING TO\nPAY, SIR?" % [int(_bill), int(GameState.credits)]
		_yn_row.visible = true


func _on_yes() -> void:
	GameState.credits = floor(GameState.credits - _bill)
	_yn_row.visible = false
	_continue_btn.visible = true
	_body.text = "  REPAIR SHIP\n\nPAID %d CREDITS.\nYOU HAVE %d CREDITS." % [int(_bill), int(GameState.credits)]


func _on_no() -> void:
	_yn_row.visible = false
	_continue_btn.visible = true
	if _bill > 0.0:
		_anger_government()
		_body.text = "  REPAIR SHIP\n\nI'M AFRAID YOU'VE\nMADE THE LOCAL\nGOVERNMENT ANGRY!"
	else:
		_body.text = "  REPAIR SHIP\n\nNOTHING OWED."


func _anger_government() -> void:
	# Lines 2610/2602-2605: $38208 (global "surrendered") and
	# $38219+planet (per-planet "secured") reset together.
	GameState.gf_planet_surrendered = false
	GameState.planet_secured[GameState.current_planet] = false


func _return() -> void:
	GameState.goto_scene("res://scenes/ground_forces.tscn")
