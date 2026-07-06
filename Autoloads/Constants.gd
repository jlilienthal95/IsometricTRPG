extends Node

const TILE_ORIGIN_OFFSET: int = 16
const UNIT_EFFECT_OFFSET: int = TILE_ORIGIN_OFFSET + 10
const FADE_OUT_TIMER: float = 0.35
const ACTION_BUTTON_X = 335
const ACTION_BUTTON_Y = 60
const BASE_DAMAGE_UNIT: float = 10.0
const UNIT_ALPHA_FADE: float = 0.6

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
