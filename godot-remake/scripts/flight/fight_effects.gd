extends Node3D
## What the fighting looks like: the laser's two beams, a missile flying
## and bursting, the flash of a hit, a fighter coming across the view and
## the turrets answering it. The rules decide what happens
## (scripts/rules/combat_rules.gd) and hand over events; this plays them,
## in Godot's own way (tweens on a clock, glowing meshes), not the
## original's page-flipped flicker.

const Craft = preload("res://scripts/world/craft.gd")

signal flashed(strength: float)

## Seconds to a step of a fighter's pass, and to a step of a missile's flight.
const FIGHTER_STEP := 0.09
const MISSILE_STEP := 0.04

var camera: Camera3D


## Two beams from the bottom corners to a point ahead, for a moment.
func laser() -> void:
	for side in [-1.0, 1.0]:
		_beam(_ahead(Vector3(side * 1.9, -1.1, -1.5)), _ahead(Vector3(0.0, 0.0, -400.0)), Color(0.4, 1.0, 0.5), 0.35)


## A missile from the ship along `direction` for `steps` steps of 160
## units, bursting at the end if it hit.
func missile(direction: Vector3, steps: int, hit: bool) -> void:
	var start := camera.global_position + camera.global_transform.basis * Vector3(0, -0.8, -3.0)
	var end := camera.global_position + direction * 160.0 * steps
	var rocket := _glow(Color(1.0, 0.7, 0.3), 6.0)
	add_child(rocket)
	rocket.global_position = start
	var tween := create_tween()
	tween.tween_property(rocket, "global_position", end, steps * MISSILE_STEP)
	tween.tween_callback(rocket.queue_free)
	if hit:
		tween.tween_callback(explosion.bind(end, 260.0))


func explosion(at: Vector3, size: float) -> void:
	var burst := _glow(Color(1.0, 0.75, 0.35), 1.0)
	add_child(burst)
	burst.global_position = at
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * size, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst.material_override, "albedo_color:a", 0.0, 0.7)
	tween.chain().tween_callback(burst.queue_free)


## A fighter's pass: `from` and `step` are the original's screen (x 10 to
## 270, y 10 to 120), `strafes` the steps at which it fires (and the
## turret that answers, 0 for none, and whether it was shot down).
func fighter(from: Vector2, step: Vector2, steps: int, strafes: Array, shot_down: bool) -> void:
	var craft := MeshInstance3D.new()
	craft.mesh = Craft.mesh()
	craft.material_override = Craft.material(Color(0.8, 0.35, 0.3))
	craft.scale = Vector3.ONE * 9.0
	camera.add_child(craft)
	craft.position = _screen(from)
	var tween := create_tween()
	var at := from
	var by_step := {}
	for strafe: Dictionary in strafes:
		by_step[strafe["step"]] = strafe
	for i in steps:
		var strafe: Dictionary = by_step.get(i, {})
		if not strafe.is_empty():
			tween.tween_callback(_strafe.bind(craft, strafe))
		if strafe.get("shot_down", false):
			tween.tween_interval(FIGHTER_STEP * 2.0)
			tween.tween_callback(_shot_down.bind(craft))
			return
		at += step
		tween.tween_property(craft, "position", _screen(at), FIGHTER_STEP)
	tween.tween_callback(craft.queue_free)


func _strafe(craft: Node3D, strafe: Dictionary) -> void:
	if not is_instance_valid(craft):
		return
	_beam(craft.global_position, camera.global_position + camera.global_transform.basis * Vector3(0, -2.0, -6.0),
			Color(1.0, 0.3, 0.25), 0.25)
	flashed.emit(0.25)
	var turret: float = strafe.get("turret", 0.0)
	if turret > 0.0:
		for offset in [-20.0, 20.0]:
			_beam(_ahead(_screen(Vector2(turret + offset, 123.0))), craft.global_position, Color(0.4, 1.0, 0.5), 0.3)


func _shot_down(craft: Node3D) -> void:
	if is_instance_valid(craft):
		explosion(craft.global_position, 40.0)
		craft.queue_free()


## A point of the original's 3D window on a plane ahead of the camera.
func _screen(point: Vector2) -> Vector3:
	var depth := 500.0
	return Vector3((point.x - 140.0) / 130.0 * depth * 0.62, (65.0 - point.y) / 55.0 * depth * 0.30, -depth)


func _ahead(local: Vector3) -> Vector3:
	return camera.global_position + camera.global_transform.basis * local


func _beam(from: Vector3, to: Vector3, color: Color, seconds: float) -> void:
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.06, 1.0)
	beam.mesh = box
	beam.material_override = _emissive(color)
	add_child(beam)
	var length := from.distance_to(to)
	beam.global_transform = Transform3D(Basis.looking_at((to - from).normalized(), Vector3.UP).scaled(Vector3(1, 1, length)), (from + to) / 2.0)
	var tween := create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(beam.queue_free)


func _glow(color: Color, size: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	node.mesh = sphere
	node.material_override = _emissive(color)
	return node


func _emissive(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m
