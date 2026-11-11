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
const BULB := preload("res://assets/shaders/bulb.gdshader")
const BALL := preload("res://assets/shaders/ball.gdshader")
const PLASTIC := preload("res://assets/shaders/plastic.gdshader")
const AMBER_TEXT := Color(1.0, 0.69, 0.0) ## an 80s terminal's amber
const GAUGE_RADIUS := 52.0
const TILE := 46.0
const ALERT := preload("res://assets/shaders/alert.gdshader")
const TIGHT := 0.8 ## letters on a lamp's arc, closer than their usual spacing
const PANEL_HEIGHT := 140.0

var camera: Camera3D
var target: Node3D ## null when there is none
var pitch := 0.0 ## the flight's own units, 256 to the circle
var bank := 0.0
var speed := 0.0
var energy := 0.0
var readout := ""
## World units to the figures the panel shows (the readouts halve the original's).
var range_scale := 0.5

var _bulbs: Array[ColorRect] = []
var _bulb_next := 0
var _ball: ColorRect
var _plastic: ColorRect
var _alert: ColorRect
var _letters: Control
var _damage_box := Rect2()
var _damage_lamps: Array = []


func _ready() -> void:
	# the alert border, under everything else
	_alert = ColorRect.new()
	_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert.material = ShaderMaterial.new()
	(_alert.material as ShaderMaterial).shader = ALERT
	_alert.show_behind_parent = true
	_alert.visible = false
	add_child(_alert)
	# the damage-control panel: plastic, then the raised lettering on it (bulbs are added over both)
	_plastic = ColorRect.new()
	_plastic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PLASTIC
	_plastic.material = material
	add_child(_plastic)
	_letters = Control.new()
	_letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letters.draw.connect(_draw_letters)
	add_child(_letters)


func _process(_delta: float) -> void:
	queue_redraw()
	if _letters != null:
		_letters.queue_redraw()


func _draw() -> void:
	_bulb_next = 0
	_update_alert()
	_draw_target()
	_draw_gauge()
	_draw_panel()
	_draw_lamps()
	for i in range(_bulb_next, _bulbs.size()):
		_bulbs[i].visible = false


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


## The attitude ball, by shader, and the pointers on it.
func _draw_gauge() -> void:
	var centre := Vector2(size.x - 80.0, 80.0)
	if _ball == null:
		_ball = ColorRect.new()
		_ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = BALL
		_ball.material = material
		_ball.show_behind_parent = true # the pointers are drawn over it
		add_child(_ball)
	_ball.position = centre - Vector2.ONE * GAUGE_RADIUS * 1.1
	_ball.size = Vector2.ONE * GAUGE_RADIUS * 2.2
	var material := _ball.material as ShaderMaterial
	material.set_shader_parameter("pitch", pitch * TAU / 256.0)
	material.set_shader_parameter("bank", bank * TAU / 256.0)
	draw_line(centre + Vector2(-16, 0), centre + Vector2(-6, 0), GREEN, 2.0, true)
	draw_line(centre + Vector2(6, 0), centre + Vector2(16, 0), GREEN, 2.0, true)
	draw_circle(centre, 2.0, GREEN)
	_ball_marker(centre, Vector3.ZERO, Color(0.35, 0.8, 1.0)) # the planet
	if target != null and is_instance_valid(target):
		_ball_marker(centre, target.global_position, TARGET) # the defender


func _draw_panel() -> void:
	var font := get_theme_default_font()
	var top := size.y - PANEL_HEIGHT
	draw_rect(Rect2(0.0, top, size.x, PANEL_HEIGHT), Color(0.02, 0.03, 0.05, 0.92))
	draw_rect(Rect2(0.0, top, size.x, PANEL_HEIGHT), Color(0.9, 0.9, 0.9), false, 2.0)
	var w := size.x
	_bar(font, "SPEED", Rect2(w * 0.015, top + 34.0, w * 0.165, 8.0), speed / 120.0, false)
	_bar(font, "TURN", Rect2(w * 0.21, top + 34.0, w * 0.13, 8.0), (bank + 48.0) / 95.0, true)
	# VERT: the nose up is the top
	var vert := Rect2(w * 0.35, top + 14.0, 14.0, 50.0)
	draw_string(font, Vector2(vert.end.x + 8.0, vert.get_center().y + 4.0), "VERT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GREEN)
	draw_rect(vert, Color(GREEN, 0.5), false, 1.0)
	draw_line(Vector2(vert.position.x - 3.0, vert.get_center().y), Vector2(vert.end.x + 3.0, vert.get_center().y), GREEN, 1.0)
	var nose := clampf((-pitch + 61.0) / 120.0, 0.0, 1.0)
	draw_rect(Rect2(vert.position.x - 3.0, vert.position.y + nose * vert.size.y - 2.0, vert.size.x + 6.0, 4.0), GREEN)
	_bar(font, "ENERGY", Rect2(w * 0.42, top + 34.0, w * 0.15, 8.0), energy / 63.0, false)
	var lines := readout.split("\n")
	for i in lines.size():
		draw_string(font, Vector2(w * 0.015, top + 78.0 + i * 18.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GREEN)
	# damage control
	var box := Rect2(w * 0.605, top + 8.0, w * 0.385, PANEL_HEIGHT - 16.0)
	_damage_box = box
	_plastic.position = box.position
	_plastic.size = box.size
	(_plastic.material as ShaderMaterial).set_shader_parameter("panel_size", box.size)
	_damage_lamps = ComRules.lamps()
	for i in _damage_lamps.size():
		var lamp: Array = _damage_lamps[i]
		_bulb(_lamp_centre(i), 9.0, RED if lamp[2] else GREEN, true)


func _lamp_centre(index: int) -> Vector2:
	return _damage_box.position + Vector2(_damage_box.size.x * (1.0 + 2.0 * (index % 6)) / 12.0, 54.0 + (index / 6) * 44.0)


## The raised amber lettering on the plastic: drawn on `_letters`, a node over it.
func _draw_letters() -> void:
	var font := get_theme_default_font()
	_raised_string(_letters, font, _damage_box.position + Vector2(10.0, 17.0), "DAMAGE CONTROL", 11)
	for i in _damage_lamps.size():
		_arc_text(_letters, font, _lamp_name(i, _damage_lamps[i]), _lamp_centre(i), 17.0)


## Lettering that stands out of the surface: a shadow below and to the right, a
## highlight on the upper left edge, and the amber between.
func _raised_string(canvas: CanvasItem, font: Font, at: Vector2, text: String, size_px: int) -> void:
	canvas.draw_string(font, at + Vector2(0.9, 1.1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.0, 0.0, 0.0, 0.75))
	canvas.draw_string(font, at + Vector2(-0.5, -0.6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, AMBER_TEXT.lightened(0.55))
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, AMBER_TEXT)


## What a lamp is called: COM's top line (the engines' number after ENG);
## the colour says the rest (NO/GO, DMG, LOW).
func _lamp_name(index: int, lamp: Array) -> String:
	var first: String = lamp[0].strip_edges()
	return "ENG %s" % first if index < 2 else first


## `text` along the top of a circle: its middle straight above `centre`, each
## letter turned to stand on the arc, raised.
func _arc_text(canvas: CanvasItem, font: Font, text: String, centre: Vector2, radius: float) -> void:
	var size_px := 7
	var widths := []
	var total := 0.0
	for character in text:
		var width := font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * TIGHT
		widths.append(width)
		total += width
	var angle := -PI / 2.0 - total / radius / 2.0
	for i in text.length():
		var half: float = widths[i] / radius / 2.0
		angle += half
		canvas.draw_set_transform(centre + Vector2(cos(angle), sin(angle)) * radius, angle + PI / 2.0, Vector2.ONE)
		_raised_string(canvas, font, Vector2(-widths[i] / TIGHT / 2.0, 0.0), text[i], size_px)
		angle += half
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


## The telltales along the top left, as on a car's dash: A and M (one lit),
## the missile and the laser (one lit), the shield and orbit lamps; then the
## damage lamp, a row of segments that sweeps to and fro while the damage
## alert is on, as a scanner or a meter does.
func _draw_lamps() -> void:
	var font := get_theme_default_font()
	var blue := Color(0.35, 0.8, 1.0)
	var x := 16.0
	var y := 14.0
	var tiles := [
		["A", GameState.autopilot_active, GREEN], ["M", not GameState.autopilot_active, GREEN], null,
		["missile", GameState.missile_mode_active, TARGET], ["laser", not GameState.missile_mode_active, blue], null,
		["shield", GameState.shields_up, GREEN], ["orbit", not GameState.in_atmosphere, blue],
	]
	for tile in tiles:
		if tile == null:
			x += 22.0
			continue
		var rect := Rect2(x, y, TILE, TILE)
		_tile(rect, tile[2], tile[1])
		var colour: Color = tile[2] if tile[1] else Color(tile[2], 0.2)
		var middle := rect.get_center()
		match tile[0]:
			"missile": _icon_missile(middle, colour)
			"laser": _icon_laser(middle, colour)
			"shield": _icon_shield(middle, colour)
			"orbit": _icon_orbit(middle, colour)
			_:
				var width := font.get_string_size(tile[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
				draw_string(font, middle + Vector2(-width / 2.0, 9.0), tile[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, colour)
		x += TILE + 8.0
	_draw_rolling(Vector2(x + 22.0, y + TILE / 2.0 - 11.0))


## A dark rounded tile with a coloured rim and glow when it is lit.
func _tile(rect: Rect2, colour: Color, lit: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.05, 0.85)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(colour, 0.9) if lit else Color(0.28, 0.3, 0.33, 0.8)
	style.anti_aliasing = true
	if lit:
		style.shadow_color = Color(colour, 0.5)
		style.shadow_size = 8
	draw_style_box(style, rect)


func _icon_missile(c: Vector2, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(14, 0), c + Vector2(6, -4), c + Vector2(-9, -4), c + Vector2(-9, 4), c + Vector2(6, 4)]), colour)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -4), c + Vector2(-15, -10), c + Vector2(-5, -4)]), colour)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 4), c + Vector2(-15, 10), c + Vector2(-5, 4)]), colour)
	draw_line(c + Vector2(-11, 0), c + Vector2(-18, 0), Color(colour, colour.a * 0.6), 3.0, true)


func _icon_laser(c: Vector2, colour: Color) -> void:
	draw_line(c + Vector2(-14, 10), c + Vector2(6, -6), colour, 3.0, true)
	var tip := c + Vector2(10, -10)
	for angle in [0.0, PI / 4.0, PI / 2.0, 3.0 * PI / 4.0]:
		var spoke := Vector2(cos(angle), sin(angle)) * 7.0
		draw_line(tip - spoke, tip + spoke, colour, 2.0, true)
	draw_circle(tip, 2.5, colour)


func _icon_shield(c: Vector2, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -11), c + Vector2(11, -11), c + Vector2(11, 1), c + Vector2(0, 13), c + Vector2(-11, 1)]), colour)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -7), c + Vector2(6, -7), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)]), Color(0.04, 0.045, 0.05, 0.6))


func _icon_orbit(c: Vector2, colour: Color) -> void:
	var ring := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		ring.append(c + Vector2(cos(a) * 15.0, sin(a) * 6.0).rotated(-0.45))
	draw_polyline(ring, colour, 2.0, true)
	draw_circle(c, 6.0, colour)
	draw_circle(c + Vector2(15.0, 0.0).rotated(-0.45) * 0.9, 2.5, colour)


## Sixteen segments; with the alert on a bright patch with a fading tail sweeps
## along and back, in amber, otherwise they sit dim.
func _draw_rolling(at: Vector2) -> void:
	var count := 16
	var alert := GameState.damage_alert_active
	var sweep := 0.0
	var direction := 1.0
	if alert:
		var phase := fmod(Time.get_ticks_msec() / 1000.0 * 1.4, 2.0)
		sweep = (phase if phase < 1.0 else 2.0 - phase) * (count - 1)
		direction = 1.0 if phase < 1.0 else -1.0
	for i in count:
		var level := 0.0
		if alert:
			var behind := (sweep - i) * direction # positive on the tail
			level = exp(-pow(behind / 1.0, 2.0)) if behind <= 0.0 else exp(-behind / 2.2)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.1, 0.03).lerp(Color(1.0, 0.62, 0.05), level)
		style.set_corner_radius_all(3)
		style.anti_aliasing = true
		if level > 0.25:
			style.shadow_color = Color(1.0, 0.6, 0.05, 0.35 * level)
			style.shadow_size = 5
		draw_style_box(style, Rect2(at + Vector2(i * 15.0, 0.0), Vector2(12.0, 22.0)))


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


## A frosted LED bulb (assets/shaders/bulb.gdshader): a node of its own, so
## that it is drawn by the shader at any resolution and not out of circles.
func _bulb(centre: Vector2, radius: float, colour: Color, lit: bool) -> void:
	var node: ColorRect
	if _bulb_next < _bulbs.size():
		node = _bulbs[_bulb_next]
	else:
		node = ColorRect.new()
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = BULB
		node.material = material
		add_child(node)
		_bulbs.append(node)
	_bulb_next += 1
	var reach := radius * 1.7
	node.position = centre - Vector2(reach, reach)
	node.size = Vector2(reach, reach) * 2.0
	node.visible = true
	var material := node.material as ShaderMaterial
	material.set_shader_parameter("colour", colour)
	material.set_shader_parameter("lit", 1.0 if lit else 0.0)


## Condition 2 is yellow alert, 3 red: a glow round the edge of the screen,
## quicker for red. Green is none.
func _update_alert() -> void:
	var yellow := GameState.condition == 2
	var red := GameState.condition == 3
	_alert.visible = yellow or red
	if not _alert.visible:
		return
	_alert.position = Vector2.ZERO
	_alert.size = size
	var material := _alert.material as ShaderMaterial
	material.set_shader_parameter("colour", Color(1.0, 0.2, 0.1) if red else Color(1.0, 0.8, 0.1))
	material.set_shader_parameter("pulse_rate", 3.0 if red else 1.2)
	material.set_shader_parameter("screen_size", size)
