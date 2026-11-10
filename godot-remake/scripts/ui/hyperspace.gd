extends Control
## H_D.bas (the real hyperdrive-jump overlay) lines 17-20 -- the actual
## in-between visual COM.bas's "3) GALAXY MAP" triggers, confirmed
## directly from source. Previously entirely unported: galaxy_map.gd
## switched straight to the Command Console with zero visual feedback,
## which a real playtest reported as "hyperspace animation is absent"
## (and, relatedly, made the jump itself easy to miss/not register as
## having happened at all).
##
## Line 17 clears the screen's text. Line 18 is 250 silent `CALL NOISE`s
## (sound only -- see the liberty note below). Line 20 is the actual
## visual: 175 lines, each freshly `HPLOT`'d from the screen's fixed
## center (`C1,C2` = 140,63, line 14) out to a new random point within
## the 280x192 hi-res bounds -- and never erased, so as the loop runs
## they visually accumulate into a growing white star-burst. Ported
## here as a real accumulating Line2D burst at the same rate/count
## rather than summarized or sped up.
##
## Liberty: `CALL NOISE`'s raw 250+175 calls are a continuous engine-
## whine sound in the original, not a discrete cue -- this project's
## AudioManager only has discrete hit/explosion-style sounds so far
## (see its own doc comment), so this plays silently for now rather
## than inventing a sound that doesn't match anything already there.

const LINE_COUNT := 175
const STEP_DURATION := 0.012 # feel-tuned -- draws all 175 in ~2.1s
const CENTER := Vector2(140, 63) # H_D.bas line 14: C1=140, C2=63
const HGR_WIDTH := 279.0
const HGR_HEIGHT := 125.0 # line 20's own C4 bound (not the full 192 -- leaves room for the label)

@onready var _lines: Node2D = $HGRCanvas/Lines
@onready var _label: Label = $Label

var _drawn := 0
var _timer := 0.0


func _ready() -> void:
	# current_planet is already the destination -- galaxy_map.gd sets it
	# before handing off here, same real moment H_D.bas's own arrival
	# writes (POKE 38209, ...) happen before this visual runs.
	_label.text = "HYPERSPACE JUMP\n\nDESTINATION: %s" % GameState.STAR_NAMES[GameState.current_planet]


func _process(delta: float) -> void:
	_timer += delta
	while _timer >= STEP_DURATION and _drawn < LINE_COUNT:
		_timer -= STEP_DURATION
		_draw_one_line()
	if _drawn >= LINE_COUNT:
		_arrive()


func _draw_one_line() -> void:
	_drawn += 1
	var target := Vector2(randf() * HGR_WIDTH, randf() * HGR_HEIGHT)
	var line := Line2D.new()
	line.add_point(CENTER)
	line.add_point(target)
	line.width = 1.0
	line.default_color = Color.WHITE
	_lines.add_child(line)


func _arrive() -> void:
	set_process(false)
	GameState.goto_scene("res://scenes/com.tscn")
