class_name BattleTileData
extends Resource

enum TerrainType {
	NORMAL = 0,
	WOOD = 1,
	METAL = 2,
	STONE = 3,
	GRASS = 4,
	DRY_GRASS = 5,
	ASH = 6,
	WATER = 7,
	ICE = 8,
	LAVA = 9,
	SAND = 10,
	PLAGUE = 11
}

@export var terrain_type: TerrainType = TerrainType.NORMAL
@export var elevation: int = 0
@export var is_walkable: bool = false

# Runtime only — not exported, not saved
var unit_ref: BattleActor = null
var object_ref: BattleObject = null
var cell: Vector3i = Vector3i.ZERO
var atlas_source_id: int = 0
var atlas_coords: Vector2i = Vector2i.ZERO
var active_effects: Array[EffectInstance] = []
var _grid_ref: BattleGrid = null	# set by BattleGrid when the tile is created

# The terrain this tile falls back to when a REVERSIBLE conversion is undone
# (e.g. FROZEN melting back off ICE). A reversible conversion caches the real
# pre-conversion terrain here; a tile that is BORN already-converted (spawned as
# ice at runtime) never caches, so it melts to this default — grass. General,
# not ice-specific: any reversible terrain effect uses the same slot.
var base_terrain_type: TerrainType = TerrainType.GRASS

# Changes the tile's terrain. A REVERSIBLE change first caches the current
# terrain as the fallback — unless it's already that type, so a redundant
# ICE->ICE (a tile born frozen) can't clobber the real previous state — letting
# restore_base_terrain() put it back later. A permanent change leaves the
# fallback alone; the next reversible change captures whatever's current then.
func set_terrain(new_terrain: TerrainType, reversible: bool = false) -> void:
	if reversible and terrain_type != new_terrain:
		base_terrain_type = terrain_type
	terrain_type = new_terrain

# reverts a reversible conversion — back to whatever this tile falls back to
func restore_base_terrain() -> void:
	terrain_type = base_terrain_type

func has_effect(effect_id: EffectId.Id) -> bool:
	return EffectStore.has_effect(active_effects, effect_id)

func get_effect(effect_id: EffectId.Id) -> EffectInstance:
	return EffectStore.get_effect(active_effects, effect_id)

func apply_effect(effect_id: EffectId.Id, ticks: int = -1) -> void:
	var actual_ticks = ticks
	if actual_ticks == -1:
		actual_ticks = EffectRules.DEFAULT_DURATION.get(effect_id, 1)
	var is_new = not has_effect(effect_id)
	EffectStore.apply_effect(active_effects, effect_id, actual_ticks)
	if _grid_ref != null and is_new:
		_grid_ref.register_effect_cell(effect_id, cell)

func remove_effect(effect_id: EffectId.Id) -> void:
	if EffectStore.remove_effect(active_effects, effect_id):
		if _grid_ref != null:
			_grid_ref.unregister_effect_cell(effect_id, cell)
