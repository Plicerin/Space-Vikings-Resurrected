extends Control
## RADAR and the SHIP # n I.D. programs on the screen. Everything the
## originals do is in radar_loop.gd and ship_id_loop.gd (and the two
## programs under them), which draw on hi-res page 1; this scene gives
## those loops a clock, a picture and a keyboard, and goes to whichever
## program RADAR ran.
##
## RADAR runs an I.D. program and the I.D. program runs RADAR again, as
## often as the player likes. Both are this one scene: it runs the one
## loop and then the other, and leaves only for the flight or for COM.
##
## The keyboard is the Apple's: every key goes into the latch, and the
## program makes of it what it will. RADAR asks for X or for anything
## else, and an I.D. for "a key".
##
## While RADAR loads the screen still shows what the last program left
## on the page, as the original's does, and then the stars come a few
## to a frame. With the radar shot away nothing comes at all: the
## program loads and runs whichever program ran it.

const RadarLoop = preload("res://scripts/radar/radar_loop.gd")
const ShipIdLoop = preload("res://scripts/radar/ship_id_loop.gd")
const HgrView = preload("res://scripts/shapes/hgr_view.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")

const FRAME := 1.0 / 60.0
## The program RADAR ran, as a scene.
const SCENES := {
	RadarLoop.Left.FLIGHT: "res://scenes/flight/space_flight.tscn",
	RadarLoop.Left.COM: "res://scenes/com.tscn",
}

@onready var _view: HgrView = $HGRCanvas/HgrView

## The RadarLoop or ShipIdLoop that is running.
var _loop: RefCounted
var _now := 0.0
var _due := 0.0
## Something to watch: called with what each loop's own `watch` is, for
## a test that drives the scene (tests/drive_radar.gd).
var watch: Callable = func(_what: String) -> void: pass


func _ready() -> void:
	_show_page()
	_radar()


func _radar() -> void:
	while true:
		var radar := RadarLoop.new()
		radar.wait = _wait
		radar.watch = _watch
		_loop = radar
		var left: RadarLoop.Left = await radar.run()
		if left != RadarLoop.Left.SHIP_ID:
			if SCENES.has(left):
				GameState.goto_scene(SCENES[left])
			return
		var id := ShipIdLoop.new(radar.ship_id)
		id.wait = _wait
		id.watch = _watch
		_loop = id
		if await id.run() != ShipIdLoop.Left.RADAR:
			return


func _watch(what: String) -> void:
	watch.call(what)


func _process(delta: float) -> void:
	_now += delta
	_show_page()


func _show_page() -> void:
	var page: HgrScreen = GameState.view3d.pages[GameState.view3d.shown]
	if _view.screen != page:
		_view.screen = page
		_view.queue_redraw()


## The loops' clock; see space_flight.gd.
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
