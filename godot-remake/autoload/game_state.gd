extends Node
## Central shared game state — replaces the original's PEEK/POKE shared-
## memory addresses that every BASIC overlay read and wrote to hand off
## state to the next one (see the state-transition graph in
## FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md). Each field below notes
## the original address it replaces where one was confirmed in the
## analysis docs in the parent repo; fields with no cited address are
## new bookkeeping the port needs that the original didn't need in this
## form (e.g. Godot's own scene path instead of `RUN "X"`).

# --- The machine the hi-res programs share ---
# The original's programs hand each other more than variables: the two
# hi-res pages, the 3D engine's display list at $7300 (with the ship's
# position and attitude inside it) and the character generator's cursor
# all stay as the last program left them. STARSHIP SIMULATOR relies on
# it (the instrument panel is drawn once, by INSTRUMENTS.bas, and only
# copied from page to page afterwards), so they live here and not in a
# scene.
const A2View = preload("res://scripts/shapes/a2_3d1_view.gd")
const CharGenerator = preload("res://scripts/shapes/char_generator.gd")

## A2-3D1 with its 64K and hi-res pages 1 and 2 (`view3d.pages`).
## Applesoft's HCOLOR, ROT and SCALE are page 1's fields: BASIC only
## ever draws on page 1.
var view3d: A2View = A2View.new()
## `HI-RES CHARACTER GENERATOR` and the cursor.
var chargen: CharGenerator = CharGenerator.new(view3d.pages[0], view3d.pages[1])

## Ship position: three signed 16-bit words at 29467/29469/29471, inside
## the display list's eye record. BASIC keeps its own floats (see
## flight_core.gd) and stores them here once a pass.
var ship_x: int:
	get: return view3d.peek_signed(A2View.EYE)
	set(value): view3d.poke_word(A2View.EYE, value)
var ship_y: int:
	get: return view3d.peek_signed(A2View.EYE + 2)
	set(value): view3d.poke_word(A2View.EYE + 2, value)
var ship_z: int:
	get: return view3d.peek_signed(A2View.EYE + 4)
	set(value): view3d.poke_word(A2View.EYE + 4, value)
## Pitch, bank, heading: bytes 29473-29475, 256 to the circle.
var ship_pitch: int:
	get: return view3d.peek(A2View.EYE + 6)
	set(value): view3d.poke(A2View.EYE + 6, value)
var ship_bank: int:
	get: return view3d.peek(A2View.EYE + 7)
	set(value): view3d.poke(A2View.EYE + 7, value)
var ship_heading: int:
	get: return view3d.peek(A2View.EYE + 8)
	set(value): view3d.poke(A2View.EYE + 8, value)
var ship_speed: int = 120        # $38157, 0..120 units a pass
var loop_flip: int = 0           # $952F: 1 while the nose is past vertical
var paddle_pitch: int = 128      # $38397, what the stick routine reads
var paddle_bank: int = 128       # $38398
var in_atmosphere: bool = false  # $38210
## START.bas line 260 / GALAXY MAP.bas line 3125: INSTRUMENTS.bas has to
## draw the panel before the flight program runs.
var instruments_due: bool = true
## $38391 = 77: the mark START.bas (an old game), GALAXY MAP.bas (leaving
## the chart) and END.bas (going on with the game) leave for INSTRUMENTS
## and GALAXY MAP, which then draw the panel's lamps from the flags
## as they are. Without it INSTRUMENTS calls TRANLIT, which flips all
## four switches as it draws them.
var saved_marker: bool = false
## $38388: a byte the programs hand each other when one runs the next.
## The star chart leaves the star asked about (1-20) for COM, which then
## shows that star's page and runs the chart again; COM leaves a 2 for
## RADAR. 0 is nothing.
var handover: int = 0
## $38151 = 7: COLLECT and GROUND FORCES run COM to have the console
## drawn, and COM runs GROUND FORCES straight back (COM.bas line 98).
var ground_forces_due: bool = false
## The floppy drive is still turning from the last load, which takes
## about a second off the next one. Set by a program that runs another
## straight after being loaded itself.
var drive_spinning: bool = false

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
## $38170. GROUND FORCES.bas line 14 sets it to 17 when the troops go
## into a fight; SHORE LEAVE.bas line 2087 sets it to 70. H_D.bas lines
## 12-13: jumping away with it still at 17 costs a point of morale.
var morale_flag: int = 0
var troop_location: int = 3        # $38166: 0=on board 1=planetside 2=shore
	# leave 3=cryo. Real starting value IS 3 (cryo), confirmed directly
	# from `SHIP'S DATA-M.payload.bin` (the new-game memory blob) —
	# surprising but literal: a new game starts with troops already in
	# cryogenic sleep.
var troops_stationed_at: int = 1   # $38158, real starting value — set by
	# an explicit `POKE 38158,1` in START.bas's new-game setup (line
	# 2030), which runs after and overrides the blob's own value there
# $38389 (enlist) / $38149 (base) — "once per trip" flags, both reset
# together by H_D.bas line 105 on arriving at a star (flight_program.gd,
# jump_finish()). The chart's "Y" writes 8 to the second one's byte and
# COM's directory page puts 0 back (GALAXY MAP.bas 3260, COM.bas 1007),
# so asking the chart about a star gives the base its turn back.
var enlisted_this_trip: bool = false
var base_built_this_trip: bool = false

# --- Per-planet state, indexed by planet id ---
# Original: $38282+C tech, $38219+C secured, $38303+C base,
# $38261+C population scale, $38240+C scouted/visited (COM.bas
# lines 1005-1180; GROUND_COMBAT_ANALYSIS.md's source map).
const PLANET_COUNT := 20
# STATUS.bas's and COLLECT.bas's 20-name DATA line. COM.bas and GALAXY
# MAP.bas have the same list with one name different: star 16 is
# "GROOMBRIDGE 168" there (chart_program.gd, star_name()).
const STAR_NAMES := [
	"SOL", "ALPHA CENTAURI", "BARNARD'S STAR", "WOLF 359", "LUYTEN",
	"LALANDE 21185", "SIRIUS", "VARCAR", "XANADON", "EPSILON ERIDANA",
	"CYGNI", "PROCYON", "TAU CETI", "LACAILLE 9352", "LARSEN-C",
	"GROOMBRIDGE 1618", "KRUGER 60", "EPSILON INDI", "ARGO", "SHIVANDA",
]
var planet_tech: Array[int] = []
## `PEEK (38219 + planet)`, the byte itself: the programs that set it
## write 1 and 0, GALAXY MAP.bas 3066 paints a star violet when it is 1
## and COM.bas 1120 calls it secured when it is not 0. They are not the
## same thing for SOL: see load_planet_record().
var planet_secured: Array[int] = []
var planet_has_base: Array[bool] = []
var planet_scouted: Array[bool] = []
var planet_population_scale: Array[int] = []

# The real new-game galaxy, read from the master files START.bas BLOADs
# at lines 2000-2010 (`PLANET FILE-M` -> $954C, `P/F-M` -> $97E1) --
# print them with tools/newgame_data.py. Index 0 = SOL (the original's
# planet 1). The same-named files without `-M` on the disk image are a
# saved-game slot, not this.
const NEW_GAME_TECH: Array[int] = [
	3, 3, 3, 0, 2, 1, 4, 2, 3, 4, 0, 1, 4, 2, 0, 3, 3, 3, 1, 2,
]
const NEW_GAME_POPULATION: Array[int] = [
	125, 70, 175, 0, 90, 3, 200, 150, 85, 157, 0, 1, 165, 6, 0, 80, 130, 155, 2, 7,
]
# Chart position: $38366+P / $38345+P / $38324+P (GALAXY MAP.bas line
# 3020). Not drawn or used for jump cost yet -- see CALL_SITES.md.
const PLANET_X: Array[int] = [
	15, 13, 14, 8, 22, 13, 17, 14, 19, 20, 9, 7, 25, 25, 9, 25, 24, 11, 18, 11,
]
const PLANET_Y: Array[int] = [
	15, 13, 9, 16, 14, 22, 23, 8, 13, 22, 23, 23, 21, 15, 21, 5, 10, 18, 27, 11,
]
const PLANET_Z: Array[int] = [
	15, 12, 15, 12, 19, 19, 12, 9, 25, 10, 20, 14, 13, 21, 19, 11, 10, 27, 11, 25,
]
# `P/F-M` record bytes 0, 1, 3 and 4 -- see the per-planet record below.
const NEW_GAME_DEFENDER_THRESHOLD: Array[int] = [
	150, 100, 150, 0, 20, 0, 200, 20, 100, 150, 0, 0, 200, 20, 0, 100, 150, 150, 0, 20,
]
const NEW_GAME_DEFENDER_TYPE: Array[int] = [
	3, 2, 3, 0, 1, 0, 4, 1, 2, 3, 0, 0, 4, 1, 0, 2, 3, 3, 0, 1,
]
const NEW_GAME_ESCORT_FIGHTERS: Array[int] = [
	30, 20, 22, 0, 0, 0, 20, 0, 40, 25, 0, 0, 50, 0, 0, 20, 40, 26, 0, 0,
]
const NEW_GAME_SURRENDERED: Array[int] = [
	1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0,
]

# --- Per-planet record ---
# Original: 16 bytes per planet at $97E1 (`P/F`). `CALL 38825` ($97A9)
# copies one record into the working registers 38204-38219 (POKE
# 38824,0) or back out (POKE 38824,1): START.bas line 220 loads the
# starting planet's, H_D.bas line 12 stores the planet being left and
# line 25 loads the one being entered, END.bas line 210 stores before a
# save. Disassembled with tools/dis6502.py and watched live in MAME
# 2026-11-10 (tools/mame/keys_live.lua). So each planet keeps its own
# defender, fighters and surrendered state between visits; the four
# registers this port models are below, with the working copy each one
# swaps with. Bytes 2 and 5-15 (ground strength, planet number,
# atmosphere flag, saved ship position) have no per-planet use here.
var planet_defender_threshold: Array[float] = [] # byte 0 <-> defender_damage_threshold
var planet_defender_type: Array[int] = []        # byte 1 <-> orbital_defender_tier
var planet_escort_fighters: Array[int] = []      # byte 3 <-> flight_escort_fighters
var planet_surrendered: Array[bool] = []         # byte 4 <-> gf_planet_surrendered

# Original: $38205 ("ET"), the orbital defender at the current planet
# -- the real text per type, straight from SHIP no N I.D..bas (not a
# guess): 0 = no ship ("THERE IS NO STARSHIP IN THIS SYSTEM" -- an
# unarmed station), 1 = "SMALL SPACE LAB AND OBSERVATORY, MINIMUM
# WEAPONS AND ARMOR" (weakest real ship), 3 = "LIGHT CRUISER WITH
# LASERS, MISSILES AND FIGHTER COVER", 4 = "HEAVY CRUISER WITH PHOTON
# MISSILES AND HEAVY LASERS, 20-40 FIGHTERS". The data also holds a
# raw 2 (planets 2, 9 and 16); every reader that picks art or text
# substitutes 3 for it (START.bas 230, H_D.bas 38, ORBIT.bas 31,
# RADAR.bas 5002) and nothing else tells 2 from 3, so
# load_planet_record() does that substitution once. Confirmed live in
# MAME 2026-11-07: this is exactly which SHIP # N wireframe RADAR.bas
# renders -- see A2-3D1_ENGINE_ANALYSIS.md and
# scripts/shapes/a2_3d1_model.gd.
#
# The only BASIC write is EX.bas's `POKE 38205,0` when the defender is
# destroyed; every other value arrives through the record copy above,
# which is why a grep for POKEs never found a setter.
const DEFENDER_TIER_LABELS := {
	0: "THERE IS NO STARSHIP IN THIS SYSTEM.",
	1: "SMALL SPACE LAB AND OBSERVATORY\nMINIMUM WEAPONS AND ARMOR.",
	3: "LIGHT CRUISER WITH LASERS,\nMISSILES AND FIGHTER COVER.",
	4: "HEAVY CRUISER WITH PHOTON\nMISSILES AND HEAVY LASERS.\n20-40 FIGHTERS.",
}
var orbital_defender_tier: int = 0 # $38205 ("ET")


## The byte after the twentieth record ($9921), which the copy reaches
## when the ship is at SHIVANDA. `P/F-M` has 255 there.
var planet_record_overrun: int = 255


## `POKE 38824,1: CALL 38825` -- write the working registers back to
## this planet's record.
func store_planet_record(index: int) -> void:
	planet_defender_threshold[index] = defender_damage_threshold
	# the seventeenth byte: see load_planet_record()
	if index + 1 < PLANET_COUNT:
		planet_defender_threshold[index + 1] = float(planet_secured[0])
	else:
		planet_record_overrun = planet_secured[0]
	planet_defender_type[index] = orbital_defender_tier
	planet_escort_fighters[index] = flight_escort_fighters
	planet_surrendered[index] = gf_planet_surrendered


## `POKE 38824,0: CALL 38825` -- make this planet's record the working
## registers.
##
## A record is 16 bytes and the routine copies 17 (`CPY #$11` at $97DC),
## from the table at $97E1 to 38204-38220. The seventeenth is the first
## byte of the next planet's record, its defender's threshold, and 38220
## is SOL's secured flag. So that flag is whatever the planet after the
## one the ship is at has for a threshold: 100 in a new game (ALPHA
## CENTAURI's), not the 1 that `PLANET FILE-M` loads. The chart, which
## wants a 1, draws SOL white; COM's directory, which wants anything but
## 0, says SOL HAS BEEN SECURED. Storing the record puts the byte back
## where it came from, changed or not. Seen live: 38220 reads 100 at SOL
## in analysis/live/jump/jump_live.log, and SOL is white in
## analysis/live/chart/chart_clean_p1.bin.
func load_planet_record(index: int) -> void:
	defender_damage_threshold = planet_defender_threshold[index]
	if index + 1 < PLANET_COUNT:
		planet_secured[0] = int(planet_defender_threshold[index + 1])
	else:
		planet_secured[0] = planet_record_overrun
	var type: int = planet_defender_type[index]
	orbital_defender_tier = 3 if type == 2 else type
	flight_escort_fighters = planet_escort_fighters[index]
	gf_planet_surrendered = planet_surrendered[index]


## START.bas lines 230-250: what is in orbit here goes behind the star
## field, at $7879. A world with industry and no defender left has the
## wreck of one.
func load_orbit_ship() -> void:
	if planet_tech[current_planet] > 1 and orbital_defender_tier == 0:
		view3d.load_debris()
	else:
		view3d.load_ship(orbital_defender_tier)

# --- The four panel switches (CALL_SITES.md section 2). Each is a byte
# the flight program flips through `POKE 38167,n: CALL 38402`. The
# values here are `SHIP'S DATA-M`'s and START.bas line 2030's; a new
# game then runs INSTRUMENTS.bas, whose line 210 has TRANLIT redraw the
# whole panel, and that path flips all four as it draws them. So the
# first flight frame has the opposite of each (watched live). ---
#
# $38202, key W: which weapon the fire button fires. false = laser
# (STARSHIP SIMULATOR.bas line 1505), true = missile (line 1000) --
# see flight_combat.gd.
var missile_mode_active: bool = false
# $38201, key S. Line 3205: a hit always wears the shield strength
# ($38200, ship_shield) down; only with the shields up AND that strength
# above 10 does the hit stop there.
var shields_up: bool = true
# $38165, key B: 1 GREEN, 2 BLUE, 3 RED, stepped 2 -> 3 -> 1 -> 2. Only
# at RED do the turrets fire on an attacking fighter (line 5200).
var condition: int = 2
# $38164, key A: on autopilot the flight loop skips reading the
# paddles (line 15), so the ship holds its last stick position.
var autopilot_active: bool = true

var current_planet: int = 0        # $38209 ("orbiting" planet) - 1
var target_planet: int = -1        # $38163 (travel target) - 1. A new
	# game has 0 there: no course is set, and H_D.bas line 1 sends the
	# ship straight back to the flight program.

# --- Ground battle state (GROUND_COMBAT_ANALYSIS.md, GROUND FORCES.bas
# lines 500-690) ---
# Starting values for $38150/$38153-38156/$38160 below are the real
# ones, not placeholders — read directly from `extracted/SHIP'S DATA-M
# .payload.bin` (2026-11-09), the exact 54-byte binary blob
# `START.bas` line 2020 BLOADs to $9506 (=38150 decimal, the base of
# this entire shared-register range) on every new game.
var gf_enemy_strength: float = 0.0   # SP, $38150 (blob: 0)
var gf_victory_progress: float = 1.0 # VP, $38160 (blob: 1). Real reset
	# point is H_D.bas line 93, system arrival (jump_finish()), NOT the
	# start of a ground attack — GROUND FORCES.bas's own attack code
	# never touches it, and flight-combat laser fire
	# (flight_combat.gd, STARSHIP SIMULATOR.bas lines 1535-1550)
	# contributes to this SAME counter before you ever reach Ground
	# Forces. ground_forces.gd used to incorrectly zero this at every
	# Attack press — fixed 2026-11-09 while wiring flight combat in,
	# since that would have silently erased flight-combat progress.
var gf_fighters: float = 75.0        # P, $38156 (blob: 75)
var gf_transports: float = 6.0       # TP, $38155 (blob: 6)
var gf_tanks: float = 0.0            # T, $38154 (blob: 0)
var gf_missiles: float = 0.0         # M, $38153 (blob: 0) — ground-combat
	# missile COUNT, NOT the same register as ship_missile_system below
	# (that's $38187, a totally different "missile system health"
	# value the real source also happens to call "MISSILES")
var gf_reserve_troops: float = 0.0   # T9 (held back when transport capacity is exceeded)
var gf_planet_surrendered: bool = true # $38208 — real default confirmed
	# true (see start_new_game()'s own comment on this)

# --- Flight combat (STARSHIP SIMULATOR.bas lines 1500-1570/3000-3381,
# "GOSUB 1500"/"GOSUB 3000") — see scripts/flight/flight_combat.gd ---
var defender_damage_points: float = 0.0      # DP, $38152 — damage dealt
	# toward destroying the current orbital defender ship, separate
	# from gf_victory_progress (which is damage toward the PLANET's
	# ground-invasion surrender; firing contributes to both at once)
var defender_damage_threshold: float = 0.0   # $38204 — set alongside
	# gf_enemy_strength at system arrival (both `tech*60`, H_D.bas line
	# 93), but tracked independently afterward in the real source
var damage_alert_active: bool = false        # $38393 — set the first
	# time the ambient incoming-fire tick lands a hit this trip
	# (STARSHIP SIMULATOR.bas line 3360's "RUN DMG", a one-line HUD
	# flash in the real source, not a full screen — see DMG.bas);
	# cleared by Repair/Restock completing (SHORE LEAVE.bas line 2555)
var flight_escort_fighters: int = 30         # $38207 — a flight-encounter
	# escort fighter count, confirmed genuinely real and live 2026-11-09
	# (booted a fresh game in MAME, read it directly: starts at 30).
	# That 30 is SOL's own record byte 3, copied in with the rest of
	# the per-planet record above. NOT the same register as gf_fighters
	# ($38156, the ground-combat squadron count) — the real source just
	# happens to use "fighters" for both. Gates whether GOSUB 5000 (a fighter
	# pass, combat_fx.gd) runs at all; EX.bas halves it when the
	# orbital defender is destroyed; the turrets (lines 5200-5251,
	# condition RED only) take one off it per fighter shot down.

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
# Real labels for all thirteen, confirmed directly 2026-11-09 by
# SUPPLY.bas lines 1410-1490 ("SUPPLY REPORT," reached from the
# Command Console's COMPUTER sub-menu, see supply_report.gd) — it
# enumerates every one of $38171-$38183 unambiguously by address.
# This REPLACES an earlier, wrong guess: the previous version of this
# table had only 3 of 13 labels "confirmed" (from a different,
# apparently mismapped source), and two of those three were wrong —
# $38182 (index 11) was labeled "food," it's really SILVER; $38183
# (index 12) was labeled "wine/liquor," it's really GOLD. collect.gd's
# own inline comments for its tech-1 loot branch had the same
# mismapping baked in (fixed alongside this).
const LOOT_LABELS := [
	"ART WORKS", "WINE/LIQUOR", "LUXURY FOODS", "FIGHTER PARTS",
	"WEAPONS", "ELECTRONIC PARTS", "FISSIONABLES", "STEEL",
	"COLLAPSIUM", "TITANIUM", "PLATINUM", "SILVER", "GOLD",
]
# SUPPLY.bas's own per-category real-world unit scale + unit name,
# same index order — e.g. index 10 (PLATINUM, $38181) displays as
# `loot[10] * 10` POUNDS. Cosmetic (Supplies Report display only, see
# supply_report.gd) — does NOT affect compute_loot_value() below,
# which uses the raw counts exactly as SHORE LEAVE.bas's own formula
# does.
const LOOT_UNIT_SCALE: Array[float] = [
	10.0, 100.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 10.0, 20.0, 10.0,
]
const LOOT_UNIT_NAMES := [
	"UNITS", "CASES", "CASES", "CRATES", "CRATES", "CRATES", "POUNDS",
	"TONS", "TONS", "THOUSAND POUNDS", "POUNDS", "POUNDS", "POUNDS",
]
# SHORE LEAVE.bas lines 2400-2406: "SELL LOOT"'s exact per-category
# credit multiplier, in loot[] index order (0 = $38171 ... 12 =
# $38183). Index 0 alone also rolls an extra RND(1) each sale (not
# baked into this table — see compute_loot_value()); the whole sum is
# then doubled (line 2406, also applied in compute_loot_value()).
const LOOT_SELL_MULTIPLIERS: Array[float] = [
	300.0, 150.0, 100.0, 200.0, 200.0, 200.0, 300.0, 15.0, 5.0, 25.0, 1500.0, 1000.0, 2000.0,
]
# COLLECT.bas lines 920-921: a second loot-collection within the same
# system visit (any planet, not just the same one — this is a single
# global flag) gets J1/J2's multipliers cut to ×0.6; H_D.bas line 5
# resets it on every fresh system arrival (`POKE 301,0`), same moment
# the other per-arrival fields are reset at (flight_program.gd).
var loot_collected_this_visit: bool = false # $301


## SHORE LEAVE.bas lines 2400-2406 ("SELL LOOT"), ported exactly:
## index 0's multiplier is itself randomized per sale (`300*RND(1)`,
## not a fixed 300 like every other category), and the full sum is
## doubled at the end.
## The machine restarted: the reset vector, and the disk boots START.bas
## again. Whatever was in memory is gone (START builds a new game or
## loads the old one), and the monitor's text window is the whole screen.
func reboot() -> void:
	booted = false
	chargen.set_window(0, 40, 0, 24)
	goto_scene("res://scenes/start.tscn")


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
	planet_defender_threshold.clear()
	planet_defender_type.clear()
	planet_escort_fighters.clear()
	planet_surrendered.clear()
	for i in range(PLANET_COUNT):
		planet_tech.append(NEW_GAME_TECH[i])
		planet_secured.append(0)
		planet_has_base.append(false)
		planet_scouted.append(false)
		planet_population_scale.append(NEW_GAME_POPULATION[i])
		planet_defender_threshold.append(float(NEW_GAME_DEFENDER_THRESHOLD[i]))
		planet_defender_type.append(NEW_GAME_DEFENDER_TYPE[i])
		planet_escort_fighters.append(NEW_GAME_ESCORT_FIGHTERS[i])
		planet_surrendered.append(NEW_GAME_SURRENDERED[i] == 1)
	# `PLANET FILE-M`'s secured, scouted and base arrays are each 1 for
	# SOL and 0 for the other nineteen.
	planet_secured[0] = 1
	planet_record_overrun = 255
	planet_scouted[0] = true
	planet_has_base[0] = true

	loot.clear()
	for i in range(13):
		loot.append(0.0)

	credits = 10000.0
	stardate = 100.3
	troops = 2000.0
	troop_morale = 6
	morale_flag = 0
	troop_location = 3
	troops_stationed_at = 1
	current_planet = 0
	target_planet = -1
	enlisted_this_trip = false
	base_built_this_trip = false
	loot_collected_this_visit = false

	gf_enemy_strength = 0.0
	gf_victory_progress = 1.0
	gf_fighters = 75.0
	gf_transports = 6.0
	gf_tanks = 0.0
	gf_missiles = 0.0
	gf_reserve_troops = 0.0
	defender_damage_points = 0.0
	damage_alert_active = false
	# START.bas line 220: load the starting planet's record. For SOL
	# that is a surrendered planet (confirmed live in MAME 2026-11-09:
	# $38208 is already 1 on a brand new game) with a type 3 ship in
	# orbit, 30 fighters and a 150-point destruction threshold.
	load_planet_record(current_planet)
	# `SHIP'S DATA-M` and line 2030. INSTRUMENTS.bas line 210 then runs
	# TRANLIT's redraw-all, which flips every panel flag as it draws it:
	# the first flight frame has MISSILE selected, the shields down, the
	# condition at RED and the autopilot off (watched live,
	# tools/mame/keys_live.lua and pass_live.lua).
	missile_mode_active = false
	shields_up = true
	condition = 2
	autopilot_active = true
	instruments_due = true
	saved_marker = false
	handover = 0
	ground_forces_due = false
	drive_spinning = false

	# START.bas lines 40-250: the machine as a new game finds it.
	view3d.pages[0].clear()
	view3d.pages[1].clear()
	view3d.pages[0].rot = 1 # line 40: ROT= 1: SCALE= 1
	view3d.pages[0].shape_scale = 1
	view3d.reset_engine()
	view3d.load_planet(0) # line 100
	ship_x = 700 # line 190
	ship_y = 200
	ship_z = -7000
	ship_heading = 0 # line 195
	load_orbit_ship()
	chargen.page = 1 # line 2036: POKE 974,64
	chargen.mode = 0
	ship_speed = 120
	loop_flip = 0
	paddle_pitch = 128
	paddle_bank = 128
	in_atmosphere = false

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
## Where the game is saved; a test points it at a file of its own.
var save_path: String = SAVE_PATH

## False until START.bas has run: at the first title screen, and again
## after the ship is destroyed (the original reboots there).
var booted: bool = false
## START.bas's OG = 77: a game was saved when the machine booted.
var old_game: bool = false


## START.bas lines 25-26, which run at every boot before the question is
## asked: `OG = PEEK(38391): POKE 38391,0`, and if a game was saved
## PLANET FILE goes straight back to the disk without the mark. So a
## saved game can be taken up once, at the next boot, and the mark is
## gone whether the answer is O or N (watched live on copies of the
## disk, tools/mame/save_live.lua). The saved state itself stays in the
## file, as it stays on the disk.
func boot(path: String = save_path) -> void:
	booted = true
	old_game = false
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return
	# a file from before the mark was kept counts as a saved game
	old_game = data.get("saved", true)
	if old_game:
		data["saved"] = false
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))


## False if the file could not be written. On the Apple a disk that
## cannot be written to (the write-protect notch covered, say) is a DOS
## error, and this disk's DOS has one answer to every error: the SYSTEM
## ERROR screen (scripts/dos/system_error.gd).
func save_to_disk(path: String = save_path) -> bool:
	# END.bas line 210 stores the current planet's record before the BSAVEs.
	store_planet_record(current_planet)
	var data := {
		"saved": true, # 204  POKE 38391,77
		"credits": credits, "stardate": stardate,
		"troops": troops, "troop_morale": troop_morale, "morale_flag": morale_flag,
		"troop_location": troop_location, "troops_stationed_at": troops_stationed_at,
		"current_planet": current_planet, "target_planet": target_planet,
		"orbital_defender_tier": orbital_defender_tier, "missile_mode_active": missile_mode_active,
		"shields_up": shields_up, "condition": condition, "autopilot_active": autopilot_active,
		"planet_tech": planet_tech, "planet_secured": planet_secured,
		"planet_record_overrun": planet_record_overrun,
		"planet_has_base": planet_has_base, "planet_scouted": planet_scouted,
		"planet_population_scale": planet_population_scale,
		"planet_defender_threshold": planet_defender_threshold,
		"planet_defender_type": planet_defender_type,
		"planet_escort_fighters": planet_escort_fighters,
		"planet_surrendered": planet_surrendered,
		"loot": loot, "loot_collected_this_visit": loot_collected_this_visit,
		"gf_fighters": gf_fighters, "gf_transports": gf_transports,
		"gf_tanks": gf_tanks, "gf_missiles": gf_missiles,
		"gf_enemy_strength": gf_enemy_strength, "gf_victory_progress": gf_victory_progress,
		"gf_planet_surrendered": gf_planet_surrendered,
		"defender_damage_points": defender_damage_points,
		"defender_damage_threshold": defender_damage_threshold,
		"damage_alert_active": damage_alert_active,
		"flight_escort_fighters": flight_escort_fighters,
		"ship_shield": ship_shield, "ship_energy": ship_energy,
		"ship_engine1": ship_engine1, "ship_engine2": ship_engine2,
		"ship_computer": ship_computer, "ship_radar": ship_radar,
		"ship_env_control": ship_env_control, "ship_hull": ship_hull,
		"ship_hyperdrive": ship_hyperdrive, "ship_missile_system": ship_missile_system,
		"ship_laser": ship_laser, "ship_nav_computer": ship_nav_computer,
		# lines 200-202: the nine bytes at 29467, and what of the flight
		# program's own is inside SHIP'S DATA (38157, 38191)
		"ship": [ship_x, ship_y, ship_z, ship_pitch, ship_bank, ship_heading],
		"ship_speed": ship_speed, "loop_flip": loop_flip,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func load_from_disk(path: String = save_path) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	if data == null:
		return
	# START.bas runs the same lines for an old game as for a new one
	# (the machine set up, INSTRUMENTS to come); only the three files
	# are different ones.
	start_new_game()
	credits = data.get("credits", credits)
	stardate = data.get("stardate", stardate)
	troops = data.get("troops", troops)
	troop_morale = data.get("troop_morale", troop_morale)
	morale_flag = data.get("morale_flag", morale_flag)
	troop_location = data.get("troop_location", troop_location)
	troops_stationed_at = data.get("troops_stationed_at", troops_stationed_at)
	current_planet = data.get("current_planet", current_planet)
	target_planet = data.get("target_planet", target_planet)
	orbital_defender_tier = data.get("orbital_defender_tier", orbital_defender_tier)
	missile_mode_active = data.get("missile_mode_active", missile_mode_active)
	shields_up = data.get("shields_up", shields_up)
	condition = int(data.get("condition", condition))
	autopilot_active = data.get("autopilot_active", autopilot_active)
	# A save written before the per-planet records existed also holds
	# the all-zero tech and population tables of that version; keep the
	# real ones for those.
	if data.has("planet_defender_type"):
		planet_tech.assign(data.get("planet_tech", planet_tech))
		planet_population_scale.assign(data.get("planet_population_scale", planet_population_scale))
		planet_defender_threshold.assign(data.get("planet_defender_threshold", planet_defender_threshold))
		planet_defender_type.assign(data.get("planet_defender_type", planet_defender_type))
		planet_escort_fighters.assign(data.get("planet_escort_fighters", planet_escort_fighters))
		planet_surrendered.assign(data.get("planet_surrendered", planet_surrendered))
	planet_secured.assign(data.get("planet_secured", planet_secured))
	planet_record_overrun = int(data.get("planet_record_overrun", planet_record_overrun))
	planet_has_base.assign(data.get("planet_has_base", planet_has_base))
	planet_scouted.assign(data.get("planet_scouted", planet_scouted))
	loot.assign(data.get("loot", loot))
	loot_collected_this_visit = data.get("loot_collected_this_visit", loot_collected_this_visit)
	gf_fighters = data.get("gf_fighters", gf_fighters)
	gf_transports = data.get("gf_transports", gf_transports)
	gf_tanks = data.get("gf_tanks", gf_tanks)
	gf_missiles = data.get("gf_missiles", gf_missiles)
	gf_enemy_strength = data.get("gf_enemy_strength", gf_enemy_strength)
	gf_victory_progress = data.get("gf_victory_progress", gf_victory_progress)
	gf_planet_surrendered = data.get("gf_planet_surrendered", gf_planet_surrendered)
	defender_damage_points = data.get("defender_damage_points", defender_damage_points)
	defender_damage_threshold = data.get("defender_damage_threshold", defender_damage_threshold)
	damage_alert_active = data.get("damage_alert_active", damage_alert_active)
	flight_escort_fighters = data.get("flight_escort_fighters", flight_escort_fighters)
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
	ship_speed = int(data.get("ship_speed", ship_speed))
	loop_flip = int(data.get("loop_flip", loop_flip))
	# START.bas lines 220-250, as a new game does them, and 225 between:
	# the ship back where it was.
	load_planet_record(current_planet)
	var ship: Array = data.get("ship", [])
	if ship.size() == 6:
		ship_x = int(ship[0])
		ship_y = int(ship[1])
		ship_z = int(ship[2])
		ship_pitch = int(ship[3])
		ship_bank = int(ship[4])
		ship_heading = int(ship[5])
	load_orbit_ship()
	saved_marker = true # 3030  POKE 38391,77
