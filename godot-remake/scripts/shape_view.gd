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

var _subpaths: Array[PackedVector2Array] = []
var _dots: Array[Vector2] = []
var _shape_count: int = 0

func _ready() -> void:
	_load_shapes()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		shape_index = (max(shape_index, 0) + 1) % max(_shape_count, 1)
		_load_shapes()
		queue_redraw()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		shape_index = (max(shape_index, 0) - 1 + _shape_count) % max(_shape_count, 1)
		_load_shapes()
		queue_redraw()

func _to_local(x: float, y: float) -> Vector2:
	var yy := -y if flip_y else y
	return Vector2(x, yy) * scale_factor

func _load_shapes() -> void:
	_subpaths.clear()
	_dots.clear()

	var file := FileAccess.open(shape_file_path, FileAccess.READ)
	if file == null:
		push_error("ShapeView: could not open %s" % shape_file_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("shapes"):
		push_error("ShapeView: %s has no 'shapes' array" % shape_file_path)
		return

	_shape_count = parsed["shapes"].size()

	for shape in parsed["shapes"]:
		if shape_index >= 0 and shape.get("id", -1) != shape_index:
			continue
		var commands: Array = shape.get("path_commands", [])
		var points: Array = shape.get("points", [])

		if commands.is_empty():
			if points.size() == 1:
				_dots.append(_to_local(points[0][0], points[0][1]))
			elif points.size() > 1:
				# No explicit pen-state breakdown for this shape; the
				# converter emits one continuous polyline in that case.
				var subpath := PackedVector2Array()
				for p in points:
					subpath.append(_to_local(p[0], p[1]))
				_subpaths.append(subpath)
			continue

		var subpath := PackedVector2Array()
		for cmd in commands:
			var pt := _to_local(cmd["x"], cmd["y"])
			if cmd["type"] == "move":
				if subpath.size() > 1:
					_subpaths.append(subpath)
				subpath = PackedVector2Array([pt])
			else:
				subpath.append(pt)
		if subpath.size() > 1:
			_subpaths.append(subpath)

func _draw() -> void:
	for subpath in _subpaths:
		draw_polyline(subpath, stroke_color, stroke_width)
	for dot in _dots:
		draw_circle(dot, dot_radius, stroke_color)

	var label := "%s — shape %d/%d (←/→ to cycle)" % [shape_file_path.get_file(), shape_index, _shape_count - 1]
	draw_string(get_theme_default_font(), Vector2(-150, -120), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

## Swap in a different converted shape file at runtime and redraw.
func load_shape_file(path: String) -> void:
	shape_file_path = path
	_load_shapes()
	queue_redraw()
