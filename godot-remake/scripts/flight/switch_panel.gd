extends Control
## The flight panel's switches as real objects, in a little 3D scene of their
## own drawn into this control: a shield push button (lit blue and pressed in
## while the shields are up) over two rockers, AUTO / MNL and missile / laser,
## the lit side the active one. Clicks on them do what the keys S, A and W do.

const FONT := preload("res://assets/fonts/space_vikings.res")

const WIDTH := 2.2 ## world units across the plate
const HEIGHT := 2.27
const SCALE := 2 ## the 3D picture is drawn at this many pixels to the control's one
const BLUE := Color(0.35, 0.8, 1.0)
const AMBER := Color(1.0, 0.69, 0.0)
const ORANGE := Color(1.0, 0.6, 0.2)
const DIM := Color(0.2, 0.18, 0.12)

var _viewport: SubViewport
var _button: Node3D
var _shield_mesh: MeshInstance3D
var _auto_pivot: Node3D
var _weapon_pivot: Node3D
var _auto_labels: Array[Label3D] = []
var _missile_parts: Array[MeshInstance3D] = []
var _laser_parts: Array[MeshInstance3D] = []


func _ready() -> void:
	custom_minimum_size = Vector2(130.0, 134.0)
	size = custom_minimum_size
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(custom_minimum_size * SCALE)
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_8X
	_viewport.own_world_3d = true
	add_child(_viewport)
	var picture := TextureRect.new()
	picture.texture = _viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.position = Vector2.ZERO
	picture.custom_minimum_size = custom_minimum_size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	_build()
	# where a click lands (pixels of this control)
	_hotspot(Rect2(65.0 - 22.0, 22.0 - 22.0 + 4.0, 44.0, 44.0), func() -> void: GameState.shields_up = not GameState.shields_up)
	_hotspot(Rect2(65.0 - 29.5 - 23.0, 67.0, 46.0, 65.0), func() -> void: GameState.autopilot_active = not GameState.autopilot_active)
	_hotspot(Rect2(65.0 + 29.5 - 23.0, 67.0, 46.0, 65.0), func() -> void: GameState.missile_mode_active = not GameState.missile_mode_active)


func _process(delta: float) -> void:
	var press := minf(1.0, delta * 18.0)
	var shields := GameState.shields_up
	_button.position.z = lerpf(_button.position.z, 0.02 if shields else 0.12, press)
	var glow := (_shield_mesh.material_override as StandardMaterial3D)
	glow.albedo_color = glow.albedo_color.lerp(BLUE if shields else Color(0.07, 0.1, 0.13), press)
	_auto_pivot.rotation.x = lerpf(_auto_pivot.rotation.x, -0.2 if GameState.autopilot_active else 0.2, press)
	_weapon_pivot.rotation.x = lerpf(_weapon_pivot.rotation.x, -0.2 if GameState.missile_mode_active else 0.2, press)
	_auto_labels[0].modulate = AMBER if GameState.autopilot_active else DIM
	_auto_labels[1].modulate = DIM if GameState.autopilot_active else AMBER
	_light(_missile_parts, ORANGE if GameState.missile_mode_active else DIM)
	_light(_laser_parts, DIM if GameState.missile_mode_active else BLUE)


func _light(parts: Array[MeshInstance3D], colour: Color) -> void:
	for part in parts:
		(part.material_override as StandardMaterial3D).albedo_color = colour


func _hotspot(rect: Rect2, action: Callable) -> void:
	var spot := Control.new()
	spot.position = rect.position
	spot.size = rect.size
	spot.mouse_filter = Control.MOUSE_FILTER_STOP
	spot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	spot.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			action.call())
	add_child(spot)


func _build() -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = HEIGHT
	camera.position = Vector3(0.0, 0.0, 5.0)
	_viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	light.light_energy = 1.0
	_viewport.add_child(light)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.52, 0.6)
	environment.ambient_light_energy = 0.45
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	# the plate: dark moulded plastic
	_mesh(_viewport, _box(Vector3(WIDTH, HEIGHT, 0.2)), Vector3(0.0, 0.0, 0.0), _plastic(Color(0.09, 0.093, 0.1)))
	# the shield button: a bezel, the button in it, the shield on the button
	var ring := TorusMesh.new()
	ring.inner_radius = 0.33
	ring.outer_radius = 0.43
	var bezel := _mesh(_viewport, ring, Vector3(0.0, 0.76, 0.12), _plastic(Color(0.05, 0.052, 0.058)))
	bezel.rotation.x = PI / 2.0
	_button = Node3D.new()
	_button.position = Vector3(0.0, 0.76, 0.12)
	_viewport.add_child(_button)
	var cap := _mesh(_button, _cylinder(0.32, 0.32, 0.16), Vector3.ZERO, _plastic(Color(0.13, 0.14, 0.16)))
	cap.rotation.x = PI / 2.0
	_shield_mesh = _mesh(_button, _shield_shape(0.2), Vector3(0.0, 0.0, 0.11), _flat(Color(0.07, 0.1, 0.13)))
	# the AUTO / MNL rocker, and the missile / laser one
	_auto_pivot = _rocker(Vector3(-0.5, -0.55, 0.1))
	_auto_labels.append(_label(_auto_pivot, "AUTO", Vector3(0.0, 0.3, 0.25)))
	_auto_labels.append(_label(_auto_pivot, "MNL", Vector3(0.0, -0.3, 0.25)))
	_weapon_pivot = _rocker(Vector3(0.5, -0.55, 0.1))
	_missile_parts = _missile(_weapon_pivot, Vector3(0.0, 0.3, 0.25))
	_laser_parts = _laser(_weapon_pivot, Vector3(0.0, -0.3, 0.25))


func _rocker(at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	_viewport.add_child(pivot)
	_mesh(_viewport, _box(Vector3(0.96, 1.26, 0.04)), at + Vector3(0.0, 0.0, 0.0), _plastic(Color(0.02, 0.02, 0.024)))
	_mesh(pivot, _box(Vector3(0.82, 1.1, 0.26)), Vector3(0.0, 0.0, 0.08), _plastic(Color(0.3, 0.31, 0.34)))
	return pivot


func _label(parent: Node3D, text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 40
	label.pixel_size = 0.0042
	label.shaded = false
	label.position = at
	label.modulate = DIM
	parent.add_child(label)
	return label


## A missile standing on end: body, nose and two fins.
func _missile(parent: Node3D, at: Vector3) -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	var material := _flat(DIM)
	parts.append(_mesh(parent, _cylinder(0.06, 0.06, 0.3), at, material))
	parts.append(_mesh(parent, _cylinder(0.0, 0.06, 0.14), at + Vector3(0.0, 0.22, 0.0), material))
	parts.append(_mesh(parent, _box(Vector3(0.2, 0.08, 0.02)), at + Vector3(0.0, -0.15, 0.0), material))
	return parts


## A point of light: a core and eight rays.
func _laser(parent: Node3D, at: Vector3) -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	var material := _flat(DIM)
	var core := SphereMesh.new()
	core.radius = 0.07
	core.height = 0.14
	parts.append(_mesh(parent, core, at, material))
	for i in 8:
		var ray := _mesh(parent, _box(Vector3(0.26 if i % 2 == 0 else 0.17, 0.025, 0.02)), at, material)
		ray.rotation.z = PI * i / 8.0 * 2.0 / 2.0 * 1.0 + PI * i / 8.0
		parts.append(ray)
	return parts


func _shield_shape(size_units: float) -> ArrayMesh:
	var outline := [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -0.1), Vector2(0, -1.15), Vector2(-1, -0.1)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector2(0.0, 0.0)
	for i in outline.size():
		var a: Vector2 = outline[i] * size_units
		var b: Vector2 = outline[(i + 1) % outline.size()] * size_units
		tool.set_normal(Vector3(0, 0, 1))
		tool.add_vertex(Vector3(centre.x, centre.y, 0.0))
		tool.add_vertex(Vector3(a.x, a.y, 0.0))
		tool.add_vertex(Vector3(b.x, b.y, 0.0))
	return tool.commit()


func _mesh(parent: Node, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _box(extent: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = extent
	return mesh


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh


func _plastic(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.45
	material.metallic = 0.1
	return material


func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
