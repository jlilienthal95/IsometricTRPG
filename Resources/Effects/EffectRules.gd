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
	]
}

const DEFAULT_DURATION: Dictionary = {
	EffectId.Id.BURNING: 3,
	EffectId.Id.REDHOT: 2,
	EffectId.Id.ELECTRIFIED: 2,
	EffectId.Id.ELECTRIFIED_CONDUCTED: 2,
	EffectId.Id.SOAKED: 2,
}

# how many ticks an effect must remain active before triggering its threshold consequence
# (e.g. burning converts contiguous stone to lava after 3 ticks)
const DURATION_THRESHOLD_TICKS: Dictionary = {
	EffectId.Id.BURNING: 3,
	EffectId.Id.SOAKED: 2,
	EffectId.Id.REDHOT: 2,
}
