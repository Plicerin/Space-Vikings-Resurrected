extends Node2D
## The game's shape table (`ENEMY I`, 26 shapes) as a contact sheet on a
## hi-res page: every shape XDRAWn by the ROM's own algorithm
## (shape_table.gd) under its number, the number being the one the BASIC
## source passes to DRAW / XDRAW. LEFT/RIGHT step ROT, UP/DOWN step
## SCALE, ESC goes back. Reachable from the Start screen.

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const HgrView = preload("res://scripts/shapes/hgr_view.gd")

const ENEMY_SHAPES := "res://assets/shapes/ENEMY I.A24580.L68.payload.json"
const COLUMNS := 7
const CELL := Vector2i(40, 40)

@onready var _view: HgrView = $HGRCanvas/HgrView

var _table := ShapeTable.new()
var _rot := 0
var _scale := 1


func _ready() -> void:
	_table.load_shapes(ENEMY_SHAPES)
	_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_rot = (_rot + 1) % 64
	elif event.is_action_pressed("ui_left"):
		_rot = (_rot + 63) % 64
	elif event.is_action_pressed("ui_up"):
		_scale = mini(_scale + 1, 4)
	elif event.is_action_pressed("ui_down"):
		_scale = maxi(_scale - 1, 1)
	elif event.is_action_pressed("ui_cancel"):
		GameState.goto_scene("res://scenes/start.tscn")
		return
	else:
		return
	_redraw()


func _redraw() -> void:
	draw_sheet(_view.screen, _table, _rot, _scale)


## Clears `screen` and draws the whole table on it. Also used by
## contact_sheet.gd.
static func draw_sheet(screen: HgrScreen, table: ShapeTable, rot: int, shape_scale: int) -> void:
	screen.clear()
	screen.text_mode = 0
	screen.rot = rot
	screen.shape_scale = shape_scale
	for id in range(1, table.shape_count + 1):
		var cell := Vector2i((id - 1) % COLUMNS, (id - 1) / COLUMNS)
		# The label goes on a text row; rows are 8 pixels, columns 7.
		screen.print_at(str(id), cell.x * CELL.x / 7 + 1, cell.y * CELL.y / 8 + 1)
		screen.xdraw(table, id, cell.x * CELL.x + CELL.x / 2, cell.y * CELL.y + CELL.y / 2 + 4)
	screen.rot = 0
	screen.shape_scale = 1
	screen.print_at("ROT=%d SCALE=%d   ARROWS CHANGE, ESC BACK" % [rot, shape_scale], 1, 23)
