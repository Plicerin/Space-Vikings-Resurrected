extends Control
## STATUS and SUPPLY on the screen. Everything the originals do is in
## status_loop.gd and supply_loop.gd (and the two programs under them),
## which draw on hi-res page 1; this scene gives one of those loops a
## clock, a picture and a keyboard, and goes back to COM as they do.
##
## The keyboard is the Apple's: every key goes into the latch, and the
## program makes of it what it will. Neither report asks for more than
## "a key".
##
## While the report loads the screen still shows COM's central computer
## menu, as the original's does, and then the view is painted green a
## row at a time before anything is printed.
##
## One thing is here that the Apple has not got, and it is outside its
## picture: when the troops are on a planet, the line of key hints under
## the screen says which. STATUS prints PLANETSIDE or SHORE LEAVE and
## not where, and with a jump between landing and recalling them it is
## easy to lose track; the original expects it written down.

const StatusLoop = preload("res://scripts/reports/status_loop.gd")
const SupplyLoop = preload("res://scripts/reports/supply_loop.gd")
const HgrView = preload("res://scripts/shapes/hgr_view.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")

const FRAME := 1.0 / 60.0
const COM := "res://scenes/com.tscn"

## Which program this scene is: "status" or "supply".
@export var report := "status"

@onready var _view: HgrView = $HGRCanvas/HgrView

## A StatusLoop or a SupplyLoop.
var _loop: RefCounted
var _now := 0.0
var _due := 0.0


func _ready() -> void:
	_loop = SupplyLoop.new() if report == "supply" else StatusLoop.new()
	if report != "supply" and (GameState.troop_location == 1 or GameState.troop_location == 2):
		var star: int = GameState.troops_stationed_at - 1
		if star >= 0 and star < GameState.STAR_NAMES.size():
			$Keys.text += "   (the troops are at %s)" % GameState.STAR_NAMES[star]
	_show_page()
	_loop.wait = _wait
	_report()


func _report() -> void:
	# both loops' Left has COM as its 1
	if await _loop.run() == StatusLoop.Left.COM:
		GameState.goto_scene(COM)


func _process(delta: float) -> void:
	_now += delta
	_show_page()


func _show_page() -> void:
	var page: HgrScreen = GameState.view3d.pages[GameState.view3d.shown]
	if _view.screen != page:
		_view.screen = page
		_view.queue_redraw()


## The loop's clock; see space_flight.gd.
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
