extends Control
## Developer preview of every flight-combat effect in combat_fx.gd, one
## button each, on an empty hi-res page. Reachable from the Start
## screen. Effects run one at a time, as in the original; a button
## pressed while one is running does nothing.

const CombatFx = preload("res://scripts/combat/combat_fx.gd")

@onready var _fx: CombatFx = $CombatFx
@onready var _status: Label = $VBox/Status
@onready var _buttons: HBoxContainer = $VBox/Buttons


func _ready() -> void:
	_bind("LaserButton", "Laser: three pulses (lines 1505-1530).", func() -> bool: return _fx.fire_laser())
	_bind("MissileHitButton", "Missile, direct hit (lines 1010-1060, 1200).", func() -> bool: return _fx.fire_missile(true))
	_bind("MissileMissButton", "Missile, miss (lines 1010-1060, 1100).", func() -> bool: return _fx.fire_missile(false))
	_bind("FighterButton", "Fighter pass, turrets silent (lines 5000-5098).", func() -> bool: return _fx.fighter_pass(false))
	_bind("FighterRedButton", "Fighter pass at condition RED (lines 5000-5251).", func() -> bool: return _fx.fighter_pass(true))
	_bind("DamageButton", "Defender fire: light flashes, then the heavier one (lines 3019, 3032).", func() -> bool: return _fx.damage(randi_range(1, 4), true))
	_bind("SurrenderButton", "Line 1550.", func() -> bool: return _fx.print_message("THE PLANET HAS SURRENDERED", 8, 13))
	_bind("DestroyButton", "EX.bas: the orbital defender is destroyed.", func() -> bool: return _fx.destroy_defender())
	var flash_toggle: CheckButton = _buttons.get_node("FlashToggle")
	flash_toggle.toggled.connect(func(on: bool) -> void: _fx.view.flashes_enabled = on)
	_buttons.get_node("BackButton").pressed.connect(func() -> void: GameState.goto_scene("res://scenes/start.tscn"))

	_fx.fighter_strafed.connect(func() -> void: _status.text = "Strafing hit.")
	_fx.fighter_shot_down.connect(func() -> void: _status.text = "Fighter shot down.")
	_fx.idle.connect(func() -> void: _status.text += "  Done.")


func _bind(button_name: String, text: String, start: Callable) -> void:
	var button: Button = _buttons.get_node(button_name)
	button.pressed.connect(func() -> void:
		# A fresh page each time: nothing redraws the window here.
		_fx.clear_window()
		if start.call():
			_status.text = text
	)
