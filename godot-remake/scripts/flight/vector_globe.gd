extends Control
## A planet as a vector globe, for the ground forces: a circle, the outline of
## a sphere, with the planet's cities projected on it in 3D as points of light,
## front and back (a filled circle on this side, an open one on the far side,
## as on the attitude ball). No land, no sea, no grid. The lights are the enemy's, red,
## and as the landing force wins them they change colour, a few at a time
## from where it came down, like flags taken in a capture-the-flag game: the
## ones on the edge of the fight flicker between the two. `capture` is how
## much has been taken, 0 to 1.
##
## The lights are the game's own cluster of points round the planet
## (assets/a2_3d1/planet_0.bin), as many of them as the planet's technology
## has cities (the same as the planet in the flight).

const DisplayList = preload("res://scripts/world/display_list.gd")

const CITIES := [0, 14, 40, 90, 144] ## as the planet in the flight has
const CLUSTER_RADIUS := 1500.0
const PHOSPHOR := Color(0.7, 1.0, 0.82)
const ENEMY := Color(1.0, 0.27, 0.2)
const OURS := Color(0.4, 1.0, 0.6)

## How much of the planet is taken, 0 to 1.
var capture := 0.0
## Where the force came down: a direction on the globe.
var landing := Vector3(0.35, 0.25, 0.9).normalized()
var radius_fraction := 0.34

var _lights := PackedVector3Array() ## in the order they are taken
var _count := 0
var _tech := -1
var _turn := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load()


func _process(delta: float) -> void:
	_turn += delta
	queue_redraw()


## The planet's lights, nearest the landing first.
func _load() -> void:
	var cluster := PackedVector3Array()
	for point in DisplayList.load_file("planet_0.bin").points:
		if point.length() < CLUSTER_RADIUS:
			cluster.append(Vector3(point.x, point.y, -point.z).normalized())
	var ordered := Array(cluster)
	ordered.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(landing) < b.distance_to(landing))
	_lights = PackedVector3Array(ordered)
	_tech = -1


func _draw() -> void:
	var tech := int(GameState.planet_tech[GameState.current_planet])
	_count = mini(CITIES[clampi(tech, 0, 4)], _lights.size())
	var centre := size / 2.0
	var radius := minf(size.x, size.y) * radius_fraction
	var flicker := 1.0 - 0.04 * absf(sin(_turn * 31.0) * sin(_turn * 9.7))
	var spin := _turn * 0.22
	var tilt := 0.38
	_wire(centre, radius, spin, tilt, flicker)
	var taken := capture * _count
	for i in _count:
		var rotated := _rotate(_lights[i], spin, tilt)
		var colour := OURS
		if i >= int(taken) + 3:
			colour = ENEMY
		elif i >= int(taken): # the edge of the fight: the flags going over
			colour = ENEMY if sin(_turn * 13.0 + i * 1.7) > 0.0 else OURS
		var front := rotated.z > 0.0
		var at := centre + Vector2(rotated.x, -rotated.y) * radius
		var lit := Color(colour.r * flicker, colour.g * flicker, colour.b * flicker)
		# as on the attitude ball: a filled circle on this side, an open one on the far side
		if front:
			draw_circle(at, 8.0, Color(colour, 0.12))
			draw_circle(at, 3.4, lit)
		else:
			draw_arc(at, 3.2, 0.0, TAU, 16, Color(lit, 0.75), 1.3, true)


## The sphere is only its outline: a circle of light. The lights are projected
## through it, the far side dimmer, so that it reads as a ball.
func _wire(centre: Vector2, radius: float, _spin: float, _tilt: float, flicker: float) -> void:
	var ink := Color(PHOSPHOR.r * flicker, PHOSPHOR.g * flicker, PHOSPHOR.b * flicker)
	draw_arc(centre, radius, 0.0, TAU, 96, Color(ink, 0.9), 1.6, true)
	draw_arc(centre, radius, 0.0, TAU, 96, Color(ink, 0.14), 7.0, true)


## A point on the unit sphere turned about the vertical and tipped.
func _rotate(p: Vector3, spin: float, tilt: float) -> Vector3:
	var x := p.x * cos(spin) + p.z * sin(spin)
	var z := -p.x * sin(spin) + p.z * cos(spin)
	var y := p.y * cos(tilt) - z * sin(tilt)
	var z2 := p.y * sin(tilt) + z * cos(tilt)
	return Vector3(x, y, z2)
