class_name CharacterInfo
extends Control

@onready var portrait_rect: TextureRect = $PortraitRect
@onready var name_label: Label = $Name
@onready var hp_bar: ProgressBarScene = $HpBar
@onready var hp_count: Label = $HpCount
@onready var hp_max_count: Label = $HpMaxCount
@onready var mp_bar: ProgressBarScene = $MpBar
@onready var mp_count: Label = $MpCount
@onready var mp_max_count: Label = $MpMaxCount
@onready var lvl_count: Label = $LvlCount

var _current_unit: UnitData = null

func _ready() -> void:
	# reactive: any HP change anywhere refreshes this panel if it is currently
	# displaying that actor — no code path needs to remember to refresh it
	BattleEvents.hp_changed.connect(_on_hp_changed)

func _on_hp_changed(actor, _amount: int, _new_hp: int) -> void:
	if _current_unit != null and actor is Unit and actor.data == _current_unit:
		refresh()

func setup(unit: UnitData) -> void:
	if unit == null:
		hide_window()
		return
	_current_unit = unit
	_load_info_from_unit(unit)
	hp_bar.setup(_current_unit.current_hp, _current_unit.max_hp)
	mp_bar.setup(_current_unit.current_mp, _current_unit.max_mp)
	show()

func _load_info_from_unit(unit_data: UnitData) -> void:
	name_label.text = unit_data.unit_name
	hp_bar.set_scene_value(unit_data.current_hp)
	hp_count.text = str(unit_data.current_hp)
	hp_max_count.text = str(unit_data.max_hp)
	mp_bar.set_scene_value(unit_data.current_mp)
	mp_count.text = str(unit_data.current_mp)
	mp_max_count.text = str(unit_data.max_mp)
	lvl_count.text = str(unit_data.current_lvl)

	# fetch unit portrait image based on job
	# TODO: implement path for custom unit portraits
	if unit_data.job != null and unit_data.job.portrait != null:
		portrait_rect.texture = unit_data.job.portrait
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
