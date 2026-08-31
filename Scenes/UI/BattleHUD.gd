class_name BattleHUD
extends Control

@onready var action_menu = $ActionMenu
@onready var move_button: HoverButton = $ActionMenu/VBoxContainer/MoveButton
@onready var abilities_button: HoverButton = $ActionMenu/VBoxContainer/AbilitiesButton
@onready var equipment_button: HoverButton = $ActionMenu/VBoxContainer/EquipmentButton
@onready var wait_button: HoverButton = $ActionMenu/VBoxContainer/WaitButton

@onready var equipment_menu = $EquipmentMenu
@onready var equipment_vbox: VBoxContainer = $EquipmentMenu/EquipmentScroll/VBoxContainer

@onready var abilities_menu = $AbilitiesMenu
@onready var fight_button = $AbilitiesMenu/VBoxContainer/FightButton
@onready var job_ability_menu_button: HoverButton = $AbilitiesMenu/VBoxContainer/JobAbilityMenuButton
@onready var items_button: HoverButton = $AbilitiesMenu/VBoxContainer/ItemsButton

@onready var job_ability_menu = $JobAbilityMenu
@onready var job_ability_vbox: VBoxContainer = $JobAbilityMenu/JobAbilityScroll/VBoxContainer

@onready var battle_info: BattleInfo = $BattleInfo
@onready var battle_info_scroll: ScrollContainer = $BattleInfo/InfoScroll
@onready var battle_info_label: Label = $BattleInfo/InfoScroll/InfoCenter/InfoLabel

var _active_unit: Unit = null

var job_ability_button = preload("res://Scenes/UI/JobActionButton.tscn")

func setup(battle_manager: BattleManager) -> void:
	move_button.pressed.connect(battle_manager.select_action_move)
	move_button.focused.connect(_on_button_focused)
	move_button.unfocused.connect(_on_button_unfocused)
	
	abilities_button.pressed.connect(battle_manager.select_action_abilities)
	abilities_button.focused.connect(_on_button_focused)
	abilities_button.unfocused.connect(_on_button_unfocused)
	
	equipment_button.pressed.connect(battle_manager.select_action_equipment)
	equipment_button.focused.connect(_on_button_focused)
	equipment_button.unfocused.connect(_on_button_unfocused)

	wait_button.pressed.connect(battle_manager.end_turn)
	wait_button.focused.connect(_on_button_focused)
	wait_button.unfocused.connect(_on_button_unfocused)
	
	fight_button.pressed.connect(_on_fight_pressed)
	fight_button.focused.connect(_on_button_focused)
	fight_button.unfocused.connect(_on_button_unfocused)
	
	job_ability_menu_button.pressed.connect(battle_manager.select_job_ability)
	job_ability_menu_button.focused.connect(_on_button_focused)
	job_ability_menu_button.unfocused.connect(_on_button_unfocused)
	
	items_button.focused.connect(_on_button_focused)
	items_button.unfocused.connect(_on_button_unfocused)
	
	_hide_all()

func refresh() -> void:
	battle_info.hide()
	if _active_unit == null:
		return
	move_button.disabled = _active_unit.data.has_moved
	abilities_button.disabled = _active_unit.data.has_acted
	_generate_equipment_buttons(_active_unit.data.equipment)
	_generate_job_ability_buttons(_active_unit.data.abilities)

# the HUD re-subscribes to each new active unit's turn-resource signals so
# button states always mirror the data without manual refresh calls scattered
# around the codebase
func on_turn_changed(unit: Unit) -> void:
	if unit.data.type == BattleActorData.Type.PLAYER:
		show()
		if _active_unit != null:
			if _active_unit.move_consumed.is_connected(refresh):
				_active_unit.move_consumed.disconnect(refresh)
			if _active_unit.ability_consumed.is_connected(refresh):
				_active_unit.ability_consumed.disconnect(refresh)
		
		_active_unit = unit
		unit.move_consumed.connect(refresh)
		unit.ability_consumed.connect(refresh)
		refresh()
	else:
		hide()

func _generate_equipment_buttons(equipment: Array[EquipmentData]) -> void:
	_equipment_reset()
	for item in equipment:
		var button = HoverButton.new()
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.text = item.equipment_name
		button.custom_minimum_size.x = Constants.ACTION_BUTTON_X
		button.custom_minimum_size.y = Constants.ACTION_BUTTON_Y
		equipment_vbox.add_child(button)

func _generate_job_ability_buttons(abilities: Array[AbilityData]) -> void:
	_job_ability_reset()
	for ability in abilities:
		var button = job_ability_button.instantiate()
		var mp_cost = ability.mp_cost
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.get_node("./ActionLabel").text = ability.ability_name.replace("_", " ")
		button.focused.connect(_on_button_focused)
		button.unfocused.connect(_on_button_unfocused)
		if mp_cost > 0:
			button.get_node("./MpLabel").text = str(ability.mp_cost)
		if _active_unit.data.current_mp >= ability.mp_cost:
			button.pressed.connect(BattleManager.select_ability.bind(ability))
		else:
			button.disabled = true
		job_ability_vbox.add_child(button)

func show_menu(menu) -> void:
	_hide_all()
	if menu != null:
		menu.show()

# the fight ability is a direct resource reference on the unit's job — no more
# name-string lookup ("Fight_" + job_name) that silently broke on rename
func _on_fight_pressed() -> void:
	if _active_unit == null or _active_unit.data.job == null:
		return
	var fight = _active_unit.data.job.fight_ability
	if fight == null:
		push_error("BattleHUD: job '%s' has no fight_ability assigned" % _active_unit.data.job.job_name)
		return
	BattleManager.select_ability(fight)
	
func _on_button_focused(button: HoverButton) -> void:
	match BattleManager.current_state:
		BattleManager.BattleState.ACTION_SELECT, BattleManager.BattleState.ABILITIES_SELECT:
			var text = button.text.to_upper().replace(" ", "_")
			var desc_id = UiDescriptions.action_description[text]
			battle_info.display(UiDescriptions.get_action_description(desc_id))
		BattleManager.BattleState.JOB_ABILITIES_SELECT:
			if button != null:
				var label = button.get_node("./ActionLabel")
				if label != null:
					var text = label.text.replace(" ", "_")
					for ability: AbilityData in AbilityRegistry.ABILITIES:
						if ability.ability_name == text:
							battle_info.display(ability.description)
							break
		BattleManager.BattleState.EQUIPMENT_SELECT:
			var text = button.text.replace(" ", "_")
			for equipment: EquipmentData in EquipmentRegistry.EQUIPMENT:
				if equipment.equipment_name == text:
					battle_info.display(equipment.description)
					break
		_:
			battle_info.hide_info()

func _on_button_unfocused() -> void:
	battle_info.hide_info()

func _equipment_reset() -> void:
	for child in equipment_vbox.get_children():
		child.queue_free()

func _job_ability_reset() -> void:
	for child in job_ability_vbox.get_children():
		child.queue_free()

func _hide_all() -> void:
	action_menu.hide()
	equipment_menu.hide()
	abilities_menu.hide()
	job_ability_menu.hide()
