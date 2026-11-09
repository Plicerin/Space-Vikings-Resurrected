extends Control
## Ports COM.bas's "GALAXY DIRECTORY" (lines 900-1180), reachable both
## from the Central Computer menu directly and from Navigation
## Computer's "1) DIRECTORY" (`central_computer.gd`/`nav_computer.gd`
## — both the same real destination in the source too, line 840's
## `IF C=1 THEN 900`). Pick a system, see what's known about it.
##
## Gated per-system on `GameState.planet_scouted` ($38240+C, line
## 1005's `IF PEEK(38240+C)=0 THEN "NO INFORMATION AVAILABLE"`) — set
## true on arrival by `galaxy_map.gd`. Tech-tier description text is
## this screen's own distinct wording (lines 1030-1070), not the same
## strings `GROUND FORCES.bas`/`COLLECT.bas` use for the same tiers.
##
## Viewing a system's detail returns to this screen's own system list
## on any key (line 1180's `GOTO 900`), not further up. The list's own
## "2) RETURN" (line 969) is a genuine, literal quirk worth keeping:
## it goes to Navigation Computer's menu specifically
## (`nav_computer.tscn`), regardless of whether you reached this
## screen from there or directly from Central Computer's own
## "2) GALAXY DIRECTORY" button.

const TECH_TEXT := {
	0: "NO INTELLIGENT LIFEFORMS INDICATED.",
	1: "PRIMITIVE PSEUDO SOCIETY ONLY.",
	2: "LIMITED ATOMIC DEVELOPMENT",
	3: "SOPHISTICATED TECHNOLOGY WITH\nSTARSHIP CAPABILITY.",
	4: "ADVANCED CAPABILITY-SUPERIOR TO OURS!",
}

@onready var _list: VBoxContainer = $VBox/List
@onready var _list_items: VBoxContainer = $VBox/List/ScrollContainer/Items
@onready var _list_return_btn: Button = $VBox/List/ReturnButton
@onready var _detail: VBoxContainer = $VBox/Detail
@onready var _detail_body: Label = $VBox/Detail/Body
@onready var _detail_back_btn: Button = $VBox/Detail/BackButton


func _ready() -> void:
	_detail.visible = false
	_detail_back_btn.pressed.connect(_show_list)
	_list_return_btn.pressed.connect(func(): GameState.goto_scene("res://scenes/nav_computer.tscn"))
	_show_list()


func _show_list() -> void:
	_detail.visible = false
	_list.visible = true
	for child in _list_items.get_children():
		child.queue_free()
	for i in range(GameState.STAR_NAMES.size()):
		var btn := Button.new()
		btn.text = "%d) %s" % [i, GameState.STAR_NAMES[i]]
		btn.pressed.connect(_show_detail.bind(i))
		_list_items.add_child(btn)


func _show_detail(index: int) -> void:
	_list.visible = false
	_detail.visible = true

	var lines: Array[String] = ["%s STAR SYSTEM" % GameState.STAR_NAMES[index], ""]
	if not GameState.planet_scouted[index]:
		lines.append("NO INFORMATION AVAILABLE AT THIS TIME.")
	else:
		var tech: int = GameState.planet_tech[index]
		lines.append("TECHNOLOGICAL DEVELOPMENT:")
		lines.append(TECH_TEXT.get(tech, ""))
		if tech >= 2:
			lines.append("")
			lines.append("ORBITING DEFENSE CAPABILITY --\nFIGHTER PROTECTION PROBABLE.")
		lines.append("")
		lines.append("POPULATION = APPROX. %d" % (GameState.planet_population_scale[index] * 35294))
		if GameState.planet_secured[index]:
			lines.append("%s HAS BEEN SECURED" % GameState.STAR_NAMES[index])
		else:
			lines.append("%s IS INDEPENDENT." % GameState.STAR_NAMES[index])
		if GameState.planet_has_base[index]:
			lines.append("")
			lines.append("THERE IS AN OPERATIONAL REPAIR BASE\nON THE PLANET.")

	_detail_body.text = "\n".join(lines)
