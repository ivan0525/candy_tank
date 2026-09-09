class_name Constants
extends Object

const TILE := 16
const MAP_W := 26
const MAP_H := 26
const BATTLE_SIZE := TILE * MAP_W  # 416
const HUD_W := 160

const CELL_EMPTY := 0
const CELL_BRICK := 1
const CELL_STEEL := 2
const CELL_WATER := 3
const CELL_BUSH := 4
const CELL_ICE := 5
const CELL_BASE := 6

const DIR_UP := 0
const DIR_RIGHT := 1
const DIR_DOWN := 2
const DIR_LEFT := 3

const DIRS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

const PLAYER_SPAWN := Vector2i(9, 24)
const PLAYER2_SPAWN := Vector2i(15, 24)
const BASE_CELL := Vector2i(12, 24)
const ENEMY_SPAWNS := [Vector2i(0, 0), Vector2i(12, 0), Vector2i(24, 0)]

const LAYER_WORLD := 1
const LAYER_BULLET := 2
const LAYER_TANK := 4
const LAYER_POWER := 8
