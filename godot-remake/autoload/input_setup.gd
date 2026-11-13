extends Node
## Registers input actions in code instead of hand-edited project.godot
## input-map resource syntax, so the key choices live next to a readable
## table instead of a serialized InputEventKey blob. Loaded as an
## autoload before anything that reads these actions (see project.godot).

## Only what the Apple had and a PC has not: the two paddles and their
## button (scripts/flight/space_flight.gd). The game's own keys (1-4, A,
## B, C, H, R, S, W; STARSHIP SIMULATOR.bas lines 200-210) are not
## actions: they go to the program as typed characters, as they did.
const ACTIONS := {
	"stick_forward": [KEY_UP],
	"stick_back": [KEY_DOWN],
	"stick_left": [KEY_LEFT],
	"stick_right": [KEY_RIGHT],
	"fire": [KEY_SPACE],
}

func _init() -> void:
	for action_name in ACTIONS:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		for keycode in ACTIONS[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action_name, ev)
