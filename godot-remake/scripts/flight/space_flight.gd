extends Node3D
## Mode-switch wrapper for the space-flight scene, standing in for
## STARSHIP SIMULATOR.bas's own mode-switch keys (RUNCOM/RUNRADAR/etc,
## line ~150/200-210) — remapped to modern keys via autoload/input_setup.gd
## rather than the original's raw PDL()/key-code checks.
##
## CORRECTION (2026-11-09, a real playtest reported "the planet is
## rendered twice"): the `Planet` node used to be built from PLANET # 0's
## real data, scaled down small and parked at the destination as a
## visible foreground object. That data isn't a planet at all -- it's
## confirmed (see A2-3D1_ENGINE_ANALYSIS.md) to be the exact same
## 195-point field the real A2-3D1 engine renders every frame during
## ordinary flight, i.e. the *starfield* (now `starfield.gd`'s own real
## data, not a synthetic placeholder -- see its doc comment). Using it
## a second time here, shrunk into a small blob, is what actually
## produced the "tight inner cluster" next to the starfield's own
## "box-like" scattering. The original never renders a visible planet
## object during ordinary flight at all -- `STARSHIP SIMULATOR.bas`
## navigates by position/heading alone, with the real radar screen
## (confirmed real, see README.md) as the actual in-flight navigation
## aid, not a 3D object floating in the flight view. `Planet` is now
## kept meshless, purely as the scene-authored position reference
## `PLANET_WORLD_POSITION` is asserted against below.
##
## Getting close to the planet now triggers `scenes/planet_approach.tscn`
## (RE.bas's "REENTRY SEQUENCE", with the real per-world terrain map —
## PLANET # 1-20, genuinely modeled line-connected data -- the first
## time this scene actually shows a planet-shaped object at all, see
## `Planet` node's own doc comment above). Ported as a
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
## Flight combat (the ship's weapon, the defender's fire, fighter
## passes, both destructions) is the `FlightCombat` child under `HUD` —
## see `flight_combat.gd`. This script handles the four panel switches,
## which use the original's own keys (STARSHIP SIMULATOR.bas lines
## 203-206, CALL_SITES.md section 2): S shields, W missile/laser, B
## condition, A autopilot.
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
## orbit) -- see README.md's "What's real vs. stubbed" table. Re-tuned
## 2026-11-09 to a slow, discrete step grounded in the real engine's
## live-measured redraw cadence -- see SHIP_BLIP_STEP_INTERVAL_SEC's own
## doc comment below for the full reasoning and the MAME measurement.

const A2_3D1_Model = preload("res://scripts/shapes/a2_3d1_model.gd")
const PLANET_WORLD_POSITION := Vector3(0, 0, -3000) # must match the Planet node's transform below
const REENTRY_RANGE := 500.0
const CONDITION_NAMES := ["", "GREEN", "BLUE", "RED"]

const SHIP_BLIP_VISUAL_RADIUS := 120.0 # smaller than the planet -- see doc comment above
const SHIP_BLIP_ORBIT_RADIUS := 650.0

## Re-tuned 2026-11-09 after a real playtest ("the game still moves too
## fast... it should be for all intents and purposes still... sub-second
## fps on the Apple II, so 20-60fps is like warp speed"). The old version
## animated continuously every frame at 0.15 rad/sec orbit + 0.3 rad/sec
## self-spin -- numbers picked for a smooth 60fps feel with no reference
## to the original's own pacing, and the self-spin (independent of the
## orbit direction) is also what read as "twisting in space" rather than
## orbiting.
##
## Live-measured this session to ground the retune in something real
## rather than a second guess: a MAME write-tap on $6CE0 (the confirmed
## once-per-redraw double-buffer flip byte -- see
## A2-3D1_ENGINE_ANALYSIS.md) during ordinary ambient flight with no
## input sent at all shows the real A2-3D1 engine completing one full
## redraw roughly every 374-380 video frames at MAME's 60fps -- about
## 6.3 real seconds per frame, i.e. well under 1fps, exactly matching
## the user's own memory of the hardware.
##
## Re-modeled as a discrete step at that measured cadence instead of
## smooth per-frame interpolation, so the blip genuinely sits still
## between steps rather than gliding -- and facing the tangent of its
## own orbit instead of spinning independently, so each step reads as
## "moved to a new point in its orbit," not "spun in place."
const SHIP_BLIP_STEP_INTERVAL_SEC := 6.3
const SHIP_BLIP_ORBIT_STEP_RAD := 0.02 # ~314 steps, ~33 real minutes per full orbit

@onready var _debug_label: Label = $HUD/DebugLabel
@onready var _planet: MeshInstance3D = $Planet
@onready var _ship_blip: MeshInstance3D = $ShipBlip
@onready var _ship: Node3D = $Ship
@onready var _flight_combat = $HUD/FlightCombat

var _reentering: bool = false
var _ship_blip_orbit_angle: float = 0.0
var _ship_blip_step_timer: float = 0.0
var _ship_blip_tier: int = -1


func _ready() -> void:
	assert(_planet.position.is_equal_approx(PLANET_WORLD_POSITION), "Planet node moved — update PLANET_WORLD_POSITION to match")

	_setup_ship_blip()

	_flight_combat.ship_node = _ship
	_flight_combat.ship_blip_target = _ship_blip

	_flight_combat.player_destroyed.connect(func():
		GameState.goto_scene("res://scenes/player_destroyed.tscn")
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
	_update_ship_blip_transform()


## Places the blip at its current orbit angle, facing the orbit's own
## tangent direction rather than spinning independently -- see
## SHIP_BLIP_STEP_INTERVAL_SEC's doc comment above. Called once up front
## (so the blip isn't sitting at the planet's own origin for the first
## full step interval) and again every time a step actually advances.
func _update_ship_blip_transform() -> void:
	var offset := Vector3(
		cos(_ship_blip_orbit_angle) * SHIP_BLIP_ORBIT_RADIUS,
		0.0,
		sin(_ship_blip_orbit_angle) * SHIP_BLIP_ORBIT_RADIUS,
	)
	_ship_blip.position = PLANET_WORLD_POSITION + offset
	var tangent := Vector3(-sin(_ship_blip_orbit_angle), 0.0, cos(_ship_blip_orbit_angle))
	_ship_blip.look_at(_ship_blip.position + tangent, Vector3.UP)


func _process(delta: float) -> void:
	if GameState.orbital_defender_tier != _ship_blip_tier:
		_setup_ship_blip()

	_ship_blip_step_timer += delta
	if _ship_blip_step_timer >= SHIP_BLIP_STEP_INTERVAL_SEC:
		_ship_blip_step_timer = 0.0
		_ship_blip_orbit_angle += SHIP_BLIP_ORBIT_STEP_RAD
		_update_ship_blip_transform()

	if Input.is_action_just_pressed("fire_laser"):
		_flight_combat.fire_weapon()

	var in_range := _is_in_range()
	var damage_line := "\nDAMAGE ALERT" if GameState.damage_alert_active else ""
	_debug_label.text = (
		"PITCH %d   BANK %d   HEADING %d   THROTTLE %.2f\nPOS %s\nSHIELDS %s (%d)   CONDITION %s   %s   %s%s\n\n[SPACE] Fire   [W] Missile/Laser   [S] Shields   [B] Condition   [A] Autopilot\n[C] Command Console   [R] Radar   [G] Ground Forces (%s)"
		% [
			int(GameState.pitch_deg), int(GameState.bank_deg), int(GameState.heading_deg),
			GameState.throttle, GameState.ship_position,
			"UP" if GameState.shields_up else "DOWN", int(GameState.ship_shield),
			CONDITION_NAMES[clampi(GameState.condition, 1, 3)],
			"MISSILE" if GameState.missile_mode_active else "LASER",
			"AUTO" if GameState.autopilot_active else "MANUAL",
			damage_line,
			"in range" if in_range else "out of range",
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
	# TRANLIT.OBJ0's four toggle routines ($9643, $966A, $96A5, $96DF).
	elif event.is_action_pressed("toggle_weapon"):
		GameState.missile_mode_active = not GameState.missile_mode_active
	elif event.is_action_pressed("toggle_shields"):
		GameState.shields_up = not GameState.shields_up
	elif event.is_action_pressed("toggle_condition"):
		# 2 -> 3, 3 -> 1, anything else -> 2
		match GameState.condition:
			2: GameState.condition = 3
			3: GameState.condition = 1
			_: GameState.condition = 2
	elif event.is_action_pressed("toggle_autopilot"):
		GameState.autopilot_active = not GameState.autopilot_active
