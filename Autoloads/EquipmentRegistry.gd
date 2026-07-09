extends Node

# Full equipment catalog, preloaded at compile time. Same export-safety rule as
# every other registry: no runtime path construction, no directory scanning.
# The registry exists for ID -> resource resolution (save files); authoring
# uses direct resource references on UnitData and never touches IDs.
const EQUIPMENT: Array[EquipmentData] = [
	preload("res://Data/Equipment/equipment_1.tres"),
	preload("res://Data/Equipment/equipment_1001.tres"),
]

var _equipment: Dictionary = {}	# equipment_id -> EquipmentData

func _ready() -> void:
	for piece in EQUIPMENT:
		if piece != null:
			if _equipment.has(piece.equipment_id):
				push_error("EquipmentRegistry: duplicate equipment_id %d ('%s' vs '%s')" % [
					piece.equipment_id, piece.equipment_name, _equipment[piece.equipment_id].equipment_name])
			_equipment[piece.equipment_id] = piece

func get_equipment(equipment_id: int) -> EquipmentData:
	return _equipment.get(equipment_id, null)
