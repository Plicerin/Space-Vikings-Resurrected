extends Node3D
## Flight in space, in Godot's own 3D: a camera where the ship is, the stars,
## the planet as a shaded sphere with the lights of its cities on the night
## side, the orbital defender as a low-poly craft, and a panel under it.
## How the ship goes is scripts/rules/flight_rules.gd, held to the
## original's arithmetic (tests/check_flight_rules.gd); this shows it.
##
## The original's world is kept as it is, in its own units: the planet at
## the origin (the ship goes down when it is within 900 of it), the
## defender at (400, -100, -3500), the world wrapping at +-20000.
## Godot's z is the original's the other way round (FlightRules.place).
##
## Not yet in here: fighting, going down to the planet and up again, and
## the hyperdrive; the original's flight scene (scenes/flight/) does them
## and is still the one the game uses.

const FlightRules = preload("res://scripts/rules/flight_rules.gd")
const DisplayList = preload("res://scripts/world/display_list.gd")

const COM := "res://scenes/com.tscn"
const RADAR := "res://scenes/radar.tscn"

const PLANET_RADIUS := 780.0
## The game's own points nearer than this to the planet are its cluster; the
## rest are stars.
const CLUSTER_RADIUS := 1500.0
## How many of the cluster are lit, by tech: nothing, a few, some, many, all.
const CITIES := [0, 14, 40, 90, 144]
const DEFENDER_AT := Vector3(400.0, -100.0, -3500.0) ## STARSHIP SIMULATOR.bas line 2: X9, Y9, Z9
const SUN := Vector3(0.6, 0.25, -0.75)
const SKY_STARS := 700
const SKY_RADIUS := 150000.0
## Stick positions: hard over, and a little over with SHIFT.
const STICK_HARD := 1.0
const STICK_FINE := 0.35

var _rules := FlightRules.new()
var _planet: MeshInstance3D
var _defender: Node3D
var _sky: MultiMeshInstance3D
var _said_for := 0.0

@onready var _camera: Camera3D = $Camera
@onready var _sun_light: DirectionalLight3D = $Sun
@onready var _speed: ProgressBar = $Hud/Bar/Rows/Gauges/Speed
@onready var _energy: ProgressBar = $Hud/Bar/Rows/Gauges/Energy
@onready var _shields: ProgressBar = $Hud/Bar/Rows/Gauges/Shields
@onready var _readout: Label = $Hud/Bar/Rows/Readout
@onready var _lamps: GridContainer = $Hud/Bar/Rows/Lamps
@onready var _said: Label = $Hud/Said


func _ready() -> void:
	_rules.load_state()
	_environment()
	_sun_light.look_at_from_position(Vector3.ZERO, -FlightRules.place(SUN))
	_make_planet()
	_make_defender()
	_make_stars()
	_make_lamps()
	_update_camera()
	_update_hud()


func _process(delta: float) -> void:
	var stick_pitch := _axis("stick_forward", "stick_back")
	var stick_bank := _axis("stick_left", "stick_right")
	_rules.fly(delta, stick_pitch, stick_bank)
	_rules.store_state() # the radar, the console and a save read the game's own copy
	_update_camera()
	_update_hud()
	if _said_for > 0.0:
		_said_for -= delta
		if _said_for <= 0.0:
			_said.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _rules.change_speed(-3.0)
		KEY_2: _rules.change_speed(3.0)
		KEY_3: _rules.change_speed(-15.0)
		KEY_4: _rules.change_speed(15.0)
		KEY_A: GameState.autopilot_active = not GameState.autopilot_active
		KEY_B: GameState.condition = {2: 3, 3: 1}.get(GameState.condition, 2)
		KEY_S: GameState.shields_up = not GameState.shields_up
		KEY_W: GameState.missile_mode_active = not GameState.missile_mode_active
		KEY_C:
			_leave(COM)
		KEY_R:
			_leave(RADAR)
		KEY_H:
			_say("THE HYPERDRIVE IS NOT HERE YET.")


## 0 for neither key, `hard` for the first, the other way for the second.
func _axis(first: String, second: String) -> float:
	var amount := STICK_FINE if Input.is_key_pressed(KEY_SHIFT) else STICK_HARD
	if Input.is_action_pressed(first):
		return amount
	if Input.is_action_pressed(second):
		return -amount
	return 0.0


func _leave(scene: String) -> void:
	_rules.store_state()
	GameState.goto_scene(scene)


func _say(text: String) -> void:
	_said.text = text
	_said_for = 2.5


# --- the world ---


func _environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.10, 0.12, 0.18)
	environment.ambient_light_energy = 0.6
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.1
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _make_planet() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = PLANET_RADIUS
	sphere.height = PLANET_RADIUS * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/planet.gdshader")
	var planet := GameState.current_planet
	material.set_shader_parameter("tech", float(GameState.planet_tech[planet]))
	material.set_shader_parameter("seed", float(planet + 1))
	material.set_shader_parameter("sun_direction", FlightRules.place(SUN))
	var cities := PackedVector3Array()
	for point in _points():
		if point.length() < CLUSTER_RADIUS:
			cities.append(FlightRules.place(point).normalized())
	var count: int = mini(CITIES[GameState.planet_tech[planet]], cities.size())
	cities.resize(144)
	material.set_shader_parameter("cities", cities)
	material.set_shader_parameter("city_count", count)
	_planet = MeshInstance3D.new()
	_planet.mesh = sphere
	_planet.material_override = material
	add_child(_planet)


## The game's 195 points: a cluster round the planet and some stars.
func _points() -> PackedVector3Array:
	return DisplayList.load_file("planet_0.bin").points


## What defends the planet, if anything does: a low-poly craft, flat
## shaded, until the originals' own shapes are made into models.
func _make_defender() -> void:
	var planet := GameState.current_planet
	if GameState.planet_tech[planet] < 2 or GameState.gf_planet_surrendered:
		return
	_defender = Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = _craft_mesh()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.68, 0.78)
	material.metallic = 0.5
	material.roughness = 0.4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	body.material_override = material
	body.scale = Vector3.ONE * 120.0
	_defender.add_child(body)
	_defender.position = FlightRules.place(DEFENDER_AT)
	add_child(_defender)


## A swept craft in a dozen triangles, nose along -z (ahead in Godot).
func _craft_mesh() -> ArrayMesh:
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


## The stars: the original's own 195 points, a little bigger, and a sky of
## far ones round the ship that goes with it.
func _make_stars() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = _star_texture()
	quad.material = material
	var near := PackedVector3Array()
	for point in _points():
		if point.length() >= CLUSTER_RADIUS:
			near.append(point)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = near.size()
	for i in near.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 160.0), FlightRules.place(near[i])))
		multimesh.set_instance_color(i, Color(0.85, 0.92, 1.0))
	var near_stars := MultiMeshInstance3D.new()
	near_stars.multimesh = multimesh
	add_child(near_stars)

	var far := MultiMesh.new()
	far.transform_format = MultiMesh.TRANSFORM_3D
	far.use_colors = true
	far.mesh = quad
	far.instance_count = SKY_STARS
	var rng := RandomNumberGenerator.new()
	rng.seed = 1982
	for i in SKY_STARS:
		var direction := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var size := SKY_RADIUS * rng.randf_range(0.006, 0.016)
		far.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), direction * SKY_RADIUS))
		var warm := rng.randf()
		far.set_instance_color(i, Color(1.0, 0.85 + 0.15 * warm, 0.75 + 0.25 * warm).lerp(Color(0.7, 0.8, 1.0), 1.0 - warm))
	_sky = MultiMeshInstance3D.new()
	_sky.multimesh = far
	add_child(_sky)


## A round, soft star: white in the middle, nothing at the edge.
func _star_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.9))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


func _update_camera() -> void:
	var eye := FlightRules.place(Vector3(_rules.x, _rules.y, _rules.z))
	_camera.transform = Transform3D(FlightRules.camera_basis(_rules.pitch, _rules.bank, _rules.heading), eye)
	_sky.position = eye


# --- the panel ---


func _make_lamps() -> void:
	for text in ["AUTOPILOT", "SHIELDS", "WEAPON", "CONDITION"]:
		var lamp := Label.new()
		lamp.name = text
		lamp.text = text
		lamp.custom_minimum_size.x = 150
		_lamps.add_child(lamp)


func _update_hud() -> void:
	_speed.value = _rules.speed
	_energy.value = GameState.ship_energy
	_shields.value = GameState.ship_shield
	# the original's read-outs: X Y Z halved, heading and pitch as degrees (a unit * 1.41)
	_readout.text = "X %d  Y %d  Z %d\nHEADING %d  PITCH %d\nBANK %d" % [
		_rules.x / 2.0, _rules.y / 2.0, _rules.z / 2.0, roundi(_rules.heading * 1.41),
		roundi(_rules.pitch * 1.41), roundi(_rules.bank * 1.41)]
	_lamp("AUTOPILOT", GameState.autopilot_active, Color(0.1, 0.95, 0.3))
	_lamp("SHIELDS", GameState.shields_up, Color(0.1, 0.95, 0.3))
	_lamp("WEAPON", true, Color(1.0, 0.55, 0.2) if GameState.missile_mode_active else Color(0.35, 0.8, 1.0))
	var colours := {1: Color(0.1, 0.95, 0.3), 2: Color(0.3, 0.6, 1.0), 3: Color(1.0, 0.3, 0.2)}
	_lamp("CONDITION", true, colours.get(GameState.condition, Color.WHITE))


func _lamp(name: String, on: bool, colour: Color) -> void:
	var lamp := _lamps.get_node(name) as Label
	lamp.modulate = colour if on else Color(0.45, 0.45, 0.45)
	if name == "WEAPON":
		lamp.text = "MISSILES" if GameState.missile_mode_active else "LASER"
