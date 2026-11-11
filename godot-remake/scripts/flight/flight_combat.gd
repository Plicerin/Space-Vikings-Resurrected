extends RefCounted
## The fighting in STARSHIP SIMULATOR.bas: lines 185-192 of the main loop
## and the subroutines they call, 1000 (missile), 1500 (fire button),
## 3000 (the defender's fire) and 5000 (a fighter pass). This script
## holds the rules, a statement at a time; combat_fx.gd draws and times
## the effects.
##
## One pass of the main loop does, after the view is drawn:
##
##   185  if the fire button is down: GOSUB 1500
##   189  the planet's technology below 2: nothing more
##   190  planet not surrendered and ship in its atmosphere: GOSUB 3000,
##        then with 50% chance, if the planet has fighters, GOSUB 5000
##   192  planet not surrendered and ship inside the box round the
##        defender: GOSUB 3000, then with 60% chance and fighters, 5000
##
## and every effect holds the loop up for as long as it lasts. `fight()`
## is that, as a coroutine: it comes back when the pass can go on to the
## keys, or with the program the original runs instead (EX, DMG, S/X).
##
## All of the game's numbers are bytes that BASIC PEEKs and POKEs, so
## every stored result is cut down to a whole number, while a result
## still in a BASIC variable keeps its fraction. Both are kept here.
##
## Checked against the real game in tests/check_jump.tscn (a missile hit,
## a miss, the laser, the defender's hits on raised shields and on the
## ship, the defender destroyed, the surrender, the ship lost), which
## also compares both hi-res pages after each. What the original does that may
## look like a mistake in this port and is not:
##
##  - 1500: firing on a planet that has surrendered makes it hostile
##    again, with strength 100.
##  - 1535: any shot scores, hit or not for the laser, and a shot at a
##    planet whose strength is 0 (technology below 2) makes it surrender.
##  - 1010-1060: the missile is flown ahead of the ship in 16 steps and
##    hits if any step is inside the box round the defender's place,
##    whether or not a defender is there. With the nose between 64 and
##    190 (pointing down) line 1060 never reaches its NEXT and the
##    missile flies one step. In an atmosphere it "hits" when the ship's
##    height is under VV, which is the pitch gauge's marker row.
##  - 1090: a missile costs 2 points of the missile system, but not the
##    one that destroys the defender (line 1560 runs EX from inside the
##    GOSUB and never comes back).
##  - 1540: DP, the damage done to the defender, is a variable. Every RUN
##    of the flight program zeroes it, and in an atmosphere it is not
##    refreshed from the byte, so the test of line 1560 uses a stale one.
##  - 3200-3205: once the defender has hit raised shields DMG stays set,
##    and every later pass in the box wears them by a point whether or
##    not anything is seen to hit. A hit through the shields clears it.
##  - 3207: `IF L=7` skips the damage to the ship's systems. L is set to
##    7 only for a fighter's strafing run, which leaves it at 0, but it
##    starts each run of the program as the low byte of the ship's Z
##    (line 8 uses it as a scratch variable). One start in 256 the ship
##    takes no system damage until a fighter has strafed it.
##  - 3350: the ship is lost when the hull's new value is 0 before it is
##    stored, so a hull at 1 survives a hit of less than 1.
##  - 5250: shooting a fighter down costs 2 points of the missile system.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const FlightProgram = preload("res://scripts/flight/flight_program.gd")

## What the pass ran into.
enum Outcome {
	NONE, ## on to the keys
	DEFENDER_DESTROYED, ## line 1560: RUN EX
	DAMAGED, ## line 3360: RUN DMG
	SHIP_DESTROYED, ## line 3350: RUN S/X
}

## X9, Y9, Z9: where the defender is taken to be.
const DEFENDER_X := 400.0
const DEFENDER_Y := -100.0
const DEFENDER_Z := -3500.0
## S2: how far the missile flies in a step.
const MISSILE_STEP := 160.0
## HL: nothing above this is stored.
const BYTE_MAX := 255.0

var program: FlightProgram
## combat_fx.gd.
var fx: Node
## RND(1). The tests load the dice.
var rnd: Callable = func() -> float: return randf()

## DMG, DP, L and TE.
var dmg := false
var dp := 0.0
var l := 0
var te := 0


func setup(flight_program: FlightProgram, combat_fx: Node) -> void:
	program = flight_program
	fx = combat_fx
	fx.fighter_strafed.connect(_on_fighter_strafed)
	fx.fighter_shot_down.connect(_on_fighter_shot_down)


## Lines 1-9, next to flight_program.gd's start(): `run` is true for RUN
## (every variable zero) and false for line 500's GOTO 1.
func start(run: bool) -> void:
	if run:
		dmg = false
		dp = 0.0
	l = GameState.ship_z & 0xFF # 8
	te = GameState.planet_tech[GameState.current_planet]


## Lines 185-192. `button` is the paddle button as line 185 reads it.
func fight(button: bool) -> Outcome:
	var outcome := Outcome.NONE
	if button: # 185
		outcome = await _fire()
		if outcome != Outcome.NONE:
			return outcome
	if GameState.planet_tech[GameState.current_planet] < 2: # 189
		return Outcome.NONE
	if not GameState.gf_planet_surrendered and GameState.in_atmosphere: # 190
		outcome = await _defender_fire()
		if outcome != Outcome.NONE:
			return outcome
		if rnd.call() < 0.5 and GameState.flight_escort_fighters > 0:
			await _fighter_pass()
	var core := program.core
	if not GameState.gf_planet_surrendered and core.x > -3500 and core.x < 4500 \
			and core.y > -3000 and core.y < 3000 and core.z > -6000 and core.z < 2000: # 192
		outcome = await _defender_fire()
		if outcome != Outcome.NONE:
			return outcome
		if rnd.call() < 0.6 and GameState.flight_escort_fighters > 0:
			await _fighter_pass()
	return Outcome.NONE


func _finish() -> void:
	if fx.is_busy():
		await fx.idle


# -- 1500: the fire button ------------------------------------------------


func _fire() -> Outcome:
	if GameState.gf_planet_surrendered: # 1500
		GameState.gf_planet_surrendered = false
		GameState.gf_enemy_strength = 100.0
	program.view.shown = 0 # 1501
	if GameState.missile_mode_active:
		return await _missile()
	if int(GameState.ship_laser) == 0: # 1502
		return Outcome.NONE
	fx.fire_laser() # 1505-1530
	await _finish()
	return await _score(10.0, 1.0)


# -- 1000: the missile ----------------------------------------------------


func _missile() -> Outcome:
	var core := program.core
	var x0 := core.x # 1000
	var y0 := core.y
	var z0 := core.z
	var x2 := MISSILE_STEP * (core.zp * core.xh)
	var z2 := MISSILE_STEP * core.zp * core.zh
	var y2 := MISSILE_STEP * core.yp
	if int(GameState.ship_missile_system) != 0:
		var hit := false
		var steps := 0
		for m in range(124, 61, -4): # 1010
			steps += 1
			if GameState.in_atmosphere and y0 < program.vv:
				hit = true
			elif x0 < DEFENDER_X + 150 and x0 > DEFENDER_X - 150 and y0 < DEFENDER_Y + 60 \
					and y0 > DEFENDER_Y - 20 and z0 < DEFENDER_Z + 100 and z0 > DEFENDER_Z - 100: # 1050
				hit = true
			x0 += x2 # 1060
			z0 += z2
			y0 += y2
			if not (program.pitch > 190 or program.pitch < 64):
				break
			y0 -= 2 * y2
		fx.fire_missile(hit, steps)
		await _finish()
		if hit: # 1085
			var outcome := await _score(10.0, 120.0)
			if outcome != Outcome.NONE:
				return outcome
	_missile_cost() # 1090
	return Outcome.NONE


## Line 1090.
func _missile_cost() -> void:
	GameState.ship_missile_system = float(maxi(int(GameState.ship_missile_system) - 2, 0))


# -- 1535: what a shot is worth -------------------------------------------


## J1 to the planet's victory points, J2 to the defender's damage, each
## divided by the planet's technology plus one.
func _score(j1: float, j2: float) -> Outcome:
	var vp := int(GameState.gf_victory_progress) + j1 / (te + 1) # 1535
	if vp < BYTE_MAX:
		GameState.gf_victory_progress = float(int(vp))
	if not GameState.in_atmosphere: # 1540
		dp = int(GameState.defender_damage_points) + j2 / (te + 1)
		if dp < BYTE_MAX:
			GameState.defender_damage_points = float(int(dp))
	if vp >= int(GameState.gf_enemy_strength): # 1550
		var text := program.text
		text.page = 0
		program.view.shown = 0
		text.vtab(13)
		text.htab(8)
		fx.type_text("THE PLANET HAS SURRENDERED", text.put, fx.TEXT_FRAMES)
		await _finish()
		GameState.planet_secured[GameState.current_planet] = 1
		GameState.gf_planet_surrendered = true
	if dp > int(GameState.defender_damage_threshold) and GameState.orbital_defender_tier != 0: # 1560
		return Outcome.DEFENDER_DESTROYED
	return Outcome.NONE


# -- 3000: the defender fires ---------------------------------------------


func _defender_fire() -> Outcome:
	if GameState.orbital_defender_tier == 0 and not GameState.in_atmosphere: # 3000
		return Outcome.NONE
	program.view.shown = 0 # 3001
	var light := 0
	var medium := false
	if rnd.call() <= 0.4 and rnd.call() <= 0.4: # 3001, 3010
		light = maxi(int(rnd.call() * 5.0), 1) # 3019: a FOR loop runs at least once
		dmg = true
	if rnd.call() <= 0.3: # 3030
		medium = true # 3032
		dmg = true
	if light > 0 or medium:
		fx.damage(light, medium)
		await _finish()
	if not dmg: # 3200
		return Outcome.NONE
	return _wear()


## Lines 3205-3360.
func _wear() -> Outcome:
	if _shield_holds(): # 3205
		return Outcome.NONE
	if l == 7: # 3207
		return Outcome.NONE
	GameState.ship_radar = _worn(GameState.ship_radar, 5.0) # 3230
	GameState.ship_engine1 = _worn(GameState.ship_engine1, 5.0) # 3260
	GameState.ship_engine2 = _worn(GameState.ship_engine2, 5.0) # 3270
	GameState.ship_computer = _worn(GameState.ship_computer, 5.0)
	GameState.ship_laser = _worn(GameState.ship_laser, 5.0)
	var hull := maxf(int(GameState.ship_hull) - rnd.call() * 4.0, 0.0)
	GameState.ship_hull = float(int(hull)) # 3350
	dmg = false
	if hull == 0.0:
		return Outcome.SHIP_DESTROYED
	if not GameState.damage_alert_active: # 3360
		GameState.damage_alert_active = true
		return Outcome.DAMAGED
	return Outcome.NONE


## Line 3205: the shield strength wears, and holds while it is above 10
## and the shields are up.
func _shield_holds() -> bool:
	GameState.ship_shield = _worn(GameState.ship_shield, 1.1)
	return int(GameState.ship_shield) > 10 and GameState.shields_up


## `J = PEEK(a) - (RND(1) * most): GOSUB 3380: POKE a,J`
func _worn(value: float, most: float) -> float:
	return float(int(maxf(int(value) - rnd.call() * most, 0.0)))


# -- 5000: a fighter pass -------------------------------------------------


func _fighter_pass() -> void:
	program.view.shown = 0 # 5000
	fx.fighter_pass(GameState.condition == 3) # 5200: the turrets answer at condition RED
	await _finish()


## Line 5098: `L=7: GOSUB 3205: L=0`. Only the shield wears.
func _on_fighter_strafed() -> void:
	_shield_holds()
	l = 0


## Lines 5250-5251.
func _on_fighter_shot_down() -> void:
	var left := GameState.flight_escort_fighters - 1
	if left > -1:
		GameState.flight_escort_fighters = left
	_missile_cost()
