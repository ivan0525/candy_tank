extends Node

var _shots: Dictionary = {}
var _bgm: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name in [
		"shoot", "shoot_super", "hit_brick", "hit_steel", "explode",
		"powerup", "bonus", "gameover", "stage", "life", "pause", "ice"
	]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/%s.wav" % name)
		p.bus = "Master"
		add_child(p)
		_shots[name] = p
	_bgm = AudioStreamPlayer.new()
	var bgm_stream := load("res://assets/sfx/bgm.wav")
	if bgm_stream is AudioStreamWAV:
		var wav := (bgm_stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		if wav.mix_rate > 0:
			wav.loop_end = int(wav.data.size() / 2)
		bgm_stream = wav
	_bgm.stream = bgm_stream
	_bgm.volume_db = -8.0
	_bgm.bus = "Master"
	add_child(_bgm)


func play(name: String) -> void:
	if _shots.has(name):
		var p: AudioStreamPlayer = _shots[name]
		p.pitch_scale = randf_range(0.94, 1.06)
		p.play()


func play_bgm() -> void:
	if not _bgm.playing:
		_bgm.play()


func stop_bgm() -> void:
	_bgm.stop()
