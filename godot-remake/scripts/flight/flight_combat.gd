extends Node2D
## Wires the ambient incoming-fire damage tick and laser-fire combat
## into actual flight -- STARSHIP SIMULATOR.bas lines 189-192/
## 3000-3381 (ambient), 185/1500-1570 (laser fire), and 5000-5251 (the
## incoming-fire visual + its own shootdown sub-mechanic). Lives under
## space_flight.tscn's HUD layer.
##
## CORRECTION (2026-11-09): an earlier version of this comment, and the
## README's own "Combat integration" section, concluded from live MAME
## testing that no ship ever renders during flight. That conclusion was
## wrong, and wrong for an identifiable reason: every test happened at
## SOL (current_planet=0) on a fresh game, where gf_planet_surrendered
## is genuinely TRUE from the start (SOL is the home base -- see
## GameState.gf_planet_surrendered's own doc comment) -- and the combat
## gate below requires it FALSE. Re-tested live with that flag forced
## false: the real incoming-fire enemy sprite (GOSUB 5000) genuinely
## does appear and is interactable (fires back, can be damaged) during
## normal flight once a planet is actually hostile. This port's own
## matching visual, incoming_fire.gd, already existed and already
## looked right -- it just needed the real gating condition, which this
## version adds.
##
## Full gate, ported directly this time (lines 189/190/192, plus GOSUB
## 3000's own internal re-check at line 3000): current planet's tech
## >= 2, NOT surrendered, AND within range of an actual orbital
## defender (orbital_defender_tier != 0 AND within COMBAT_RANGE of the
## planet -- a liberty standing in for the original's landed-OR-
## bounding-box test, since this port's flight scene has no "landed"
## sub-state and doesn't track position in the original's exact
## units).
##
## Ambient damage (GOSUB 3000) is a literal port of its formula: two
## independent 40%-chance rolls can set a hit flag, plus an independent
## 30%-chance roll; any hit drains SHIELD a little first, and only
## cascades to RADAR/engines/COMPUTER/LASER/HULL if the shield is
## empty (<=10 -- $38201, "shields up", is never toggled anywhere in
## the available BASIC source, so this port treats it as permanently
## true rather than modeling a switch that doesn't exist). HULL
## reaching 0 triggers S_X.bas (player_destroyed.tscn).
##
## The incoming-fire visual (GOSUB 5000) now spawns on its own real
## independent roll (60%, the bounding-box variant -- this port doesn't
## model the landed-specific 50% variant, same "no landed sub-state"
## reasoning as above), gated on GameState.flight_escort_fighters > 0
## -- a real register this port didn't track until now (confirmed live,
## starts at 30, never written anywhere in BASIC -- see that field's
## own doc comment). Its internal shootdown sub-mechanic (lines
## 5200-5251, incoming_fire.gd's tracer_fired signal) rolls a 30%
## chance per tracer to intercept the raider, decrementing
## flight_escort_fighters by 1 and ship_missile_system by 2 --
## simplified from the source, which additionally gates this on an
## unresolved status register ($38165) this port treats as
## always-eligible instead, the same "no confident analog" reasoning
## $38202 below gets.
##
## Laser fire is a literal port of GOSUB 1500/1535-1560: firing while
## already-surrendered re-arms resistance (line 1500's own quirk,
## _rearm_if_surrendered()); gated on LASER health > 0, always adds to
## gf_victory_progress (ground-invasion softening, shared with
## GROUND FORCES.bas -- see that field's doc comment) and to
## defender_damage_points (toward destroying the current orbital
## defender, EX.bas/ship_destruction.gd), neither gated on actually
## being near anything -- the original checks the fire button every
## main-loop pass regardless of position. EX.bas also halves
## flight_escort_fighters (line 56) -- ported in
## _check_defender_destroyed().
##
## Still NOT ported, documented rather than silently dropped: the
## two-fighter approach minigame's real trigger ($38202, GOSUB 1500
## line 1501). That register is never written anywhere in the
## available BASIC source, so unlike $38205/$38207 (both confirmed
## real and load-bearing by live testing) there's still no confident
## analog trigger point to port it to; fighter_encounter.gd remains
## reachable only from the dev-tool combat demo.
##
## Bigger finding from the same investigation, NOT addressed here:
## RE.bas ("re-entry") doesn't show a static terrain display at all --
## it resets position/loads the real per-world terrain then hands
## control straight back into this SAME live STARSHIP SIMULATOR.bas
## loop, with $38210=1 (atmosphere). This port's planet_approach.tscn
## (a timed 3-second display) doesn't match that shape -- the real
## re-entry is live, interactive, combat-active flight over real
## terrain. Reproducing that properly means either merging re-entry
## into this same flight scene with a terrain-swap, or giving the
## flight scene its own "atmosphere" sub-state; either is a real
## redesign, not a quick fix, so it's deliberately left for its own
## pass rather than attempted inside this one.

const ShipDestructionScript = preload("res://scripts/combat/ship_destruction.gd")
const IncomingFireScript = preload("res://scripts/combat/incoming_fire.gd")
const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const ENEMY_SHAPES := "res://assets/shapes/ENEMY I.A24580.L68.payload.json"

const PLANET_WORLD_POSITION := Vector3(0, 0, -3000) # must match space_flight.tscn's Planet node
const COMBAT_RANGE := 4000.0 # liberty, see doc comment above
const INCOMING_FIRE_CHANCE := 0.6 # line 192's bounding-box variant
const SHOOTDOWN_CHANCE := 0.3 # line 5240
const TICK_INTERVAL := 1.0 # liberty -- the original rolls this every
	# main-loop pass (every frame); BASIC's own loop runs far slower
	# than 60fps once all its PRINT/DRAW calls are counted, so a
	# per-frame roll here would land ambient damage much faster than
	# the original's real effective cadence. Tuned to feel similarly
	# occasional rather than ported byte-exact.

signal player_destroyed
signal status_message(text: String)

@onready var _ship_destruction: ShipDestructionScript = $HGRCanvas/ShipDestruction
@onready var _incoming_fire: IncomingFireScript = $HGRCanvas/IncomingFire
@onready var _tick_timer: Timer = $TickTimer


func _ready() -> void:
	var table := ShapeTable.new()
	table.load_shapes(ENEMY_SHAPES)
	_ship_destruction.table = table
	_incoming_fire.table = table
	_incoming_fire.tracer_fired.connect(_on_tracer_fired)
	_tick_timer.timeout.connect(_ambient_damage_tick)
	_tick_timer.start(TICK_INTERVAL)


func fire_laser() -> void:
	_rearm_if_surrendered()
	if GameState.ship_laser <= 0.0:
		return
	AudioManager.play_laser()
	var tech: int = GameState.planet_tech[GameState.current_planet]
	GameState.gf_victory_progress = minf(GameState.gf_victory_progress + 10.0 / (tech + 1.0), 255.0)
	GameState.defender_damage_points = minf(GameState.defender_damage_points + 1.0 / (tech + 1.0), 255.0)
	_check_surrender()
	_check_defender_destroyed()


## Line 1500: firing while the current planet is already surrendered
## re-arms its resistance instead of doing nothing.
func _rearm_if_surrendered() -> void:
	if GameState.gf_planet_surrendered:
		GameState.gf_planet_surrendered = false
		GameState.gf_enemy_strength = 100.0


func _is_combat_eligible() -> bool:
	var tech: int = GameState.planet_tech[GameState.current_planet]
	if tech < 2:
		return false
	if GameState.gf_planet_surrendered:
		return false
	if GameState.orbital_defender_tier == 0:
		return false
	if GameState.ship_position.distance_to(PLANET_WORLD_POSITION) > COMBAT_RANGE:
		return false
	return true


func _ambient_damage_tick() -> void:
	if not _is_combat_eligible():
		return

	if randf() < INCOMING_FIRE_CHANCE and GameState.flight_escort_fighters > 0:
		_incoming_fire.start()

	var hit := false
	# Lines 3001/3010/3019: GOSUB 4110's preset (light).
	if randf() <= 0.4 and randf() <= 0.4:
		hit = true
		AudioManager.play_hit_light()
	# Line 3030/3032: GOSUB 4120's preset (medium) -- independent of the
	# branch above, same as the source (both can fire the same tick).
	if randf() <= 0.3:
		hit = true
		AudioManager.play_hit_medium()
	if not hit:
		return

	GameState.ship_shield = maxf(GameState.ship_shield - randf() * 1.1, 0.0)
	if GameState.ship_shield > 10.0:
		return

	GameState.ship_radar = maxf(GameState.ship_radar - randf() * 5.0, 0.0)
	GameState.ship_engine1 = maxf(GameState.ship_engine1 - randf() * 5.0, 0.0)
	GameState.ship_engine2 = maxf(GameState.ship_engine2 - randf() * 5.0, 0.0)
	GameState.ship_computer = maxf(GameState.ship_computer - randf() * 5.0, 0.0)
	GameState.ship_laser = maxf(GameState.ship_laser - randf() * 5.0, 0.0)
	GameState.ship_hull = maxf(GameState.ship_hull - randf() * 4.0, 0.0)

	if not GameState.damage_alert_active:
		GameState.damage_alert_active = true

	if GameState.ship_hull <= 0.0:
		_tick_timer.stop()
		player_destroyed.emit()


func _on_tracer_fired() -> void:
	if GameState.flight_escort_fighters <= 0:
		return
	if randf() < SHOOTDOWN_CHANCE:
		GameState.flight_escort_fighters -= 1
		GameState.ship_missile_system = maxf(GameState.ship_missile_system - 2.0, 0.0)


func _check_surrender() -> void:
	if not GameState.gf_planet_surrendered and GameState.gf_victory_progress >= GameState.gf_enemy_strength:
		GameState.gf_planet_surrendered = true
		GameState.planet_secured[GameState.current_planet] = true
		status_message.emit("THE PLANET HAS SURRENDERED")


func _check_defender_destroyed() -> void:
	if GameState.orbital_defender_tier != 0 and GameState.defender_damage_points > GameState.defender_damage_threshold:
		GameState.orbital_defender_tier = 0
		GameState.flight_escort_fighters = int(GameState.flight_escort_fighters / 2.0)
		_ship_destruction.play()
		status_message.emit("ORBITAL DEFENDER DESTROYED")
