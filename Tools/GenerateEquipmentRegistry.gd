@tool
extends EditorScript

# Editor-only tool: recursively scans res://Data/Equipment/ and all
# subdirectories (Armor/, Weapons/, etc.) and regenerates the EQUIPMENT
# const array in EquipmentRegistry.gd.
#
# USAGE: open this script in the editor and run it after adding, removing,
# or moving any equipment .tres file.

const EQUIPMENT_DIR := "res://Data/Equipment/"
const REGISTRY_PATH := "res://Autoloads/EquipmentRegistry.gd"
const START_MARKER := "# --- AUTO-GENERATED EQUIPMENT LIST START ---"
const END_MARKER := "# --- AUTO-GENERATED EQUIPMENT LIST END ---"

func _run() -> void:
	var paths := _find_equipment_paths(EQUIPMENT_DIR)
	if paths.is_empty():
		push_warning("GenerateEquipmentRegistry: no equipment .tres files found under " + EQUIPMENT_DIR)
		return

	var block := _build_block(paths)
	if _replace_block_in_file(REGISTRY_PATH, block):
		print("EquipmentRegistry.gd updated with %d piece(s):" % paths.size())
		for p in paths:
			print("  ", p)
	else:
		push_error("GenerateEquipmentRegistry: failed to update " + REGISTRY_PATH)

# recursively collects every .tres file under the given directory
func _find_equipment_paths(dir_path: String) -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("GenerateEquipmentRegistry: could not open " + dir_path)
		return paths
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			# recurse into subdirectories (Armor/, Weapons/, etc.)
			paths.append_array(_find_equipment_paths(dir_path + entry + "/"))
		elif entry.ends_with(".tres"):
			paths.append(dir_path + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths

func _build_block(paths: Array[String]) -> String:
	var lines: Array[String] = [START_MARKER]
	lines.append("const EQUIPMENT: Array[EquipmentData] = [")
	for p in paths:
		lines.append("\tpreload(\"%s\")," % p)
	lines.append("]")
	lines.append(END_MARKER)
	return "\n".join(lines)

func _replace_block_in_file(path: String, new_block: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GenerateEquipmentRegistry: could not read " + path)
		return false
	var contents := file.get_as_text()
	file.close()

	var start_idx := contents.find(START_MARKER)
	var end_idx := contents.find(END_MARKER)
	if start_idx == -1 or end_idx == -1:
		push_error("GenerateEquipmentRegistry: markers not found in " + path)
		return false
	end_idx += END_MARKER.length()

	var updated := contents.substr(0, start_idx) + new_block + contents.substr(end_idx)

	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		push_error("GenerateEquipmentRegistry: could not write " + path)
		return false
	out.store_string(updated)
	out.close()

	var efs := EditorInterface.get_resource_filesystem()
	if efs:
		efs.update_file(path)
	return true
