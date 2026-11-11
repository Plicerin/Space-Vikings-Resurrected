extends Control
## GROUND FORCES' commands 3 to 8, the six of SHORE LEAVE.bas: shore
## leave, enlisting and the weapons bought with it, the sale of the
## loot, repairs, a new base and the cryogenic sleep. One panel, put up
## over the menu by scenes/ground_forces.tscn and taken down at `done`.
## What each does and what the crew says is scripts/rules/shore_rules.gd,
## which is held to the real game (tests/check_shore_rules.gd); this
## shows it, asks, and keeps the time.
##
## Where it parts from the original, on purpose:
## - a number is typed into a field that takes digits and nothing else.
##   The original took any characters and made what it could of them,
##   so that a number below zero or a part of a troop could be enlisted;
## - Y and N are asked for by name. The original took any key but N as
##   yes to the repair bill, and did not ask it of a bill of nothing
##   any less than of another;
## - TOO MANY TROOPS asks again; the original began the command again
##   to do it;
## - the pauses are about the original's, but a key or a click moves on.

const ShoreRules = preload("res://scripts/rules/shore_rules.gd")

# Seconds.
const LEAVE := 4.0    ## the last thing said, before the menu is back (line 2099)
const READ := 6.0     ## the same when it is a screenful
const REFUSAL := 2.5  ## why a number was not taken
const BRIEF := 1.0    ## nothing new to read
const FADE := 0.25

const TITLES := {
	ShoreRules.SHORE_LEAVE: "SHORE LEAVE", ShoreRules.ENLIST: "ENLIST TROOPS", ShoreRules.SELL_LOOT: "SELL LOOT",
	ShoreRules.REPAIR: "REPAIR SHIP", ShoreRules.BASE: "ESTABLISH BASE", ShoreRules.CRYOGENICS: "CRYOGENICS",
}

## Which of the six, as GROUND FORCES numbers them.
var command := ShoreRules.SHORE_LEAVE
## Tests shorten every wait by this.
var pace := 1.0

var _rules := ShoreRules.new()

## The command is over and the menu's turn again.
signal done
signal _moved_on
signal _answered(answer: Variant)

@onready var _hold_timer: Timer = $Hold
@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _table: GridContainer = $Center/Panel/VBox/Table
@onready var _said: Label = $Center/Panel/VBox/Said
@onready var _question: Label = $Center/Panel/VBox/Asked/Question
@onready var _answers: HBoxContainer = $Center/Panel/VBox/Asked/Answers
@onready var _entry: LineEdit = $Center/Panel/VBox/Asked/Entry


func _ready() -> void:
	_hold_timer.timeout.connect(_move_on)
	(_answers.get_node("Yes") as Button).pressed.connect(_answer.bind(true))
	(_answers.get_node("No") as Button).pressed.connect(_answer.bind(false))
	_entry.text_changed.connect(_keep_digits)
	_entry.text_submitted.connect(func(text: String) -> void: _answer(text.to_float()))
	_title.text = TITLES[command]
	match command:
		ShoreRules.SHORE_LEAVE: await _shore_leave()
		ShoreRules.ENLIST: await _enlist()
		ShoreRules.SELL_LOOT: await _sell_loot()
		ShoreRules.REPAIR: await _repair()
		ShoreRules.BASE: await _base()
		ShoreRules.CRYOGENICS: await _cryogenics()
	done.emit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and _answers.visible:
		if key.keycode == KEY_Y or key.keycode == KEY_N:
			get_viewport().set_input_as_handled()
			_answer(key.keycode == KEY_Y)
			return
	var click := event as InputEventMouseButton
	var moved_on := event.is_action_pressed("ui_accept") or (
			click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT)
	if moved_on and not _hold_timer.is_stopped():
		get_viewport().set_input_as_handled()
		_move_on()


func _shore_leave() -> void:
	_say(_rules.shore_leave_offer())
	var short := _rules.shore_leave(await _ask("PAY THEM?"))
	if short.is_empty():
		await _hold(BRIEF)
	else:
		_say(short)
		await _hold(LEAVE)


func _base() -> void:
	_say(_rules.base_offer())
	if not _rules.asking:
		await _hold(LEAVE)
	elif await _ask("BUILD A BASE?"):
		_say(_rules.build_base())
		await _hold(LEAVE)
	else:
		await _hold(BRIEF)


func _sell_loot() -> void:
	_say(_rules.sell_loot())
	await _hold(READ)


func _cryogenics() -> void:
	_say(_rules.cryogenics())
	await _hold(LEAVE)


func _enlist() -> void:
	_say(_rules.enlist_offer())
	if not _rules.asking:
		await _hold(LEAVE)
		return
	while true:
		var why := _rules.enlist(await _ask_number("HOW MANY TROOPS DO YOU WANT TO ENLIST?"))
		if why.is_empty():
			break
		_say(why)
		await _hold(REFUSAL)
		_say(_rules.enlist_terms())
	_title.text = "BUY WEAPONS"
	for weapon in ShoreRules.WEAPONS.size():
		var offer: Array[String] = ["%s COST %d" % [ShoreRules.WEAPONS[weapon][0], _rules.price_weapon(weapon)]]
		while true:
			_show_weapons()
			_say(offer)
			var why := _rules.buy(weapon, await _ask_number("BUY HOW MANY?"))
			if why.is_empty():
				break
			_say(why)
			await _hold(REFUSAL)
	_show_weapons()
	_say([])
	await _hold(LEAVE)


func _show_weapons() -> void:
	var rows := [["CREDITS", "%d" % GameState.credits]]
	for weapon in ShoreRules.WEAPONS.size():
		rows.append([ShoreRules.WEAPONS[weapon][0], "%d" % _rules.weapon_count(weapon)])
	_show_table(rows)


func _repair() -> void:
	if not _rules.landed():
		_say(ShoreRules.SAID_MUST_LAND)
		await _hold(LEAVE)
		return
	var mended := _rules.repair()
	if not mended.is_empty():
		_show_table(mended.map(func(row: Array) -> Array: return [row[0], "%d%%" % row[1]]))
		_say([])
		await _hold(LEAVE)
	_say(_rules.bill_said())
	var pay := true
	if not _rules.asking: # more than there is
		await _hold(LEAVE)
	elif _rules.bill > 0:
		pay = await _ask("ARE YOU GOING TO PAY, SIR?")
	var angry := _rules.settle(pay)
	if angry.is_empty():
		await _hold(BRIEF if _rules.bill > 0 else LEAVE)
	else:
		_say(angry)
		await _hold(READ)


## `rows` of [name, number], or none to take the table down.
func _show_table(rows: Array) -> void:
	for cell in _table.get_children():
		cell.free()
	for row: Array in rows:
		for text: String in row:
			var cell := Label.new()
			cell.text = text
			if _table.get_child_count() % 2 == 1:
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				cell.custom_minimum_size.x = 80
			_table.add_child(cell)
	_table.visible = not rows.is_empty()


func _say(lines: Array) -> void:
	_said.text = "\n".join(lines)
	_said.modulate.a = 0.0
	create_tween().tween_property(_said, "modulate:a", 1.0, FADE * pace)


## Y or N.
func _ask(question: String) -> bool:
	_question.text = question
	_question.show()
	_answers.show()
	var yes: bool = await _answered
	_question.hide()
	_answers.hide()
	return yes


## A whole number, none below nothing; nothing typed is none.
func _ask_number(question: String) -> float:
	_question.text = question
	_question.show()
	_entry.clear()
	_entry.show()
	_entry.edit()
	var number: float = await _answered
	_question.hide()
	_entry.hide()
	return number


func _answer(answer: Variant) -> void:
	if _question.visible:
		_answered.emit(answer)


func _keep_digits(text: String) -> void:
	var digits := ""
	for character in text:
		if character >= "0" and character <= "9":
			digits += character
	if digits != text:
		_entry.text = digits
		_entry.caret_column = digits.length()


## Waits `seconds`, or less if the player moves on.
func _hold(seconds: float) -> void:
	_hold_timer.start(maxf(seconds * pace, 0.001))
	await _moved_on


func _move_on() -> void:
	_hold_timer.stop()
	_moved_on.emit()
