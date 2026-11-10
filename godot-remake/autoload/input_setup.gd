extends Node
## Registers input actions in code instead of hand-edited project.godot
## input-map resource syntax, so the key choices live next to a readable
## table instead of a serialized InputEventKey blob. Loaded as an
## autoload before anything that reads these actions (see project.godot).

## The letter keys are the original's own (STARSHIP SIMULATOR.bas lines
## 200-210; CALL_SITES.md has the full dispatch table): A autopilot, B
## condition, C command console, H hyperdrive, R radar, S shields, W
## missile/laser. The paddles and their button become the arrow keys and
## SPACE. G is this port's own shortcut.
const ACTIONS := {
	"pitch_up": [KEY_UP],
	"pitch_down": [KEY_DOWN],
	"bank_left": [KEY_LEFT],
	"bank_right": [KEY_RIGHT],
	"throttle_up": [KEY_E, KEY_PAGEUP],
	"throttle_down": [KEY_Q, KEY_PAGEDOWN],
	"open_com": [KEY_C],
	"open_ground_forces": [KEY_G],
	"open_radar": [KEY_R],
	"fire_laser": [KEY_SPACE, KEY_CTRL],
	"toggle_weapon": [KEY_W, KEY_TAB],
	"toggle_shields": [KEY_S],
	"toggle_condition": [KEY_B],
	"toggle_autopilot": [KEY_A],
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
