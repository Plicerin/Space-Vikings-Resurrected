extends RefCounted
## The rules of the hyperdrive, H_D.bas: when the ship will not go, what a
## jump costs, and what has changed when it comes out at the other star.
## No screen in it (scripts/flight/native_flight.gd shows the jump).
## tests/check_hyperdrive_rules.gd holds it to the original's own
## statements (scripts/flight/flight_program.gd's jump_*, themselves held
## to a live run in check_jump), jump after jump.
##
## What the original does that may look like a mistake and is kept:
##  - the distance, and so the energy it costs, is worked from the stars'
##    chart X alone, three times over (X1, Y1 and Z1 are all read from the X
##    table), not the distance the chart gives;
##  - the star date moves on by the distance and 0.3;
##  - troops that fought and were not paid off lose a point of morale;
##  - the ship comes out somewhere at random and at least 7000 from the
##    planet on z; the defender's strength, the planet's and the
##    "trip" flags (enlist, base) are set afresh.

## @witness H_D 1
## No jump from inside an atmosphere, to the star the ship is at, or with no
## course set.
static func refused() -> bool:
	return GameState.in_atmosphere or GameState.target_planet == GameState.current_planet \
		or GameState.target_planet < 0


## @witness H_D 2-4
## With no energy at all the ship is lost instead.
static func has_energy() -> bool:
	return int(GameState.ship_energy) != 0


## @witness H_D 10000-10020
## Light-years to the course's star, which is also the energy the jump costs.
static func distance() -> int:
	var d: int = absi(GameState.PLANET_X[GameState.current_planet]) \
		- absi(GameState.PLANET_X[GameState.target_planet])
	return int(sqrt(3.0 * d * d) + 0.6)


## @witness H_D 5-26, 30-76, 90-105
## The jump itself: what changes in the game. `rnd` is RND(1). Returns the
## distance it cost.
static func jump(rnd: Callable) -> int:
	var cost := distance()
	GameState.loot_collected_this_visit = false # 5  POKE 301,0
	GameState.stardate += cost + 0.3 # 6
	if GameState.troop_location == 0 or GameState.troop_location == 3: # 11
		GameState.troops_stationed_at = GameState.target_planet + 1
	GameState.store_planet_record(GameState.current_planet) # 12
	if GameState.morale_flag == 17: # 12-13: troops that fought and were not paid off
		GameState.troop_morale = maxi(GameState.troop_morale - 1, 0)
		GameState.morale_flag = 0
	GameState.ship_energy = maxf(int(GameState.ship_energy) - cost, 0.0) # 14-15
	GameState.defender_damage_points = 0.0 # 16
	GameState.planet_scouted[GameState.target_planet] = true
	GameState.load_planet_record(GameState.target_planet) # 25
	GameState.current_planet = GameState.target_planet # 26
	GameState.ship_x = floori(10000.0 - rnd.call() * 20000.0) # 50
	GameState.ship_y = floori(5000.0 - rnd.call() * 10000.0) # 60
	var z := 0
	while absi(z) < 7000: # 70: never close in
		z = floori(10000.0 - rnd.call() * 20000.0)
	GameState.ship_z = z
	GameState.ship_pitch = 0 # 73-75
	GameState.ship_heading = int(rnd.call() * 255.0)
	GameState.ship_bank = 0
	var tech: int = GameState.planet_tech[GameState.current_planet] # 90
	if tech < 2:
		GameState.gf_enemy_strength = 0.0
	else: # 93
		GameState.gf_enemy_strength = tech * 60.0
		GameState.defender_damage_threshold = tech * 60.0
		GameState.gf_victory_progress = 0.0
	GameState.enlisted_this_trip = false # 105
	GameState.base_built_this_trip = false
	return cost
