class_name BattleUI
extends Control

@onready var battle_hud: BattleHUD = $BattleHUD
@onready var character_info: CharacterInfo = $CharacterInfo
@onready var cinematic_bars: CinematicBars = $CinematicBars

func setup(battle_manager: BattleManager) -> void:
	modulate.a = 1.0
	battle_hud.setup(battle_manager)

func refresh(state: BattleManager.BattleState) -> void:
	match state:
		BattleManager.BattleState.ACTION_SELECT:
			battle_hud.show_menu(battle_hud.action_menu)
			fade_in()
		BattleManager.BattleState.MOVE_SELECT:
			battle_hud.show_menu(null)
			fade_out()
		BattleManager.BattleState.EQUIPMENT_SELECT:
			battle_hud.show_menu(battle_hud.equipment_menu)
			fade_in()
		BattleManager.BattleState.ABILITIES_SELECT:
			battle_hud.show_menu(battle_hud.abilities_menu)
			fade_in()
		BattleManager.BattleState.JOB_ABILITIES_SELECT:
			battle_hud.show_menu(battle_hud.job_ability_menu)
			fade_in()
		BattleManager.BattleState.RESOLVING:
			battle_hud.show_menu(null)
			fade_out()
		_:
			battle_hud.show_menu(null)
			fade_out()

func on_turn_changed(unit: Unit) -> void:
	battle_hud.on_turn_changed(unit)

func refresh_character_info(unit_data: UnitData) -> void:
	character_info.setup(unit_data)

func refresh_hp() -> void:
	character_info.refresh()

func refresh_hud() -> void:
	battle_hud.refresh()

func fade_out(duration: float = Constants.FADE_OUT_TIMER) -> void:
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(battle_hud, "modulate:a", 0.0, duration)
	tween.tween_property(character_info, "modulate:a", 0.0, duration)

func fade_in(duration: float = 0.2) -> void:
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(battle_hud, "modulate:a", 1.0, duration)
	tween.tween_property(character_info, "modulate:a", 1.0, duration)

func fade_bars_in() -> void:
	await cinematic_bars.fade_in()

func fade_bars_out() -> void:
	await cinematic_bars.fade_out()
