extends RefCounted
## The rules of SHORE LEAVE.bas, the program behind GROUND FORCES'
## commands 3 to 8: shore leave, enlisting (and the weapons bought with
## it), selling the loot, repairs, a new base and the cryogenic sleep.
## What each does to the game and what the crew says about it; nothing
## here draws or waits (scripts/ui/shore_leave.gd shows it). Line
## numbers are the original's. tests/check_shore_rules.gd plays the
## recordings in analysis/live/shore/ through this, with the numbers RND
## gave on the real machine, and compares the state.
##
## The original keeps the credits and the troops in a file it reads at
## the start and writes at the end of every command that changes them,
## so here they are simply GameState's.

const SHORE_LEAVE := 3
const ENLIST := 4
const SELL_LOOT := 5
const REPAIR := 6
const BASE := 7
const CRYOGENICS := 8

const SAID_NOT_SURRENDERED: Array[String] = ["SIR! THE PLANET", "HASN'T SURRENDERED!"]
const SAID_MUST_LAND: Array[String] = ["YOU MUST LAND ON", "PLANET FIRST."]
const SAID_ANGRY: Array[String] = ["I'M AFRAID YOU'VE", "MADE THE LOCAL", "GOVERNMENT ANGRY!"]

const MOST_TROOPS := 20000.0
const MOST_OF_A_WEAPON := 255.0
## 3000: the weapons in the order they are offered, the GameState count
## of each and the price each is drawn around (MU).
const WEAPONS := [
	["FIGHTERS", "gf_fighters", 50.0], ["TRANSPORTS", "gf_transports", 75.0],
	["TANKS", "gf_tanks", 40.0], ["MISSILES", "gf_missiles", 30.0],
]
## 2400-2405: what one of each of the thirteen kinds of loot fetches.
## The first is drawn afresh at every sale.
const LOOT_WORTH := [0.0, 150.0, 100.0, 200.0, 200.0, 200.0, 300.0, 15.0, 5.0, 25.0, 1500.0, 1000.0, 2000.0]
const LOOT_WORTH_FIRST := 300.0
## 2500: the ship's systems in the order they are looked over.
const SYSTEMS := [
	["SHIELD", "ship_shield"], ["ENERGY", "ship_energy"], ["# 1 ENGINE", "ship_engine1"],
	["# 2 ENGINE", "ship_engine2"], ["COMPUTER", "ship_computer"], ["RADAR", "ship_radar"],
	["ENV. CONTROL", "ship_env_control"], ["HULL DMG.", "ship_hull"], ["HYPERDRIVE", "ship_hyperdrive"],
	["MISSILES", "ship_missile_system"], ["LASER", "ship_laser"], ["NAV. COMP.", "ship_nav_computer"],
]
const ENERGY := 1
const MISSILES := 9
const FULL := 100.0
const FULL_ENERGY := 63.0

## A number in [0, 1), as RND(1) gives.
var rnd: Callable = randf

## A question follows what was just said.
var asking := false
var base_cost := 0.0   ## C, 2170
var weapon_price := 0.0 ## C, 3060
var bill := 0.0        ## P, the repairs


## Lines 4-5: why command 3-8 of GROUND FORCES comes straight back, or
## nothing. The cryogenic sleep is the one thing a planet that has not
## given in does not stand in the way of.
static func refusal(command: int) -> Array[String]:
	if command != CRYOGENICS and not GameState.gf_planet_surrendered:
		return SAID_NOT_SURRENDERED
	return []


# --- 3) SHORE LEAVE ---

## Line 2082.
func shore_leave_offer() -> Array[String]:
	return [
		"TROOPS READY FOR", "SHORE LEAVE, SIR.", "BACK PAY COMES TO", "%d CREDITS." % GameState.troops, "",
		"YOU HAVE %d" % GameState.credits, "CREDITS.",
	]


## Lines 2087-2098. Leave without pay is leave all the same: the troops
## go ashore here either way.
func shore_leave(pay: bool) -> Array[String]:
	var said: Array[String] = []
	GameState.morale_flag = 70
	if pay and GameState.troops > GameState.credits: # 2090
		said = ["YOU DON'T HAVE", "ENOUGH CREDITS, SIR!"]
		pay = false
	if pay: # 2093-2095
		GameState.troop_morale = mini(GameState.troop_morale + 1, 6)
		GameState.credits = floorf(GameState.credits - GameState.troops)
	else: # 2088-2089
		GameState.troop_morale = maxi(GameState.troop_morale - 2, 1)
	GameState.troops_stationed_at = GameState.current_planet + 1 # 2098
	GameState.troop_location = 2
	return said


# --- 7) ESTABLISH BASE ---

## Lines 2100-2130. The price is drawn before anything is looked at,
## and the one try a trip is used up by being told the price.
func base_offer() -> Array[String]:
	var here := GameState.current_planet
	asking = false
	base_cost = 20000 + (rnd.call() * 5000) * (rnd.call() * 10) # 2170
	if GameState.planet_has_base[here]:
		return ["THERE IS ALREADY", "A BASE ON THIS", "PLANET, SIR!"]
	if GameState.planet_tech[here] < 2:
		return ["THIS PLANET IS TOO", "BACKWARD TO BUILD", "A BASE, SIR!"]
	if GameState.base_built_this_trip:
		return ["ONLY ONE TIME PER", "TRIP, SIR."]
	GameState.base_built_this_trip = true
	base_cost = floorf(base_cost)
	var said: Array[String] = [
		"SIR! IT WILL COST", "%d TO BUILD A" % base_cost, "BASE HERE.", "", "YOU HAVE %d" % GameState.credits,
		"CREDITS NOW.",
	]
	if GameState.credits < base_cost:
		said.append_array(["YOU DON'T HAVE", "ENOUGH CREDITS TO", "BUILD A BASE HERE."])
	else:
		asking = true
	return said


## Lines 2159-2160, the Y to BUILD A BASE?
func build_base() -> Array[String]:
	GameState.credits = floorf(GameState.credits - base_cost)
	GameState.planet_has_base[GameState.current_planet] = true
	return ["CONSTRUCTION IS", "UNDER WAY, SIR."]


# --- 4) ENLIST TROOPS, and the weapons ---

## Lines 2200-2270. Like the base, the one time a trip is used up here.
func enlist_offer() -> Array[String]:
	asking = false
	if GameState.enlisted_this_trip:
		return ["ONE TIME PER TRIP."]
	GameState.enlisted_this_trip = true
	asking = true
	return enlist_terms()


## Lines 2250-2270.
func enlist_terms() -> Array[String]:
	return [
		"EACH NEW TROOP", "MUST BE PAID ONE", "CREDIT IN ADVANCE.", "YOU HAVE %d" % GameState.credits,
		"CREDITS, SIR.", "TROOPS= %d" % GameState.troops,
	]


## Lines 2280-2290: why `count` recruits are not taken on, or nothing
## when they are (none at all is a number like any other). The weapons
## are offered next.
func enlist(count: float) -> Array[String]:
	if count > GameState.credits:
		return ["YOU DON'T HAVE", "%d CREDITS!" % count]
	if GameState.troops + count > MOST_TROOPS:
		return ["TOO MANY TROOPS."]
	GameState.troops += count
	GameState.credits -= count
	return []


## Line 3060: the price asked for weapon `index` this time.
func price_weapon(index: int) -> float:
	weapon_price = floorf((rnd.call() + 0.2) * 4 * WEAPONS[index][2])
	return weapon_price


func weapon_count(index: int) -> float:
	return GameState.get(WEAPONS[index][1])


## Lines 3070-3110: why `count` of weapon `index` are not bought at the
## price asked, or nothing when they are.
func buy(index: int, count: float) -> Array[String]:
	var aboard := weapon_count(index)
	if count < 0 or count > MOST_OF_A_WEAPON:
		return ["BUY 255 MAX."]
	if count + aboard > MOST_OF_A_WEAPON:
		return ["255 MAX"]
	if count * weapon_price > GameState.credits:
		return ["NOT ENOUGH CREDITS"]
	GameState.credits = floorf(GameState.credits - count * weapon_price)
	GameState.set(WEAPONS[index][1], aboard + count)
	return []


# --- 5) SELL LOOT ---

## Lines 2400-2460.
func sell_loot() -> Array[String]:
	var worth: float = GameState.loot[0] * (LOOT_WORTH_FIRST * rnd.call())
	for kind in range(1, LOOT_WORTH.size()):
		worth += GameState.loot[kind] * LOOT_WORTH[kind]
	worth = floorf(worth * 2)
	var had := floorf(GameState.credits)
	GameState.credits = had + worth
	GameState.loot.fill(0.0)
	return [
		"YOU HAD %d" % had, "CREDITS.", "YOUR LOOT IS WORTH", "%d CREDITS." % worth, "", "THAT GIVES YOU A",
		"TOTAL OF %d" % GameState.credits, "CREDITS!",
	]


# --- 6) REPAIR ---

## Line 2505: on the ground, by the low byte of the height alone.
func landed() -> bool:
	return GameState.in_atmosphere and (GameState.ship_y & 0xFF) <= 22


## Lines 2510-2555: every system below its best is mended there and
## then, whatever comes of the bill. Returns each one mended with what
## it was at: [name, percent].
func repair() -> Array:
	var mended: Array = []
	bill = 0.0
	for index in SYSTEMS.size():
		var system: Array = SYSTEMS[index]
		var was := floorf(GameState.get(system[1]))
		var best := FULL_ENERGY if index == ENERGY else FULL
		if was >= best:
			continue
		var cost: float
		match index:
			ENERGY: # 2524-2525: its 63 counted as a hundred
				cost = floorf(rnd.call() * 200 * (100 - _energy_gone(was)))
			MISSILES: # 2530
				cost = floorf(rnd.call() * 100 * (100 - was))
			_: # 2520
				cost = floorf(rnd.call() * 150 * (100 - was))
		bill += cost
		GameState.set(system[1], best)
		mended.append([system[0], int(was)])
	GameState.damage_alert_active = false # 2555
	GameState.credits = floorf(GameState.credits)
	asking = GameState.credits >= bill # 2560
	return mended


## Lines 2550-2560.
func bill_said() -> Array[String]:
	return [
		"ALL REPAIRS ARE", "COMPLETE, SIR.", "THE TOTAL REPAIR", "BILL COMES TO", "%d CREDITS." % bill,
		"YOU HAVE %d" % GameState.credits, "CREDITS.",
	]


## Lines 2580-2610: the bill paid, refused, or beyond the credits there
## are. A bill of nothing cannot be refused. Refusing, or not having
## it, loses the planet (and not having it, every credit too).
func settle(pay: bool) -> Array[String]:
	var said: Array[String] = []
	if GameState.credits < bill: # 2602
		said = ["YOU DON'T HAVE", "ENOUGH CREDITS!", "YOU HAVE 0 CREDITS", "LEFT!"]
		GameState.credits = 0.0
	elif pay or bill == 0: # 2590
		GameState.credits = floorf(GameState.credits - bill)
		return []
	said.append_array(SAID_ANGRY) # 2605-2610
	GameState.gf_planet_surrendered = false
	GameState.planet_secured[GameState.current_planet] = 0
	return said


## 2524-2525: `D2 = (63 - D) * (100 / 63): D1 = INT((D2 / 100) * 100)`.
## This gives what Applesoft's own arithmetic gives for every energy
## from 0 to 62 (analysis/live/shore/shore_float_live.txt).
func _energy_gone(was: float) -> float:
	return floorf((FULL_ENERGY - was) * (100.0 / FULL_ENERGY))


# --- 8) CRYOGENICS ---

## Lines 4000-4020.
func cryogenics() -> Array[String]:
	match GameState.troop_location:
		1, 2:
			return ["TROOPS NOT ON", "BOARD, SIR."]
		3:
			GameState.troop_location = 0
			return ["TROOPS ARE BEING", "REVIVED, SIR."]
		_:
			GameState.troop_location = 3
			return ["TROOPS ARE BEING", "PUT IN CRYOGENICS"]
