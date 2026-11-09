extends Node2D
## One missile trail's approach/miss/hit visuals
## (`STARSHIP SIMULATOR.bas` lines 1000-1222, see `missile_strike.gd`'s
## doc comment for the 2026-11-09 correction from this file's previous
## life as `fighter_slot.gd` -- "two-fighter minigame" was never
## confirmed and was wrong; this is the real missile attack on the
## orbital defender, drawn as a symmetric twin trail). Two of these,
## mirrored left/right, make up one strike -- see `missile_strike.gd`,
## which drives both in lockstep. The Tween-based animation here is the
## idiomatic-Godot replacement for the original's manual per-frame
## redraw loop; the shapes, phases, and their order are ported straight
## from the BASIC source.
##
## No `class_name` (see shape_table.gd) -- callers preload this script
## into a local `MissileTrail` const.

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const VectorShape2D = preload("res://scripts/shapes/vector_shape_2d.gd")

signal miss_finished
signal hit_finished

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
# miss/hit's tween can still be mid-flight when a new strike starts
# (start_strike() is re-entrant on the same MissileTrail) -- kill it
# first, or it keeps animating scale/rotation underneath the fresh
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
## cycled 0/25 while shrinking away -- the manual's own "missiles...
## self-destruct before reaching their target" (out of range, or
## "electronic countermeasures confuse the missile guidance system",
## i.e. a bad aim). XDRAW's ROT parameter is a 0-255 shape-table
## rotation unit (255 = full turn); 25 ~= 35 degrees -- ported here as
## a small rocking motion between 0 and that angle while the sprite
## scales down, standing in for the original's literal redraw-at-
## alternating-ROT loop. Preceded by GOSUB 4100 in the source (line
## 1100's own first call, before its two bare CALL SG), so this is the
## NOISE_HEAVY preset -- found and fixed 2026-11-09, this previously
## played NOISE_MEDIUM (the bare-CALL-SG convention used elsewhere in
## this project, which doesn't apply here since line 1100 explicitly
## sets the heavy preset first).
func start_miss() -> void:
	_kill_tweens()
	AudioManager.play_hit_heavy()
	var rot_deg := 25.0 * 360.0 / 255.0
	_approach.configure(table, 2)

	# Two independent Tweens running concurrently (not Tween.set_parallel,
	# which only pairs each new Tweener with the one immediately before
	# it -- not what a 4-cycle oscillation alongside a single long scale
	# tween needs) so the shrink and the rock genuinely overlap.
	_tween = create_tween()
	_tween.tween_property(_approach, "scale", Vector2(0.1, 0.1), 0.8)
	_tween.tween_callback(func() -> void:
		_approach.visible = false
		miss_finished.emit()
	)

	_rot_tween = create_tween()
	for i in range(4):
		_rot_tween.tween_property(_approach, "rotation_degrees", rot_deg, 0.1)
		_rot_tween.tween_property(_approach, "rotation_degrees", 0.0, 0.1)

## Lines 1200-1222: SCALE 1 then 2 flash on shape 2, then shapes 15-18
## stamped together at the same anchor point -- the doc's own read of
## those four shapes is that they're scattered debris fragments, not a
## tidy radial starburst, so they're shown together rather than in
## sequence; the flash and the simultaneous overlay carry the effect.
## Same GOSUB-4100-before-CALL-SG precedence as start_miss() above --
## NOISE_HEAVY, fixed 2026-11-09 (was NOISE_MEDIUM).
func start_hit() -> void:
	_kill_tweens()
	AudioManager.play_hit_heavy()
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
		hit_finished.emit()
	)
