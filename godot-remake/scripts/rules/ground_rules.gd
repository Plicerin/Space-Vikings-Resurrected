extends RefCounted
## The rules of GROUND FORCES.bas, RECALL.bas and COLLECT.bas: what a
## command does to the game and what the crew says about it. Nothing
## here draws or waits; the scene (scripts/ui/ground_forces.gd) shows
## it. Line numbers are the original's. tests/check_ground_rules.gd
## plays the recordings in analysis/live/ground/ through this, with the
## numbers RND gave on the real machine, and compares the state.

enum Landing {
	NOTHING, ## line 172: one escort fighter and a planet that has given in. No word said.
	NO_TRANSPORTS,
	UNOPPOSED, ## tech 0
	BATTLE,
}
enum Outcome {
	FIGHTING,
	SURRENDERED, ## the screen then says 100%, whatever `success` was
	LOST,
	RETREATED,
}

const SAID_NO_BASE: Array[String] = ["NO BASE"]
const SAID_ENLIST_ELSEWHERE: Array[String] = [
	"DO YOU REALLY", "EXPECT ANYONE TO", "ENLIST!? YOU LEFT", "YOUR TROOPS ON", "ANOTHER PLANET!",
]
const SAID_ATTACK_ELSEWHERE: Array[String] = ["YOU CAN'T ATTACK!", "YOU LEFT", "YOUR TROOPS ON", "ANOTHER PLANET!"]
const SAID_NO_TRANSPORTS: Array[String] = ["THERE ARE NO TRANSPORTS AVAILABLE!"]
const SAID_SURRENDERED: Array[String] = ["THE PLANET HAS SURRENDERED!"]
const SAID_COLLECTING: Array[String] = ["TROOPS ARE NOW COLLECTING LOOT."]
const SAID_LOST: Array[String] = ["THE BATTLE IS LOST! ALL TROOPS", "HAVE BEEN DESTROYED!!!"]
const SAID_RETREATING: Array[String] = ["GROUND FORCES RETREATING, SIR!", "PLANET NOT SECURED!"]

## COLLECT 925-1050: the loot, in the order its numbers are drawn, and
## which of J1, J2 or a flat 20 each is drawn up to.
const HAUL := [
	[12, "j2"], [11, "j2"], [10, "j2"], [9, "j2"], [8, "j1"], [7, "j2"], [6, "j2"],
	[5, "j1"], [4, "j1"], [3, "j2"], [2, "flat"], [1, "j2"], [0, "j1"],
]
const HAUL_FLAT := 20.0
const SECOND_HAUL := 0.6

## A number in [0, 1), as RND(1) gives.
var rnd: Callable = randf

# The program's own variables. The counts are read when the menu comes
# up (lines 11-13), the troops from the MISC file.
var troops: float = 0.0     ## TR
var reserve: float = 0.0    ## T9: troops the transports had no room for
var fighters: float = 0.0   ## P
var transports: float = 0.0 ## TP
var tanks: float = 0.0      ## T
var missiles: float = 0.0   ## M
var enemy: float = 0.0      ## SP
var progress: float = 0.0   ## VP
var success: float = 0.0    ## PS, the PROBABILITY OF SUCCESS shown
var tech: int = 0


## Lines 11-14, the menu coming up.
## @witness GROUND FORCES 11-14
func open_menu() -> void:
	troops = GameState.troops
	missiles = GameState.gf_missiles
	fighters = GameState.gf_fighters
	transports = GameState.gf_transports
	tanks = GameState.gf_tanks
	# 14: landed, the troops are owed a shore leave; the flight
	# program takes it out of their morale at the next star
	if GameState.ship_y == 20 and GameState.morale_flag == 0:
		GameState.morale_flag = 17


## Lines 65-67: why command 1-9 is refused, or nothing.
## @witness GROUND FORCES 65-67
func refusal(command: int) -> Array[String]:
	var here := GameState.troops_stationed_at == GameState.current_planet + 1
	if command > 2 and command < 7 and not GameState.planet_has_base[GameState.current_planet]:
		return SAID_NO_BASE
	if command == 4 and not here:
		return SAID_ENLIST_ELSEWHERE
	if command == 1 and not here:
		return SAID_ATTACK_ELSEWHERE
	return []


## Lines 120-179.
## @witness GROUND FORCES 120-179
func begin_attack() -> Landing:
	if GameState.gf_planet_surrendered: # 120: a planet that gave in is taken again cheaply
		GameState.gf_enemy_strength = 25.0
	GameState.troops_stationed_at = GameState.current_planet + 1 # 150
	if GameState.flight_escort_fighters == 1 and GameState.gf_planet_surrendered: # 172
		return Landing.NOTHING
	if GameState.gf_transports == 0: # 175
		return Landing.NO_TRANSPORTS
	GameState.troop_location = 1 # 177
	var room := GameState.gf_transports * 1000.0 # 178-179
	reserve = maxf(troops - room, 0.0)
	troops = minf(troops, room)
	tech = GameState.planet_tech[GameState.current_planet]
	return Landing.UNOPPOSED if tech == 0 else Landing.BATTLE


## Lines 180-185, one message at a time.
## @witness GROUND FORCES 180-185
func departure() -> Array[String]:
	var said: Array[String] = ["ALL TRANSPORTS AWAY, SIR!"]
	if not GameState.in_atmosphere:
		said.append("TRANSPORTS ENTERING ATMOSPHERE!")
	if GameState.gf_fighters > 0:
		said.append("FIGHTERS LAUNCHING FROM TRANSPORTS!")
	return said


## Lines 200-510: what the landing force finds, a message at a time.
## A lifeless planet is secured here.
## @witness GROUND FORCES 200-510
func land() -> Array:
	var given_in := GameState.gf_planet_surrendered
	var said: Array = []
	match tech:
		0: # 220-240, 740
			said = [["PLANET IS NON HABITABLE. THERE IS NO", "ENEMY TO RESIST LANDING FORCE."]]
			_secure()
		1: # 300-305
			said = [[
				"PLANET IS VERY PRIMITIVE.", "THE LOCAL INHABITANTS ARE UNABLE TO",
				"RESIST THE LANDING FORCE!!!", "PLANET SECURE WITH MINIMUM OF FIGHTING!",
			]]
			GameState.gf_enemy_strength = 0.0
		2: # 330-340
			said = [["PLANET IS IN THE LIMITED ATOMIC STAGE", "OF DEVELOPMENT!"]]
			if not given_in:
				said.append(["ATTACK FORCE IS MEETING RESISTANCE!!"])
		3: # 400
			said = [["PLANET HAS COMPARABLE TECHNOLOGY TO US!"], ["HEAVY COUNTER ATTACK HAS BEEN LAUNCHED!"]]
		_: # 450
			said = [["PLANET HAS SUPERIOR TECHNOLOGY TO OURS!"]]
			if not given_in:
				said.append(["THE ENEMY HAS LAUNCHED A VERY HEAVY", "COUNTER ATTACK!!!"])
				said.append(["GOOD LUCK, SIR!!!"])
	missiles = GameState.gf_missiles # 500
	enemy = GameState.gf_enemy_strength # 510
	progress = GameState.gf_victory_progress
	return said


## Lines 550-670 and 1100-1130: one round of the battle. `retreat`
## is the order to pull out, which the original takes from any key and
## reads after the round's losses, before it looks at who has won.
## @witness GROUND FORCES 550-670, 1100-1130, 4000-4020
func fight(retreat: bool) -> Outcome:
	var t2: float
	var x: float
	var vic: float = rnd.call() * (10 * tech) # 550
	if vic < 20:
		t2 = 500 + rnd.call() * 20
		rnd.call() # T3
		x = rnd.call() * (12 / (tech + 0.5))
	else: # 555
		t2 = 200 * (rnd.call() * 5)
		rnd.call() # T3
		x = -(rnd.call() * (10 / (tech + 0.5)))
	tanks -= _twice(5) # 560
	fighters -= _twice(5)
	missiles -= _twice(5)
	transports = transports - rnd.call() + 0.5
	var a: float = rnd.call()
	var b: float = rnd.call()
	var c: float = rnd.call()
	troops -= a * (b * (tech * (c * t2)))
	for i in 3: # 570: ET, which nothing reads
		rnd.call()
	if GameState.orbital_defender_tier > 0: # the defender overhead holds the attack back
		x -= rnd.call()
	success = 100 / (enemy + 0.01) * progress # 572: from the progress before this round
	x += GameState.troop_morale - 3 # 575
	progress = clampf(progress + x, 0, 255) # 580-585
	fighters = maxf(fighters, 0) # 590-598
	transports = maxf(transports, 0)
	tanks = maxf(tanks, 0)
	missiles = maxf(missiles, 0)
	troops = maxf(troops, 0)
	fighters = floorf(fighters) # 600, 4000-4001
	transports = floorf(transports)
	tanks = floorf(tanks)
	missiles = floorf(missiles)
	troops = floorf(troops)
	success = minf(floorf(success), 100)
	GameState.gf_fighters = fighters
	GameState.gf_transports = transports
	GameState.gf_tanks = tanks
	GameState.gf_missiles = missiles

	if retreat: # 1120-1130
		GameState.troops = troops + reserve
		if GameState.troop_morale - 1 > -1:
			GameState.troop_morale -= 1
		return Outcome.RETREATED
	if progress >= enemy: # 660, 800: the progress itself is never kept
		GameState.gf_enemy_strength = 0.0
		_secure()
		GameState.troops = troops + reserve
		return Outcome.SURRENDERED
	if troops == 0: # 665-670
		GameState.troop_location = 0
		GameState.troops = troops + reserve
		return Outcome.LOST
	return Outcome.FIGHTING


## RECALL.bas 2000-2030.
## @witness RECALL 2000-2030
func recall() -> Array[String]:
	var place := GameState.troop_location
	if GameState.current_planet + 1 != GameState.troops_stationed_at and place > 0 and place < 3:
		return ["TROOPS ARE NOT ON", "THIS PLANET, SIR!"]
	if GameState.troops == 0:
		GameState.troop_location = 0
		return ["WE HAVE NO TROOPS", "LEFT, SIR!"]
	if place == 1 or place == 2:
		GameState.troop_location = 0
		return ["TROOPS ARE BEING", "RECALLED, SIR!"]
	if place == 3:
		return ["TROOPS ARE IN", "CRYOGENIC SLEEP!"]
	return ["TROOPS ARE ALREADY", "ON BOARD, SIR!"]


## COLLECT.bas: the loot of the planet just taken, and what is said of
## it. Two of the original's slips are fixed, as the plain rule is the
## simpler one: a primitive planet's silver is its own sum, not the gold
## just counted (870-880), and titanium is added like the rest (960 pokes
## 31180, so the original never collects any).
## @witness COLLECT 11, 15-16, 800-805, 820, 840-900, 910, 1070, 1090
func collect() -> Array:
	var said: Array = []
	match GameState.planet_tech[GameState.current_planet]:
		0: # 820
			said = [["PLANET IS NON-HABITABLE.", "THERE IS NO LOOT TO GATHER, SIR."]]
		1: # 840-900
			said = [[
				"PLANET IS PRIMITIVE. THE ONLY LOOT", "IS A LITTLE GOLD AND SILVER AND SOME",
				"WINES AND LIQUORS, SIR.",
			]]
			_add(12, 5.0)
			_add(11, 5.0)
			_add(2, 10.0)
		2: # 910
			said = [[
				"PLANET IS IN THE LIMITED ATOMIC STAGE.", "THERE ARE NO HIGH TECHNOLOGY PRODUCTS",
				"AVAILABLE, BUT THERE IS AN ABUNDANCE", "OF OTHER GOODS, SIR!",
			]]
			_haul(0.0, 10.0)
		3: # 1070
			said = [["PLANET HAS A SOPHISTICATED TECHNOLOGY.", "WE'LL GET PLENTY OF LOOT HERE, SIR."]]
			_haul(10.0, 7.0)
		_: # 1090
			said = [["PLANET HAS A SUPERIOR TECHNOLOGY.", "WE'VE HIT IT BIG THIS TIME, SIR!!!"]]
			_haul(15.0, 15.0)
	said.append(["OPERATION %s IS A" % GameState.STAR_NAMES[GameState.current_planet], "SUCCESS, SIR!"]) # 16
	return said


## Lines 740 and 660: the planet is ours.
## @witness GROUND FORCES 660, 740
func _secure() -> void:
	GameState.gf_planet_surrendered = true
	GameState.planet_secured[GameState.current_planet] = 1


## `RND (1) * ( RND (1) * n)`, drawn in that order.
func _twice(n: float) -> float:
	var a: float = rnd.call()
	var b: float = rnd.call()
	return a * (b * n)


## COLLECT 920-1050: a second haul in one visit to a star is cut.
## @witness COLLECT 915, 920-1060
func _haul(j1: float, j2: float) -> void:
	if GameState.loot_collected_this_visit:
		j1 *= SECOND_HAUL
		j2 *= SECOND_HAUL
	GameState.loot_collected_this_visit = true
	var up_to := {"j1": j1, "j2": j2, "flat": HAUL_FLAT}
	for entry in HAUL:
		_add(entry[0], up_to[entry[1]])


## A loot byte and a draw up to `most`, capped as the byte is. Returns
## the sum before it is cut to a whole number.
func _add(index: int, most: float) -> float:
	var sum: float = minf(GameState.loot[index] + rnd.call() * most, 255)
	GameState.loot[index] = floorf(sum)
	return sum
