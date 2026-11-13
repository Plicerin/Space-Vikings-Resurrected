extends RefCounted
## The planet's map and the flat frame laid on it where the ship goes down. The map is the same
## noise the planet's and the ground's shaders read (assets/shaders/planet.gdshader,
## ground.gdshader), so the continents seen from orbit are the land flown over, and what is built
## on the land (the cities) stands on land and not in the sea.
##
## The planet is one sphere: its radius PLANET_RADIUS (in the ground's units) is the anchor of the
## sizes. The ground the ship flies over is a flat frame touching it at `site` (a direction from
## the planet's centre): `w`, a place on it (east and south of the site), is a place on the sphere,
## and the frame's up is the sphere's up where the ship is.

const SCALE := 0.00018
const SEA := 0.5
const PLANET_RADIUS := 450000.0

var map_seed := 1.0
var site := Vector3(0.0, 0.0, 1.0)
var east := Vector3.RIGHT
var south := Vector3.BACK


func _init(for_seed: float, at_site: Vector3) -> void:
	map_seed = for_seed
	site = at_site.normalized()
	east = Vector3.UP.cross(site)
	east = east.normalized() if east.length() > 0.001 else Vector3.RIGHT
	south = east.cross(site) # east, up (the site) and south are right-handed


# --- the frame on the sphere ---------------------------------------------------


## The direction from the planet's centre to the place `w` of the frame.
func ground_point(w: Vector2) -> Vector3:
	return (site + (east * w.x + south * w.y) / PLANET_RADIUS).normalized()


## The place of the frame under the direction `n` from the planet's centre.
func ground_coords(n: Vector3) -> Vector2:
	var d := n / n.dot(site) - site
	return Vector2(d.dot(east), d.dot(south)) * PLANET_RADIUS


## The axes of the frame at the direction `n`: east, up and south, carried round the sphere from
## the site (the shortest way).
func frame_at(n: Vector3) -> Basis:
	return Basis(Quaternion(site, n)) * Basis(east, site, south)


# --- the map ----------------------------------------------------------------------


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


## The map's height under the direction `n`: the planet's own continents (in the planet's size) and the
## coasts, islands and ridges of the ground (in the ground's own size, the same on a planet of any size).
## The sea is below SEA.
func height_at(n: Vector3) -> float:
	var broad := _noise3(n * 3.0 + Vector3.ONE * map_seed) * 0.6 + _noise3(n * 7.0) * 0.3 + _noise3(n * 15.0) * 0.1
	var p := n * PLANET_RADIUS * SCALE
	var local := _noise3(p * 3.0 + Vector3.ONE * map_seed) * 0.55 + _noise3(p * 9.0) * 0.28 + _noise3(p * 31.0) * 0.12 + _noise3(p * 97.0) * 0.05
	return broad * 0.6 + local * 0.4


## Low, dry land with room round it, at the place `w` of the frame: where a city can stand.
func is_building_land(w: Vector2) -> bool:
	var h := height_at(ground_point(w))
	return h > SEA + 0.035 and h < SEA + 0.17
