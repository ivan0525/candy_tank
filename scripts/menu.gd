extends Control

var _starting := false


func _ready() -> void:
	Sfx.play_bgm()
	$HighScore.text = "最高分  %d" % Game.high_score
	$Start.pressed.connect(_on_start)
	$Start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") or event.is_action_pressed("fire"):
		_on_start()


func _on_start() -> void:
	if _starting:
		return
	_starting = true
	Game.new_game()
	Sfx.play("stage")
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
