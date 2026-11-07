extends Control
## Ground-invasion menu + battle loop — ports the formula documented in
## GROUND_COMBAT_ANALYSIS.md directly from GROUND FORCES.bas lines
## 170-690. Deliberately NOT faithful on one point: the original's
## retreat trigger is a verified bug (any keypress fires it — see the
## doc's "Retreating mid-battle" section, line 1115's unconditional
## `K = 82`). This port uses an explicit Retreat button instead of
## reproducing that bug as if it were a design choice.
##
## The original also routes Shore Leave/Enlist/Sell Loot/Repair/Build
## Base through one shared overlay (SHORE LEAVE.bas, dispatched by
## $38388); this port splits them into separate destinations, with only
## Shore Leave's pay-troops flow actually implemented so far (see
## scripts/ui/shore_leave.gd) — the rest are stubs pointing back here.

@onready var _menu: VBoxContainer = $VBox/Menu
@onready var _battle: VBoxContainer = $VBox/Battle
@onready var _status_label: Label = $VBox/Battle/StatusLabel
@onready var _counts_label: Label = $VBox/Battle/CountsLabel
@onready var _retreat_btn: Button = $VBox/Battle/RetreatButton
@onready var _round_timer: Timer = $RoundTimer

@onready var _attack_btn: Button = $VBox/Menu/AttackButton
@onready var _recall_btn: Button = $VBox/Menu/RecallButton
@onready var _shore_leave_btn: Button = $VBox/Menu/ShoreLeaveButton
@onready var _enlist_btn: Button = $VBox/Menu/EnlistButton
@onready var _sell_loot_btn: Button = $VBox/Menu/SellLootButton
@onready var _repair_btn: Button = $VBox/Menu/RepairButton
@onready var _base_btn: Button = $VBox/Menu/BaseButton
@onready var _cryo_btn: Button = $VBox/Menu/CryoButton
@onready var _return_btn: Button = $VBox/Menu/ReturnButton

var _in_battle := false


func _ready() -> void:
	_battle.visible = false
	_attack_btn.pressed.connect(_on_attack_pressed)
	_recall_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/recall.tscn"))
	_shore_leave_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/shore_leave.tscn"))
	_enlist_btn.pressed.connect(func(): GameState.show_stub(
		"ENLIST TROOPS", "1 credit/troop, one-shot per trip — SHORE LEAVE.bas lines 2200-2300.", "res://scenes/ground_forces.tscn"
	))
	_sell_loot_btn.pressed.connect(func(): GameState.show_stub(
		"SELL LOOT", "Converts the 13 loot categories to credits — SHORE LEAVE.bas lines 2400-2460.", "res://scenes/ground_forces.tscn"
	))
	_repair_btn.pressed.connect(func(): GameState.show_stub(
		"REPAIR/RESTOCK", "Repairs ship systems, buys weapons — SHORE LEAVE.bas lines 2500-3110.", "res://scenes/ground_forces.tscn"
	))
	_base_btn.pressed.connect(func(): GameState.show_stub(
		"ESTABLISH BASE", "20000-25000cr one-shot per trip — SHORE LEAVE.bas lines 2100-2160.", "res://scenes/ground_forces.tscn"
	))
	_cryo_btn.pressed.connect(func(): GameState.show_stub(
		"CRYOGENICS", "Puts troops in cryo sleep — GROUND FORCES.bas lines 4000-4020.", "res://scenes/ground_forces.tscn"
	))
	_return_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/com.tscn"))
	_retreat_btn.pressed.connect(_on_retreat_pressed)
	_round_timer.timeout.connect(_on_round_tick)
	_update_menu_gating()


func _update_menu_gating() -> void:
	# GROUND FORCES.bas line 65: options 3-6 all require a base on this
	# planet ($38303+planet != 0).
	var has_base := GameState.planet_has_base[GameState.current_planet]
	_shore_leave_btn.disabled = not has_base
	_enlist_btn.disabled = not has_base
	_sell_loot_btn.disabled = not has_base
	_repair_btn.disabled = not has_base


# --- Attack / battle loop (GROUND FORCES.bas lines 170-690) ---

func _on_attack_pressed() -> void:
	if GameState.gf_transports <= 0.0:
		GameState.show_stub(
			"ATTACK PLANET", "THERE ARE NO TRANSPORTS AVAILABLE!", "res://scenes/ground_forces.tscn"
		)
		return

	GameState.troop_location = 1 # planetside

	# Line 178-179: each transport carries up to 1000 troops; any excess
	# stays aboard ship in reserve (T9) rather than landing.
	var capacity := GameState.gf_transports * 1000.0
	if GameState.troops > capacity:
		GameState.gf_reserve_troops = GameState.troops - capacity
		GameState.troops = capacity
	else:
		GameState.gf_reserve_troops = 0.0

	var tech: int = GameState.planet_tech[GameState.current_planet]
	if tech == 0:
		# Line 220-240: no enemy at all — instant surrender, no loop.
		GameState.gf_planet_surrendered = true
		GameState.planet_secured[GameState.current_planet] = true
		_finish_battle("PLANET IS NON-HABITABLE. NO ENEMY TO RESIST — SECURED IMMEDIATELY.")
		return

	# Lines 90-93 (H_D.bas) / line 510 (GROUND FORCES.bas): enemy
	# resistance threshold scales directly with tech; tech 1 ("limited
	# atomic") still runs the loop but with resistance forced to 0.
	GameState.gf_enemy_strength = float(tech) * 60.0 if tech >= 2 else 0.0
	GameState.gf_victory_progress = 0.0
	_in_battle = true
	_menu.visible = false
	_battle.visible = true
	_status_label.text = "ATTACK UNDERWAY..."
	_round_timer.start(0.5)


func _on_round_tick() -> void:
	if not _in_battle:
		return

	var tech := float(GameState.planet_tech[GameState.current_planet])

	# Line 550/555: favorable vs. unfavorable round roll.
	var vic := randf() * (10.0 * tech)
	var t2: float
	var x: float
	if vic < 20.0:
		t2 = 500.0 + randf() * 20.0
		x = randf() * (12.0 / (tech + 0.5))
	else:
		t2 = 200.0 * randf() * 5.0
		x = -randf() * (10.0 / (tech + 0.5))

	# Lines 560-570: universal per-round attrition, both branches.
	GameState.gf_tanks -= randf() * randf() * 5.0
	GameState.gf_fighters -= randf() * randf() * 5.0
	GameState.gf_missiles -= randf() * randf() * 5.0
	GameState.gf_transports -= randf() * 1.0 - 0.5 # net ~flat, same as the original
	GameState.troops -= randf() * randf() * (tech * randf() * t2)

	# Line 570: an orbital defender still present taxes progress every
	# round, independent of the round's own outcome.
	if GameState.planet_orbital_defender[GameState.current_planet]:
		x -= randf() * 1.0

	# Line 575: troop morale (1-6) is added to progress every round,
	# centered on 3 — the single most consistent term in the formula.
	x += float(GameState.troop_morale - 3)

	GameState.gf_victory_progress = clampf(GameState.gf_victory_progress + x, 0.0, 255.0)
	GameState.gf_tanks = maxf(GameState.gf_tanks, 0.0)
	GameState.gf_fighters = maxf(GameState.gf_fighters, 0.0)
	GameState.gf_missiles = maxf(GameState.gf_missiles, 0.0)
	GameState.gf_transports = maxf(GameState.gf_transports, 0.0)
	GameState.troops = maxf(GameState.troops, 0.0)

	var success_pct := 0.0
	if GameState.gf_enemy_strength > 0.0:
		success_pct = clampf((100.0 / GameState.gf_enemy_strength) * GameState.gf_victory_progress, 0.0, 100.0)

	_counts_label.text = (
		"FIGHTERS %d   TRANSPORTS %d   TROOPS %d   TANKS %d   MISSILES %d\nSUCCESS %.0f%%"
		% [
			int(GameState.gf_fighters), int(GameState.gf_transports), int(GameState.troops),
			int(GameState.gf_tanks), int(GameState.gf_missiles), success_pct,
		]
	)

	# Line 660/670: surrender or total loss ends the round loop.
	if GameState.gf_victory_progress >= GameState.gf_enemy_strength:
		GameState.gf_planet_surrendered = true
		GameState.planet_secured[GameState.current_planet] = true
		_finish_battle("THE PLANET HAS SURRENDERED!")
	elif GameState.troops <= 0.0:
		_finish_battle("THE BATTLE IS LOST! ALL TROOPS HAVE BEEN DESTROYED!")


func _on_retreat_pressed() -> void:
	# Line 1120-1121: reserve troops rejoin the count, morale takes a -1
	# hit, floored at 0.
	GameState.troops += GameState.gf_reserve_troops
	GameState.troop_morale = maxi(GameState.troop_morale - 1, 0)
	_finish_battle("GROUND FORCES RETREATING, SIR! PLANET NOT SECURED!")


func _finish_battle(message: String) -> void:
	_in_battle = false
	_round_timer.stop()
	_status_label.text = message
	await get_tree().create_timer(2.0).timeout
	_battle.visible = false
	_menu.visible = true
	_update_menu_gating()
	if GameState.gf_planet_surrendered:
		GameState.gf_planet_surrendered = false
		GameState.goto_scene("res://scenes/collect.tscn")
