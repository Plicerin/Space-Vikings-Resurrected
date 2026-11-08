extends Node2D
## RADAR.bas lines 2005-2042: the radar screen's border/crosshair/reticle
## overlay. Literal HPLOT coordinates ported straight from the BASIC
## source, same convention as laser_beam.gd — draw inside an HgrCanvas
## parent so these numbers match the cited line numbers directly.
##
## HCOLOR=2 reads as violet/magenta on real HGR hardware (confirmed
## against the live MAME screenshot in A2-3D1_ENGINE_ANALYSIS.md's
## "Live-verified 2026-11-07" section — the crosshair is unmistakably
## magenta there); HCOLOR=1 is green.

const BORDER_COLOR := Color(0.85, 0.25, 0.85)
const RETICLE_COLOR := Color(0.2, 0.9, 0.2)


func _draw() -> void:
	# Line 2005/2032: outer border, double-lined on the right edge.
	_line(Vector2(0, 0), Vector2(0, 123), BORDER_COLOR)
	_line(Vector2(0, 123), Vector2(278, 123), BORDER_COLOR)
	_line(Vector2(278, 123), Vector2(278, 0), BORDER_COLOR)
	_line(Vector2(278, 0), Vector2(0, 0), BORDER_COLOR)
	_line(Vector2(277, 0), Vector2(277, 123), BORDER_COLOR)

	# Line 2033: the four diagonal sweep lines forming the X pattern.
	_line(Vector2(1, 0), Vector2(131, 59), BORDER_COLOR)
	_line(Vector2(279, 0), Vector2(151, 59), BORDER_COLOR)
	_line(Vector2(151, 67), Vector2(279, 123), BORDER_COLOR)
	_line(Vector2(1, 123), Vector2(131, 67), BORDER_COLOR)

	# Line 2040: center cross, with a gap left for the reticle box.
	_line(Vector2(140, 1), Vector2(140, 55), BORDER_COLOR)
	_line(Vector2(140, 71), Vector2(140, 123), BORDER_COLOR)
	_line(Vector2(1, 63), Vector2(131, 63), BORDER_COLOR)
	_line(Vector2(151, 63), Vector2(279, 63), BORDER_COLOR)

	# Line 2042: the green reticle box + center dot.
	var box := PackedVector2Array([
		Vector2(137, 60), Vector2(137, 66), Vector2(145, 66), Vector2(145, 60), Vector2(137, 60),
	])
	draw_polyline(box, RETICLE_COLOR, 1.0)
	draw_rect(Rect2(Vector2(140.5, 62.5), Vector2(1, 1)), RETICLE_COLOR)


func _line(a: Vector2, b: Vector2, color: Color) -> void:
	draw_line(a, b, color, 1.0)
