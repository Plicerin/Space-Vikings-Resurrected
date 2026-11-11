extends Node
## Holds scripts/rules/report_rules.gd (STATUS and SUPPLY) to the real
## game. tools/mame/reports_live.lua recorded every character the two
## programs drew, with the line that drew it and where (analysis/live/
## reports/reports_<route>_glyphs.log), and every byte it poked into
## the game before them (reports_<route>.log). Here each page the real
## game printed is put together from the characters, and the game is
## put as the recording had it when the page was drawn, and what the
## rules say is compared with what is on the page.
##
##   godot --headless --path godot-remake res://tests/check_report_rules.tscn
##
## Spaces are not compared (the original lays its columns out with
## HTAB). Two things are left out on purpose, as the rules do not
## follow the original there (see report_rules.gd): a page with a
## condition, a morale or a place that has no word, where the original
## runs a line into the next, and line 1386, which the recording of
## poked bytes makes print and the rules do not. SUPPLY's numbers are
## read from the first character drawn in each cell and its units from
## the last, as the unit is drawn over the end of a number.

const ReportRules = preload("res://scripts/rules/report_rules.gd")

const REFERENCE := "../analysis/live/reports/"
const ROUTES := ["status", "status_poked", "status_morale", "status_odd", "supply", "supply_poked"]
## The bytes the recorder poked, as GameState has them.
const BYTES := {
	38153: "gf_missiles", 38154: "gf_tanks", 38155: "gf_transports", 38156: "gf_fighters",
	38165: "condition", 38166: "troop_location", 38186: "ship_laser", 38187: "ship_missile_system",
	38190: "ship_hyperdrive", 38193: "ship_hull", 38195: "ship_radar", 38196: "ship_computer",
	38197: "ship_engine2", 38198: "ship_engine1", 38199: "ship_energy", 38200: "ship_shield",
	38203: "troop_morale",
}
const STATUS_FIRST := [1240, 1250, 1255, 1256, 1260, 1270, 1280, 1290, 1292, 1294, 1300, 5100, 5110, 5120, 1310]
const STATUS_SECOND := [1320, 1330, 1340, 1350, 1352, 1354, 1356, 1358, 1360, 1370, 1380, 1381, 1382, 1384, 5200, 5210, 1386]
const SUPPLY_FIRST := [1410, 1420, 1430, 1440]
const SUPPLY_SECOND := [1470, 1480, 1485, 1490]

var _bad := 0
var _checked := 0
var _skipped := 0


func _ready() -> void:
	for route: String in ROUTES:
		await _route(route)
	print("report rules: %d pages compared, %d left out, %d wrong" % [_checked, _skipped, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


func _route(route: String) -> void:
	var pokes := _pokes(REFERENCE.path_join("reports_%s.log" % route))
	var pages := _pages(REFERENCE.path_join("reports_%s_glyphs.log" % route), route.begins_with("supply"))
	GameState.start_new_game()
	_poke_what_was_flown(REFERENCE.path_join("reports_%s.log" % route))
	var applied := 0
	var seen := 0
	for page: Dictionary in pages:
		while applied < pokes.size() and pokes[applied][0] <= page["ms"]:
			_poke(pokes[applied][1], pokes[applied][2])
			applied += 1
		seen += 1
		var name_ := "%s, page %d (%d)" % [route, page["number"], seen]
		if route.begins_with("supply"):
			_supply(name_, page)
		else:
			_status(name_, page)
	_check("%s: pages were found (%d)" % [route, pages.size()], pages.size() >= 2)


func _status(name_: String, page: Dictionary) -> void:
	var rows := _rows(page, true)
	var expected: Array[String] = []
	var unworded := false
	if page["number"] == 1:
		for row: Array in ReportRules.ship():
			var text := ""
			for cell: Array in row:
				unworded = unworded or cell[1] == ""
				text += _plain(_original_label(cell[0]) + ":" + cell[1])
			expected.append(text)
	else:
		for entry: Array in ReportRules.troops():
			unworded = unworded or entry[1] == ""
			expected.append(_plain(entry[0] + "-" + entry[1]))
		if rows.has("THETROOPSAREALLDEAD!"):
			rows.erase("THETROOPSAREALLDEAD!")
			_check("%s: the troops are all dead is the rules' to say by troops" % name_, true)
	if unworded:
		_skipped += 1
		return
	_checked += 1
	_check("%s: %s" % [name_, str(expected)], rows == expected)
	if rows != expected:
		print("       the real game: %s" % str(rows))


func _supply(name_: String, page: Dictionary) -> void:
	var first := _rows(page, true)
	var last := _rows(page, false)
	var supply := ReportRules.supply()
	var wanted: Array = supply.slice(0, 7) if page["number"] == 1 else supply.slice(7)
	_checked += 1
	var ok := first.size() == wanted.size() + (0 if page["number"] == 1 else 1)
	for i in wanted.size():
		var row: Array = wanted[i]
		var shown: String = first[i] if i < first.size() else ""
		var name_plain := "*" + _plain(row[0])
		var named := shown.begins_with(name_plain)
		# ELECTRONIC PARTS is a letter too long: its "=" is drawn over the S
		var digits := ""
		for c in shown.substr(name_plain.length()).trim_prefix("="):
			if c < "0" or c > "9":
				break
			digits += c
		var unit_ok: bool = i < last.size() and last[i].ends_with(_plain(row[2]))
		if not (named and digits == row[1] and unit_ok):
			ok = false
			print("       %s: wanted %s, the real game drew %s and %s" % [row[0], str(row), shown, last[i] if i < last.size() else ""])
	if page["number"] == 2:
		ok = ok and first.size() > wanted.size() and first[wanted.size()] == "*CREDITS=" + ReportRules.supply_credits()
	_check(name_, ok)


## The labels as the original spelt them, for the one that is not
## spelt as shown.
func _original_label(label: String) -> String:
	return {"ENV.": "ENV.", "NAV.COMP.": "NAV.COMP."}.get(label, label)


func _plain(text: String) -> String:
	return text.replace(" ", "")


## The page's rows as text without spaces, top to bottom: of the first
## character drawn in each place, or the last.
func _rows(page: Dictionary, first_drawn: bool) -> Array[String]:
	var cells := {}
	for glyph: Array in page["glyphs"]:
		var key := Vector2i(glyph[3], glyph[4])
		if first_drawn and cells.has(key):
			continue
		cells[key] = String.chr(glyph[2])
	var rows := {}
	for key: Vector2i in cells:
		if not rows.has(key.y):
			rows[key.y] = {}
		rows[key.y][key.x] = cells[key]
	var tops: Array = rows.keys()
	tops.sort()
	var out: Array[String] = []
	for y: int in tops:
		var columns: Array = rows[y].keys()
		columns.sort()
		var text := ""
		for x: int in columns:
			text += rows[y][x]
		text = _plain(text)
		if text != "" and not text.begins_with("-SHIPSTATUS") and not text.begins_with("-TROOPSTATUS") \
				and not text.begins_with("-SUPPLYREPORT") and not text.begins_with("HITSPACE") \
				and not text.begins_with("(1TO"):
			out.append(text)
	return out


## The pages the real game printed: the glyphs drawn by the report's
## lines, a new page when a line of the other page comes.
func _pages(path: String, supply: bool) -> Array:
	var first := SUPPLY_FIRST if supply else STATUS_FIRST
	var second := SUPPLY_SECOND if supply else STATUS_SECOND
	var pages: Array = []
	var current := 0
	for line: String in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		var words := line.split(" ", false)
		if words.size() < 5:
			continue
		var number := int(words[1])
		var side := 1 if number in first else (2 if number in second else 0)
		if side == 0:
			continue
		if side != current:
			pages.append({"number": side, "ms": float(words[0]), "glyphs": []})
			current = side
		pages[-1]["glyphs"].append([float(words[0]), number, int(words[2]), int(words[3]), int(words[4])])
	return pages


## [ms, address, value] of each poke.
func _pokes(path: String) -> Array:
	var pokes: Array = []
	for line: String in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		var at := line.find("-- poke ")
		if at >= 0:
			var pair := line.substr(at + 8).split("=")
			pokes.append([float(line), int(pair[0]), int(pair[1])])
	return pokes


## Three passes of flight come before the console, and leave the
## condition RED and the like: the recording's "in flight" line has the
## bytes as they were when it left.
func _poke_what_was_flown(path: String) -> void:
	for line: String in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		if line.contains("-- in flight"):
			for word in line.split(" "):
				var pair := word.split("=")
				# the rest (38209, the star, is SOL as it is in a new game) change nothing reported
				if pair.size() == 2 and pair[0].is_valid_int() and BYTES.has(int(pair[0])):
					_poke(int(pair[0]), int(pair[1]))
			return


func _poke(address: int, value: int) -> void:
	if BYTES.has(address):
		GameState.set(BYTES[address], value)
	elif address >= 38171 and address <= 38183:
		GameState.loot[address - 38171] = float(value)
	elif address != 38159 and address != 38167: # only line 1386's, which the rules do not use
		_check("a poke of %d, which the test has no name for" % address, false)


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1
