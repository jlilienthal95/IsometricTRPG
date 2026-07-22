class_name MaterialRules
extends RefCounted

const IMMUNITIES := {
	EquipmentData.EquipmentMaterial.WOOD: [EffectId.Id.ELECTRIFIED, EffectId.Id.MAGNETISED, EffectId.Id.INDUCTION], # wood - focused on phsyical immunities
	EquipmentData.EquipmentMaterial.METAL: [EffectId.Id.BURNING, EffectId.Id.BLAZING, EffectId.Id.SOAKED, EffectId.Id.FEATHER], # metal - heavy with powerful physical protection, focused on physical imminuties
	EquipmentData.EquipmentMaterial.CLOTH: [EffectId.Id.CONFUSE, EffectId.Id.CHARM, EffectId.Id.INDUCTION, EffectId.Id.MAGNETISED], # cloth - focused on strength of mind and resistance to magic
	EquipmentData.EquipmentMaterial.LEATHER: [EffectId.Id.BLAZING, EffectId.Id.PLAGUED, EffectId.Id.INDUCTION, EffectId.Id.MAGNETISED], # leather - all rounder focused on limiting environmental impact
	EquipmentData.EquipmentMaterial.BONE: [],
}

const WEAKNESSES := {
	EquipmentData.EquipmentMaterial.WOOD: [EffectId.Id.BURNING, EffectId.Id.BLAZING, EffectId.Id.SOAKED], # wood - very weak to fire. Gets soaked by water.
	EquipmentData.EquipmentMaterial.METAL: [EffectId.Id.ELECTRIFIED, EffectId.Id.MAGNETISED, EffectId.Id.REDHOT, EffectId.Id.INDUCTION], # metal - very weak to electricity and magnetics. Sensitive to excessive heat
	EquipmentData.EquipmentMaterial.CLOTH: [EffectId.Id.BURNING, EffectId.Id.FEATHER, EffectId.Id.SOAKED], # cloth - very light and susceptible to fire and water
	EquipmentData.EquipmentMaterial.LEATHER: [EffectId.Id.SOAKED, EffectId.Id.FEATHER], # leather - not weak to much, but is light and prone to slips
	EquipmentData.EquipmentMaterial.BONE: [EffectId.Id.PLAGUED, EffectId.Id.CONFUSE, EffectId.Id.CHARM], # bone - exposes your weakness to the influence of the dead and dark magic
}
