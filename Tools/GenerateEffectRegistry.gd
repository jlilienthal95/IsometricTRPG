@tool
extends EditorScript

# Editor-only tool: scans res://Resources/Effects/Handlers/ and regenerates the
# HANDLER_SCRIPTS const array in EffectRegistry.gd. Runs only inside the Godot
# editor via EditorScript — never ships in an exported build, so DirAccess is
# safe here even though EffectRegistry itself no longer scans at runtime.
#
# USAGE: whenever you add or remove a handler .gd file in Handlers/, open this
# script in the Godot editor and run it — File > Run (Ctrl+Shift+X / Cmd+Shift+X),
# or the "Run" icon in the script editor toolbar.

const HANDLERS_DIR := "res://Resources/Effects/Handlers/"
const REGISTRY_PATH := "res://Autoloads/EffectRegistry.gd"
const START_MARKER := "# --- AUTO-GENERATED HANDLERS LIST START ---"
const END_MARKER := "# --- AUTO-GENERATED HANDLERS LIST END ---"

func _run() -> void:
	var handler_paths := _find_handler_paths()
	if handler_paths.is_empty():
		push_warning("RegenerateEffectRegistry: no handler .gd files found in " + HANDLERS_DIR)
		return

	var block := _build_handlers_block(handler_paths)
	if _replace_block_in_file(REGISTRY_PATH, block):
		print("EffectRegistry.gd updated with %d handler(s):" % handler_paths.size())
		for p in handler_paths:
			print("  ", p)
	else:
		push_error("RegenerateEffectRegistry: failed to update " + REGISTRY_PATH)

# finds every handler script in HANDLERS_DIR, skipping subdirectories and .uid files
func _find_handler_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(HANDLERS_DIR)
	if dir == null:
		push_error("RegenerateEffectRegistry: could not open " + HANDLERS_DIR)
		return paths
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".gd"):
			paths.append(HANDLERS_DIR + file)
		file = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths

# builds the replacement text block, including the markers themselves
func _build_handlers_block(paths: Array[String]) -> String:
	var lines: Array[String] = [START_MARKER]
	lines.append("const HANDLER_SCRIPTS: Array[GDScript] = [")
	for p in paths:
		lines.append("\tpreload(\"%s\")," % p)
	lines.append("]")
	lines.append(END_MARKER)
	return "\n".join(lines)

# reads the target file, replaces everything between the markers (inclusive),
# and writes the result back
func _replace_block_in_file(path: String, new_block: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("RegenerateEffectRegistry: could not read " + path)
		return false
	var contents := file.get_as_text()
	file.close()

	var start_idx := contents.find(START_MARKER)
	var end_idx := contents.find(END_MARKER)
	if start_idx == -1 or end_idx == -1:
		push_error("RegenerateEffectRegistry: markers not found in " + path)
		return false
	end_idx += END_MARKER.length()

	var updated := contents.substr(0, start_idx) + new_block + contents.substr(end_idx)

	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		push_error("RegenerateEffectRegistry: could not write " + path)
		return false
	out.store_string(updated)
	out.close()

	var efs := EditorInterface.get_resource_filesystem()
	if efs:
		efs.update_file(path)
	return true
