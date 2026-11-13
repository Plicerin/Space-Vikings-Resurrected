extends Node
## The game's sounds, all made here from nothing (no sample files): filtered
## noise, sweeps and tones shaped by envelopes, the way a small synthesizer
## would. Each is built once when the game starts and played from a few
## voices, so that a laser, an explosion and a key click can sound together.
##
## The original had two sounds, a falling chirp for the laser and a burst of
## shift-register noise for every hit and explosion (LASER at $92D1, SOUND GEN
## at $9276, read from the disassembly). The events that make them are the
## same here; the sounds are modern: the laser a bright zap, the hits a thump
## and a crackle, the explosion a crack with a low rumble after it, the jump a
## rising rush. The names of the old cues are kept (`play_laser`,
## `play_hit_light` and the rest) so that what called them still does.
##
## Also here: the engine's hum (a loop whose pitch follows the speed), the
## klaxon of a red alert, the radar's ping, and the little clicks and beeps
## of the console and its switches.

const RATE := 32000
const VOICES := 10

var _sounds := {}
var _voices: Array[AudioStreamPlayer] = []
var _engine: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1982
	_sounds = {
		"laser": _laser(), "enemy_fire": _enemy_fire(), "missile": _missile_launch(),
		"hit_light": _hit(0.22, 900.0, 0.55), "hit_medium": _hit(0.34, 520.0, 0.8), "hit_heavy": _hit(0.5, 300.0, 1.0),
		"explosion": _explosion(2.2, 1.0), "small_explosion": _explosion(0.9, 0.55), "destruction": _explosion(4.0, 1.2),
		"jump": _jump(), "tick": _click(2400.0, 0.03, 0.5), "key": _click(1800.0, 0.025, 0.35),
		"select": _beep(880.0, 1320.0, 0.09, 0.4), "refuse": _beep(220.0, 160.0, 0.18, 0.4),
		"switch": _switch(), "ping": _ping(), "alarm": _alarm(), "capture": _beep(660.0, 990.0, 0.16, 0.35),
	}
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_voices.append(player)
	_engine = AudioStreamPlayer.new()
	_engine.stream = _engine_loop()
	_engine.volume_db = -14.0
	add_child(_engine)


# --- the cues -------------------------------------------------------------------


func play_laser() -> void: _play("laser", -4.0)
func play_enemy_fire() -> void: _play("enemy_fire", -6.0)
func play_missile() -> void: _play("missile", -3.0)
## GOSUB 4110: the light damage flashes, a fighter's strafing hit and the turrets' answer.
## @witness STARSHIP SIMULATOR 4110
## @witness-asm 37494
func play_hit_light() -> void: _play("hit_light", -4.0)
## GOSUB 4120: the heavier incoming-damage flash.
## @witness STARSHIP SIMULATOR 4120
func play_hit_medium() -> void: _play("hit_medium", -2.0)
## GOSUB 4100: the missile's miss and hit.
## @witness STARSHIP SIMULATOR 4100
func play_hit_heavy() -> void: _play("hit_heavy", -1.0)
## EX.bas: the defender destroyed.
## @witness STARSHIP SIMULATOR 1205
func play_explosion() -> void: _play("explosion", 0.0)
func play_small_explosion() -> void: _play("small_explosion", -3.0)
## S_X.bas: the ship's own destruction.
func play_destruction() -> void: _play("destruction", 0.0)
## H_D.bas line 18: the hyperdrive winding up.
func play_jump() -> void: _play("jump", -2.0)
## H_D.bas line 20 and a ground battle's rounds.
func play_tick() -> void: _play("tick", -8.0)
func play_key() -> void: _play("key", -10.0)
func play_select() -> void: _play("select", -8.0)
func play_refuse() -> void: _play("refuse", -8.0)
func play_switch() -> void: _play("switch", -4.0)
func play_ping() -> void: _play("ping", -8.0)
func play_alarm() -> void: _play("alarm", -5.0)
func play_capture() -> void: _play("capture", -8.0)


## The engine's hum, at `speed` (0 to 120): low and slow at rest, higher and
## louder as the ship goes faster. Called every frame of the flight.
func engine(speed: float) -> void:
	if not _engine.playing:
		_engine.play()
	var t := clampf(speed / 120.0, 0.0, 1.0)
	_engine.pitch_scale = lerpf(0.7, 1.7, t)
	_engine.volume_db = lerpf(-30.0, -13.0, t)


func engine_off() -> void:
	_engine.stop()


func _play(sound: String, volume_db := 0.0) -> void:
	var stream: AudioStreamWAV = _sounds[sound]
	for voice in _voices:
		if not voice.playing:
			_start(voice, stream, volume_db)
			return
	_start(_voices[0], stream, volume_db) # all busy: the oldest gives way


func _start(voice: AudioStreamPlayer, stream: AudioStreamWAV, volume_db: float) -> void:
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = _rng.randf_range(0.97, 1.03) # no two alike
	voice.play()


# --- making them -----------------------------------------------------------------
# Buffers of floats, 32000 a second, mixed and shaped here, then turned into a WAV.


func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


## An envelope: a short rise and an exponential fall.
func _env(i: int, total: int, attack: float, decay: float) -> float:
	var t := float(i) / RATE
	var rise := minf(t / maxf(attack, 0.0001), 1.0)
	return rise * exp(-t / maxf(decay, 0.0001)) * (1.0 - float(i) / total * 0.1)


## Noise through a one-pole low-pass (`cutoff` in Hz).
func _noise(samples: PackedFloat32Array, cutoff: float, gain: float, decay: float, attack := 0.002, start := 0) -> void:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in range(start, samples.size()):
		y += a * (_rng.randf_range(-1.0, 1.0) - y)
		samples[i] += y * gain * _env(i - start, samples.size() - start, attack, decay) * 2.0


## A tone sweeping from `from` to `to` Hz; a square-ish wave if `edge` > 0.
func _sweep(samples: PackedFloat32Array, from: float, to: float, gain: float, decay: float, edge := 0.0, start := 0) -> void:
	var phase := 0.0
	var n := samples.size() - start
	for i in range(start, samples.size()):
		var u := float(i - start) / n
		phase += lerpf(from, to, u) / RATE
		var wave := sin(TAU * phase)
		if edge > 0.0:
			wave = lerpf(wave, signf(wave), edge)
		samples[i] += wave * gain * _env(i - start, n, 0.003, decay)


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	var norm := 0.92 / maxf(peak, 0.0001)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * norm, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav


func _laser() -> AudioStreamWAV:
	var s := _buffer(0.32)
	_sweep(s, 2600.0, 380.0, 0.6, 0.12, 0.35)
	_sweep(s, 5200.0, 760.0, 0.18, 0.06)
	_noise(s, 6000.0, 0.12, 0.03)
	return _wav(s)


func _enemy_fire() -> AudioStreamWAV:
	var s := _buffer(0.28)
	_sweep(s, 900.0, 230.0, 0.6, 0.1, 0.5)
	_noise(s, 2400.0, 0.2, 0.05)
	return _wav(s)


func _missile_launch() -> AudioStreamWAV:
	var s := _buffer(1.1)
	# a thump, then a rush that climbs as the rocket gathers speed
	_sweep(s, 120.0, 45.0, 0.7, 0.12)
	var a := 1.0 - exp(-TAU * 600.0 / RATE)
	var y := 0.0
	for i in s.size():
		var u := float(i) / s.size()
		var cutoff := lerpf(300.0, 3200.0, u)
		a = 1.0 - exp(-TAU * cutoff / RATE)
		y += a * (_rng.randf_range(-1.0, 1.0) - y)
		s[i] += y * sin(PI * u) * 1.4
	return _wav(s)


func _hit(seconds: float, ring: float, weight: float) -> AudioStreamWAV:
	var s := _buffer(seconds)
	_sweep(s, 160.0 * weight + 60.0, 50.0, 0.8 * weight, 0.08)
	_noise(s, 3000.0, 0.5, 0.06)
	_sweep(s, ring, ring * 0.92, 0.2, 0.1)
	return _wav(s)


func _explosion(seconds: float, size: float) -> AudioStreamWAV:
	var s := _buffer(seconds)
	_noise(s, 5000.0, 0.7, 0.05 * size) # the crack
	_noise(s, 900.0 * size, 1.0, 0.45 * size, 0.01) # the body
	_noise(s, 220.0, 1.2 * size, 0.9 * size, 0.05) # the rumble
	_sweep(s, 70.0, 28.0, 0.9 * size, 0.7 * size)
	return _wav(s)


func _jump() -> AudioStreamWAV:
	var s := _buffer(2.2)
	var y := 0.0
	for i in s.size():
		var u := float(i) / s.size()
		var a := 1.0 - exp(-TAU * lerpf(200.0, 5500.0, u * u) / RATE)
		y += a * (_rng.randf_range(-1.0, 1.0) - y)
		s[i] += y * (0.3 + u) * 1.5 * (1.0 - pow(u, 8.0))
	_sweep(s, 80.0, 1400.0, 0.5, 5.0, 0.0)
	return _wav(s)


func _click(freq: float, seconds: float, gain: float) -> AudioStreamWAV:
	var s := _buffer(seconds)
	_noise(s, 7000.0, gain, 0.004, 0.0005)
	_sweep(s, freq, freq * 0.7, gain, 0.008)
	return _wav(s)


func _beep(from: float, to: float, seconds: float, gain: float) -> AudioStreamWAV:
	var s := _buffer(seconds)
	_sweep(s, from, to, gain, seconds * 0.7)
	_sweep(s, from * 2.0, to * 2.0, gain * 0.25, seconds * 0.5)
	return _wav(s)


func _switch() -> AudioStreamWAV:
	var s := _buffer(0.16)
	_sweep(s, 180.0, 90.0, 0.8, 0.03)
	_noise(s, 4500.0, 0.8, 0.01, 0.0005)
	_noise(s, 3000.0, 0.5, 0.01, 0.0005, int(0.07 * RATE)) # the click back
	return _wav(s)


func _ping() -> AudioStreamWAV:
	var s := _buffer(0.9)
	_sweep(s, 1500.0, 1450.0, 0.7, 0.28)
	_sweep(s, 3000.0, 2900.0, 0.15, 0.18)
	return _wav(s)


func _alarm() -> AudioStreamWAV:
	var s := _buffer(1.3)
	for pulse in 4:
		var start := int(pulse * 0.32 * RATE)
		var part := _buffer(0.28)
		_sweep(part, 740.0 if pulse % 2 == 0 else 560.0, 740.0 if pulse % 2 == 0 else 560.0, 0.5, 0.5, 0.6)
		for i in part.size():
			if start + i < s.size():
				s[start + i] += part[i] * minf(float(i) / 400.0, 1.0) * (1.0 - float(i) / part.size())
	return _wav(s)


## A hum for a loop: a low tone, its octave, and a breath of noise, whole
## cycles long so that the joint cannot be heard.
func _engine_loop() -> AudioStreamWAV:
	var seconds := 1.0
	var s := _buffer(seconds)
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		y += 0.04 * (_rng.randf_range(-1.0, 1.0) - y)
		s[i] = sin(TAU * 55.0 * t) * 0.55 + sin(TAU * 110.0 * t) * 0.25 + sin(TAU * 165.0 * t) * 0.1 + y * 0.35
	return _wav(s, true)
