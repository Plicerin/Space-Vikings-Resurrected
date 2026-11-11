extends Control
## STARSHIP SIMULATOR on the screen. Everything the original does in
## flight is in flight_loop.gd (and flight_program.gd, flight_combat.gd,
## combat_fx.gd under it), which draws on the two software hi-res pages
## GameState holds. This scene gives that loop a clock, a keyboard and a
## picture: whichever of the two pages the original would have on show.
##
## The keyboard is the Apple's: every printable key goes into the latch
## the program reads once a pass (line 200), so the keys are the
## original's own: 1 2 3 4 for the speed, A autopilot, B condition,
## S shields, W missile or laser, C command console, R radar,
## H hyperdrive.
##
## What the original had and a PC has not is a pair of paddles and their
## button. Here, and this is the port's choice:
##
##  - The arrow keys are the stick. Held when the program reads the
##    paddles (once a pass, line 15) they are the stick hard over, the
##    fastest of the original's four rates. A tap between two reads is
##    the stick a little off centre for that one pass, the slowest rate,
##    which is how to trim the bank back to level.
##    Up is stick forward (PDL(1) low: nose down), Down is stick back.
##  - SPACE is the button. A press is remembered until the program next
##    looks (line 185), so a tap between two passes still fires.

const FlightLoop = preload("res://scripts/flight/flight_loop.gd")
const HgrView = preload("res://scripts/shapes/hgr_view.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")

const FRAME := 1.0 / 60.0
## Paddle readings (0..255, 128 centred): hard over and just off centre.
## $9023 turns four times as fast under $1F and over $E6 as it does
## between $46 and $5A or $AA and $BE.
const STICK_LOW := 0
const STICK_HIGH := 255
const STICK_SLIGHTLY_LOW := 0x50
const STICK_SLIGHTLY_HIGH := 0xB0
const STICK_CENTRED := 128
## S_X.bas line 50: `GET A$: GET A$`, then the machine reboots.
const KEYS_AFTER_DESTRUCTION := 2

@onready var _view: HgrView = $HGRCanvas/HgrView
@onready var _fx: Node = $CombatFx

var _loop := FlightLoop.new()
var _now := 0.0
var _due := 0.0
var _tapped := {} # stick action -> pressed since the paddles were last read
var _fire := false
var _keys_to_leave := 0


func _ready() -> void:
	_fx.screen = GameState.view3d.pages[0] # BASIC draws on page 1 whatever is shown
	_show_page()
	_loop.setup(_fx)
	_loop.wait = _wait
	_loop.read_stick = _read_stick
	_loop.read_button = _read_button
	_fly()


func _fly() -> void:
	match await _loop.run():
		FlightLoop.Left.COM:
			GameState.goto_scene("res://scenes/com.tscn")
		FlightLoop.Left.RADAR:
			GameState.goto_scene("res://scenes/radar.tscn")
		FlightLoop.Left.DESTROYED:
			_keys_to_leave = KEYS_AFTER_DESTRUCTION


func _process(delta: float) -> void:
	_now += delta
	_show_page()


func _show_page() -> void:
	var page: HgrScreen = GameState.view3d.pages[GameState.view3d.shown]
	if _view.screen != page:
		_view.screen = page
		_view.queue_redraw()


## flight_loop.gd's clock. The waits are added up from where the last one
## ended, not from when it was noticed to have ended, so a slow frame
## here does not slow the game down; but a long stop (an effect that ran
## on its own clock, a stalled window) is not made up for either.
func _wait(frames: float) -> void:
	_due = maxf(_due, _now - 2.0 * FRAME) + frames * FRAME
	while _now < _due:
		await get_tree().process_frame


func _read_stick() -> void:
	_loop.program.input_pitch = _paddle("stick_forward", "stick_back")
	_loop.program.input_bank = _paddle("stick_left", "stick_right")
	_tapped.clear()


func _paddle(low: String, high: String) -> int:
	if Input.is_action_pressed(low):
		return STICK_LOW
	if Input.is_action_pressed(high):
		return STICK_HIGH
	if _tapped.has(low):
		return STICK_SLIGHTLY_LOW
	if _tapped.has(high):
		return STICK_SLIGHTLY_HIGH
	return STICK_CENTRED


func _read_button() -> bool:
	var down := _fire or Input.is_action_pressed("fire")
	_fire = false
	return down


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if _keys_to_leave > 0:
		_keys_to_leave -= 1
		if _keys_to_leave == 0:
			GameState.booted = false # the original reboots
			GameState.goto_scene("res://scenes/start.tscn")
		return
	for action: String in ["stick_forward", "stick_back", "stick_left", "stick_right"]:
		if event.is_action(action):
			_tapped[action] = true
			return
	if event.is_action("fire"):
		_fire = true
		return
	var code: int = event.unicode
	if code > 32 and code < 127:
		_loop.program.press(String.chr(code))
