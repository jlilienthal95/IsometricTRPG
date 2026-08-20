extends Node

var testing_mode: bool = false

const TILE_ORIGIN_OFFSET: int = 16
const TILE_WORLD_SIZE: float = 32.0  # world-space distance of one flat tile step
const MAX_ELEVATION: int = 14
const UNIT_EFFECT_OFFSET: int = TILE_ORIGIN_OFFSET + 10
const FADE_TIMER: float = 0.2
const ACTION_BUTTON_X = 24
const ACTION_BUTTON_Y = 16
const BASE_DAMAGE_UNIT: float = 10.0
const UNIT_ALPHA_FADE: float = 0.6

#Unit Stat Constants
const UNIT_BASE_HP: int = 50
const UNIT_BASE_MP: int = 15
const UNIT_BASE_ATTACK: int = 10
const UNIT_BASE_DEFENSE: int = 10
const UNIT_BASE_MOVE_RANGE: int = 3
const UNIT_BASE_JUMP_HEIGHT: int = 2

const BASE_EXP_PER_LEVEL: int = 100
const BASE_XP_REQ_MOD: float = 1.5

#Battle Constants
const BASE_CRIT_CHANCE: float = 0.05
const CRIT_MULTIPLIER: float = 2.0
const POWER_VARIANCE: float = 0.2

#const ARROW_TRAVEL_DISTANCE: int = 50

# one elevation step is equivalent to this many flat grid steps for distance estimation.
# derived from elevation neighbor offset formula: one z level shifts x and y by 1 each.
const ELEVATION_DISTANCE_MULTIPLIER: int = 2

static func level_from_xp(current_exp: int) -> int:
	return floori(pow((current_exp / BASE_EXP_PER_LEVEL), 1.0 / BASE_XP_REQ_MOD))

# returns the 4 elevation-shifted neighbor cells exactly n levels above the given cell
static func get_elevation_neighbors_up(cell: Vector3i, n: int = 1) -> Array[Vector3i]:
	return [
		Vector3i(cell.x - (n + 1), cell.y - n, cell.z + n),	# front
		Vector3i(cell.x - (n - 1), cell.y - n, cell.z + n),	# behind
		Vector3i(cell.x - n, cell.y - (n + 1), cell.z + n),	# left
		Vector3i(cell.x - n, cell.y - (n - 1), cell.z + n),	# right
	]

# returns the 4 elevation-shifted neighbor cells exactly n levels below the given cell
static func get_elevation_neighbors_down(cell: Vector3i, n: int = 1) -> Array[Vector3i]:
	return [
		Vector3i(cell.x + (n + 1), cell.y + n, cell.z - n),	# front
		Vector3i(cell.x + (n - 1), cell.y + n, cell.z - n),	# behind
		Vector3i(cell.x + n, cell.y + (n + 1), cell.z - n),	# left
		Vector3i(cell.x + n, cell.y + (n - 1), cell.z - n),	# right
	]
