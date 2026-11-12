extends Control
## RADAR as a vector display laid over the front window, in the manner of an
## early arcade game: thin glowing lines, wire-frame craft, nothing filled. It
## is drawn live over the flight, which goes on behind it: a plan of the world
## from above (the original's units, +-20000 a side, north, the original's +z,
## at the top) with the planet, the stars, the firing box, the defender as its
## own wire-frame model and the ship as an arrow along its heading; and, with
## SPACE (or "I"), the SHIP I.D.: the defender's wire-frame, large, turning slowly at the
## side. Everything written goes on the console's display (`console.page`), as
## what the original's I.D. program says of it does. What the radar does and where it goes
## back to is scripts/rules/radar_rules.gd, held to the real game
## (tests/check_radar_rules.gd).

const RadarRules = preload("res://scripts/rules/radar_rules.gd")
const CombatRules = preload("res://scripts/rules/combat_rules.gd")
const DisplayList = preload("res://scripts/world/display_list.gd")
const BlockFont = preload("res://scripts/flight/block_font.gd")

signal closed(to_console: bool)

const WORLD := 20000.0
const PHOSPHOR := Color(0.7, 1.0, 0.82)
const AMBER := Color(1.0, 0.62, 0.2)
const CYAN := Color(0.45, 0.85, 1.0)

var identify := false

## The flight's display panel (hud_overlay.gd): the radar writes its page there.
var console: Control
var _model_lines := PackedVector3Array()
var _model_scale := 1.0
var _model_centre := Vector3.ZERO
var _model_for := -1
var _turn := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## @witness RADAR 10
## Shows the radar; with it shot away it draws nothing and goes straight back.
func open(with_id := false) -> void:
	if not RadarRules.works():
		close()
		return
	identify = with_id
	visible = true
	AudioManager.play_ping()


func close() -> void:
	visible = false
	identify = false
	_release_console()
	closed.emit(RadarRules.back() == RadarRules.Goes.COM)


## @witness RADAR 2050-2056
## @witness RADAR 2056-2059
## @witness RADAR 5000-5005
## "X" (or R, or Escape) goes back, to the console if it ran the radar; the
## I.D. of what is in orbit is "I", and "I" there is the radar again. Returns
## whether the key was the radar's.
func handle_key(key: InputEventKey) -> bool:
	if not visible or not key.pressed or key.echo:
		return false
	match key.keycode:
		KEY_X, KEY_ESCAPE, KEY_R:
			close()
		KEY_I, KEY_SPACE: # the manual's SPACE BAR scans and identifies the ship in orbit, and again returns to the radar
			identify = not identify
		_:
			return false
	return true


func _process(delta: float) -> void:
	if visible:
		position = Vector2.ZERO
		size = get_viewport_rect().size # a canvas layer has no layout to fill
		_turn += delta
		_write_console()
		queue_redraw()


# --- drawing ------------------------------------------------------------------


func _draw() -> void:
	var width := 960.0 if identify else 600.0
	var area := Rect2(size.x * 0.5 - width / 2.0, 28.0, width, size.y - PANEL_HEIGHT_CLEAR - 48.0)
	draw_rect(area, Color(0.0, 0.03, 0.02, 0.78)) # the window's glass, a little darker
	_brackets(area)
	var flicker := 1.0 - 0.04 * absf(sin(_turn * 31.0) * sin(_turn * 9.7))
	var side := minf(area.size.y - 48.0, 440.0)
	var map := Rect2(area.position + Vector2(24.0, 24.0), Vector2.ONE * side)
	if not identify:
		map.position.x = area.get_center().x - side / 2.0
	_plan(map, flicker)
	if identify:
		var big := Rect2(map.end.x + 24.0, area.position.y + 16.0, area.end.x - map.end.x - 48.0, area.size.y - 32.0)
		_ship_id(big, flicker)


## What the radar writes on the console's display: the numbers and the keys, or
## what the I.D. program says of the ship in orbit.
func _write_console() -> void:
	if console == null:
		return
	console.hide_target = true
	var columns: Callable = console.columns
	if identify:
		var text: Array = RadarRules.ship_id_text(RadarRules.ship_id_program(GameState.orbital_defender_tier))
		var lines: Array = [text[0], ""]
		lines.append_array(BlockFont.wrap(" ".join(text.slice(1)), 1.0, 40.0 * BlockFont.ADVANCE)) # the description, run on across the forty columns
		lines.append("")
		lines.append(columns.call("SPACE  RADAR", "X  CLOSE"))
		console.page = lines
		return
	var lines: Array = ["-RADAR-",
			columns.call("X %d" % (GameState.ship_x / 2), "HEADING %d" % roundi(GameState.ship_heading * 1.41)),
			columns.call("Y %d" % (GameState.ship_y / 2), "")]
	lines[2] = columns.call("Y %d" % (GameState.ship_y / 2), _defender_line())
	lines.append("Z %d" % (GameState.ship_z / 2))
	lines.append("")
	lines.append(columns.call("SPACE  SHIP I.D.", "X  CLOSE"))
	console.page = lines


func _defender_line() -> String:
	if GameState.orbital_defender_tier != 0 and not GameState.gf_planet_surrendered:
		return "DEFENDER %d" % roundi(Vector3(GameState.ship_x, GameState.ship_y, GameState.ship_z).distance_to(CombatRules.DEFENDER) / 2.0)
	return "NO DEFENDER"


func _release_console() -> void:
	if console != null:
		console.page = []
		console.hide_target = false


const PANEL_HEIGHT_CLEAR := 150.0


func _tint(colour: Color, flicker: float) -> Color:
	return Color(colour.r * flicker, colour.g * flicker, colour.b * flicker, colour.a)


## A line of light: a faint wide glow under a bright thin core.
func _vline(from: Vector2, to: Vector2, colour: Color, width := 1.6) -> void:
	draw_line(from, to, Color(colour, colour.a * 0.16), width * 4.0, true)
	draw_line(from, to, colour, width, true)


func _vpoly(points: PackedVector2Array, colour: Color, closed_loop := true, width := 1.6) -> void:
	var line := points.duplicate()
	if closed_loop:
		line.append(points[0])
	draw_polyline(line, Color(colour, colour.a * 0.16), width * 4.0, true)
	draw_polyline(line, colour, width, true)


func _brackets(area: Rect2) -> void:
	var arm := 26.0
	for corner in [[area.position, Vector2(1, 1)], [Vector2(area.end.x, area.position.y), Vector2(-1, 1)],
			[area.end, Vector2(-1, -1)], [Vector2(area.position.x, area.end.y), Vector2(1, -1)]]:
		var at: Vector2 = corner[0]
		var direction: Vector2 = corner[1]
		_vline(at, at + Vector2(arm * direction.x, 0.0), PHOSPHOR)
		_vline(at, at + Vector2(0.0, arm * direction.y), PHOSPHOR)


## @witness RADAR 2000-2042
## @witness-asm 24576, 37936
## (CALL 24576 is A2-3D1 drawing the flight's view from straight above, and
## CALL 37936 the page it draws on: the plan here is what replaces them.)
func _plan(map: Rect2, flicker: float) -> void:
	var at := func(world: Vector3) -> Vector2:
		return Vector2(map.position.x + (world.x + WORLD) / (2.0 * WORLD) * map.size.x,
				map.end.y - (world.z + WORLD) / (2.0 * WORLD) * map.size.y)
	var frame := PackedVector2Array([map.position, Vector2(map.end.x, map.position.y), map.end, Vector2(map.position.x, map.end.y)])
	_vpoly(frame, _tint(Color(PHOSPHOR, 0.55), flicker), true, 1.2)
	# a few tick marks along the edges, as on a scope
	for i in range(1, 8):
		var f := i / 8.0
		_vline(Vector2(map.position.x + f * map.size.x, map.end.y), Vector2(map.position.x + f * map.size.x, map.end.y - 6.0), Color(PHOSPHOR, 0.5), 1.0)
		_vline(Vector2(map.position.x, map.position.y + f * map.size.y), Vector2(map.position.x + 6.0, map.position.y + f * map.size.y), Color(PHOSPHOR, 0.5), 1.0)
	var centre: Vector2 = at.call(Vector3.ZERO)
	for ring in [0.25, 0.5, 0.75]: # range rings round the planet
		draw_arc(centre, ring * map.size.x * 0.5, 0.0, TAU, 64, Color(PHOSPHOR, 0.12), 1.0, true)
	# the sweep: a line turning round the planet and its fading trail
	for trail in 7:
		var angle := _turn * 1.3 - trail * 0.07
		var alpha := 0.5 * (1.0 - trail / 7.0)
		draw_line(centre, centre + Vector2(sin(angle), -cos(angle)) * map.size.x * 0.5, Color(PHOSPHOR, alpha * 0.4), 1.0, true)
	# where the defender fires from
	var near: Vector2 = at.call(Vector3(CombatRules.FIRING_X.x, 0, CombatRules.FIRING_Z.y))
	var far: Vector2 = at.call(Vector3(CombatRules.FIRING_X.y, 0, CombatRules.FIRING_Z.x))
	_dashed_box(Rect2(near, far - near), _tint(Color(AMBER, 0.55), flicker))
	# the planet: a wire sphere seen from above
	draw_arc(centre, 9.0, 0.0, TAU, 32, _tint(CYAN, flicker), 1.6, true)
	draw_arc(centre, 9.0, 0.0, TAU, 32, Color(CYAN, 0.16), 6.0, true)
	_vline(centre + Vector2(-9, 0), centre + Vector2(9, 0), CYAN, 1.0)
	_vline(centre + Vector2(0, -9), centre + Vector2(0, 9), CYAN, 1.0)
	if GameState.orbital_defender_tier != 0 and not GameState.gf_planet_surrendered:
		var spot: Vector2 = at.call(CombatRules.DEFENDER)
		_wire_icon(spot, RadarRules.ship_id_program(GameState.orbital_defender_tier), 30.0, _tint(AMBER, flicker))
	# the ship: an arrow with a notch, in the manner of the old games, along its heading
	var ship: Vector2 = at.call(Vector3(GameState.ship_x, 0, GameState.ship_z))
	var h := GameState.ship_heading * TAU / 256.0
	var ahead := Vector2(sin(h), -cos(h))
	var side := Vector2(-ahead.y, ahead.x)
	var arrow := PackedVector2Array([
		ship + ahead * 13.0, ship - ahead * 9.0 + side * 8.0, ship - ahead * 5.0, ship - ahead * 9.0 - side * 8.0,
	])
	_vpoly(arrow, _tint(PHOSPHOR, flicker), true, 1.8)
	_vline(ship + ahead * 15.0, ship + ahead * 60.0, Color(PHOSPHOR, 0.35), 1.0)


func _dashed_box(rect: Rect2, colour: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		var length := from.distance_to(to)
		var steps := int(length / 10.0)
		for s in range(0, steps, 2):
			var a := from.lerp(to, float(s) / steps)
			var b := from.lerp(to, float(s + 1) / steps)
			draw_line(a, b, colour, 1.2, true)


## The defender's wire-frame seen from above, small, at a point of the plan.
func _wire_icon(at: Vector2, program: int, extent: float, colour: Color) -> void:
	_load_model(program)
	if _model_lines.is_empty():
		_vpoly(PackedVector2Array([at + Vector2(0, -6), at + Vector2(6, 0), at + Vector2(0, 6), at + Vector2(-6, 0)]), colour)
		return
	var scale := extent / maxf(_model_scale, 1.0)
	for i in range(0, _model_lines.size(), 2):
		var a := _model_lines[i] - _model_centre
		var b := _model_lines[i + 1] - _model_centre
		_vline(at + Vector2(a.x, -a.z) * scale, at + Vector2(b.x, -b.z) * scale, colour, 1.2)


func _load_model(program: int) -> void:
	if _model_for == program:
		return
	_model_for = program
	_model_lines = DisplayList.load_file("ship_%d.bin" % program).lines
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for p in _model_lines:
		low = low.min(p)
		high = high.max(p)
	_model_centre = (low + high) / 2.0 if not _model_lines.is_empty() else Vector3.ZERO
	_model_scale = maxf(1.0, maxf((high - low).x, maxf((high - low).y, (high - low).z)) / 2.0) if not _model_lines.is_empty() else 1.0


func _ship_id(box: Rect2, flicker: float) -> void:
	var program := RadarRules.ship_id_program(GameState.orbital_defender_tier)
	_load_model(program)
	_brackets_small(box)
	if _model_lines.is_empty():
		return
	var extent := minf(box.size.x, box.size.y) * 0.46
	var scale := extent / _model_scale
	var spin := _turn * 0.6
	var tilt := 0.42
	var centre := box.get_center()
	for i in range(0, _model_lines.size(), 2):
		var a := _project(_model_lines[i] - _model_centre, spin, tilt) * scale
		var b := _project(_model_lines[i + 1] - _model_centre, spin, tilt) * scale
		_vline(centre + a, centre + b, _tint(AMBER, flicker), 1.6)


func _brackets_small(box: Rect2) -> void:
	for corner in [[box.position, Vector2(1, 1)], [Vector2(box.end.x, box.position.y), Vector2(-1, 1)],
			[box.end, Vector2(-1, -1)], [Vector2(box.position.x, box.end.y), Vector2(1, -1)]]:
		var at: Vector2 = corner[0]
		var direction: Vector2 = corner[1]
		_vline(at, at + Vector2(14.0 * direction.x, 0.0), Color(PHOSPHOR, 0.6), 1.0)
		_vline(at, at + Vector2(0.0, 14.0 * direction.y), Color(PHOSPHOR, 0.6), 1.0)


## A point of the model turned about the vertical and tipped, flat to the screen.
func _project(p: Vector3, spin: float, tilt: float) -> Vector2:
	var x := p.x * cos(spin) + p.z * sin(spin)
	var z := -p.x * sin(spin) + p.z * cos(spin)
	var y := p.y * cos(tilt) - z * sin(tilt)
	return Vector2(x, -y)
