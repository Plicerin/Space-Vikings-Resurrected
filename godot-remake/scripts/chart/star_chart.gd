extends Control
## GALAXY MAP on the screen. Everything the original does is in
## chart_loop.gd (and chart_program.gd under it), which draws on hi-res
## page 1; this scene gives that loop a clock, a picture, a keyboard and
## something to be the paddles.
##
## The keyboard is the Apple's: every key goes into the latch. The chart
## leaves on any key at all (the screen asks for SPACE), and its two
## questions take a key each.
##
## What the original had and a PC has not is the pair of paddles that
## move the cross, and their button. Here, and this is the port's choice:
##
##  - The mouse is the paddles. The original's cross is at PDL(0) * 1.19
##    across and PDL(1) down, so the paddles are set to whatever puts
##    the cross under the pointer. It still moves the way the original's
##    did: twelve times a second, and it flickers (chart_loop.gd).
##  - The arrow keys turn the same two paddles, a step for every turn of
##    the chart's loop they are held through.
##  - A mouse click or ENTER is the button. A press is remembered until
##    the program next looks (line 3130).
##
## While GALAXY MAP loads the screen still shows what COM left on the
## page, as the original's does. Both ways out run COM (scenes/com.tscn).

const ChartLoop = preload("res://scripts/chart/chart_loop.gd")
const HgrView = preload("res://scripts/shapes/hgr_view.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")

const FRAME := 1.0 / 60.0
## Paddle units an arrow key turns in one turn of the loop.
const ARROW_STEP_X := 5
const ARROW_STEP_Y := 4

@onready var _view: HgrView = $HGRCanvas/HgrView

var _loop := ChartLoop.new()
var _now := 0.0
var _due := 0.0
var _paddles := [128, 96]
var _button := false


func _ready() -> void:
	_show_page()
	_point(_view.get_local_mouse_position())
	_loop.wait = _wait
	_loop.read_paddles = func() -> Array: return _paddles
	_loop.read_button = _read_button
	_loop.watch = _watch
	_chart()


func _chart() -> void:
	if await _loop.run() == ChartLoop.Left.COM:
		GameState.goto_scene("res://scenes/com.tscn")


func _process(delta: float) -> void:
	_now += delta
	_show_page()


func _show_page() -> void:
	var page: HgrScreen = GameState.view3d.pages[GameState.view3d.shown]
	if _view.screen != page:
		_view.screen = page
		_view.queue_redraw()


## chart_loop.gd's clock; see space_flight.gd.
func _wait(frames: float) -> void:
	_due = maxf(_due, _now - 2.0 * FRAME) + frames * FRAME
	while _now < _due:
		await get_tree().process_frame


func _watch(what: String) -> void:
	if what == "turn":
		_turn_paddle(0, "stick_left", "stick_right", ARROW_STEP_X)
		_turn_paddle(1, "stick_forward", "stick_back", ARROW_STEP_Y)


func _turn_paddle(paddle: int, down: String, up: String, step: int) -> void:
	if Input.is_action_pressed(down):
		_paddles[paddle] = maxi(_paddles[paddle] - step, 0)
	if Input.is_action_pressed(up):
		_paddles[paddle] = mini(_paddles[paddle] + step, 255)


func _read_button() -> bool:
	var down := _button or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			or Input.is_key_pressed(KEY_ENTER)
	_button = false
	return down


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_point(_view.make_input_local(event).position)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_button = true
	elif event is InputEventKey:
		_key(event)


## The paddles that put the cross at a place on the hi-res screen.
func _point(at: Vector2) -> void:
	_paddles[0] = clampi(roundi(at.x / 1.19), 0, 255)
	_paddles[1] = clampi(roundi(at.y), 0, 255)


func _key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	for action: String in ["stick_forward", "stick_back", "stick_left", "stick_right"]:
		if event.is_action(action):
			return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_button = true
		return
	var code: int = event.unicode
	if event.keycode == KEY_ESCAPE:
		code = 27
	if code == 27 or (code >= 32 and code < 127):
		_loop.program.press(String.chr(code))
