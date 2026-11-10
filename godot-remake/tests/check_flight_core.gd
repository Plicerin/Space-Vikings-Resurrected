extends SceneTree
## Holds scripts/flight/flight_core.gd to the reference model
## (tools/flight_model.py, which replays a live run of the real game):
## 40 flights of 40 passes, every angle's factors, 4000 stick cases and
## the pitch stops.
##
##   godot --headless --path godot-remake -s res://tests/check_flight_core.gd
##
## New vectors: python3 -I tools/flight_model.py vectors godot-remake/tests/flight_core_vectors.json

const FlightCore = preload("res://scripts/flight/flight_core.gd")


func _init() -> void:
	var text := FileAccess.get_file_as_string("res://tests/flight_core_vectors.json")
	var vectors: Dictionary = JSON.parse_string(text)
	var bad := 0

	var passes := 0
	for flight in vectors["flights"]:
		var start: Array = flight["start"]
		var core := FlightCore.new(int(start[0]), int(start[1]), int(start[2]))
		var atmosphere: bool = int(flight["atmosphere"]) == 1
		for p in flight["passes"]:
			passes += 1
			core.step(int(p[0]), int(p[1]), int(p[2]))
			var stored := core.stored()
			var grounded := core.sink(int(p[2])) if atmosphere else false
			var same := stored == Vector3i(int(p[3]), int(p[4]), int(p[5])) \
				and _close(core.x, p[6]) and _close(core.y, p[7]) and _close(core.z, p[8]) \
				and grounded == (int(p[9]) == 1)
			if not same:
				bad += 1
				if bad <= 10:
					print("DIFFERENT pass %s: stored %s floats %s %s %s grounded %s" % [
						p, stored, core.x, core.y, core.z, grounded])
				break

	var factors: Array = vectors["factors"]
	for angle in range(256):
		var cosine := FlightCore.basic_cos(angle, 0.25)
		var sine := FlightCore.basic_sin(angle)
		if not _close(cosine, factors[angle][0]) or not _close(sine, factors[angle][1]):
			bad += 1
			print("DIFFERENT factors at %d: %s %s, expected %s" % [angle, cosine, sine, factors[angle]])

	for s in vectors["sticks"]:
		var got := FlightCore.stick(int(s[0]), int(s[1]), int(s[2]), int(s[3]), int(s[4]), int(s[5]))
		if got[0] != int(s[6]) or got[1] != int(s[7]) or got[2] != int(s[8]) or got[3] != int(s[9]):
			bad += 1
			if bad <= 10:
				print("DIFFERENT stick %s: %s" % [s, got])

	var clamps: Array = vectors["clamps"]
	for pitch in range(256):
		if FlightCore.pitch_clamp(pitch) != int(clamps[pitch]):
			bad += 1
			print("DIFFERENT pitch stop at %d" % pitch)

	print("%d passes, 256 angles, %d stick cases, 256 pitch stops: %d different" % [
		passes, vectors["sticks"].size(), bad])
	quit(1 if bad > 0 else 0)


## The floats go through JSON text, and Godot's number parser is not
## exact to the last bit; the stored integers are compared exactly.
func _close(value: float, expected) -> bool:
	return absf(value - float(expected)) < 1e-7
