extends Control
## END on the screen. Everything the original does is in end_loop.gd
## (and end_program.gd under it), which draws on hi-res page 1; this
## scene gives that loop a clock, a picture and a keyboard, and goes
## where END went.
##
## The keyboard is the Apple's: every key goes into the latch, and the
## program makes of it what it will. Here that matters: END reads a
## number, and a key that is not one is the SYSTEM ERROR screen and a
## reboot, as on the real game (see end_program.gd).
##
## While END loads the screen still shows what COM left on the page, as
## the original's does.
##
## "3) END GAME" leaves the Apple dead with a black screen, to be
## switched off. Here the screen goes black at the same moment and the
## application closes a second later: the switching off is the one
## thing done for the player.

const EndLoop = preload("res://scripts/end/end_loop.gd")
const HgrView = preload("res://scripts/shapes/hgr_view.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")

const FRAME := 1.0 / 60.0
## How long the dead machine's black screen is left up.
const DEAD_FRAMES := 60.0

@onready var _view: HgrView = $HGRCanvas/HgrView

var _loop := EndLoop.new()
var _now := 0.0
var _due := 0.0


func _ready() -> void:
	_show_page()
	_loop.wait = _wait
	_end()


func _end() -> void:
	var left: EndLoop.Left = await _loop.run()
	match left:
		EndLoop.Left.CONTINUE:
			GameState.goto_scene("res://scenes/flight/space_flight.tscn")
		EndLoop.Left.ERROR:
			GameState.goto_scene("res://scenes/system_error.tscn")
		EndLoop.Left.QUIT:
			_view.visible = false
			$Keys.visible = false
			await _wait(DEAD_FRAMES)
			get_tree().quit()


func _process(delta: float) -> void:
	_now += delta
	_show_page()


func _show_page() -> void:
	var page: HgrScreen = GameState.view3d.pages[GameState.view3d.shown]
	if _view.screen != page:
		_view.screen = page
		_view.queue_redraw()


## end_loop.gd's clock; see space_flight.gd.
func _wait(frames: float) -> void:
	_due = maxf(_due, _now - 2.0 * FRAME) + frames * FRAME
	while _now < _due and is_inside_tree(): # a scene taken down mid-wait stops waiting
		await get_tree().process_frame


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.unicode
	match event.keycode:
		KEY_ESCAPE:
			code = 27
		KEY_BACKSPACE, KEY_LEFT:
			code = 8
		KEY_ENTER, KEY_KP_ENTER:
			code = 13
	if code == 8 or code == 13 or code == 27 or (code >= 32 and code < 127):
		_loop.program.press(String.chr(code))


func _exit_tree() -> void:
	_loop.stop = true # a scene taken down mid-run has nothing to wait for
