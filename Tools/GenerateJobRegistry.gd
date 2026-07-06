@tool
extends EditorScript

# Editor-only tool: scans res://Data/Jobs/ and regenerates the JOBS const array
# in JobRegistry.gd. This runs entirely inside the Godot editor via EditorScript —
# it never ships in an exported build, so using DirAccess here is completely safe
# even though JobRegistry itself no longer scans directories at runtime (runtime
# DirAccess scanning is what caused the original export bug — see JobRegistry.gd).
#
# USAGE: whenever you add or remove a job .tres file in Data/Jobs/, open this
# script in the Godot editor and run it — File > Run (Ctrl+Shift+X / Cmd+Shift+X),
# or the "Run" icon in the script editor toolbar. It rewrites JobRegistry.gd in
# place, replacing only the block between the AUTO-GENERATED markers.

const JOBS_DIR := "res://Data/Jobs/"
const REGISTRY_PATH := "res://Autoloads/JobRegistry.gd"
const START_MARKER := "# --- AUTO-GENERATED JOBS LIST START ---"
const END_MARKER := "# --- AUTO-GENERATED JOBS LIST END ---"

func _run() -> void:
	var job_paths := _find_job_paths()
	if job_paths.is_empty():
		push_warning("RegenerateJobRegistry: no job .tres files found in " + JOBS_DIR)
		return

	var block := _build_jobs_block(job_paths)
	if _replace_block_in_file(REGISTRY_PATH, block):
		print("JobRegistry.gd updated with %d job(s):" % job_paths.size())
		for p in job_paths:
			print("  ", p)
	else:
		push_error("RegenerateJobRegistry: failed to update " + REGISTRY_PATH)

# finds every job resource in JOBS_DIR, skipping the *Frames.tres sprite resources
# and any subdirectories — this mirrors the filter JobRegistry used to apply at runtime
func _find_job_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(JOBS_DIR)
	if dir == null:
		push_error("RegenerateJobRegistry: could not open " + JOBS_DIR)
		return paths
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tres") and not file.ends_with("Frames.tres"):
			paths.append(JOBS_DIR + file)
		file = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths

# builds the replacement text block, including the markers themselves
func _build_jobs_block(paths: Array[String]) -> String:
	var lines: Array[String] = [START_MARKER]
	lines.append("const JOBS: Array[JobData] = [")
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
		push_error("RegenerateJobRegistry: could not read " + path)
		return false
	var contents := file.get_as_text()
	file.close()

	var start_idx := contents.find(START_MARKER)
	var end_idx := contents.find(END_MARKER)
	if start_idx == -1 or end_idx == -1:
		push_error("RegenerateJobRegistry: markers not found in " + path + " — see the comment at the top of this tool")
		return false
	end_idx += END_MARKER.length()

	var updated := contents.substr(0, start_idx) + new_block + contents.substr(end_idx)

	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		push_error("RegenerateJobRegistry: could not write " + path)
		return false
	out.store_string(updated)
	out.close()

	# tell the editor's filesystem to notice the change on disk
	var efs := EditorInterface.get_resource_filesystem()
	if efs:
		efs.update_file(path)
	return true
