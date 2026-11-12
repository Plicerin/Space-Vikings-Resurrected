extends Control
## The title: SPACE VIKINGS over a slowly turning night planet with its cities
## lit, stars drifting by and a heavy cruiser passing, and a menu in the
## console's own block lettering: 1) NEW GAME, 2) CONTINUE (when a game is
## saved; it stays until saved over), 3) QUIT. The keys 1 to 3, the arrows and
## Enter, or the mouse choose.

const BlockFont = preload("res://scripts/flight/block_font.gd")
const DisplayList = preload("res://scripts/world/display_list.gd")
const Craft = preload("res://scripts/world/craft.gd")
const FlightRules = preload("res://scripts/rules/flight_rules.gd")

const LED := Color(0.25, 1.0, 0.45)
const AMBER := Color(1.0, 0.69, 0.0)
const STARS := 260
const CLUSTER_RADIUS := 1500.0

## Whether a game is saved (CONTINUE is on).
var can_continue := false

var _selected := 0
var _time := 0.0
var _stars: Array = [] ## [position 0..1 each way, depth, size, phase]
var _planet: MeshInstance3D
var _ship: Node3D
var _menu_rects: Array[Rect2] = []
var _viewport: SubViewport
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	can_continue = GameState.has_saved_game()
	_selected = 1 if can_continue else 0
	_rng.seed = 1982
	for i in STARS:
		_stars.append([Vector2(_rng.randf(), _rng.randf()), _rng.randf_range(0.2, 1.0), _rng.randf_range(0.6, 2.0), _rng.randf() * TAU])
	_build_scene()


func _process(delta: float) -> void:
	_time += delta
	if _planet != null:
		_planet.rotate_y(delta * 0.06)
	if _ship != null:
		# a cruiser crossing the top of the picture, a long way off, then round again
		var t := fposmod(_time / 46.0, 1.0)
		_ship.position = Vector3(lerpf(-9.0, 9.0, t), lerpf(2.3, 1.7, t), -6.0)
		_ship.rotation = Vector3(0.1, deg_to_rad(-90.0 + 12.0), sin(_time * 0.3) * 0.08)
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_KP_1:
			_choose(0)
		KEY_2, KEY_KP_2:
			_choose(1)
		KEY_3, KEY_KP_3, KEY_ESCAPE:
			_choose(2)
		KEY_UP:
			_move(-1)
		KEY_DOWN:
			_move(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_choose(_selected)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		for i in _menu_rects.size():
			if _menu_rects[i].has_point(motion.position) and _available(i) and _selected != i:
				_selected = i
				AudioManager.play_key()
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		for i in _menu_rects.size():
			if _menu_rects[i].has_point(click.position):
				_choose(i)


func _available(item: int) -> bool:
	return item != 1 or can_continue


func _move(by: int) -> void:
	var next := _selected
	for i in 3:
		next = posmod(next + by, 3)
		if _available(next):
			break
	if next != _selected:
		_selected = next
		AudioManager.play_key()


func _choose(item: int) -> void:
	if not _available(item):
		AudioManager.play_refuse()
		return
	AudioManager.play_select()
	match item:
		0:
			GameState.start_new_game()
			GameState.goto_scene(GameState.flight_scene)
		1:
			GameState.load_from_disk()
			GameState.goto_scene(GameState.flight_scene)
		2:
			get_tree().quit()


## The night planet with its cities, and the cruiser, in a 3D world of their own
## drawn under the lettering.
func _build_scene() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(1280, 720)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	container.add_child(_viewport)
	move_child(container, 0)
	var camera := Camera3D.new()
	camera.fov = 38.0
	camera.position = Vector3(0.0, 0.0, 6.0)
	_viewport.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	_viewport.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.8, -0.3, -0.6))
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.12, 0.14, 0.2)
	environment.ambient_light_energy = 0.7
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	# the planet, low on the right and large
	var sphere := SphereMesh.new()
	sphere.radius = 3.4
	sphere.height = 6.8
	sphere.radial_segments = 96
	sphere.rings = 48
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/planet.gdshader")
	material.set_shader_parameter("tech", 4.0)
	material.set_shader_parameter("seed", 7.0)
	material.set_shader_parameter("sun_direction", Vector3(0.9, 0.35, 0.4))
	var cities := PackedVector3Array()
	for point in DisplayList.load_file("planet_0.bin").points:
		if point.length() < CLUSTER_RADIUS:
			cities.append(FlightRules.place(point).normalized())
	var count := mini(144, cities.size())
	cities.resize(144)
	material.set_shader_parameter("cities", cities)
	material.set_shader_parameter("city_count", count)
	_planet = MeshInstance3D.new()
	_planet.mesh = sphere
	_planet.material_override = material
	_planet.position = Vector3(3.6, -3.3, -1.0)
	_planet.rotation = Vector3(0.3, 0.0, 0.2)
	_viewport.add_child(_planet)
	# the cruiser
	var model := Craft.defender(4)
	if model != null:
		_ship = Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = model
		body.material_override = Craft.material(Color(0.62, 0.68, 0.78))
		var extent := model.get_aabb().size.length()
		body.scale = Vector3.ONE * (2.2 / extent)
		body.position = -model.get_aabb().get_center() * body.scale.x
		_ship.add_child(body)
		_viewport.add_child(_ship)


func _draw() -> void:
	# the stars, drifting left, the near ones faster, and twinkling
	for star: Array in _stars:
		var x := fposmod(star[0].x - _time * 0.004 * star[1], 1.0) * size.x
		var y: float = star[0].y * size.y
		var twinkle := 0.65 + 0.35 * sin(_time * (1.5 + star[1]) + star[3])
		draw_circle(Vector2(x, y), star[2] * star[1], Color(0.8, 0.88, 1.0, twinkle * star[1]))
	# the title, big, in the game's own lettering, with a glow and a CRT's scan
	var scale := minf(size.x / 1280.0, size.y / 720.0)
	var title := "SPACE VIKINGS"
	var title_scale := 7.0 * scale
	var title_at := Vector2((size.x - BlockFont.width(title, title_scale)) / 2.0, size.y * 0.12)
	BlockFont.draw(self, title, title_at, title_scale, Color(AMBER, 0.95))
	for line in range(int(title_at.y), int(title_at.y + 8.0 * title_scale), 4):
		draw_line(Vector2(title_at.x, line), Vector2(title_at.x + BlockFont.width(title, title_scale), line), Color(0.0, 0.0, 0.0, 0.25), 1.0)
	var tagline := "RESURRECTED"
	var tag_scale := 3.2 * scale
	BlockFont.draw(self, tagline, Vector2((size.x - BlockFont.width(tagline, tag_scale)) / 2.0, title_at.y + 9.5 * title_scale), tag_scale, Color(LED, 0.85))
	# the credit: this is a fan remake of someone else's game, and says so
	var credit_scale := 1.3 * scale
	var credits := [
		"A FAN REMAKE OF SPACE VIKINGS (1982)", "BY MITCHELL ROBBINS, PUBLISHED BY SUBLOGIC",
		"(C) 1982 MITCHELL ROBBINS", "A2-3D1 (C) 1979 SUBLOGIC COMPANY",
	]
	for i in credits.size():
		BlockFont.draw(self, credits[i], Vector2(size.x * 0.08, size.y - (92.0 - i * 18.0) * scale), credit_scale, Color(AMBER, 0.6))
	# the menu: a glass panel with the console's block lettering
	var panel := Rect2(size.x * 0.08, size.y * 0.52, 400.0 * scale, 190.0 * scale)
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.01, 0.04, 0.02, 0.82)
	glass.set_corner_radius_all(10)
	glass.set_border_width_all(3)
	glass.border_color = Color(0.22, 0.24, 0.27)
	glass.anti_aliasing = true
	draw_style_box(glass, panel)
	var items := ["1) NEW GAME", "2) CONTINUE", "3) QUIT"]
	var item_scale := 2.6 * scale
	_menu_rects.clear()
	for i in items.size():
		var at := panel.position + Vector2(28.0 * scale, (24.0 + i * 52.0) * scale)
		var rect := Rect2(panel.position + Vector2(10.0 * scale, (12.0 + i * 52.0) * scale), Vector2(panel.size.x - 20.0 * scale, 44.0 * scale))
		_menu_rects.append(rect)
		var on := _available(i)
		var chosen := i == _selected
		if chosen:
			draw_rect(rect, Color(LED, 0.14 + 0.04 * sin(_time * 5.0)))
			draw_rect(rect, Color(LED, 0.7), false, 1.5)
		var colour := Color(LED, 1.0 if on else 0.3)
		BlockFont.draw(self, items[i], at, item_scale, colour)
	# the scan over the glass
	for line in range(int(panel.position.y) + 4, int(panel.end.y) - 2, 3):
		draw_line(Vector2(panel.position.x + 3.0, line), Vector2(panel.end.x - 3.0, line), Color(0.0, 0.0, 0.0, 0.16), 1.0)
	var hint := "KEYS 1 2 3, ARROWS AND ENTER, OR THE MOUSE"
	BlockFont.draw(self, hint, Vector2(panel.position.x, panel.end.y + 16.0 * scale), 1.2 * scale, Color(LED, 0.55))
