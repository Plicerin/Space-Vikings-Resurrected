extends Control
## GALAXY MAP as a vector display over the front window, drawn like the radar
## (scripts/flight/vector_radar.gd): the twenty stars as the original has them
## placed, marked by how far off they are (a ring and a dot for near, a ring for
## middle, a cross for far), violet where the planet is secured, a square round
## the star the ship is at, and a crosshair to point with: the mouse, or the
## arrow keys, which count through the stars by number. Everything written goes on the console's display: what is
## pointed at, what the chart says of a star on Enter, and its question
## "DO YOU WISH FURTHER INFORMATION?", "Y" to which runs the console with that
## star's page. What a click finds and what is said is
## scripts/rules/chart_rules.gd, held to the real game (tests/check_chart_rules.gd).
##
## Where it parts from the original, on purpose: the cursor is a pointer (or
## arrow keys), not a flickering cross; only Space, Escape and G leave, where
## any key did; N and Escape answer no, where any key but Y did.

const ChartRules = preload("res://scripts/rules/chart_rules.gd")
const HudOverlay = preload("res://scripts/flight/hud_overlay.gd")

signal closed(to_console: bool)
## A star was clicked while the chart is up to pick one for a prompt.
signal picked(star: int)

const SAID := 2.0 ## seconds a "no star there" stays
const PHOSPHOR := Color(0.7, 1.0, 0.82)
const VIOLET := Color(0.75, 0.55, 1.0)
const AMBER := Color(1.0, 0.62, 0.2)

## The flight's display panel (hud_overlay.gd): the chart writes its page there.
var console: Control
## Opened by the console's GALAXY MAP: Space goes back to the console. Opened
## from the flight it just closes.
var from_console := false
## Up to pick a star for a prompt of the console's (the destination, a system): a click names a star to
## the console and asks nothing, and the console has the display and the keys.
var picking := false

var _cursor := Vector2(140.0, 75.0)
var _asking := 0 ## the star the player is being asked about, or 0
var _focus := 0 ## the star the arrow keys are on, or 0 when the pointer is in charge
var _said_until := 0.0
var _said_no_star := false
var _turn := 0.0
var _map := Rect2()
var _scale := 3.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(console_asked := false) -> void:
	from_console = console_asked
	visible = true
	_asking = 0
	_said_no_star = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func pick(on: bool) -> void:
	picking = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_asking = 0
	_said_no_star = false
	_focus = 0
	if console != null:
		console.hide_target = on


## The star the prompt has typed, ringed (0 for none).
func focus_star(star: int) -> void:
	if not picking:
		return
	if star >= 1 and star <= ChartRules.STARS:
		_cursor = ChartRules.clamp_cursor(ChartRules.place(star))
		_focus = star
	else:
		_focus = 0


func close(to_console := false) -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_asking = 0
	if console != null:
		console.page = []
		console.hide_target = false
	if to_console or from_console:
		closed.emit(true)
	else:
		closed.emit(false)
	from_console = false


## Keys of the chart while it is up; returns whether it took the key.
func handle_key(key: InputEventKey) -> bool:
	if not visible or not key.pressed:
		return false
	if _asking > 0:
		if key.echo:
			return true
		if key.keycode == KEY_Y:
			_answer(true)
		elif key.keycode == KEY_N or key.keycode == KEY_ESCAPE:
			_answer(false)
		return true
	match key.keycode:
		KEY_SPACE, KEY_ESCAPE, KEY_G:
			if not key.echo:
				_leave()
		KEY_ENTER, KEY_KP_ENTER:
			if not key.echo:
				select()
		KEY_LEFT, KEY_UP:
			_step(-1)
		KEY_RIGHT, KEY_DOWN:
			_step(1)
		_:
			return false
	return true


## @witness GALAXY MAP 3110-3130
func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		point_at(ChartRules.clamp_cursor((motion.position - _map.position) / _scale))
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		point_at(ChartRules.clamp_cursor((click.position - _map.position) / _scale))
		select()
	accept_event()


## Points the cursor at a place in the chart's dots.
func point_at(dots: Vector2) -> void:
	_cursor = ChartRules.clamp_cursor(dots)
	_focus = 0


func _move(by: Vector2) -> void:
	point_at(_cursor + by)


## The arrow keys count through the stars: left and up to the one before,
## right and down to the next, 20 round to 1 and 1 round to 20, the crosshair
## put on it. (The original's paddles moved a free cursor and its button asked
## about whatever it was over; this is the keyboard's way of getting to a star.)
func _step(by: int) -> void:
	var from := _focus if _focus > 0 else maxi(ChartRules.star_at(_cursor), 0)
	if from == ChartRules.NO_STAR:
		from = 0
	var star := posmod(from - 1 + by, ChartRules.STARS) + 1
	_cursor = ChartRules.clamp_cursor(ChartRules.place(star))
	_focus = star


## The star pointed at: the one the keys chose, or what the cursor is over.
func _pointed() -> int:
	return _focus if _focus > 0 else ChartRules.star_at(_cursor)


## @witness GALAXY MAP 3210-3270
func select() -> void:
	if _asking > 0:
		return
	var star := _pointed()
	if star == ChartRules.NO_STAR:
		AudioManager.play_refuse()
		_said_no_star = true
		_said_until = _turn + SAID
		return
	if picking:
		picked.emit(star)
		return
	AudioManager.play_select()
	_asking = star


func _answer(yes: bool) -> void:
	if _asking == 0:
		return
	if yes:
		ChartRules.further(_asking)
		close(true)
		return
	_asking = 0


## @witness GALAXY MAP 1, 3125
## Back to the console, as the original's way out by INSTRUMENTS and line 1
## is, if the console ran the chart: the marks it set are cleared.
func _leave() -> void:
	if from_console:
		GameState.handover = 0
	close(false)


func _process(delta: float) -> void:
	if not visible:
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size # a canvas layer has no layout to fill
	_turn += delta
	if _said_no_star and _turn > _said_until:
		_said_no_star = false
	_write_console()
	queue_redraw()


## What the chart writes on the console's display.
func _write_console() -> void:
	if console == null or picking:
		return
	console.hide_target = true
	var columns: Callable = console.columns
	var lines: Array = ["-GALAXY MAP-", ""]
	if _asking > 0:
		lines.append_array(ChartRules.said(_asking))
		lines.append(ChartRules.QUESTION)
		lines.append(columns.call("Y  YES", "N  NO"))
	elif _said_no_star:
		lines.append(ChartRules.SAID_NO_STAR)
	else:
		var over := _pointed()
		lines.append("CLICK A STAR." if over == ChartRules.NO_STAR else "STAR %d: %s" % [over, ChartRules.NAMES[over - 1]])
		lines.append("")
		lines.append(columns.call("ARROWS  STAR NUMBER", "ENTER  ASK"))
		lines.append(columns.call("SPACE  CLOSE", ""))
	console.page = lines


# --- drawing ------------------------------------------------------------------


## @witness GALAXY MAP 3000-3100
func _draw() -> void:
	var area := Rect2(size.x * 0.5 - 470.0, 28.0, 940.0, size.y - HudOverlay.panel_height(size.x) - 48.0)
	_scale = minf((area.size.x - 40.0) / 280.0, (area.size.y - 40.0) / 160.0)
	_map = Rect2(area.get_center() - Vector2(280.0, 160.0) * _scale / 2.0, Vector2(280.0, 160.0) * _scale)
	draw_rect(area, Color(0.0, 0.03, 0.02, 0.78))
	_brackets(area)
	var flicker := 1.0 - 0.04 * absf(sin(_turn * 31.0) * sin(_turn * 9.7))
	var ink := Color(PHOSPHOR.r * flicker, PHOSPHOR.g * flicker, PHOSPHOR.b * flicker)
	# a faint grid: a line every forty dots
	for i in range(1, 7):
		_vline(_map.position + Vector2(i * 40.0 * _scale, 0.0), _map.position + Vector2(i * 40.0 * _scale, _map.size.y), Color(PHOSPHOR, 0.08), 1.0)
	for i in range(1, 4):
		_vline(_map.position + Vector2(0.0, i * 40.0 * _scale), _map.position + Vector2(_map.size.x, i * 40.0 * _scale), Color(PHOSPHOR, 0.08), 1.0)
	var over := _pointed()
	for star in range(1, ChartRules.STARS + 1):
		var at := _map.position + ChartRules.place(star) * _scale
		var colour := VIOLET if ChartRules.secured(star) else ink
		match ChartRules.mark(star):
			ChartRules.Mark.NEAR:
				draw_arc(at, 7.0, 0.0, TAU, 24, colour, 1.6, true)
				draw_arc(at, 7.0, 0.0, TAU, 24, Color(colour, 0.16), 6.0, true)
				draw_circle(at, 2.0, colour)
			ChartRules.Mark.MIDDLE:
				draw_arc(at, 4.5, 0.0, TAU, 20, colour, 1.4, true)
				draw_arc(at, 4.5, 0.0, TAU, 20, Color(colour, 0.16), 5.0, true)
			_:
				_vline(at + Vector2(-3, 0), at + Vector2(3, 0), colour, 1.2)
				_vline(at + Vector2(0, -3), at + Vector2(0, 3), colour, 1.2)
		if ChartRules.here(star): # the ship's star: a square round it
			var half := 13.0
			_vpoly(PackedVector2Array([at + Vector2(-half, -half), at + Vector2(half, -half), at + Vector2(half, half), at + Vector2(-half, half)]), VIOLET)
		if star == over:
			draw_arc(at, 13.0, 0.0, TAU, 32, AMBER, 1.6, true)
			draw_arc(at, 13.0, 0.0, TAU, 32, Color(AMBER, 0.2), 6.0, true)
	var pointer := _map.position + _cursor * _scale
	_vline(pointer + Vector2(-14, 0), pointer + Vector2(-4, 0), AMBER, 1.2)
	_vline(pointer + Vector2(4, 0), pointer + Vector2(14, 0), AMBER, 1.2)
	_vline(pointer + Vector2(0, -14), pointer + Vector2(0, -4), AMBER, 1.2)
	_vline(pointer + Vector2(0, 4), pointer + Vector2(0, 14), AMBER, 1.2)


func _vline(from: Vector2, to: Vector2, colour: Color, width := 1.6) -> void:
	draw_line(from, to, Color(colour, colour.a * 0.16), width * 4.0, true)
	draw_line(from, to, colour, width, true)


func _vpoly(points: PackedVector2Array, colour: Color, width := 1.6) -> void:
	var line := points.duplicate()
	line.append(points[0])
	draw_polyline(line, Color(colour, colour.a * 0.16), width * 4.0, true)
	draw_polyline(line, colour, width, true)


func _brackets(area: Rect2) -> void:
	for corner in [[area.position, Vector2(1, 1)], [Vector2(area.end.x, area.position.y), Vector2(-1, 1)],
			[area.end, Vector2(-1, -1)], [Vector2(area.position.x, area.end.y), Vector2(1, -1)]]:
		var at: Vector2 = corner[0]
		var direction: Vector2 = corner[1]
		_vline(at, at + Vector2(26.0 * direction.x, 0.0), PHOSPHOR)
		_vline(at, at + Vector2(0.0, 26.0 * direction.y), PHOSPHOR)
