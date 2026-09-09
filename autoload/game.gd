extends Node

const MAX_STAGE := 6
const START_LIVES := 3
const ENEMIES_PER_STAGE := 20
const MAX_ENEMIES_ON_FIELD := 4

var score: int = 0
var high_score: int = 0
var lives: int = START_LIVES
var stage: int = 1
var player_level: int = 1
var paused: bool = false
var stage_kills: Array[int] = [0, 0, 0, 0]

signal score_changed(value: int)
signal lives_changed(value: int)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_high_score()
	randomize()


func new_game() -> void:
	score = 0
	lives = START_LIVES
	stage = 1
	player_level = 1
	paused = false
	reset_stage_kills()
	score_changed.emit(score)
	lives_changed.emit(lives)


func reset_stage_kills() -> void:
	stage_kills = [0, 0, 0, 0]


func record_kill(type_index: int) -> void:
	if type_index >= 0 and type_index < stage_kills.size():
		stage_kills[type_index] += 1


func add_score(amount: int) -> void:
	score += amount
	if score > high_score:
		high_score = score
		_save_high_score()
	score_changed.emit(score)


func add_life() -> void:
	lives += 1
	lives_changed.emit(lives)
	Sfx.play("life")


func lose_life() -> bool:
	lives -= 1
	player_level = 1
	lives_changed.emit(lives)
	return lives <= 0


func next_stage() -> bool:
	stage += 1
	reset_stage_kills()
	return stage <= MAX_STAGE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		var scn := get_tree().current_scene
		if scn and scn.has_method("toggle_pause"):
			scn.toggle_pause()


func _setup_input() -> void:
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("fire", [KEY_SPACE, KEY_J, KEY_Z, KEY_K])
	_bind("pause_game", [KEY_P, KEY_ESCAPE])
	_bind("confirm", [KEY_ENTER, KEY_SPACE])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://candy_tank.cfg") == OK:
		high_score = int(cfg.get_value("save", "high_score", 0))


func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "high_score", high_score)
	cfg.save("user://candy_tank.cfg")
