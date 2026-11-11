extends Node
## Holds scripts/rules/com_rules.gd (COM.bas, the command console) to the
## real game. tools/mame/com_live.lua recorded every character the
## console drew, with the BASIC line that drew it and where
## (analysis/live/com/com_<route>_glyphs.log), and every byte it poked
## into the game first (com_<route>.log). Each screen the real game
## printed is put together from the characters and compared with what
## the rules say: the menus' words, the twelve lamps and which of them
## were out, what a course answered, and what the directory said of a
## star.
##
##   godot --headless --path godot-remake res://tests/check_com_rules.tscn
##
## Spaces are not compared (the original lays its columns out with
## HTAB and TAB).

const ComRules = preload("res://scripts/rules/com_rules.gd")

const REFERENCE := "../analysis/live/com/"
const ROUTES := ["menus", "damaged", "lamps", "stars", "edges"]
## The bytes the recorder poked, as GameState has them.
const BYTES := {
	38186: "ship_laser", 38187: "ship_missile_system", 38190: "ship_hyperdrive", 38193: "ship_hull",
	38194: "ship_env_control", 38195: "ship_radar", 38196: "ship_computer", 38197: "ship_engine2", 38198: "ship_engine1",
	38199: "ship_energy", 38200: "ship_shield",
}

var _bad := 0
var _checked := 0


func _ready() -> void:
	for route: String in ROUTES:
		_route(route)
	print("com rules: %d screens compared, %d wrong" % [_checked, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


## [ms, 38163] at each GET: the course the game had.
var _courses: Array = []


func _route(route: String) -> void:
	var pokes := _pokes(REFERENCE.path_join("com_%s.log" % route))
	_courses = _gets(REFERENCE.path_join("com_%s.log" % route))
	var glyphs := _glyphs(REFERENCE.path_join("com_%s_glyphs.log" % route))
	GameState.start_new_game()
	var applied := 0
	for screen: Dictionary in _screens(glyphs):
		while applied < pokes.size() and pokes[applied][0] <= screen["ms"]:
			_poke(pokes[applied][1], pokes[applied][2])
			applied += 1
		var name_ := "%s, line %d at %.0f" % [route, screen["first"], screen["ms"]]
		match screen["kind"]:
			"lamps": _lamps(name_, screen)
			"page": _page(name_, screen)
			"text": _text(name_, screen)
			"course": _course(name_, screen)


func _lamps(name_: String, screen: Dictionary) -> void:
	var labels: Array = []
	var run := ""
	var inverse := false
	var count := 0
	for glyph: Array in screen["glyphs"]:
		if count % 5 == 0:
			inverse = glyph[5] == 255
		run += String.chr(glyph[2])
		count += 1
		if count % 5 == 0:
			labels.append([run, inverse])
			run = ""
	var lamps := ComRules.lamps()
	var ok := labels.size() == 24
	for lamp in lamps.size():
		for half in 2:
			var seen: Array = labels[lamp * 2 + half] if labels.size() > lamp * 2 + half else ["", false]
			ok = ok and seen[0] == lamps[lamp][half] and seen[1] == lamps[lamp][2]
	_checked += 1
	_check("%s: the twelve lamps (%s)" % [name_, ", ".join(lamps.map(func(l: Array) -> String: return "x" if l[2] else "."))], ok)
	if not ok:
		print("       the real game: %s" % str(labels))


func _page(name_: String, screen: Dictionary) -> void:
	var rows := _rows(screen)
	var title: String = rows[0] if not rows.is_empty() else ""
	var star := -1
	for i in ComRules.STARS:
		if title == _plain(ComRules.NAMES[i] + " STAR SYSTEM"):
			star = i
	var expected: Array = []
	if star >= 0:
		for line in ComRules.star_page(star + 1):
			if line != "":
				expected.append(_plain(line))
	_checked += 1
	var shown: Array = []
	shown = rows.slice(1)
	_check("%s: the page of %s" % [name_, title], star >= 0 and shown == expected)
	if shown != expected:
		print("       the real game: %s\n       the rules:     %s" % [str(shown), str(expected)])


func _text(name_: String, screen: Dictionary) -> void:
	# line 978 clears the message after it, over the same cells
	var rows := _rows(screen, screen["first"] == 978)
	if screen["first"] == 978 and rows.is_empty():
		return # the spaces that take the message down, three seconds after it
	var expected: Array = []
	match screen["first"]:
		100:
			expected = ["COMMANDMODE"]
			for i in ComRules.COMMANDS.size():
				expected.append(_plain("%d) %s" % [i + 1, ComRules.COMMANDS[i]]))
		210:
			expected = ["CENTRALCOMPUTER"]
			if not ComRules.computer_out(): # with it out, line 215 says so and the menu is not printed
				for i in ComRules.CENTRAL.size():
					expected.append(_plain("%d) %s" % [i + 1, ComRules.CENTRAL[i]]))
		215:
			expected = ComRules.SAID_COMPUTER_OUT.map(_plain)
			rows = rows.slice(rows.size() - 2)
		810:
			expected = ["NAVIGATIONCOMPUTER"]
			for i in ComRules.NAVIGATION.size():
				expected.append(_plain("%d) %s" % [i + 1, ComRules.NAVIGATION[i]]))
		920, 940:
			expected = ["**GALAXYDIRECTORY**"] if screen["first"] == 920 else []
			if screen["first"] == 940:
				for i in 10:
					expected.append(_plain("%d) %s%d) %s" % [i + 1, ComRules.NAMES[i], i + 11, ComRules.NAMES[i + 10]]))
				for i in ComRules.DIRECTORY.size():
					expected.append(_plain("%d) %s" % [i + 1, ComRules.DIRECTORY[i]]))
		978:
			expected = ["TRYAGAINPLEASE."]
			# the numbers the recordings gave it: 30 and 0 (menus), 21 (edges)
			_check("%s: what is no star" % name_, not ComRules.is_star(30) and not ComRules.is_star(0)
					and not ComRules.is_star(21) and ComRules.is_star(1) and ComRules.is_star(20))
		_:
			return
	_checked += 1
	_check("%s: its words" % name_, rows == expected)
	if rows != expected:
		print("       the real game: %s\n       the rules:     %s" % [str(rows), str(expected)])


func _course(name_: String, screen: Dictionary) -> void:
	var rows := _rows(screen)
	GameState.current_planet = 0
	var target: int = GameState.target_planet
	var said: Array = []
	match screen["first"]:
		878: said = ComRules.course(0)
		895: said = ComRules.course(1)
		890:
			for i in ComRules.STARS:
				if rows.size() == 2 and rows[0] == _plain(ComRules.NAMES[i]) and i > 0:
					said = ComRules.course(i + 1)
	var set_to: int = GameState.target_planet + 1
	GameState.target_planet = target
	if screen["first"] == 890:
		var real := -1
		for got: Array in _courses:
			if got[0] > screen["ms"]:
				real = got[1]
				break
		_check("%s: the course the game was left with" % name_, real == set_to)
	_checked += 1
	var expected: Array = []
	expected = said.map(_plain)
	_check("%s: what a course answers" % name_, rows == expected and not said.is_empty())
	if rows != expected:
		print("       the real game: %s\n       the rules:     %s" % [str(rows), str(expected)])


func _plain(text: String) -> String:
	return text.replace(" ", "")


## The screen's rows as text without spaces, top to bottom.
func _rows(screen: Dictionary, first_drawn := false) -> Array:
	var cells := {}
	for glyph: Array in screen["glyphs"]:
		if first_drawn and cells.has(Vector2i(glyph[3], glyph[4])):
			continue
		cells[Vector2i(glyph[3], glyph[4])] = String.chr(glyph[2])
	var rows := {}
	for key: Vector2i in cells:
		if not rows.has(key.y):
			rows[key.y] = {}
		rows[key.y][key.x] = cells[key]
	var tops: Array = rows.keys()
	tops.sort()
	var out: Array = []
	for y: int in tops:
		var columns: Array = rows[y].keys()
		columns.sort()
		var text := ""
		for x: int in columns:
			text += rows[y][x]
		text = _plain(text)
		if text != "":
			out.append(text)
	return out


## The recording's glyphs as [ms, line, code, column, row, 973].
func _glyphs(path: String) -> Array:
	var out: Array = []
	for line: String in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		var w := line.split(" ", false)
		if w.size() >= 7:
			out.append([float(w[0]), int(w[1]), int(w[2]), int(w[3]), int(w[4]), int(w[5])])
	return out


## The screens, in the order drawn: a run of glyphs by lines that belong
## together, a new one when the line number falls back or a gap of more
## than a second comes.
func _screens(glyphs: Array) -> Array:
	var groups := [
		["lamps", [70]], ["text", [100, 110]], ["text", [210, 220]], ["text", [215]], ["text", [810]],
		["text", [920]], ["text", [940]], ["page", [990, 1005, 1010, 1030, 1040, 1050, 1060, 1070, 1090, 1110, 1130, 1140, 1160]],
		["course", [878]], ["course", [890]], ["course", [895]], ["text", [978]],
	]
	var screens: Array = []
	for group: Array in groups:
		var lines: Array = group[1]
		var current: Dictionary = {}
		var last_ms := -1e9
		var last_line := 0
		for glyph: Array in glyphs:
			if not lines.has(glyph[1]):
				continue
			if current.is_empty() or glyph[0] - last_ms > 1500.0 or (group[0] == "page" and glyph[1] < last_line):
				if not current.is_empty():
					screens.append(current)
				current = {"kind": group[0], "first": lines[0] if group[0] != "text" else glyph[1],
						"ms": glyph[0], "glyphs": []}
				if group[0] == "text" and lines.size() > 1:
					current["first"] = lines[0]
			current["glyphs"].append(glyph)
			last_ms = glyph[0]
			last_line = glyph[1]
		if not current.is_empty():
			screens.append(current)
	screens.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["ms"] < b["ms"])
	return screens


## [ms, address, value] of each poke.
func _pokes(path: String) -> Array:
	var pokes: Array = []
	for line: String in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		var at := line.find("-- poke ")
		if at >= 0:
			var pair := line.substr(at + 8).split("=")
			pokes.append([float(line), int(pair[0]), int(pair[1])])
	return pokes


func _gets(path: String) -> Array:
	var out: Array = []
	for line: String in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		if line.contains("-- get ") and line.contains(" 38163="):
			out.append([float(line), int(line.split(" 38163=")[1].split(" ")[0])])
	return out


func _poke(address: int, value: int) -> void:
	if BYTES.has(address):
		GameState.set(BYTES[address], value)
	elif address >= 38220 and address <= 38239: # 38219 + the star
		GameState.planet_secured[address - 38220] = value
	elif address >= 38241 and address <= 38260: # 38240 + the star
		GameState.planet_scouted[address - 38241] = value != 0
	elif address >= 38304 and address <= 38323: # 38303 + the star
		GameState.planet_has_base[address - 38304] = value != 0
	else:
		_check("a poke of %d, which the test has no name for" % address, false)


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1
