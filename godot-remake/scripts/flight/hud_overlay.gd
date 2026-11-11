extends Control
## What the flight panel shows besides its bars: the target bracket (where
## the defender is, how far, or an arrow to the edge toward it), the
## attitude gauge (horizon by pitch and bank, the orbit ring) and the bottom panel: speed, turn, vert
## and energy gauges, the readout and the damage-control lamps. Drawn over the 3D view;
## native_flight.gd feeds it each frame.

const ComRules = preload("res://scripts/rules/com_rules.gd")

const GREEN := Color(0.1, 0.95, 0.3)
const AMBER := Color(1.0, 0.75, 0.15)
const RED := Color(1.0, 0.25, 0.2)
const TARGET := Color(1.0, 0.6, 0.2)
const BULB := preload("res://assets/shaders/bulb.gdshader")
const BALL := preload("res://assets/shaders/ball.gdshader")
const RING := preload("res://assets/shaders/ring.gdshader")
const PLASTIC := preload("res://assets/shaders/plastic.gdshader")
const GLASS := preload("res://assets/shaders/glass.gdshader")
const SWITCHES := preload("res://scripts/flight/switch_panel.gd")
const BlockFont = preload("res://scripts/flight/block_font.gd")
const AMBER_TEXT := Color(1.0, 0.69, 0.0) ## an 80s terminal's amber
const GAUGE_RADIUS := 52.0
const GAUGE_LETTERS := 7 ## the size of a damage lamp's lettering
const ALERT := preload("res://assets/shaders/alert.gdshader")
const TIGHT := 0.8 ## letters on a lamp's arc, closer than their usual spacing
const PANEL_HEIGHT := 150.0

var camera: Camera3D
var target: Node3D ## null when there is none
var pitch := 0.0 ## the flight's own units, 256 to the circle
var bank := 0.0
var speed := 0.0
var energy := 0.0
var nav: Array = [0, 0, 0, 0, 0, 0] ## X, Y, Z, heading, pitch, bank, as the panel shows them
var message := "" ## what the display says, for a while, over its page
var page: Array = [] ## lines another part of the flight (the radar) has put on the display
var hide_target := false ## the target bracket is not drawn (the radar is up)
enum Mode { IDLE, NAV, HELP }
var mode := Mode.IDLE
## World units to the figures the panel shows (the readouts halve the original's).
var range_scale := 0.5

var _bulbs: Array[ColorRect] = []
var _bulb_next := 0
var _ball: ColorRect
var _ring: ColorRect
var _plastic: ColorRect
var _glass: ColorRect
var _trail := {} ## per line of the display: its text now, the text before, and when it changed
var _switches: Control
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
	_glass = ColorRect.new()
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.material = ShaderMaterial.new()
	(_glass.material as ShaderMaterial).shader = GLASS
	add_child(_glass)
	_switches = SWITCHES.new()
	add_child(_switches)
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
	for i in range(_bulb_next, _bulbs.size()):
		_bulbs[i].visible = false


func _draw_target() -> void:
	if hide_target or camera == null or target == null or not is_instance_valid(target):
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
	if _ring == null:
		_ring = ColorRect.new()
		_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ring_material := ShaderMaterial.new()
		ring_material.shader = RING
		_ring.material = ring_material
		_ring.show_behind_parent = true
		add_child(_ring)
	var in_orbit := not GameState.in_atmosphere
	_ring.position = centre - Vector2.ONE * GAUGE_RADIUS * 1.5
	_ring.size = Vector2.ONE * GAUGE_RADIUS * 3.0
	var ring_material := _ring.material as ShaderMaterial
	ring_material.set_shader_parameter("radius", GAUGE_RADIUS * 1.13 / (GAUGE_RADIUS * 1.5))
	ring_material.set_shader_parameter("lit", 1.0 if in_orbit else 0.0)
	var badge := centre + Vector2(1.0, 1.0).normalized() * GAUGE_RADIUS * 1.13
	draw_circle(badge, 10.0, Color(0.03, 0.035, 0.04))
	draw_set_transform(badge, 0.0, Vector2(0.5, 0.5))
	_icon_orbit(Vector2.ZERO, Color(0.35, 0.8, 1.0) if in_orbit else Color(0.35, 0.8, 1.0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
	_display(Rect2(w * 0.012, top + 10.0, w * 0.385, PANEL_HEIGHT - 20.0))
	# TURN with SPEED and ENERGY tucked under it, VERT standing tall beside
	var column := w * 0.412
	_dial(font, "TURN", Rect2(column, top + 24.0, w * 0.088, 26.0), (bank + 48.0) / 95.0, false)
	_bar(font, "SPEED", Rect2(column, top + 74.0, w * 0.088, 8.0), speed / 120.0, false)
	_bar(font, "ENERGY", Rect2(column, top + 108.0, w * 0.088, 8.0), energy / 63.0, false)
	# VERT: the nose up is the top
	_dial(font, "VERT", Rect2(w * 0.513, top + 12.0, 26.0, PANEL_HEIGHT - 28.0), (-pitch + 61.0) / 120.0, true)
	_switches.position = Vector2(w * 0.562, top + 8.0)
	# damage control
	var box := Rect2(w * 0.672, top + 8.0, w * 0.318, PANEL_HEIGHT - 16.0)
	_damage_box = box
	_plastic.position = box.position
	_plastic.size = box.size
	(_plastic.material as ShaderMaterial).set_shader_parameter("panel_size", box.size)
	_damage_lamps = ComRules.lamps()
	for i in _damage_lamps.size():
		var lamp: Array = _damage_lamps[i]
		_bulb(_lamp_centre(i), 9.0, RED if lamp[2] else GREEN, true)


func _lamp_centre(index: int) -> Vector2:
	return _damage_box.position + Vector2(_damage_box.size.x * (1.0 + 2.0 * (index % 6)) / 12.0, 84.0 + (index / 6) * 36.0)


## The raised amber lettering on the plastic: drawn on `_letters`, a node over it.
func _draw_letters() -> void:
	var font := get_theme_default_font()
	_draw_damage(_letters, _damage_box)
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


## An old radio's tuning dial: a window with a scale printed behind it and a
## small plastic triangle that slides in it, about a third of the window's
## width across. `amount` is 0 to 1 along the window; `vertical` for VERT.
func _dial(font: Font, name: String, window: Rect2, amount: float, vertical: bool) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if vertical:
		_stacked(font, name, Vector2(window.end.x + 8.0, window.get_center().y), 8.0)
	else:
		_raised_string(self, font, window.position + Vector2(0.0, -6.0), name, GAUGE_LETTERS)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.03, 0.05, 0.04)
	frame.set_corner_radius_all(4)
	frame.set_border_width_all(2)
	frame.border_color = Color(0.3, 0.32, 0.36)
	frame.anti_aliasing = true
	draw_style_box(frame, window)
	var inner := window.grow(-3.0)
	# the scale, lit from behind: a tick every eighth, the middle longer
	var along := inner.size.y if vertical else inner.size.x
	var across := inner.size.x if vertical else inner.size.y
	for i in 9:
		var t := i / 8.0
		var length := across * (0.42 if i == 4 else 0.28)
		var tick := Color(1.0, 0.8, 0.35, 0.9 if i == 4 else 0.6)
		if vertical:
			var y := inner.position.y + t * along
			draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + length, y), tick, 1.0 if i != 4 else 1.5, true)
		else:
			var x := inner.position.x + t * along
			draw_line(Vector2(x, inner.position.y), Vector2(x, inner.position.y + length), tick, 1.0 if i != 4 else 1.5, true)
	# the pointer: a triangle of red plastic, a third of the window across
	var size_px := across / 3.0 + 2.0
	var base := size_px * 1.1
	var point: Vector2
	var corners: PackedVector2Array
	if vertical:
		var y := inner.position.y + amount * along
		point = Vector2(inner.position.x + across * 0.45, y)
		corners = PackedVector2Array([point, point + Vector2(size_px, -base / 2.0), point + Vector2(size_px, base / 2.0)])
	else:
		var x := inner.position.x + amount * along
		point = Vector2(x, inner.position.y + across * 0.45)
		corners = PackedVector2Array([point, point + Vector2(-base / 2.0, size_px), point + Vector2(base / 2.0, size_px)])
	var shadow := PackedVector2Array()
	for corner in corners:
		shadow.append(corner + Vector2(1.2, 1.2))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.5))
	draw_colored_polygon(corners, Color(0.9, 0.18, 0.1))
	draw_line(corners[0], corners[1], Color(1.0, 0.65, 0.5, 0.9), 1.2, true) # the edge catching the light
	draw_line(corners[0], corners[2], Color(0.45, 0.05, 0.03, 0.9), 1.0, true)
	# the glass over it all
	draw_rect(Rect2(window.position + Vector2(3.0, 3.0), Vector2(window.size.x - 6.0, (window.size.y - 6.0) * 0.45)), Color(1.0, 1.0, 1.0, 0.05))


## A gauge: its name above, an outlined track, filled from the left to
## `amount` (0 to 1), or a marker on a centre mark when `centred`.
func _bar(font: Font, name: String, track: Rect2, amount: float, centred: bool) -> void:
	_raised_string(self, font, track.position + Vector2(0.0, -6.0), name, GAUGE_LETTERS)
	draw_rect(track, Color(GREEN, 0.5), false, 1.0)
	amount = clampf(amount, 0.0, 1.0)
	if centred:
		var middle := track.position.x + track.size.x / 2.0
		draw_line(Vector2(middle, track.position.y - 3.0), Vector2(middle, track.end.y + 3.0), GREEN, 1.0)
		draw_rect(Rect2(track.position.x + amount * track.size.x - 2.0, track.position.y - 3.0, 4.0, track.size.y + 6.0), GREEN)
	else:
		draw_rect(Rect2(track.position, Vector2(track.size.x * amount, track.size.y)), GREEN)


func _icon_orbit(c: Vector2, colour: Color) -> void:
	var ring := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		ring.append(c + Vector2(cos(a) * 15.0, sin(a) * 6.0).rotated(-0.45))
	draw_polyline(ring, colour, 2.0, true)
	draw_circle(c, 6.0, colour)
	draw_circle(c + Vector2(15.0, 0.0).rotated(-0.45) * 0.9, 2.5, colour)


## The damage scanner, in the damage-control panel on `canvas`: its name over
## a row of LEDs. With the damage alert on, a bright patch with a fading tail sweeps along and back, in amber.
func _draw_damage(canvas: CanvasItem, box: Rect2) -> void:
	var count := 24
	var frame_rect := Rect2(box.position + Vector2(10.0, 22.0), Vector2(box.size.x - 20.0, 28.0))
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.02, 0.022, 0.026, 0.9)
	frame.set_corner_radius_all(8)
	frame.set_border_width_all(2)
	frame.border_color = Color(0.22, 0.24, 0.28, 0.8)
	frame.anti_aliasing = true
	canvas.draw_style_box(frame, frame_rect)
	var alert := GameState.damage_alert_active
	var sweep := 0.0
	var direction := 1.0
	if alert:
		var phase := fmod(Time.get_ticks_msec() / 1000.0 * 1.4, 2.0)
		sweep = (phase if phase < 1.0 else 2.0 - phase) * (count - 1)
		direction = 1.0 if phase < 1.0 else -1.0
	var pitch_px := (frame_rect.size.x - 24.0) / count
	for i in count:
		var level := 0.0
		if alert:
			var behind := (sweep - i) * direction # positive on the tail
			level = exp(-pow(behind / 1.0, 2.0)) if behind <= 0.0 else exp(-behind / 2.4)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.1, 0.03).lerp(Color(1.0, 0.62, 0.05), level)
		style.set_corner_radius_all(2)
		style.anti_aliasing = true
		if level > 0.25:
			style.shadow_color = Color(1.0, 0.6, 0.05, 0.35 * level)
			style.shadow_size = 4
		canvas.draw_style_box(style, Rect2(frame_rect.position + Vector2(12.0 + i * pitch_px, 7.0), Vector2(pitch_px - 3.0, 14.0)))
	_raised_string(canvas, get_theme_default_font(), box.position + Vector2(12.0, 16.0), "DAMAGE", 11)


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


## Letters one over the next, centred on `at` vertically, for a gauge that stands up.
func _stacked(font: Font, text: String, at: Vector2, pitch_px: float) -> void:
	var top := at.y - pitch_px * (text.length() - 1) / 2.0
	for i in text.length():
		var width := font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, GAUGE_LETTERS).x
		_raised_string(self, font, Vector2(at.x - width / 2.0, top + i * pitch_px + GAUGE_LETTERS / 2.0), text[i], GAUGE_LETTERS)


# --- the display: a green panel that can be written to ---

const COLUMNS := 40 ## the Apple's text screen
const HELP := [
	"ARROWS  STICK          1 2 3 4  SPEED",
	"SPACE   FIRE           A  AUTO",
	"S  SHIELD              W  WEAPON",
	"B  ALERT               C  CONSOLE",
	"R  RADAR               H  JUMP",
	"N  NAV DATA            F1 KEYS",
]
const LED := Color(0.25, 1.0, 0.45)


## NAV and HELP are shown by their keys and go again on the same key; a message
## written to the display is shown over either for a while.
func show_mode(wanted: Mode) -> void:
	mode = Mode.IDLE if mode == wanted else wanted


func _display(rect: Rect2) -> void:
	var window := StyleBoxFlat.new()
	window.bg_color = Color(0.01, 0.03, 0.015)
	window.set_corner_radius_all(10)
	window.set_border_width_all(3)
	window.border_color = Color(0.22, 0.24, 0.27)
	window.anti_aliasing = true
	draw_style_box(window, rect)
	_glass.position = rect.position + Vector2(3.0, 3.0)
	_glass.size = rect.size - Vector2(6.0, 6.0)
	(_glass.material as ShaderMaterial).set_shader_parameter("panel_size", _glass.size)
	# the Apple's text screen: 40 columns across, and as many rows of eight dots as fit
	var inner := rect.grow(-14.0)
	var scale := inner.size.x / (COLUMNS * BlockFont.ADVANCE)
	var pitch_px := (BlockFont.HEIGHT + 1.0) * scale # a blank dot row between lines
	var rows := int(inner.size.y / pitch_px)
	var lines: Array
	if message != "":
		lines = BlockFont.wrap(message, scale, inner.size.x)
	elif not page.is_empty():
		lines = page
	elif mode == Mode.NAV:
		lines = _nav_lines()
	elif mode == Mode.HELP:
		lines = HELP
	else:
		lines = [GameState.STAR_NAMES[GameState.current_planet], "IN ORBIT" if not GameState.in_atmosphere else "IN THE ATMOSPHERE",
				"", columns("N  NAV DATA", "F1 KEYS")]
	_write(lines.slice(0, rows), inner.position, scale, pitch_px)
	# a faint scan over the glass
	for line in range(int(rect.position.y) + 4, int(rect.end.y) - 2, 3):
		draw_line(Vector2(rect.position.x + 3.0, line), Vector2(rect.end.x - 3.0, line), Color(0.0, 0.0, 0.0, 0.16), 1.0)


## Lines of the block lettering, `scale` pixels to the dot.
func _write(lines: Array, at: Vector2, scale: float, pitch_px: float) -> void:
	for i in 8:
		_crt("line%d" % i, lines[i] if i < lines.size() else "", at + Vector2(0.0, i * pitch_px), scale, 1.0)


## The position and the headings: the numbers big, their names small.
func _nav_lines() -> Array:
	var going := "" if GameState.target_planet < 0 else " > %s" % GameState.STAR_NAMES[GameState.target_planet]
	return [
		columns("X %d" % nav[0], "HEADING %d" % nav[3]),
		columns("Y %d" % nav[1], "PITCH %d" % nav[4]),
		columns("Z %d" % nav[2], "BANK %d" % nav[5]),
		"%s%s" % [GameState.STAR_NAMES[GameState.current_planet], going],
		columns("SPEED %d" % roundi(speed), "ENERGY %d" % roundi(energy)),
		columns("SHIELD %d" % roundi(GameState.ship_shield), "HULL %d" % roundi(GameState.ship_hull)),
	]


## Two columns on the text screen's forty: `right` starts at the twenty-first.
static func columns(left: String, right: String, width := 20) -> String:
	return left.rpad(width).left(width) + right


## One line of the display, as a phosphor draws it: lit at a brightness that
## flickers a little, and when its text changes the old text fades away over a
## moment instead of going at once.
func _crt(key: String, text: String, at: Vector2, scale: float, strength: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var entry: Array = _trail.get(key, [text, "", -10.0])
	if entry[0] != text:
		entry = [text, entry[0], now]
	_trail[key] = entry
	var flicker := 1.0 - 0.04 * absf(sin(now * 37.0) * sin(now * 11.3))
	var colour := Color(LED.r * flicker * strength, LED.g * flicker * strength, LED.b * flicker * strength)
	var fade: float = 1.0 - (now - float(entry[2])) / 0.12
	if fade > 0.0 and entry[1] != "":
		BlockFont.draw(self, entry[1], at, scale, Color(colour, 0.25 * fade))
	BlockFont.draw(self, text, at, scale, colour)
