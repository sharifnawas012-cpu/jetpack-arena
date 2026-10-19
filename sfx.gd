extends Node
## Procedurally generated placeholder sound effects (no audio files needed).

const RATE := 22050
var snd: Dictionary = {}
var players: Array = []
var idx := 0

func _ready() -> void:
	snd["shot"] = _make(900.0, 0.07, 0.55, 45.0)
	snd["heavy"] = _make(220.0, 0.16, 0.55, 16.0)
	snd["boom"] = _make(70.0, 0.7, 0.9, 4.5)
	snd["hit"] = _make(420.0, 0.05, 0.35, 60.0)
	snd["flame"] = _make(300.0, 0.08, 0.95, 28.0)
	snd["die"] = _make(160.0, 0.35, 0.4, 7.0)
	snd["pick"] = _make(1200.0, 0.1, 0.0, 20.0)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func _make(freq: float, dur: float, noise: float, decay: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay)
		var s := sin(TAU * freq * t * (1.0 - t * 0.6)) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func play(nm: String, pos: Vector2 = Vector2.INF) -> void:
	var vol: float = Cfg.prefs.volume
	if vol <= 0.01 or not snd.has(nm):
		return
	var atten := 0.0
	if pos != Vector2.INF and Net.game != null and Net.game.get("cam") != null:
		var d: float = pos.distance_to(Net.game.cam.global_position)
		if d > 1500.0:
			return
		atten = -d / 180.0
	var p: AudioStreamPlayer = players[idx]
	idx = (idx + 1) % players.size()
	p.stream = snd[nm]
	p.volume_db = linear_to_db(vol) + atten
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()
