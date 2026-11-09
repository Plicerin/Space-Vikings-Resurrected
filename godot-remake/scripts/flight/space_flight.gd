extends Node3D
## Mode-switch wrapper for the space-flight scene, standing in for
## STARSHIP SIMULATOR.bas's own mode-switch keys (RUNCOM/RUNRADAR/etc,
## line ~150/200-210) — remapped to modern keys via autoload/input_setup.gd
## rather than the original's raw PDL()/key-code checks.
##
## The `Planet` node used to be a plain placeholder SphereMesh. It's now
## built from PLANET # 0's real data — the same file ORBIT.bas actually
## loads for this exact "deep space, not yet landing" view. It's
## genuinely just 195 floating points with zero connecting edges — not
## a bug in this port, that's what the original data is. The slow
## constant spin on it is an idiomatic-Godot liberty, not in the
## original (which has no camera-relative planet rotation at all in
## this view) — purely so a static screenshot doesn't read as "nothing
## rendered."
##
## Getting close to the planet now triggers `scenes/planet_approach.tscn`
## (RE.bas's "REENTRY SEQUENCE", with the real per-world terrain map —
## PLANET # 1-20, genuinely modeled line-connected data, a different
## visual from this scene's own point-field `Planet`). Ported as a
## world-space distance check rather than the original's byte-exact
## `ABS(X)<900 AND ABS(Y)<900 AND ABS(Z)<900` box test (`STARSHIP
## SIMULATOR.bas` line 156) — this port's flight model doesn't track
## position in the original's units, and has no "weapon fired" flag
## yet to port that condition's other half (`AND PEEK(38210)=0`), so
## proximity alone is what gates it here.
##
## `[G] Ground Forces` is now actually gated on the same proximity check
## — the HUD text has said "(when in range)" since this scene was
## scaffolded, but nothing enforced it until now.
##
## Flight combat (ambient incoming damage, laser fire, the orbital
## defender's own destruction sequence, player-ship destruction) is
## wired in via the `FlightCombat` child under `HUD` — see
## `flight_combat.gd`'s doc comment for the full source trace.
##
## `ShipBlip`: the orbital defender itself, rendered in open-space
## flight next to the planet -- not just on the radar screen. This was
## a real gap, found only after a direct user correction ("the ship is
## 3d right next to the planet... it is the ship you see on the
## radar") and confirmed live in MAME 2026-11-09: a genuine hyperdrive
## jump to a hostile system (current_planet 1->2, orbital_defender_tier
## organically changing 3->2 on arrival -- SOL, planet 0, is pre-
## surrendered and useless as a test bed here, see
## GameState.gf_planet_surrendered's doc comment) shows a compact,
## solid silhouette near the horizon that is absent both at SOL and
## during the hyperspace-warp transit itself. Ruled out as just this
## scene's own `Planet` node (PLANET # 0 is a real but *sparse* 195-
## point field spanning a ±10000-unit volume -- it would read as
## scattered dots across a wide area, not one small dense blob) by
## inspecting that model's own raw coordinate data directly. Built from
## the same `A2_3D1_Model.build_ship_mesh(tier)` radar_screen.gd
## already uses correctly, keyed off the same
## `GameState.orbital_defender_tier` -- tier 0 (no defender) naturally
## renders nothing, same as radar, since `SHIP no 0.json` is genuinely
## an empty model. Orbit position/speed are idiomatic-Godot liberties,
## not in the original (whose 6502 bytecode interpreter does its own
## rotate/clip/perspective-divide per frame rather than tracking an
## orbit) -- see README.md's "What's real vs. stubbed" table.

const A2_3D1_Model = preload("res://scripts/shapes/a2_3d1_model.gd")
const PLANET_VISUAL_RADIUS := 400.0 # matches the old placeholder's footprint
const PLANET_WORLD_POSITION := Vector3(0, 0, -3000) # must match the Planet node's transform below
const REENTRY_RANGE := 500.0

const SHIP_BLIP_VISUAL_RADIUS := 120.0 # smaller than the planet -- see doc comment above
const SHIP_BLIP_ORBIT_RADIUS := 650.0
const SHIP_BLIP_ORBIT_SPEED := 0.15 # radians/sec, liberty -- see doc comment above
const SHIP_BLIP_SPIN_SPEED := 0.3 # matches radar_screen.gd's own spin liberty

@onready var _debug_label: Label = $HUD/DebugLabel
@onready var _planet: MeshInstance3D = $Planet
@onready var _ship_blip: MeshInstance3D = $ShipBlip
@onready var _ship: Node3D = $Ship
@onready var _flight_combat = $HUD/FlightCombat

var _reentering: bool = false
var _status_message: String = ""
var _status_timer: float = 0.0
var _ship_blip_orbit_angle: float = 0.0
var _ship_blip_tier: int = -1


func _ready() -> void:
	var built: Dictionary = A2_3D1_Model.build_planet_mesh(0)
	_planet.mesh = built["mesh"]
	var radius: float = built["radius"]
	if radius > 0.0:
		_planet.scale = Vector3.ONE * (PLANET_VISUAL_RADIUS / radius)
	assert(_planet.position.is_equal_approx(PLANET_WORLD_POSITION), "Planet node moved — update PLANET_WORLD_POSITION to match")

	_setup_ship_blip()

	_flight_combat.ship_node = _ship
	_flight_combat.ship_blip_target = _ship_blip

	_flight_combat.player_destroyed.connect(func():
		GameState.goto_scene("res://scenes/player_destroyed.tscn")
	)
	_flight_combat.status_message.connect(func(text: String):
		_status_message = text
		_status_timer = 3.0
	)


## Rebuilds the orbital defender's visible model whenever
## `orbital_defender_tier` changes -- called from `_ready()` and polled
## in `_process()` below, rather than wired to a one-off signal, so a
## destroyed defender's blip actually disappears mid-flight
## (`_check_defender_destroyed()`, flight_combat.gd) and any other
## future write to the tier (rearm, load-game) picks up the same way.
func _setup_ship_blip() -> void:
	var tier: int = GameState.orbital_defender_tier
	_ship_blip_tier = tier
	var built: Dictionary = A2_3D1_Model.build_ship_mesh(tier)
	_ship_blip.mesh = built["mesh"]
	var ship_radius: float = built["radius"]
	if ship_radius > 0.0:
		_ship_blip.scale = Vector3.ONE * (SHIP_BLIP_VISUAL_RADIUS / ship_radius)


func _process(delta: float) -> void:
	_planet.rotate_y(0.05 * delta)

	if GameState.orbital_defender_tier != _ship_blip_tier:
		_setup_ship_blip()

	_ship_blip_orbit_angle += SHIP_BLIP_ORBIT_SPEED * delta
	_ship_blip.position = PLANET_WORLD_POSITION + Vector3(
		cos(_ship_blip_orbit_angle) * SHIP_BLIP_ORBIT_RADIUS,
		0.0,
		sin(_ship_blip_orbit_angle) * SHIP_BLIP_ORBIT_RADIUS,
	)
	_ship_blip.rotate_y(SHIP_BLIP_SPIN_SPEED * delta)

	if Input.is_action_just_pressed("fire_laser"):
		_flight_combat.fire_weapon()

	if _status_timer > 0.0:
		_status_timer -= delta

	var in_range := _is_in_range()
	var damage_line := "\nDAMAGE ALERT" if GameState.damage_alert_active else ""
	var status_line := ("\n" + _status_message) if _status_timer > 0.0 else ""
	var weapon_label := "MISSILE" if GameState.missile_mode_active else "LASER"
	_debug_label.text = (
		"PITCH %d   BANK %d   HEADING %d   THROTTLE %.2f\nPOS %s\n\n[C] Command Console   [G] Ground Forces (%s)   [R] Radar   [SPACE] Fire %s   [TAB] Switch Weapon%s%s"
		% [
			int(GameState.pitch_deg), int(GameState.bank_deg), int(GameState.heading_deg),
			GameState.throttle, GameState.ship_position,
			"in range" if in_range else "out of range",
			weapon_label,
			damage_line, status_line,
		]
	)

	if in_range and not _reentering:
		_reentering = true
		GameState.goto_scene("res://scenes/planet_approach.tscn")


func _is_in_range() -> bool:
	return GameState.ship_position.distance_to(PLANET_WORLD_POSITION) < REENTRY_RANGE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_com"):
		GameState.goto_scene("res://scenes/com.tscn")
	elif event.is_action_pressed("open_ground_forces"):
		if _is_in_range():
			GameState.goto_scene("res://scenes/ground_forces.tscn")
	elif event.is_action_pressed("open_radar"):
		GameState.goto_scene("res://scenes/radar.tscn")
	elif event.is_action_pressed("toggle_weapon"):
		GameState.missile_mode_active = not GameState.missile_mode_active
