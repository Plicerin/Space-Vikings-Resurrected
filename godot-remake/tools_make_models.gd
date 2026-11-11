extends SceneTree
## The game's ships as low-poly solids. The original's SHIP # n files are
## wireframes: lines between corners, built of boxes and wedges. This
## fills them in: every closed flat loop of three to six lines becomes a
## face, flat shaded; a line that is in no face stays a thin strut. The
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
const FLAT := 1.0
const STRUT := 3.0


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
		elif next > path[0] and not path.has(next) and path.size() < 6:
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
