extends Node
## Registers input actions in code instead of hand-edited project.godot
## input-map resource syntax, so the key choices live next to a readable
## table instead of a serialized InputEventKey blob. Loaded as an
## autoload before anything that reads these actions (see project.godot).

const ACTIONS := {
	"pitch_up": [KEY_UP, KEY_W],
	"pitch_down": [KEY_DOWN, KEY_S],
	"bank_left": [KEY_LEFT, KEY_A],
	"bank_right": [KEY_RIGHT, KEY_D],
	"throttle_up": [KEY_E, KEY_PAGEUP],
	"throttle_down": [KEY_Q, KEY_PAGEDOWN],
	"open_com": [KEY_C],
	"open_ground_forces": [KEY_G],
	"open_radar": [KEY_R],
	"fire_laser": [KEY_SPACE, KEY_CTRL],
	# Real key is W (manual page 8, "Missile/Laser... Use the W key to
	# toggle between weapon systems") -- unusable here since this port's
	# W is already WASD pitch-up (ship_controller.gd); TAB is free.
	"toggle_weapon": [KEY_TAB],
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
