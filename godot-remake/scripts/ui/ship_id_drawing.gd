extends Node2D
## The bordered grid box + ship silhouette from `SHIP no N I.D..bas`
## lines 12-14 (border/grid, literal HPLOT coordinates) and lines
## 1000-1050 (the silhouette itself, decoded by
## tools/decode_ship_id.py — see scripts/shapes/ship_id_silhouette.gd).
## Draw inside an HgrCanvas parent, same convention as radar_hud.gd.

const ShipIdSilhouette = preload("res://scripts/shapes/ship_id_silhouette.gd")

const BORDER_COLOR := Color(0.2, 0.9, 0.2) # HCOLOR=1, green
const SHIP_COLOR := Color.WHITE # HCOLOR=3

var tier: int = 0:
	set(value):
		tier = value
		queue_redraw()


func _draw() -> void:
	# Lines 12-14: outer box + a 5px grid, drawn once regardless of tier
	# (SHIP no 0 I.D..bas draws this same box even with no ship to show).
	draw_line(Vector2(1, 1), Vector2(161, 1), BORDER_COLOR)
	draw_line(Vector2(161, 1), Vector2(161, 123), BORDER_COLOR)
	draw_line(Vector2(161, 123), Vector2(1, 123), BORDER_COLOR)
	draw_line(Vector2(1, 123), Vector2(1, 1), BORDER_COLOR)
	var x := 7
	while x <= 161:
		draw_line(Vector2(x, 1), Vector2(x, 123), BORDER_COLOR)
		x += 5
	var y := 5
	while y <= 123:
		draw_line(Vector2(1, y), Vector2(161, y), BORDER_COLOR)
		y += 5

	var segments: Array = ShipIdSilhouette.load_segments(tier)
	var cur: Vector2 = Vector2.ZERO
	var have_cur := false
	for seg in segments:
		var p := Vector2(seg["x"], seg["y"])
		if seg["type"] == "move":
			cur = p
			have_cur = true
		else:
			if have_cur:
				draw_line(cur, p, SHIP_COLOR)
			cur = p
			have_cur = true
