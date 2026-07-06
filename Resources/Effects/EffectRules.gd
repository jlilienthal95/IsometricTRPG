class_name EffectRules
extends RefCounted

# which effects each effect instantly neutralizes on contact
const NEUTRALIZE_MAP: Dictionary = {
	EffectId.Id.SOAKED: [EffectId.Id.BURNING],
	EffectId.Id.FROZEN: [EffectId.Id.BURNING],
}

# which terrain types each effect can spread/apply to
const SUSCEPTIBLE_TERRAIN: Dictionary = {
	EffectId.Id.BURNING: [
		BattleTileData.TerrainType.WOOD,
		BattleTileData.TerrainType.DRY_GRASS,
		BattleTileData.TerrainType.GRASS,
	],
}

# how many ticks an effect must remain active before triggering its threshold consequence
# (e.g. burning converts contiguous stone to lava after 3 ticks)
const DURATION_THRESHOLD_TICKS: Dictionary = {
	EffectId.Id.BURNING: 3,
	EffectId.Id.SOAKED: 2,
	EffectId.Id.REDHOT: 1,
}
