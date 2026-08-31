class_name DebugPanel
extends PanelContainer

signal terrain_selected(terrain_type: int)
signal effect_applied(effect_id: EffectId.Id)
signal effect_removed(effect_id: EffectId.Id)
signal walkable_toggled(value: bool)
signal tick_requested

@onready var _tile_info: RichTextLabel = $VBox/TileInfo
@onready var _effect_buttons: VBoxContainer = $VBox/Sections/EffectSection/EffectCheckboxes
@onready var _walkable_check: CheckBox = $VBox/WalkableCheck
@onready var _tick_button: Button = $VBox/TickButton
@onready var _terrain_buttons: VBoxContainer = $VBox/Sections/TerrainSection/TerrainButtons


func _ready() -> void:
	_build_terrain_palette()
	_build_effect_palette()
	_walkable_check.toggled.connect(func(v): walkable_toggled.emit(v))
	_tick_button.pressed.connect(func(): tick_requested.emit())

func _build_terrain_palette() -> void:
	var group = ButtonGroup.new()
	for key in BattleTileData.TerrainType.keys():
		var btn = Button.new()
		btn.text = key
		btn.toggle_mode = true
		btn.button_group = group
		var value = BattleTileData.TerrainType[key]
		var captured_value = value
		btn.pressed.connect(func(): terrain_selected.emit(captured_value))
		_terrain_buttons.add_child(btn)

func _build_effect_palette() -> void:
	for key in EffectId.Id.keys():
		if key == "NONE":
			continue
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.text = key
		label.custom_minimum_size.x = 120
		var apply_btn = Button.new()
		apply_btn.text = "Apply"
		apply_btn.custom_minimum_size.x = 60
		var remove_btn = Button.new()
		remove_btn.text = "Remove"
		remove_btn.custom_minimum_size.x = 60
		var value = EffectId.Id[key]
		var captured_value = value
		apply_btn.pressed.connect(func(): effect_applied.emit(captured_value))
		remove_btn.pressed.connect(func(): effect_removed.emit(captured_value))
		hbox.add_child(label)
		hbox.add_child(apply_btn)
		hbox.add_child(remove_btn)
		_effect_buttons.add_child(hbox)

func refresh_tile_info(tile: BattleTileData) -> void:
	_tile_info.text = "[b]Selected Tile[/b]\n" + _format_tile_body(tile)
	_walkable_check.set_block_signals(true)
	_walkable_check.button_pressed = tile.is_walkable
	_walkable_check.set_block_signals(false)

# multi-tile equivalent of refresh_tile_info — call this instead when
# _selected_cells.size() != 1. Shows a per-tile breakdown rather than
# picking one tile to represent the whole selection, since a click-drag
# selection can easily span mixed terrain/effects and silently displaying
# only the last-touched tile's info would be misleading.
func refresh_selection_info(cells: Array[Vector3i], grid: BattleGrid) -> void:
	if cells.is_empty():
		_tile_info.text = "[b]No tile selected[/b]"
		return
	if cells.size() == 1:
		var tile = grid.get_tile(cells[0])
		if tile != null:
			refresh_tile_info(tile)
		return

	var body = "[b]%d Tiles Selected[/b]" % cells.size()
	for cell in cells:
		var tile = grid.get_tile(cell)
		if tile == null:
			continue
		body += "\n\n[b]" + str(cell) + "[/b]\n" + _format_tile_body(tile)
	_tile_info.text = body
	# walkable checkbox has no single value to show across a mixed
	# selection — leave it as whatever it last was rather than guessing

# shared formatter — the per-tile detail block used by both the single-tile
# and multi-tile displays, so they can never drift out of sync with each other.
func _format_tile_body(tile: BattleTileData) -> String:
	var terrain_name = BattleTileData.TerrainType.keys()[tile.terrain_type]
	var effects_text = ""
	for instance in tile.active_effects:
		effects_text += "\n  • " + EffectId.Id.keys()[instance.effect_id] + \
			" (" + str(instance.rounds_remaining) + " rounds, " + \
			str(instance.ticks_active) + " ticks)"
	if effects_text == "":
		effects_text = "\n  none"
	return "Cell: " + str(tile.cell) + \
		"\nTerrain: " + terrain_name + \
		"\nWalkable: " + str(tile.is_walkable) + \
		"\nEffects:" + effects_text
