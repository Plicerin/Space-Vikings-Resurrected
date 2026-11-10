extends MultiMeshInstance3D
## The "A2-3D1 engine runs every frame during normal flight" finding in
## FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md (SPACE SIMULATOR
## ASSEMBLY's FUN_921e calls straight into the 3D engine's entry point
## once per frame). Confirmed live 2026-11-09 (MAME screenshot +
## byte-exact $7300 memory dump, see A2-3D1_ENGINE_ANALYSIS.md): it's
## PLANET # 0, a static 195-point deep-space starfield (x/y/z each
## spanning -10000..10000) with zero connecting lines, resident at
## $7300 since boot.
##
## CORRECTION (2026-11-09, follow-up to a real playtest reporting "the
## planet is rendered twice"): this used to be a synthetic placeholder
## -- 800 random points in a generic +-6000 box, standing in for the
## finding above rather than using it. Meanwhile space_flight.gd
## separately loaded this SAME real PLANET # 0 data a second time and
## (mis)used it as a small foreground "planet" object positioned at the
## destination -- which is simply wrong, since this data isn't a planet
## at all, it's the ordinary-flight starfield itself, confirmed above.
## That's what actually produced "a tight inner cluster" next to "an
## outside scattering that's more box-like": two unrelated fields, one
## of them the real data misplaced. Fixed by giving this node the real
## data it was always meant to stand in for, and removing the duplicate
## use entirely -- see space_flight.gd's own doc comment for that half.
## Godot's own MultiMesh still does the actual per-point transform/
## render; this does not attempt to reproduce the original's bytecode-
## driven point plot, consistent with the decision that A2-3D1's
## internals don't need to survive the port.

const PLANET_MODEL_PATH := "res://assets/models/PLANET no 0.json"


func _ready() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4, 4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mat

	var points := _load_real_points()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in range(points.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), points[i]))
	multimesh = mm


## Loads PLANET # 0's own 195 real points directly, rather than going
## through a2_3d1_model.gd's build_planet_mesh() -- that helper
## re-centers and builds an ArrayMesh/radius pair for the camera-framing
## use case (a small foreground object), neither of which applies here:
## this field surrounds the viewer at its own real, already-centered
## scale, with each point rendered as its own billboard rather than one
## shared point-cloud surface.
func _load_real_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	var file := FileAccess.open(PLANET_MODEL_PATH, FileAccess.READ)
	if file == null:
		push_error("starfield.gd: could not open %s" % PLANET_MODEL_PATH)
		return points
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return points
	for seg in data.get("segments", []):
		if seg["type"] != "line":
			points.append(Vector3(seg["x"], seg["y"], seg["z"]))
	return points
