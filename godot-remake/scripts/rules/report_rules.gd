extends RefCounted
## What STATUS.bas and SUPPLY.bas say, the central computer's SHIP
## STATUS and SUPPLY STATUS: each a list of what the game holds, put
## into words. No screen in it (scripts/reports/report_console.gd shows
## it). tests/check_report_rules.gd compares it with what the real
## game printed, taken from the recordings in analysis/live/reports/.
##
## The listings' own line numbers are given for each. Where the original
## shows a number that is not the game's (see the first three notes) the
## rule follows the original; where the machine got in the way of the
## text (see the last two) it does not.
##
## - The energy is a percentage of 62 and a full ship has 63: line
##   1256 makes the 101% 100.
## - "HULL DMG" is 100 less the hull's byte, which counts what is left.
## - ENV. and NAV.COMP. are the number 100, whatever their bytes hold.
## - A condition, morale or place that has no word has no word here;
##   the original left the cursor where it was and the next line ran on
##   from it.
## - Line 1386's THE TROOPS ARE ALL DEAD! goes by two bytes that nothing
##   in the game sets, so it cannot print. Here it goes by what it
##   means: no troops left.
## - SUPPLY writes a number into three cells and its unit over the rest,
##   so 2550 pounds read "= 255POUNDS". Here they are as they are.

const CONDITIONS := {1: "GREEN", 2: "BLUE", 3: "RED"}
const MORALES := {1: "AWFUL!!!", 2: "POOR", 3: "SO-SO", 4: "FAIR", 5: "GOOD", 6: "EXCELLENT!"}
const PLACES := {3: "CRYOGENIC SLEEP", 0: "ON BOARD", 1: "PLANETSIDE", 2: "SHORE LEAVE"}

## 1410-1490: the loot in the order it is listed, [name, index into
## GameState.loot, what one of it counts for, unit]. The first page ends
## at fissionables.
const LOOT := [
	["PLATINUM", 10, 10, "POUNDS"],
	["GOLD", 12, 10, "POUNDS"],
	["SILVER", 11, 20, "POUNDS"],
	["TITANIUM", 9, 1, "THOUSAND POUNDS"],
	["COLLAPSIUM", 8, 1, "TONS"],
	["STEEL", 7, 1, "TONS"],
	["FISSIONABLES", 6, 1, "POUNDS"],
	["ELECTRONIC PARTS", 5, 1, "CRATES"],
	["WEAPONS", 4, 1, "CRATES"],
	["FIGHTER PARTS", 3, 1, "CRATES"],
	["LUXURY FOODS", 2, 1, "CASES"],
	["WINE/LIQUOR", 1, 100, "CASES"],
	["ART WORKS", 0, 10, "UNITS"],
]


## Lines 1235-1310 and 5100-5120: the ship, a row at a time, each
## [label, value] once or twice (the original sets two side by side).
## @witness STATUS 1235-1310, 5100-5130
static func ship() -> Array:
	var gs := GameState
	return [
		[["LOCATION", _star(gs.current_planet)]],
		[["STARDATE", _number(gs.stardate)]],
		[["ENERGY", "%d%%" % mini(int(int(gs.ship_energy) / 62.0 * 100.0), 100)], ["CREDITS", _number(floorf(gs.credits))]],
		[["SHIELDS", "%d%%" % int(gs.ship_shield)], ["CONDITION", CONDITIONS.get(int(gs.condition), "")]],
		[["HULL DMG", "%d%%" % (100 - int(gs.ship_hull))], ["MISSILES", "%d" % int(gs.ship_missile_system)]],
		[["COMPUTER", "%d%%" % int(gs.ship_computer)], ["H-DRIVE", "%d%%" % int(gs.ship_hyperdrive)]],
		[["RADAR", "%d%%" % int(gs.ship_radar)], ["ENV.", "100%"]],
		[["LASER", "%d%%" % int(gs.ship_laser)], ["NAV.COMP.", "100%"]],
		[["ENGINE#1", "%d%%" % int(gs.ship_engine1)], ["ENGINE#2", "%d%%" % int(gs.ship_engine2)]],
	]


## Lines 1330-1386 and 5200-5210: the troops, [label, value] a line.
## @witness STATUS 1320-1385, 5200-5220
static func troops() -> Array:
	var gs := GameState
	return [
		["NO. OF TROOPS", _number(gs.troops)],
		["TROOP MORALE", MORALES.get(int(gs.troop_morale), "")],
		["TROOP LOCATION", PLACES.get(int(gs.troop_location), "")],
		["FIGHTERS", "%d" % int(gs.gf_fighters)],
		["TRANSPORTS", "%d" % int(gs.gf_transports)],
		["TANKS", "%d" % int(gs.gf_tanks)],
		["GROUND MISSILES", "%d" % int(gs.gf_missiles)],
	]


## Line 1386.
## @witness STATUS 1386
static func troops_all_dead() -> bool:
	return GameState.troops <= 0.0


## Lines 1410-1490: [name, amount, unit] for each kind of loot.
## @witness SUPPLY 1410-1490
static func supply() -> Array:
	var rows := []
	for kind: Array in LOOT:
		rows.append([kind[0], "%d" % int(GameState.loot[kind[1]] * kind[2]), kind[3]])
	return rows


## Line 1490's last: the credits, whole.
## @witness SUPPLY 1490
static func supply_credits() -> String:
	return _number(floorf(GameState.credits))


static func _star(index: int) -> String:
	return GameState.STAR_NAMES[clampi(index, 0, GameState.STAR_NAMES.size() - 1)]


## What Applesoft prints for a number: whole ones without a point, and
## no 0 before one.
static func _number(value: float) -> String:
	if value == floorf(value) and absf(value) < 1e9:
		return "%d" % value
	var text := String.num(value)
	return text.trim_prefix("0") if text.begins_with("0.") else text
