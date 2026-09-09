class_name PowerUp
extends Area2D

enum Type { HELMET, CLOCK, SHOVEL, STAR, GRENADE, LIFE }

var type: Type = Type.STAR
var world: Node = null
var bob: float = 0.0
var life: float = 16.0

var _sprite: Sprite2D


func setup(p_type: Type, pos: Vector2) -> void:
	type = p_type
	global_position = pos
	z_index = 12
	collision_layer = Constants.LAYER_POWER
	collision_mask = 0
	monitoring = false

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	col.shape = shape
	add_child(col)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var names := ["helmet", "clock", "shovel", "star", "grenade", "life"]
	_sprite.texture = load("res://assets/sprites/power_%s.png" % names[type])
	add_child(_sprite)


func _process(delta: float) -> void:
	bob += delta * 6.0
	if _sprite:
		_sprite.position.y = sin(bob) * 2.0
		var blink := int(Time.get_ticks_msec() / 160) % 2 == 0
		_sprite.visible = blink or life > 5.0
		if life < 4.0:
			_sprite.modulate.a = 0.4 if int(life * 8.0) % 2 == 0 else 1.0
	life -= delta
	if life <= 0.0:
		queue_free()
