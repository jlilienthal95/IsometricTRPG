class_name CharacterInfo
extends Control

@onready var player_bg = load("res://Assets/UI/Windows/Character_Info_Window.png")
@onready var enemy_bg = load("res://Assets/UI/Windows/Character_Info_Window_Enemy.png")
@onready var neutral_bg = load("res://Assets/UI/Windows/Character_Info_Window_Neutral.png")

@onready var background: NinePatchRect = $Background
@onready var portrait_rect: TextureRect = $PortraitRect
@onready var name_label: Label = $Name
@onready var hp_bar: ProgressBarScene = $HpBar
@onready var hp_count: Label = $HpCount
@onready var hp_max_count: Label = $HpMaxCount
@onready var mp_bar: ProgressBarScene = $MpBar
@onready var mp_count: Label = $MpCount
@onready var mp_max_count: Label = $MpMaxCount
@onready var lvl_count: Label = $LvlCount

var _current_actor: BattleActor = null

func _ready() -> void:
	BattleEvents.hp_changed.connect(_on_hp_changed)

func _on_hp_changed(actor, _amount: int, _new_hp: int) -> void:
	if _current_actor != null and actor == _current_actor:
		refresh()

func setup(actor: BattleActor) -> void:
	if actor == null:
		_clear_info()
		return
	_current_actor = actor
	_set_bg_color(actor.data.type)
	hp_bar.setup(actor.data.current_hp, actor.data.max_hp)
	if actor.data is UnitData:
		var unit_data := actor.data as UnitData
		mp_bar.show()
		mp_bar.setup(unit_data.current_mp, unit_data.max_mp)
		mp_count.text = str(unit_data.current_mp)
		mp_max_count.text = str(unit_data.max_mp)
		name_label.text = unit_data.unit_name
		lvl_count.text = str(unit_data.current_lvl)
		portrait_rect.texture = unit_data.job.portrait if unit_data.job != null else null
	else:
		mp_bar.hide()
		mp_count.text = ""
		mp_max_count.text = ""
		lvl_count.text = ""
		name_label.text = actor.data.object_name if actor.data is ObjectData else ""
		portrait_rect.texture = null
	show()

func _set_bg_color(type: BattleActorData.Type) -> void:
	match type:
		BattleActorData.Type.PLAYER:
			background.texture = player_bg
		BattleActorData.Type.ENEMY:
			background.texture = enemy_bg
		BattleActorData.Type.NEUTRAL:
			background.texture = neutral_bg

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
	if _current_actor != null:
		setup(_current_actor)
