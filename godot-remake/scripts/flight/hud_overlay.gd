extends Control
## What the flight panel shows besides its bars: the target bracket (where
## the defender is, how far, or an arrow to the edge toward it), the
## attitude gauge (horizon by pitch and bank), the indicator lamps (autopilot,
## shields, weapon, condition, damage) and the bottom panel: speed, turn, vert
## and energy gauges, the readout and the damage-control lamps. Drawn over the 3D view;
## native_flight.gd feeds it each frame.

const ComRules = preload("res://scripts/rules/com_rules.gd")

const GREEN := Color(0.1, 0.95, 0.3)
const AMBER := Color(1.0, 0.75, 0.15)
const RED := Color(1.0, 0.25, 0.2)
const TARGET := Color(1.0, 0.6, 0.2)
const GAUGE_RADIUS := 52.0
const PANEL_HEIGHT := 118.0

var camera: Camera3D
var target: Node3D ## null when there is none
var pitch := 0.0 ## the flight's own units, 256 to the circle
var bank := 0.0
var speed := 0.0
var energy := 0.0
var readout := ""
## World units to the figures the panel shows (the readouts halve the original's).
var range_scale := 0.5


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_target()
	_draw_gauge()
	_draw_panel()
	_draw_lamps()


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
	_ball_marker(centre, Vector3.ZERO, Color(0.35, 0.8, 1.0)) # the planet
	if target != null and is_instance_valid(target):
		_ball_marker(centre, target.global_position, TARGET) # the defender


## The panel along the bottom, in the original's order (INSTRUMENTS 170-200):
## SPEED, TURN (the bank), VERT (the nose) and ENERGY gauges, the position
## and headings under them, and the damage-control lamps (COM's twelve) on
## the right.
func _draw_panel() -> void:
	var font := get_theme_default_font()
	var top := size.y - PANEL_HEIGHT
	draw_rect(Rect2(0.0, top, size.x, PANEL_HEIGHT), Color(0.02, 0.03, 0.05, 0.92))
	draw_rect(Rect2(0.0, top, size.x, PANEL_HEIGHT), Color(0.9, 0.9, 0.9), false, 2.0)
	var w := size.x
	_bar(font, "SPEED", Rect2(w * 0.015, top + 30.0, w * 0.165, 16.0), speed / 120.0, false)
	_bar(font, "TURN", Rect2(w * 0.21, top + 30.0, w * 0.13, 16.0), (bank + 48.0) / 95.0, true)
	# VERT: the nose up is the top
	var vert := Rect2(w * 0.35, top + 14.0, 14.0, 50.0)
	draw_string(font, Vector2(vert.end.x + 8.0, vert.get_center().y + 4.0), "VERT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GREEN)
	draw_rect(vert, Color(GREEN, 0.5), false, 1.0)
	draw_line(Vector2(vert.position.x - 3.0, vert.get_center().y), Vector2(vert.end.x + 3.0, vert.get_center().y), GREEN, 1.0)
	var nose := clampf((-pitch + 61.0) / 120.0, 0.0, 1.0)
	draw_rect(Rect2(vert.position.x - 3.0, vert.position.y + nose * vert.size.y - 2.0, vert.size.x + 6.0, 4.0), GREEN)
	_bar(font, "ENERGY", Rect2(w * 0.42, top + 30.0, w * 0.15, 16.0), energy / 63.0, false)
	var lines := readout.split("\n")
	for i in lines.size():
		draw_string(font, Vector2(w * 0.015, top + 78.0 + i * 18.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GREEN)
	# damage control
	var box := Rect2(w * 0.605, top + 8.0, w * 0.385, PANEL_HEIGHT - 16.0)
	draw_rect(box, Color(GREEN, 0.4), false, 1.0)
	draw_string(font, box.position + Vector2(8.0, 14.0), "DAMAGE CONTROL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GREEN)
	var lamps := ComRules.lamps()
	for i in lamps.size():
		var lamp: Array = lamps[i]
		var cell := box.position + Vector2(10.0 + (i % 4) * (box.size.x - 14.0) / 4.0, 36.0 + (i / 4) * 28.0)
		var colour := RED if lamp[2] else GREEN
		draw_circle(cell + Vector2(5.0, -4.0), 5.0, colour if lamp[2] else Color(colour, 0.7))
		draw_string(font, cell + Vector2(14.0, -8.0), lamp[0].strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, colour)
		draw_string(font, cell + Vector2(14.0, 4.0), lamp[1].strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, colour)


## A gauge: its name above, an outlined track, filled from the left to
## `amount` (0 to 1), or a marker on a centre mark when `centred`.
func _bar(font: Font, name: String, track: Rect2, amount: float, centred: bool) -> void:
	draw_string(font, track.position + Vector2(0.0, -8.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GREEN)
	draw_rect(track, Color(GREEN, 0.5), false, 1.0)
	amount = clampf(amount, 0.0, 1.0)
	if centred:
		var middle := track.position.x + track.size.x / 2.0
		draw_line(Vector2(middle, track.position.y - 3.0), Vector2(middle, track.end.y + 3.0), GREEN, 1.0)
		draw_rect(Rect2(track.position.x + amount * track.size.x - 2.0, track.position.y - 3.0, 4.0, track.size.y + 6.0), GREEN)
	else:
		draw_rect(Rect2(track.position, Vector2(track.size.x * amount, track.size.y)), GREEN)


## The panel's switches as indicator lamps along the top left: lit
## bright with a halo, or dark.
func _draw_lamps() -> void:
	var font := get_theme_default_font()
	var blue := Color(0.35, 0.8, 1.0)
	var lamps := [
		["MANUAL", not GameState.autopilot_active, GREEN],
		["AUTO", GameState.autopilot_active, GREEN],
		["ORBIT", not GameState.in_atmosphere, blue],
		["SHIELDS", GameState.shields_up, GREEN],
		["MISSILE", GameState.missile_mode_active, TARGET],
		["LASER", not GameState.missile_mode_active, blue],
		["GREEN", GameState.condition == 1, GREEN],
		["BLUE", GameState.condition == 2, blue],
		["RED", GameState.condition == 3, RED],
		["DAMAGE", GameState.damage_alert_active, AMBER],
	]
	for i in lamps.size():
		var at := Vector2(48.0 + i * 104.0, 36.0)
		var colour: Color = lamps[i][2]
		if lamps[i][1]:
			draw_circle(at, 17.0, Color(colour, 0.25))
			draw_circle(at, 11.0, colour)
		else:
			draw_arc(at, 11.0, 0.0, TAU, 24, Color(colour, 0.35), 2.0)
		var width := font.get_string_size(lamps[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, at + Vector2(-width / 2.0, 32.0), lamps[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, colour if lamps[i][1] else Color(colour, 0.4))


## Where `world_at` lies as seen from the ship, on the ball: straight ahead is
## the centre, abeam is half way out, behind is the rim (a hollow mark).
func _ball_marker(centre: Vector2, world_at: Vector3, colour: Color) -> void:
	if camera == null:
		return
	var local := camera.global_transform.basis.inverse() * (world_at - camera.global_position)
	if local.length() < 1.0:
		return
	var angle := local.angle_to(Vector3(0.0, 0.0, -1.0)) # 0 ahead, PI behind
	var across := Vector2(local.x, -local.y)
	var dir := across.normalized() if across.length() > 0.0001 else Vector2.UP
	var spot := centre + dir * (angle / PI) * (GAUGE_RADIUS - 5.0)
	if angle > PI / 2.0:
		draw_arc(spot, 5.0, 0.0, TAU, 16, colour, 2.0)
	else:
		draw_circle(spot, 5.0, colour)
