extends Node

var _jobs: Dictionary = {} # job_id: JobData

func _ready() -> void:
	_load_jobs()
	
func _load_jobs() -> void:
	var dir = DirAccess.open("res://Data/Jobs/")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres") and not file.ends_with("Frames.tres"):
				var path = "res://Data/Jobs/" + file
				var job = load(path)
				if job != null:
					_jobs[job.job_id] = job
				else:
					push_error("Failed to load job: " + path)
			file = dir.get_next()

func get_job(job_id: int) -> JobData:
	return _jobs.get(job_id, null)
