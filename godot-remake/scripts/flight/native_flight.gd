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

const VectorRadar = preload("res://scripts/flight/vector_radar.gd")
const VectorChart = preload("res://scripts/flight/vector_chart.gd")
const CrtConsole = preload("res://scripts/flight/crt_console.gd")
const VectorGlobe = preload("res://scripts/flight/vector_globe.gd")
const GroundForcesProgram = preload("res://scripts/flight/ground_forces_program.gd")
const CommandConsoleProgram = preload("res://scripts/flight/command_console_program.gd")
const EndProgram = preload("res://scripts/flight/end_program.gd")
const RadarRules = preload("res://scripts/rules/radar_rules.gd")

const PLANET_RADIUS := 780.0
## The game's own points nearer than this to the planet are its cluster; the
## rest are stars.
const CLUSTER_RADIUS := 1500.0
## How many of the cluster are lit, by tech: nothing, a few, some, many, all.
const CITIES := [0, 14, 40, 90, 144]
const DEFENDER_AT := Vector3(400.0, -100.0, -3500.0) ## STARSHIP SIMULATOR.bas line 2: X9, Y9, Z9
const SUN := Vector3(0.6, 0.25, -0.75)
const SKY_STARS := 700
const CLOUD_HEIGHT := 2200.0
const SKY_RADIUS := 150000.0
## Stick positions: hard over, and a little over with SHIFT.
const STICK_HARD := 1.0
const STICK_FINE := 0.35

var _rules := FlightRules.new()
var _combat := CombatRules.new()
var _effects: Node3D
var _radar: Control
var _chart: Control
var _console: Node
var _globe: Control
var _clouds: MeshInstance3D
var _fog: Environment
var _sky_material: ProceduralSkyMaterial
var _com_waiting := false ## the console is waiting for the chart to close
## Seconds since the last pass of fighting, and whether the fire key was
## pressed since (a tap between two passes still fires).
var _fight_clock := 0.0
var _fire_tapped := false
var _dead := false
var _jumping := false
var _planet: MeshInstance3D
var _defender: Node3D
var _shake := 0.0 ## camera shake left, from a burst or a hit; dies away
var _stick := Vector2.ZERO ## pitch and bank stick, as last read
var _sky: MultiMeshInstance3D
var _said_for := 0.0

@onready var _camera: Camera3D = $Camera
@onready var _sun_light: DirectionalLight3D = $Sun
@onready var _flash: ColorRect = $Hud/Flash
@onready var _overlay: Control = $Hud/Overlay


func _exit_tree() -> void:
	AudioManager.engine_off() # the scene is going: its hum with it


func _ready() -> void:
	GameState.flight_scene = scene_file_path
	_rules.load_state()
	_environment()
	_sun_light.look_at_from_position(Vector3.ZERO, -FlightRules.place(SUN))
	_sun_light.light_energy = 1.6
	# a cool fill from the other side, so that the dark side of a ship still has its shape
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.65, 0.95)
	fill.light_energy = 0.55
	add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, FlightRules.place(SUN) + Vector3(0.0, -0.4, 0.0) * FlightRules.place(SUN).length())
	if _rules.in_atmosphere:
		_make_ground()
	else:
		_make_planet()
		_make_defender()
		_make_stars()
	_combat.start(true)
	_effects = FightEffects.new()
	_effects.camera = _camera
	_effects.flashed.connect(_flash_screen)
	_effects.shaken.connect(func(amount: float) -> void: _shake = maxf(_shake, amount))
	add_child(_effects)
	_radar = VectorRadar.new()
	_radar.console = $Hud/Overlay
	$Hud.add_child(_radar)
	_console = CrtConsole.new()
	_console.overlay = $Hud/Overlay
	add_child(_console)
	_globe = VectorGlobe.new()
	$Hud.add_child(_globe)
	_chart = VectorChart.new()
	_chart.console = $Hud/Overlay
	$Hud.add_child(_chart)
	_chart.closed.connect(func(to_console: bool) -> void: # a chart opened by G: its "Y" runs the console with the star's page
		if to_console and not _com_waiting and GameState.handover > 0:
			_run_command_console.call_deferred())
	_overlay.camera = _camera
	_overlay.target = _defender
	_update_camera()
	_update_hud()


func _process(delta: float) -> void:
	if _dead or _jumping:
		return
	# AUTO does as the original did: the stick is not read, the ship keeps the
	# position it had; MNL reads it each frame (keys, mouse or joystick alike)
	if not GameState.autopilot_active:
		_stick = Vector2(_axis("stick_forward", "stick_back"), _axis("stick_left", "stick_right"))
	_rules.fly(delta, _stick.x, _stick.y)
	AudioManager.engine(_rules.speed)
	_rules.store_state() # the radar, the console and a save read the game's own copy
	_update_camera()
	_update_atmosphere()
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
			_overlay.message = ""


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or (key.echo and not _chart.visible): # a held arrow moves the chart's cursor
		return
	if _dead:
		GameState.reboot() # a key after the ship is lost, and the machine starts again
		return
	var viewport := get_viewport() # the radar's X may leave for the console
	if _console.handle_key(key) or _radar.handle_key(key) or _chart.handle_key(key):
		viewport.set_input_as_handled()
		return
	if event.is_action("fire"):
		_fire_tapped = true
		return
	match key.keycode:
		KEY_1: _rules.change_speed(-3.0)
		KEY_2: _rules.change_speed(3.0)
		KEY_3: _rules.change_speed(-15.0)
		KEY_4: _rules.change_speed(15.0)
		KEY_N: _overlay.show_mode(_overlay.Mode.NAV)
		KEY_F1, KEY_SLASH: _overlay.show_mode(_overlay.Mode.HELP)
		KEY_A:
			GameState.autopilot_active = not GameState.autopilot_active
			AudioManager.play_switch()
		KEY_B:
			GameState.condition = {2: 3, 3: 1}.get(GameState.condition, 2)
			AudioManager.play_alarm() if GameState.condition == 3 else AudioManager.play_select()
		KEY_S:
			GameState.shields_up = not GameState.shields_up
			AudioManager.play_switch()
		KEY_W:
			GameState.missile_mode_active = not GameState.missile_mode_active
			AudioManager.play_switch()
		KEY_C:
			_run_command_console.call_deferred()
		KEY_R:
			if not _chart.visible:
				_radar.open()
		KEY_G:
			if not _radar.visible:
				_chart.open()
		KEY_H:
			_hyperdrive()


## 0 for neither key, `hard` for the first, the other way for the second.
func _axis(first: String, second: String) -> float:
	var amount := STICK_FINE if Input.is_key_pressed(KEY_SHIFT) else STICK_HARD
	return clampf(Input.get_action_strength(first) - Input.get_action_strength(second), -1.0, 1.0) * amount


func _leave(scene: String) -> void:
	_rules.store_state()
	GameState.goto_scene(scene)


## @witness STARSHIP SIMULATOR 185-192
## @witness DMG 10
## @witness S_X 40-70
## A pass of fighting: the rules decide, the effects play it.
## The command console, on the display: its menus, and on from them to the
## programs of the original that ran from it, which are this scene's own.
## @witness COM 1-12
func _run_command_console() -> void:
	if _console.active() or _radar.visible or _chart.visible or _dead or _jumping:
		return
	var host := {
		"ground_forces": func() -> void: await GroundForcesProgram.new().run(_console, _globe),
		"radar": _com_radar,
		"chart": _com_chart,
		"end": _com_end,
	}
	await CommandConsoleProgram.new().run(_console, host)
	_rules.store_state()


## The console's RADAR: the vector radar over the flight, to its X. With the radar
## shot away it draws nothing and goes straight back.
func _com_radar() -> void:
	_console.close()
	if not RadarRules.works():
		RadarRules.back()
		return
	_radar.open()
	await _radar.closed


## The console's GALAXY MAP, to its Space, or to its "Y".
func _com_chart() -> void:
	_console.close()
	_com_waiting = true
	_chart.open(true)
	await _chart.closed
	_com_waiting = false


## The console's END: true to go on with the game.
func _com_end() -> bool:
	return await EndProgram.new().run(_console, get_tree().quit)


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
				_overlay.target = null
			_combat.defender_destroyed()
			_combat.start(true)
			_make_debris()
		CombatRules.Outcome.DAMAGED:
			AudioManager.play_alarm()
			_say("DAMAGE TO THE SHIP.")
			_combat.start(true)
		CombatRules.Outcome.SHIP_DESTROYED:
			AudioManager.play_destruction()
			AudioManager.engine_off()
			_flash_screen(1.0)
			_overlay.message = "YOUR SHIP HAS BEEN DESTROYED!!"
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
				_flash_later(0.12 * i, 0.35)
			if event["medium"]:
				_flash_screen(0.7)
				AudioManager.play_hit_medium()
		"fighter":
			_effects.fighter(event["from"], event["step"], event["steps"], event["strafes"], event["shot_down"])


## A light flash of damage after `delay`, with its thump.
func _flash_later(delay: float, strength: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_inside_tree():
		_flash_screen(strength)
		AudioManager.play_hit_light()


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
		AudioManager.play_destruction()
		AudioManager.engine_off()
		_flash_screen(1.0)
		_overlay.message = "YOUR SHIP HAS BEEN DESTROYED!!"
		_said_for = 1e9
		_dead = true
		return
	_jumping = true
	AudioManager.play_jump()
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
	_overlay.message = text
	_said_for = 2.5


# --- the world ---


func _environment() -> void:
	var environment := Environment.new()
	if _rules.in_atmosphere:
		var sky := Sky.new()
		_sky_material = ProceduralSkyMaterial.new()
		_sky_material.sky_top_color = Color(0.16, 0.36, 0.74)
		_sky_material.sky_horizon_color = Color(0.66, 0.80, 0.95)
		_sky_material.ground_horizon_color = Color(0.66, 0.80, 0.95)
		_sky_material.ground_bottom_color = Color(0.45, 0.58, 0.72)
		_sky_material.sky_curve = 0.22
		_sky_material.sun_angle_max = 28.0
		_sky_material.sun_curve = 0.12
		sky.sky_material = _sky_material
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.66, 0.80, 0.95)
		environment.fog_density = 0.000035
		_fog = environment
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.10, 0.12, 0.18)
	environment.ambient_light_energy = 0.9
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
	_make_clouds()


## A layer of cloud over the ground, at 2200: the way out of the atmosphere
## (4000) goes up through it and out into the clear above.
func _make_clouds() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 90000.0
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/clouds.gdshader")
	material.set_shader_parameter("seed", float(GameState.current_planet + 1))
	material.set_shader_parameter("sun_direction", FlightRules.place(SUN))
	material.set_shader_parameter("layer_height", CLOUD_HEIGHT)
	_clouds = MeshInstance3D.new()
	_clouds.mesh = plane
	_clouds.material_override = material
	_clouds.position.y = CLOUD_HEIGHT
	_clouds.extra_cull_margin = 90000.0
	add_child(_clouds)


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


## The cloud layer under the eye, and the sky going dark as the ship climbs out.
func _update_atmosphere() -> void:
	if _clouds == null:
		return
	_clouds.position.x = _rules.x
	_clouds.position.z = -_rules.z
	if _sky_material != null:
		var up := clampf((_rules.y - 1500.0) / 2500.0, 0.0, 1.0) # thin air from 1500 to 4000
		_sky_material.sky_top_color = Color(0.16, 0.36, 0.74).lerp(Color(0.0, 0.01, 0.04), up)
		_sky_material.sky_horizon_color = Color(0.66, 0.80, 0.95).lerp(Color(0.10, 0.18, 0.34), up)
		_sky_material.ground_horizon_color = _sky_material.sky_horizon_color
		_fog.fog_light_color = _sky_material.sky_horizon_color
		_fog.fog_density = lerpf(0.000035, 0.000012, up)


func _update_camera() -> void:
	var eye := FlightRules.place(Vector3(_rules.x, _rules.y, _rules.z))
	var basis := FlightRules.camera_basis(_rules.pitch, _rules.bank, _rules.heading)
	if _shake > 0.001:
		var jolt := Vector3(randf() - 0.5, randf() - 0.5, 0.0) * _shake * 0.06
		basis = basis * Basis.from_euler(jolt)
		_shake = move_toward(_shake, 0.0, get_process_delta_time() * 1.6)
	_camera.transform = Transform3D(basis, eye)
	if _sky != null:
		_sky.position = eye


# --- the panel ---


func _update_hud() -> void:
	_overlay.pitch = _rules.pitch
	_overlay.bank = _rules.bank
	_overlay.speed = _rules.speed
	_overlay.energy = GameState.ship_energy
	# the original's read-outs: X Y Z halved, heading and pitch as degrees (a unit * 1.41)
	_overlay.nav = [roundi(_rules.x / 2.0), roundi(_rules.y / 2.0), roundi(_rules.z / 2.0),
			roundi(_rules.heading * 1.41), roundi(_rules.pitch * 1.41), roundi(_rules.bank * 1.41)]
