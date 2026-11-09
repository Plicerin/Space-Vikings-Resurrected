extends Control
## Ports `SUPPLY.bas`, "SUPPLY REPORT" — a real find while scoping this
## screen (2026-11-09): it's the direct, unambiguous source for every
## one of the 13 loot categories' real labels and display units,
## confirmed by literal PEEK address (`$38171`-`$38183`). It revealed
## `GameState.LOOT_LABELS` had the wrong labels at several indices —
## fixed alongside this screen, see that field's own doc comment.
##
## Two pages (lines 1410-1490), each ending with a continue prompt —
## this port uses Next/Back buttons instead of the original's
## "HIT SPACE BAR"/"1 TO RETURN TO 1ST PAGE" key-driven paging, same
## button-based convention every other screen this session uses.
## Credits ("* CREDITS = n") only appears on page 2 (line 1490).

const PAGE_1_INDICES := [10, 12, 11, 9, 8, 7, 6] # PLATINUM/GOLD/SILVER/TITANIUM/COLLAPSIUM/STEEL/FISSIONABLES
const PAGE_2_INDICES := [5, 4, 3, 2, 1, 0] # ELECTRONIC PARTS/WEAPONS/FIGHTER PARTS/LUXURY FOODS/WINE-LIQUOR/ART WORKS

@onready var _body: Label = $VBox/Body
@onready var _next_btn: Button = $VBox/ButtonRow/NextButton
@onready var _back_btn: Button = $VBox/ButtonRow/BackButton
@onready var _return_btn: Button = $VBox/ButtonRow/ReturnButton

var _page: int = 1


func _ready() -> void:
	_next_btn.pressed.connect(func(): _show_page(2))
	_back_btn.pressed.connect(func(): _show_page(1))
	_return_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/com.tscn"))
	_show_page(1)


func _show_page(page: int) -> void:
	_page = page
	var lines: Array[String] = ["- SUPPLY REPORT -", ""]
	var indices := PAGE_1_INDICES if page == 1 else PAGE_2_INDICES
	for i in indices:
		var amount := int(GameState.loot[i] * GameState.LOOT_UNIT_SCALE[i])
		lines.append("* %s = %d %s" % [GameState.LOOT_LABELS[i], amount, GameState.LOOT_UNIT_NAMES[i]])
	if page == 2:
		lines.append("* CREDITS = %d" % int(GameState.credits))
	_body.text = "\n".join(lines)

	_next_btn.visible = page == 1
	_back_btn.visible = page == 2
	_return_btn.visible = page == 2
