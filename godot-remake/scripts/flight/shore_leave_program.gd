extends RefCounted
## GROUND FORCES' commands 3 to 8, the six of SHORE LEAVE.bas: shore leave,
## enlisting and the weapons bought with it, the sale of the loot, repairs, a
## new base and the cryogenic sleep, said and asked on the CRT console. What
## each does and what the crew says is scripts/rules/shore_rules.gd, held to
## the real game (tests/check_shore_rules.gd); this asks, shows, and keeps
## the time.
##
## Where it parts from the original, on purpose:
## - a number is typed on a line that takes digits and nothing else. The
##   original took any characters and made what it could of them, so that a
##   number below zero or a part of a troop could be enlisted;
## - Y and N are asked for by name. The original took any key but N as yes
##   to the repair bill, and did not ask it of a bill of nothing any less
##   than of another;
## - TOO MANY TROOPS asks again; the original began the command again to do it;
## - the pauses are about the original's, but a key moves on.

const ShoreRules = preload("res://scripts/rules/shore_rules.gd")

# Seconds.
const LEAVE := 4.0    ## the last thing said, before the menu is back (line 2099)
const READ := 6.0     ## the same when it is a screenful
const REFUSAL := 2.5  ## why a number was not taken
const BRIEF := 1.0    ## nothing new to read

const TITLES := {
	ShoreRules.SHORE_LEAVE: "SHORE LEAVE", ShoreRules.ENLIST: "ENLIST TROOPS", ShoreRules.SELL_LOOT: "SELL LOOT",
	ShoreRules.REPAIR: "REPAIR SHIP", ShoreRules.BASE: "ESTABLISH BASE", ShoreRules.CRYOGENICS: "CRYOGENICS",
}

var _rules := ShoreRules.new()
var _console: Node
var _title := ""


## Runs command `command` (3 to 8) to its end.
func run(console: Node, command: int) -> void:
	_console = console
	_title = "-%s-" % TITLES[command]
	match command:
		ShoreRules.SHORE_LEAVE: await _shore_leave()
		ShoreRules.ENLIST: await _enlist()
		ShoreRules.SELL_LOOT: await _sell_loot()
		ShoreRules.REPAIR: await _repair()
		ShoreRules.BASE: await _base()
		ShoreRules.CRYOGENICS: await _cryogenics()


## Lines under the command's title.
func _page(lines: Array) -> Array:
	return [_title] + lines


## @witness SHORE LEAVE 2085
func _shore_leave() -> void:
	var offer := _rules.shore_leave_offer()
	var pay: bool = await _console.ask_yes_no(_page(offer + ["PAY THEM?"]))
	var short := _rules.shore_leave(pay)
	if short.is_empty():
		await _console.wait(BRIEF)
	else:
		await _console.say(_page(short), LEAVE)


## @witness SHORE LEAVE 2140
func _base() -> void:
	var offer := _rules.base_offer()
	if not _rules.asking:
		await _console.say(_page(offer), LEAVE)
	elif await _console.ask_yes_no(_page(offer + ["BUILD A BASE?"])):
		await _console.say(_page(_rules.build_base()), LEAVE)
	else:
		await _console.wait(BRIEF)


func _sell_loot() -> void:
	await _console.say(_page(_rules.sell_loot()), READ)


func _cryogenics() -> void:
	await _console.say(_page(_rules.cryogenics()), LEAVE)


## A whole number is asked for (none below nothing; nothing typed is none).
## @witness SHORE LEAVE 5000-5010
func _enlist() -> void:
	var offer := _rules.enlist_offer()
	if not _rules.asking:
		await _console.say(_page(offer), LEAVE)
		return
	var terms: Array = offer
	while true:
		var asked: float = await _console.ask_number(_page(terms), "HOW MANY TROOPS DO YOU WANT TO ENLIST? ")
		var why := _rules.enlist(asked)
		if why.is_empty():
			break
		await _console.say(_page(why), REFUSAL)
		terms = _rules.enlist_terms()
	_title = "-BUY WEAPONS-"
	for weapon in ShoreRules.WEAPONS.size():
		var offer_line := "%s COST %d" % [ShoreRules.WEAPONS[weapon][0], _rules.price_weapon(weapon)]
		while true:
			var asked: float = await _console.ask_number(_page(_weapons() + [offer_line]), "BUY HOW MANY? ")
			var why := _rules.buy(weapon, asked)
			if why.is_empty():
				break
			await _console.say(_page(_weapons() + why), REFUSAL)
	await _console.say(_page(_weapons()), LEAVE)


## The credits and what is held of each weapon, in two columns.
func _weapons() -> Array:
	var lines := [_console.columns("CREDITS", "%d" % GameState.credits)]
	var names: Array = []
	for weapon in ShoreRules.WEAPONS.size():
		names.append("%s %d" % [ShoreRules.WEAPONS[weapon][0], _rules.weapon_count(weapon)])
	for i in range(0, names.size(), 2):
		lines.append(_console.columns(names[i], names[i + 1] if i + 1 < names.size() else ""))
	return lines


func _repair() -> void:
	if not _rules.landed():
		await _console.say(_page(ShoreRules.SAID_MUST_LAND), LEAVE)
		return
	var mended := _rules.repair()
	if not mended.is_empty():
		var rows: Array = []
		for i in range(0, mended.size(), 2):
			var left: Array = mended[i]
			var right: Array = mended[i + 1] if i + 1 < mended.size() else ["", 0]
			rows.append(_console.columns("%s %d%%" % [left[0], left[1]], "%s %d%%" % [right[0], right[1]] if right[0] != "" else ""))
		await _console.say(_page(rows), LEAVE)
	var bill := _rules.bill_said()
	var pay := true
	if not _rules.asking: # more than there is
		await _console.say(_page(bill), LEAVE)
	elif _rules.bill > 0:
		pay = await _console.ask_yes_no(_page(bill + ["ARE YOU GOING TO PAY, SIR?"]))
	else: # a bill of nothing is up for the pause below
		_console.show(_page(bill))
	var angry := _rules.settle(pay)
	if angry.is_empty():
		await _console.wait(BRIEF if _rules.bill > 0 else LEAVE)
	else:
		await _console.say(_page(angry), READ)
