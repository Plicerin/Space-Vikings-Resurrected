extends Control
## The star chart, GALAXY MAP: the twenty stars as the original has them
## placed, marked by how far off they are, violet where the planet is
## secured, a box round the star the ship is at. Point at one (mouse or
## the arrow keys) and click (or Enter) and it says what the star is
## called, where it is and how far; "Y" to "DO YOU WISH FURTHER
## INFORMATION?" runs the console with that star's page. Space goes back
## to the console. What a click finds and what is said is
## scripts/rules/chart_rules.gd, held to the real game
## (tests/check_chart_rules.gd); this shows it.
##
## Where it parts from the original, on purpose: the cursor is a mouse
## pointer (or arrow keys), not a flickering cross; the star under it is
## named as it is pointed at; only Space and Escape leave, where any key
## did; N and Escape answer no, where any key but Y did.

const ChartRules = preload("res://scripts/rules/chart_rules.gd")

const COM := "res://scenes/com.tscn"

## Dots to a pixel of the map: the original's chart is 280 across.
const SCALE := 3.0
const ARROW_STEP := Vector2(5.0, 4.0) ## dots an arrow key moves the cursor
const SAID := 2.0 ## seconds a "no star there" stays

const NEAR_COLOR := Color(0.95, 0.95, 0.95)
const SECURED_COLOR := Color(0.72, 0.5, 1.0)
const CURSOR_COLOR := Color(1.0, 0.42, 0.24)
const FRAME_COLOR := Color(0.35, 0.35, 0.35)
const RADIUS := {ChartRules.Mark.NEAR: 3.2, ChartRules.Mark.MIDDLE: 2.2, ChartRules.Mark.FAR: 1.3}

## Tests shorten every wait by this.
var pace := 1.0

var _cursor := Vector2(140.0, 75.0)
## The star the player is being asked about, or 0.
var _asking := 0

@onready var _hold: Timer = $Hold
@onready var _map: Control = $Center/Columns/MapPanel/VBox/Map
@onready var _said: Label = $Center/Columns/Info/VBox/Said
@onready var _question: Label = $Center/Columns/Info/VBox/Question
@onready var _answers: HBoxContainer = $Center/Columns/Info/VBox/Answers


func _ready() -> void:
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_map_input)
	_hold.timeout.connect(_clear)
	($Center/Columns/Info/VBox/Answers/Yes as Button).pressed.connect(_answer.bind(true))
	($Center/Columns/Info/VBox/Answers/No as Button).pressed.connect(_answer.bind(false))
	($Center/Columns/Info/VBox/Return as Button).pressed.connect(_leave)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	get_viewport().set_input_as_handled()
	if _asking > 0:
		if key.keycode == KEY_Y:
			_answer(true)
		elif key.keycode == KEY_N or key.keycode == KEY_ESCAPE:
			_answer(false)
		return
	match key.keycode:
		KEY_SPACE, KEY_ESCAPE:
			_leave()
		KEY_ENTER, KEY_KP_ENTER:
			_select()
		KEY_LEFT:
			_move(Vector2(-ARROW_STEP.x, 0.0))
		KEY_RIGHT:
			_move(Vector2(ARROW_STEP.x, 0.0))
		KEY_UP:
			_move(Vector2(0.0, -ARROW_STEP.y))
		KEY_DOWN:
			_move(Vector2(0.0, ARROW_STEP.y))


## @witness GALAXY MAP 3110-3130
func _map_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_cursor = ChartRules.clamp_cursor(motion.position / SCALE)
		_map.queue_redraw()
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_cursor = ChartRules.clamp_cursor(click.position / SCALE)
		_select()


func _move(by: Vector2) -> void:
	_cursor = ChartRules.clamp_cursor(_cursor + by)
	_map.queue_redraw()


## @witness GALAXY MAP 3210-3270
func _select() -> void:
	if _asking > 0:
		return
	var star := ChartRules.star_at(_cursor)
	if star == ChartRules.NO_STAR:
		_said.text = ChartRules.SAID_NO_STAR
		_hold.start(maxf(SAID * pace, 0.001))
		return
	_asking = star
	_said.text = "\n".join(ChartRules.said(star))
	_question.text = ChartRules.QUESTION
	_question.show()
	_answers.show()


func _answer(yes: bool) -> void:
	if _asking == 0:
		return
	if yes:
		ChartRules.further(_asking)
		GameState.goto_scene(COM)
		return
	_asking = 0
	_clear()


func _clear() -> void:
	if _asking > 0:
		return
	_said.text = "CLICK A STAR."
	_question.hide()
	_answers.hide()


## @witness GALAXY MAP 1, 3125
## Back to the console, as the original's way out by INSTRUMENTS and
## line 1 is: the marks it set are cleared.
func _leave() -> void:
	GameState.handover = 0
	GameState.goto_scene(COM)


## @witness GALAXY MAP 3000-3100
func _draw_map() -> void:
	var size := _map.size
	_map.draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	_map.draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), FRAME_COLOR, false, 2.0)
	var over := ChartRules.star_at(_cursor)
	for star in range(1, ChartRules.STARS + 1):
		var at := ChartRules.place(star) * SCALE
		var color := SECURED_COLOR if ChartRules.secured(star) else NEAR_COLOR
		_map.draw_circle(at, RADIUS[ChartRules.mark(star)] * SCALE, color)
		if ChartRules.here(star):
			_map.draw_rect(Rect2(at - Vector2(5, 5) * SCALE, Vector2(10, 10) * SCALE), SECURED_COLOR, false, 2.0)
		if star == over:
			_map.draw_arc(at, 7.0 * SCALE, 0.0, TAU, 32, CURSOR_COLOR, 2.0)
			_map.draw_string(ThemeDB.fallback_font, at + Vector2(8, -10) * SCALE / 2.0, ChartRules.NAMES[star - 1],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CURSOR_COLOR)
	var pointer := _cursor * SCALE
	_map.draw_line(pointer - Vector2(8, 0), pointer + Vector2(8, 0), CURSOR_COLOR, 1.0)
	_map.draw_line(pointer - Vector2(0, 8), pointer + Vector2(0, 8), CURSOR_COLOR, 1.0)
