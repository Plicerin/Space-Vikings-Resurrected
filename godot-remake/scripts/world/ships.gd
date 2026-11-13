extends RefCounted
## The defenders' ships, built clean from boxes and wedges in the style of the originals' wireframes
## (assets/a2_3d1/ship_1.bin, ship_3.bin, ship_4.bin): the same parts in the same places, with their
## sides closed. A part is a box, or a loft from one rectangle to another, or a few triangles; every
## coordinate below is the original's own (x along the ship, y up, z across, the ship about
## (400, -100, -3500)), and is moved to the middle of the ship and mirrored into Godot's world when it
## is made, so that the model is where the rules put the defender.

const MIDDLE := Vector3(400.0, -100.0, -3500.0)

static var _built := {}


## The ship of the defender of type `tier` (1 the small observatory, 2 and 3 the light cruiser, 4 the
## heavy cruiser), or null.
static func ship(tier: int) -> ArrayMesh:
	if not _built.has(tier):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_smooth_group(-1) # flat: each face by itself, as the original's polygons are
		match tier:
			1: _observatory(tool)
			2, 3: _light_cruiser(tool)
			4: _heavy_cruiser(tool)
			_: return null
		tool.generate_normals()
		_built[tier] = tool.commit()
	return _built[tier]


# --- the ships ------------------------------------------------------------------------


## The small space lab: a diamond-section nose, a body with side boxes, and a solar panel on a strut.
static func _observatory(tool: SurfaceTool) -> void:
	# the nose: a prism with a diamond for its end
	var front := [_g(300, -85, -3500), _g(300, -100, -3515), _g(300, -115, -3500), _g(300, -100, -3485)]
	var back := [_g(350, -85, -3500), _g(350, -100, -3515), _g(350, -115, -3500), _g(350, -100, -3485)]
	_loft(tool, front, back)
	_box(tool, 290, -105, -3505, 300, -95, -3495) # the sensor, with its rod
	_box(tool, 270, -101, -3501, 290, -99, -3499)
	_box(tool, 350, -125, -3525, 450, -75, -3475) # the body
	_box(tool, 450, -115, -3515, 460, -85, -3485) # the stern
	_box(tool, 460, -105, -3502, 470, -95, -3498)
	_box(tool, 380, -75, -3505, 420, -65, -3495) # the boxes about the body
	_box(tool, 380, -105, -3535, 420, -95, -3525)
	_box(tool, 380, -135, -3505, 420, -125, -3495)
	_box(tool, 380, -105, -3475, 420, -95, -3465)
	_box(tool, 468, -145, -3502, 472, -105, -3498) # the panel's strut and the panel
	_box(tool, 470, -175, -3503, 560, -145, -3497)


## The light cruiser: a low delta hull, wedge-shaped, with a raised spine, a keel, and its works at
## the stern: a block, a tower, a bridge, and two turrets.
static func _light_cruiser(tool: SurfaceTool) -> void:
	var nose := _g(150, -100, -3500)
	var left := _g(600, -100, -3350)
	var right := _g(600, -100, -3650)
	var spine := _g(450, -89, -3500)
	_tri(tool, nose, left, spine) # the top
	_tri(tool, nose, spine, right)
	_tri(tool, spine, left, right)
	var nose_under := _g(150, -105, -3500)
	var left_under := _g(600, -105, -3350)
	var right_under := _g(600, -105, -3650)
	_tri(tool, nose_under, right_under, left_under) # the underside, and the edges of the slab
	_quad(tool, nose, nose_under, left_under, left)
	_quad(tool, nose, right, right_under, nose_under)
	_quad(tool, left, left_under, right_under, right)
	var keel := _g(600, -120, -3500) # the keel fin
	_tri(tool, nose_under, keel, _g(600, -105, -3500))
	_box(tool, 300, -111, -3530, 410, -105, -3470) # the pod under the hull
	_box(tool, 550, -95, -3550, 600, -60, -3450) # the stern block
	var tower_base := [_g(550, -60, -3510), _g(600, -60, -3510), _g(600, -60, -3490), _g(550, -60, -3490)]
	var tower_top := [_g(580, -10, -3510), _g(600, -10, -3510), _g(600, -10, -3490), _g(580, -10, -3490)]
	_loft(tool, tower_base, tower_top) # the tower, leaning back
	_box(tool, 580, -10, -3540, 600, 10, -3460) # the bridge
	_box(tool, 582, 10, -3530, 600, 28, -3505) # its dome
	_box(tool, 560, -60, -3540, 580, -50, -3520) # the turrets
	_box(tool, 560, -60, -3470, 570, -50, -3460)
	_box(tool, 596, -110, -3560, 604, -100, -3510) # the engines
	_box(tool, 596, -110, -3490, 604, -100, -3440)


## The heavy cruiser: a pointed nose, a neck, a long hull with a bridge, the engines at the stern,
## and two pods slung under the hull on pylons.
static func _heavy_cruiser(tool: SurfaceTool) -> void:
	var tip := [_g(170, -90, -3510), _g(170, -90, -3490), _g(170, -100, -3490), _g(170, -100, -3510)]
	var base := [_g(250, -60, -3540), _g(250, -60, -3460), _g(250, -110, -3460), _g(250, -110, -3540)]
	_loft(tool, tip, base) # the nose
	_box(tool, 250, -110, -3540, 300, -60, -3460) # the neck
	_box(tool, 300, -100, -3520, 340, -70, -3480)
	_box(tool, 340, -100, -3540, 600, -60, -3460) # the hull
	_box(tool, 380, -60, -3510, 400, -50, -3490) # the bridge, and its mast
	var mast_base := [_g(380, -50, -3510), _g(400, -50, -3510), _g(400, -50, -3490), _g(380, -50, -3490)]
	var mast_top := [_g(388, -30, -3502), _g(392, -30, -3502), _g(392, -30, -3498), _g(388, -30, -3498)]
	_loft(tool, mast_base, mast_top)
	_box(tool, 600, -100, -3540, 630, -70, -3460) # the engines
	for side in [1.0, -1.0]: # the pods and their pylons
		var near := -3440.0 if side > 0.0 else -3560.0
		var far := -3400.0 if side > 0.0 else -3600.0
		var inner := -3460.0 if side > 0.0 else -3540.0
		_box(tool, 380, -130, minf(near, far), 600, -110, maxf(near, far))
		_box(tool, 420, -120, minf(inner, near), 440, -80, maxf(inner, near))
		_box(tool, 530, -120, minf(inner, near), 550, -80, maxf(inner, near))


# --- the parts ------------------------------------------------------------------------


## A point of the original's world, in the model: the ship's middle at the origin, z mirrored.
static func _g(x: float, y: float, z: float) -> Vector3:
	var v := Vector3(x, y, z) - MIDDLE
	return Vector3(v.x, v.y, -v.z)


## A box between two corners of the original's world.
static func _box(tool: SurfaceTool, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> void:
	var a := _g(x0, y0, z0)
	var b := _g(x1, y1, z1)
	var lo := a.min(b)
	var hi := a.max(b)
	var p := [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	_quad(tool, p[0], p[3], p[2], p[1]) # back
	_quad(tool, p[4], p[5], p[6], p[7]) # front
	_quad(tool, p[0], p[4], p[7], p[3]) # left
	_quad(tool, p[1], p[2], p[6], p[5]) # right
	_quad(tool, p[3], p[7], p[6], p[2]) # top
	_quad(tool, p[0], p[1], p[5], p[4]) # bottom


## The sides of a solid between two four-cornered ends (the corners in the same order round), and the ends.
static func _loft(tool: SurfaceTool, a: Array, b: Array) -> void:
	for i in 4:
		var n := (i + 1) % 4
		_quad(tool, a[i], a[n], b[n], b[i])
	_quad(tool, a[0], a[1], a[2], a[3])
	_quad(tool, b[3], b[2], b[1], b[0])


static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex in [a, b, c]:
		tool.add_vertex(vertex)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(tool, a, b, c)
	_tri(tool, a, c, d)
