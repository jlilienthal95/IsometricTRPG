class_name MaterialRules
extends RefCounted

const IMMUNITIES := {
	EquipmentData.EquipmentMaterial.WOOD: [EffectId.Id.ELECTRIFIED, EffectId.Id.MAGNETISED],
	EquipmentData.EquipmentMaterial.METAL: [],
	EquipmentData.EquipmentMaterial.CLOTH: [],
	EquipmentData.EquipmentMaterial.LEATHER: [],
	EquipmentData.EquipmentMaterial.BONE: [],
}

const WEAKNESSES := {
	EquipmentData.EquipmentMaterial.WOOD: [EffectId.Id.BURNING],
	EquipmentData.EquipmentMaterial.METAL: [EffectId.Id.ELECTRIFIED, EffectId.Id.MAGNETISED],
	EquipmentData.EquipmentMaterial.CLOTH: [],
	EquipmentData.EquipmentMaterial.LEATHER: [],
	EquipmentData.EquipmentMaterial.BONE: [],
}
