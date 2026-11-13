extends RefCounted
## STATUS and SUPPLY, the central computer's two reports, on the CRT console:
## what scripts/rules/report_rules.gd says, a screenful a page and a key to the
## next (the original's were two screens each, a key apart). What they say is
## the rules', held to the recordings by tests/check_report_rules.gd.
##
## The troops' line says which star they are at when they are on a planet;
## the original's says only PLANETSIDE or SHORE LEAVE, and with a jump between
## landing and recalling them it is easy to lose track.

const ReportRules = preload("res://scripts/rules/report_rules.gd")


## @witness STATUS 1232, 1315, 1390, 1400
func status(console: Node) -> void:
	var rows: Array = ["-SHIP STATUS REPORT-"]
	for row: Array in ReportRules.ship():
		var left: Array = row[0]
		var right: Array = row[1] if row.size() > 1 else ["", ""]
		rows.append(console.columns(_cell(left), _cell(right)).strip_edges(false, true))
	await console.any_key(rows + ["ANY KEY  NEXT"])
	var troops := ReportRules.troops()
	var by_name := {}
	for entry: Array in troops:
		by_name[entry[0]] = entry[1]
	var location: String = by_name["TROOP LOCATION"]
	if GameState.troop_location == 1 or GameState.troop_location == 2:
		var star: int = GameState.troops_stationed_at - 1
		if star >= 0 and star < GameState.STAR_NAMES.size():
			location = "%s (%s)" % [location, GameState.STAR_NAMES[star]]
	var page: Array = ["-TROOP STATUS-",
			console.columns("TROOPS %s" % by_name["NO. OF TROOPS"], "MORALE %s" % by_name["TROOP MORALE"]),
			console.columns("FIGHTERS %s" % by_name["FIGHTERS"], "TRANSPORTS %s" % by_name["TRANSPORTS"]),
			console.columns("TANKS %s" % by_name["TANKS"], "GROUND MISSILES %s" % by_name["GROUND MISSILES"]),
			"LOCATION %s" % location]
	if ReportRules.troops_all_dead():
		page.append("THE TROOPS ARE ALL DEAD!")
	await console.any_key(page + ["ANY KEY  RETURN"])


## @witness SUPPLY 1400, 1450, 1500-1520
func supply(console: Node) -> void:
	var rows := ReportRules.supply()
	var first: Array = ["-SUPPLY REPORT-"]
	var second: Array = ["-SUPPLY REPORT-"]
	for i in rows.size():
		var row: Array = rows[i]
		var line := "%s %s %s" % [str(row[0]).rpad(16), str(row[1]).lpad(6), row[2]]
		(first if i < 7 else second).append(line)
	second.append("%s %s" % ["CREDITS".rpad(16), ReportRules.supply_credits().lpad(6)])
	await console.any_key(first + ["ANY KEY  NEXT"])
	await console.any_key(second + ["ANY KEY  RETURN"])


## One [label, value] as a cell of the two columns.
func _cell(cell: Array) -> String:
	return "" if cell[0] == "" else "%s %s" % [str(cell[0]).rpad(9), cell[1]]
