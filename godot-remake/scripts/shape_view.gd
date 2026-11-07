extends Node2D

## Renders a converted Apple II shape-table file (see
## modern/shapes_json/*.payload.json in the main repo) as plain
## lines and dots. One shape = one subpath list; a "move" command
## starts a new subpath (pen up), a "line" command extends the
## current one (pen down). Shapes with no path_commands and a
## single point are drawn as dots (texture/crater detail).

@export_file("*.json") var shape_file_path: String = "res://assets/shapes/PLANET no 0.payload.json"
## -1 draws every shape in the file overlaid at its own origin (noisy —
## Apple II shape tables are usually a set of independently-drawn
## elements, not pieces of one combined image). >= 0 draws only that
## shape index, which is what you want for checking one shape at a time.
@export var shape_index: int = 0
@export var scale_factor: float = 3.0
@export var stroke_color: Color = Color.WHITE
@export var stroke_width: float = 1.0
@export var dot_radius: float = 1.5
@export var flip_y: bool = false

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")

var _table: ShapeTable
var _subpaths: Array[PackedVector2Array] = []
var _dots: Array[Vector2] = []

func _ready() -> void:
	_load_shapes()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	var shape_count: int = _table.shape_count if _table else 0
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		shape_index = (max(shape_index, 0) + 1) % max(shape_count, 1)
		_load_shapes()
		queue_redraw()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		shape_index = (max(shape_index, 0) - 1 + shape_count) % max(shape_count, 1)
		_load_shapes()
		queue_redraw()

func _to_local(p: Vector2) -> Vector2:
	var yy := -p.y if flip_y else p.y
	return Vector2(p.x, yy) * scale_factor

func _load_shapes() -> void:
	_subpaths.clear()
	_dots.clear()

	_table = ShapeTable.new()
	_table.load_shapes(shape_file_path)
	if _table.shape_count == 0:
		return

	var indices: Array[int] = []
	if shape_index >= 0:
		indices.append(shape_index)
	else:
		for i in range(_table.shape_count):
			indices.append(i)

	for i in indices:
		for subpath in _table.get_subpaths(i):
			var local_subpath := PackedVector2Array()
			for p in subpath:
				local_subpath.append(_to_local(p))
			_subpaths.append(local_subpath)
		for dot in _table.get_dots(i):
			_dots.append(_to_local(dot))

func _draw() -> void:
	for subpath in _subpaths:
		draw_polyline(subpath, stroke_color, stroke_width)
	for dot in _dots:
		draw_circle(dot, dot_radius, stroke_color)

	var shape_count: int = _table.shape_count if _table else 0
	var label := "%s — shape %d/%d (←/→ to cycle)" % [shape_file_path.get_file(), shape_index, shape_count - 1]
	draw_string(ThemeDB.fallback_font, Vector2(-150, -120), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

## Swap in a different converted shape file at runtime and redraw.
func load_shape_file(path: String) -> void:
	shape_file_path = path
	_load_shapes()
	queue_redraw()
