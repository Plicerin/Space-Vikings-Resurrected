extends RefCounted
## The planet's map as the ground shader reads it (assets/shaders/ground.gdshader):
## the same noise, so that what is built on the land (the cities) stands on land and
## not in the sea. `w` is a place on the ground, x and z in the scene's world.

const SCALE := 0.00018
const SEA := 0.5


static func _hash(p: Vector2, seed: float) -> float:
	var q := Vector2(p.x * 0.3183099 + seed * 0.137, p.y * 0.3678794 + seed * 0.137)
	q = Vector2(q.x - floorf(q.x), q.y - floorf(q.y)) * 17.0
	var v := q.x * q.y * (q.x + q.y)
	return v - floorf(v)


static func _noise(p: Vector2, seed: float) -> float:
	var i := Vector2(floorf(p.x), floorf(p.y))
	var f := p - i
	f = Vector2(f.x * f.x * (3.0 - 2.0 * f.x), f.y * f.y * (3.0 - 2.0 * f.y))
	var a := lerpf(_hash(i, seed), _hash(i + Vector2(1, 0), seed), f.x)
	var b := lerpf(_hash(i + Vector2(0, 1), seed), _hash(i + Vector2(1, 1), seed), f.x)
	return lerpf(a, b, f.y)


## The map's height at `w`: the sea is below SEA.
static func height(w: Vector2, seed: float) -> float:
	var p := w * SCALE
	return _noise(p * 3.0 + Vector2(seed, seed), seed) * 0.55 + _noise(p * 9.0, seed) * 0.28 \
			+ _noise(p * 31.0, seed) * 0.12 + _noise(p * 97.0, seed) * 0.05


## Low, dry land with room round it: where a city can stand.
static func is_building_land(w: Vector2, seed: float) -> bool:
	var h := height(w, seed)
	return h > SEA + 0.035 and h < SEA + 0.17
