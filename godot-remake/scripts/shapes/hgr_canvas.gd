extends Node2D
## A stand-in for the Apple II's 280x192 hi-res screen. Combat VFX ports
## the original's literal HPLOT/XDRAW pixel coordinates (reticle corners,
## M-loop screen Y, etc.) straight from the BASIC source instead of
## re-deriving new ones — this node just scales that 280x192 space up to
## something visible, so every child's position/size numbers match the
## cited line numbers directly.

const HGR_WIDTH := 280.0
const HGR_HEIGHT := 192.0

@export var pixel_scale: float = 3.0

func _ready() -> void:
	scale = Vector2(pixel_scale, pixel_scale)
	position = Vector2(
		(get_viewport_rect().size.x - HGR_WIDTH * pixel_scale) * 0.5,
		(get_viewport_rect().size.y - HGR_HEIGHT * pixel_scale) * 0.5,
	)
