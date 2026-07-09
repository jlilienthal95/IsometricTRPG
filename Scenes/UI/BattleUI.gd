class_name BattleUI
extends Control

@onready var battle_hud: BattleHUD = $BattleHUD
@onready var character_info: CharacterInfo = $CharacterInfo
@onready var cinematic_bars: CinematicBars = $CinematicBars

# The UI subscribes ITSELF to the state machine and turn signals — BattleManager
# never calls into the UI. New UI elements can react to battle state without
# any change to battle logic.
func setup() -> void:
	modulate.a = 1.0
	battle_hud.setup(BattleManager)
	BattleManager.state_changed.connect(_on_state_changed)
	BattleManager.active_unit_changed.connect(on_turn_changed)
	BattleManager.turn_ended.connect(_on_turn_ended)
	BattleManager.battle_ended.connect(_on_battle_end)

func _on_state_changed(state: BattleManager.BattleState) -> void:
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

func on_battle_start() -> void:
	var battle_start_scene: PackedScene = preload("res://Scenes/UI/BattleStart.tscn")
	var battle_start: BattleStart = battle_start_scene.instantiate()
	add_child(battle_start)
	battle_start.animation_player.play("transition_in")
	await battle_start.animation_player.animation_finished
	battle_start.queue_free()
	
func _on_battle_end(isWin: bool) -> void:
	var battle_start_scene: PackedScene = preload("res://Scenes/UI/BattleStart.tscn")
	var battle_start: BattleStart = battle_start_scene.instantiate()
	add_child(battle_start)
	if isWin:
		battle_start.battle_start_label.text = "BATTLE WON!"
	else:
		battle_start.battle_start_label.text = "BATTLE LOST."
	battle_start.animation_player.play("transition_in")
	await battle_start.animation_player.animation_finished
	battle_start.queue_free()

func on_turn_changed(unit: Unit) -> void:
	battle_hud.on_turn_changed(unit)

func _on_turn_ended(_unit: Unit) -> void:
	fade_out()

func refresh_character_info(unit_data: UnitData) -> void:
	character_info.setup(unit_data)

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
