extends RefCounted
## The rules of fighting in STARSHIP SIMULATOR.bas: the fire button (lines
## 185 and 1500), the missile (1000), what a shot scores (1535), the
## defender's fire (3000) and a fighter's pass (5000). What happens, in
## what order the dice are thrown, and what is left in the game's bytes;
## not how it looks (scripts/flight/native_flight.gd plays the events it
## returns). tests/check_combat_rules.gd holds it to the real game: every
## pass of the recordings in analysis/live/combat/, with the numbers RND
## gave, from the state at the start of the pass to the state at the start
## of the next.
##
## One pass of the main loop does, after the view is drawn (lines 185-192):
##
##   185  the fire button down: GOSUB 1500
##   189  the planet's technology below 2: nothing more
##   190  planet not surrendered and ship in its atmosphere: the defender
##        fires (3000), then 50% of the time, if the planet has fighters,
##        a fighter passes (5000)
##   192  planet not surrendered and ship inside the box round the
##        defender: the same, and 60%
##
## All the game's numbers are bytes that BASIC PEEKs and POKEs, so every
## stored result is cut down to a whole number while a result still in a
## BASIC variable keeps its fraction. Both are kept here. What the
## original does that may look like a mistake here and is not:
##
##  - 1500: firing on a planet that has surrendered makes it hostile
##    again, with strength 100.
##  - 1535: any shot scores, a hit or not for the laser, and a shot at a
##    planet whose strength is 0 (technology below 2) makes it surrender.
##  - 1010-1060: the missile is flown ahead of the ship in 16 steps and
##    hits if any step is inside the box round the defender's place,
##    whether or not a defender is there. In an atmosphere it "hits"
##    when the ship's height is under VV, the row of the pitch gauge's
##    marker.
##  - 1090: a missile costs 2 points of the missile system, but not the
##    one that destroys the defender.
##  - 1540: DP, the damage done to the defender, is a variable that every
##    RUN of the flight program zeroes, and in an atmosphere it is not
##    refreshed from the byte, so the test of line 1560 uses a stale one.
##  - 3200-3205: once the defender has hit raised shields DMG stays set,
##    and every later pass in the box wears them by a point whether or not
##    anything is seen to hit. A hit through the shields clears it.
##  - 3207: `IF L=7` skips the damage to the ship's systems. L is set to 7
##    only for a fighter's strafing run, which leaves it at 0, but it
##    starts each run of the program as the low byte of the ship's Z
##    (line 8 uses it as a scratch variable).
##  - 3350: the ship is lost when the hull's new value is 0 before it is
##    stored, so a hull at 1 survives a hit of less than 1.
##  - 5250: shooting a fighter down costs 2 points of the missile system.
##
## What is not kept is the pitch gauge's part in a missile's height, which
## is a drawing's row: VV is given by the caller.

## What the pass ran into.
enum Outcome {
	NONE, ## on to the keys
	DEFENDER_DESTROYED, ## line 1560: RUN EX
	DAMAGED, ## line 3360: RUN DMG
	SHIP_DESTROYED, ## line 3350: RUN S/X
}

## X9, Y9, Z9: where the defender is taken to be.
const DEFENDER := Vector3(400.0, -100.0, -3500.0)
## The box round it a missile hits in (lines 1050): half widths, above and below.
const BOX_X := 150.0
const BOX_Y_ABOVE := 60.0
const BOX_Y_BELOW := 20.0
const BOX_Z := 100.0
## Line 192: the box the ship has to be in for the defender to fire.
const FIRING_X := Vector2(-3500.0, 4500.0)
const FIRING_Y := Vector2(-3000.0, 3000.0)
const FIRING_Z := Vector2(-6000.0, 2000.0)
## S2: how far the missile flies in a step, and how many steps.
const MISSILE_STEP := 160.0
const MISSILE_STEPS := 16
## HL: nothing above this is stored.
const BYTE_MAX := 255.0

## RND(1). The tests load the dice.
var rnd: Callable = func() -> float: return randf()

## DMG, DP, L and TE of the flight program.
var dmg := false
var dp := 0.0
var l := 0
var te := 0


## @witness STARSHIP SIMULATOR 8-9, 182
## Lines 1-9, next to the start of the flight program: `fresh` is true for
## RUN (every variable zero) and false for line 500's GOTO 1.
func start(fresh: bool) -> void:
	if fresh:
		dmg = false
		dp = 0.0
	l = GameState.ship_z & 0xFF # 8
	te = GameState.planet_tech[GameState.current_planet]


## @witness EX 30-56
## RUN EX, after the defender is destroyed: it is gone (its type is 0) and
## half of the planet's fighters with it. The flight program then starts
## again, as `start(true)`.
func defender_destroyed() -> void:
	GameState.orbital_defender_tier = 0 # 30  POKE 38205,0
	GameState.flight_escort_fighters = int(GameState.flight_escort_fighters / 2.0) # 56


## @witness STARSHIP SIMULATOR 185-192
## One pass's fighting. `button` is the fire button as line 185 reads it,
## `eye` the ship's place, `attitude` its (pitch, heading) in units of
## 1/256 of a circle, `vv` the pitch gauge's marker row. Returns
## {"outcome": Outcome, "events": [...]}: what the pass ran into, and what
## happened, in order, for the screen to play: "hostile_again", "laser",
## "missile" (hit, steps, cost), "surrendered", "defender_hit",
## "damage" (light flashes, medium), "fighter" (the path, strafes, whether
## it was shot down).
func fight(button: bool, eye: Vector3, attitude: Vector2, vv: float, factors: Array = []) -> Dictionary:
	var events: Array = []
	var outcome := Outcome.NONE
	if button: # 185
		outcome = _fire(events, eye, attitude, vv, factors)
		if outcome != Outcome.NONE:
			return {"outcome": outcome, "events": events}
	if GameState.planet_tech[GameState.current_planet] < 2: # 189
		return {"outcome": outcome, "events": events}
	if not GameState.gf_planet_surrendered and GameState.in_atmosphere: # 190
		outcome = _defender_fire(events)
		if outcome != Outcome.NONE:
			return {"outcome": outcome, "events": events}
		if rnd.call() < 0.5 and GameState.flight_escort_fighters > 0:
			_fighter_pass(events)
	if not GameState.gf_planet_surrendered and _in_firing_box(eye): # 192
		outcome = _defender_fire(events)
		if outcome != Outcome.NONE:
			return {"outcome": outcome, "events": events}
		if rnd.call() < 0.6 and GameState.flight_escort_fighters > 0:
			_fighter_pass(events)
	return {"outcome": Outcome.NONE, "events": events}


func _in_firing_box(eye: Vector3) -> bool:
	return eye.x > FIRING_X.x and eye.x < FIRING_X.y and eye.y > FIRING_Y.x and eye.y < FIRING_Y.y \
			and eye.z > FIRING_Z.x and eye.z < FIRING_Z.y


# -- 1500: the fire button --------------------------------------------------


## @witness STARSHIP SIMULATOR 1500-1502, 1505
## @witness-asm 37585
## (CALL LA at 37585 is the laser's chirp: the audio manager's laser.)
func _fire(events: Array, eye: Vector3, attitude: Vector2, vv: float, factors: Array) -> Outcome:
	if GameState.gf_planet_surrendered: # 1500
		GameState.gf_planet_surrendered = false
		GameState.gf_enemy_strength = 100.0
		events.append({"kind": "hostile_again"})
	if GameState.missile_mode_active: # 1501
		return _missile(events, eye, attitude, vv, factors)
	if int(GameState.ship_laser) == 0: # 1502
		return Outcome.NONE
	events.append({"kind": "laser"}) # 1505-1530
	return _score(events, 10.0, 1.0)


# -- 1000: the missile ------------------------------------------------------


## @witness STARSHIP SIMULATOR 1000, 1010, 1050, 1060, 1085, 1100
## @witness-asm 37494
## (CALL SG at 37494 is the noise of a hit or a miss: the audio manager's.)
func _missile(events: Array, eye: Vector3, attitude: Vector2, vv: float, factors: Array) -> Outcome:
	# the step: BASIC's four factors if it is given them (zp, zh, xh, yp), or
	# the model's: ahead along the heading, climbing or diving by the pitch
	var step := Vector3.ZERO
	if factors.size() == 4:
		step = Vector3(MISSILE_STEP * (factors[0] * factors[2]), -MISSILE_STEP * factors[3], MISSILE_STEP * factors[0] * factors[1])
	else:
		var p := attitude.x * TAU / 256.0
		var h := attitude.y * TAU / 256.0
		step = Vector3(cos(p) * sin(h), -sin(p), cos(p) * cos(h)) * MISSILE_STEP
	if int(GameState.ship_missile_system) != 0:
		var at := eye
		var hit := false
		var struck_defender := false ## the first thing it met was the defender, not the ground
		var steps := 0
		for i in MISSILE_STEPS: # 1010
			steps += 1
			if GameState.in_atmosphere and at.y < vv:
				hit = true
			elif absf(at.x - DEFENDER.x) < BOX_X and at.y < DEFENDER.y + BOX_Y_ABOVE and at.y > DEFENDER.y - BOX_Y_BELOW \
					and absf(at.z - DEFENDER.z) < BOX_Z: # 1050
				struck_defender = not hit
				hit = true
			at += step # 1060
		events.append({"kind": "missile", "hit": hit, "steps": steps, "defender": struck_defender})
		if hit: # 1085
			var outcome := _score(events, 10.0, 120.0)
			if outcome != Outcome.NONE:
				return outcome
	_missile_cost() # 1090
	return Outcome.NONE


## @witness STARSHIP SIMULATOR 1090, 3380
## Line 1090.
func _missile_cost() -> void:
	GameState.ship_missile_system = float(maxi(int(GameState.ship_missile_system) - 2, 0))


# -- 1535: what a shot is worth ---------------------------------------------


## @witness STARSHIP SIMULATOR 1535, 1540, 1550, 1560
## J1 to the planet's victory points, J2 to the defender's damage, each
## divided by the planet's technology plus one.
func _score(events: Array, j1: float, j2: float) -> Outcome:
	var vp := int(GameState.gf_victory_progress) + j1 / (te + 1) # 1535
	if vp < BYTE_MAX:
		GameState.gf_victory_progress = float(int(vp))
	if not GameState.in_atmosphere: # 1540
		dp = int(GameState.defender_damage_points) + j2 / (te + 1)
		if dp < BYTE_MAX:
			GameState.defender_damage_points = float(int(dp))
	if vp >= int(GameState.gf_enemy_strength): # 1550
		events.append({"kind": "surrendered"})
		GameState.planet_secured[GameState.current_planet] = 1
		GameState.gf_planet_surrendered = true
	if dp > int(GameState.defender_damage_threshold) and GameState.orbital_defender_tier != 0: # 1560
		return Outcome.DEFENDER_DESTROYED
	return Outcome.NONE


# -- 3000: the defender fires -----------------------------------------------


## @witness STARSHIP SIMULATOR 3000-3001, 3010, 3019, 3030, 3032, 3200
## (3019, 3032 and 5098's CALL SG are the audio manager's hits, 37494.)
func _defender_fire(events: Array) -> Outcome:
	if GameState.orbital_defender_tier == 0 and not GameState.in_atmosphere: # 3000
		return Outcome.NONE
	var light := 0
	var medium := false
	if rnd.call() <= 0.4 and rnd.call() <= 0.4: # 3001, 3010
		light = maxi(int(rnd.call() * 5.0), 1) # 3019: a FOR loop runs at least once
		for i in light:
			rnd.call() # the pause between flashes: X1 = RND(1) * 40 + 10
		dmg = true
	if rnd.call() <= 0.3: # 3030
		medium = true # 3032
		dmg = true
	if light > 0 or medium:
		events.append({"kind": "damage", "light": light, "medium": medium})
	if not dmg: # 3200
		return Outcome.NONE
	return _wear()


## @witness STARSHIP SIMULATOR 3205, 3207, 3230, 3260, 3270, 3350, 3360, 3380
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


# -- 5000: a fighter pass ---------------------------------------------------


## @witness STARSHIP SIMULATOR 5000, 5045, 5050, 5060, 5080, 5090, 5095, 5098, 5200, 5210, 5230, 5240, 5250
## The pass: where the fighter comes in, which way it goes, and at each step
## whether it strafes (the shield wears; at condition RED the turrets
## answer and may shoot it down, which ends the pass and costs a missile's
## worth of the missile system).
func _fighter_pass(events: Array) -> void:
	var at := Vector2(rnd.call() * 260.0 + 10.0, 0.0) # 5000
	var step := Vector2.ZERO
	if rnd.call() >= 0.4:
		at.y = 10.0
		step.y = rnd.call() * 7.0
	else:
		at.y = 120.0 # 5045
		step.y = -rnd.call() * 7.0
	if at.x > 190.0: # 5050
		step.x = -7.0
	elif at.x < 91.0:
		step.x = 7.0
	else:
		step.x = -2.0
		if absf(step.y) < 4.0:
			step.y *= 2.0
	var from := at
	var turrets := GameState.condition == 3 # 5200
	var strafes: Array = []
	var shot_down := false
	var steps := 0
	while true:
		if rnd.call() < 0.3: # 5090
			l = 7 # 5098
			_shield_holds()
			l = 0
			var turret_x := 0.0
			if turrets: # 5200-5240
				turret_x = 40.0 if rnd.call() < 0.6 else 240.0
				if rnd.call() < 0.3:
					strafes.append({"step": steps, "turret": turret_x, "shot_down": true})
					shot_down = true
					var left := GameState.flight_escort_fighters - 1 # 5250
					if left > -1:
						GameState.flight_escort_fighters = left
					_missile_cost()
					break
			strafes.append({"step": steps, "turret": turret_x, "shot_down": false})
		at += step # 5095
		steps += 1
		if at.y < 10.0 or at.y > 120.0 or at.x < 10.0 or at.x > 270.0:
			break
	events.append({"kind": "fighter", "from": from, "step": step, "steps": steps, "strafes": strafes,
			"shot_down": shot_down})
