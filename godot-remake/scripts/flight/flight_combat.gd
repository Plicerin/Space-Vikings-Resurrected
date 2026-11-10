extends Node2D
## Flight combat: the part of STARSHIP SIMULATOR.bas's main loop that
## fires the ship's weapon (line 185, GOSUB 1500) and lets the planet's
## defender and fighters attack (lines 189-192, GOSUB 3000 and 5000).
## This script holds the rules; combat_fx.gd draws and times the effects
## and reports back through signals. Lives under space_flight.tscn's HUD.
##
## The original is one BASIC loop that does everything in turn, so a
## turn of the loop ("iteration") is the unit of time here as well:
##
##   quiet part (flight renderer, panel)        about 130 frames, measured
##   185  if the fire button is down: GOSUB 1500
##   189  tech below 2: nothing more
##   192  planet not surrendered and ship inside the combat box:
##          GOSUB 3000 (the defender's fire), then with 60% chance, if
##          the planet has fighters left, GOSUB 5000 (one fighter pass)
##
## and every effect holds the loop up for as long as it lasts. `_queue`
## is the rest of the current iteration. One liberty: the original only
## looks at the button once per iteration, so a tap between two looks is
## lost and a held button fires up to two seconds late. Here a press
## during the quiet part cuts the quiet part short: the iteration's
## line 185 runs at once, and the enemy's turn follows the shot as it
## always does, so shots and enemy turns stay one for one.
##
## Rules ported line for line. All of these bytes are POKEd, so every
## stored result is cut down to a whole number, and that matters:
##
##  - 1500: firing at a surrendered planet makes it hostile again with
##    strength 100.
##  - 1535-1560: a laser volley adds 10/(tech+1) to the planet's victory
##    points and 1/(tech+1) to the defender's damage; a missile hit adds
##    10/(tech+1) and 120/(tech+1). Because of the truncation the laser
##    never damages a defender of tech 1 or more (watched live: three
##    volleys at tech 3 took victory points 1 -> 3 -> 5 -> 7 and left the
##    damage byte at 0). The surrender and destruction tests use the
##    untruncated sums.
##  - 1090: a missile costs 2 points of the missile system, but not when
##    it destroys the defender (line 1560 runs EX from inside the GOSUB
##    and never comes back).
##  - 3000-3032: no defender in orbit, no defender fire. Otherwise a 16%
##    chance (two rolls of 40%) of one to four light flashes and a
##    separate 30% chance of a heavier one; either sets DMG.
##  - 3200-3360: with DMG set the shield strength drops by up to 1.1.
##    With the shields up (GameState.shields_up, key S) and the strength
##    above 10 that is all. Otherwise radar, both engines, computer and
##    laser lose up to 5 each and the hull up to 4, and DMG is cleared.
##    DMG is cleared nowhere else, so once a hit has been absorbed by
##    raised shields every later iteration in the box wears them down by
##    one more point whether or not anything is seen to hit (watched
##    live: 14 iterations in a row, one point each). A new game starts
##    with the shields down.
##  - 5098: a fighter's strafing hit wears only the shield strength.
##  - 5200-5251: the turrets answer a strafing fighter only at condition
##    RED (GameState.condition, key B); a kill costs the planet one
##    fighter and the ship 2 points of the missile system.
##  - EX.bas: the destroyed defender takes half the fighters with it.
##
## Still approximate, waiting on the flight model's own port: the combat
## box (line 192) is a distance to the planet here, the missile's hit
## test (line 1050) is a forward cone, and there is no atmosphere state
## (line 190, $38210).

const CombatFx = preload("res://scripts/combat/combat_fx.gd")

const PLANET_WORLD_POSITION := Vector3(0, 0, -3000) # must match space_flight.tscn's Planet node
const COMBAT_RANGE := 4000.0 # stands in for line 192's box
## The quiet part of one loop iteration, in 1/60 s (109-152 measured).
const ITERATION_FRAMES := 130.0
const FIGHTER_PASS_CHANCE := 0.6 # line 192

# Manual page 13: "An enemy ship must be within half the range covered
# by your forward radar scan or your missiles will self-destruct".
const MISSILE_RANGE := COMBAT_RANGE * 0.5
const MISSILE_AIM_TOLERANCE_DEG := 8.0

signal player_destroyed

# Set by space_flight.gd: the missile's stand-in hit test needs the
# ship's heading and the defender's position.
@export var ship_node: Node3D
@export var ship_blip_target: Node3D

@onready var _fx: CombatFx = $CombatFx

var _queue: Array[Callable] = []
var _quiet := ITERATION_FRAMES / 60.0
## BASIC's DMG variable (see above).
var _dmg_pending := false
var _dead := false


func _ready() -> void:
	_fx.idle.connect(_advance)
	_fx.laser_finished.connect(func() -> void: _score_shot(10.0, 1.0))
	_fx.missile_finished.connect(_on_missile_finished)
	_fx.damage_finished.connect(_apply_damage)
	_fx.fighter_strafed.connect(_wear_shield)
	_fx.fighter_shot_down.connect(_on_fighter_shot_down)
	_fx.message_finished.connect(_on_surrender_printed)
	_fx.destruction_finished.connect(_on_defender_destroyed)


func _process(delta: float) -> void:
	if _dead or _fx.is_busy() or not _queue.is_empty():
		return
	_quiet -= delta
	if _quiet <= 0.0:
		_iteration(Input.is_action_pressed("fire_laser"))


## One pass through lines 150-192.
func _iteration(fire: bool) -> void:
	_fx.clear_window()
	if fire:
		_queue.append(_fire)
	_queue.append(_defender_fire)
	_queue.append(_fighter_attack)
	_advance()


## The fire button was pressed (see the liberty above).
func fire_weapon() -> void:
	if _dead or _fx.is_busy() or not _queue.is_empty():
		return
	_iteration(true)


func _advance() -> void:
	while not _queue.is_empty() and not _fx.is_busy() and not _dead:
		var next: Callable = _queue.pop_front()
		next.call()
	if _queue.is_empty() and not _fx.is_busy():
		_quiet = ITERATION_FRAMES / 60.0


static func _whole(value: float) -> float:
	return maxf(floorf(value), 0.0)


func _tech() -> int:
	return GameState.planet_tech[GameState.current_planet]


# --- The ship's weapon (lines 1500-1570, 1000-1090) ---

func _fire() -> void:
	# 1500
	if GameState.gf_planet_surrendered:
		GameState.gf_planet_surrendered = false
		GameState.gf_enemy_strength = 100.0
	if GameState.missile_mode_active:
		if GameState.ship_missile_system >= 1.0:
			_fx.fire_missile(_is_missile_hit())
	elif GameState.ship_laser >= 1.0:
		_fx.fire_laser()


func _on_missile_finished(hit: bool) -> void:
	if hit and _score_shot(10.0, 120.0):
		return
	GameState.ship_missile_system = _whole(GameState.ship_missile_system - 2.0)


## Lines 1535-1560 with J1 and J2. Returns true if the defender is
## destroyed by it.
func _score_shot(victory: float, damage: float) -> bool:
	var share := _tech() + 1.0
	var vp := floorf(GameState.gf_victory_progress) + victory / share
	if vp < 255.0:
		GameState.gf_victory_progress = floorf(vp)
	var dp := floorf(GameState.defender_damage_points) + damage / share
	if dp < 255.0:
		GameState.defender_damage_points = floorf(dp)
	var follow: Array[Callable] = []
	if vp >= GameState.gf_enemy_strength:
		follow.append(func() -> void: _fx.print_message("THE PLANET HAS SURRENDERED", 8, 13))
	var destroyed := dp > GameState.defender_damage_threshold and GameState.orbital_defender_tier != 0
	if destroyed:
		follow.append(func() -> void: _fx.destroy_defender())
	_queue = follow + _queue
	return destroyed


func _on_surrender_printed() -> void:
	GameState.planet_secured[GameState.current_planet] = true
	GameState.gf_planet_surrendered = true


## EX.bas lines 30-60. It ends in RUN STARSHIP SIMULATOR, which starts
## the flight program afresh: the rest of the iteration is dropped and
## BASIC's variables (DMG among them) are cleared.
func _on_defender_destroyed() -> void:
	GameState.orbital_defender_tier = 0
	GameState.flight_escort_fighters = int(GameState.flight_escort_fighters / 2.0)
	_queue.clear()
	_dmg_pending = false


## Stand-in for line 1050's box test: the defender must be within
## missile range and within a few degrees of dead ahead.
func _is_missile_hit() -> bool:
	if ship_node == null or ship_blip_target == null:
		return false
	if GameState.orbital_defender_tier == 0:
		return false
	var to_target := ship_blip_target.global_position - ship_node.global_position
	var distance := to_target.length()
	if distance < 0.01 or distance > MISSILE_RANGE:
		return false
	var forward := -ship_node.global_transform.basis.z
	return rad_to_deg(forward.angle_to(to_target / distance)) <= MISSILE_AIM_TOLERANCE_DEG


# --- The enemy (lines 189-192, 3000-3381, 5000-5251) ---

func _is_combat_eligible() -> bool:
	if _tech() < 2 or GameState.gf_planet_surrendered:
		return false
	return GameState.ship_position.distance_to(PLANET_WORLD_POSITION) <= COMBAT_RANGE


## GOSUB 3000.
func _defender_fire() -> void:
	if not _is_combat_eligible() or GameState.orbital_defender_tier == 0:
		return
	var light_flashes := 0
	if randf() <= 0.4 and randf() <= 0.4:
		# FOR LY=1 TO RND(1)*5: a FOR loop always runs once.
		light_flashes = maxi(int(randf() * 5.0), 1)
	var medium := randf() <= 0.3
	if light_flashes == 0 and not medium:
		_apply_damage()
		return
	_dmg_pending = true
	_fx.damage(light_flashes, medium)


## Lines 3200-3360.
func _apply_damage() -> void:
	if not _dmg_pending:
		return
	_wear_shield()
	if GameState.ship_shield > 10.0 and GameState.shields_up:
		return
	GameState.ship_radar = _whole(GameState.ship_radar - randf() * 5.0)
	GameState.ship_engine1 = _whole(GameState.ship_engine1 - randf() * 5.0)
	GameState.ship_engine2 = _whole(GameState.ship_engine2 - randf() * 5.0)
	GameState.ship_computer = _whole(GameState.ship_computer - randf() * 5.0)
	GameState.ship_laser = _whole(GameState.ship_laser - randf() * 5.0)
	var hull := floorf(GameState.ship_hull) - randf() * 4.0
	GameState.ship_hull = _whole(hull)
	_dmg_pending = false
	if hull <= 0.0:
		# RUN S/X
		_dead = true
		_queue.clear()
		player_destroyed.emit()
		return
	# RUN DMG lights the DAMAGE lamp.
	GameState.damage_alert_active = true


## Line 3205's first statement, also all a strafing fighter does (5098).
func _wear_shield() -> void:
	GameState.ship_shield = _whole(floorf(GameState.ship_shield) - randf() * 1.1)


## Line 192's second half.
func _fighter_attack() -> void:
	if not _is_combat_eligible():
		return
	if randf() < FIGHTER_PASS_CHANCE and GameState.flight_escort_fighters > 0:
		_fx.fighter_pass(GameState.condition == 3)


## Lines 5250-5251 and 1090.
func _on_fighter_shot_down() -> void:
	GameState.flight_escort_fighters = maxi(GameState.flight_escort_fighters - 1, 0)
	GameState.ship_missile_system = _whole(GameState.ship_missile_system - 2.0)
