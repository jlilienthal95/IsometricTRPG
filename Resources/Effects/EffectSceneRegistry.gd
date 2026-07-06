class_name EffectSceneRegistry
extends RefCounted

const SCENES: Dictionary = {
	EffectId.Id.BURNING: preload("res://Scenes/Battle/Effects/Burning.tscn"),
}

static func get_scene(effect_id: EffectId.Id) -> PackedScene:
	return SCENES.get(effect_id, null)
