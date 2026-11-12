extends RefCounted
## The cities on a planet's ground, the manual's "cities and other targets" to
## "hit with your missiles and laser fire" from the atmosphere ("softening up a
## planet before dispatching your troops"): clusters of buildings on a patch of
## paved ground, standing on land (scripts/world/terrain.gd), as many as the
## planet's technology allows. A strike near one burns it. The rules do not
## know of them (a hit on the ground counts for the planet whether it is a city
## or open ground, as in the original); they are what the strikes are aimed at.


const COUNTS := [0, 0, 12, 26, 44] ## by technology
const SPREAD := 17000.0
const SPACING := 2300.0
const CITY_RADIUS := 230.0

var sites: Array[Vector3] = []
var burning: Array[bool] = []
var _nodes: Array[Node3D] = []
var _bodies: Array[MultiMeshInstance3D] = []
var _pads: Array[MeshInstance3D] = []


## Takes the cities down (the ground has changed under them).
func clear() -> void:
	for node in _nodes:
		node.queue_free()
	sites.clear()
	burning.clear()
	_nodes.clear()
	_bodies.clear()
	_pads.clear()


## Puts the cities of the planet with map `terrain` and technology `tech` under `parent`.
func build(parent: Node3D, terrain: RefCounted, tech: int) -> void:
	var want: int = COUNTS[clampi(tech, 0, COUNTS.size() - 1)]
	if want == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(terrain.map_seed * 7919.0) + 11
	var candidates: Array[Vector2] = []
	var cell := -SPREAD
	while cell < SPREAD:
		var row := -SPREAD
		while row < SPREAD:
			var at := Vector2(cell + rng.randf() * SPACING, row + rng.randf() * SPACING)
			if terrain.is_building_land(at) and at.length() > 1500.0: # not on the planet's own landing ground
				candidates.append(at)
			row += SPACING
		cell += SPACING
	# a spread of them, not the first found
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var kept := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = kept
	for at in candidates.slice(0, want):
		_city(parent, at, rng)


func _city(parent: Node3D, at: Vector2, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = Vector3(at.x, 0.0, at.y)
	parent.add_child(root)
	# the paved ground
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = CITY_RADIUS * 1.15
	disc.bottom_radius = CITY_RADIUS * 1.15
	disc.height = 1.0
	disc.radial_segments = 20
	pad.mesh = disc
	pad.position.y = 1.2
	var pad_material := StandardMaterial3D.new()
	pad_material.albedo_color = Color(0.5, 0.49, 0.46)
	pad_material.roughness = 0.95
	pad.material_override = pad_material
	root.add_child(pad)
	# the buildings: boxes, tallest in the middle
	var count := rng.randi_range(40, 70)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	multi.mesh = box
	multi.instance_count = count
	for i in count:
		var spot := Vector2(rng.randfn(0.0, CITY_RADIUS * 0.42), rng.randfn(0.0, CITY_RADIUS * 0.42)).limit_length(CITY_RADIUS)
		var tall := lerpf(60.0, 12.0, spot.length() / CITY_RADIUS) * rng.randf_range(0.5, 1.3)
		var wide := rng.randf_range(14.0, 30.0)
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(wide, tall, rng.randf_range(14.0, 30.0))),
				Vector3(spot.x, 1.7 + tall / 2.0, spot.y)))
		var shade := rng.randf_range(0.62, 0.92)
		multi.set_instance_color(i, Color(shade, shade * 0.97, shade * 0.9))
	var body := MultiMeshInstance3D.new()
	body.multimesh = multi
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.8
	body.material_override = material
	root.add_child(body)
	sites.append(root.position)
	burning.append(false)
	_nodes.append(root)
	_bodies.append(body)
	_pads.append(pad)


## A strike at `at` with a blast `radius` wide: the nearest city it reaches is
## burned, its buildings black rubble. Returns that city's number, or -1.
func hit(at: Vector3, radius: float) -> int:
	var best := -1
	var near := INF
	for i in sites.size():
		var gap := Vector2(sites[i].x - at.x, sites[i].z - at.z).length()
		if gap < CITY_RADIUS + radius and gap < near and not burning[i]:
			near = gap
			best = i
	if best < 0:
		return -1
	burning[best] = true
	var multi := _bodies[best].multimesh
	for i in multi.instance_count:
		var t := multi.get_instance_transform(i)
		t.basis = t.basis.scaled(Vector3(1.0, 0.25, 1.0))
		t.origin.y = 1.7 + t.basis.get_scale().y / 2.0
		multi.set_instance_transform(i, t)
		multi.set_instance_color(i, Color(0.08, 0.07, 0.06))
	(_pads[best].material_override as StandardMaterial3D).albedo_color = Color(0.16, 0.14, 0.12)
	return best
