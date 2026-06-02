class_name BattleTileData
extends Resource

enum TerrainType {
	NORMAL = 0,
	WATER = 1,
	FIRE = 2,
	LAVA = 3,
	ICE = 4,
	SAND = 5,
	ROCK = 6
}

@export var terrain_type: TerrainType = TerrainType.NORMAL
@export var elevation: int = 0
@export var is_walkable: bool = true

# Runtime only — not exported, not saved
var unit_ref = null        # will hold a UnitData reference later
var interactive_ref = null
