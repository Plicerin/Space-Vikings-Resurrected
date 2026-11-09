extends Node2D
## Wires the ambient incoming-fire damage tick and laser-fire combat
## into actual flight — `STARSHIP SIMULATOR.bas` lines 189-192/
## 3000-3381 (ambient) and 185/1500-1570 (laser fire). Lives under
## `space_flight.tscn`'s HUD layer.
##
## Ambient-tick gating, ported directly: requires an orbital defender
## present (`$38205`/`orbital_defender_tier != 0`) AND either landed
## (`$38210=1` — no equivalent sub-state exists in this port; flight is
## its own separate scene from `ground_forces.tscn`/`planet_approach.
## tscn`, so this half of the original's OR is structurally always
## false here) or within a bounding box near the planet (line 192's
## X/Y/Z ranges) — approximated as a distance check from the planet's
## world position, wider than the re-entry trigger range
## (`COMBAT_RANGE`, a liberty; this port doesn't track position in the
## original's exact units).
##
## Per-tick damage formula is a literal port of GOSUB 3000: two
## independent 40%-chance rolls can set a hit flag, plus an independent
## 30%-chance roll; any hit drains SHIELD a little first, and only
## cascades to RADAR/engines/COMPUTER/LASER/HULL if the shield is
## empty (<=10 — `$38201`, "shields up", is never toggled anywhere in
## the available BASIC source, so this port treats it as permanently
## true rather than modeling a switch that doesn't exist). HULL
## reaching 0 triggers S_X.bas (`player_destroyed.tscn`).
##
## Laser fire is a literal port of GOSUB 1500/1535-1560: gated on
## LASER health > 0, always adds to `gf_victory_progress` (ground-
## invasion softening, shared with `GROUND FORCES.bas` — see that
## field's doc comment) and to `defender_damage_points` (toward
## destroying the current orbital defender, `EX.bas`/
## `ship_destruction.gd`), neither gated on actually being near
## anything — the original checks the fire button every main-loop pass
## regardless of position.
##
## Liberty: when the ambient tick lands a hit, this also plays the
## already-built `incoming_fire.gd` visual (an enemy ship crossing the
## screen firing tracers) purely for feedback — the real source spawns
## that independently (GOSUB 5000, its own separate 50%/60% roll at
## lines 190/192), not tied to whether a hit actually landed. Its own
## internal random-shootdown sub-mechanic (lines 5200-5251, which can
## reduce an "escort fighter count" register this port doesn't model,
## `$38207`) is NOT ported — left for later, not silently dropped.
##
## Also NOT ported yet: the two-fighter approach minigame's real
## trigger (`$38202`, GOSUB 1500 line 1501) — that register is never
## written anywhere in the available BASIC source, so unlike `$38205`
## (which IS read on every single encounter and clearly real) there's
## no confident analog trigger point to port it to yet;
## `fighter_encounter.gd` remains reachable only from the dev-tool
## combat demo.

const ShipDestructionScript = preload("res://scripts/combat/ship_destruction.gd")
const IncomingFireScript = preload("res://scripts/combat/incoming_fire.gd")
const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const ENEMY_SHAPES := "res://assets/shapes/ENEMY I.A24580.L68.payload.json"

const PLANET_WORLD_POSITION := Vector3(0, 0, -3000) # must match space_flight.tscn's Planet node
const COMBAT_RANGE := 4000.0 # liberty, see doc comment above
const TICK_INTERVAL := 1.0 # liberty — the original rolls this every
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
	_tick_timer.timeout.connect(_ambient_damage_tick)
	_tick_timer.start(TICK_INTERVAL)


func fire_laser() -> void:
	if GameState.ship_laser <= 0.0:
		return
	var tech: int = GameState.planet_tech[GameState.current_planet]
	GameState.gf_victory_progress = minf(GameState.gf_victory_progress + 10.0 / (tech + 1.0), 255.0)
	GameState.defender_damage_points = minf(GameState.defender_damage_points + 1.0 / (tech + 1.0), 255.0)
	_check_surrender()
	_check_defender_destroyed()


func _ambient_damage_tick() -> void:
	if GameState.orbital_defender_tier == 0:
		return
	if GameState.ship_position.distance_to(PLANET_WORLD_POSITION) > COMBAT_RANGE:
		return

	var hit := false
	if randf() <= 0.4 and randf() <= 0.4:
		hit = true
	if randf() <= 0.3:
		hit = true
	if not hit:
		return

	_incoming_fire.start()

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


func _check_surrender() -> void:
	if not GameState.gf_planet_surrendered and GameState.gf_victory_progress >= GameState.gf_enemy_strength:
		GameState.gf_planet_surrendered = true
		GameState.planet_secured[GameState.current_planet] = true
		status_message.emit("THE PLANET HAS SURRENDERED")


func _check_defender_destroyed() -> void:
	if GameState.orbital_defender_tier != 0 and GameState.defender_damage_points > GameState.defender_damage_threshold:
		GameState.orbital_defender_tier = 0
		_ship_destruction.play()
		status_message.emit("ORBITAL DEFENDER DESTROYED")
