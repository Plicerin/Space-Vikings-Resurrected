extends Control
## Ports STATUS.bas's readout (lines 1240-1385) from GameState instead
## of PEEK.

@onready var _body: Label = $VBox/Body
@onready var _back_btn: Button = $VBox/BackButton

const MORALE_LABELS := ["", "AWFUL!!!", "POOR", "SO-SO", "FAIR", "GOOD", "EXCELLENT!"]
const LOCATION_LABELS := {
	0: "ON BOARD",
	1: "PLANETSIDE",
	2: "SHORE LEAVE",
	3: "CRYOGENIC SLEEP",
}


func _ready() -> void:
	_back_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/com.tscn"))
	var morale_label: String = MORALE_LABELS[clampi(GameState.troop_morale, 1, 6)]
	var location_label: String = LOCATION_LABELS.get(GameState.troop_location, "UNKNOWN")
	# Liberty, added 2026-11-09 after a real playtest reported "tracking
	# troops is lost": the original's own STATUS.bas never names *which*
	# planet troops are on either (same blind spot), but it's a much
	# smaller problem there since the player is sitting at a 1982 Apple
	# II keyboard with the whole session's own memory of recent moves.
	# ground_forces.gd's "YOU LEFT YOUR TROOPS ON ANOTHER PLANET!" message
	# (shown only reactively, on a failed Attack/Enlist press) was this
	# port's only other way to find out -- never proactively, and never
	# which planet. troops_stationed_at was already tracked
	# (GameState, real $38158 data) but never surfaced anywhere.
	if GameState.troop_location == 1 or GameState.troop_location == 2:
		location_label += " (%s)" % GameState.STAR_NAMES[GameState.troops_stationed_at]
	_body.text = (
		"-SHIP STATUS REPORT-\n\n"
		+ "CREDITS   : %d\n\n" % int(GameState.credits)
		+ "-TROOP STATUS-\n\n"
		+ "NO. OF TROOPS   - %d\n" % int(GameState.troops)
		+ "TROOP MORALE    - %s\n" % morale_label
		+ "TROOP LOCATION  - %s\n\n" % location_label
		+ "FIGHTERS        - %d\n" % int(GameState.gf_fighters)
		+ "TRANSPORTS      - %d\n" % int(GameState.gf_transports)
		+ "TANKS           - %d\n" % int(GameState.gf_tanks)
		+ "GROUND MISSILES - %d" % int(GameState.gf_missiles)
	)
