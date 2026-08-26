class_name EffectRules
extends RefCounted

const ID = EffectId.Id
const TYPE = BattleTileData.TerrainType

# which effects each effect instantly neutralizes on contact
const NEUTRALIZE_MAP: Dictionary = {
	ID.SOAKED: [ID.BURNING],
	ID.FROZEN: [ID.BURNING, ID.ELECTRIFIED],
}

# which terrain types each effect can spread/apply to
const SUSCEPTIBLE_TERRAIN: Dictionary = {
	ID.BURNING: [
		TYPE.WOOD,
		TYPE.DRY_GRASS,
	],
	ID.ELECTRIFIED: [
		TYPE.METAL,
		TYPE.WATER
	],
	ID.ELECTRIFIED_CONDUCTED: [
		TYPE.METAL,
		TYPE.WATER
	],
	ID.FROZEN: [
		TYPE.NORMAL,
		TYPE.WOOD,
		TYPE.METAL,
		TYPE.STONE,
		TYPE.GRASS,
		TYPE.DRY_GRASS,
		TYPE.ASH,
		TYPE.WATER,
		TYPE.SAND,
		TYPE.PLAGUE,
	]
}

const DEFAULT_DURATION: Dictionary = {
	ID.BURNING: 3,
	ID.REDHOT: 2,
	ID.ELECTRIFIED: 2,
	ID.ELECTRIFIED_CONDUCTED: 2,
	ID.SOAKED: 2,
}

# how many ticks an effect must remain active before triggering its threshold consequence
# (e.g. burning converts contiguous stone to lava after 3 ticks)
const DURATION_THRESHOLD_TICKS: Dictionary = {
	ID.BURNING: 3,
	ID.SOAKED: 2,
	ID.REDHOT: 2,
	ID.FROZEN: 3,
}

const LIQUID_TERRAIN: Array[BattleTileData.TerrainType] = [
	TYPE.WATER,
	# add ACID_POOL etc. here as they're implemented
]
