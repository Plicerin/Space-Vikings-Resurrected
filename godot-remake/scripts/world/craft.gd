extends RefCounted
## The low-poly craft of the game, flat shaded. Placeholders until the
## originals' own shapes (assets/a2_3d1/ship_*.bin) are made into models.

## A swept craft in eight triangles, nose along -z (ahead in Godot).
static func mesh() -> ArrayMesh:
	var nose := Vector3(0, 0, -3)
	var left := Vector3(-2.2, 0, 1.6)
	var right := Vector3(2.2, 0, 1.6)
	var top := Vector3(0, 0.9, 1.0)
	var bottom := Vector3(0, -0.6, 1.0)
	var tail := Vector3(0, 0, 2.2)
	var faces := [
		[nose, left, top], [nose, top, right], [nose, bottom, left], [nose, right, bottom],
		[left, tail, top], [top, tail, right], [left, bottom, tail], [bottom, right, tail],
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1) # flat: each face by itself, as the original's polygons are
	for face: Array in faces:
		for vertex: Vector3 in face:
			tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()


static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.5
	m.roughness = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


const MODELS := "res://assets/models/"
## Which of the game's ships a defender of each type is (ORBIT.bas line 31:
## a type 2 has no ship of its own and is the light cruiser).
const DEFENDER_MODEL := {1: "ship_1", 2: "ship_3", 3: "ship_3", 4: "ship_4"}


## The model of the defender of type `tier`, or null.
static func defender(tier: int) -> Mesh:
	if not DEFENDER_MODEL.has(tier):
		return null
	return load(MODELS + DEFENDER_MODEL[tier] + ".res") as Mesh


## A rough rock for wreckage: eight faces.
static func rock() -> ArrayMesh:
	var top := Vector3(0, 1, 0)
	var bottom := Vector3(0, -1, 0)
	var ring := [Vector3(1, 0.1, 0.2), Vector3(0.1, -0.1, 1), Vector3(-1, 0.2, 0.1), Vector3(-0.2, 0, -1)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		for vertex in [top, a, b, bottom, b, a]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()
