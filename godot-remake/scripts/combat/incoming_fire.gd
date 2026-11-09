extends Node2D
## `STARSHIP SIMULATOR.bas` lines 5000-5096: a second, simpler enemy
## pattern, independent of the two-fighter approach in
## `fighter_encounter.gd` — one shape crosses the screen in a straight
## line from a random top/bottom starting point, with a per-step
## chance (`RND(1)<.3`) to fire a fading tracer toward the player, and
## a smaller chance to reuse the retreat-flicker animation.
##
## CORRECTION (2026-11-09): this port originally hardcoded shape index
## 2 for the whole pattern — wrong, and a real one, not a cosmetic
## detail. The source's own shape pick (lines 5050-5080) depends on
## which horizontal third the spawn point falls in: `X1>190` (right
## third) draws shape **9**, which decodes to 23 real path commands;
## `X1<91` (left third) and the remaining middle case both draw shapes
## **10** and **8**, which both decode to only 2 commands (a single
## near-invisible dash — the same "odd=detailed, even=blank" pattern
## already confirmed elsewhere in this table, see
## `fighter_encounter.gd`'s doc comment). Shape 2 is neither of these —
## it's the fixed retreat/explosion shape `fighter_slot.gd` uses
## elsewhere. The structured, ship-like silhouette the manual's cockpit
## screenshot shows is shape 9; this port was never drawing it.
##
## The original's tracer target is the player's actual 3D position
## (never ported here — no player-relative combat position is tracked
## yet); PLAYER_POINT is a fixed stand-in for "toward the viewer."
##
## `tracer_fired` lets `flight_combat.gd` drive the real shootdown
## sub-mechanic (lines 5200-5251) without this node touching GameState
## itself — stays pure visual, same convention as the rest of
## `scripts/combat/`.

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const VectorShape2D = preload("res://scripts/shapes/vector_shape_2d.gd")

signal finished
signal tracer_fired

const PLAYER_POINT := Vector2(140, 150)
const FIRE_CHANCE := 0.3 # RND(1)<.3
const FLICKER_CHANCE := 0.15
const STEP_DURATION := 0.12
const TOTAL_STEPS := 20
const SCREEN := Rect2(0, 0, 280, 192)

var table: ShapeTable

@onready var _ship: VectorShape2D = $Ship
@onready var _tracers: Node2D = $Tracers

var _step: int = 0
var _timer: float = 0.0
var _pos: Vector2
var _vel: Vector2
var _active: bool = false


func _ready() -> void:
	_ship.visible = false


## Lines 5000-5080, ported directly (HGR pixel-space coordinates, same
## convention `hgr_canvas.gd`/`radar_hud.gd` already use):
## `X1=(RND(5)*260)+10`, `Y1` starts at the top (10) or bottom (120)
## edge with roughly 60%/40% odds, and the shape/horizontal-velocity
## pick depends on which third of the screen X1 falls in.
func start() -> void:
	_clear_tracers()
	_step = 0
	_timer = 0.0

	var x1 := randf() * 260.0 + 10.0
	var y1: float
	var y2: float
	if randf() >= 0.4:
		y1 = 10.0
		y2 = randf() * 7.0
	else:
		y1 = 120.0
		y2 = -(randf() * 7.0)

	var shape_idx: int
	var x2: float
	if x1 > 190.0:
		x2 = -7.0
		shape_idx = 9
	elif x1 < 91.0:
		x2 = 7.0
		shape_idx = 10
	else:
		x2 = -2.0
		shape_idx = 8
		if absf(y2) < 4.0:
			y2 *= 2.0

	_pos = Vector2(x1, y1)
	_vel = Vector2(x2, y2) / STEP_DURATION
	_active = true
	_ship.visible = true
	_ship.rotation_degrees = 0.0
	_ship.configure(table, table.clamp_index(shape_idx))
	_ship.position = _pos


func _process(delta: float) -> void:
	if not _active:
		return
	_timer += delta
	if _timer < STEP_DURATION:
		return
	_timer = 0.0
	_step += 1
	_pos += _vel * STEP_DURATION
	_ship.position = _pos

	if randf() < FIRE_CHANCE:
		_fire_tracer()
	elif randf() < FLICKER_CHANCE:
		_flicker()

	# Line 5095's own bounds check (`Y1<10 OR Y1>120 OR X1<10 OR
	# X1>270`) ends the pattern early once it leaves the HUD-bordered
	# play field, same bounds `TOTAL_STEPS` approximates as a fixed
	# step count -- whichever ends the pattern first.
	if _step >= TOTAL_STEPS or _pos.y < 10.0 or _pos.y > 120.0 or _pos.x < 10.0 or _pos.x > 270.0:
		_active = false
		_ship.visible = false
		finished.emit()


func _fire_tracer() -> void:
	# Line 5098: GOSUB 4110's preset (light) — the same one the ambient
	# damage tick's lighter hit uses (flight_combat.gd).
	AudioManager.play_hit_light()
	tracer_fired.emit()
	var line := Line2D.new()
	line.add_point(_pos)
	line.add_point(PLAYER_POINT)
	line.width = 1.0
	line.default_color = Color.WHITE
	_tracers.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(line.queue_free)


func _flicker() -> void:
	var rot_deg := 25.0 * 360.0 / 255.0
	var tween := create_tween()
	tween.tween_property(_ship, "rotation_degrees", rot_deg, 0.08)
	tween.tween_property(_ship, "rotation_degrees", 0.0, 0.08)


func _clear_tracers() -> void:
	for child in _tracers.get_children():
		child.queue_free()
