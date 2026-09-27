extends CanvasLayer

const WINDOWED_SIZE := Vector2i(1280, 720)
const UPGRADE_FONT_SIZE := 24

var _purchase_buttons: Dictionary = {}
var _owned_labels: Dictionary = {}
var _last_windowed_size := WINDOWED_SIZE
var _last_windowed_position := Vector2i(-1, -1)

@onready var credits_value: Label = %CreditsValue
@onready var throughput_value: Label = %ThroughputValue
@onready var bottleneck_value: Label = %BottleneckValue
@onready var upgrade_overlay: CenterContainer = %UpgradeOverlay
@onready var upgrade_rows: VBoxContainer = %UpgradeRows
@onready var shop_status: Label = %ShopStatus
@onready var display_mode_button: Button = %DisplayModeButton


func _ready() -> void:
	%UpgradeButton.pressed.connect(open_upgrade_shop)
	%CloseShopButton.pressed.connect(close_upgrade_shop)
	%DebugDashboardButton.pressed.connect(_open_debug_dashboard)
	display_mode_button.pressed.connect(toggle_display_mode)
	GameState.money_changed.connect(_on_money_changed)
	GameState.state_restored.connect(_refresh)
	SimulationManager.production_line_changed.connect(_refresh)
	SimulationManager.upgrades_changed.connect(_refresh_upgrade_state)
	SimulationManager.simulation_updated.connect(_on_simulation_updated)
	_build_upgrade_rows()
	_refresh()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		_last_windowed_size = DisplayServer.window_get_size()
		_last_windowed_position = DisplayServer.window_get_position()
	_refresh_display_mode_label()


func _exit_tree() -> void:
	if GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.disconnect(_on_money_changed)
	if GameState.state_restored.is_connected(_refresh):
		GameState.state_restored.disconnect(_refresh)
	if SimulationManager.production_line_changed.is_connected(_refresh):
		SimulationManager.production_line_changed.disconnect(_refresh)
	if SimulationManager.upgrades_changed.is_connected(_refresh_upgrade_state):
		SimulationManager.upgrades_changed.disconnect(_refresh_upgrade_state)
	if SimulationManager.simulation_updated.is_connected(_on_simulation_updated):
		SimulationManager.simulation_updated.disconnect(_on_simulation_updated)


func open_upgrade_shop() -> void:
	upgrade_overlay.visible = true
	shop_status.text = "Select one of the two available machine upgrades."
	_refresh_upgrade_state()


func close_upgrade_shop() -> void:
	upgrade_overlay.visible = false


func toggle_display_mode() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(_last_windowed_size)
		if _last_windowed_position.x >= 0 and _last_windowed_position.y >= 0:
			DisplayServer.window_set_position(_last_windowed_position)
		else:
			var screen_size := DisplayServer.screen_get_size()
			DisplayServer.window_set_position((screen_size - _last_windowed_size) / 2)
	else:
		_last_windowed_size = DisplayServer.window_get_size()
		_last_windowed_position = DisplayServer.window_get_position()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_display_mode_label()


func get_readability_snapshot() -> Dictionary:
	return {
		"minimum_font_size": UPGRADE_FONT_SIZE,
		"primary_button_size": %UpgradeButton.custom_minimum_size,
		"shop_panel_size": %UpgradePanel.custom_minimum_size,
		"windowed_size": WINDOWED_SIZE,
	}


func _build_upgrade_rows() -> void:
	for child in upgrade_rows.get_children():
		child.queue_free()
	_purchase_buttons.clear()
	_owned_labels.clear()

	for definition: UpgradeDefinition in SimulationManager.get_upgrade_definitions():
		var card := PanelContainer.new()
		card.name = "Upgrade_%s" % definition.id
		card.custom_minimum_size = Vector2(0.0, 172.0)
		upgrade_rows.add_child(card)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 22)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 22)
		margin.add_theme_constant_override("margin_bottom", 16)
		card.add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		margin.add_child(row)

		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)

		var title := Label.new()
		title.add_theme_font_size_override("font_size", 30)
		title.text = definition.display_name
		copy.add_child(title)

		var description := Label.new()
		description.add_theme_font_size_override("font_size", UPGRADE_FONT_SIZE)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = "%s\nCost: %d Credits" % [definition.description, definition.cost]
		copy.add_child(description)

		var owned_label := Label.new()
		owned_label.custom_minimum_size = Vector2(190.0, 40.0)
		owned_label.add_theme_font_size_override("font_size", UPGRADE_FONT_SIZE)
		owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(owned_label)
		_owned_labels[String(definition.id)] = owned_label

		var purchase_button := Button.new()
		purchase_button.name = "Purchase_%s" % definition.id
		purchase_button.custom_minimum_size = Vector2(190.0, 64.0)
		purchase_button.add_theme_font_size_override("font_size", UPGRADE_FONT_SIZE)
		purchase_button.text = "Purchase"
		purchase_button.pressed.connect(_purchase_upgrade.bind(String(definition.id)))
		row.add_child(purchase_button)
		_purchase_buttons[String(definition.id)] = purchase_button


func _purchase_upgrade(upgrade_id: String) -> void:
	var result := SimulationManager.purchase_upgrade(upgrade_id)
	shop_status.text = SimulationManager.get_purchase_result_message(result, upgrade_id)
	_refresh()


func _on_money_changed(_current_money: int) -> void:
	_refresh()


func _on_simulation_updated(_items_processed: int, _credits_earned: int, _elapsed_seconds: float) -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	credits_value.text = "%d" % GameState.get_money()
	throughput_value.text = "%.2f items/sec" % SimulationManager.get_effective_throughput()
	var bottleneck: MachineRuntime = SimulationManager.get_production_line().get_bottleneck()
	bottleneck_value.text = "Line stopped" if bottleneck == null else bottleneck.get_definition().display_name
	_refresh_upgrade_state()


func _refresh_upgrade_state() -> void:
	if not is_node_ready():
		return
	for definition: UpgradeDefinition in SimulationManager.get_upgrade_definitions():
		var upgrade_id := String(definition.id)
		var owned := SimulationManager.owns_upgrade(upgrade_id)
		var button: Button = _purchase_buttons.get(upgrade_id) as Button
		var owned_label: Label = _owned_labels.get(upgrade_id) as Label
		if button != null:
			button.disabled = owned
			button.text = "Owned" if owned else "Purchase"
		if owned_label != null:
			owned_label.text = "INSTALLED" if owned else "AVAILABLE"


func _refresh_display_mode_label() -> void:
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	display_mode_button.text = "Windowed" if fullscreen else "Fullscreen"


func _open_debug_dashboard() -> void:
	get_tree().change_scene_to_file("res://scenes/debug/debug_dashboard.tscn")
