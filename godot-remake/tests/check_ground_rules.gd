extends Node
## The rules of GROUND FORCES, RECALL and COLLECT
## (scripts/rules/ground_rules.gd) against the real game: every route
## recorded by tools/mame/ground_live.lua (analysis/live/ground/) is
## played through the rules with the keys pressed there and the
## numbers RND gave there, and at each stop of the recording the game's
## bytes, the program's variables, the numbers on the battle screen and
## what was printed are compared. A recording that drew more or fewer
## random numbers than the rules did is wrong too.
##
##   godot --headless --path godot-remake res://tests/check_ground_rules.tscn

const GroundRules = preload("res://scripts/rules/ground_rules.gd")
const LOGS := "../analysis/live/ground"
const ROUTES := [
	"menu", "gates", "leave", "stale", "sol", "tech_0", "tech_1", "tech_2", "tech_3", "tech_4",
	"clamp", "early_key", "none", "twice",
]
## The lines that say something a rule decides, by program.
const SPOKEN := {
	"GROUND_FORCES": [65, 66, 67, 175, 180, 185, 220, 300, 330, 340, 400, 450, 660, 670, 690, 1120],
	"RECALL": [2000, 2005, 2010, 2020, 2030],
	"COLLECT": [16, 820, 840, 910, 1070, 1090],
}
const LOOT := 38171
const SETTLED := [185, 190, 195, 200] ## GROUND FORCES lines where the attack's set-up is done

var _bad := 0
var _checked := 0
var _route := ""
var _events: Array = []
var _draws: Array = [] ## [event index, value]
var _drawn := 0
var _rules: GroundRules


func _ready() -> void:
	for route in ROUTES:
		_route = route
		var before := [_bad, _checked]
		_play(ProjectSettings.globalize_path("res://").path_join(LOGS).path_join("ground_%s.log" % route))
		print("%s: %d checks, %d wrong, %d random numbers" % [route, _checked - before[1], _bad - before[0], _draws.size()])
	print("ground rules: %d wrong of %d" % [_bad, _checked])
	get_tree().quit(1 if _bad > 0 else 0)


func _play(path: String) -> void:
	_read(path)
	GameState.start_new_game()
	_rules = null
	var program := ""
	var ours := false      # the state is the rules' own doing since the last load
	var at_menu := false
	var attacking := false
	var landed := false
	var collecting := false
	var outcome := -1
	var shown := ""        # the last numbers line 4010 printed
	var said := ""
	var heard := ""

	for i in _events.size():
		var e: Dictionary = _events[i]
		match e.kind:
			"poke":
				_poke(e.address, e.value)
			"text":
				if e.line == 4010 and program == "GROUND_FORCES":
					shown = e.text
				elif e.line in SPOKEN.get(program, []):
					heard += e.text.trim_prefix("100%") if e.line == 660 else e.text
			"key":
				if not at_menu:
					continue
				at_menu = false
				var command := int(e.key)
				var why := _rules.refusal(command)
				if not why.is_empty():
					said += "".join(why)
				elif command == 1:
					attacking = true
					landed = false
					outcome = -1
					match _rules.begin_attack():
						GroundRules.Landing.NOTHING:
							attacking = false
						GroundRules.Landing.NO_TRANSPORTS:
							attacking = false
							said += "".join(GroundRules.SAID_NO_TRANSPORTS)
						_:
							said += "".join(_rules.departure())
				elif command > 2 and command < 9:
					ours = false # SHORE LEAVE's
			"ran":
				_same("what was said in %s before %d" % [program, e.at], said.replace(" ", ""), heard.replace(" ", ""))
				_same("random numbers drawn in %s before %d" % [program, e.at], _drawn, _before(i))
				_drawn = _before(i)
				said = ""
				heard = ""
				program = e.name
				at_menu = false
				match program:
					"GROUND_FORCES":
						var filed: float = _next_menu(i).vars.get("TR", -1.0)
						if ours:
							_expect(e)
							_near("troops in the MISC file", GameState.troops, filed, e.at)
						_load(e)
						GameState.troops = filed
						ours = true
						attacking = false
						_rules = GroundRules.new()
						_rules.rnd = _draw
						_rules.open_menu()
					"COLLECT":
						collecting = true
					"COM":
						if ours and _rules != null:
							if attacking and outcome == GroundRules.Outcome.FIGHTING:
								_wrong("the battle at %d was still going when COM ran" % e.at)
							_expect(e)
						attacking = false
					"RECALL":
						pass
					_:
						ours = false
			"get":
				if program == "GROUND_FORCES":
					_expect(e)
					at_menu = true
			"at":
				if not ours:
					continue
				if program == "RECALL" and e.line == 2050:
					said += "".join(_rules.recall())
					_expect(e)
				elif program == "COLLECT" and e.line == 810 and collecting:
					collecting = false
					said += _flat(_rules.collect())
					_expect(e)
				elif program == "GROUND_FORCES" and e.line == 310 and not attacking:
					_expect(e)
				elif program == "GROUND_FORCES" and attacking:
					if e.line in SETTLED:
						_expect(e)
						if e.vars.has("T9"):
							_near("T9", _rules.reserve, e.vars.T9, e.at)
							_near("TR", _rules.troops, e.vars.TR, e.at)
					elif (e.line == 500 or e.line == 310) and not landed:
						landed = true
						said += _flat(_rules.land())
						_expect(e)
					elif (e.line == 660 or e.line == 1121) and _drawn < _before(i):
						outcome = _rules.fight(e.line == 1121)
						_same("random numbers drawn by the round before %d" % e.at, _drawn, _before(i))
						_round(e, shown)
						var then: Dictionary = _next_stop(i)
						var expected := GroundRules.Outcome.FIGHTING
						if e.line == 1121:
							expected = GroundRules.Outcome.RETREATED
						elif then.kind == "ran":
							expected = GroundRules.Outcome.LOST
						elif then.line != 675:
							expected = GroundRules.Outcome.SURRENDERED
						_same("how the round before %d ended" % e.at, outcome, expected)
						match outcome:
							GroundRules.Outcome.SURRENDERED:
								said += "".join(GroundRules.SAID_SURRENDERED) + "".join(GroundRules.SAID_COLLECTING)
							GroundRules.Outcome.LOST:
								said += "".join(GroundRules.SAID_LOST)
							GroundRules.Outcome.RETREATED:
								said += "".join(GroundRules.SAID_RETREATING)
					elif e.line in [675, 690, 1130]:
						_expect(e)
	_same("random numbers drawn by the end", _drawn, _draws.size())


## The numbers of a round against the program's variables, its bytes
## and line 4010's print.
func _round(e: Dictionary, shown: String) -> void:
	var r := _rules
	_same("the battle screen's numbers at %d" % e.at,
			"%d %d %d %d %d %d%%" % [r.fighters, r.transports, r.troops, r.tanks, r.missiles, r.success], shown)
	# line 1120 has added the troops held back by the time 1121 begins
	var pairs := {"TR": r.troops + (r.reserve if e.line == 1121 else 0.0), "P": r.fighters, "TP": r.transports, "T": r.tanks, "VP": r.progress,
			"SP": r.enemy, "PS": r.success, "T9": r.reserve}
	for name in pairs:
		_near(name, pairs[name], e.vars[name], e.at)
	for address in [38153, 38154, 38155, 38156]:
		_same("%d at %d" % [address, e.at], _peek(address), e.bytes[address])


## Every byte the rules keep, against the recording's.
func _expect(e: Dictionary) -> void:
	for address in e.bytes:
		var ours: Variant = _peek(address)
		if ours == null:
			continue
		var theirs: int = e.bytes[address]
		if address == 301: # only 1 means a haul was made; it starts at 255
			_same("301 at %d" % e.at, ours, int(theirs == 1))
		else:
			_same("%d at %d" % [address, e.at], ours, theirs)


func _load(e: Dictionary) -> void:
	for address in e.bytes:
		_poke(address, e.bytes[address])


func _peek(address: int) -> Variant:
	if address >= LOOT and address < LOOT + 13:
		return int(GameState.loot[address - LOOT])
	match address:
		38150: return int(GameState.gf_enemy_strength)
		38153: return int(GameState.gf_missiles)
		38154: return int(GameState.gf_tanks)
		38155: return int(GameState.gf_transports)
		38156: return int(GameState.gf_fighters)
		38158: return GameState.troops_stationed_at
		38160: return int(GameState.gf_victory_progress)
		38166: return GameState.troop_location
		38170: return GameState.morale_flag
		38203: return GameState.troop_morale
		38205: return GameState.orbital_defender_tier
		38207: return GameState.flight_escort_fighters
		38208: return int(GameState.gf_planet_surrendered)
		38209: return GameState.current_planet + 1
		38210: return int(GameState.in_atmosphere)
		38220: return GameState.planet_secured[0]
		38283: return GameState.planet_tech[0]
		38304: return int(GameState.planet_has_base[0])
		301: return int(GameState.loot_collected_this_visit)
		29469: return GameState.ship_y & 0xFF
		29470: return (GameState.ship_y >> 8) & 0xFF
	return null


func _poke(address: int, value: int) -> void:
	if address >= LOOT and address < LOOT + 13:
		GameState.loot[address - LOOT] = float(value)
		return
	match address:
		38150: GameState.gf_enemy_strength = float(value)
		38153: GameState.gf_missiles = float(value)
		38154: GameState.gf_tanks = float(value)
		38155: GameState.gf_transports = float(value)
		38156: GameState.gf_fighters = float(value)
		38158: GameState.troops_stationed_at = value
		38160: GameState.gf_victory_progress = float(value)
		38166: GameState.troop_location = value
		38170: GameState.morale_flag = value
		38203: GameState.troop_morale = value
		38205: GameState.orbital_defender_tier = value
		38207: GameState.flight_escort_fighters = value
		38208: GameState.gf_planet_surrendered = value == 1
		38209: GameState.current_planet = value - 1
		38210: GameState.in_atmosphere = value != 0
		38220: GameState.planet_secured[0] = value
		38283: GameState.planet_tech[0] = value
		38304: GameState.planet_has_base[0] = value != 0
		301: GameState.loot_collected_this_visit = value == 1
		29469: GameState.ship_y = (GameState.ship_y & 0xFF00) | value
		29470: GameState.ship_y = (GameState.ship_y & 0xFF) | (value << 8)


func _draw() -> float:
	if _drawn >= _draws.size():
		_wrong("a random number drawn that the recording never drew")
		return 0.5
	_drawn += 1
	return _draws[_drawn - 1][1]


## How many random numbers the recording had drawn before event `index`.
func _before(index: int) -> int:
	var count := 0
	for draw in _draws:
		if draw[0] < index:
			count += 1
	return count


func _next_menu(index: int) -> Dictionary:
	for i in range(index + 1, _events.size()):
		if _events[i].kind == "get":
			return _events[i]
	return {"vars": {}}


func _next_stop(index: int) -> Dictionary:
	for i in range(index + 1, _events.size()):
		if _events[i].kind in ["ran", "at", "get"]:
			return _events[i]
	return {"kind": "ran"}


func _flat(messages: Array) -> String:
	var all := ""
	for lines in messages:
		all += "".join(lines)
	return all


func _read(path: String) -> void:
	_events = []
	_draws = []
	_drawn = 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_wrong("cannot read " + path)
		return
	var stop := RegEx.create_from_string("^\\s*([\\d.]+) \\[\\d+\\] -- (ran|at|get) (\\S+)(.*)$")
	var poke := RegEx.create_from_string("^\\s*[\\d.]+ \\[\\d+\\] -- poke (\\d+)=(\\d+)")
	var key := RegEx.create_from_string("^\\s*[\\d.]+ \\[\\d+\\] -- key '(.)'")
	var statement := RegEx.create_from_string("^\\s*[\\d.]+ \\[\\d+\\] line (\\d+)\\s.*  \"(.*)\"$")
	var byte := RegEx.create_from_string(" (\\d+)=(\\d+)")
	while not file.eof_reached():
		var line := file.get_line()
		var m := stop.search(line)
		if m != null:
			var e := {"kind": m.get_string(2), "name": m.get_string(3), "at": int(float(m.get_string(1))),
					"line": int(m.get_string(3)) if m.get_string(2) == "at" else -1, "bytes": {}, "vars": {}}
			for b in byte.search_all(m.get_string(4)):
				e.bytes[int(b.get_string(1))] = int(b.get_string(2))
			_events.append(e)
			continue
		if line.begins_with("    vars"):
			for pair in line.substr(9).split(" ", false):
				var halves := pair.split("=")
				if halves.size() == 2 and halves[1].is_valid_float():
					_events[-1].vars[halves[0]] = float(halves[1])
			continue
		if line.begins_with("    rnd"):
			for number in line.substr(8).split(" ", false):
				var halves := number.split(":")
				var value := halves[1].hex_to_int() / 4294967296.0 * pow(2.0, halves[0].hex_to_int() - 0x80)
				_draws.append([_events.size(), value])
			continue
		m = poke.search(line)
		if m != null:
			_events.append({"kind": "poke", "address": int(m.get_string(1)), "value": int(m.get_string(2))})
			continue
		m = key.search(line)
		if m != null:
			_events.append({"kind": "key", "key": m.get_string(1)})
			continue
		m = statement.search(line)
		if m != null and not m.get_string(2).strip_edges().is_empty():
			_events.append({"kind": "text", "line": int(m.get_string(1)), "text": m.get_string(2)})


func _same(what: String, ours: Variant, theirs: Variant) -> void:
	_checked += 1
	if ours != theirs:
		_wrong("%s: %s, the recording has %s" % [what, ours, theirs])


func _near(what: String, ours: float, theirs: float, at: int) -> void:
	_checked += 1
	if absf(ours - theirs) > 1e-6 * maxf(1.0, absf(theirs)):
		_wrong("%s at %d: %s, the recording has %s" % [what, at, ours, theirs])


func _wrong(what: String) -> void:
	_bad += 1
	print("WRONG  %s: %s" % [_route, what])
