extends Node
## Holds scripts/rules/combat_rules.gd (the fighting of STARSHIP
## SIMULATOR.bas) to the real game. tools/mame/combat_live.lua flew the
## real program with the ship held still and each pass given a state to
## fight in (the ship in the firing box and out of it, a missile flown at
## the defender and past it, in space and in the atmosphere, every
## technology, shields up and down, a surrendered planet, a few for the
## ends) and wrote down, for each pass, the game's bytes and BASIC's own
## variables at the fire button's line (182) and where the pass left them,
## with every RND(1) the pass threw (analysis/live/combat/).
##
## Here each pass is begun in the state it began in, the dice are the
## numbers RND gave, in order, and what the rules leave is compared with
## what the real game left: every byte, DMG, DP and L, how many dice were
## thrown (a die too many or too few and the dice after it are not the
## game's), and which program the pass ended in (EX, DMG, S/X) if one.
##
##   godot --headless --path godot-remake res://tests/check_combat_rules.tscn

const CombatRules = preload("res://scripts/rules/combat_rules.gd")

const LOG := "../analysis/live/combat/combat.log"

## The game's bytes the pass looks at or changes, and what GameState calls them.
const BYTES := {
	38150: "gf_enemy_strength", 38152: "defender_damage_points", 38160: "gf_victory_progress",
	38165: "condition", 38186: "ship_laser", 38187: "ship_missile_system", 38193: "ship_hull",
	38195: "ship_radar", 38196: "ship_computer", 38197: "ship_engine2", 38198: "ship_engine1",
	38200: "ship_shield", 38201: "shields_up", 38202: "missile_mode_active", 38204: "defender_damage_threshold",
	38205: "orbital_defender_tier", 38207: "flight_escort_fighters", 38208: "gf_planet_surrendered",
	38210: "in_atmosphere", 38393: "damage_alert_active",
}
const NO_CHANGE: Array[int] = [38165, 38202, 38204, 38210, 38209, 29473, 29474, 29475, 38157] # nothing in a fight writes them

var _bad := 0
var _checked := 0
var _outcomes := {}
var _events := {}


func _ready() -> void:
	var stops := _read(LOG)
	var i := 0
	while i < stops.size():
		var a: Dictionary = stops[i]
		if a["what"] != "at 182":
			i += 1
			continue
		# the pass ends at line 200, or in a program the fight ran
		var j := i + 1
		while j < stops.size() and stops[j]["what"] == "at 182":
			j += 1
		if j >= stops.size() or stops[j]["what"].begins_with("at 182"):
			break
		var b: Dictionary = stops[j]
		if b["what"] == "at 200" or b["what"].begins_with("ran "):
			_pass(a, b, stops[j + 1] if j + 1 < stops.size() else {})
			i = j
		else:
			i += 1
	print("combat rules: %d passes compared, %d wrong; outcomes %s; events %s" % [_checked, _bad, str(_outcomes), str(_events)])
	get_tree().quit(1 if _bad > 0 else 0)


func _pass(a: Dictionary, b: Dictionary, next: Dictionary) -> void:
	GameState.start_new_game()
	for address: int in BYTES:
		if a["bytes"].has(address):
			_put(address, a["bytes"][address])
	GameState.planet_tech[0] = a["bytes"].get(38283, 0)
	GameState.planet_secured[0] = a["bytes"].get(38220, 0)
	GameState.current_planet = 0
	var vars: Dictionary = a["vars"]
	var rules := CombatRules.new()
	var dice: Array = b["drawn"].duplicate()
	var used := [0]
	rules.rnd = func() -> float:
		var value: float = dice[used[0]] if used[0] < dice.size() else 0.99
		used[0] += 1
		return value
	rules.dmg = vars.get("DM", 0.0) != 0.0
	rules.dp = vars.get("DP", 0.0)
	rules.l = int(vars.get("L", 0.0))
	rules.te = int(vars.get("TE", 0.0))
	var eye := Vector3(vars["X"], vars["Y"], vars["Z"])
	var result := rules.fight(a["btn"] == 1, eye, Vector2(a["bytes"][29473], a["bytes"][29475]), vars.get("VV", 0.0),
			[vars["ZP"], vars["ZH"], vars["XH"], vars["YP"]])
	var label := "pass %s at line 182 (n=%s)" % [a["n"], a["n"]]
	_checked += 1
	var ok := true
	var why := ""
	for address: int in BYTES:
		if not b["bytes"].has(address):
			continue
		var mine := int(_byte(address))
		if mine != b["bytes"][address]:
			ok = false
			why += " %s is %d, the game's %d;" % [BYTES[address], mine, b["bytes"][address]]
	if b["what"] == "at 200":
		var after: Dictionary = b["vars"]
		for pair in [["DM", 1.0 if rules.dmg else 0.0], ["DP", rules.dp], ["L", float(rules.l)]]:
			if absf(after.get(pair[0], pair[1]) - pair[1]) > 0.0001:
				ok = false
				why += " %s is %s, the game's %s;" % [pair[0], pair[1], after.get(pair[0], 0.0)]
	if used[0] != dice.size():
		ok = false
		why += " %d dice used, the game threw %d;" % [used[0], dice.size()]
	# which program the pass ended in
	var ended := "line 200"
	if b["what"].begins_with("ran "):
		ended = b["what"].substr(4).split(" ")[0]
	var expected := {CombatRules.Outcome.NONE: "line 200", CombatRules.Outcome.DEFENDER_DESTROYED: "EX",
			CombatRules.Outcome.DAMAGED: "DMG", CombatRules.Outcome.SHIP_DESTROYED: "S/X"}
	var mine_ended: String = expected[result["outcome"]]
	if mine_ended != ended and not (ended.replace("_", "/") == mine_ended):
		ok = false
		why += " ended in %s, the game in %s;" % [mine_ended, ended]
	# RUN EX: the defender gone and half the fighters, as the flight program begins again
	if mine_ended == "EX" and next.get("what", "").begins_with("ran STARSHIP"):
		rules.defender_destroyed()
		for address in [38205, 38207]:
			if int(_byte(address)) != next["bytes"][address]:
				ok = false
				why += " after EX %s is %d, the game's %d;" % [BYTES[address], int(_byte(address)), next["bytes"][address]]
	_outcomes[mine_ended] = _outcomes.get(mine_ended, 0) + 1
	for event: Dictionary in result["events"]:
		_events[event["kind"]] = _events.get(event["kind"], 0) + 1
	if not ok:
		_bad += 1
		print("WRONG  %s:%s" % [label, why])
		if _bad <= 4 or OS.get_cmdline_user_args().has("--all"):
			var show := {}
			for key: String in ["X", "Y", "Z", "P", "ZP", "ZH", "XH", "YP", "VV", "DM", "DP", "L", "TE", "S"]:
				show[key] = a["vars"].get(key)
			print("       before: %s %s" % [str(a["bytes"]), str(show)])
			print("       dice (%d): %s button %d; events %s outcome %d" % [dice.size(), str(dice.slice(0, 12)), a["btn"],
					str(result["events"].map(func(e: Dictionary) -> String: return e["kind"])), result["outcome"]])


func _put(address: int, value: int) -> void:
	var field: String = BYTES[address]
	var current: Variant = GameState.get(field)
	if current is bool:
		GameState.set(field, value != 0)
	elif current is int:
		GameState.set(field, value)
	else:
		GameState.set(field, float(value))


func _byte(address: int) -> float:
	var value: Variant = GameState.get(BYTES[address])
	if value is bool:
		return 1.0 if value else 0.0
	return float(value)


## Each stop: what it is, its bytes, BASIC's variables, the dice since the
## last stop, the button.
func _read(path: String) -> Array:
	var stops: Array = []
	var current: Dictionary = {}
	for line: String in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		var at := line.find("-- ")
		if line.begins_with("    vars "):
			if not current.is_empty():
				var vars := {}
				for word in line.substr(10).split(" ", false):
					var pair := word.split("=")
					vars[pair[0]] = float(pair[1])
				current["vars"] = vars
		elif line.begins_with("    drawn"):
			if not current.is_empty():
				var dice: Array = []
				for word in line.substr(10).split(" ", false):
					dice.append(_die(word))
				current["drawn"] = dice
		elif at > 0 and (line.substr(at + 3).begins_with("at ") or line.substr(at + 3).begins_with("ran ")):
			var words := line.substr(at + 3).split(" ", false)
			current = {"what": "%s %s" % [words[0], words[1]] if words[0] == "at" else line.substr(at + 3).split(" gap=")[0],
					"bytes": {}, "btn": 0, "n": 0, "vars": {}, "drawn": []}
			for word in words:
				if word.begins_with("n="):
					current["n"] = int(word.substr(2))
				elif word.begins_with("btn="):
					current["btn"] = int(word.substr(4))
				elif word.contains("=") and word.split("=")[0].is_valid_int():
					current["bytes"][int(word.split("=")[0])] = int(word.split("=")[1])
			stops.append(current)
	return stops


## RND's result from the five bytes it leaves as the seed: the exponent
## byte, then the mantissa with its leading one put back.
static func _die(word: String) -> float:
	var parts := word.split(":")
	var exponent := parts[0].hex_to_int()
	var mantissa := parts[1].hex_to_int()
	return float(mantissa) / 4294967296.0 * pow(2.0, exponent - 128)
