extends Control
## COM on the screen. Everything the original does is in com_loop.gd
## (and com_program.gd under it), which draws on hi-res page 1; this
## scene gives that loop a clock, a picture and a keyboard, and goes to
## whichever program COM ran.
##
## The keyboard is the Apple's: every key goes into the latch, and the
## program makes of it what it will. BACKSPACE and the left arrow are
## the Apple's left arrow (CHR$(8)), ENTER its RETURN.
##
## While COM loads the screen still shows what the last program left on
## the page, as the original's does.
##
## The programs under COM that are not on the hi-res page yet (GROUND
## FORCES, RADAR, END, STATUS, SUPPLY) are still Godot screens. They come
## back here, which runs COM from the top again as theirs do.

const ComLoop = preload("res://scripts/com/com_loop.gd")
const HgrView = preload("res://scripts/shapes/hgr_view.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")

const FRAME := 1.0 / 60.0
## The program COM ran, as a scene.
const SCENES := {
	ComLoop.Left.FLIGHT: "res://scenes/flight/space_flight.tscn",
	ComLoop.Left.GROUND_FORCES: "res://scenes/ground_forces.tscn",
	ComLoop.Left.RADAR: "res://scenes/radar.tscn",
	ComLoop.Left.END: "res://scenes/end_game.tscn",
	ComLoop.Left.GALAXY_MAP: "res://scenes/star_chart.tscn",
	ComLoop.Left.STATUS: "res://scenes/status.tscn",
	ComLoop.Left.SUPPLY: "res://scenes/supply_report.tscn",
}

@onready var _view: HgrView = $HGRCanvas/HgrView

var _loop := ComLoop.new()
var _now := 0.0
var _due := 0.0


func _ready() -> void:
	_show_page()
	_loop.wait = _wait
	_console()


func _console() -> void:
	var left: ComLoop.Left = await _loop.run()
	if SCENES.has(left):
		GameState.goto_scene(SCENES[left])


func _process(delta: float) -> void:
	_now += delta
	_show_page()


func _show_page() -> void:
	var page: HgrScreen = GameState.view3d.pages[GameState.view3d.shown]
	if _view.screen != page:
		_view.screen = page
		_view.queue_redraw()


## com_loop.gd's clock; see space_flight.gd.
func _wait(frames: float) -> void:
	_due = maxf(_due, _now - 2.0 * FRAME) + frames * FRAME
	while _now < _due:
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
