@tool
extends EditorScript

# Scans res://Scenes/Battle/Abilities/ recursively and regenerates the SCENES
# const dictionary in AbilitySceneRegistry.gd.
# USAGE: run via GenerateAll.gd or open and run directly.

const ABILITIES_DIR := "res://Data/Abilities/"
const REGISTRY_PATH := "res://Autoloads/AbilitySceneRegistry.gd"
const START_MARKER := "# --- AUTO-GENERATED ABILITY SCENES START ---"
const END_MARKER := "# --- AUTO-GENERATED ABILITY SCENES END ---"

func _run() -> void:
	var paths := _find_scene_paths(ABILITIES_DIR)
	if paths.is_empty():
		push_warning("GenerateAbilitySceneRegistry: no .tscn files found under " + ABILITIES_DIR)
		return
	var block := _build_block(paths)
	if _replace_block_in_file(REGISTRY_PATH, block):
		print("AbilitySceneRegistry.gd updated with %d scene(s):" % paths.size())
		for p in paths:
			print("  ", p)
	else:
		push_error("GenerateAbilitySceneRegistry: failed to update " + REGISTRY_PATH)

func _find_scene_paths(dir_path: String) -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("GenerateAbilitySceneRegistry: could not open " + dir_path)
		return paths
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			paths.append_array(_find_scene_paths(dir_path + entry + "/"))
		elif entry.ends_with(".tscn"):
			paths.append(dir_path + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths

func _build_block(paths: Array[String]) -> String:
	var lines: Array[String] = [START_MARKER]
	lines.append("const SCENES: Dictionary = {")
	for p in paths:
		# key is the filename without extension — matches animation_id on AbilityData
		var key = p.get_file().get_basename()
		key = key[0].to_lower() + key.substr(1)
		lines.append("\t\"%s\": preload(\"%s\")," % [key, p])
	lines.append("}")
	lines.append(END_MARKER)
	return "\n".join(lines)

func _replace_block_in_file(path: String, new_block: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GenerateAbilitySceneRegistry: could not read " + path)
		return false
	var contents := file.get_as_text()
	file.close()
	var start_idx := contents.find(START_MARKER)
	var end_idx := contents.find(END_MARKER)
	if start_idx == -1 or end_idx == -1:
		push_error("GenerateAbilitySceneRegistry: markers not found in " + path)
		return false
	end_idx += END_MARKER.length()
	var updated := contents.substr(0, start_idx) + new_block + contents.substr(end_idx)
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		push_error("GenerateAbilitySceneRegistry: could not write " + path)
		return false
	out.store_string(updated)
	out.close()
	var efs := EditorInterface.get_resource_filesystem()
	if efs:
		efs.update_file(path)
	return true
