extends SceneTree
## Cities stand on land, and a strike burns the one it reaches.

const Cities = preload("res://scripts/flight/cities.gd")
const Terrain = preload("res://scripts/world/terrain.gd")


func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var wrong := 0
	var cities := Cities.new()
	cities.build(root, Terrain.new(3.0, Vector3(0.3, 0.5, 0.8)), 4)
	if cities.sites.size() < 20:
		print("few cities: ", cities.sites.size())
		wrong += 1
	var none := Cities.new()
	none.build(root, Terrain.new(3.0, Vector3(0.3, 0.5, 0.8)), 0)
	if not none.sites.is_empty():
		wrong += 1
	var at: Vector3 = cities.sites[0]
	if cities.hit(at + Vector3(5000, 0, 0), 40.0) != -1:
		wrong += 1
	if cities.hit(at, 40.0) != 0 or cities.hit(at, 40.0) != -1:
		wrong += 1
	print("cities checked: %d wrong (%d cities)" % [wrong, cities.sites.size()])
	quit(wrong)
