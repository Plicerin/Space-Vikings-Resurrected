extends Node
## Holds scripts/rules/radar_rules.gd to the real game. tools/mame/
## radar_live.lua took a new game from flight into RADAR, and through the
## I.D. of every kind of defender (a type of 0 to 4 poked into 38205), with
## every character the programs drew in analysis/live/radar/radar_radar_ids_
## glyphs.log. Here each I.D. screen is put together from its characters and
## compared with what the rules say for the defender it was for; and the
## radar with the radar shot away (radar_radar_dead.log) is not one that
## works.
##
##   godot --headless --path godot-remake res://tests/check_radar_rules.tscn
##
## Spaces are not compared.

const RadarRules = preload("res://scripts/rules/radar_rules.gd")

const REFERENCE := "../analysis/live/radar/"

var _bad := 0
var _checked := 0


func _ready() -> void:
	_ids()
	_dead()
	_routing()
	print("radar rules: %d compared, %d wrong" % [_checked, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


func _plain(text: String) -> String:
	return text.replace(" ", "")


func _ids() -> void:
	var log := FileAccess.open(REFERENCE + "radar_radar_ids.log", FileAccess.READ).get_as_text().split("\n")
	# the defender's type at each "get id": poked before, or the flight's
	var tier := 0
	var stops: Array = [] # [ms, tier]
	var last_get := 0.0
	for line: String in log:
		if line.contains("-- in flight") and line.contains(" 38205="):
			tier = int(line.split(" 38205=")[1].split(" ")[0])
		elif line.contains("-- poke 38205="):
			tier = int(line.split("38205=")[1].strip_edges())
		elif line.contains("-- get id") and not line.contains("-- get id_") or line.contains("-- get id_"):
			stops.append([float(line), tier])
	var glyphs := _glyphs(REFERENCE + "radar_radar_ids_glyphs.log")
	var from := 0.0
	for stop: Array in stops:
		var cells := {}
		for g: Array in glyphs:
			if g[0] > from and g[0] <= stop[0] and [1060, 1061, 1065, 1070].has(g[1]) and g[2] != 32:
				if not cells.has(Vector2i(g[3], g[4])):
					cells[Vector2i(g[3], g[4])] = String.chr(g[2])
		var rows := _rows(cells)
		var expected: Array = RadarRules.ship_id_text(RadarRules.ship_id_program(stop[1])).map(_plain)
		_checked += 1
		_check("the I.D. of a defender of type %d: %s" % [stop[1], str(expected)], rows == expected)
		if rows != expected:
			print("       the real game: %s" % str(rows))
		from = stop[0]


func _rows(cells: Dictionary) -> Array:
	var by_row := {}
	for key: Vector2i in cells:
		if not by_row.has(key.y):
			by_row[key.y] = {}
		by_row[key.y][key.x] = cells[key]
	var tops: Array = by_row.keys()
	tops.sort()
	var out: Array = []
	for y: int in tops:
		var columns: Array = by_row[y].keys()
		columns.sort()
		var text := ""
		for x: int in columns:
			text += by_row[y][x]
		out.append(text)
	return out


func _glyphs(path: String) -> Array:
	var out: Array = []
	for line: String in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		var w := line.split(" ", false)
		if w.size() >= 7:
			out.append([float(w[0]), int(w[1]), int(w[2]), int(w[3]), int(w[4])])
	return out


## The radar shot away (38195 poked to 0): the program loads and runs the
## one that ran it, drawing nothing and asking nothing.
func _dead() -> void:
	var log := FileAccess.open(REFERENCE + "radar_radar_dead.log", FileAccess.READ).get_as_text()
	var asked := log.contains("-- get radar ")
	_checked += 1
	GameState.start_new_game()
	GameState.ship_radar = 0.0
	_check("with the radar poked to 0 it does not work, and the real game never asks for a key (%s)" % str(asked),
			not RadarRules.works() and not asked)
	GameState.ship_radar = 100.0
	_checked += 1
	_check("with it whole it works", RadarRules.works())
	GameState.ship_radar = 0.7
	_checked += 1
	_check("a radar of a fraction of a point is none (the byte is 0)", not RadarRules.works())


func _routing() -> void:
	GameState.start_new_game()
	GameState.handover = 2
	_checked += 1
	_check("from the console's 3 it goes back to the console, the mark taken", RadarRules.back() == RadarRules.Goes.COM and GameState.handover == 0)
	_checked += 1
	_check("from the flight it goes back to the flight", RadarRules.back() == RadarRules.Goes.FLIGHT)
	_checked += 1
	_check("a defender of type 2 gets the light cruiser's, the others their own",
			RadarRules.ship_id_program(2) == 3 and RadarRules.ship_id_program(1) == 1 and RadarRules.ship_id_program(4) == 4
			and RadarRules.ship_id_program(0) == 0 and RadarRules.ship_id_program(3) == 3)


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1
