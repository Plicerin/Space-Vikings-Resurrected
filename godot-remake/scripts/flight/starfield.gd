extends MultiMeshInstance3D
## Placeholder for the "A2-3D1 engine runs every frame during normal
## flight" finding in FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md
## (SPACE SIMULATOR ASSEMBLY's FUN_921e calls straight into the 3D
## engine's entry point once per frame; what it actually draws there —
## almost certainly a starfield, given the engine's "transform and plot
## a point" primitive is a natural fit — was never independently
## confirmed). Godot's own MultiMesh replaces whatever that call
## actually did; this does not attempt to reproduce the original's
## bytecode-driven point transform, consistent with the decision that
## A2-3D1's internals don't need to survive the port.

@export var star_count: int = 800
@export var field_radius: float = 6000.0


func _ready() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4, 4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = star_count
	for i in range(star_count):
		var pos := Vector3(
			randf_range(-field_radius, field_radius),
			randf_range(-field_radius, field_radius),
			randf_range(-field_radius, field_radius)
		)
		mm.set_instance_transform(i, Transform3D(Basis(), pos))
	multimesh = mm
