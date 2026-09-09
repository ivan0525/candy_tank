class_name Explosion
extends Node2D

var _sprite: Sprite2D
var _t: float = 0.0
var _frames: Array = []


func _ready() -> void:
	z_index = 20
	for i in range(5):
		_frames.append(load("res://assets/sprites/boom_%d.png" % i))
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = _frames[0]
	add_child(_sprite)


func _process(delta: float) -> void:
	_t += delta
	var idx := clampi(int(_t / 0.07), 0, 4)
	_sprite.texture = _frames[idx]
	if _t > 0.35:
		queue_free()
