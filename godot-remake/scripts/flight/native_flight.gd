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
## The fighting is scripts/rules/combat_rules.gd, a pass of it a second as
## the original did, and scripts/flight/fight_effects.gd plays what it says.
##
## The hyperdrive is scripts/rules/hyperdrive_rules.gd with the jump's rays
## over it and the scene begun again at the other star.
##
## Going down to the planet (within 900 of it) and up again (above 4000 in
## the atmosphere) are flight_rules.gd's, with a few words over the view and
## the scene begun again, the other side of the planet's sky: the ground
## from the air, the planet's own map lines on it. In the atmosphere there
## is no defender; the planet's fighters are all there is.
##
## The original's flight scene (scenes/flight/) is still the one the game
## uses until this has the real ship models.

const FlightRules = preload("res://scripts/rules/flight_rules.gd")
const CombatRules = preload("res://scripts/rules/combat_rules.gd")
const HyperdriveRules = preload("res://scripts/rules/hyperdrive_rules.gd")
const HyperspaceEffect = preload("res://scripts/flight/hyperspace_effect.gd")
const DisplayList = preload("res://scripts/world/display_list.gd")
const Craft = preload("res://scripts/world/craft.gd")
const FightEffects = preload("res://scripts/flight/fight_effects.gd")

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
var _combat := CombatRules.new()
var _effects: Node3D
## Seconds since the last pass of fighting, and whether the fire key was
## pressed since (a tap between two passes still fires).
var _fight_clock := 0.0
var _fire_tapped := false
var _dead := false
var _jumping := false
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
@onready var _flash: ColorRect = $Hud/Flash


func _ready() -> void:
	GameState.flight_scene = scene_file_path
	_rules.load_state()
	_environment()
	_sun_light.look_at_from_position(Vector3.ZERO, -FlightRules.place(SUN))
	if _rules.in_atmosphere:
		_make_ground()
	else:
		_make_planet()
		_make_defender()
		_make_stars()
	_make_lamps()
	_combat.start(true)
	_effects = FightEffects.new()
	_effects.camera = _camera
	_effects.flashed.connect(_flash_screen)
	add_child(_effects)
	_update_camera()
	_update_hud()


func _process(delta: float) -> void:
	if _dead or _jumping:
		return
	var stick_pitch := _axis("stick_forward", "stick_back")
	var stick_bank := _axis("stick_left", "stick_right")
	_rules.fly(delta, stick_pitch, stick_bank)
	_rules.store_state() # the radar, the console and a save read the game's own copy
	_update_camera()
	_update_hud()
	if _rules.is_over_planet():
		_change_world("REENTRY SEQUENCE START", _rules.reenter)
		return
	if _rules.is_leaving_atmosphere():
		_change_world("ORBITAL INSERTION START", _rules.enter_orbit)
		return
	_fight_clock += delta
	if _fight_clock >= FlightRules.PASS:
		_fight_clock = 0.0
		_fight()
	if _said_for > 0.0:
		_said_for -= delta
		if _said_for <= 0.0:
			_said.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _dead:
		GameState.reboot() # a key after the ship is lost, and the machine starts again
		return
	if event.is_action("fire"):
		_fire_tapped = true
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
			_hyperdrive()


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


## @witness STARSHIP SIMULATOR 185-192
## @witness DMG 10
## @witness S_X 40-70
## A pass of fighting: the rules decide, the effects play it.
func _fight() -> void:
	var button := _fire_tapped or Input.is_action_pressed("fire")
	_fire_tapped = false
	var eye := Vector3(_rules.x, _rules.y, _rules.z)
	var result := _combat.fight(button, eye, Vector2(_rules.pitch, _rules.heading),
			FlightRules.pitch_marker(_rules.pitch))
	for event: Dictionary in result["events"]:
		_play(event)
	match result["outcome"]:
		CombatRules.Outcome.DEFENDER_DESTROYED:
			_say("THE DEFENDER IS DESTROYED.")
			if _defender != null:
				_effects.explosion(_defender.global_position, 300.0)
				_defender.queue_free()
				_defender = null
			_combat.defender_destroyed()
			_combat.start(true)
			_make_debris()
		CombatRules.Outcome.DAMAGED:
			_say("DAMAGE TO THE SHIP.")
			_combat.start(true)
		CombatRules.Outcome.SHIP_DESTROYED:
			_flash_screen(1.0)
			_said.text = "YOUR SHIP HAS BEEN DESTROYED!!"
			_said_for = 1e9
			_dead = true


func _play(event: Dictionary) -> void:
	match event["kind"]:
		"laser":
			_effects.laser()
		"missile":
			var ahead := -_camera.global_transform.basis.z
			_effects.missile(ahead, event["steps"], event["hit"])
		"surrendered":
			_say("THE PLANET HAS SURRENDERED")
		"damage":
			for i in event["light"]:
				get_tree().create_timer(0.12 * i).timeout.connect(_flash_screen.bind(0.35))
			if event["medium"]:
				_flash_screen(0.7)
		"fighter":
			_effects.fighter(event["from"], event["step"], event["steps"], event["strafes"], event["shot_down"])


func _flash_screen(strength: float) -> void:
	_flash.color.a = strength
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)


## @witness STARSHIP SIMULATOR 209
## @witness H_D 1-8
## @witness-asm 37494
## (CALL 37494 is SOUND GEN's noise, played in the jump at lines 18 and 20.)
## The hyperdrive: refused without a word where the original refuses (here it
## says why), the ship lost with no energy at all, otherwise the jump.
func _hyperdrive() -> void:
	if _jumping or _dead:
		return
	_rules.store_state()
	if HyperdriveRules.refused():
		if GameState.in_atmosphere:
			_say("NO JUMP FROM THE ATMOSPHERE.")
		elif GameState.target_planet < 0:
			_say("NO COURSE IS SET.")
		else:
			_say("WE ARE THERE ALREADY.")
		return
	if not HyperdriveRules.has_energy():
		_jumping = true
		_say("OUT OF ENERGY")
		await get_tree().create_timer(1.6).timeout
		_say("ORBIT DECAYING")
		await get_tree().create_timer(1.6).timeout
		_flash_screen(1.0)
		_said.text = "YOUR SHIP HAS BEEN DESTROYED!!"
		_said_for = 1e9
		_dead = true
		return
	_jumping = true
	var rays := HyperspaceEffect.new()
	$Hud.add_child(rays)
	await rays.done
	HyperdriveRules.jump(func() -> float: return randf())
	get_tree().reload_current_scene()


## @witness RE 20-40
## @witness ORBIT 20-40
## Down to the planet or up into orbit: the words, a moment, and the ship
## put where the original puts it, in the other world.
func _change_world(words: String, move: Callable) -> void:
	_jumping = true
	_say(words)
	await get_tree().create_timer(2.0).timeout
	move.call()
	_rules.store_state()
	get_tree().reload_current_scene()


func _say(text: String) -> void:
	_said.text = text
	_said_for = 2.5


# --- the world ---


func _environment() -> void:
	var environment := Environment.new()
	if _rules.in_atmosphere:
		var sky := Sky.new()
		sky.sky_material = ProceduralSkyMaterial.new()
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.55, 0.70, 0.90)
		environment.fog_density = 0.00004
	else:
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


## The ground from the air: land and sea, and the planet's own map lines.
func _make_ground() -> void:
	var planet := GameState.current_planet
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 80000.0
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/ground.gdshader")
	material.set_shader_parameter("tech", float(GameState.planet_tech[planet]))
	material.set_shader_parameter("seed", float(planet + 1))
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = material
	add_child(ground)
	var map: PackedVector3Array = DisplayList.load_file("planet_%d.bin" % (planet + 1)).lines
	if map.is_empty():
		return
	var points := PackedVector3Array()
	for point in map:
		points.append(FlightRules.place(point + Vector3(0, 4, 0)))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var lines := ArrayMesh.new()
	lines.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var map_material := StandardMaterial3D.new()
	map_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	map_material.albedo_color = Color(0.95, 0.9, 0.55)
	var map_lines := MeshInstance3D.new()
	map_lines.mesh = lines
	map_lines.material_override = map_material
	add_child(map_lines)


## What is left of a defender: the game's own fifty points of wreckage.
func _make_debris() -> void:
	var points: PackedVector3Array = DisplayList.load_file("debris.bin").points
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = Craft.rock()
	multimesh.instance_count = points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in points.size():
		var rock := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(
				Vector3.ONE * rng.randf_range(4.0, 16.0))
		multimesh.set_instance_transform(i, Transform3D(rock, FlightRules.place(points[i])))
	var wreck := MultiMeshInstance3D.new()
	wreck.multimesh = multimesh
	wreck.material_override = Craft.material(Color(0.5, 0.48, 0.45))
	add_child(wreck)


## What defends the planet, if anything does: a low-poly craft, flat
## shaded, until the originals' own shapes are made into models.
func _make_defender() -> void:
	var planet := GameState.current_planet
	if GameState.planet_tech[planet] < 2:
		return
	if GameState.orbital_defender_tier == 0: # the wreck of one
		_make_debris()
		return
	if GameState.gf_planet_surrendered:
		return
	_defender = Node3D.new()
	var body := MeshInstance3D.new()
	var model := Craft.defender(GameState.orbital_defender_tier)
	if model != null:
		body.mesh = model
	else:
		body.mesh = Craft.mesh()
		body.scale = Vector3.ONE * 120.0
	body.material_override = Craft.material(Color(0.62, 0.68, 0.78))
	_defender.add_child(body)
	_defender.position = FlightRules.place(DEFENDER_AT)
	add_child(_defender)


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
	if _sky != null:
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
