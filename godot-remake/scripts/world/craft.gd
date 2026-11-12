extends RefCounted
## The low-poly craft of the game, flat shaded.

const Ships = preload("res://scripts/world/ships.gd")

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


## A fighter, nose along -z, about three units long, in three surfaces:
## 0 the hull (painted by vertex colour: grey, with a red stripe on the
## wings and tail), 1 the canopy, 2 the engine nozzles' glow. A hexagonal
## fuselage drawn out to a nose spike, swept wings with a cannon at each tip,
## two engine pods and a V tail.
static func fighter() -> ArrayMesh:
	var grey := Color(0.88, 0.9, 0.94)
	var dark := Color(0.38, 0.40, 0.44)
	var red := Color(0.86, 0.2, 0.16)
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	hull.set_smooth_group(-1)
	# the fuselage: rings along z, each a flattened hexagon
	var rings := [[-1.9, 0.0], [-1.45, 0.10], [-0.8, 0.26], [0.1, 0.32], [0.8, 0.30], [1.15, 0.22]]
	var sides := 6
	for i in rings.size() - 1:
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var r0: float = rings[i][1]
			var r1: float = rings[i + 1][1]
			var z0: float = rings[i][0]
			var z1: float = rings[i + 1][0]
			var p00 := Vector3(cos(a0) * r0, sin(a0) * r0 * 0.7, z0)
			var p01 := Vector3(cos(a1) * r0, sin(a1) * r0 * 0.7, z0)
			var p10 := Vector3(cos(a0) * r1, sin(a0) * r1 * 0.7, z1)
			var p11 := Vector3(cos(a1) * r1, sin(a1) * r1 * 0.7, z1)
			var colour := dark if i == 0 else grey
			_tri(hull, p00, p10, p01, colour)
			if r0 > 0.0:
				_tri(hull, p01, p10, p11, colour)
			else:
				_tri(hull, p01, p10, p11, colour)
	# the wings: a flat wedge each side, top and bottom, the outer part striped
	for side in [-1.0, 1.0]:
		var root_front := Vector3(side * 0.28, 0.0, -0.55)
		var root_back := Vector3(side * 0.28, 0.0, 0.85)
		var mid_front := Vector3(side * 1.05, -0.03, 0.05)
		var mid_back := Vector3(side * 1.0, -0.03, 0.95)
		var tip_front := Vector3(side * 1.85, -0.07, 0.75)
		var tip_back := Vector3(side * 1.6, -0.07, 1.05)
		for lift in [0.035, -0.035]:
			var up := Vector3(0.0, lift, 0.0)
			var flip: bool = (lift < 0.0) != (side < 0.0)
			_quad(hull, root_front + up, mid_front + up, mid_back + up, root_back + up, grey, flip)
			_quad(hull, mid_front + up, tip_front + up, tip_back + up, mid_back + up, red, flip)
		# a cannon at the tip, a thin hexagonal barrel reaching forward
		_barrel(hull, Vector3(side * 1.78, -0.07, 0.75), Vector3(side * 1.78, -0.07, 0.1), 0.045, dark)
	# the engine pods
	for side in [-1.0, 1.0]:
		_barrel(hull, Vector3(side * 0.42, -0.02, 0.2), Vector3(side * 0.42, -0.02, 1.3), 0.15, dark)
	# the V tail: a fin each side, leaning out
	for side in [-1.0, 1.0]:
		var base_front := Vector3(side * 0.08, 0.2, 0.6)
		var base_back := Vector3(side * 0.12, 0.18, 1.15)
		var top_front := Vector3(side * 0.42, 0.78, 1.0)
		var top_back := Vector3(side * 0.42, 0.78, 1.25)
		_quad(hull, base_front, top_front, top_back, base_back, red, side > 0.0)
		_quad(hull, base_front, top_front, top_back, base_back, red, side < 0.0)
	hull.generate_normals()
	var mesh := hull.commit()
	# the canopy: a half ellipsoid on the fuselage
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	glass.set_smooth_group(-1)
	var bands := 4
	var around := 8
	for i in bands:
		for k in around:
			var t0 := PI / 2.0 * i / bands
			var t1 := PI / 2.0 * (i + 1) / bands
			var a0 := TAU * k / around
			var a1 := TAU * (k + 1) / around
			var q00 := _canopy_point(t0, a0)
			var q01 := _canopy_point(t0, a1)
			var q10 := _canopy_point(t1, a0)
			var q11 := _canopy_point(t1, a1)
			_tri(glass, q00, q10, q01, Color.WHITE)
			_tri(glass, q01, q10, q11, Color.WHITE)
	glass.generate_normals()
	glass.commit(mesh)
	# the nozzles' glow: a disc behind each engine
	var glow := SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var centre := Vector3(side * 0.42, -0.02, 1.31)
		for k in 8:
			var a0 := TAU * k / 8.0
			var a1 := TAU * (k + 1) / 8.0
			_tri(glow, centre, centre + Vector3(cos(a0), sin(a0), 0.0) * 0.12, centre + Vector3(cos(a1), sin(a1), 0.0) * 0.12, Color.WHITE)
	glow.generate_normals()
	glow.commit(mesh)
	return mesh


## The materials of Craft.fighter()'s three surfaces: hull, canopy, nozzles.
static func fighter_materials() -> Array[Material]:
	var hull := StandardMaterial3D.new()
	hull.vertex_color_use_as_albedo = true
	hull.metallic = 0.3
	hull.roughness = 0.42
	hull.cull_mode = BaseMaterial3D.CULL_DISABLED
	var canopy := StandardMaterial3D.new()
	canopy.albedo_color = Color(0.25, 0.55, 0.9, 0.85)
	canopy.emission_enabled = true
	canopy.emission = Color(0.1, 0.35, 0.8)
	canopy.emission_energy_multiplier = 0.8
	canopy.metallic = 0.3
	canopy.roughness = 0.1
	canopy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var nozzle := StandardMaterial3D.new()
	nozzle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nozzle.albedo_color = Color(1.0, 0.7, 0.3)
	nozzle.cull_mode = BaseMaterial3D.CULL_DISABLED
	return [hull, canopy, nozzle]


static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	for vertex in [a, b, c]:
		tool.set_color(colour)
		tool.add_vertex(vertex)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color, flip := false) -> void:
	if flip:
		_tri(tool, a, c, b, colour)
		_tri(tool, a, d, c, colour)
	else:
		_tri(tool, a, b, c, colour)
		_tri(tool, a, c, d, colour)


## A hexagonal barrel from `from` to `to`.
static func _barrel(tool: SurfaceTool, from: Vector3, to: Vector3, radius: float, colour: Color) -> void:
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		var o0 := Vector3(cos(a0), sin(a0), 0.0) * radius
		var o1 := Vector3(cos(a1), sin(a1), 0.0) * radius
		_quad(tool, from + o0, from + o1, to + o1, to + o0, colour)


static func _canopy_point(t: float, a: float) -> Vector3:
	return Vector3(cos(a) * cos(t) * 0.17, 0.12 + sin(t) * 0.2, -0.55 + sin(a) * cos(t) * 0.5)


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


## The model of the defender of type `tier` (ORBIT.bas line 31: a type 2 has no ship of its own and is the
## light cruiser), or null: scripts/world/ships.gd builds them clean, in the style of the originals' wireframes.
static func defender(tier: int) -> Mesh:
	return Ships.ship(tier)


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
