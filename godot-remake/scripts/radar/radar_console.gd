extends Control
## RADAR: a map of the world from above, with the planet, the stars, the
## defender (if there is one) and where the ship is and which way it
## points. "X" goes back to what ran it; any other key, or the button,
## goes to the I.D. of what is in orbit. What it will do and where it goes
## is scripts/rules/radar_rules.gd, held to the real game
## (tests/check_radar_rules.gd).
##
## The original's radar was the flight's own 3D view from straight above,
## drawn in two seconds a point at a time, and it is not a rule: this is a
## plan of the same world, in the original's units (+-20000 a side), north
## (the original's +z) at the top. The box the defender fires from, which
## the original never showed, is drawn faint.

const RadarRules = preload("res://scripts/rules/radar_rules.gd")
const CombatRules = preload("res://scripts/rules/combat_rules.gd")
const DisplayList = preload("res://scripts/world/display_list.gd")

const COM := "res://scenes/com.tscn"
const SHIP_ID := "res://scenes/ship_id.tscn"
const WORLD := 20000.0
const CLUSTER_RADIUS := 1500.0

const FRAME := Color(0.35, 0.35, 0.35)
const GRID := Color(0.12, 0.22, 0.14)
const GREEN := Color(0.1, 0.95, 0.3)
const ORANGE := Color(1.0, 0.42, 0.24)
const BLUE := Color(0.35, 0.8, 1.0)

var _stars := PackedVector3Array()

@onready var _map: Control = $Center/Columns/MapPanel/VBox/Map
@onready var _readout: Label = $Center/Columns/Info/VBox/Readout


func _ready() -> void:
	if not RadarRules.works(): # nothing drawn, nothing asked
		_back.call_deferred()
		return
	for point in DisplayList.load_file("planet_0.bin").points:
		if point.length() >= CLUSTER_RADIUS:
			_stars.append(point)
	_map.draw.connect(_draw_map)
	($Center/Columns/Info/VBox/Id as Button).pressed.connect(_id)
	($Center/Columns/Info/VBox/Return as Button).pressed.connect(_back)
	_readout.text = "X %d\nY %d\nZ %d\nHEADING %d" % [GameState.ship_x / 2, GameState.ship_y / 2, GameState.ship_z / 2,
			roundi(GameState.ship_heading * 1.41)]
	_map.queue_redraw()


## @witness RADAR 2050-2056
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.keycode == KEY_X or key.keycode == KEY_ESCAPE:
		_back()
	else:
		_id()


## @witness RADAR 2056-2059
func _back() -> void:
	if RadarRules.back() == RadarRules.Goes.COM:
		GameState.goto_scene(COM)
	else:
		GameState.goto_scene(GameState.flight_scene)


## @witness RADAR 5000-5005
func _id() -> void:
	GameState.goto_scene(SHIP_ID)


## The map: x across, the original's z up.
func _at(world: Vector3) -> Vector2:
	var size := _map.size
	return Vector2((world.x + WORLD) / (2.0 * WORLD) * size.x, size.y - (world.z + WORLD) / (2.0 * WORLD) * size.y)


## @witness RADAR 2000-2042
## @witness-asm 24576, 37936
## (CALL 24576 is A2-3D1 drawing the flight's view from straight above, and
## CALL 37936 the page it draws on: the plan here is what replaces them.)
func _draw_map() -> void:
	var size := _map.size
	_map.draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	for i in range(1, 8):
		var f := i / 8.0
		_map.draw_line(Vector2(f * size.x, 0), Vector2(f * size.x, size.y), GRID)
		_map.draw_line(Vector2(0, f * size.y), Vector2(size.x, f * size.y), GRID)
	_map.draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), FRAME, false, 2.0)
	# where the defender fires from
	var near := _at(Vector3(CombatRules.FIRING_X.x, 0, CombatRules.FIRING_Z.y))
	var far := _at(Vector3(CombatRules.FIRING_X.y, 0, CombatRules.FIRING_Z.x))
	_map.draw_rect(Rect2(near, far - near), Color(ORANGE, 0.35), false, 1.0)
	for star in _stars:
		_map.draw_circle(_at(star), 1.6, Color(0.8, 0.85, 1.0, 0.8))
	_map.draw_circle(_at(Vector3.ZERO), 6.0, BLUE)
	if GameState.orbital_defender_tier != 0 and not GameState.gf_planet_surrendered:
		var defender := _at(CombatRules.DEFENDER)
		_map.draw_rect(Rect2(defender - Vector2(4, 4), Vector2(8, 8)), ORANGE)
	# the ship, an arrow along its heading (0 is +z: up)
	var ship := _at(Vector3(GameState.ship_x, 0, GameState.ship_z))
	var h := GameState.ship_heading * TAU / 256.0
	var ahead := Vector2(sin(h), -cos(h))
	var side := Vector2(-ahead.y, ahead.x)
	_map.draw_colored_polygon(PackedVector2Array([ship + ahead * 11.0, ship - ahead * 6.0 + side * 6.0, ship - ahead * 3.0,
			ship - ahead * 6.0 - side * 6.0]), GREEN)
