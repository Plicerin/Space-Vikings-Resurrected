extends Node2D
## `STARSHIP SIMULATOR.bas` lines 5000-5251: a second, simpler enemy
## pattern, independent of the two-fighter approach in
## `fighter_encounter.gd` — one shape crosses the screen from a random
## edge position along a straight trajectory, with a per-step chance
## (`RND(1)<.3`) to fire a fading tracer toward the player, and a smaller
## chance to reuse the retreat-flicker animation.
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


func start() -> void:
	_clear_tracers()
	_step = 0
	_timer = 0.0
	_pos = _random_edge_point()
	var target := _random_edge_point()
	_vel = (target - _pos) / (TOTAL_STEPS * STEP_DURATION)
	_active = true
	_ship.visible = true
	_ship.rotation_degrees = 0.0
	_ship.configure(table, 2)
	_ship.position = _pos


func _random_edge_point() -> Vector2:
	match randi() % 4:
		0:
			return Vector2(0.0, randf() * SCREEN.size.y)
		1:
			return Vector2(SCREEN.size.x, randf() * SCREEN.size.y)
		2:
			return Vector2(randf() * SCREEN.size.x, 0.0)
		_:
			return Vector2(randf() * SCREEN.size.x, SCREEN.size.y)


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

	if _step >= TOTAL_STEPS:
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
