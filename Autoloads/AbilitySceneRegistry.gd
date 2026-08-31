class_name AbilitySceneRegistry
extends Node

# --- AUTO-GENERATED ABILITY SCENES START ---
const SCENES: Dictionary = {
	"arrow": preload("res://Data/Abilities/Arrow.tscn"),
	"flame": preload("res://Data/Abilities/Flame/Flame.tscn"),
	"freeze": preload("res://Data/Abilities/Freeze/Freeze.tscn"),
	"spark": preload("res://Data/Abilities/Spark/Spark.tscn"),
}
# --- AUTO-GENERATED ABILITY SCENES END ---

static func get_scene(animation_id: String) -> PackedScene:
	return SCENES.get(animation_id, null)
