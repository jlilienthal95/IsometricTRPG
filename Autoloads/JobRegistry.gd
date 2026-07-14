extends Node

# Design-time list of every job. Preloaded explicitly instead of scanning
# res://Data/Jobs/ at runtime via DirAccess — exported builds remap .tres files
# and append ".remap" to the filenames DirAccess returns, which silently broke
# the "ends_with(.tres)" check here and left _jobs empty in exports while working
# fine in-editor. Preloading resolves everything at compile time, so there's no
# runtime discovery step left to fail.

# --- AUTO-GENERATED JOBS LIST START ---
const JOBS: Array[JobData] = [
	preload("res://Data/Jobs/Knight.tres"),
	preload("res://Data/Jobs/Pirate.tres"),
]
# --- AUTO-GENERATED JOBS LIST END ---

var _jobs: Dictionary = {} # job_id: JobData

func _ready() -> void:
	_load_jobs()

func _load_jobs() -> void:
	for job in JOBS:
		if job != null:
			_jobs[job.job_id] = job

func get_job(job_id: int) -> JobData:
	return _jobs.get(job_id, null)
