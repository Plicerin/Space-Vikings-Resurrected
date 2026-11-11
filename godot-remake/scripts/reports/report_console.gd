extends Control
## STATUS and SUPPLY, the central computer's two reports: what
## scripts/rules/report_rules.gd says, laid out on one panel each (the
## original's were two screens, a key apart). Enter, Space, Escape or
## the button goes back to the console.
##
## The troops' line says which star they are at when they are on a
## planet; the original's says only PLANETSIDE or SHORE LEAVE, and with
## a jump between landing and recalling them it is easy to lose track.

const ReportRules = preload("res://scripts/rules/report_rules.gd")

const COM := "res://scenes/com.tscn"

## "status" or "supply".
@export var report := "status"

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _ship: GridContainer = $Center/Panel/VBox/Ship
@onready var _troops_title: Label = $Center/Panel/VBox/TroopsTitle
@onready var _troops: GridContainer = $Center/Panel/VBox/Troops
@onready var _dead: Label = $Center/Panel/VBox/Dead
@onready var _return: Button = $Center/Panel/VBox/Return


func _ready() -> void:
	_return.pressed.connect(_leave)
	if report == "supply":
		_supply()
	else:
		_status()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	GameState.goto_scene(COM)


func _status() -> void:
	_title.text = "SHIP STATUS REPORT"
	_ship.columns = 4
	for row: Array in ReportRules.ship():
		for cell: Array in row:
			_cell(_ship, cell[0], false)
			_cell(_ship, cell[1], true)
		if row.size() == 1: # the left of two, alone
			_cell(_ship, "", false)
			_cell(_ship, "", false)
	_troops_title.text = "TROOP STATUS"
	_troops.columns = 2
	for entry: Array in ReportRules.troops():
		_cell(_troops, entry[0], false)
		_cell(_troops, _with_star(entry), true)
	_dead.visible = ReportRules.troops_all_dead()


func _supply() -> void:
	_title.text = "SUPPLY REPORT"
	_ship.columns = 3
	for row: Array in ReportRules.supply():
		_cell(_ship, row[0], false)
		_cell(_ship, row[1], true).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_cell(_ship, row[2], false)
	_cell(_ship, "CREDITS", false)
	_cell(_ship, ReportRules.supply_credits(), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cell(_ship, "", false)
	_troops_title.hide()
	_troops.hide()


func _with_star(entry: Array) -> String:
	if entry[0] == "TROOP LOCATION" and (GameState.troop_location == 1 or GameState.troop_location == 2):
		var star: int = GameState.troops_stationed_at - 1
		if star >= 0 and star < GameState.STAR_NAMES.size():
			return "%s (%s)" % [entry[1], GameState.STAR_NAMES[star]]
	return entry[1]


## A label in `grid`: green if it is a value.
func _cell(grid: GridContainer, text: String, value: bool) -> Label:
	var cell := Label.new()
	cell.text = text
	if value:
		cell.theme_type_variation = &"CrewLabel"
	grid.add_child(cell)
	return cell
