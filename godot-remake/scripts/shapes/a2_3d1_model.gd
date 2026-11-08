extends RefCounted
## Loader for the real A2-3D1 3D-engine bytecode models (SHIP # N,
## PLANET # N), pre-decoded to JSON by tools/a2_3d1_model_decoder.py /
## tools/extract_planets.py. Distinct from shape_table.gd, which is the
## *other*, Applesoft-style format used by ENEMY/EXPL -- these are
## genuinely different binary formats, confirmed live in MAME; see
## A2-3D1_ENGINE_ANALYSIS.md's "Resolved 2026-11-07" sections. No
## class_name, per this project's convention -- see godot-remake/README.md.

const SHIP_MODEL_PATHS := {
	0: "res://assets/models/SHIP no 0.json",
	1: "res://assets/models/SHIP no 1.json",
	3: "res://assets/models/SHIP no 3.json",
	4: "res://assets/models/SHIP no 4.json",
}

const PLANET_MODEL_PATH_FORMAT := "res://assets/models/PLANET no %d.json"

# Real HGR screen-pixel scale (280x192) -- these models were authored in
# the same world-space the flight sim uses for everything else, so a
# too-small point size reads as near-invisible at the distances
# space_flight.tscn's camera actually sits at.
const POINT_SIZE := 6.0


## Loads one SHIP # N model by tier (0/1/3/4 -- the real
## PEEK(38205)/ET values, see GameState.planet_orbital_defender_tier)
## and returns {"mesh": ArrayMesh, "radius": float}. Returns an empty
## mesh (0 vertices, radius 0) for tier 0, which is correct: the
## unarmed station genuinely has no ship model, confirmed against the
## real disk data -- not a loading failure.
static func build_ship_mesh(tier: int) -> Dictionary:
	return build_model_mesh(SHIP_MODEL_PATHS.get(tier, ""))


## Loads PLANET # n and returns {"mesh": ArrayMesh, "radius": float}.
## PLANET # 0 (ORBIT.bas's deep-space orbital-insertion view) is a
## 195-point field with zero connecting lines -- real geometry, no
## surface, by design (see A2-3D1_ENGINE_ANALYSIS.md's "Planet
## point-field" section). PLANET # 1-20 (RE.bas's re-entry view,
## selected by PEEK(38209)) are genuinely modeled, line-connected
## terrain maps instead -- a different kind of visual, not just a
## bigger version of # 0.
static func build_planet_mesh(planet_index: int) -> Dictionary:
	return build_model_mesh(PLANET_MODEL_PATH_FORMAT % planet_index)


## Loads one model's JSON and returns {"mesh": ArrayMesh, "radius": float}
## using Mesh.PRIMITIVE_LINES for connected segments and
## Mesh.PRIMITIVE_POINTS for isolated vertices (as up to two surfaces on
## the same mesh -- several real files mix both, e.g. PLANET # 9/# 13),
## so Godot's own renderer does the actual 3D transform/projection work
## -- the original's A2-3D1 engine (hand-rolled rotate/clip/perspective-
## divide in 6502) is intentionally not ported; see the "What's real vs.
## stubbed" table in README.md for why.
##
## The model is re-centered on its own bounding-box center: the raw
## coordinates sit far from the origin (e.g. SHIP # 1 clusters around
## X=300-350, Z=-3500) because they're expressed in the original's
## world-space, not model-local space. "radius" is the bounding-sphere
## radius around that center, for the caller to frame a camera with --
## the real files span wildly different absolute sizes.
static func build_model_mesh(path: String) -> Dictionary:
	var mesh := ArrayMesh.new()
	if path == "" or not FileAccess.file_exists(path):
		return {"mesh": mesh, "radius": 0.0}

	var f := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null:
		return {"mesh": mesh, "radius": 0.0}

	var segments: Array = data.get("segments", [])
	if segments.is_empty():
		return {"mesh": mesh, "radius": 0.0}

	var bounds := _compute_bounds(segments)
	var center: Vector3 = bounds[0]
	var radius: float = bounds[1]

	var line_points := PackedVector3Array()
	var dot_points := PackedVector3Array()
	for seg in segments:
		if seg["type"] == "line":
			line_points.append(Vector3(seg["x1"], seg["y1"], seg["z1"]) - center)
			line_points.append(Vector3(seg["x2"], seg["y2"], seg["z2"]) - center)
		else:
			dot_points.append(Vector3(seg["x"], seg["y"], seg["z"]) - center)

	var unshaded_white := StandardMaterial3D.new()
	unshaded_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Matches the live MAME screenshots' blip color -- see
	# A2-3D1_ENGINE_ANALYSIS.md's "Live-verified" section.
	unshaded_white.albedo_color = Color.WHITE

	if not line_points.is_empty():
		var line_arrays := []
		line_arrays.resize(Mesh.ARRAY_MAX)
		line_arrays[Mesh.ARRAY_VERTEX] = line_points
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, unshaded_white)

	if not dot_points.is_empty():
		var dot_arrays := []
		dot_arrays.resize(Mesh.ARRAY_MAX)
		dot_arrays[Mesh.ARRAY_VERTEX] = dot_points
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, dot_arrays)
		var dot_mat := unshaded_white.duplicate() as StandardMaterial3D
		dot_mat.use_point_size = true
		dot_mat.point_size = POINT_SIZE
		mesh.surface_set_material(mesh.get_surface_count() - 1, dot_mat)

	return {"mesh": mesh, "radius": radius}


## Returns [center: Vector3, radius: float] — radius is the largest
## distance from center to any vertex (not just the bounding-box
## diagonal), so a long thin model doesn't under-frame the camera.
static func _compute_bounds(segments: Array) -> Array:
	var min_v := Vector3.INF
	var max_v := -Vector3.INF
	var all_pts: Array[Vector3] = []
	for seg in segments:
		var pts: Array[Vector3] = []
		if seg["type"] == "line":
			pts = [Vector3(seg["x1"], seg["y1"], seg["z1"]), Vector3(seg["x2"], seg["y2"], seg["z2"])]
		else:
			pts = [Vector3(seg["x"], seg["y"], seg["z"])]
		for p in pts:
			min_v = min_v.min(p)
			max_v = max_v.max(p)
			all_pts.append(p)
	var center := (min_v + max_v) * 0.5
	var radius := 0.0
	for p in all_pts:
		radius = max(radius, p.distance_to(center))
	return [center, radius]
