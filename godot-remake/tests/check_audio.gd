extends Node
## The sounds the audio manager makes (autoload/audio_manager.gd) are all
## synthesized at start; this checks each of them is a real sound (a sensible
## length, not silent, not clipped or broken) and that building them all does
## not hold the game up. What they sound like is for the ear.
##
##   godot --headless --path godot-remake res://tests/check_audio.tscn

## Seconds each may last: [least, most].
const LENGTHS := {
	"laser": [0.2, 0.5], "enemy_fire": [0.15, 0.5], "missile": [0.6, 1.5], "hit_light": [0.1, 0.4], "hit_medium": [0.2, 0.6],
	"hit_heavy": [0.3, 0.8], "explosion": [1.5, 3.0], "small_explosion": [0.5, 1.5], "destruction": [3.0, 5.0], "jump": [1.5, 3.0],
	"tick": [0.01, 0.1], "key": [0.01, 0.1], "select": [0.05, 0.3], "refuse": [0.1, 0.4], "switch": [0.1, 0.3], "ping": [0.5, 1.5],
	"alarm": [1.0, 2.0], "capture": [0.1, 0.4],
}

var _bad := 0


func _ready() -> void:
	var sounds: Dictionary = AudioManager._sounds
	var checked := 0
	for name: String in LENGTHS:
		_check("there is a sound called %s" % name, sounds.has(name))
		if not sounds.has(name):
			continue
		var wav: AudioStreamWAV = sounds[name]
		var samples := wav.data.size() / 2
		var seconds := float(samples) / wav.mix_rate
		var peak := 0
		var energy := 0.0
		for i in samples:
			var v := wav.data.decode_s16(i * 2)
			peak = maxi(peak, absi(v))
			energy += float(v) * float(v)
		var rms := sqrt(energy / maxf(samples, 1.0)) / 32768.0
		_check("%s lasts %.2fs (%.2f to %.2f) and is heard (peak %d, rms %.3f)" % [name, seconds, LENGTHS[name][0], LENGTHS[name][1], peak, rms],
				seconds >= LENGTHS[name][0] and seconds <= LENGTHS[name][1] and peak > 8000 and peak <= 32000 and rms > 0.01)
		checked += 1
	_check("the engine's hum loops", AudioManager._engine.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	print("audio: %d sounds checked, %d wrong" % [checked, _bad])
	get_tree().quit(1 if _bad > 0 else 0)


func _check(what: String, ok: bool) -> void:
	if not ok:
		print("WRONG  %s" % what)
		_bad += 1
	else:
		print("ok     %s" % what)
