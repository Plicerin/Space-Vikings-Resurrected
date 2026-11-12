extends Node3D
## What the fighting looks like: the laser's two bolts, a missile flying on a
## flame and smoke trail and bursting, the flash of a hit, a fighter swooping
## across the view and the turrets answering it. The rules decide what happens
## (scripts/rules/combat_rules.gd) and hand over events; this plays them in
## Godot's own way: tweens with easing, particles with ramps and curves,
## additive glow and short-lived lights, not the original's flicker.

const Craft = preload("res://scripts/world/craft.gd")

signal flashed(strength: float)
signal shaken(strength: float)

## Seconds to a step of a fighter's pass, and to a step of a missile's flight.
const FIGHTER_STEP := 0.09
const MISSILE_STEP := 0.04

const FLAME := Color(1.0, 0.62, 0.2)
const GREEN := Color(0.45, 1.0, 0.55)
const RED := Color(1.0, 0.3, 0.25)

var camera: Camera3D

var _glow_texture: GradientTexture2D
var _ring_texture: GradientTexture2D


func _ready() -> void:
	_glow_texture = _radial([0.0, 0.4, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	_ring_texture = _radial([0.0, 0.62, 0.8, 0.9, 1.0], [Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)])


# --- the ship's laser --------------------------------------------------------


## Two bolts from the bottom corners to a point ahead: a bright core in a wider
## halo, a flare where each leaves, a flicker of light.
func laser() -> void:
	for side in [-1.0, 1.0]:
		var from := _ahead(Vector3(side * 1.9, -1.1, -1.5))
		_bolt(from, _ahead(Vector3(0.0, 0.0, -420.0)), GREEN, 0.3, 0.12)
		_flare(from, GREEN, 1.6)
	_light(_ahead(Vector3(0.0, -1.0, -3.0)), GREEN, 2.5, 18.0, 0.2)


# --- the missile ---------------------------------------------------------------


## A missile from the ship along `direction` for `steps` steps of 160 units,
## bursting at the end if it hit. It leaves slowly and gathers speed, rolling on
## its way, a flame behind it and a smoke trail left in the air.
func missile(direction: Vector3, steps: int, hit: bool) -> void:
	var start := camera.global_position + camera.global_transform.basis * Vector3(0.0, -0.9, -3.0)
	var end := camera.global_position + direction * 160.0 * steps
	var rocket := Node3D.new()
	add_child(rocket)
	rocket.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), start)
	var body := MeshInstance3D.new()
	body.mesh = Craft.missile()
	body.scale = Vector3.ONE * 3.0
	body.material_override = Craft.material(Color(0.82, 0.84, 0.88))
	rocket.add_child(body)
	var light := OmniLight3D.new()
	light.light_color = FLAME
	light.light_energy = 2.0
	light.omni_range = 80.0
	light.position = Vector3(0.0, 0.0, 3.0)
	rocket.add_child(light)
	rocket.add_child(_exhaust(Vector3(0.0, 0.0, 2.6), true))
	rocket.add_child(_exhaust(Vector3(0.0, 0.0, 2.6), false))
	var flight := create_tween()
	flight.set_parallel(true)
	flight.tween_property(rocket, "global_position", end, steps * MISSILE_STEP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(body, "rotation:z", TAU * 3.0, steps * MISSILE_STEP)
	flight.chain().tween_callback(_finish_rocket.bind(rocket))
	if hit:
		flight.tween_callback(explosion.bind(end, 260.0))


## Stops a rocket's engine and lets its trail thin out before the node goes.
func _finish_rocket(rocket: Node3D) -> void:
	for child in rocket.get_children():
		if child is CPUParticles3D:
			(child as CPUParticles3D).emitting = false
		elif child is MeshInstance3D or child is OmniLight3D:
			child.visible = false
	get_tree().create_timer(1.6).timeout.connect(rocket.queue_free)


## The engine's flame (additive, short) or its smoke (grey, long); both leave
## their particles in the world, so that the trail stays where it was made.
func _exhaust(at: Vector3, flame: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.position = at
	particles.local_coords = false
	particles.amount = 36 if flame else 40
	particles.lifetime = 0.3 if flame else 1.3
	particles.direction = Vector3(0, 0, 1)
	particles.spread = 6.0 if flame else 12.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 26.0 if flame else 12.0
	particles.scale_amount_min = 4.0 if flame else 5.0
	particles.scale_amount_max = 7.0 if flame else 9.0
	var ramp := Gradient.new()
	if flame:
		ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.45, 0.1, 0.8), Color(0.5, 0.1, 0.05, 0.0)])
		ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	else:
		ramp.colors = PackedColorArray([Color(0.6, 0.6, 0.6, 0.0), Color(0.55, 0.55, 0.58, 0.45), Color(0.3, 0.3, 0.33, 0.0)])
		ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	particles.color_ramp = ramp
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.5))
	growth.add_point(Vector2(1.0, 0.2 if flame else 1.8))
	particles.scale_amount_curve = growth
	particles.mesh = _sprite(_glow_texture, flame)
	particles.emitting = true
	return particles


# --- bursts ----------------------------------------------------------------------


## A fireball with a white flash, a shockwave ring, sparks and a pulse of light;
## `size` is about the radius it reaches.
func explosion(at: Vector3, size: float) -> void:
	var flash := _sprite_node(Color(1.0, 0.95, 0.8, 1.0), size * 1.6, true)
	add_child(flash)
	flash.global_position = at
	var burst := create_tween()
	burst.set_parallel(true)
	burst.tween_property(flash, "scale", Vector3.ONE * 1.5, 0.14).from(Vector3.ONE * 0.3).set_ease(Tween.EASE_OUT)
	burst.tween_property(flash, "transparency", 1.0, 0.18).from(0.0)
	burst.chain().tween_callback(flash.queue_free)
	var ring := _sprite_node(Color(1.0, 0.75, 0.4, 0.9), size * 2.4, true, _ring_texture)
	add_child(ring)
	ring.global_position = at
	var wave := create_tween()
	wave.set_parallel(true)
	wave.tween_property(ring, "scale", Vector3.ONE, 0.55).from(Vector3.ONE * 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	wave.tween_property(ring, "transparency", 1.0, 0.55).from(0.0)
	wave.chain().tween_callback(ring.queue_free)
	_burst(at, size, 54, 0.95, Color(1.0, 0.85, 0.45), true) # the fire
	_burst(at, size, 24, 1.6, Color(0.3, 0.28, 0.28), false) # the smoke that follows
	_sparks(at, size)
	_light(at, Color(1.0, 0.7, 0.35), 8.0, size * 7.0, 0.7)
	shaken.emit(clampf(size / 260.0, 0.15, 1.0))
	flashed.emit(clampf(size / 400.0, 0.1, 0.6))


func _burst(at: Vector3, size: float, count: int, seconds: float, tint: Color, fire: bool) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = seconds
	particles.explosiveness = 0.92 if fire else 0.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = size * 0.08
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = size * 0.25
	particles.initial_velocity_max = size * (1.1 if fire else 0.6)
	particles.damping_min = size * 0.6
	particles.damping_max = size * 1.0
	particles.scale_amount_min = size * (0.5 if fire else 0.45)
	particles.scale_amount_max = size * (1.1 if fire else 0.9)
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.4))
	growth.add_point(Vector2(0.35, 1.0))
	growth.add_point(Vector2(1.0, 0.6 if fire else 1.2))
	particles.scale_amount_curve = growth
	var ramp := Gradient.new()
	if fire:
		ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.45, 0.55), Color(1.0, 0.5, 0.12, 0.5), Color(0.7, 0.16, 0.04, 0.34), Color(0.15, 0.08, 0.06, 0.0)])
		ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
	else:
		ramp.colors = PackedColorArray([Color(0.25, 0.2, 0.18, 0.0), Color(tint, 0.16), Color(0.15, 0.15, 0.17, 0.0)])
		ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	particles.color_ramp = ramp
	particles.mesh = _sprite(_glow_texture, fire)
	add_child(particles)
	particles.global_position = at
	particles.emitting = true
	get_tree().create_timer(seconds + 0.6).timeout.connect(particles.queue_free)


func _sparks(at: Vector3, size: float) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.amount = 36
	particles.lifetime = 0.9
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = size * 1.2
	particles.initial_velocity_max = size * 3.2
	particles.damping_min = size * 1.2
	particles.damping_max = size * 2.2
	particles.scale_amount_min = size * 0.025
	particles.scale_amount_max = size * 0.06
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 1.0, 0.85, 1.0), Color(1.0, 0.6, 0.2, 0.8), Color(1.0, 0.3, 0.1, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	particles.color_ramp = ramp
	particles.mesh = _sprite(_glow_texture, true)
	add_child(particles)
	particles.global_position = at
	particles.emitting = true
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)


# --- fighters ----------------------------------------------------------------------


## A fighter's pass: `from` and `step` are the original's screen (x 10 to 270,
## y 10 to 120), `strafes` the steps at which it fires (and the turret that
## answers, 0 for none, and whether it was shot down). It sweeps in a curve,
## nearer as it crosses, banking into the turn.
func fighter(from: Vector2, step: Vector2, steps: int, strafes: Array, shot_down: bool) -> void:
	var craft := Node3D.new()
	camera.add_child(craft)
	var body := MeshInstance3D.new()
	body.mesh = Craft.fighter()
	body.scale = Vector3.ONE * 16.0
	var materials := Craft.fighter_materials()
	for surface in materials.size():
		body.set_surface_override_material(surface, materials[surface])
	craft.add_child(body)
	_navigation_lights(craft)
	for side in [-1.0, 1.0]: # the engines
		var engine := _exhaust(Vector3(side * 0.42, -0.02, 1.35) * 16.0, true)
		engine.amount = 20
		engine.scale_amount_min = 4.0
		engine.scale_amount_max = 7.0
		engine.initial_velocity_max = 40.0
		engine.local_coords = false
		craft.add_child(engine)
	craft.position = _place(from, 0.0)
	var by_step := {}
	for strafe: Dictionary in strafes:
		by_step[strafe["step"]] = strafe
	var tween := create_tween()
	var at := from
	for i in steps:
		var strafe: Dictionary = by_step.get(i, {})
		if not strafe.is_empty():
			tween.tween_callback(_strafe.bind(craft, strafe))
		if strafe.get("shot_down", false):
			tween.tween_callback(_tumble.bind(craft))
			tween.tween_interval(FIGHTER_STEP * 4.0)
			tween.tween_callback(_shot_down.bind(craft))
			return
		at += step
		var progress := float(i + 1) / float(steps)
		var to := _place(at, progress)
		tween.tween_callback(_steer.bind(craft, to))
		tween.tween_property(craft, "position", to, FIGHTER_STEP).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(craft.queue_free)


## Turns a fighter to face where it is going and rolls it into the turn.
func _steer(craft: Node3D, to: Vector3) -> void:
	if not is_instance_valid(craft):
		return
	var heading := to - craft.position
	if heading.length() < 0.01:
		return
	var facing := Basis.looking_at(heading.normalized(), Vector3.UP)
	var roll := clampf(-heading.x / maxf(heading.length(), 0.01) * 1.1, -0.8, 0.8)
	var target := (facing * Basis(Vector3(0, 0, 1), roll)).get_rotation_quaternion()
	var turn := create_tween()
	turn.tween_method(func(t: float) -> void:
		if is_instance_valid(craft):
			craft.quaternion = craft.quaternion.slerp(target, t), 0.0, 1.0, FIGHTER_STEP * 1.5).set_ease(Tween.EASE_OUT)


## A fighter fires on the ship: two bolts from its wings across to the ship, which
## flash the screen and shake it; and a turret's answer, if there is one.
func _strafe(craft: Node3D, strafe: Dictionary) -> void:
	if not is_instance_valid(craft):
		return
	var target := _ahead(Vector3(0.0, -2.0, -6.0))
	for side in [-1.0, 1.0]:
		var muzzle := craft.to_global(Vector3(side * 1.6, 0.0, -0.3) * 16.0)
		_flare(muzzle, RED, 7.0)
		_bolt(muzzle, target + Vector3(side * 0.8, 0.0, 0.0), RED, 0.22, 0.12, 0.17)
	get_tree().create_timer(0.17).timeout.connect(_hit_ship.bind(target))
	var turret: float = strafe.get("turret", 0.0)
	if turret > 0.0:
		for offset in [-20.0, 20.0]:
			var from := _ahead(_place(Vector2(turret + offset, 123.0), 0.0) * 0.012 + Vector3(0.0, -0.4, 0.0))
			_bolt(from, craft.global_position, GREEN, 0.2, 0.08, 0.16)
			_flare(from, GREEN, 0.9)


func _hit_ship(at: Vector3) -> void:
	_flare(at, RED, 2.6)
	flashed.emit(0.25)
	shaken.emit(0.25)


## Hit by the turrets: it tumbles, trailing smoke and fire, before it goes.
func _tumble(craft: Node3D) -> void:
	if not is_instance_valid(craft):
		return
	var spin := create_tween()
	spin.set_parallel(true)
	spin.tween_property(craft, "rotation", craft.rotation + Vector3(2.4, 1.1, 5.5), FIGHTER_STEP * 4.0).set_ease(Tween.EASE_IN)
	spin.tween_property(craft, "position", craft.position + Vector3(0.0, -18.0, 22.0), FIGHTER_STEP * 4.0).set_ease(Tween.EASE_IN)
	craft.add_child(_exhaust(Vector3.ZERO, false))


func _shot_down(craft: Node3D) -> void:
	if is_instance_valid(craft):
		explosion(craft.global_position, 60.0)
		craft.queue_free()


# --- small parts -----------------------------------------------------------------


## A bolt of light from `from` to `to`: it travels there in `travel` seconds as a
## short bright streak, then fades. Core and halo, additive.
func _bolt(from: Vector3, to: Vector3, color: Color, seconds: float, width: float, travel := 0.0) -> void:
	var direction := (to - from).normalized()
	var length := from.distance_to(to)
	var streak := minf(length, 18.0 if travel > 0.0 else length)
	var bolt := Node3D.new()
	add_child(bolt)
	bolt.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), from)
	for layer in 2:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width * (1.0 if layer == 0 else 3.2), width * (1.0 if layer == 0 else 3.2), streak)
		mesh.mesh = box
		mesh.material_override = _emissive(Color(1, 1, 1, 0.95) if layer == 0 else Color(color, 0.35))
		mesh.position = Vector3(0, 0, -streak / 2.0)
		bolt.add_child(mesh)
	var tween := create_tween()
	if travel > 0.0:
		tween.tween_property(bolt, "global_position", to, travel)
		tween.tween_callback(bolt.queue_free)
	else:
		tween.tween_property(bolt, "scale", Vector3(0.15, 0.15, 1.0), seconds).set_ease(Tween.EASE_IN)
		tween.tween_callback(bolt.queue_free)


## A soft round flash of light, at once and gone.
func _flare(at: Vector3, color: Color, size: float) -> void:
	var node := _sprite_node(Color(color, 0.9).lightened(0.3), size, true)
	add_child(node)
	node.global_position = at
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector3.ONE * 1.6, 0.16).from(Vector3.ONE * 0.5)
	tween.tween_property(node, "transparency", 1.0, 0.16).from(0.0)
	tween.chain().tween_callback(node.queue_free)


func _light(at: Vector3, color: Color, energy: float, light_range: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	add_child(light)
	light.global_position = at
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds).set_ease(Tween.EASE_OUT)
	tween.tween_callback(light.queue_free)


## A billboard sprite: a quad that always faces the camera, additive or blended.
func _sprite_node(color: Color, size: float, additive: bool, texture: Texture2D = null) -> Sprite3D:
	var node := Sprite3D.new()
	node.texture = texture if texture != null else _glow_texture
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.shaded = false
	node.modulate = color
	node.pixel_size = size / 64.0
	node.transparent = true
	node.double_sided = true
	node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	if additive:
		node.material_override = _sprite_material(node.texture, true)
	return node


func _sprite(texture: Texture2D, additive: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _sprite_material(texture, additive)
	return quad


func _sprite_material(texture: Texture2D, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true # the particles' own sizes
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = texture
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _radial(offsets: Array, colors: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


## Red to port, green to starboard, on the wingtips, blinking out of step.
func _navigation_lights(craft: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var light := _sprite_node(RED if side < 0.0 else GREEN, 5.0, true)
		light.position = Vector3(side * 1.85, -0.04, 0.8) * 16.0
		craft.add_child(light)
		var blink := light.create_tween().set_loops()
		blink.tween_property(light, "modulate:a", 0.15, 0.35)
		blink.tween_property(light, "modulate:a", 1.0, 0.35)
		if side > 0.0:
			blink.pause()
			light.modulate.a = 0.6


## A point of the original's 3D window on a plane ahead of the camera: nearer as
## `progress` (0 to 1) goes on, as a fighter swoops across.
func _place(point: Vector2, progress: float) -> Vector3:
	var depth := lerpf(620.0, 440.0, sin(progress * PI * 0.5))
	return Vector3((point.x - 140.0) / 130.0 * depth * 0.62, (65.0 - point.y) / 55.0 * depth * 0.30, -depth)


func _ahead(local: Vector3) -> Vector3:
	return camera.global_position + camera.global_transform.basis * local


func _emissive(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m
