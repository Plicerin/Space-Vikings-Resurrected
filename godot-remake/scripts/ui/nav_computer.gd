extends Control
## Ports COM.bas's "NAVIGATION COMPUTER" (lines 800-897): Directory
## (same destination as Central Computer's own "2) GALAXY DIRECTORY",
## see galaxy_directory.gd's doc comment), Set Course, Return.
##
## "RETURN" (line 850's `IF C=3 THEN 20`) goes all the way back to the
## top-level Command Console menu (`com.tscn`), not to Central
## Computer — a real, literal quirk this screen shares with every
## other Central Computer sub-screen (see galaxy_directory.gd).
##
## Liberty, not in the original: "SET COURSE" genuinely sets
## `GameState.target_planet` here (lines 860-897's numeric entry,
## same gates — 1-20 only, "THAT'S WHERE WE ARE NOW" if you pick the
## current planet), but doesn't itself trigger travel. In the real
## source, a separately-triggered hyperdrive jump (`H_D.bas`, an
## in-flight key this port hasn't identified/wired) later reads
## `target_planet` to decide where you arrive. This port's
## `galaxy_map.gd` already collapses "pick a destination" and "arrive
## there" into one click — an architecture decision from well before
## this screen existed — so Set Course here is real data entry with no
## further mechanical effect yet; actually traveling still means going
## to the Galaxy Map and picking a system directly.

@onready var _menu: VBoxContainer = $VBox/Menu
@onready var _set_course: VBoxContainer = $VBox/SetCourse
@onready var _set_course_body: Label = $VBox/SetCourse/Body
@onready var _spin: SpinBox = $VBox/SetCourse/InputRow/SpinBox
@onready var _set_course_btn: Button = $VBox/SetCourse/InputRow/SetButton
@onready var _set_course_continue_btn: Button = $VBox/SetCourse/ContinueButton


func _ready() -> void:
	$VBox/Menu/DirectoryButton.pressed.connect(func(): GameState.goto_scene("res://scenes/galaxy_directory.tscn"))
	$VBox/Menu/SetCourseButton.pressed.connect(_show_set_course)
	$VBox/Menu/ReturnButton.pressed.connect(func(): GameState.goto_scene("res://scenes/com.tscn"))
	_set_course_btn.pressed.connect(_on_set_course)
	_set_course_continue_btn.pressed.connect(_show_menu)
	_show_menu()


func _show_menu() -> void:
	_set_course.visible = false
	_menu.visible = true


func _show_set_course() -> void:
	_menu.visible = false
	_set_course.visible = true
	_set_course_body.text = "NAVIGATION COMPUTER\n\nENTER DESIRED\nDESTINATION:"
	_spin.min_value = 0
	_spin.max_value = GameState.STAR_NAMES.size() - 1
	_spin.value = GameState.target_planet
	$VBox/SetCourse/InputRow.visible = true
	_set_course_continue_btn.visible = false


func _on_set_course() -> void:
	var dest := int(_spin.value)
	if dest == GameState.current_planet:
		_set_course_body.text = "THAT'S WHERE WE\nARE NOW, SIR!"
	else:
		GameState.target_planet = dest
		_set_course_body.text = "%s\nCOURSE SET." % GameState.STAR_NAMES[dest]
	$VBox/SetCourse/InputRow.visible = false
	_set_course_continue_btn.visible = true
