extends Control
## SHIP I.D.: the defender in orbit, turning slowly, and what the original's
## I.D. program says of it. Any key (or the button) goes back to the radar.
## Which ship it is and what is said is scripts/rules/radar_rules.gd, held
## to the real game (tests/check_radar_rules.gd).

const RadarRules = preload("res://scripts/rules/radar_rules.gd")
const Craft = preload("res://scripts/world/craft.gd")

const RADAR := "res://scenes/radar.tscn"
const TURN := 0.5 ## radians a second

var _turntable: Node3D

@onready var _view: SubViewport = $Center/Columns/ModelPanel/Container/View
@onready var _said: Label = $Center/Columns/Info/VBox/Said


func _ready() -> void:
	var program := RadarRules.ship_id_program(GameState.orbital_defender_tier)
	var text: Array = RadarRules.ship_id_text(program)
	_said.text = "\n".join(text.slice(1))
	($Center/Columns/Info/VBox/Return as Button).pressed.connect(_back)
	_build(program)


func _process(delta: float) -> void:
	if _turntable != null:
		_turntable.rotate_y(TURN * delta)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		get_viewport().set_input_as_handled()
		_back()


## @witness RADAR 2000
func _back() -> void:
	GameState.goto_scene(RADAR)


## The ship on a turntable under a light, in a viewport of its own.
func _build(program: int) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.04, 0.03)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.34, 0.4)
	var world := WorldEnvironment.new()
	world.environment = environment
	_view.add_child(world)
	var light := DirectionalLight3D.new()
	_view.add_child(light)
	light.look_at_from_position(Vector3.ZERO, Vector3(-0.5, -0.8, -0.6))
	var model := Craft.defender(program)
	if model == null:
		return # no ship in this system
	_turntable = Node3D.new()
	_view.add_child(_turntable)
	var body := MeshInstance3D.new()
	body.mesh = model
	body.material_override = Craft.material(Color(0.62, 0.68, 0.78))
	_turntable.add_child(body)
	var camera := Camera3D.new()
	_view.add_child(camera)
	var reach := model.get_aabb().size.length()
	camera.look_at_from_position(Vector3(0.0, reach * 0.35, reach * 1.1), Vector3.ZERO, Vector3.UP)
	camera.current = true
