extends RefCounted
## The planet's map as the planet and the ground shaders read it
## (assets/shaders/planet.gdshader, ground.gdshader): the same noise, so that the
## continents seen from orbit are the land flown over, and what is built on the land
## (the cities) stands on land and not in the sea. `w` is a place on the ground, x and
## z in the scene's world; the ground's middle is the point `site` of the sphere (a
## direction from the planet's centre), and a radian of the sphere is PLANET_RADIUS of ground.
##
## The planet's radius is the anchor of the sizes: the atmosphere (4000 up in the original's
## units) is under a tenth of it, the ground the flight covers (the world wraps at 20000 each
## way) under half a radian each way, and the sphere seen from orbit is the same planet at
## the orbit's own scale (the orbit's units are PLANET_RADIUS over the sphere's drawn radius
## times the atmosphere's: the original's two worlds were never the one scale, and its
## teleport between them is the joint).

const SCALE := 0.00018
const SEA := 0.5
const PLANET_RADIUS := 45000.0

var map_seed := 1.0
var site := Vector3(0.0, 0.0, 1.0)
var _east := Vector3.RIGHT
var _north := Vector3.UP


func _init(for_seed: float, at_site: Vector3) -> void:
	map_seed = for_seed
	site = at_site.normalized()
	_east = Vector3.UP.cross(site)
	_east = _east.normalized() if _east.length() > 0.001 else Vector3.RIGHT
	_north = site.cross(_east)


static func _fract3(v: Vector3) -> Vector3:
	return v - v.floor()


func _hash3(p: Vector3) -> float:
	var q := _fract3(p * 0.3183099 + Vector3(0.1, 0.2, 0.3) + Vector3.ONE * map_seed * 0.137) * 17.0
	return fposmod(q.x * q.y * q.z * (q.x + q.y + q.z), 1.0)


func _noise3(p: Vector3) -> float:
	var i := p.floor()
	var f := p - i
	f = Vector3(f.x * f.x * (3.0 - 2.0 * f.x), f.y * f.y * (3.0 - 2.0 * f.y), f.z * f.z * (3.0 - 2.0 * f.z))
	var a := lerpf(_row(i, 0.0, f), _row(i + Vector3(0, 1, 0), 0.0, f), f.y)
	var b := lerpf(_row(i, 1.0, f), _row(i + Vector3(0, 1, 0), 1.0, f), f.y)
	return lerpf(a, b, f.z)


## Two corners of a cell, `z_step` along z, blended along x.
func _row(corner: Vector3, z_step: float, f: Vector3) -> float:
	var base := corner + Vector3(0.0, 0.0, z_step)
	return lerpf(_hash3(base), _hash3(base + Vector3(1, 0, 0)), f.x)


func _hash2(p: Vector2) -> float:
	var q := Vector2(p.x * 0.3183099 + map_seed * 0.137, p.y * 0.3678794 + map_seed * 0.137)
	q = Vector2(q.x - floorf(q.x), q.y - floorf(q.y)) * 17.0
	return fposmod(q.x * q.y * (q.x + q.y), 1.0)


func _noise2(p: Vector2) -> float:
	var i := Vector2(floorf(p.x), floorf(p.y))
	var f := p - i
	f = Vector2(f.x * f.x * (3.0 - 2.0 * f.x), f.y * f.y * (3.0 - 2.0 * f.y))
	var a := lerpf(_hash2(i), _hash2(i + Vector2(1, 0)), f.x)
	var b := lerpf(_hash2(i + Vector2(0, 1)), _hash2(i + Vector2(1, 1)), f.x)
	return lerpf(a, b, f.y)


## The map's height at `w`: the planet's own continents, with local relief on them. The sea is
## below SEA.
func height(w: Vector2) -> float:
	var n := (site + (_east * w.x + _north * w.y) / PLANET_RADIUS).normalized()
	var h := _noise3(n * 3.0 + Vector3.ONE * map_seed) * 0.6 + _noise3(n * 7.0) * 0.3 + _noise3(n * 15.0) * 0.1
	var p := w * SCALE
	return h + (_noise2(p * 31.0) - 0.5) * 0.10 + (_noise2(p * 97.0) - 0.5) * 0.05


## Low, dry land with room round it: where a city can stand.
func is_building_land(w: Vector2) -> bool:
	var h := height(w)
	return h > SEA + 0.035 and h < SEA + 0.17
