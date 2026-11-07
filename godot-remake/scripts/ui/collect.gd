extends Control
## Ports COLLECT.bas's loot-by-tech-tier tables (lines 800-1090). The
## original has a verified typo bug — line 960 reads $38180 but writes
## the result to $31180, so that category never actually accumulates
## (see GROUND_COMBAT_ANALYSIS.md) — not reproduced here; this port
## writes to the same index it read from, like every other category.

@onready var _body: Label = $VBox/Body
@onready var _continue_btn: Button = $VBox/ContinueButton

# loot[] index -> original address: index N = $38171 + N (0 = $38171 ...
# 12 = $38183). Only index 2 ($38173, "general goods"), 11 ($38182,
# "food"), and 12 ($38183, "wine/liquor") have confirmed real-world
# labels from other BASIC source (GAME_MECHANICS_DOCUMENTATION.md); the
# rest are placeholder names — their on-screen label was never traced.
const LABELS := [
	"RAW MATERIALS A", "RAW MATERIALS B", "GENERAL GOODS", "RAW MATERIALS C",
	"GOODS D", "GOODS E", "GOODS F", "GOODS G",
	"GOODS H", "GOODS I", "LUXURY GOODS", "FOOD", "WINE/LIQUOR",
]

# COLLECT.bas lines 925-1050: which multiplier (J1 or J2) each category
# uses at tech 2-4, and the one category (index 2, $38173) that always
# uses a fixed RND(1)*20 regardless of tier.
const J1_INDICES := [0, 4, 5, 8, 9]
const J2_INDICES := [1, 3, 6, 7, 10, 11, 12]
const FIXED_INDEX := 2


func _ready() -> void:
	_continue_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/com.tscn"))

	var tech: int = GameState.planet_tech[GameState.current_planet]
	var lines := ["TROOPS ARE NOW COLLECTING LOOT.", ""]

	match tech:
		0:
			lines.append("PLANET IS NON-HABITABLE. THERE IS NO LOOT TO GATHER, SIR.")
		1:
			_add_loot(12, randf() * 5.0) # wine/liquor
			_add_loot(11, randf() * 5.0) # food
			_add_loot(2, randf() * 10.0) # general goods
			lines.append("PLANET IS PRIMITIVE. A LITTLE GOLD AND SILVER, SOME WINES AND LIQUORS, SIR.")
		2, 3, 4:
			var j1 := 0.0
			var j2 := 10.0
			if tech == 3:
				j1 = 10.0
				j2 = 7.0
			elif tech == 4:
				j1 = 15.0
				j2 = 15.0
			for i in J1_INDICES:
				_add_loot(i, randf() * j1)
			for i in J2_INDICES:
				_add_loot(i, randf() * j2)
			_add_loot(FIXED_INDEX, randf() * 20.0)
			var tier_names := {2: "LIMITED ATOMIC", 3: "SOPHISTICATED", 4: "SUPERIOR"}
			lines.append("PLANET HAS %s TECHNOLOGY. LOOT COLLECTED." % tier_names[tech])

	_body.text = "\n".join(lines)


func _add_loot(index: int, amount: float) -> void:
	GameState.loot[index] = clampf(GameState.loot[index] + amount, 0.0, 255.0)
