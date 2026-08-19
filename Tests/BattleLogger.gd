class_name BattleLogger
extends RefCounted

# Buffers lines for one test run and flushes to disk on completion, keeping
# only the most recent MAX_LOGS files so old runs don't accumulate forever.
#
# LIMITATION: this only captures lines explicitly logged through log_line() —
# it cannot intercept the engine's global print() stream (Godot has no public
# API for that from GDScript). Game code's own print() calls still appear
# live in the editor console during a run but are not persisted here. If full
# capture becomes necessary, enable Project Settings > Application > Run >
# Logs > Enable File Logging, which writes ALL stdout to user://logs/ — this
# class can then be pointed at copying that file instead.

const LOG_DIR := "user://test_logs/"
const MAX_LOGS := 10

var _lines: Array[String] = []
var _run_id: String = ""

func _init(run_id: String) -> void:
	_run_id = run_id
	DirAccess.make_dir_recursive_absolute(LOG_DIR)

func log_line(text: String) -> void:
	_lines.append("[%d] %s" % [Time.get_ticks_msec(), text])
	print(text)

func flush(success: bool) -> void:
	var status := "PASS" if success else "FAIL"
	var path := LOG_DIR + "run_%s_%s.log" % [_run_id, status]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines))
		file.close()
	_trim_old_logs()

func _trim_old_logs() -> void:
	var dir := DirAccess.open(LOG_DIR)
	if dir == null:
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".log"):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()	# run_id is a timestamp string, so lexical sort == chronological
	while files.size() > MAX_LOGS:
		var oldest: String = files.pop_front()
		DirAccess.remove_absolute(LOG_DIR + oldest)
