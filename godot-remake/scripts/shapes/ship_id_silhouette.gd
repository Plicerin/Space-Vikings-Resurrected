extends RefCounted
## Loader for the SHIP no N I.D..bas inline DATA-point 2D silhouettes --
## the *third* ship-rendering system in this game (see
## scripts/shapes/a2_3d1_model.gd's doc comment for the other two).
## Pre-decoded to JSON by tools/decode_ship_id.py. No class_name, per
## this project's convention -- see godot-remake/README.md.

const PATHS := {
	1: "res://assets/ship_id/SHIP no 1.json",
	3: "res://assets/ship_id/SHIP no 3.json",
	4: "res://assets/ship_id/SHIP no 4.json",
}


## Returns the segment list for one tier (each {"type": "move"|"line",
## "x": float, "y": float}, already in the original's literal HGR pixel
## coordinates) or an empty array for tier 0 -- correct, not a loading
## failure: SHIP no 0 I.D..bas has no DATA statements at all ("THERE IS
## NO STARSHIP IN THIS SYSTEM").
static func load_segments(tier: int) -> Array:
	var path: String = PATHS.get(tier, "")
	if path == "" or not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null:
		return []
	return data.get("segments", [])
