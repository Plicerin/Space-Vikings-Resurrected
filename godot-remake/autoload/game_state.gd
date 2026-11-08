extends Node
## Central shared game state — replaces the original's PEEK/POKE shared-
## memory addresses that every BASIC overlay read and wrote to hand off
## state to the next one (see the state-transition graph in
## FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md). Each field below notes
## the original address it replaces where one was confirmed in the
## analysis docs in the parent repo; fields with no cited address are
## new bookkeeping the port needs that the original didn't need in this
## form (e.g. Godot's own scene path instead of `RUN "X"`).

# --- Ship attitude & position ---
# Original: $7321 (pitch), $7322 (bank), $7323 (heading), each a
# 0-255 byte representing a full 360° turn; X/Y/Z world-position
# variables in STARSHIP SIMULATOR.bas. Stored here in degrees/world
# units directly rather than replicating the byte encoding — see
# scripts/flight/ship_controller.gd for the behavior this drives.
var ship_position: Vector3 = Vector3.ZERO
var pitch_deg: float = 0.0
var bank_deg: float = 0.0
var heading_deg: float = 0.0
var throttle: float = 0.0

# --- Economy ---
# Original: credits/stardate were persisted via the "MISC FILE" disk
# file (SD/TR/CR), not a fixed memory address — see GROUND_COMBAT_
# ANALYSIS.md's "MISC FILE" read/write call sites.
var credits: float = 1000.0
var stardate: float = 0.0

# --- Troops ---
var troops: float = 50.0 # TR — placeholder starting value; the original's
	# real starting troop count is set wherever START.bas's MISC FILE is
	# first initialized, which hasn't been traced yet. Not a confirmed
	# number — change freely once that's found.
var troop_morale: int = 6          # $38203, range 1 (AWFUL) - 6 (EXCELLENT)
var troop_location: int = 0        # $38166: 0=on board 1=planetside 2=shore leave 3=cryo
var troops_stationed_at: int = -1  # $38158

# --- Per-planet state, indexed by planet id ---
# Original: $38282+C tech, $38219+C secured, $38303+C base,
# $38261+C population scale, $38240+C scouted/visited (COM.bas
# lines 1005-1180; GROUND_COMBAT_ANALYSIS.md's source map).
const PLANET_COUNT := 20
var planet_tech: Array[int] = []
var planet_secured: Array[bool] = []
var planet_has_base: Array[bool] = []
var planet_scouted: Array[bool] = []
var planet_population_scale: Array[int] = []
# Original: $38205 ("ET"), read as a single "current target's orbital
# defender tech tier" register — 0 (no ship, e.g. an unarmed station),
# 1 (light cruiser), 3 (heavy cruiser), 4 (seen in H_D.bas/ORBIT.bas's
# tier-correction logic; a raw 2 always gets remapped to 3 before use,
# so 2 itself never appears here) — not literally a per-planet array in
# the original, simplified to one entry per planet here since the port
# doesn't yet model transit. Confirmed live in MAME 2026-11-07: this is
# exactly which SHIP # N wireframe RADAR.bas renders — see
# A2-3D1_ENGINE_ANALYSIS.md and scripts/shapes/a2_3d1_model.gd.
const DEFENDER_TIERS: Array[int] = [0, 1, 3, 4]
var planet_orbital_defender_tier: Array[int] = []

var current_planet: int = 0        # $38209 ("orbiting" planet)
var target_planet: int = 0         # $38163 (travel target)

# --- Ground battle state (GROUND_COMBAT_ANALYSIS.md, GROUND FORCES.bas
# lines 500-690) ---
var gf_enemy_strength: float = 0.0   # SP, $38150
var gf_victory_progress: float = 0.0 # VP, $38160
var gf_fighters: float = 0.0         # P, $38156
var gf_transports: float = 10.0      # TP, $38155 — placeholder starting count
var gf_tanks: float = 0.0            # T, $38154
var gf_missiles: float = 0.0         # M, $38153
var gf_reserve_troops: float = 0.0   # T9 (held back when transport capacity is exceeded)
var gf_planet_surrendered: bool = false # $38208

# --- Loot / goods inventory ---
# Original: $38171-$38183, 13 bytes, shared between COLLECT.bas's loot
# tables and SHORE LEAVE.bas's "SELL LOOT" valuation — see
# GROUND_COMBAT_ANALYSIS.md. Index 0 = $38171 ... index 12 = $38183.
var loot: Array[float] = []

# --- Stub-screen handoff (for state-graph nodes not yet built out) ---
var stub_title: String = ""
var stub_note: String = ""
var stub_back_scene: String = ""


func _ready() -> void:
	start_new_game()


func start_new_game() -> void:
	planet_tech.clear()
	planet_secured.clear()
	planet_has_base.clear()
	planet_scouted.clear()
	planet_population_scale.clear()
	planet_orbital_defender_tier.clear()
	for i in range(PLANET_COUNT):
		planet_tech.append(0)
		planet_secured.append(false)
		planet_has_base.append(false)
		planet_scouted.append(false)
		planet_population_scale.append(1)
		# Placeholder distribution — the original's real per-planet tier
		# assignment (likely tied to planet_tech/population, going by
		# GROUND_COMBAT_ANALYSIS.md's tech-tier framing) hasn't been
		# traced yet. Picked here just so the radar screen has variety
		# to actually show; change freely once that's found.
		planet_orbital_defender_tier.append(DEFENDER_TIERS.pick_random())

	loot.clear()
	for i in range(13):
		loot.append(0.0)

	credits = 1000.0
	stardate = 0.0
	troops = 50.0
	troop_morale = 6
	troop_location = 0
	troops_stationed_at = current_planet
	current_planet = 0
	target_planet = 0

	ship_position = Vector3.ZERO
	pitch_deg = 0.0
	bank_deg = 0.0
	heading_deg = 0.0
	throttle = 0.0

	gf_enemy_strength = 0.0
	gf_victory_progress = 0.0
	gf_fighters = 0.0
	gf_transports = 10.0
	gf_tanks = 0.0
	gf_missiles = 0.0
	gf_reserve_troops = 0.0
	gf_planet_surrendered = false


## Thin wrapper so call sites read like the original's `RUN "X"` program
## chaining, in one place that could later add transition effects.
func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


## Shows a generic "not yet built" screen for a state-graph node this
## scaffold hasn't implemented, with a citation back to the doc covering
## it, so the full navigation graph stays walkable while real screens
## get filled in one at a time.
func show_stub(title: String, note: String, back_scene: String) -> void:
	stub_title = title
	stub_note = note
	stub_back_scene = back_scene
	goto_scene("res://scenes/stub_screen.tscn")
