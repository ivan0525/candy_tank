class_name Tank
extends CharacterBody2D

signal destroyed(tank: Tank)
signal fired(bullet: Bullet)

enum Kind { PLAYER, BASIC, FAST, POWER, ARMOR }

@export var kind: Kind = Kind.PLAYER
@export var is_player: bool = false

var dir: int = 0
var speed: float = 60.0
var bullet_speed: float = 180.0
var max_bullets: int = 1
var hp: int = 1
var level: int = 1
var frozen: float = 0.0
var shield_time: float = 0.0
var spawn_time: float = 0.6
var fire_cd: float = 0.0
var anim_t: float = 0.0
var moving: bool = false
var flash_t: float = 0.0
var bonus_carrier: bool = false
var alive: bool = true
var ai_timer: float = 0.0
var ai_fire_timer: float = 0.0
var slide: bool = false
var _want_dir: int = -1

var _sprite: Sprite2D
var _shield: Sprite2D
var _frames: Dictionary = {}
var world: Node = null


func setup(p_kind: Kind, p_is_player: bool, p_level: int = 1) -> void:
	kind = p_kind
	is_player = p_is_player
	level = p_level
	_apply_stats()
	_load_frames()
	_build_visual()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Constants.LAYER_TANK
	collision_mask = Constants.LAYER_WORLD | Constants.LAYER_TANK
	z_index = 8
	if is_player:
		shield_time = 3.0
	spawn_time = 0.55


func _apply_stats() -> void:
	match kind:
		Kind.PLAYER:
			speed = 80.0
			bullet_speed = 240.0 + (level - 1) * 28.0
			max_bullets = 2 if level >= 2 else 1
			hp = 1
		Kind.BASIC:
			speed = 48.0
			bullet_speed = 168.0
			max_bullets = 1
			hp = 1
		Kind.FAST:
			speed = 96.0
			bullet_speed = 188.0
			max_bullets = 1
			hp = 1
		Kind.POWER:
			speed = 56.0
			bullet_speed = 280.0
			max_bullets = 1
			hp = 1
		Kind.ARMOR:
			speed = 44.0
			bullet_speed = 168.0
			max_bullets = 1
			hp = 4


func _kind_name() -> String:
	if is_player:
		return "player"
	match kind:
		Kind.FAST:
			return "enemy_fast"
		Kind.POWER:
			return "enemy_power"
		Kind.ARMOR:
			return "enemy_armor"
		_:
			return "enemy_basic"


func _load_frames() -> void:
	var n := _kind_name()
	for dname in ["up", "right", "down", "left"]:
		_frames[dname] = [
			load("res://assets/sprites/%s_%s_0.png" % [n, dname]),
			load("res://assets/sprites/%s_%s_1.png" % [n, dname]),
		]


func _build_visual() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	col.shape = shape
	add_child(col)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	_shield = Sprite2D.new()
	_shield.texture = load("res://assets/sprites/shield_0.png")
	_shield.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shield.visible = false
	_shield.z_index = 1
	add_child(_shield)
	_frames["shield"] = [
		load("res://assets/sprites/shield_0.png"),
		load("res://assets/sprites/shield_1.png"),
	]
	_update_sprite()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if world and world.get("stage_over"):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if spawn_time > 0.0:
		spawn_time -= delta
		modulate.a = 0.45 + abs(sin(Time.get_ticks_msec() * 0.02)) * 0.55
		velocity = Vector2.ZERO
		move_and_slide()
		return
	modulate.a = 1.0

	if world and world.has_method("is_ice_at"):
		slide = world.is_ice_at(global_position)

	if flash_t > 0.0:
		flash_t -= delta
		_sprite.modulate = Color(2.2, 2.2, 2.2) if int(flash_t * 20.0) % 2 == 0 else Color.WHITE
	else:
		_sprite.modulate = _idle_modulate()

	if shield_time > 0.0:
		shield_time -= delta
		_shield.visible = true
		_shield.texture = _frames["shield"][1 if int(Time.get_ticks_msec() / 80) % 2 else 0]
	else:
		_shield.visible = false

	if fire_cd > 0.0:
		fire_cd -= delta

	if frozen > 0.0:
		frozen -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		_update_sprite()
		return

	moving = false
	if is_player:
		_player_control(delta)
	else:
		_ai_control(delta)

	if moving:
		anim_t += delta * 10.0
	_update_sprite()


func _idle_modulate() -> Color:
	if bonus_carrier and not is_player:
		var t := int(Time.get_ticks_msec() / 90) % 2
		return Color(1.7, 1.15, 1.7) if t == 0 else Color(1.15, 1.7, 1.8)
	if kind == Kind.ARMOR and not is_player:
		match hp:
			4:
				return Color.WHITE
			3:
				return Color(0.75, 1.15, 0.8)
			2:
				return Color(1.2, 1.15, 0.55)
			_:
				return Color(1.35, 0.7, 0.7)
	return Color.WHITE


func _player_control(_delta: float) -> void:
	# Newest key wins so holding Up still lets you tap Left/Right to turn.
	if Input.is_action_just_pressed("move_left"):
		_want_dir = 3
	elif Input.is_action_just_pressed("move_right"):
		_want_dir = 1
	elif Input.is_action_just_pressed("move_up"):
		_want_dir = 0
	elif Input.is_action_just_pressed("move_down"):
		_want_dir = 2

	if _want_dir >= 0 and not Input.is_action_pressed(_dir_action(_want_dir)):
		_want_dir = _held_move_dir()
	elif _want_dir < 0:
		_want_dir = _held_move_dir()

	if _want_dir >= 0:
		_try_move(_want_dir, true)
	elif slide:
		_try_move(dir, true)
	else:
		velocity = Vector2.ZERO
		move_and_slide()

	if Input.is_action_pressed("fire"):
		try_fire()


func _dir_action(d: int) -> StringName:
	return [&"move_up", &"move_right", &"move_down", &"move_left"][d]


func _held_move_dir() -> int:
	if Input.is_action_pressed(_dir_action(dir)):
		return dir
	if Input.is_action_pressed("move_up"):
		return 0
	if Input.is_action_pressed("move_down"):
		return 2
	if Input.is_action_pressed("move_left"):
		return 3
	if Input.is_action_pressed("move_right"):
		return 1
	return -1


func _ai_control(delta: float) -> void:
	ai_timer -= delta
	ai_fire_timer -= delta
	if ai_timer <= 0.0:
		_pick_ai_dir()
		ai_timer = randf_range(0.4, 1.25)
	_try_move(dir, false)
	var fire_chance := 0.7
	var fire_gap := randf_range(0.4, 1.15)
	if kind == Kind.POWER:
		fire_chance = 0.9
		fire_gap = randf_range(0.22, 0.55)
	if _has_shot_line():
		fire_chance = 1.0
		fire_gap = minf(fire_gap, 0.28)
	if ai_fire_timer <= 0.0:
		ai_fire_timer = fire_gap
		if randf() < fire_chance:
			try_fire()


func _pick_ai_dir() -> void:
	if world == null:
		dir = randi() % 4
		return
	var prefer: Array[int] = []
	var base_pos: Vector2 = world.get_base_world_pos()
	var to_base := base_pos - global_position
	if abs(to_base.x) > abs(to_base.y):
		prefer.append(1 if to_base.x > 0.0 else 3)
		prefer.append(2 if to_base.y > 0.0 else 0)
	else:
		prefer.append(2 if to_base.y > 0.0 else 0)
		prefer.append(1 if to_base.x > 0.0 else 3)
	if randf() < 0.4 and world.player and is_instance_valid(world.player) and world.player.alive:
		var to_p: Vector2 = world.player.global_position - global_position
		if abs(to_p.x) > abs(to_p.y):
			prefer.insert(0, 1 if to_p.x > 0.0 else 3)
		else:
			prefer.insert(0, 2 if to_p.y > 0.0 else 0)
	if randf() < 0.18:
		dir = randi() % 4
		return
	for d in prefer:
		if world.has_method("can_tank_advance") and world.can_tank_advance(global_position, d):
			dir = d
			return
	var order := [0, 1, 2, 3]
	order.shuffle()
	for d in order:
		if world.has_method("can_tank_advance") and world.can_tank_advance(global_position, d):
			dir = d
			return
	dir = randi() % 4


func _has_shot_line() -> bool:
	if world == null:
		return false
	var targets: Array[Vector2] = [world.get_base_world_pos()]
	if world.player and is_instance_valid(world.player) and world.player.alive:
		targets.append(world.player.global_position)
	for target in targets:
		var d: Vector2 = target - global_position
		match dir:
			0:
				if abs(d.x) <= 14.0 and d.y < -8.0:
					return true
			1:
				if abs(d.y) <= 14.0 and d.x > 8.0:
					return true
			2:
				if abs(d.x) <= 14.0 and d.y > 8.0:
					return true
			3:
				if abs(d.y) <= 14.0 and d.x < -8.0:
					return true
	return false


func _try_move(want: int, instant_turn: bool) -> void:
	if want != dir:
		if instant_turn or _aligned_for_turn(want):
			_snap_axis(want)
			dir = want
	var v := Vector2(Constants.DIRS[dir]) * speed
	if slide:
		v *= 1.25
	velocity = v
	var before := global_position
	move_and_slide()
	if global_position.distance_to(before) > 0.15:
		moving = true
	else:
		if not is_player:
			ai_timer = 0.0


func _aligned_for_turn(new_dir: int) -> bool:
	var axis := global_position.x if (new_dir == 0 or new_dir == 2) else global_position.y
	var m := fposmod(axis - 16.0, 8.0)
	return m < 3.0 or m > 5.0


func _snap_axis(new_dir: int) -> void:
	if new_dir == 0 or new_dir == 2:
		global_position.x = snapped(global_position.x - 16.0, 8.0) + 16.0
	else:
		global_position.y = snapped(global_position.y - 16.0, 8.0) + 16.0
	global_position = global_position.clamp(Vector2(16, 16), Vector2(400, 400))


func try_fire() -> bool:
	if not alive or spawn_time > 0.0 or frozen > 0.0:
		return false
	if world == null or world.get("stage_over"):
		return false
	if world.count_bullets(self) >= max_bullets:
		return false
	if fire_cd > 0.0:
		return false
	fire_cd = 0.16 if is_player else 0.22
	var b := Bullet.new()
	var origin := global_position + Vector2(Constants.DIRS[dir]) * 16.0
	var super_shot := is_player and level >= 4
	b.setup(self, dir, bullet_speed, origin, super_shot, is_player)
	world.add_bullet(b)
	fired.emit(b)
	Sfx.play("shoot_super" if super_shot else "shoot")
	return true


func hit(by_player: bool, super_shot: bool) -> bool:
	if not alive or spawn_time > 0.0:
		return false
	if shield_time > 0.0:
		return false
	if is_player and not by_player:
		_die()
		return true
	if not is_player and by_player:
		var dmg := 2 if super_shot else 1
		hp -= dmg
		flash_t = 0.18
		if hp <= 0:
			_die()
			return true
		return false
	return false


func die() -> void:
	_die()


func _die() -> void:
	if not alive:
		return
	alive = false
	destroyed.emit(self)
	queue_free()


func freeze(sec: float) -> void:
	if not is_player:
		frozen = max(frozen, sec)


func grant_shield(sec: float) -> void:
	shield_time = max(shield_time, sec)


func upgrade() -> void:
	if not is_player:
		return
	level = mini(level + 1, 4)
	Game.player_level = level
	_apply_stats()


func _update_sprite() -> void:
	var names := ["up", "right", "down", "left"]
	var frame := int(anim_t) % 2
	var tex: Texture2D = _frames[names[dir]][frame]
	if _sprite:
		_sprite.texture = tex
