extends Node2D

## One-shot batch screenshot tool: renders every shape in one converted
## Apple II shape file, one shape per screenshot, then quits.
##
## Headless mode won't work for this — Godot's "headless" display driver
## only pairs with the no-op "dummy" renderer, so a screenshot taken under
## --headless would just be blank. Run this with a real rendering driver
## under an actual (even minimal) display session, e.g.:
##
##   cage -- godot --path godot-remake --rendering-driver opengl3 \
##     scenes/contact_sheet.tscn -- --file="PLANET no 0.payload.json"
##
## Optional args (after the `--`):
##   --file=<name>     shape file in assets/shapes/ (default: PLANET no 0.payload.json)
##   --outdir=<path>   absolute output directory (default: /tmp/godot_shape_screenshots)

@export var scale_factor: float = 3.0
@export var stroke_color: Color = Color.WHITE
@export var stroke_width: float = 1.0
@export var dot_radius: float = 1.5
@export var flip_y: bool = false

var _subpaths: Array[PackedVector2Array] = []
var _dots: Array[Vector2] = []
var _out_dir: String = "/tmp/godot_shape_screenshots"
var _file_name: String = "PLANET no 0.payload.json"
var _combined: bool = false

func _to_local(x: float, y: float) -> Vector2:
	var yy := -y if flip_y else y
	return Vector2(x, yy) * scale_factor

func _add_shape(shape: Dictionary) -> void:
	var commands: Array = shape.get("path_commands", [])
	var points: Array = shape.get("points", [])

	if commands.is_empty():
		if points.size() == 1:
			_dots.append(_to_local(points[0][0], points[0][1]))
		elif points.size() > 1:
			var subpath := PackedVector2Array()
			for p in points:
				subpath.append(_to_local(p[0], p[1]))
			_subpaths.append(subpath)
		return

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

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="):
			_out_dir = arg.substr("--outdir=".length())
		elif arg.begins_with("--file="):
			_file_name = arg.substr("--file=".length())
		elif arg == "--combined":
			_combined = true

	DirAccess.make_dir_recursive_absolute(_out_dir)
	position = get_viewport().get_visible_rect().size / 2.0

	var path := "res://assets/shapes/" + _file_name
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("contact_sheet: could not open %s" % path)
		get_tree().quit(1)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("shapes"):
		push_error("contact_sheet: %s has no 'shapes' array" % path)
		get_tree().quit(1)
		return

	var base_name := _file_name.replace(".payload.json", "")
	var shapes: Array = parsed["shapes"]
	print("contact_sheet: capturing %d shapes from %s into %s (combined=%s)" % [shapes.size(), _file_name, _out_dir, _combined])

	if _combined:
		_subpaths.clear()
		_dots.clear()
		for shape in shapes:
			_add_shape(shape)
		queue_redraw()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var out_path := "%s/%s_combined.png" % [_out_dir, base_name]
		img.save_png(out_path)
		print("  wrote %s" % out_path)
	else:
		for shape in shapes:
			_subpaths.clear()
			_dots.clear()
			_add_shape(shape)
			queue_redraw()
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var out_path := "%s/%s_shape_%02d.png" % [_out_dir, base_name, int(shape.get("id", 0))]
			img.save_png(out_path)
			print("  wrote %s" % out_path)

	print("contact_sheet: done")
	get_tree().quit()
