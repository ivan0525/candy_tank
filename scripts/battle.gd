class_name Battle
extends Node2D

const TILE := 16
const MAP_W := 26
const MAP_H := 26

enum Cell { EMPTY, BRICK, STEEL, WATER, BUSH, ICE, BASE }

var cells: PackedInt32Array = PackedInt32Array()
var brick_hp: PackedInt32Array = PackedInt32Array()
var player: Tank
var enemies: Array[Tank] = []
var bullets: Array[Bullet] = []
var powerups: Array[PowerUp] = []
var enemy_queue: Array[int] = []
var remaining_to_spawn: int = 0
var spawn_cooldown: float = 1.2
var spawn_index: int = 0
var base_alive: bool = true
var shovel_time: float = 0.0
var stage_over: bool = false
var intro_t: float = 1.6
var result_t: float = 0.0
var result_kind: String = ""
var water_anim: float = 0.0
var water_cells: Array[Vector2i] = []
var spawned_enemies: int = 0
var _hud_enemy_shown: int = -1
var _water_frame: int = 4

@onready var floor_layer: TileMapLayer = $World/Floor
@onready var wall_layer: TileMapLayer = $World/Walls
@onready var overlay_layer: TileMapLayer = $World/Overlay
@onready var entities: Node2D = $World/Entities
@onready var bushes: Node2D = $World/Bushes
@onready var hud: CanvasLayer = $HUD
@onready var overlay_ui: CanvasLayer = $OverlayUI


func _ready() -> void:
	Sfx.play_bgm()
	Sfx.play("stage")
	_build_tile_sets()
	_add_bounds()
	_load_stage(Game.stage)
	_spawn_player()
	entities.process_mode = Node.PROCESS_MODE_DISABLED
	_update_hud()
	_show_intro()


func _build_tile_sets() -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load("res://assets/sprites/tileset.png")
	source.texture_region_size = Vector2i(16, 16)
	for i in range(9):
		source.create_tile(Vector2i(i, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, Constants.LAYER_WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_source(source, 0)
	for atlas in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]:
		var data := source.get_tile_data(atlas, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
		]))
	floor_layer.tile_set = ts
	wall_layer.tile_set = ts
	overlay_layer.tile_set = ts
	floor_layer.collision_enabled = false
	overlay_layer.collision_enabled = false
	wall_layer.collision_enabled = true


func _load_stage(stage: int) -> void:
	cells = Stages.get_map(stage)
	brick_hp.resize(MAP_W * MAP_H)
	enemy_queue = Stages.enemy_queue(stage)
	remaining_to_spawn = enemy_queue.size()
	spawn_cooldown = 0.4
	spawn_index = 0
	spawned_enemies = 0
	base_alive = true
	stage_over = false
	shovel_time = 0.0
	_hud_enemy_shown = -1
	_paint_map()
	_place_base_sprite()


func _idx(x: int, y: int) -> int:
	return y * MAP_W + x


func _in(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < MAP_W and y < MAP_H


func _paint_map() -> void:
	floor_layer.clear()
	wall_layer.clear()
	overlay_layer.clear()
	water_cells.clear()
	for child in bushes.get_children():
		child.queue_free()
	for y in range(MAP_H):
		for x in range(MAP_W):
			var c := cells[_idx(x, y)]
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
			match c:
				Cell.BRICK:
					wall_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 0))
					brick_hp[_idx(x, y)] = 2
				Cell.STEEL:
					wall_layer.set_cell(Vector2i(x, y), 0, Vector2i(3, 0))
				Cell.WATER:
					wall_layer.set_cell(Vector2i(x, y), 0, Vector2i(4, 0))
					water_cells.append(Vector2i(x, y))
				Cell.ICE:
					floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(7, 0))
				Cell.BUSH:
					var spr := Sprite2D.new()
					spr.texture = load("res://assets/sprites/bush.png")
					spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					spr.position = Vector2(x * TILE + 8, y * TILE + 8)
					spr.z_index = 18
					bushes.add_child(spr)
				Cell.BASE:
					pass


func _place_base_sprite() -> void:
	var old := entities.get_node_or_null("Base")
	if old:
		old.queue_free()
	var spr := Sprite2D.new()
	spr.name = "Base"
	spr.texture = load("res://assets/sprites/base.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = Vector2(13 * TILE, 25 * TILE)
	spr.z_index = 6
	entities.add_child(spr)
	var old_body := entities.get_node_or_null("BaseBody")
	if old_body:
		old_body.queue_free()
	var body := StaticBody2D.new()
	body.name = "BaseBody"
	body.collision_layer = Constants.LAYER_WORLD
	body.collision_mask = 0
	body.position = spr.position
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(28, 28)
	col.shape = sh
	body.add_child(col)
	entities.add_child(body)


func get_base_world_pos() -> Vector2:
	return Vector2(13 * TILE, 25 * TILE)


func _spawn_player() -> void:
	if player and is_instance_valid(player):
		player.queue_free()
	player = Tank.new()
	player.setup(Tank.Kind.PLAYER, true, Game.player_level)
	player.world = self
	player.global_position = Vector2(7 * TILE + 16, 24 * TILE + 16)
	player.dir = 0
	player.destroyed.connect(_on_player_dead)
	entities.add_child(player)
	_spawn_fx(player.global_position)


func _spawn_fx(pos: Vector2) -> void:
	var fx := SpawnFx.new()
	fx.position = pos
	entities.add_child(fx)


func _process(delta: float) -> void:
	_prune_lists()
	if intro_t > 0.0:
		intro_t -= delta
		if overlay_ui.get_node_or_null("Intro"):
			overlay_ui.get_node("Intro").visible = intro_t > 0.0
		if intro_t <= 0.0:
			entities.process_mode = Node.PROCESS_MODE_INHERIT
		return

	if stage_over:
		result_t -= delta
		if result_t <= 0.0:
			_finish_result()
		return

	water_anim += delta
	var frame := 4 if int(water_anim * 3.0) % 2 == 0 else 5
	if frame != _water_frame:
		_water_frame = frame
		_refresh_water(frame)

	if shovel_time > 0.0:
		shovel_time -= delta
		if shovel_time <= 0.0:
			_set_base_armor(false)

	_try_spawn_enemy(delta)
	_collect_powerups()
	_update_hud()


func _refresh_water(atlas_x: int) -> void:
	for cell in water_cells:
		if _cell_at(cell) == Cell.WATER:
			wall_layer.set_cell(cell, 0, Vector2i(atlas_x, 0))


func is_ice_at(pos: Vector2) -> bool:
	return _cell_at(_world_to_cell(pos)) == Cell.ICE


func can_tank_advance(pos: Vector2, d: int) -> bool:
	var ahead := pos + Vector2(Constants.DIRS[d]) * 18.0
	if ahead.x < 16.0 or ahead.y < 16.0 or ahead.x > 400.0 or ahead.y > 400.0:
		return false
	var kind := _cell_at(_world_to_cell(ahead))
	return kind != Cell.STEEL and kind != Cell.WATER and kind != Cell.BASE


func _try_spawn_enemy(delta: float) -> void:
	if remaining_to_spawn <= 0:
		return
	if enemies.size() >= Game.MAX_ENEMIES_ON_FIELD:
		return
	spawn_cooldown -= delta
	if spawn_cooldown > 0.0:
		return
	var spots := Constants.ENEMY_SPAWNS
	for k in range(3):
		var cell: Vector2i = spots[(spawn_index + k) % 3]
		var pos := Vector2(cell.x * TILE + 16, cell.y * TILE + 16)
		if _area_blocked(pos, 14.0):
			continue
		var kind_i := 0
		if not enemy_queue.is_empty():
			kind_i = enemy_queue.pop_front()
		var kinds := [Tank.Kind.BASIC, Tank.Kind.FAST, Tank.Kind.POWER, Tank.Kind.ARMOR]
		var tank := Tank.new()
		tank.setup(kinds[kind_i], false)
		tank.world = self
		tank.global_position = pos
		tank.dir = 2
		spawned_enemies += 1
		if spawned_enemies in [4, 11, 18]:
			tank.bonus_carrier = true
		tank.destroyed.connect(_on_enemy_dead)
		entities.add_child(tank)
		enemies.append(tank)
		_spawn_fx(pos)
		remaining_to_spawn -= 1
		spawn_index = (spawn_index + 1) % 3
		spawn_cooldown = 2.2 - Game.stage * 0.12
		break
	if spawn_cooldown <= 0.0:
		spawn_cooldown = 0.4


func _area_blocked(pos: Vector2, radius: float) -> bool:
	if player and is_instance_valid(player) and player.alive:
		if player.global_position.distance_to(pos) < radius * 2.0:
			return true
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.global_position.distance_to(pos) < radius * 2.0:
			return true
	return false


func add_bullet(b: Bullet) -> void:
	b.world = self
	entities.add_child(b)
	bullets.append(b)


func count_bullets(tank: Tank) -> int:
	var n := 0
	for b in bullets:
		if is_instance_valid(b) and b.alive and b.owner_tank == tank:
			n += 1
	return n


func on_bullet_moved(b: Bullet) -> void:
	if not b.alive:
		return
	var p := b.global_position
	if p.x < 2 or p.y < 2 or p.x > MAP_W * TILE - 2 or p.y > MAP_H * TILE - 2:
		b.kill()
		return

	if player and is_instance_valid(player) and player.alive and not b.from_player:
		var player_pos := player.global_position
		if _overlaps(p, player_pos, 12):
			if player.hit(false, b.super_shot):
				_explode(player_pos)
			else:
				Sfx.play("hit_steel")
			b.kill()
			return
	for e in enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		if b.from_player and _overlaps(p, e.global_position, 12):
			var enemy_pos := e.global_position
			var was_bonus := e.bonus_carrier
			var dead := e.hit(true, b.super_shot)
			if was_bonus:
				e.bonus_carrier = false
				_drop_powerup(enemy_pos)
			if dead:
				_explode(enemy_pos)
			else:
				Sfx.play("hit_steel")
			b.kill()
			return

	for other in bullets:
		if other == b or not is_instance_valid(other) or not other.alive:
			continue
		if other.from_player == b.from_player:
			continue
		if _overlaps(p, other.global_position, 6):
			b.kill()
			other.kill()
			return

	var hit_cells := _bullet_cells(p, b.dir)
	var destroyed_any := false
	for cell in hit_cells:
		var kind := _cell_at(cell)
		if kind == Cell.EMPTY or kind == Cell.BUSH or kind == Cell.ICE or kind == Cell.WATER:
			continue
		if kind == Cell.BASE:
			_kill_base()
			b.kill()
			return
		if kind == Cell.STEEL:
			if b.super_shot:
				_clear_cell(cell)
				destroyed_any = true
			else:
				Sfx.play("hit_steel")
				b.kill()
				return
		elif kind == Cell.BRICK:
			_damage_brick(cell, b.super_shot)
			destroyed_any = true
	if destroyed_any:
		Sfx.play("hit_brick")
		b.kill()


func _bullet_cells(p: Vector2, dir: int) -> Array[Vector2i]:
	var c := _world_to_cell(p)
	var out: Array[Vector2i] = [c]
	if dir == 0 or dir == 2:
		var side := 1 if fposmod(p.x, 16.0) >= 8.0 else -1
		out.append(Vector2i(c.x + side, c.y))
	else:
		var side := 1 if fposmod(p.y, 16.0) >= 8.0 else -1
		out.append(Vector2i(c.x, c.y + side))
	var uniq: Array[Vector2i] = []
	for v in out:
		if _in(v.x, v.y) and v not in uniq:
			uniq.append(v)
	return uniq


func _damage_brick(cell: Vector2i, super_shot: bool) -> void:
	var i := _idx(cell.x, cell.y)
	brick_hp[i] -= 2 if super_shot else 1
	if brick_hp[i] <= 0:
		_clear_cell(cell)
	else:
		wall_layer.set_cell(cell, 0, Vector2i(2, 0))


func _clear_cell(cell: Vector2i) -> void:
	if not _in(cell.x, cell.y):
		return
	cells[_idx(cell.x, cell.y)] = Cell.EMPTY
	wall_layer.erase_cell(cell)
	brick_hp[_idx(cell.x, cell.y)] = 0


func _cell_at(cell: Vector2i) -> int:
	if not _in(cell.x, cell.y):
		return Cell.STEEL
	return cells[_idx(cell.x, cell.y)]


func _world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / TILE), 0, MAP_W - 1), clampi(int(p.y / TILE), 0, MAP_H - 1))


func _overlaps(a: Vector2, b: Vector2, r: float) -> bool:
	return abs(a.x - b.x) < r and abs(a.y - b.y) < r


func _explode(pos: Vector2) -> void:
	var fx := Explosion.new()
	fx.position = pos
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	entities.add_child(fx)
	Sfx.play("explode")


func _on_player_dead(_t: Tank) -> void:
	player = null
	if Game.lose_life():
		_end_stage("lose")
	else:
		await get_tree().create_timer(1.1).timeout
		if is_inside_tree() and not stage_over:
			_spawn_player()


func _on_enemy_dead(t: Tank) -> void:
	var scores := [100, 200, 300, 400]
	var k := 0
	match t.kind:
		Tank.Kind.FAST:
			k = 1
		Tank.Kind.POWER:
			k = 2
		Tank.Kind.ARMOR:
			k = 3
		_:
			k = 0
	Game.add_score(scores[k])
	Game.record_kill(k)
	enemies.erase(t)
	if remaining_to_spawn <= 0 and enemies.is_empty():
		_end_stage("clear")


func _drop_powerup(around: Vector2) -> void:
	var types := [
		PowerUp.Type.HELMET, PowerUp.Type.CLOCK, PowerUp.Type.SHOVEL,
		PowerUp.Type.STAR, PowerUp.Type.GRENADE, PowerUp.Type.LIFE
	]
	var pu := PowerUp.new()
	var pos := Vector2.ZERO
	for _i in range(12):
		var cand := Vector2(randi_range(2, 23) * TILE + 8, randi_range(2, 20) * TILE + 8)
		var kind := _cell_at(_world_to_cell(cand))
		if kind != Cell.STEEL and kind != Cell.WATER and kind != Cell.BASE:
			pos = cand
			break
	if pos == Vector2.ZERO:
		pos = around if around != Vector2.ZERO else Vector2(208, 208)
	pu.setup(types[randi() % types.size()], pos)
	pu.world = self
	entities.add_child(pu)
	powerups.append(pu)
	Sfx.play("bonus")


func _collect_powerups() -> void:
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	for pu in powerups.duplicate():
		if not is_instance_valid(pu):
			powerups.erase(pu)
			continue
		if _overlaps(player.global_position, pu.global_position, 14):
			_apply_power(pu.type)
			powerups.erase(pu)
			pu.queue_free()


func _apply_power(t: PowerUp.Type) -> void:
	Sfx.play("powerup")
	Game.add_score(500)
	match t:
		PowerUp.Type.HELMET:
			player.grant_shield(10.0)
		PowerUp.Type.CLOCK:
			for e in enemies:
				if is_instance_valid(e):
					e.freeze(8.0)
		PowerUp.Type.SHOVEL:
			shovel_time = 12.0
			_set_base_armor(true)
		PowerUp.Type.STAR:
			player.upgrade()
		PowerUp.Type.GRENADE:
			for e in enemies.duplicate():
				if is_instance_valid(e) and e.alive:
					_explode(e.global_position)
					e.die()
		PowerUp.Type.LIFE:
			Game.add_life()


func _set_base_armor(steel: bool) -> void:
	var ring := [
		Vector2i(10, 22), Vector2i(11, 22), Vector2i(12, 22), Vector2i(13, 22), Vector2i(14, 22), Vector2i(15, 22),
		Vector2i(10, 23), Vector2i(11, 23), Vector2i(12, 23), Vector2i(13, 23), Vector2i(14, 23), Vector2i(15, 23),
		Vector2i(10, 24), Vector2i(11, 24), Vector2i(14, 24), Vector2i(15, 24),
		Vector2i(10, 25), Vector2i(11, 25), Vector2i(14, 25), Vector2i(15, 25),
	]
	for cell in ring:
		if steel:
			cells[_idx(cell.x, cell.y)] = Cell.STEEL
			wall_layer.set_cell(cell, 0, Vector2i(3, 0))
		else:
			cells[_idx(cell.x, cell.y)] = Cell.BRICK
			wall_layer.set_cell(cell, 0, Vector2i(1, 0))
			brick_hp[_idx(cell.x, cell.y)] = 2


func _kill_base() -> void:
	if not base_alive:
		return
	base_alive = false
	var spr := entities.get_node_or_null("Base")
	if spr:
		spr.texture = load("res://assets/sprites/base_dead.png")
	_explode(get_base_world_pos())
	_end_stage("lose")


func _prune_lists() -> void:
	var live_bullets: Array[Bullet] = []
	for b in bullets:
		if is_instance_valid(b) and b.alive:
			live_bullets.append(b)
	bullets = live_bullets
	var live_enemies: Array[Tank] = []
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			live_enemies.append(e)
	enemies = live_enemies
	var live_power: Array[PowerUp] = []
	for p in powerups:
		if is_instance_valid(p):
			live_power.append(p)
	powerups = live_power


func _add_bounds() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WORLD
	body.collision_mask = 0
	var rects := [
		Rect2(-16, -16, 448, 16),
		Rect2(-16, 416, 448, 16),
		Rect2(-16, 0, 16, 416),
		Rect2(416, 0, 16, 416),
	]
	for r in rects:
		var col := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		col.shape = sh
		col.position = r.position + r.size * 0.5
		body.add_child(col)
	$World.add_child(body)


func _end_stage(kind: String) -> void:
	if stage_over:
		return
	stage_over = true
	result_kind = kind
	if player and is_instance_valid(player):
		player.set_physics_process(false)
	for e in enemies:
		if is_instance_valid(e):
			e.set_physics_process(false)
	for b in bullets:
		if is_instance_valid(b):
			b.kill()
	var node := overlay_ui.get_node("Result")
	node.visible = true
	var tex_name := "stageclear"
	if kind == "lose":
		tex_name = "gameover"
		result_t = 2.6
		Sfx.play("gameover")
		Sfx.stop_bgm()
		var tally_hide: Label = overlay_ui.get_node_or_null("Tally")
		if tally_hide:
			tally_hide.visible = false
	elif Game.stage >= Game.MAX_STAGE:
		tex_name = "youwin"
		result_t = 3.4
		Sfx.play("stage")
		_show_tally()
	else:
		result_t = 3.4
		Sfx.play("stage")
		_show_tally()
	node.texture = load("res://assets/ui/%s.png" % tex_name)


func _show_tally() -> void:
	var scores := [100, 200, 300, 400]
	var names := ["饼干坦克", "薄荷快车", "柠檬炮手", "蓝莓重甲"]
	var lines: PackedStringArray = []
	for i in range(4):
		var n: int = Game.stage_kills[i]
		lines.append("%s  ×%d   %d" % [names[i], n, n * scores[i]])
	var tally: Label = overlay_ui.get_node_or_null("Tally")
	if tally:
		tally.visible = true
		tally.text = "\n".join(lines)
	_update_hud()


func _finish_result() -> void:
	get_tree().paused = false
	Game.paused = false
	if result_kind == "lose":
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if Game.next_stage():
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _show_intro() -> void:
	var intro := overlay_ui.get_node("Intro")
	intro.visible = true
	var label: Label = overlay_ui.get_node("Intro/StageNum")
	label.text = "第 %d 关" % Game.stage


func toggle_pause() -> void:
	if intro_t > 0.0 or stage_over:
		return
	Game.paused = not Game.paused
	get_tree().paused = Game.paused
	_set_pause_visible(Game.paused)
	Sfx.play("pause")


func _set_pause_visible(v: bool) -> void:
	overlay_ui.get_node("Paused").visible = v


func _update_hud() -> void:
	hud.get_node("Panel/Score").text = "%d" % Game.score
	hud.get_node("Panel/High").text = "HI %d" % Game.high_score
	hud.get_node("Panel/Lives").text = "× %d" % max(Game.lives, 0)
	hud.get_node("Panel/Stage").text = "关卡 %d" % Game.stage
	hud.get_node("Panel/Left").text = "敌方 %d" % (remaining_to_spawn + enemies.size())
	var lv := Game.player_level
	var stars := ""
	for i in range(lv):
		stars += "★"
	hud.get_node("Panel/Level").text = "火力 %s" % stars
	_draw_enemy_icons()


func _draw_enemy_icons() -> void:
	var box: GridContainer = hud.get_node("Panel/EnemyIcons")
	var need := remaining_to_spawn + enemies.size()
	if need == _hud_enemy_shown:
		return
	_hud_enemy_shown = need
	while box.get_child_count() > need:
		var child := box.get_child(box.get_child_count() - 1)
		box.remove_child(child)
		child.free()
	while box.get_child_count() < need:
		var t := TextureRect.new()
		t.texture = load("res://assets/sprites/enemy_icon.png")
		t.custom_minimum_size = Vector2(16, 16)
		t.stretch_mode = TextureRect.STRETCH_KEEP
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(t)


func _exit_tree() -> void:
	get_tree().paused = false
	Game.paused = false
