extends Node
## Holds scripts/rules/end_rules.gd (END.bas) to the real game.
## tools/mame/end_live.lua took a new game from flight through COM's
## "4) END" and round END's menu: digits that are no choice, a save, a
## save refused in the atmosphere (38210 poked to 1), "2) CONTINUE". Every
## character it drew is in analysis/live/end/end_<route>_glyphs.log and the
## keys, the pokes and the byte 38391 at each stop in end_<route>.log.
## Here the menu's words, the refusal and the "GAME SAVED." are compared
## with what the rules say, and the saved-game mark after each "1" with the
## real game's.
##
##   godot --headless --path godot-remake res://tests/check_end_rules.tscn
##
## Spaces are not compared.

const EndRules = preload("res://scripts/rules/end_rules.gd")

const REFERENCE := "../analysis/live/end/"
const ROUTES := ["menu", "atmosphere"]

var _bad := 0
var _checked := 0


func _ready() -> void:
	for route: String in ROUTES:
		_route(route)
	print("end rules: %d compared, %d wrong" % [_checked, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


func _route(route: String) -> void:
	var glyphs := _glyphs(REFERENCE.path_join("end_%s_glyphs.log" % route))
	# COM's own lines 40 to 70 come first: END is run by the "4" at the console
	var started := 0.0
	for line: String in FileAccess.open(REFERENCE.path_join("end_%s.log" % route), FileAccess.READ).get_as_text().split("\n"):
		if line.contains("-- key '4'"):
			started = float(line)
			break
	glyphs = glyphs.filter(func(g: Array) -> bool: return g[0] > started)
	for screen: Dictionary in _screens(glyphs):
		var rows := _rows(screen)
		var expected := []
		match screen["first"]:
			40:
				expected = [_plain(EndRules.TITLE)]
				for i in EndRules.CHOICES.size():
					expected.append(_plain("%d) %s" % [i + 1, EndRules.CHOICES[i]]))
				expected.append(_plain(EndRules.PROMPT))
			190:
				expected = EndRules.SAID_ORBIT.map(_plain)
			210:
				expected = EndRules.SAID_SAVED.map(_plain)
		_checked += 1
		_check("%s, line %d at %.0f: its words" % [route, screen["first"], screen["ms"]], rows == expected)
		if rows != expected:
			print("       the real game: %s" % str(rows))
	# a "1" at the menu, and the mark the real game had at the next stop
	var stops := _stops(REFERENCE.path_join("end_%s.log" % route))
	var in_atmosphere := false
	for i in stops.size():
		in_atmosphere = stops[i]["in_atmosphere"]
		if stops[i]["key"] != "1" or not stops[i]["name"].begins_with("menu") or i + 1 >= stops.size():
			continue
		GameState.start_new_game()
		GameState.in_atmosphere = in_atmosphere
		var rules := EndRules.new()
		rules.writer = func() -> bool: return true
		var said := rules.save()
		_checked += 1
		_check("%s, %s: a save %s, the mark is %d afterwards" % [route, stops[i]["name"],
				"refused" if in_atmosphere else "made", stops[i + 1]["mark"]],
				(GameState.saved_marker) == (stops[i + 1]["mark"] == 77)
				and said == (EndRules.SAID_ORBIT if in_atmosphere else EndRules.SAID_SAVED))


func _plain(text: String) -> String:
	return text.replace(" ", "")


func _rows(screen: Dictionary) -> Array:
	var cells := {}
	for glyph: Array in screen["glyphs"]:
		var key := Vector2i(glyph[3], glyph[4])
		if glyph[2] != 32 and not cells.has(key):
			cells[key] = String.chr(glyph[2])
	var by_row := {}
	for key: Vector2i in cells:
		if not by_row.has(key.y):
			by_row[key.y] = {}
		by_row[key.y][key.x] = cells[key]
	var tops: Array = by_row.keys()
	tops.sort()
	var out := []
	for y: int in tops:
		var columns: Array = by_row[y].keys()
		columns.sort()
		var text := ""
		for x: int in columns:
			text += by_row[y][x]
		out.append(_plain(text))
	return out


## [ms, line, code, column, row] of each character drawn.
func _glyphs(path: String) -> Array:
	var out: Array = []
	for line: String in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		var w := line.split(" ", false)
		if w.size() >= 7:
			out.append([float(w[0]), int(w[1]), int(w[2]), int(w[3]), int(w[4])])
	return out


## The menu (lines 40-70) and the two messages (190, 210) as the screens
## they were drawn in: a new one when the line numbers fall back or a
## second passes.
func _screens(glyphs: Array) -> Array:
	var groups := [[40, 50, 60, 70], [190], [210]]
	var screens: Array = []
	for group: Array in groups:
		var current := {}
		var last_ms := -1e9
		var last_line := 0
		for glyph: Array in glyphs:
			if not group.has(glyph[1]):
				continue
			if current.is_empty() or glyph[0] - last_ms > 1500.0 or glyph[1] < last_line:
				if not current.is_empty():
					screens.append(current)
				current = {"first": group[0], "ms": glyph[0], "glyphs": []}
			current["glyphs"].append(glyph)
			last_ms = glyph[0]
			last_line = glyph[1]
		if not current.is_empty():
			screens.append(current)
	return screens


## Each "-- get" with the key pressed there, 38391 as the get saw it and
## whether 38210 had been poked to 1.
func _stops(path: String) -> Array:
	var stops: Array = []
	var atmosphere := false
	for line: String in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		if line.contains("-- poke 38210="):
			atmosphere = line.split("38210=")[1].strip_edges() == "1"
		var at := line.find("-- get ")
		if at >= 0:
			var w := line.substr(at + 7).split(" ")
			var mark := 0
			if line.contains(" 38391="):
				mark = int(line.split(" 38391=")[1].split(" ")[0])
			stops.append({"name": w[0], "mark": mark, "key": "", "in_atmosphere": atmosphere})
		elif line.contains("-- key '") and not stops.is_empty() and stops[-1]["key"] == "":
			stops[-1]["key"] = line.split("-- key '")[1].substr(0, 1)
	return stops


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1
