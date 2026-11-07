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

func _draw() -> void:
	if table == null:
		return
	for subpath in table.get_subpaths(shape_index):
		draw_polyline(subpath, color, stroke_width)
	for dot in table.get_dots(shape_index):
		draw_circle(dot, dot_radius, color)
