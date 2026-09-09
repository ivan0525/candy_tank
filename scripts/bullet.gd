class_name Bullet
extends Area2D

const TILE := 16

var owner_tank: Tank
var dir: int = 0
var speed: float = 180.0
var super_shot: bool = false
var from_player: bool = false
var alive: bool = true
var world: Node = null

var _sprite: Sprite2D


func setup(tank: Tank, p_dir: int, p_speed: float, origin: Vector2, p_super: bool, p_from_player: bool) -> void:
	owner_tank = tank
	dir = p_dir
	speed = p_speed
	super_shot = p_super
	from_player = p_from_player
	global_position = origin
	z_index = 10
	collision_layer = Constants.LAYER_BULLET
	collision_mask = 0
	monitoring = false
	monitorable = false

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(6, 6)
	col.shape = shape
	add_child(col)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if from_player:
		_sprite.texture = load("res://assets/sprites/bullet_super.png" if super_shot else "res://assets/sprites/bullet_player.png")
	else:
		_sprite.texture = load("res://assets/sprites/bullet_enemy.png")
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var v := Vector2(Constants.DIRS[dir]) * speed
	global_position += v * delta
	if world:
		world.on_bullet_moved(self)


func kill() -> void:
	if not alive:
		return
	alive = false
	queue_free()
