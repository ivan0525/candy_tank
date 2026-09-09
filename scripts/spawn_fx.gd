class_name SpawnFx
extends Node2D

var _sprite: Sprite2D
var _t: float = 0.0
var _frames: Array = []


func _ready() -> void:
	z_index = 15
	for i in range(4):
		_frames.append(load("res://assets/sprites/spawn_%d.png" % i))
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _process(delta: float) -> void:
	_t += delta
	var idx := clampi(int(_t / 0.12), 0, 3)
	_sprite.texture = _frames[idx]
	if _t > 0.5:
		queue_free()
