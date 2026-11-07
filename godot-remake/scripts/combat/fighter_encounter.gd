extends Node2D
## Two-fighter approach encounter — `STARSHIP SIMULATOR.bas` lines
## 1000-1090. Each step: the shared "flip-book" shape index (M3) creeps
## up by .32, the gap between the symmetric pair (M2) shrinks by 2, and
## the shared screen Y (M) drops by 4 — a fake-perspective "converging as
## they approach" look with none of the real 3D engine's math. A hit
## (firing the laser during the approach) sends both into
## `start_explosion()`; otherwise both `start_retreat()` once the
## approach completes.
##
## Simplified from the original: the real hit check is
## `PEEK(38210)=1 AND Y0<VV` (weapon fired and target in 3D range) or a
## bounding-box test against the player's position (line 1050) — neither
## of those has a Godot-side equivalent yet (no player-relative 3D combat
## position is tracked), so here firing at any point during the approach
## counts as a hit.

signal encounter_resolved(destroyed: bool)

@export var approach_steps: int = 16
@export var step_duration: float = 0.12 # feel-tuned; the original has no fixed real-time rate
@export var m1_center_x: float = 113.0 # matches the laser reticle's apex X, see laser_beam.gd
@export var m2_gap_start: float = 40.0
@export var m2_gap_step: float = 2.0
@export var m_y_start: float = 124.0
@export var m_y_step: float = 4.0
@export var m3_shape_start: float = 3.0
@export var m3_shape_increment: float = 0.32

var table: ShapeTable

@onready var _left: FighterSlot = $Left
@onready var _right: FighterSlot = $Right

var _step: int = 0
var _timer: float = 0.0
var _m: float
var _m2: float
var _m3: float
var _hit: bool = false
var _active: bool = false


func _ready() -> void:
	_left.retreat_finished.connect(_on_resolved.bind(false))
	_right.retreat_finished.connect(func() -> void: pass)
	_left.explosion_finished.connect(_on_resolved.bind(true))
	_right.explosion_finished.connect(func() -> void: pass)


func start_encounter() -> void:
	_left.table = table
	_right.table = table
	_step = 0
	_timer = 0.0
	_m = m_y_start
	_m2 = m2_gap_start
	_m3 = m3_shape_start
	_hit = false
	_active = true
	_update_approach_visual()


func _process(delta: float) -> void:
	if not _active:
		return
	if Input.is_action_just_pressed("fire_laser"):
		_hit = true

	_timer += delta
	if _timer < step_duration:
		return
	_timer = 0.0
	_step += 1
	if _step >= approach_steps:
		_active = false
		if _hit:
			_left.start_explosion()
			_right.start_explosion()
		else:
			_left.start_retreat()
			_right.start_retreat()
		return

	_m -= m_y_step
	_m2 -= m2_gap_step
	_m3 += m3_shape_increment
	_update_approach_visual()


func _update_approach_visual() -> void:
	var shape_idx := table.clamp_index(int(_m3))
	_left.show_approach(Vector2(m1_center_x - _m2, _m), shape_idx)
	_right.show_approach(Vector2(m1_center_x + _m2, _m), shape_idx)


func _on_resolved(destroyed: bool) -> void:
	encounter_resolved.emit(destroyed)
