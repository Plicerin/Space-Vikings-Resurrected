extends Node
## Every flight-combat effect of STARSHIP SIMULATOR.bas and EX.bas, drawn
## on the hi-res page the way the original draws it: the same XDRAW /
## HPLOT calls at the same coordinates in the same order, with the
## pauses between them taken from the real machine. Nothing here decides
## game state; flight_combat.gd does that and listens to the signals.
##
## The original runs these as BASIC subroutines, one at a time, with the
## flight loop stopped while they run. So only one effect runs at a time
## here too: every `fire_*` / `fighter_pass` / ... returns false and does
## nothing while another is running, and `idle` fires when one ends.
##
## Timing. One unit is one video frame (1/60 s) of the real machine,
## measured with tools/mame/fight_live.lua (page-change and byte-change
## frames in analysis/fight_live_*.log):
##   - fighter pass: 5 frames per step (drawn about 2, erased about 3);
##     a strafing hit holds the step for about 35 with the turrets firing
##   - a `CALL SG` right after a GOSUB 4100/4110 preset lasts 13 / 11
##     frames, later ones 1-2
##   - the burst of line 1100: XDRAWs at frames 0, 13, 17, 22, 27, 31,
##     35, 40, done at 45
##   - laser: lines up in about 5 frames, 44 lit (`CALL LA`), erased over
##     about 5 in drawing order, 3 dark; 56 per pulse
##   - missile sparkles: 12 frames per step
##   - hi-res text: about 2.5 frames per character
## The missile's direct hit (1200-1222), the damage flashes (3019/3032)
## and EX.bas were not caught on a capture; their waits are estimates
## built from the measured costs above and are marked ESTIMATE below.
##
## The white flashes are `POKE -16298,0` ... `POKE -16297,0` (see
## hgr_view.gd). A flash lasts as long as whatever BASIC runs between
## the two POKEs.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const HgrView = preload("res://scripts/shapes/hgr_view.gd")

const ENEMY_SHAPES := "res://assets/shapes/ENEMY I.A24580.L68.payload.json"
const FRAME := 1.0 / 60.0
## The 3D window is rows 0..123; the instrument panel starts below it.
const WINDOW_ROWS := 124

## `CALL SG` lengths in frames, first call after each preset.
const SG_HEAVY := 13.0
const SG_MEDIUM := 12.0 # ESTIMATE (between the two measured ones)
const SG_LIGHT := 11.0
## Frames between the eight XDRAWs of the line-1100 burst.
const BURST_WAITS: Array[float] = [13.0, 4.0, 5.0, 5.0, 4.0, 4.0, 5.0, 5.0]

signal idle
signal missile_finished(hit: bool)
signal laser_finished
signal fighter_strafed
signal fighter_shot_down
signal fighter_pass_finished
signal damage_finished
signal message_finished
signal destruction_finished

@export var view_path: NodePath

var table := ShapeTable.new()
var view: HgrView
var screen: HgrScreen

var _steps: Array = [] # float = wait that many frames, Callable = do it
var _wait := 0.0
var _busy := false
var _done := Callable()

# The fighter of the pass in progress (X1, Y1, X2, Y2, M of line 5000).
var _fighter_pos := Vector2.ZERO
var _fighter_step := Vector2.ZERO
var _fighter_shape := 8
var _turrets_armed := false


func _ready() -> void:
	table.load_shapes(ENEMY_SHAPES)
	view = get_node(view_path)
	screen = view.screen


func is_busy() -> bool:
	return _busy


## Stands for the flight renderer redrawing page 1: whatever BASIC left
## in the 3D window is gone. Call once per flight-loop iteration.
func clear_window() -> void:
	if not _busy:
		screen.clear_rows(0, WINDOW_ROWS - 1)


func _process(delta: float) -> void:
	if not _busy:
		return
	_wait -= delta
	while _busy and _wait <= 0.0:
		if _steps.is_empty():
			_busy = false
			var done := _done
			_done = Callable()
			done.call()
			if not _busy:
				idle.emit()
			return
		var step = _steps.pop_front()
		if step is Callable:
			step.call()
		else:
			_wait += float(step) * FRAME


func _begin(steps: Array, done: Callable) -> bool:
	if _busy:
		return false
	_steps = steps
	_done = done
	_wait = 0.0
	_busy = true
	return true


func _flash(frames: float) -> void:
	view.flash(frames * FRAME)


func _xdraw(shape: int, x: float, y: float) -> void:
	screen.xdraw(table, table.clamp_index(shape), int(x), int(y))


# --- Missile (lines 1000-1222) ---

## Two sparkles converge on the gunsight over 16 steps, then either the
## direct hit of line 1200 or the burst of line 1100. Whether it hits is
## the caller's decision (line 1050's box test).
func fire_missile(hit: bool) -> bool:
	if _busy:
		return false
	var steps: Array = []
	# FOR M=124 TO 62 STEP -4, with M3=M3+.32 and M2=M2-2 each time round.
	for k in range(16):
		var shape := int(3.0 + 0.32 * k)
		var y := 124 - 4 * k
		var spread := 40 - 2 * k
		var pair := func() -> void:
			_xdraw(shape, 140 + spread, y)
			_xdraw(shape, 140 - spread, y)
		steps.append_array([pair, 6.0, pair, 6.0])
	# The loop leaves M=60 and M2=8.
	if hit:
		steps.append_array(_direct_hit_steps(132, 148, 60))
	else:
		steps.append_array(_burst_steps(132, 148, 60))
	return _begin(steps, func() -> void: missile_finished.emit(hit))


## Line 1100: `GOSUB 4100: POKE -16298,0: POKE -16297,0: HCOLOR=3: FOR
## X0=1 TO 2: FOR LY=0 TO 1: ROT=LY*25: XDRAW 2 AT M1-M2,M: CALL SG:
## XDRAW 2 AT M1+M2,M: CALL SG: NEXT: HCOLOR=0: NEXT: ROT=1`. The second
## pass XORs the first one away. It leaves ROT=1 and HCOLOR=0 behind, as
## the original does.
func _burst_steps(left: float, right: float, y: float) -> Array:
	var start := func() -> void:
		AudioManager.play_hit_heavy()
		_flash(0.18) # two POKEs back to back, about 3 ms
		screen.hcolor = 3
	var steps: Array = [start]
	var n := 0
	for pass_no in range(2):
		for ly in range(2):
			for x in [left, right]:
				steps.append(func() -> void:
					screen.rot = ly * 25
					_xdraw(2, x, y)
				)
				steps.append(BURST_WAITS[n])
				n += 1
		steps.append(func() -> void: screen.hcolor = 0)
	steps.append(func() -> void: screen.rot = 1)
	return steps


## Lines 1200-1222, twice over (the second pass erases): on each side the
## burst at SCALE 1 and 2, then the four quarter-discs under a flash,
## with the heavy noise between the two sides. Waits are an ESTIMATE.
func _direct_hit_steps(left: float, right: float, y: float) -> Array:
	var steps: Array = []
	for pass_no in range(2):
		for side in range(2):
			var x: float = left if side == 0 else right
			steps.append(func() -> void:
				screen.shape_scale = 1
				_xdraw(2, x, y)
			)
			steps.append(1.0)
			steps.append(func() -> void:
				screen.shape_scale = 2
				_xdraw(2, x, y)
			)
			steps.append(2.0)
			steps.append(func() -> void:
				screen.shape_scale = 1
				_flash(5.0)
				for quarter in range(15, 19):
					_xdraw(quarter, x, y)
			)
			steps.append(5.0)
			if side == 0:
				steps.append(func() -> void: AudioManager.play_hit_heavy())
				steps.append(SG_HEAVY)
	return steps


# --- Laser (lines 1505-1530) ---

## Three pulses of the two orange V's from the panel corners to the
## gunsight. The lines are drawn while the screen is white, so they
## appear whole; the erase is visible, and because HCOLOR 0 clears a
## byte's palette bit the not-yet-erased rest of each line turns from
## orange to green as the eraser passes. All of that is the original.
func fire_laser() -> bool:
	if _busy:
		return false
	var left: Array = [90, 123, 136, 60, 94, 123]
	var right: Array = [190, 123, 144, 60, 186, 123]
	var steps: Array = []
	for pulse in range(3):
		steps.append(func() -> void:
			screen.hcolor = 5
			_flash(5.0)
			screen.hplot_path(left)
			screen.hplot_path(right)
		)
		steps.append(5.0)
		steps.append(func() -> void: AudioManager.play_laser())
		steps.append(44.0)
		steps.append(func() -> void: screen.hcolor = 0)
		for path: Array in [left, right]:
			for i in [0, 2]:
				var segment: Array = path.slice(i, i + 4)
				steps.append(func() -> void: screen.hplot_path(segment))
				steps.append(1.25)
		steps.append(3.0) # FOR J=1 TO 40: NEXT
	return _begin(steps, func() -> void: laser_finished.emit())


# --- Fighter pass (lines 5000-5251) ---

## One enemy fighter crosses the window. Each step has a 30% chance of a
## strafing hit (`fighter_strafed`); if `turrets_armed` (condition RED)
## the point-defence turrets then fire two tracers at it and destroy it
## 30% of the time (`fighter_shot_down`, which also ends the pass).
func fighter_pass(turrets_armed: bool) -> bool:
	if _busy:
		return false
	_turrets_armed = turrets_armed
	# 5000-5080
	_fighter_pos.x = randf() * 260.0 + 10.0
	if randf() >= 0.4:
		_fighter_pos.y = 10.0
		_fighter_step.y = randf() * 7.0
	else:
		_fighter_pos.y = 120.0
		_fighter_step.y = -randf() * 7.0
	if _fighter_pos.x > 190.0:
		_fighter_step.x = -7.0
		_fighter_shape = 9
	elif _fighter_pos.x < 91.0:
		_fighter_step.x = 7.0
		_fighter_shape = 10
	else:
		_fighter_step.x = -2.0
		_fighter_shape = 8
		if absf(_fighter_step.y) < 4.0:
			_fighter_step.y *= 2.0
	return _begin([_fighter_show], func() -> void: fighter_pass_finished.emit())


func _draw_fighter() -> void:
	_xdraw(_fighter_shape, _fighter_pos.x, _fighter_pos.y)


## Line 5090: draw, then maybe strafe.
func _fighter_show() -> void:
	_draw_fighter()
	if randf() >= 0.3:
		_steps.append_array([2.0, _fighter_advance])
		return
	# 5098: GOSUB 4110: POKE -16298,0: CALL SG: POKE -16297,0, then the
	# shield wear of line 3205.
	var strafe := func() -> void:
		AudioManager.play_hit_light()
		_flash(SG_LIGHT)
	var strafed := func() -> void: fighter_strafed.emit()
	_steps.append_array([1.0, strafe, SG_LIGHT, strafed])
	if not _turrets_armed:
		_steps.append_array([2.0, _fighter_advance])
		return
	# 5210-5230: both tracers in HCOLOR 5, then again in HCOLOR 0.
	var turret_x := 40.0 if randf() < 0.6 else 240.0
	var target := _fighter_pos
	var tracer_a: Array = [int(turret_x - 20.0), 123, int(target.x - 3.0), int(target.y + 3.0)]
	var tracer_b: Array = [int(turret_x + 20.0), 123, int(target.x + 3.0), int(target.y + 3.0)]
	_steps.append(6.0)
	for color: int in [5, 0]:
		var first := func() -> void:
			screen.hcolor = color
			_flash(0.4) # FOR J1=1 TO 5: NEXT
			screen.hplot_path(tracer_a)
		var second := func() -> void: screen.hplot_path(tracer_b)
		_steps.append_array([first, 2.25, second, 2.25, 3.5 if color == 5 else 0.0])
	# 5240
	if randf() < 0.3:
		# 5250: erase the fighter, burst where it was.
		_steps.append_array([2.0, _draw_fighter, 6.0])
		_steps.append_array(_burst_steps(target.x - 4.0, target.x + 4.0, target.y))
		_steps.append(func() -> void: fighter_shot_down.emit())
	else:
		_steps.append_array([2.5, _fighter_advance])


## Line 5095: erase, move, leave when outside the window.
func _fighter_advance() -> void:
	_draw_fighter()
	_fighter_pos += _fighter_step
	if _fighter_pos.y < 10.0 or _fighter_pos.y > 120.0 or _fighter_pos.x < 10.0 or _fighter_pos.x > 270.0:
		return
	_steps.append_array([3.0, _fighter_show])


# --- Damage flashes (lines 3019 and 3032) ---

## `light_flashes` short flashes with the light noise (0 = none), then,
## if `medium`, one long flash with the medium noise. Waits are an
## ESTIMATE.
func damage(light_flashes: int, medium: bool) -> bool:
	if _busy:
		return false
	var steps: Array = []
	for i in range(light_flashes):
		# POKE -16298,0: FOR J=1 TO 10: NEXT: POKE -16297,0: CALL SG, then
		# a pause of 10 to 50 empty FOR passes.
		steps.append(func() -> void: _flash(0.8))
		steps.append(1.0)
		if i == 0:
			steps.append(func() -> void: AudioManager.play_hit_light())
			steps.append(SG_LIGHT)
		else:
			steps.append(1.5)
		steps.append(randf_range(0.8, 4.0))
	if medium:
		# POKE -16298,0: CALL SG: POKE -16297,0: CALL SG
		steps.append(func() -> void:
			AudioManager.play_hit_medium()
			_flash(SG_MEDIUM)
		)
		steps.append(SG_MEDIUM)
		steps.append(1.5)
	return _begin(steps, func() -> void: damage_finished.emit())


# --- Text (line 1550) ---

## PRINT at SPEED=127 through the hi-res character generator: one
## character at a time. `htab` and `vtab` are 1-based, as in BASIC.
func print_message(text: String, htab: int, vtab: int) -> bool:
	if _busy:
		return false
	var steps: Array = []
	for i in range(text.length()):
		steps.append(func() -> void:
			screen.text_mode = 0
			screen.print_at(text[i], htab + i, vtab)
		)
		steps.append(2.5)
	return _begin(steps, func() -> void: message_finished.emit())


# --- The orbital defender blows up (EX.bas) ---

## Lines 5-30: the burst and the four quarter-discs at SCALE 2 on the
## gunsight, a long white-out with 50 noise calls, 25 more with the
## picture back, then 16 x 15 white lines thrown out from (140,60), each
## fan wider than the last. Nothing erases it; the next redraw of the
## window does. Waits are an ESTIMATE.
func destroy_defender() -> bool:
	if _busy:
		return false
	var blast := func() -> void:
		screen.hcolor = 3
		screen.shape_scale = 2
		for shape: int in [2, 15, 16, 17, 18]:
			_xdraw(shape, 140, 65)
		screen.shape_scale = 1
		AudioManager.play_explosion()
		_flash(75.0)
	var steps: Array = [blast, 75.0, 37.0]
	var y1 := 20.0
	for x1 in range(5, 131, 8):
		y1 += 4.8
		for j in range(15):
			var x2 := x1 - randf() * 2.0 * x1
			var y2 := clampf(y1 - randf() * 2.0 * y1, -60.0, 65.0)
			steps.append(func() -> void:
				screen.hcolor = 3
				screen.hplot_path([140, 60, int(140.0 + x2), int(60.0 + y2)])
			)
			steps.append(1.2 + Vector2(x2, y2).length() / 62.0)
	return _begin(steps, func() -> void: destruction_finished.emit())
