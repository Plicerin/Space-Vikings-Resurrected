extends Control
## GROUND FORCES, with RECALL and COLLECT: the menu and the battle,
## drawn by Godot. What a command does and what the crew says of it is
## scripts/rules/ground_rules.gd, which is held to the real game
## (tests/check_ground_rules.gd); this shows it and keeps the time.
##
## Where it parts from the original, on purpose:
## - a refusal or a recall is said under the menu, which stays up; the
##   original cleared its window and ran the program again;
## - the battle is called off with RETREAT (or R). The original took
##   any key for it. As there, the order is obeyed after the round in
##   hand, which is fought and paid for;
## - the pauses between reports are about the original's
##   (analysis/live/ground/README.md), but a key or a click moves on.
##   The rounds keep their beat;
## - the numbers are up from the start and count down; the original
##   printed them first with the first round.

const GroundRules = preload("res://scripts/rules/ground_rules.gd")
const COM := "res://scenes/com.tscn"
## Commands 3-8, SHORE LEAVE.bas's six: each a scene of its own here.
const ELSEWHERE := {
	3: "shore_leave", 4: "enlist", 5: "sell_loot", 6: "repair_ship", 7: "establish_base", 8: "cryogenics",
}

# Seconds.
const REPORT := 3.0    ## a report from the landing
const ROUND := 2.3
const SURRENDER := 5.0
const LOOT := 6.0      ## each of COLLECT's two reports
const ENDED := 4.0     ## a battle lost or broken off
const BRIEF := 1.0     ## the battle screen put up and taken down with nothing said
const COUNT := 0.6     ## a number running to its new value
const FADE := 0.25

## Tests shorten every wait by this.
var pace := 1.0

var _rules: GroundRules
var _retreat := false
var _may_skip := false
var _shown := {} ## the number each count label is at or running to

signal _moved_on

@onready var _hold_timer: Timer = $Hold
@onready var _menu: PanelContainer = $Center/Menu
@onready var _commands: VBoxContainer = $Center/Menu/VBox/Commands
@onready var _menu_said: Label = $Center/Menu/VBox/Said
@onready var _battle: PanelContainer = $Center/Battle
@onready var _battle_said: Label = $Center/Battle/VBox/Said
@onready var _retreat_button: Button = $Center/Battle/VBox/Orders/Retreat
@onready var _success_bar: ProgressBar = $Center/Battle/VBox/Columns/Projection/Success/Bar
@onready var _success: Label = $Center/Battle/VBox/Columns/Projection/Success/Percent
@onready var _counts: GridContainer = $Center/Battle/VBox/Columns/Status/Counts


func _ready() -> void:
	for number in range(1, 10):
		(_commands.get_node("Command%d" % number) as Button).pressed.connect(_command.bind(number))
	_retreat_button.pressed.connect(_order_retreat)
	_hold_timer.timeout.connect(_move_on)
	_open_menu()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var number := int(key.unicode) - KEY_0 if key.unicode != 0 else int(key.keycode) - KEY_0
		if _menu.visible and number >= 1 and number <= 9:
			get_viewport().set_input_as_handled()
			_command(number)
			return
		if _battle.visible and key.keycode == KEY_R:
			get_viewport().set_input_as_handled()
			_order_retreat()
			return
	var click := event as InputEventMouseButton
	var moved_on := event.is_action_pressed("ui_accept") or (
			click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT)
	if moved_on and _battle.visible and _may_skip and not _hold_timer.is_stopped():
		get_viewport().set_input_as_handled()
		_move_on()


## The menu, as the program coming up afresh: every command of the
## original ends by running it again. `said` is what the last one had
## to say.
func _open_menu(said: Array[String] = []) -> void:
	_rules = GroundRules.new()
	_rules.open_menu()
	_battle.hide()
	_menu.show()
	_say(_menu_said, said)
	if get_viewport().gui_get_focus_owner() == null:
		(_commands.get_node("Command1") as Button).grab_focus()


func _command(number: int) -> void:
	if not _menu.visible:
		return
	var why := _rules.refusal(number)
	if not why.is_empty():
		_open_menu(why)
		return
	match number:
		1:
			_attack()
		2:
			_open_menu(_rules.recall())
		9:
			GameState.goto_scene(COM)
		_:
			GameState.goto_scene("res://scenes/%s.tscn" % ELSEWHERE[number])


func _attack() -> void:
	var landing := _rules.begin_attack()
	_retreat = false
	_menu.hide()
	_battle.show()
	get_viewport().gui_release_focus()
	_retreat_button.hide()
	_say(_battle_said, [])
	_success_bar.value = 0.0
	_success.text = ""
	_show_counts(false)
	match landing:
		GroundRules.Landing.NOTHING:
			await _hold(BRIEF)
		GroundRules.Landing.NO_TRANSPORTS:
			_say(_battle_said, GroundRules.SAID_NO_TRANSPORTS)
			await _hold(REPORT)
		_:
			for line in _rules.departure():
				_say(_battle_said, [line])
				await _hold(REPORT)
			for report: Array in _rules.land():
				_say(_battle_said, report)
				await _hold(REPORT)
			if landing == GroundRules.Landing.BATTLE:
				await _fight()
	_open_menu()


func _fight() -> void:
	_retreat_button.text = "R) RETREAT"
	_retreat_button.disabled = false
	_retreat_button.show()
	while true:
		var outcome := _rules.fight(_retreat)
		AudioManager.play_tick()
		_show_counts(true)
		_show_success(100.0 if outcome == GroundRules.Outcome.SURRENDERED else _rules.success)
		if outcome == GroundRules.Outcome.FIGHTING:
			await _hold(ROUND, false)
			continue
		_retreat_button.hide()
		match outcome:
			GroundRules.Outcome.SURRENDERED:
				_say(_battle_said, GroundRules.SAID_SURRENDERED)
				await _hold(SURRENDER)
				_say(_battle_said, GroundRules.SAID_COLLECTING)
				await _hold(REPORT)
				for report: Array in _rules.collect():
					_say(_battle_said, report)
					await _hold(LOOT)
			GroundRules.Outcome.LOST:
				_say(_battle_said, GroundRules.SAID_LOST)
				await _hold(ENDED)
			GroundRules.Outcome.RETREATED:
				_say(_battle_said, GroundRules.SAID_RETREATING)
				await _hold(ENDED)
		return


func _order_retreat() -> void:
	if not _retreat_button.is_visible_in_tree() or _retreat:
		return
	_retreat = true
	_retreat_button.disabled = true
	_retreat_button.text = "RETREAT ORDERED"


func _show_counts(running: bool) -> void:
	var now := {
		"Fighters": _rules.fighters, "Transports": _rules.transports, "Troops": _rules.troops,
		"Tanks": _rules.tanks, "Missiles": _rules.missiles,
	}
	for count: String in now:
		var label: Label = _counts.get_node(count)
		var to: float = now[count]
		var from: float = _shown.get(count, to) if running else to
		_shown[count] = to
		if from == to:
			label.text = str(int(to))
		else:
			create_tween().tween_method(
					func(n: float) -> void: label.text = str(int(roundf(n))), from, to, COUNT * pace)


func _show_success(percent: float) -> void:
	_success.text = "%d%%" % percent
	create_tween().tween_property(_success_bar, "value", percent, COUNT * pace)


func _say(label: Label, lines: Array) -> void:
	label.text = "\n".join(lines)
	label.modulate.a = 0.0
	create_tween().tween_property(label, "modulate:a", 1.0, FADE * pace)


## Waits `seconds`, or less if the player moves on.
func _hold(seconds: float, may_skip: bool = true) -> void:
	_may_skip = may_skip
	_hold_timer.start(maxf(seconds * pace, 0.001))
	await _moved_on


func _move_on() -> void:
	_hold_timer.stop()
	_moved_on.emit()
