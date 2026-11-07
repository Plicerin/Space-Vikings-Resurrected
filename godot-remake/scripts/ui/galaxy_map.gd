extends Control
## Minimal galaxy map: pick a planet, go to the command console there.
## The original's GALAXY MAP.bas also draws a starfield-position chart
## of each system — not ported yet, this is list-selection only.

# Source: detokenized/COLLECT.bas and STATUS.bas share this exact DATA
# line (20 star names) — see GROUND_COMBAT_ANALYSIS.md.
const STAR_NAMES := [
	"SOL", "ALPHA CENTAURI", "BARNARD'S STAR", "WOLF 359", "LUYTEN",
	"LALANDE 21185", "SIRIUS", "VARCAR", "XANADON", "EPSILON ERIDANA",
	"CYGNI", "PROCYON", "TAU CETI", "LACAILLE 9352", "LARSEN-C",
	"GROOMBRIDGE 1618", "KRUGER 60", "EPSILON INDI", "ARGO", "SHIVANDA",
]

@onready var _list: VBoxContainer = $VBox/ScrollContainer/List
@onready var _flight_btn: Button = $VBox/FlightButton


func _ready() -> void:
	_flight_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/flight/space_flight.tscn"))
	for i in range(STAR_NAMES.size()):
		var btn := Button.new()
		var secured := i < GameState.planet_secured.size() and GameState.planet_secured[i]
		var base := i < GameState.planet_has_base.size() and GameState.planet_has_base[i]
		var tags := ""
		if secured:
			tags += "  [SECURED]"
		if base:
			tags += "  [BASE]"
		btn.text = "%d) %s%s" % [i, STAR_NAMES[i], tags]
		btn.pressed.connect(_make_select_callback(i))
		_list.add_child(btn)


func _make_select_callback(index: int) -> Callable:
	return func():
		GameState.current_planet = index
		GameState.target_planet = index
		GameState.goto_scene("res://scenes/com.tscn")
