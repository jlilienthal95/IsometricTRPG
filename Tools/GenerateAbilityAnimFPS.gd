@tool
extends EditorScript

# Scans all AbilityData resources and updates their animation_fps field
# by instantiating the linked ability scene and reading the AnimatedSprite2D fps.
# Run via GenerateAll.gd after adding or changing ability scenes.

const ABILITIES_DIR := "res://Data/Abilities/"

func _run() -> void:
	var paths := _find_ability_paths(ABILITIES_DIR)
	var updated := 0
	for path in paths:
		var ability := load(path) as AbilityData
		if ability == null:
			continue
		if ability.animation_id == "":
			continue
		var scene_path := "res://Data/Abilities/" + ability.animation_id.substr(0, 1).to_upper() + ability.animation_id.substr(1) + ".tscn"
		if not ResourceLoader.exists(scene_path):
			continue
		var scene := load(scene_path) as PackedScene
		if scene == null:
			continue
		var temp := scene.instantiate()
		var sprite := temp.get_node_or_null("AbilitySprite")
		if sprite is AnimatedSprite2D and sprite.sprite_frames != null:
			var anim_name := ability.animation_id
			if sprite.sprite_frames.has_animation(anim_name):
				var fps = sprite.sprite_frames.get_animation_speed(anim_name)
				if ability.animation_fps != fps:
					ability.animation_fps = fps
					ResourceSaver.save(ability, path)
					updated += 1
					print("Updated fps for: ", path, " -> ", fps)
		temp.queue_free()
	print("GenerateAbilityAnimFPS: updated %d ability resources" % updated)

func _find_ability_paths(dir_path: String) -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".tres"):
			paths.append(dir_path + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return paths
