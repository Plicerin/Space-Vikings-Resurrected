class_name FighterSlot
extends Node2D
## One fighter's approach/retreat/explosion visuals
## (`STARSHIP SIMULATOR.bas` lines 1000-1222). Two of these, mirrored
## left/right, make up one symmetric encounter — see
## `fighter_encounter.gd`, which drives both in lockstep. The Tween-based
## animation here is the idiomatic-Godot replacement for the original's
## manual per-frame redraw loop; the shapes, phases, and their order are
## ported straight from the BASIC source.

signal retreat_finished
signal explosion_finished

var table: ShapeTable

@onready var _approach: VectorShape2D = $Approach
@onready var _flash: VectorShape2D = $Flash
@onready var _debris: Array[VectorShape2D] = [$Debris15, $Debris16, $Debris17, $Debris18]

var _tween: Tween
var _rot_tween: Tween

func _ready() -> void:
	_approach.visible = false
	_flash.visible = false
	for d in _debris:
		d.visible = false

# Approach steps reuse this same sprite node every call, but a previous
# retreat/explosion's tween can still be mid-flight when a new encounter
# starts (start_encounter() is re-entrant on the same FighterSlot) — kill
# it first, or it keeps animating scale/rotation underneath the fresh
# approach pose and corrupts the frame.
func show_approach(screen_pos: Vector2, shape_idx: int) -> void:
	_kill_tweens()
	_approach.visible = true
	_approach.scale = Vector2.ONE
	_approach.rotation_degrees = 0.0
	_approach.position = screen_pos
	_approach.configure(table, table.clamp_index(shape_idx))

func _kill_tweens() -> void:
	if _tween:
		_tween.kill()
	if _rot_tween:
		_rot_tween.kill()

## Line 1100: fixed shape 2 (not the approach flip-book), Applesoft ROT
## cycled 0/25 while shrinking away. XDRAW's ROT parameter is a 0-255
## shape-table rotation unit (255 = full turn); 25 ~= 35 degrees — ported
## here as a small rocking motion between 0 and that angle while the
## sprite scales down, standing in for the original's literal redraw-at-
## alternating-ROT loop.
func start_retreat() -> void:
	_kill_tweens()
	var rot_deg := 25.0 * 360.0 / 255.0
	_approach.configure(table, 2)

	# Two independent Tweens running concurrently (not Tween.set_parallel,
	# which only pairs each new Tweener with the one immediately before
	# it — not what a 4-cycle oscillation alongside a single long scale
	# tween needs) so the shrink and the rock genuinely overlap.
	_tween = create_tween()
	_tween.tween_property(_approach, "scale", Vector2(0.1, 0.1), 0.8)
	_tween.tween_callback(func() -> void:
		_approach.visible = false
		retreat_finished.emit()
	)

	_rot_tween = create_tween()
	for i in range(4):
		_rot_tween.tween_property(_approach, "rotation_degrees", rot_deg, 0.1)
		_rot_tween.tween_property(_approach, "rotation_degrees", 0.0, 0.1)

## Lines 1200-1222: SCALE 1 then 2 flash on shape 2, then shapes 15-18
## stamped together at the same anchor point — the doc's own read of
## those four shapes is that they're scattered debris fragments, not a
## tidy radial starburst, so they're shown together rather than in
## sequence; the flash and the simultaneous overlay carry the effect.
func start_explosion() -> void:
	_kill_tweens()
	var anchor := _approach.position
	_approach.visible = false

	_flash.position = anchor
	_flash.scale = Vector2.ONE
	_flash.configure(table, 2)
	_flash.visible = true

	for d in _debris:
		d.position = anchor
		d.scale = Vector2.ONE
		d.visible = false

	_tween = create_tween()
	_tween.tween_property(_flash, "scale", Vector2(2.0, 2.0), 0.15)
	_tween.tween_callback(func() -> void:
		_flash.visible = false
		for i in range(_debris.size()):
			_debris[i].configure(table, 15 + i)
			_debris[i].visible = true
	)
	_tween.tween_interval(0.35)
	_tween.tween_callback(func() -> void:
		for d in _debris:
			d.visible = false
		explosion_finished.emit()
	)
