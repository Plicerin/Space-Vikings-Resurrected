extends Control
## Minimal galaxy map: pick a planet, go to the command console there.
## The original's GALAXY MAP.bas also draws a starfield-position chart
## of each system — not ported yet, this is list-selection only.

@onready var _list: VBoxContainer = $VBox/ScrollContainer/List
@onready var _flight_btn: Button = $VBox/FlightButton


func _ready() -> void:
	_flight_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/flight/space_flight.tscn"))
	for i in range(GameState.STAR_NAMES.size()):
		var btn := Button.new()
		var secured := i < GameState.planet_secured.size() and GameState.planet_secured[i]
		var base := i < GameState.planet_has_base.size() and GameState.planet_has_base[i]
		var tags := ""
		if secured:
			tags += "  [SECURED]"
		if base:
			tags += "  [BASE]"
		btn.text = "%d) %s%s" % [i, GameState.STAR_NAMES[i], tags]
		btn.pressed.connect(_make_select_callback(i))
		_list.add_child(btn)


func _make_select_callback(index: int) -> Callable:
	return func():
		GameState.current_planet = index
		GameState.target_planet = index
		# H_D.bas loads this system's orbital defender (`SHIP # PEEK(38205)`)
		# right after a hyperdrive jump completes; that register is never
		# written in BASIC (see GameState.orbital_defender_tier's doc
		# comment), so this port re-rolls it here instead, at its closest
		# analog: committing to travel to a new system.
		GameState.reroll_orbital_defender_tier()
		# H_D.bas lines 90-93: on arrival, the ground-invasion/flight-
		# combat thresholds reset together from this planet's tech
		# (tech<2 planets get no orbital threat at all). Previously this
		# was set at the start of a ground attack instead
		# (ground_forces.gd) — moved here 2026-11-09 while wiring flight
		# combat in, to match the real arrival-time reset and because
		# flight combat (flight_combat.gd) now shares gf_victory_progress
		# with ground combat and needs it zeroed at the same real moment.
		var tech: int = GameState.planet_tech[index]
		if tech < 2:
			GameState.gf_enemy_strength = 0.0
			GameState.defender_damage_threshold = 0.0
		else:
			GameState.gf_enemy_strength = float(tech) * 60.0
			GameState.defender_damage_threshold = float(tech) * 60.0
		GameState.gf_victory_progress = 0.0
		GameState.defender_damage_points = 0.0
		# H_D.bas line 5: `POKE 301,0` — same real arrival moment resets
		# the loot diminishing-returns flag too (see
		# GameState.loot_collected_this_visit's doc comment).
		GameState.loot_collected_this_visit = false
		# H_D.bas line 16: `POKE 38240+PEEK(38163),1` — arriving at a
		# system marks it scouted, gating the Galaxy Directory's detail
		# view (galaxy_directory.gd).
		GameState.planet_scouted[index] = true
		GameState.goto_scene("res://scenes/com.tscn")
