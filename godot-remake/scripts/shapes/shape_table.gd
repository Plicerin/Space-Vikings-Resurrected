extends RefCounted
## Loads a converted Apple II shape-table JSON file (see
## modern/shapes_json/*.payload.json in the main repo) and exposes each
## shape's geometry pre-parsed into drawable Godot primitives. Shared by
## scripts/shape_view.gd (the debug viewer) and the combat VFX scripts —
## written once here so both read the exact same path-command/pen-state
## logic rather than duplicating it.
##
## Deliberately no `class_name` — that requires Godot's global script-
## class cache, which only exists after the project has been opened once
## in the full editor (not guaranteed on a fresh clone run straight from
## the command line). Callers `preload()` this script into a local
## `ShapeTable` const instead; see scripts/shape_view.gd for the pattern.

var shape_count: int = 0
var _subpaths_by_shape: Dictionary = {} # int -> Array[PackedVector2Array]
var _dots_by_shape: Dictionary = {} # int -> Array[Vector2]

## Instance method, not a static factory — a static factory would need to
## self-reference this script's own type, which needs either class_name
## or a self-preload, both more trouble than they're worth here.
func load_shapes(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ShapeTable: could not open %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("shapes"):
		push_error("ShapeTable: %s has no 'shapes' array" % path)
		return

	var shapes: Array = parsed["shapes"]
	shape_count = shapes.size()

	for shape in shapes:
		var id: int = shape.get("id", -1)
		var commands: Array = shape.get("path_commands", [])
		var points: Array = shape.get("points", [])
		var subpaths: Array[PackedVector2Array] = []
		var dots: Array[Vector2] = []

		if commands.is_empty():
			# tools/shape_table_decoder.py always populates path_commands
			# now (possibly empty) — empty here means this shape's cursor
			# never actually plots a pixel, not "no pen-state breakdown
			# available" (a quirk of an earlier, wrong decoder, which this
			# used to work around by drawing a line through every visited
			# position regardless of whether it was ever plotted). Render
			# nothing for it, except a single debug dot for a totally
			# blank shape so the viewer can still tell "this index exists
			# but draws nothing" apart from "doesn't exist."
			if points.size() <= 1:
				dots.append(Vector2.ZERO)
		else:
			var subpath := PackedVector2Array()
			for cmd in commands:
				var pt := Vector2(cmd["x"], cmd["y"])
				if cmd["type"] == "move":
					if subpath.size() > 1:
						subpaths.append(subpath)
					subpath = PackedVector2Array([pt])
				else:
					subpath.append(pt)
			if subpath.size() > 1:
				subpaths.append(subpath)

		_subpaths_by_shape[id] = subpaths
		_dots_by_shape[id] = dots

## Clamps to the nearest valid index so a flip-book creep (e.g. fighter
## approach's M3 += .32) never reads past the table's real shape count.
func clamp_index(index: int) -> int:
	return clampi(index, 0, max(shape_count - 1, 0))

func get_subpaths(index: int) -> Array[PackedVector2Array]:
	if _subpaths_by_shape.has(index):
		return _subpaths_by_shape[index]
	return [] as Array[PackedVector2Array]

func get_dots(index: int) -> Array[Vector2]:
	if _dots_by_shape.has(index):
		return _dots_by_shape[index]
	return [] as Array[Vector2]
