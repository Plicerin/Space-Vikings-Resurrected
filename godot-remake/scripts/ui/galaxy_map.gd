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
		# H_D.bas lines 12 and 25: the planet being left gets its record
		# written back (defender, fighters, surrendered state), and the
		# one being entered has its own loaded -- see GameState's
		# per-planet record. A destroyed defender stays destroyed.
		GameState.store_planet_record(GameState.current_planet)
		GameState.load_planet_record(index)
		GameState.current_planet = index
		GameState.target_planet = index
		# H_D.bas lines 90-93: on arrival, the ground-invasion/flight-
		# combat thresholds reset together from this planet's tech
		# (tech<2 planets get no orbital threat at all, and keep the
		# record's own defender threshold). Previously this
		# was set at the start of a ground attack instead
		# (ground_forces.gd) — moved here 2026-11-09 while wiring flight
		# combat in, to match the real arrival-time reset and because
		# flight combat (flight_combat.gd) now shares gf_victory_progress
		# with ground combat and needs it zeroed at the same real moment.
		var tech: int = GameState.planet_tech[index]
		if tech < 2:
			GameState.gf_enemy_strength = 0.0
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
		# 2026-11-10 fix: a real playtest reported "the planet and ship
		# disappeared" right after a hyperspace jump. Root cause:
		# ship_position/pitch/bank/heading/throttle were only ever reset
		# at a brand-new game (game_state.gd's new-game init) — arriving
		# at a *new* system via hyperspace left the player's ship sitting
		# wherever it happened to be at the end of whatever they were
		# doing in the *previous* system's flight scene (mid-combat,
		# past the planet, facing away, etc.), since every system shares
		# the one space_flight.tscn and its one fixed PLANET_WORLD_POSITION.
		# A hyperdrive arrival is a real reset point in spirit even
		# though the original's own engine doesn't track position the
		# same way (see space_flight.gd's own doc comment) — so this
		# port resets flight state here, matching the new-game defaults,
		# so every arrival drops you at the same sane starting point
		# relative to the new system's planet instead of carrying over
		# stale state from the last one.
		GameState.ship_position = Vector3.ZERO
		GameState.pitch_deg = 0.0
		GameState.bank_deg = 0.0
		GameState.heading_deg = 0.0
		GameState.throttle = 0.0
		# 2026-11-09 fix: this used to go straight to the Command
		# Console with zero visual feedback -- a real playtest
		# reported "hyperspace animation is absent" (and the jump
		# itself was easy to miss). hyperspace.gd ports H_D.bas's
		# real line-20 star-burst visual, then continues to com.tscn
		# itself.
		GameState.goto_scene("res://scenes/hyperspace.tscn")
