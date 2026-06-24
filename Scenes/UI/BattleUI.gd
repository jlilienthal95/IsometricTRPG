class_name BattleUI
extends Control

@onready var battle_hud: BattleHUD = $BattleHUD
@onready var character_info: CharacterInfo = $CharacterInfo

func setup(battle_manager: BattleManager) -> void:
	modulate.a = 1.0
	battle_hud.menu_requested.connect(_on_menu_requested, CONNECT_DEFERRED)
	battle_hud.hide_requested.connect(fade_out, CONNECT_DEFERRED)
	battle_hud.setup(battle_manager)

func on_turn_changed(unit: Unit) -> void:
	battle_hud.on_turn_changed(unit)

func refresh_character_info(unit_data: UnitData) -> void:
	character_info.setup(unit_data)

func refresh_hp() -> void:
	character_info.refresh()

func refresh_hud() -> void:
	battle_hud.refresh()

func _on_menu_requested(menu) -> void:
	await fade_out(0.2)
	battle_hud.show_menu(menu)
	await fade_in(0.1)

func fade_out(duration: float = 0.5) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished

func fade_in(duration: float = 0.5) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)
	await tween.finished
