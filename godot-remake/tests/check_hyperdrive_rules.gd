extends Node
## Holds scripts/rules/hyperdrive_rules.gd (H_D.bas) to the original's own
## statements (flight_program.gd's jump_*, held to a live run of the real
## game while it was in the project): tests/golden/hyperdrive_rules.json. Jumps from random states to random stars, the
## same dice for both (the original's draws in the order of lines 50 to
## 75), and every field either of them changes compared.
##
##   godot --headless --path godot-remake res://tests/check_hyperdrive_rules.tscn

const HyperdriveRules = preload("res://scripts/rules/hyperdrive_rules.gd")
const GOLDEN := "res://tests/golden/hyperdrive_rules.json"

const FIELDS := [
	"stardate", "ship_energy", "troops_stationed_at", "troop_morale", "morale_flag", "current_planet",
	"orbital_defender_tier", "ship_x", "ship_y", "ship_z", "ship_pitch", "ship_bank", "ship_heading",
	"gf_enemy_strength", "defender_damage_threshold", "gf_victory_progress", "defender_damage_points",
	"enlisted_this_trip", "base_built_this_trip", "loot_collected_this_visit", "planet_scouted",
	"planet_defender_threshold", "planet_defender_type", "planet_escort_fighters", "planet_surrendered",
	"flight_escort_fighters", "gf_planet_surrendered", "planet_secured",
]

var _bad := 0
var _checked := 0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	for i in 150:
		_jump(rng, i, golden.jumps[i])
	_refusals()
	print("hyperdrive rules: %d compared, %d wrong" % [_checked, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


func _state(rng: RandomNumberGenerator) -> void:
	GameState.start_new_game()
	GameState.current_planet = rng.randi_range(0, 19)
	var target := GameState.current_planet
	while target == GameState.current_planet:
		target = rng.randi_range(0, 19)
	GameState.target_planet = target
	GameState.ship_energy = float(rng.randi_range(1, 63))
	GameState.troop_location = rng.randi_range(0, 3)
	GameState.troops_stationed_at = rng.randi_range(1, 20)
	GameState.troop_morale = rng.randi_range(0, 6)
	GameState.morale_flag = [0, 17, 70][rng.randi_range(0, 2)]
	GameState.stardate = rng.randf_range(100.0, 300.0)
	GameState.defender_damage_points = float(rng.randi_range(0, 200))
	GameState.enlisted_this_trip = true
	GameState.base_built_this_trip = true
	GameState.loot_collected_this_visit = true
	GameState.gf_victory_progress = float(rng.randi_range(0, 250))
	GameState.defender_damage_threshold = float(rng.randi_range(0, 250))
	GameState.gf_enemy_strength = float(rng.randi_range(0, 250))
	GameState.orbital_defender_tier = rng.randi_range(0, 4)
	GameState.flight_escort_fighters = rng.randi_range(0, 30)
	GameState.in_atmosphere = false


func _snapshot() -> Dictionary:
	var out := {}
	for field: String in FIELDS:
		var value: Variant = GameState.get(field)
		out[field] = value.duplicate() if value is Array else value
	return out


func _jump(rng: RandomNumberGenerator, i: int, golden: Dictionary) -> void:
	_state(rng)
	var seed := rng.randi()
	_checked += 1
	seed(seed)
	var mine_cost := HyperdriveRules.jump(func() -> float: return randf())
	var mine: Dictionary = JSON.parse_string(JSON.stringify(_snapshot()))
	var theirs: Dictionary = golden.after
	var differences := []
	if seed != int(golden.seed):
		differences.append("the test's dice are not the recording's")
	for field: String in FIELDS:
		if JSON.stringify(theirs[field]) != JSON.stringify(mine[field]):
			differences.append("%s: %s against %s" % [field, str(theirs[field]).left(60), str(mine[field]).left(60)])
	if int(golden.cost) != mine_cost:
		differences.append("cost %d against %d" % [golden.cost, mine_cost])
	if not differences.is_empty():
		_bad += 1
		print("WRONG  jump %d: %s" % [i, "; ".join(differences)])


func _refusals() -> void:
	GameState.start_new_game()
	GameState.in_atmosphere = true
	GameState.target_planet = 5
	_check("no jump from the atmosphere", HyperdriveRules.refused())
	GameState.in_atmosphere = false
	GameState.target_planet = GameState.current_planet
	_check("none to the star the ship is at", HyperdriveRules.refused())
	GameState.target_planet = -1
	_check("none with no course set", HyperdriveRules.refused())
	GameState.target_planet = 5
	_check("and one where there is a course", not HyperdriveRules.refused())
	GameState.ship_energy = 0.0
	_check("with no energy at all the ship is lost", not HyperdriveRules.has_energy())
	GameState.ship_energy = 0.4
	_check("a fraction of a point is none (the byte is 0)", not HyperdriveRules.has_energy())


func _check(what: String, ok: bool) -> void:
	_checked += 1
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1
