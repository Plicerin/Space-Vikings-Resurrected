extends Node2D
## `EX.bas` — the big "enemy ship destroyed" sequence, triggered in the
## original via `PRINT "RUNEX"` when an enemy's hull depletes
## (`STARSHIP SIMULATOR.bas` line 1560). A bigger, screen-centered version
## of the per-fighter hit explosion (same shape 2 flash + shapes 15-18),
## plus a genuine particle-style burst of random radiating lines (lines
## 7-10 of `EX.bas`, clamped to screen bounds), plus persistent wreckage
## left behind afterward. `CALL EX` is 75 calls to the same sound routine
## used everywhere else (`SG`, "sound gen") — not a distinct explosion
## sound, and not ported; sound is a separate task.
##
## Not wired to a hull/health system — none has been traced yet. Call
## `play()` directly to preview it (see the Start screen's combat demo).

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const VectorShape2D = preload("res://scripts/shapes/vector_shape_2d.gd")

signal finished

const CENTER := Vector2(140, 65)
const RADIATING_LINE_COUNT := 24
const RADIATING_LINE_LENGTH := 60.0
const SCREEN_BOUNDS := Rect2(0, 0, 280, 192)

var table: ShapeTable

@onready var _flash: VectorShape2D = $Flash
@onready var _debris: Array[VectorShape2D] = [$Debris15, $Debris16, $Debris17, $Debris18]
@onready var _wreckage: VectorShape2D = $Wreckage
@onready var _sparks: Node2D = $Sparks


func _ready() -> void:
	_flash.visible = false
	for d in _debris:
		d.visible = false
	_wreckage.visible = false


func play() -> void:
	_clear_sparks()
	_wreckage.visible = false

	_flash.position = CENTER
	_flash.scale = Vector2.ONE
	_flash.configure(table, 2)
	_flash.visible = true

	var tween := create_tween()
	tween.tween_property(_flash, "scale", Vector2(2.0, 2.0), 0.2)
	tween.tween_callback(func() -> void:
		_flash.visible = false
		for i in range(_debris.size()):
			_debris[i].position = CENTER
			_debris[i].scale = Vector2(2.0, 2.0)
			_debris[i].configure(table, 15 + i)
			_debris[i].visible = true
		_spawn_sparks()
	)
	tween.tween_interval(0.5)
	tween.tween_callback(func() -> void:
		for d in _debris:
			d.visible = false
		_clear_sparks()
		# EX.bas BLOADs the DEBRIS file here for persistent wreckage in the
		# next scene. DEBRIS's own shape data hasn't been decoded/confirmed
		# (see COMBAT_VFX_ANALYSIS.md's "EXPL: still an open question"), so
		# this reuses one of the already-decoded fighter-debris shapes as a
		# stand-in rather than inventing new geometry.
		_wreckage.position = CENTER
		_wreckage.scale = Vector2.ONE
		_wreckage.modulate.a = 0.5
		_wreckage.configure(table, 16)
		_wreckage.visible = true
		finished.emit()
	)


func _spawn_sparks() -> void:
	for i in range(RADIATING_LINE_COUNT):
		var angle := randf() * TAU
		var length := randf_range(10.0, RADIATING_LINE_LENGTH)
		var end := CENTER + Vector2.RIGHT.rotated(angle) * length
		end.x = clampf(end.x, SCREEN_BOUNDS.position.x, SCREEN_BOUNDS.end.x)
		end.y = clampf(end.y, SCREEN_BOUNDS.position.y, SCREEN_BOUNDS.end.y)
		var line := Line2D.new()
		line.add_point(CENTER)
		line.add_point(end)
		line.width = 1.0
		line.default_color = Color.WHITE
		_sparks.add_child(line)


func _clear_sparks() -> void:
	for child in _sparks.get_children():
		child.queue_free()
