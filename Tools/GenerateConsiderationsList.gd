@tool
extends EditorScript

# Editor-only tool: scans res://Core/AI/Considerations/ and regenerates the
# CONSIDERATIONS const array in AIBrain.gd.
#
# USAGE: open this script in the editor and run it after adding or removing
# a consideration script.

const CONSIDERATIONS_DIR := "res://Core/AI/Considerations/"
const BRAIN_PATH := "res://Core/AI/AIBrain.gd"
const START_MARKER := "# --- AUTO-GENERATED CONSIDERATIONS LIST START ---"
const END_MARKER := "# --- AUTO-GENERATED CONSIDERATIONS LIST END ---"

func _run() -> void:
	var paths := _find_consideration_paths(CONSIDERATIONS_DIR)
	if paths.is_empty():
		push_warning("GenerateConsiderationsList: no consideration .gd files found under " + CONSIDERATIONS_DIR)
		return

	var block := _build_block(paths)
	if _replace_block_in_file(BRAIN_PATH, block):
		print("AIBrain.gd updated with %d consideration(s):" % paths.size())
		for p in paths:
			print("  ", p)
	else:
		push_error("GenerateConsiderationsList: failed to update " + BRAIN_PATH)

# recursively collects every .gd file under the given directory,
# skipping the base Consideration.gd class itself
func _find_consideration_paths(dir_path: String) -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("GenerateConsiderationsList: could not open " + dir_path)
		return paths
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			paths.append_array(_find_consideration_paths(dir_path + entry + "/"))
		elif entry.ends_with(".gd") and entry != "Consideration.gd":
			paths.append(dir_path + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths

func _build_block(paths: Array[String]) -> String:
	var lines: Array[String] = [START_MARKER]
	lines.append("const CONSIDERATIONS: Array[GDScript] = [")
	for p in paths:
		lines.append("\tpreload(\"%s\")," % p)
	lines.append("]")
	lines.append(END_MARKER)
	return "\n".join(lines)

func _replace_block_in_file(path: String, new_block: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GenerateConsiderationsList: could not read " + path)
		return false
	var contents := file.get_as_text()
	file.close()

	var start_idx := contents.find(START_MARKER)
	var end_idx := contents.find(END_MARKER)
	if start_idx == -1 or end_idx == -1:
		push_error("GenerateConsiderationsList: markers not found in " + path)
		return false
	end_idx += END_MARKER.length()

	var updated := contents.substr(0, start_idx) + new_block + contents.substr(end_idx)

	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		push_error("GenerateConsiderationsList: could not write " + path)
		return false
	out.store_string(updated)
	out.close()

	var efs := EditorInterface.get_resource_filesystem()
	if efs:
		efs.update_file(path)
	return true
