extends Control
## Ports `S_X.bas` — the player's OWN ship being destroyed (distinct
## from `EX.bas` / `combat_fx.gd`'s `destroy_defender()`, which is the *enemy* orbital
## defender exploding). Reached when the ambient incoming-fire damage
## tick (`flight_combat.gd`, `STARSHIP SIMULATOR.bas` lines 3000-3381)
## drives `GameState.ship_hull` to exactly 0 (line 3350's
## `IF J=0 THEN PRINT "RUNS/X"`).
##
## Visually simpler than EX.bas: no ship-shape flash at all, just a
## literal port of lines 6-30's expanding radial burst (`X1=5 TO 130
## STEP 8`, 15 random lines per step, `Y2` clamped to [-60,65]) plus
## the exact text, "YOUR SHIP HAS BEEN DESTROYED!!". Line 6's `FOR J=1
## TO 500: CALL EX` (500 calls — the longest burst anywhere in the
## game) plays via AudioManager.play_destruction().
##
## The original waits for two keypresses then `PR#6` — a hard reboot
## from the disk's boot sector. This port's closest real equivalent is
## returning to the start screen (`start.tscn`), the nearest thing it
## has to "back to the title/boot"; a single key or the Continue button
## does it here instead of two presses, since this port has no
## multi-stage "press any key" idiom elsewhere either.

const CENTER := Vector2(140, 60)

@onready var _sparks: Node2D = $HGRCanvas/Sparks
@onready var _continue_btn: Button = $ContinueButton


func _ready() -> void:
	AudioManager.play_destruction()
	_continue_btn.pressed.connect(_on_continue)
	_spawn_burst()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_on_continue()


func _spawn_burst() -> void:
	var y1 := 20.0
	var x1 := 5.0
	while x1 <= 130.0:
		y1 += 4.8
		for i in range(15):
			var x2 := x1 - (randf() * (x1 + x1))
			var y2 := y1 - (randf() * (y1 + y1))
			y2 = clampf(y2, -60.0, 65.0)
			var line := Line2D.new()
			line.add_point(CENTER)
			line.add_point(CENTER + Vector2(x2, y2))
			line.width = 1.0
			line.default_color = Color.WHITE
			_sparks.add_child(line)
		x1 += 8.0


func _on_continue() -> void:
	GameState.goto_scene("res://scenes/start.tscn")
