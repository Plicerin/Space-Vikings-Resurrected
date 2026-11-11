extends Node
## The rules of SHORE LEAVE (scripts/rules/shore_rules.gd) against the
## real game: every route recorded by tools/mame/shore_live.lua
## (analysis/live/shore/) is played through the rules with the keys
## pressed there and the numbers RND gave there, and at each stop of
## the recording the game's bytes, the credits, the troops, the prices
## and what was printed are compared. A recording that drew more or
## fewer random numbers than the rules did is wrong too.
##
##   godot --headless --path godot-remake res://tests/check_shore_rules.tscn

const ShoreRules = preload("res://scripts/rules/shore_rules.gd")
const GroundRules = preload("res://scripts/rules/ground_rules.gd")
const LOGS := "../analysis/live/shore"
const ROUTES := ["gates", "pay", "loot", "base", "enlist", "repair", "edges"]
## SHORE LEAVE's lines that say something a rule decides.
const SPOKEN := [
	5, 2082, 2090, 2100, 2105, 2106, 2110, 2130, 2160, 2210, 2240, 2250, 2260, 2270, 2280, 2285, 2430, 2460,
	2505, 2520, 2525, 2530, 2550, 2560, 2602, 2605, 3070, 3072, 3090, 4000, 4010, 4020,
]
## What those lines print besides: the questions and a title, which are
## the scene's to put.
const NOT_THE_RULES := ["HOWMANYTROOPSDOYOUWANTTOENLIST?", "BUYHOWMANY?", "REPAIRSHIP"]
const LOOT := 38171
const TRIP_FLAGS := {38149: "base_built_this_trip", 38389: "enlisted_this_trip"}
const SYSTEMS := {
	38200: "ship_shield", 38199: "ship_energy", 38198: "ship_engine1", 38197: "ship_engine2",
	38196: "ship_computer", 38195: "ship_radar", 38194: "ship_env_control", 38193: "ship_hull",
	38190: "ship_hyperdrive", 38187: "ship_missile_system", 38186: "ship_laser", 38184: "ship_nav_computer",
}
const WEAPONS := {38156: "gf_fighters", 38155: "gf_transports", 38154: "gf_tanks", 38153: "gf_missiles"}

var _bad := 0
var _checked := 0
var _route := ""
var _events: Array = []
var _draws: Array = [] ## [event index, value]
var _drawn := 0
var _rules: ShoreRules
var _ground: GroundRules


func _ready() -> void:
	for route in ROUTES:
		_route = route
		var before := [_bad, _checked]
		_play(ProjectSettings.globalize_path("res://").path_join(LOGS).path_join("shore_%s.log" % route))
		print("%s: %d checks, %d wrong, %d random numbers" % [route, _checked - before[1], _bad - before[0], _draws.size()])
	print("shore rules: %d wrong of %d" % [_bad, _checked])
	get_tree().quit(1 if _bad > 0 else 0)


func _play(path: String) -> void:
	_read(path)
	GameState.start_new_game()
	_rules = null
	var program := ""
	var ours := false   # the state is the rules' own doing since the last load
	var at_menu := false
	var command := 0    # the one SHORE LEAVE is run for
	var phase := ""     # what SHORE LEAVE is waiting to be told: pay, build, bill, enlist, buy
	var weapon := 0
	var said := ""
	var heard := ""

	for i in _events.size():
		var e: Dictionary = _events[i]
		match e.kind:
			"poke":
				_poke(e.address, e.value)
			"set":
				GameState.credits = e.value
			"text":
				if program == "SHORE_LEAVE" and e.line in SPOKEN:
					heard += e.text
			"key":
				if at_menu:
					at_menu = false
					command = int(e.key)
					if command < 3 or command > 8 or not _ground.refusal(command).is_empty():
						command = 0
				elif program == "SHORE_LEAVE":
					match phase:
						"pay":
							if e.key == "Y" or e.key == "N":
								said += "".join(_rules.shore_leave(e.key == "Y"))
								phase = ""
						"build":
							if e.key == "Y":
								said += "".join(_rules.build_base())
							if e.key == "Y" or e.key == "N":
								phase = ""
						"bill":
							said += "".join(_rules.settle(e.key != "N"))
							phase = ""
			"enter":
				var count: float = e.text.to_float()
				match phase:
					"enlist":
						var why := _rules.enlist(count)
						said += "".join(why)
						if why.is_empty():
							phase = "buy"
							weapon = 0
							_rules.price_weapon(weapon)
						elif why.size() == 1: # too many: the program starts over (2285)
							said += "".join(_rules.enlist_terms())
						else: # too dear: asked again from 2270
							said += "TROOPS= %d" % GameState.troops
					"buy":
						var why := _rules.buy(weapon, count)
						said += "".join(why)
						if why.is_empty():
							weapon += 1
							if weapon < ShoreRules.WEAPONS.size():
								_rules.price_weapon(weapon)
							else:
								phase = ""
					_:
						_wrong("a number entered that nothing asked for")
			"ran":
				_heard("in %s before %d" % [program, e.at], said, heard)
				_same("random numbers drawn in %s before %d" % [program, e.at], _drawn, _before(i))
				_drawn = _before(i)
				_same("left unasked in %s before %d" % [program, e.at], phase, "")
				said = ""
				heard = ""
				phase = ""
				program = e.name
				at_menu = false
				match program:
					"GROUND_FORCES":
						var filed: Dictionary = _next_menu(i).vars
						if ours:
							_expect(e)
							_filed(filed, e.at)
						_load(e)
						GameState.troops = filed.get("TR", -1.0)
						GameState.credits = filed.get("CR", -1.0)
						_ground = GroundRules.new()
						_ground.open_menu()
						ours = true
					"SHORE_LEAVE":
						if command == 0:
							_wrong("SHORE LEAVE ran at %d for a command the rules refuse" % e.at)
							ours = false
							continue
						_rules = ShoreRules.new()
						_rules.rnd = _draw
						# credits the recorder set before the program looked at them
						for later in range(i + 1, _events.size()):
							if _events[later].kind in ["get", "key", "enter", "ran"]:
								break
							if _events[later].kind == "set":
								GameState.credits = _events[later].value
						var why := ShoreRules.refusal(command)
						if not why.is_empty():
							said += "".join(why)
							continue
						match command:
							ShoreRules.SHORE_LEAVE:
								said += "".join(_rules.shore_leave_offer())
								phase = "pay"
							ShoreRules.ENLIST:
								said += "".join(_rules.enlist_offer())
								phase = "enlist" if _rules.asking else ""
							ShoreRules.SELL_LOOT:
								said += "".join(_rules.sell_loot())
							ShoreRules.REPAIR:
								if not _rules.landed():
									said += "".join(ShoreRules.SAID_MUST_LAND)
									continue
								for row: Array in _rules.repair():
									var colon := "" if row[0] in ["ENERGY", "MISSILES"] else ":"
									said += "%s%s%d%%" % [row[0], colon, row[1]]
								said += "".join(_rules.bill_said())
								if _rules.asking:
									phase = "bill"
								else:
									said += "".join(_rules.settle(false))
							ShoreRules.BASE:
								said += "".join(_rules.base_offer())
								phase = "build" if _rules.asking else ""
							ShoreRules.CRYOGENICS:
								said += "".join(_rules.cryogenics())
					"COM":
						if ours:
							_expect(e)
					_:
						ours = false
			"get":
				if not ours:
					continue
				if program == "GROUND_FORCES":
					_expect(e)
					at_menu = true
				elif program == "SHORE_LEAVE":
					_same("random numbers drawn by %d" % e.at, _drawn, _before(i))
					_expect(e)
					_filed(e.vars, e.at)
					match e.line:
						2085:
							_same("asked at %d" % e.at, phase, "pay")
						2140:
							_same("asked at %d" % e.at, phase, "build")
							_near("the base's price", _rules.base_cost, e.vars.C, e.at)
						2580:
							_same("asked at %d" % e.at, phase, "bill")
							_near("the bill", _rules.bill, e.vars.get("P", 0.0), e.at)
						5000:
							if phase == "buy":
								_near("the weapon's price", _rules.weapon_price, e.vars.C, e.at)
								_near("which weapon", weapon, e.vars.J1, e.at)
							else:
								_same("asked at %d" % e.at, phase, "enlist")
			"at":
				if not ours or program != "SHORE_LEAVE":
					continue
				match e.line:
					2099: # the way out of every command
						_same("random numbers drawn by %d" % e.at, _drawn, _before(i))
						_same("left unasked at %d" % e.at, phase, "")
						_expect(e)
						_filed(e.vars, e.at)
						if command == ShoreRules.REPAIR:
							_near("the bill", _rules.bill, e.vars.get("P", 0.0), e.at)
	_same("random numbers drawn by the end", _drawn, _draws.size())


## What the rules said against what the program printed, the scene's
## own part of it and the spaces apart.
func _heard(where: String, said: String, heard: String) -> void:
	heard = heard.replace(" ", "")
	for scenes in NOT_THE_RULES:
		heard = heard.replace(scenes, "")
	_same("what was said " + where, said.replace(" ", ""), heard)


## The credits and the troops against the program's own.
func _filed(vars: Dictionary, at: int) -> void:
	if vars.has("CR"):
		_near("credits", GameState.credits, vars.CR, at)
		_near("troops", GameState.troops, vars.TR, at)


## Every byte the rules keep, against the recording's.
func _expect(e: Dictionary) -> void:
	for address in e.bytes:
		var ours: Variant = _peek(address)
		if ours == null:
			continue
		var theirs: int = e.bytes[address]
		if address == 301 or address in TRIP_FLAGS: # only 1 is set; they start at anything
			theirs = int(theirs == 1)
		_same("%d at %d" % [address, e.at], ours, theirs)


func _load(e: Dictionary) -> void:
	for address in e.bytes:
		_poke(address, e.bytes[address])


func _peek(address: int) -> Variant:
	if address >= LOOT and address < LOOT + 13:
		return int(GameState.loot[address - LOOT])
	for names: Dictionary in [TRIP_FLAGS, SYSTEMS, WEAPONS]:
		if address in names:
			return int(GameState.get(names[address]))
	match address:
		38158: return GameState.troops_stationed_at
		38166: return GameState.troop_location
		38170: return GameState.morale_flag
		38203: return GameState.troop_morale
		38208: return int(GameState.gf_planet_surrendered)
		38209: return GameState.current_planet + 1
		38210: return int(GameState.in_atmosphere)
		38220: return GameState.planet_secured[0]
		38283: return GameState.planet_tech[0]
		38304: return int(GameState.planet_has_base[0])
		38393: return int(GameState.damage_alert_active)
		301: return int(GameState.loot_collected_this_visit)
		29469: return GameState.ship_y & 0xFF
		29470: return (GameState.ship_y >> 8) & 0xFF
	return null


func _poke(address: int, value: int) -> void:
	if address >= LOOT and address < LOOT + 13:
		GameState.loot[address - LOOT] = float(value)
		return
	if address in TRIP_FLAGS:
		GameState.set(TRIP_FLAGS[address], value == 1)
		return
	for names: Dictionary in [SYSTEMS, WEAPONS]:
		if address in names:
			GameState.set(names[address], float(value))
			return
	match address:
		38158: GameState.troops_stationed_at = value
		38166: GameState.troop_location = value
		38170: GameState.morale_flag = value
		38203: GameState.troop_morale = value
		38208: GameState.gf_planet_surrendered = value == 1
		38209: GameState.current_planet = value - 1
		38210: GameState.in_atmosphere = value != 0
		38220: GameState.planet_secured[0] = value
		38283: GameState.planet_tech[0] = value
		38304: GameState.planet_has_base[0] = value != 0
		38393: GameState.damage_alert_active = value != 0
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


func _read(path: String) -> void:
	_events = []
	_draws = []
	_drawn = 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_wrong("cannot read " + path)
		return
	var stop := RegEx.create_from_string("^\\s*([\\d.]+) \\[\\d+\\] -- (ran|at|get) (\\S+)(.*)$")
	var at_line := RegEx.create_from_string(" line=(\\d+)")
	var poke := RegEx.create_from_string("^\\s*[\\d.]+ \\[\\d+\\] -- poke (\\d+)=(\\d+)")
	var set_credits := RegEx.create_from_string("^\\s*[\\d.]+ \\[\\d+\\] -- set CR=([\\d.]+)")
	var key := RegEx.create_from_string("^\\s*[\\d.]+ \\[\\d+\\] -- key '(.)'")
	var enter := RegEx.create_from_string("^\\s*[\\d.]+ \\[\\d+\\] -- enter '(.*)'")
	var statement := RegEx.create_from_string("^\\s*[\\d.]+ \\[\\d+\\] line (\\d+)\\s.*  \"(.*)\"$")
	var byte := RegEx.create_from_string(" (\\d+)=(\\d+)")
	while not file.eof_reached():
		var line := file.get_line()
		var m := stop.search(line)
		if m != null:
			var e := {"kind": m.get_string(2), "name": m.get_string(3), "at": int(float(m.get_string(1))),
					"line": int(at_line.search(m.get_string(4)).get_string(1)), "bytes": {}, "vars": {}}
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
		m = set_credits.search(line)
		if m != null:
			_events.append({"kind": "set", "value": float(m.get_string(1))})
			continue
		m = key.search(line)
		if m != null:
			_events.append({"kind": "key", "key": m.get_string(1)})
			continue
		m = enter.search(line)
		if m != null:
			_events.append({"kind": "enter", "text": m.get_string(1)})
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
