extends Control
## What the flight panel shows besides its bars: the target bracket (where
## the defender is, how far, or an arrow to the edge toward it), the
## attitude gauge (horizon by pitch and bank) and the ship's systems as
## lamps (green, amber below 60, red below 25). Drawn over the 3D view;
## native_flight.gd feeds it each frame.

const SYSTEMS := [
	["SHLD", "ship_shield"], ["ENG1", "ship_engine1"], ["ENG2", "ship_engine2"], ["COMP", "ship_computer"],
	["RADR", "ship_radar"], ["ENV", "ship_env_control"], ["HULL", "ship_hull"], ["HYPR", "ship_hyperdrive"],
	["MSL", "ship_missile_system"], ["LASR", "ship_laser"], ["NAV", "ship_nav_computer"],
]
const GREEN := Color(0.1, 0.95, 0.3)
const AMBER := Color(1.0, 0.75, 0.15)
const RED := Color(1.0, 0.25, 0.2)
const TARGET := Color(1.0, 0.6, 0.2)
const GAUGE_RADIUS := 52.0

var camera: Camera3D
var target: Node3D ## null when there is none
var pitch := 0.0 ## the flight's own units, 256 to the circle
var bank := 0.0
## World units to the figures the panel shows (the readouts halve the original's).
var range_scale := 0.5


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_target()
	_draw_gauge()
	_draw_systems()


func _draw_target() -> void:
	if camera == null or target == null or not is_instance_valid(target):
		return
	var at := target.global_position
	var range_units := camera.global_position.distance_to(at) * range_scale
	var font := get_theme_default_font()
	var middle := size / 2.0
	var text := "DEFENDER  %d" % roundi(range_units)
	if camera.is_position_behind(at):
		var away := (camera.global_transform.basis.inverse() * (at - camera.global_position))
		_edge_arrow(Vector2(away.x, -away.y), text, font)
		return
	var screen := camera.unproject_position(at)
	if screen.x > 40.0 and screen.y > 40.0 and screen.x < size.x - 40.0 and screen.y < size.y - 40.0:
		var half := 22.0
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var c: Vector2 = screen + corner * half
			draw_line(c, c - Vector2(corner.x * 9.0, 0.0), TARGET, 2.0)
			draw_line(c, c - Vector2(0.0, corner.y * 9.0), TARGET, 2.0)
		draw_string(font, screen + Vector2(-half, half + 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TARGET)
	else:
		_edge_arrow(screen - middle, text, font)


func _edge_arrow(direction: Vector2, text: String, font: Font) -> void:
	if direction.length() < 0.001:
		direction = Vector2.DOWN
	var middle := size / 2.0
	var dir := direction.normalized()
	var spot := middle + dir * minf(middle.x - 130.0, middle.y - 130.0)
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([spot + dir * 16.0, spot - dir * 10.0 + side * 12.0, spot - dir * 10.0 - side * 12.0]), TARGET)
	draw_string(font, spot + Vector2(-50.0, 34.0 if dir.y < 0.5 else -22.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TARGET)


## A ball: the horizon tilts with the bank and slides with the nose.
func _draw_gauge() -> void:
	var centre := Vector2(size.x - 80.0, 80.0)
	draw_circle(centre, GAUGE_RADIUS, Color(0.03, 0.05, 0.1, 0.7))
	var tilt := -bank * TAU / 256.0
	var slide := clampf(pitch / 61.0, -1.0, 1.0) * GAUGE_RADIUS * 0.8
	var along := Vector2.RIGHT.rotated(tilt)
	var down := Vector2.DOWN.rotated(tilt)
	var horizon := centre + down * slide
	var reach := sqrt(maxf(GAUGE_RADIUS * GAUGE_RADIUS - slide * slide, 0.0))
	draw_line(horizon - along * reach, horizon + along * reach, Color(0.5, 0.8, 1.0), 2.0)
	draw_arc(centre, GAUGE_RADIUS, 0.0, TAU, 48, Color(0.5, 0.8, 1.0, 0.8), 2.0)
	draw_line(centre + Vector2(-14, 0), centre + Vector2(-5, 0), GREEN, 2.0)
	draw_line(centre + Vector2(5, 0), centre + Vector2(14, 0), GREEN, 2.0)
	draw_circle(centre, 2.0, GREEN)


func _draw_systems() -> void:
	var font := get_theme_default_font()
	var at := Vector2(size.x - 120.0, 168.0)
	for i in SYSTEMS.size():
		var level: float = GameState.get(SYSTEMS[i][1])
		var colour := GREEN if level >= 60.0 else (AMBER if level >= 25.0 else RED)
		var cell := at + Vector2(0.0, i * 20.0)
		draw_circle(cell + Vector2(5.0, -5.0), 5.0, colour)
		draw_string(font, cell + Vector2(16.0, 0.0), SYSTEMS[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
