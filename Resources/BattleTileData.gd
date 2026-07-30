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

func has_effect(effect_id: EffectId.Id) -> bool:
	return EffectStore.has_effect(active_effects, effect_id)

func get_effect(effect_id: EffectId.Id) -> EffectInstance:
	return EffectStore.get_effect(active_effects, effect_id)

func apply_effect(effect_id: EffectId.Id, ticks: int = -1) -> void:
	var actual_ticks = ticks
	if actual_ticks == -1:
		actual_ticks = EffectRules.DURATION_THRESHOLD_TICKS.get(effect_id, 1)
	var is_new = not has_effect(effect_id)
	EffectStore.apply_effect(active_effects, effect_id, actual_ticks)
	if _grid_ref != null and is_new:
		_grid_ref.register_effect_cell(effect_id, cell)

func remove_effect(effect_id: EffectId.Id) -> void:
	if EffectStore.remove_effect(active_effects, effect_id):
		if _grid_ref != null:
			_grid_ref.unregister_effect_cell(effect_id, cell)
