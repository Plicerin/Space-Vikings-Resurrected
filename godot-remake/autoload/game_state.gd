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
# $38389 (enlist) / $38149 (base) — "once per trip" flags, both reset
# together by H_D.bas line 105 at the start of a fresh orbital
# engagement. This port's nearest equivalent moment is the re-entry
# sequence (scripts/ui/planet_approach.gd) — see its _ready().
var enlisted_this_trip: bool = false
var base_built_this_trip: bool = false

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
# defender tech tier" register — the real text per tier, straight from
# SHIP no N I.D..bas (not a guess): 0 = no ship ("THERE IS NO STARSHIP
# IN THIS SYSTEM" — an unarmed station), 1 = "SMALL SPACE LAB AND
# OBSERVATORY, MINIMUM WEAPONS AND ARMOR" (weakest real ship), 3 =
# "LIGHT CRUISER WITH LASERS, MISSILES AND FIGHTER COVER", 4 = "HEAVY
# CRUISER WITH PHOTON MISSILES AND HEAVY LASERS, 20-40 FIGHTERS" —
# a raw ET value of 2 always gets remapped to 3 before use in the
# original (H_D.bas/ORBIT.bas's tier-correction logic), so 2 itself
# never appears here. Confirmed live in MAME 2026-11-07: this is
# exactly which SHIP # N wireframe RADAR.bas renders — see
# A2-3D1_ENGINE_ANALYSIS.md and scripts/shapes/a2_3d1_model.gd.
#
# Exhaustively grepped every detokenized .bas file for writes to
# $38205 (2026-11-09): the ONLY one in the entire BASIC source is
# EX.bas's post-encounter `POKE 38205,0` reset. It is never assigned a
# nonzero tier anywhere in BASIC — H_D.bas, ORBIT.bas and RADAR.bas all
# only ever read it. It must be set by machine code (plausibly inside
# "SPACE SIMULATOR ASSEMBLY" or another CALL'd overlay reachable only
# from the hyperdrive-jump path), which the available linear
# disassembly dumps under disassembly/ don't resolve either — those
# that were checked either don't reference $953D (its absolute
# address) at all or decode-truncate well before any plausible site.
# Confirmed real, NOT per-planet, architecture from this: $38205 is a
# single transient global, not an array indexed by planet — so this
# port now models it the same way (see orbital_defender_tier below)
# instead of fixing one tier per planet for the whole game, which was
# this field's previous, less faithful shape.
const DEFENDER_TIERS: Array[int] = [0, 1, 3, 4]
const DEFENDER_TIER_LABELS := {
	0: "THERE IS NO STARSHIP IN THIS SYSTEM.",
	1: "SMALL SPACE LAB AND OBSERVATORY\nMINIMUM WEAPONS AND ARMOR.",
	3: "LIGHT CRUISER WITH LASERS,\nMISSILES AND FIGHTER COVER.",
	4: "HEAVY CRUISER WITH PHOTON\nMISSILES AND HEAVY LASERS.\n20-40 FIGHTERS.",
}
# Re-rolled by galaxy_map.gd on each system selection — the real
# trigger point (somewhere on the hyperdrive-jump path, H_D.bas) isn't
# reachable from BASIC alone (see note above), so this port re-rolls
# at its own closest analog: committing to travel to a new system.
# Uniform pick, same distribution this field always used — only the
# *when* changed, not the odds.
var orbital_defender_tier: int = 0 # $38205 ("ET")


func reroll_orbital_defender_tier() -> void:
	orbital_defender_tier = DEFENDER_TIERS.pick_random()

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
# Only index 2 ($38173, "general goods"), 11 ($38182, "food"), and 12
# ($38183, "wine/liquor") have confirmed real-world labels from other
# BASIC source (GAME_MECHANICS_DOCUMENTATION.md); the rest are
# placeholder names — their on-screen label was never traced. Shared
# by collect.gd and scripts/ui/sell_loot.gd.
const LOOT_LABELS := [
	"RAW MATERIALS A", "RAW MATERIALS B", "GENERAL GOODS", "RAW MATERIALS C",
	"GOODS D", "GOODS E", "GOODS F", "GOODS G",
	"GOODS H", "GOODS I", "LUXURY GOODS", "FOOD", "WINE/LIQUOR",
]
# SHORE LEAVE.bas lines 2400-2406: "SELL LOOT"'s exact per-category
# credit multiplier, in loot[] index order (0 = $38171 ... 12 =
# $38183). Index 0 alone also rolls an extra RND(1) each sale (not
# baked into this table — see compute_loot_value()); the whole sum is
# then doubled (line 2406, also applied in compute_loot_value()).
const LOOT_SELL_MULTIPLIERS: Array[float] = [
	300.0, 150.0, 100.0, 200.0, 200.0, 200.0, 300.0, 15.0, 5.0, 25.0, 1500.0, 1000.0, 2000.0,
]


## SHORE LEAVE.bas lines 2400-2406 ("SELL LOOT"), ported exactly:
## index 0's multiplier is itself randomized per sale (`300*RND(1)`,
## not a fixed 300 like every other category), and the full sum is
## doubled at the end.
func compute_loot_value() -> float:
	var total := 0.0
	for i in range(loot.size()):
		var multiplier: float = LOOT_SELL_MULTIPLIERS[i]
		if i == 0:
			multiplier *= randf()
		total += loot[i] * multiplier
	return total * 2.0


## SHORE LEAVE.bas line 2170: `C = 20000 + ((RND(1)*5000) * (RND(1)*10))`.
func roll_base_cost() -> float:
	return 20000.0 + ((randf() * 5000.0) * (randf() * 10.0))

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
	for i in range(PLANET_COUNT):
		planet_tech.append(0)
		planet_secured.append(false)
		planet_has_base.append(false)
		planet_scouted.append(false)
		planet_population_scale.append(1)
	orbital_defender_tier = DEFENDER_TIERS.pick_random()

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
	enlisted_this_trip = false
	base_built_this_trip = false

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
