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
## The lights are spread evenly over the sphere (a spiral of points, a little
## shaken, differently for each planet), as many as the planet's technology has
## cities (the same as the planet in the flight), so that no part of it is
## bare: what has not been taken is red wherever it is.

const CITIES := [0, 14, 40, 90, 144] ## as the planet in the flight has
const GOLDEN_ANGLE := 2.399963
const PHOSPHOR := Color(0.7, 1.0, 0.82)
const ENEMY := Color(1.0, 0.27, 0.2)
const OURS := Color(0.4, 1.0, 0.6)

## How much of the planet is taken, 0 to 1.
var capture := 0.0
## Where the force came down: a direction on the globe.
var landing := Vector3(0.35, 0.25, 0.9).normalized()
var radius_fraction := 0.36

var _lights := PackedVector3Array() ## in the order they are taken
var _count := 0
var _lit_for := Vector2i(-1, -1) ## the planet and the number of lights `_lights` is for
var _turn := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size # a canvas layer has no layout to fill
	_turn += delta
	queue_redraw()


## `count` lights over the sphere, nearest the landing first.
func _scatter(count: int, planet: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = planet * 7919 + 13
	var points: Array[Vector3] = []
	for i in count:
		var y := 1.0 - (i + 0.5) * 2.0 / count # down the sphere, round and round
		var ring := sqrt(maxf(1.0 - y * y, 0.0))
		var angle := i * GOLDEN_ANGLE
		var at := Vector3(cos(angle) * ring, y, sin(angle) * ring)
		points.append((at + Vector3(rng.randfn(0.0, 0.05), rng.randfn(0.0, 0.05), rng.randfn(0.0, 0.05))).normalized())
	points.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(landing) < b.distance_to(landing))
	_lights = PackedVector3Array(points)
	_lit_for = Vector2i(planet, count)


func _draw() -> void:
	var tech := int(GameState.planet_tech[GameState.current_planet])
	_count = CITIES[clampi(tech, 0, 4)]
	if _lit_for != Vector2i(GameState.current_planet, _count):
		_scatter(_count, GameState.current_planet)
	var centre := Vector2(size.x * 0.5, (size.y - 150.0) * 0.5)
	var radius := minf(size.x, size.y - 150.0) * radius_fraction
	draw_rect(Rect2(centre - Vector2(radius, radius) * 1.25, Vector2(radius, radius) * 2.5), Color(0.0, 0.03, 0.02, 0.7)) # the glass
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
