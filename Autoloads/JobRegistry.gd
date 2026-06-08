var _jobs: Dictionary = {} # job_id: JobData

func _ready() -> void:
	_load_jobs()
	
func _load_jobs() -> void:
	#load all jobs tres files from data folder
	var dir = DirAccess.open("res://Data/Jobs")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var job = load("res://Data/Jobs" + file)
				_jobs[job.job_id] = job
			file = dir.get_next()

func get_job(job_id: int) -> JobData:
	return _jobs.get(job_id, null)
