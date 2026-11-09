extends Node
## Procedural sound effects. Every real sound cue in the original game
## reduces to exactly two machine-code routines, confirmed by reading
## their disassembly (`disassembly/LASER.disasm.txt` and
## `disassembly/SOUND GEN.disasm.txt`) rather than guessing:
##
## - **LASER** ($92D1-$92E6): a tight nested loop — 14 outer
##   repetitions, each toggling the speaker ($C030) 140 times with a
##   delay that grows every toggle (`CPX #$8C`, X climbing 0→140 as the
##   per-toggle busy-wait). A growing delay between toggles means a
##   falling toggle rate, i.e. falling pitch — so each of the 14 reps
##   is a quick descending chirp, back-to-back: the classic "pew"
##   laser-zap shape. Used for every laser-fire visual in the game
##   (`CALL LA`, `STARSHIP SIMULATOR.bas` line 1505).
## - **SOUND GEN** ($9276-$92BF, aliased as `SG`/`NOISE`/`EX` under
##   different BASIC variable names — all the same routine, confirmed
##   by address: `NOISE=37494` and `EX=37494` both resolve to $9276):
##   a 16-bit shift register (`ROL $9270`/`ROL $9271`) toggling the
##   speaker in a pseudo-random pattern, wrapped in a nested duration
##   loop (`$9272`/`$9273`, set via `POKE 37490/37491` before most
##   calls) — a noise burst, not a tone. Used for every hit, miss,
##   retreat-flicker, and explosion sound in the game. The three
##   distinct parameter presets this port found cited in
##   `STARSHIP SIMULATOR.bas` (subroutines 4100/4110/4120, inner×outer
##   loop counts 10×10 / 5×5 / 7×7) become NOISE_HEAVY/LIGHT/MEDIUM
##   below. `EX.bas` (75 calls) and `S_X.bas` (500 calls) call the
##   routine directly, with whatever $9272-9275 parameters happened to
##   be left over from whatever ran before — genuinely unknowable, not
##   just unported — so their much longer call counts are what this
##   port actually reproduces (as NOISE_EXPLOSION/NOISE_DESTRUCTION,
##   scaled proportionally from the 4100 preset's per-call duration),
##   not a specific leftover parameter state.
##
## None of this is cycle-exact (that would need emulating real 6502
## timing against the speaker toggle, not just the routine's shape) —
## each sound is synthesized from the real algorithm's shape (chirp vs.
## noise, relative durations) rather than reproduced bit-for-bit, same
## "faithful shape, feel-tuned constants" approach this port already
## uses for non-byte-exact timing elsewhere (e.g. flight_combat.gd's
## TICK_INTERVAL).

const SAMPLE_RATE := 22050
const POLYPHONY := 6

var _laser: AudioStreamWAV
var _noise_light: AudioStreamWAV
var _noise_medium: AudioStreamWAV
var _noise_heavy: AudioStreamWAV
var _noise_explosion: AudioStreamWAV
var _noise_destruction: AudioStreamWAV

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_laser = _build_laser()
	# Durations scale with the real relative "size" of each site (GOSUB
	# 4110/4120/4100's 5x5/7x7/10x10 inner x outer loop counts, and
	# EX.bas/S_X.bas's 75/500 direct call counts) but are picked
	# directly rather than literally multiplied out — a literal
	# steps x per-call-duration product would run the explosion sounds
	# into double digits of seconds, nowhere near a real speaker burst's
	# actual length. Step duration (noise coarseness/pitch) stays
	# roughly constant across all five; only the overall duration grows.
	_noise_light = _build_noise(0.10, 0.004)
	_noise_medium = _build_noise(0.18, 0.004)
	_noise_heavy = _build_noise(0.35, 0.004)
	_noise_explosion = _build_noise(0.7, 0.004)
	_noise_destruction = _build_noise(1.6, 0.0035)

	for i in range(POLYPHONY):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play_laser() -> void:
	_play(_laser)


## GOSUB 4110 preset — the lighter of the two ambient incoming-damage
## "hit" flashes (STARSHIP SIMULATOR.bas line 3019), also the
## incoming-fire pattern's own tracer-fire moment (line 5098, same
## preset).
func play_hit_light() -> void:
	_play(_noise_light)


## GOSUB 4120 preset — the heavier ambient incoming-damage flash
## (line 3032), and the bare `CALL SG` sites with no preceding GOSUB
## (the fighter-approach step tick and retreat/explosion flourishes,
## which reuse whatever preset was last set — this port just picks
## MEDIUM for all of those rather than tracking real leftover state).
func play_hit_medium() -> void:
	_play(_noise_medium)


## GOSUB 4100 preset, standalone (not currently a direct call site on
## its own, but kept as the base unit the two explosion sounds below
## scale up from).
func play_hit_heavy() -> void:
	_play(_noise_heavy)


## EX.bas's 75-call burst — the orbital defender's destruction.
func play_explosion() -> void:
	_play(_noise_explosion)


## S_X.bas's 500-call burst — the player's OWN ship destroyed.
func play_destruction() -> void:
	_play(_noise_destruction)


func _play(stream: AudioStreamWAV) -> void:
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_players[0].stream = stream
	_players[0].play()


## LASER.disasm.txt's shape: 14 back-to-back descending chirps.
func _build_laser() -> AudioStreamWAV:
	const REPS := 14
	const REP_DURATION := 0.018 # seconds — tuned, see doc comment above
	const FREQ_START := 2600.0
	const FREQ_END := 350.0

	var rep_samples := int(REP_DURATION * SAMPLE_RATE)
	var total_samples := rep_samples * REPS
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var phase := 0.0
	for i in range(total_samples):
		var within := float(i % rep_samples) / float(rep_samples)
		var freq: float = lerpf(FREQ_START, FREQ_END, within)
		phase += freq / SAMPLE_RATE
		if phase >= 1.0:
			phase -= 1.0
		var value := 1.0 if phase < 0.5 else -1.0
		var decay := 1.0 - (float(i) / float(total_samples)) * 0.4
		samples[i] = value * decay

	return _to_wav(samples)


## SOUND GEN.disasm.txt's shape: an LFSR-driven pseudo-random speaker
## toggle, wrapped in a nested duration loop. `duration` is this
## sound's overall length (see `_ready()`'s doc comment for how the
## five presets' durations were picked); `step_seconds` is how long
## each LFSR step lasts — the noise's coarseness/pitch, tuned for an
## audible crackle rather than cycle-exact timing.
func _build_noise(duration: float, step_seconds: float) -> AudioStreamWAV:
	var total_samples := maxi(int(duration * SAMPLE_RATE), 1)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var lfsr := 0xACE1
	var samples_per_step := maxi(int(step_seconds * SAMPLE_RATE), 1)
	var value := 1.0
	var since_step := 0
	for i in range(total_samples):
		if since_step >= samples_per_step:
			since_step = 0
			var bit := ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1
			lfsr = (lfsr >> 1) | (bit << 15)
			value = 1.0 if (lfsr & 1) == 1 else -1.0
		since_step += 1
		var decay := 1.0 - (float(i) / float(total_samples))
		samples[i] = value * decay

	return _to_wav(samples)


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := clampf(samples[i], -1.0, 1.0)
		var s16 := int(v * 32000.0)
		data.encode_s16(i * 2, s16)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	return wav
