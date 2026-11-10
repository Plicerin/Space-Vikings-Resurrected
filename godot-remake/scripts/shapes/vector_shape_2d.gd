extends Node2D
## Draws one shape (by index) from a ShapeTable at this node's position —
## the idiomatic replacement for an Apple II `XDRAW shape AT x,y`. Unlike
## the original's XOR-toggle erase/redraw, visibility is just `visible`;
## HGRCanvas (the parent space) supplies the pixel-coordinate scale, so
## positions and shape indices here are the same numbers the BASIC source
## uses.
##
## No `class_name` (see shape_table.gd) — callers preload this script
## into a local `VectorShape2D` const.

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")

@export var color: Color = Color.WHITE
@export var stroke_width: float = 1.0
@export var dot_radius: float = 1.0

var table: ShapeTable
var shape_index: int = 0:
	set(value):
		shape_index = value
		queue_redraw()

## Set both at once so there's exactly one redraw, not one per field.
func configure(new_table: ShapeTable, new_index: int) -> void:
	table = new_table
	shape_index = new_index

## Fixed 2026-11-09, found while chasing a real playtest report that the
## missile-strike approach sprite "doesn't look like a sprite": many
## real decoded shapes (the ENEMY table's shape 3 is the case that
## surfaced this) are built from the Apple II source as runs of single
## plot-then-lift vectors -- a decoded subpath of just two IDENTICAL
## points (a true zero-length segment) every time the pen lifts after
## one step, confirmed directly against the decoded JSON. `draw_polyline`
## renders a zero-length segment as literally nothing (no round line
## caps in Godot's 2D polyline drawing), so the majority of a shape like
## that was silently invisible -- not a decode error, a renderer gap.
## Plotting a small circle at every vertex (not just true "dots" shapes)
## gives every segment, degenerate or not, a visible mark, same as a
## round line-cap would.
func _draw() -> void:
	if table == null:
		return
	for subpath in table.get_subpaths(shape_index):
		draw_polyline(subpath, color, stroke_width)
		for point in subpath:
			draw_circle(point, stroke_width * 0.5, color)
	for dot in table.get_dots(shape_index):
		draw_circle(dot, dot_radius, color)
