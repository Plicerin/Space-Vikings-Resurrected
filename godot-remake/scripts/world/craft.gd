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


## A fighter: a slim fuselage, swept wings with fins on the tips, nose along -z,
## about three units long.
static func fighter() -> ArrayMesh:
	var nose := Vector3(0, 0, -1.8)
	var tail := Vector3(0, 0, 1.0)
	var up := Vector3(0, 0.28, 0.1)
	var down := Vector3(0, -0.22, 0.1)
	var left := Vector3(-0.36, 0, 0.2)
	var right := Vector3(0.36, 0, 0.2)
	var faces := [
		[nose, up, right], [nose, left, up], [nose, right, down], [nose, down, left],
		[tail, right, up], [tail, up, left], [tail, down, right], [tail, left, down],
		# the wings, swept back
		[Vector3(-0.3, 0, -0.4), Vector3(-1.7, -0.1, 0.9), Vector3(-0.3, 0, 0.8)],
		[Vector3(0.3, 0, -0.4), Vector3(0.3, 0, 0.8), Vector3(1.7, -0.1, 0.9)],
		# the fins on the wing tips
		[Vector3(-1.7, -0.1, 0.9), Vector3(-1.75, 0.55, 1.05), Vector3(-1.45, -0.05, 1.0)],
		[Vector3(1.7, -0.1, 0.9), Vector3(1.45, -0.05, 1.0), Vector3(1.75, 0.55, 1.05)],
		# the engine pods
		[Vector3(-0.45, 0.1, 0.3), Vector3(-0.3, -0.1, 0.3), Vector3(-0.38, 0.0, 1.15)],
		[Vector3(0.45, 0.1, 0.3), Vector3(0.38, 0.0, 1.15), Vector3(0.3, -0.1, 0.3)],
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for face: Array in faces:
		for vertex: Vector3 in face:
			tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()


## A missile: body, nose cone and four fins, nose along -z, about 1.6 units long.
static func missile() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var ring := 6
	for i in ring:
		var a0 := TAU * i / ring
		var a1 := TAU * (i + 1) / ring
		var front0 := Vector3(cos(a0) * 0.12, sin(a0) * 0.12, -0.4)
		var front1 := Vector3(cos(a1) * 0.12, sin(a1) * 0.12, -0.4)
		var back0 := Vector3(cos(a0) * 0.12, sin(a0) * 0.12, 0.7)
		var back1 := Vector3(cos(a1) * 0.12, sin(a1) * 0.12, 0.7)
		for vertex in [front0, back0, front1, front1, back0, back1]: # the body
			tool.add_vertex(vertex)
		for vertex in [Vector3(0, 0, -0.9), front1, front0]: # the nose cone
			tool.add_vertex(vertex)
	for i in 4:
		var angle := TAU * i / 4.0 + PI / 4.0
		var out := Vector3(cos(angle), sin(angle), 0.0)
		for vertex in [out * 0.12 + Vector3(0, 0, 0.35), out * 0.42 + Vector3(0, 0, 0.8), out * 0.12 + Vector3(0, 0, 0.8)]:
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
