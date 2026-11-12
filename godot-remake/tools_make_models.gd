extends SceneTree
## The game's ships as low-poly solids. The original's SHIP # n files are
## wireframes: lines between corners, built of boxes and wedges (the lines
## are all real: a start point only begins one, a continue point and a ray
## draw, as the A2-3D1 manual has it). This fills them in: every closed,
## roughly flat loop of three to eight lines becomes a face, flat shaded;
## a line that runs close beside another, with nothing between, gets the
## panel that closes the gap (a thin hull drawn as two sides); a line left
## in no face stays a thin strut. The
## models are centred on the original's place for the defender, in Godot's
## world (z reversed), in the original's units.
##
##   godot --headless --path godot-remake -s res://tools_make_models.gd
##
## Writes assets/models/<name>.res, which the game loads and an artist can
## replace.

const DisplayList = preload("res://scripts/world/display_list.gd")

const MODELS := ["ship_1", "ship_3", "ship_4"]
const OUT := "res://assets/models/"
## How far from a plane a corner of a face may be, in the original's units.
const FLAT := 10.0
## The most lines in a loop that is made a face.
const MAX_LOOP := 8
const STRUT := 3.0
## How far apart the two sides of a slab may be, in the original's units.
const SLAB := 25.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for name in MODELS:
		_make(name)
	quit(0)


func _make(name: String) -> void:
	var list = DisplayList.load_file(name + ".bin")
	var lines: PackedVector3Array = list.lines
	# corners and the lines between them
	var corners: Array[Vector3] = []
	var index := {}
	var adjacent := {}
	var edges := {}
	for i in range(0, lines.size(), 2):
		var pair := []
		for end in [lines[i], lines[i + 1]]:
			if not index.has(end):
				index[end] = corners.size()
				corners.append(end)
				adjacent[index[end]] = {}
			pair.append(index[end])
		if pair[0] != pair[1]:
			adjacent[pair[0]][pair[1]] = true
			adjacent[pair[1]][pair[0]] = true
			edges[Vector2i(mini(pair[0], pair[1]), maxi(pair[0], pair[1]))] = true
	var faces := _faces(corners, adjacent)
	var covered := {}
	for face: Array in faces:
		for k in face.size():
			var a: int = face[k]
			var b: int = face[(k + 1) % face.size()]
			covered[Vector2i(mini(a, b), maxi(a, b))] = true
	_close_gaps(corners, edges, faces, covered)
	# centre: the middle of the corners, taken to the model's own origin
	var lo := corners[0]
	var hi := corners[0]
	for c in corners:
		lo = lo.min(c)
		hi = hi.max(c)
	var centre := (lo + hi) / 2.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for face: Array in faces:
		for k in range(1, face.size() - 1):
			for corner in [face[0], face[k], face[k + 1]]:
				tool.add_vertex(_place(corners[corner] - centre))
	tool.generate_normals()
	var mesh := tool.commit()
	# struts: lines in no face, as thin boxes
	var struts := SurfaceTool.new()
	struts.begin(Mesh.PRIMITIVE_TRIANGLES)
	struts.set_smooth_group(-1)
	var loose := 0
	for edge: Vector2i in edges:
		if covered.has(edge):
			continue
		loose += 1
		_strut(struts, _place(corners[edge.x] - centre), _place(corners[edge.y] - centre))
	if loose > 0:
		struts.generate_normals()
		struts.commit(mesh)
	ResourceSaver.save(mesh, OUT + name + ".res")
	print("%s: %d corners, %d lines, %d faces, %d struts, %d x %d x %d" % [name, corners.size(), edges.size(), faces.size(), loose,
			int(hi.x - lo.x), int(hi.y - lo.y), int(hi.z - lo.z)])


## A wireframe of a thin solid has the two sides of a slab drawn as separate lines, a few units
## apart, with nothing between them: from the side the hull is a slit. Where a line that is in no
## face runs side by side with another, close to it, with its ends close to the other's, the gap
## between them is a panel.
func _close_gaps(corners: Array[Vector3], edges: Dictionary, faces: Array, covered: Dictionary) -> void:
	var uses := {}
	for face: Array in faces:
		for k in face.size():
			var a: int = face[k]
			var b: int = face[(k + 1) % face.size()]
			var key := Vector2i(mini(a, b), maxi(a, b))
			uses[key] = int(uses.get(key, 0)) + 1
	var all: Array[Vector2i] = []
	for edge: Vector2i in edges:
		all.append(edge)
	for i in all.size():
		for j in range(i + 1, all.size()):
			var e: Vector2i = all[i]
			var f: Vector2i = all[j]
			if int(uses.get(e, 0)) > 0 and int(uses.get(f, 0)) > 0:
				continue # both are the edge of a face already: only a loose line wants a panel
			if e.x == f.x or e.x == f.y or e.y == f.x or e.y == f.y:
				continue # they meet: that is a corner, not a slab
			var quad := _slab(corners, e, f)
			if quad.is_empty() or _has_face(faces, quad):
				continue
			faces.append(quad)
			for k in 4:
				var a: int = quad[k]
				var b: int = quad[(k + 1) % 4]
				covered[Vector2i(mini(a, b), maxi(a, b))] = true


## The four corners of the panel between two lines that run side by side, or none.
func _slab(corners: Array[Vector3], e: Vector2i, f: Vector2i) -> Array:
	var ea := corners[e.x]
	var eb := corners[e.y]
	var fa := corners[f.x]
	var fb := corners[f.y]
	var along := eb - ea
	if along.length() < 1.0 or (fb - fa).length() < 1.0:
		return []
	if absf(along.normalized().dot((fb - fa).normalized())) < 0.995:
		return [] # not side by side
	var straight := ea.distance_to(fa) <= SLAB and eb.distance_to(fb) <= SLAB
	var crossed := ea.distance_to(fb) <= SLAB and eb.distance_to(fa) <= SLAB
	if not straight and not crossed:
		return []
	return [e.x, e.y, f.x, f.y] if crossed else [e.x, e.y, f.y, f.x]


func _has_face(faces: Array, quad: Array) -> bool:
	var key := quad.duplicate()
	key.sort()
	for face: Array in faces:
		if face.size() == 4:
			var other := face.duplicate()
			other.sort()
			if other == key:
				return true
	return false


## Godot's z is the original's reversed.
func _place(v: Vector3) -> Vector3:
	return Vector3(v.x, v.y, -v.z)


## The closed flat loops of three to six lines with no line across them.
func _faces(corners: Array[Vector3], adjacent: Dictionary) -> Array:
	var seen := {}
	var faces: Array = []
	for start: int in adjacent:
		_walk([start], adjacent, corners, seen, faces)
	return faces


func _walk(path: Array, adjacent: Dictionary, corners: Array[Vector3], seen: Dictionary, faces: Array) -> void:
	var last: int = path[-1]
	for next: int in adjacent[last]:
		if next == path[0] and path.size() >= 3:
			_try_face(path, adjacent, corners, seen, faces)
		elif next > path[0] and not path.has(next) and path.size() < MAX_LOOP:
			path.append(next)
			_walk(path, adjacent, corners, seen, faces)
			path.pop_back()


func _try_face(path: Array, adjacent: Dictionary, corners: Array[Vector3], seen: Dictionary, faces: Array) -> void:
	var key := path.duplicate()
	key.sort()
	if seen.has(str(key)) or path[1] > path[-1]:
		return # the loop the other way round, or already found
	# flat: every corner in the plane of the first three
	var normal := (corners[path[1]] - corners[path[0]]).cross(corners[path[2]] - corners[path[0]])
	if normal.length() < 0.001:
		return
	normal = normal.normalized()
	for corner: int in path:
		if absf((corners[corner] - corners[path[0]]).dot(normal)) > FLAT:
			return
	# no line across it (a chord means two smaller faces)
	for i in path.size():
		for j in range(i + 2, path.size()):
			if i == 0 and j == path.size() - 1:
				continue
			if adjacent[path[i]].has(path[j]):
				return
	seen[str(key)] = true
	faces.append(path.duplicate())


func _strut(tool: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP)
	if side.length() < 0.1:
		side = along.cross(Vector3.RIGHT)
	side = side.normalized() * STRUT / 2.0
	var up := along.cross(side).normalized() * STRUT / 2.0
	var ring_a := [a + side + up, a - side + up, a - side - up, a + side - up]
	var ring_b := [b + side + up, b - side + up, b - side - up, b + side - up]
	for k in 4:
		var n := (k + 1) % 4
		for vertex in [ring_a[k], ring_a[n], ring_b[n], ring_a[k], ring_b[n], ring_b[k]]:
			tool.add_vertex(vertex)
