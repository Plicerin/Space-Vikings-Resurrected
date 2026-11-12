extends Node
## Holds scripts/rules/chart_rules.gd (GALAXY MAP.bas, the star chart) to
## the real game. tools/mame/chart_rules_live.lua put the paddles to 50
## places one after another, pressed the button and noted BASIC's PX, PY
## and P and every character the chart printed
## (analysis/live/chart/chart_rules_live.log): the cell of each of the
## twenty stars, the cells just inside and just outside the edges of four
## of them, and the ends of both paddles. Here each is put to the rules:
## where the cursor goes, which star it is on, and what is said of it.
## The log also gives the twenty stars' places as the game holds them.
##
##   godot --headless --path godot-remake res://tests/check_chart_rules.tscn
##
## Spaces are not compared (the original lays its text out with spaces).

const ChartRules = preload("res://scripts/rules/chart_rules.gd")

const PAGE := "../analysis/live/chart/chart_clean_p1.bin"

const LOG := "../analysis/live/chart/chart_rules_live.log"

var _bad := 0
var _checked := 0


func _ready() -> void:
	GameState.start_new_game()
	var probes := {}
	var text := {}
	var current := 0
	for line: String in FileAccess.open(LOG, FileAccess.READ).get_as_text().split("\n"):
		var w := line.split(" ", false)
		if line.begins_with("star "):
			var star := int(w[1])
			_check("star %d's place is the game's (%s)" % [star, line],
					GameState.PLANET_X[star - 1] == int(w[2]) and GameState.PLANET_Y[star - 1] == int(w[3])
					and GameState.PLANET_Z[star - 1] == int(w[4]))
			continue
		var at := line.find("probe ")
		if at >= 0:
			current = int(w[2])
			var pdl := w[3].trim_prefix("pdl=").split(",")
			probes[current] = {"pdl": [int(pdl[0]), int(pdl[1])]}
			text[current] = {}
			continue
		at = line.find(" result ")
		if at >= 0:
			var n := int(w[2])
			probes[n]["px"] = float(w[3].trim_prefix("PX="))
			probes[n]["py"] = float(w[4].trim_prefix("PY="))
			probes[n]["p"] = int(float(w[5].trim_prefix("P=")))
			current = 0
			continue
		if current > 0 and line.contains(" ch "):
			# [frame] ch  <code> '<c>' col=<n> row=<n> ...
			var code := int(line.split(" ch ")[1].strip_edges().split(" ")[0])
			var col := int(line.split("col=")[1].split(" ")[0])
			var row := int(line.split("row=")[1].split(" ")[0])
			# the first character drawn in a place that is not a space: line 3250 and 3240
			# clear the line before and after what they say
			if code != 32 and not text[current].has(Vector2i(col, row)):
				text[current][Vector2i(col, row)] = String.chr(code)
	for n: int in probes:
		_probe(n, probes[n], text[n])
	_marks()
	print("chart rules: %d probes compared, %d wrong" % [_checked, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


func _probe(n: int, probe: Dictionary, glyphs: Dictionary) -> void:
	var pdl: Array = probe["pdl"]
	var cursor := ChartRules.cursor(pdl[0], pdl[1])
	var star := ChartRules.star_at(cursor)
	_checked += 1
	var label := "probe %d (paddles %d, %d)" % [n, pdl[0], pdl[1]]
	# BASIC's PX has the 35 of line 3215 added by then, unless no star was there and
	# the chart has gone round to read the paddle again
	var shifted := absf(cursor.x + 35.0 - probe["px"]) < 0.0001
	var read_again := absf(cursor.x - probe["px"]) < 0.0001
	# (or the recording read PX and PY between lines 3110 and 3117, before the limits: one probe)
	var unlimited: bool = probe["px"] == pdl[0] * 1.19 and probe["py"] == pdl[1]
	_check("%s: the cursor is where BASIC had it (%.3f, %.3f)" % [label, probe["px"], probe["py"]],
			((shifted or (star == ChartRules.NO_STAR and read_again)) and cursor.y == probe["py"]) or unlimited)
	_check("%s: it is on star %d, BASIC's P (%d)" % [label, star, probe["p"]], star == probe["p"])
	var rows := _rows(glyphs)
	var expected: Array = []
	if star == ChartRules.NO_STAR:
		expected = [_plain(ChartRules.SAID_NO_STAR)]
	else:
		for line in ChartRules.said(star):
			expected.append(_plain(line))
		expected.append(_plain(ChartRules.QUESTION))
	# the chart's own text is on the last rows; the rows above are what it printed first
	rows = rows.slice(maxi(rows.size() - expected.size(), 0))
	_check("%s: what it said %s" % [label, str(expected)], rows == expected)
	if rows != expected:
		print("       the real game: %s" % str(rows))


func _plain(text: String) -> String:
	return text.replace(" ", "")


## The text's rows, top to bottom, without spaces and without the rows
## that are only the spaces that clear a line.
func _rows(glyphs: Dictionary) -> Array:
	var by_row := {}
	for key: Vector2i in glyphs:
		if not by_row.has(key.y):
			by_row[key.y] = {}
		by_row[key.y][key.x] = glyphs[key]
	var tops: Array = by_row.keys()
	tops.sort()
	var out: Array = []
	for y: int in tops:
		var columns: Array = by_row[y].keys()
		columns.sort()
		var text := ""
		for x: int in columns:
			text += by_row[y][x]
		text = _plain(text)
		if text != "":
			out.append(text)
	return out


## A dot of the recorded hi-res page: seven to a byte, the lowest bit leftmost.
func _lit(bytes: PackedByteArray, x: int, y: int) -> bool:
	return x >= 0 and x < 280 and y >= 0 and y < 192 and (bytes[y * 40 + x / 7] >> (x % 7)) & 1 == 1


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1


## The recorded picture of the chart (hi-res page 1 when it was drawn):
## the dots round where the rules put each star are the mark the rules
## give it. A near star's mark is eight dots, centred half a dot low; a
## middle one thirteen, a far one nine, centred. Two stars (3 and 8) are
## a row apart and share dots, and are left out.
func _marks() -> void:
	var bytes := FileAccess.get_file_as_bytes(PAGE)
	var marks := {
		ChartRules.Mark.NEAR: [8, Vector2(0.0, 0.5)], ChartRules.Mark.MIDDLE: [13, Vector2.ZERO],
		ChartRules.Mark.FAR: [9, Vector2.ZERO],
	}
	for star in range(1, ChartRules.STARS + 1):
		if star == 3 or star == 8:
			continue
		var at := ChartRules.place(star)
		var n := 0
		var sum := Vector2.ZERO
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				if _lit(bytes, int(at.x) + dx, int(at.y) + dy):
					n += 1
					sum += Vector2(dx, dy)
		var want: Array = marks[ChartRules.mark(star)]
		_checked += 1
		_check("star %d is drawn as its mark (%d dots about %s)" % [star, n, str(sum / maxf(n, 1))],
				n == want[0] and sum / maxf(n, 1) == want[1])
