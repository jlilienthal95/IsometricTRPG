class_name AbilitySceneRegistry
extends Node

const SCENES: Dictionary = {
	"spark": preload("res://Scenes/Battle/Abilities/Spark.tscn"),
	"flame": preload("res://Scenes/Battle/Abilities/Flame.tscn"),
	"arrow": preload("res://Scenes/Battle/Abilities/Arrow.tscn"),
}

static func get_scene(animation_id: String) -> PackedScene:
	return SCENES.get(animation_id, null)
