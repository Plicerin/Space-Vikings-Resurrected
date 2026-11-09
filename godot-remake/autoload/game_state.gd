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
# Original: credits/stardate/troops were persisted via the "MISC FILE"
# disk file (SD/TR/CR), not a fixed memory address. Real starting
# values, not placeholders — `START.bas` line 2050's new-game MISC
# FILE write: `PRINT 100.3: PRINT 2000: PRINT 10000` (SD, TR, CR, in
# that literal order), found 2026-11-09 while tracing Repair/Restock.
var credits: float = 10000.0
var stardate: float = 100.3

# --- Troops ---
var troops: float = 2000.0         # TR, real starting value (see above)
var troop_morale: int = 6          # $38203, range 1 (AWFUL) - 6 (EXCELLENT)
var troop_location: int = 3        # $38166: 0=on board 1=planetside 2=shore
	# leave 3=cryo. Real starting value IS 3 (cryo), confirmed directly
	# from `SHIP'S DATA-M.payload.bin` (the new-game memory blob) —
	# surprising but literal: a new game starts with troops already in
	# cryogenic sleep.
var troops_stationed_at: int = 1   # $38158, real starting value — set by
	# an explicit `POKE 38158,1` in START.bas's new-game setup (line
	# 2030), which runs after and overrides the blob's own value there
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
# Starting values for $38150/$38153-38156/$38160 below are the real
# ones, not placeholders — read directly from `extracted/SHIP'S DATA-M
# .payload.bin` (2026-11-09), the exact 54-byte binary blob
# `START.bas` line 2020 BLOADs to $9506 (=38150 decimal, the base of
# this entire shared-register range) on every new game.
var gf_enemy_strength: float = 0.0   # SP, $38150 (blob: 0)
var gf_victory_progress: float = 1.0 # VP, $38160 (blob: 1 — overwritten to
	# 0 by ground_forces.gd before every battle anyway, so this only
	# matters if something reads it before a first attack)
var gf_fighters: float = 75.0        # P, $38156 (blob: 75)
var gf_transports: float = 6.0       # TP, $38155 (blob: 6)
var gf_tanks: float = 0.0            # T, $38154 (blob: 0)
var gf_missiles: float = 0.0         # M, $38153 (blob: 0) — ground-combat
	# missile COUNT, NOT the same register as ship_missile_system below
	# (that's $38187, a totally different "missile system health"
	# value the real source also happens to call "MISSILES")
var gf_reserve_troops: float = 0.0   # T9 (held back when transport capacity is exceeded)
var gf_planet_surrendered: bool = false # $38208

# --- Ship system health (SHORE LEAVE.bas lines 2500-2545, "REPAIR
# SHIP") ---
# Real starting values, same source as the ground-battle defaults
# above (the blob), with two exceptions overridden by explicit POKEs
# in START.bas's own new-game setup (line 2030) that run right after
# the BLOAD and win: $38200 (redundant, blob already had 100) and
# $38187 (blob said 100, the explicit `POKE 38187,60` overrides it to
# 60 — the value actually used).
#
# All twelve are driven generically by REPAIR_SYSTEMS below
# (label/getter/setter/multiplier/max, in the original's exact DATA
# order) rather than one-off repair functions per field — see
# scripts/ui/repair_ship.gd.
var ship_shield: float = 100.0        # $38200
var ship_energy: float = 63.0         # $38199 — special: repairs cap at
	# 63, not 100 (SHORE LEAVE.bas line 2524's distinct formula; the
	# blob's own starting value is already exactly 63, independently
	# confirming the cap)
var ship_engine1: float = 100.0       # $38198
var ship_engine2: float = 100.0       # $38197
var ship_computer: float = 100.0      # $38196
var ship_radar: float = 100.0         # $38195
var ship_env_control: float = 128.0   # $38194 — literal blob value, above
	# the general 100 "full health" ceiling every other system uses;
	# not a transcription error, just means this system never actually
	# needs repair (its repair check is `IF D<100`, so a value that
	# starts above 100 never triggers)
var ship_hull: float = 100.0          # $38193 ("HULL DMG." in the source,
	# but higher reads as healthier here, same convention as every
	# other system — not literally "amount of damage")
var ship_hyperdrive: float = 100.0    # $38190
var ship_missile_system: float = 60.0 # $38187 — ship-system condition,
	# NOT gf_missiles (the ground-combat ammo count, $38153) above;
	# the real source just happens to label both "MISSILES"
var ship_laser: float = 100.0         # $38186
var ship_nav_computer: float = 100.0  # $38184

# label, cost multiplier, full-health value — in the original's exact
# DATA order (SHORE LEAVE.bas line 2500). repair_ship.gd reads/writes
# the matching ship_* field above by index (same match-by-index
# pattern buy_weapons.gd already uses for its 4 categories).
const REPAIR_LABELS := [
	"SHIELD", "ENERGY", "# 1 ENGINE", "# 2 ENGINE", "COMPUTER", "RADAR",
	"ENV. CONTROL", "HULL DMG.", "HYPERDRIVE", "MISSILES", "LASER", "NAV. COMP.",
]
const REPAIR_MULTIPLIERS: Array[float] = [
	150.0, 200.0, 150.0, 150.0, 150.0, 150.0, 150.0, 150.0, 150.0, 100.0, 150.0, 150.0,
]
const REPAIR_MAX_HEALTH: Array[float] = [
	100.0, 63.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0,
]


func get_ship_system_health(index: int) -> float:
	match index:
		0: return ship_shield
		1: return ship_energy
		2: return ship_engine1
		3: return ship_engine2
		4: return ship_computer
		5: return ship_radar
		6: return ship_env_control
		7: return ship_hull
		8: return ship_hyperdrive
		9: return ship_missile_system
		10: return ship_laser
		_: return ship_nav_computer


func set_ship_system_health(index: int, value: float) -> void:
	match index:
		0: ship_shield = value
		1: ship_energy = value
		2: ship_engine1 = value
		3: ship_engine2 = value
		4: ship_computer = value
		5: ship_radar = value
		6: ship_env_control = value
		7: ship_hull = value
		8: ship_hyperdrive = value
		9: ship_missile_system = value
		10: ship_laser = value
		_: ship_nav_computer = value

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

	credits = 10000.0
	stardate = 100.3
	troops = 2000.0
	troop_morale = 6
	troop_location = 3
	troops_stationed_at = 1
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
	gf_victory_progress = 1.0
	gf_fighters = 75.0
	gf_transports = 6.0
	gf_tanks = 0.0
	gf_missiles = 0.0
	gf_reserve_troops = 0.0
	gf_planet_surrendered = false

	ship_shield = 100.0
	ship_energy = 63.0
	ship_engine1 = 100.0
	ship_engine2 = 100.0
	ship_computer = 100.0
	ship_radar = 100.0
	ship_env_control = 128.0
	ship_hull = 100.0
	ship_hyperdrive = 100.0
	ship_missile_system = 60.0
	ship_laser = 100.0
	ship_nav_computer = 100.0


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


# --- Save / load (END.bas lines 190-220, "SAVE GAME") ---
# The original BSAVEs three raw memory-image files straight to the
# Apple II disk (P/F, PLANET FILE, and a 54-byte SHIP'S DATA block —
# the same memory range SHIP'S DATA-M's new-game template occupies,
# see the ship-system-health fields above) plus 9 bytes of ship
# position. This port has no equivalent of raw memory images to BSAVE,
# so it serializes the fields that actually hold persistent state
# instead, to a single JSON file — same real effect (resume where you
# left off), not a byte-exact format.
const SAVE_PATH := "user://savegame.json"


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_to_disk() -> void:
	var data := {
		"credits": credits, "stardate": stardate,
		"troops": troops, "troop_morale": troop_morale,
		"troop_location": troop_location, "troops_stationed_at": troops_stationed_at,
		"current_planet": current_planet, "target_planet": target_planet,
		"orbital_defender_tier": orbital_defender_tier,
		"planet_tech": planet_tech, "planet_secured": planet_secured,
		"planet_has_base": planet_has_base, "planet_scouted": planet_scouted,
		"planet_population_scale": planet_population_scale,
		"loot": loot,
		"gf_fighters": gf_fighters, "gf_transports": gf_transports,
		"gf_tanks": gf_tanks, "gf_missiles": gf_missiles,
		"ship_shield": ship_shield, "ship_energy": ship_energy,
		"ship_engine1": ship_engine1, "ship_engine2": ship_engine2,
		"ship_computer": ship_computer, "ship_radar": ship_radar,
		"ship_env_control": ship_env_control, "ship_hull": ship_hull,
		"ship_hyperdrive": ship_hyperdrive, "ship_missile_system": ship_missile_system,
		"ship_laser": ship_laser, "ship_nav_computer": ship_nav_computer,
		"ship_position": [ship_position.x, ship_position.y, ship_position.z],
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))


func load_from_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	if data == null:
		return
	credits = data.get("credits", credits)
	stardate = data.get("stardate", stardate)
	troops = data.get("troops", troops)
	troop_morale = data.get("troop_morale", troop_morale)
	troop_location = data.get("troop_location", troop_location)
	troops_stationed_at = data.get("troops_stationed_at", troops_stationed_at)
	current_planet = data.get("current_planet", current_planet)
	target_planet = data.get("target_planet", target_planet)
	orbital_defender_tier = data.get("orbital_defender_tier", orbital_defender_tier)
	planet_tech.assign(data.get("planet_tech", planet_tech))
	planet_secured.assign(data.get("planet_secured", planet_secured))
	planet_has_base.assign(data.get("planet_has_base", planet_has_base))
	planet_scouted.assign(data.get("planet_scouted", planet_scouted))
	planet_population_scale.assign(data.get("planet_population_scale", planet_population_scale))
	loot.assign(data.get("loot", loot))
	gf_fighters = data.get("gf_fighters", gf_fighters)
	gf_transports = data.get("gf_transports", gf_transports)
	gf_tanks = data.get("gf_tanks", gf_tanks)
	gf_missiles = data.get("gf_missiles", gf_missiles)
	ship_shield = data.get("ship_shield", ship_shield)
	ship_energy = data.get("ship_energy", ship_energy)
	ship_engine1 = data.get("ship_engine1", ship_engine1)
	ship_engine2 = data.get("ship_engine2", ship_engine2)
	ship_computer = data.get("ship_computer", ship_computer)
	ship_radar = data.get("ship_radar", ship_radar)
	ship_env_control = data.get("ship_env_control", ship_env_control)
	ship_hull = data.get("ship_hull", ship_hull)
	ship_hyperdrive = data.get("ship_hyperdrive", ship_hyperdrive)
	ship_missile_system = data.get("ship_missile_system", ship_missile_system)
	ship_laser = data.get("ship_laser", ship_laser)
	ship_nav_computer = data.get("ship_nav_computer", ship_nav_computer)
	var pos: Array = data.get("ship_position", [0.0, 0.0, 0.0])
	ship_position = Vector3(pos[0], pos[1], pos[2])
