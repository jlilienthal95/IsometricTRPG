class_name CharacterInfo
extends Control

@onready var portrait_rect: TextureRect = $PortraitRect
@onready var name_label: Label = $Name
@onready var hp_count: Label = $HpCount
@onready var hp_max_count: Label = $HpMaxCount
@onready var mp_count: Label = $MpCount
@onready var mp_max_count: Label = $MpMaxCount
@onready var lvl_count: Label = $LvlCount

var _current_unit: UnitData = null

func setup(unit: UnitData) -> void:
	if unit == null:
		hide_window()
		return
	_current_unit = unit
	_load_info_from_unit(unit)
	show()

func _load_info_from_unit(unit_data: UnitData) -> void:
	name_label.text = unit_data.unit_name
	hp_count.text = str(unit_data.current_hp)
	hp_max_count.text = str(unit_data.max_hp)
	mp_count.text = str(unit_data.current_mp)
	mp_max_count.text = str(unit_data.max_mp)
	lvl_count.text = str(unit_data.current_lvl)
	
	# load portrait from job data
	var job: JobData = JobRegistry.get_job(unit_data.job_id)
	if job != null and job.portrait != null:
		portrait_rect.texture = job.portrait
	else:
		portrait_rect.texture = null
	
func _clear_info() -> void:
	name_label.text = ""
	hp_count.text = ""
	hp_max_count.text = ""
	mp_count.text = ""
	mp_max_count.text = ""
	lvl_count.text = ""
	
func hide_window() -> void:
	_clear_info()
	hide()

func refresh() -> void:
	if _current_unit != null:
		_load_info_from_unit(_current_unit)
	
