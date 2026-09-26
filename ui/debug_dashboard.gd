extends Control

var _stage_views: Dictionary = {}
var _upgrade_views: Dictionary = {}

@onready var money_value: Label = %MoneyValue
@onready var processed_items_value: Label = %ProcessedItemsValue
@onready var playtime_value: Label = %PlaytimeValue
@onready var stage_rows: VBoxContainer = %StageRows
@onready var throughput_value: Label = %ThroughputValue
@onready var credits_per_second_value: Label = %CreditsPerSecondValue
@onready var bottleneck_value: Label = %BottleneckValue
@onready var fractional_progress_value: Label = %FractionalProgressValue
@onready var owned_upgrades_value: Label = %OwnedUpgradesValue
@onready var upgrade_rows: VBoxContainer = %UpgradeRows
@onready var status_value: Label = %StatusValue


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.processed_items_changed.connect(_on_processed_items_changed)
	GameState.state_restored.connect(_refresh_all)
	SimulationManager.simulation_updated.connect(_on_simulation_updated)
	SimulationManager.production_line_changed.connect(_on_production_line_changed)
	SimulationManager.upgrades_changed.connect(_on_upgrades_changed)
	SaveManager.game_saved.connect(_on_game_saved)
	SaveManager.game_loaded.connect(_on_game_loaded)
	_build_stage_rows()
	_build_upgrade_rows()
	_refresh_all()


func _on_process_item_button_pressed() -> void:
	SimulationManager.process_manual_items(1)


func _on_add_credits_button_pressed() -> void:
	Economy.add_money(10)


func _on_spend_credits_button_pressed() -> void:
	if Economy.spend_money(5):
		status_value.text = "Spent 5 Credits."
	else:
		status_value.text = "Cannot afford 5 Credits."


func _on_stage_toggle_pressed(machine_id: StringName) -> void:
	var stage: MachineRuntime = SimulationManager.get_production_line().get_stage(machine_id)
	if stage == null:
		status_value.text = "Unknown production stage: %s" % machine_id
		return

	SimulationManager.set_machine_enabled(machine_id, not stage.is_enabled())


func _on_upgrade_purchase_pressed(upgrade_id: String) -> void:
	var result: int = SimulationManager.purchase_upgrade(upgrade_id)
	status_value.text = SimulationManager.get_purchase_result_message(result, upgrade_id)
	_refresh_upgrade_shop()


func _on_save_button_pressed() -> void:
	if not SaveManager.save_game():
		status_value.text = "Save failed. See the debugger output."


func _on_load_button_pressed() -> void:
	if not SaveManager.load_game():
		status_value.text = "No valid save could be loaded."


func _on_money_changed(_current_money: int) -> void:
	_refresh_money()
	_refresh_upgrade_shop()


func _on_processed_items_changed(_total_processed_items: int) -> void:
	_refresh_processed_items()


func _on_simulation_updated(
	_items_processed: int, _credits_earned: int, _elapsed_seconds: float
) -> void:
	_refresh_playtime()
	_refresh_production()
	_refresh_upgrade_shop()


func _on_production_line_changed() -> void:
	_refresh_production()
	_refresh_upgrade_shop()


func _on_upgrades_changed() -> void:
	_refresh_production()
	_refresh_upgrade_shop()


func _on_game_saved() -> void:
	status_value.text = "Game saved."


func _on_game_loaded() -> void:
	status_value.text = "Game loaded."
	_refresh_all()


func _build_stage_rows() -> void:
	for stage: MachineRuntime in SimulationManager.get_production_line().get_stages():
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var name_label: Label = Label.new()
		name_label.custom_minimum_size = Vector2(190.0, 0.0)
		name_label.text = stage.get_definition().display_name
		row.add_child(name_label)

		var capacity_label: Label = Label.new()
		capacity_label.custom_minimum_size = Vector2(100.0, 0.0)
		capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(capacity_label)

		var utilization_label: Label = Label.new()
		utilization_label.custom_minimum_size = Vector2(90.0, 0.0)
		utilization_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(utilization_label)

		var state_label: Label = Label.new()
		state_label.custom_minimum_size = Vector2(130.0, 0.0)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(state_label)

		var toggle_button: Button = Button.new()
		toggle_button.name = "ToggleButton"
		toggle_button.custom_minimum_size = Vector2(90.0, 0.0)
		toggle_button.pressed.connect(_on_stage_toggle_pressed.bind(stage.get_id()))
		row.add_child(toggle_button)

		stage_rows.add_child(row)
		row.name = String(stage.get_id())
		_stage_views[String(stage.get_id())] = {
			"capacity": capacity_label,
			"utilization": utilization_label,
			"state": state_label,
			"toggle": toggle_button,
		}


func _build_upgrade_rows() -> void:
	for definition: UpgradeDefinition in SimulationManager.get_upgrade_definitions():
		var card: VBoxContainer = VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)

		var header: HBoxContainer = HBoxContainer.new()
		header.add_theme_constant_override("separation", 10)
		card.add_child(header)

		var name_label: Label = Label.new()
		name_label.custom_minimum_size = Vector2(180.0, 0.0)
		name_label.text = definition.display_name
		header.add_child(name_label)

		var price_label: Label = Label.new()
		price_label.custom_minimum_size = Vector2(90.0, 0.0)
		price_label.text = "%d Credits" % definition.cost
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(price_label)

		var ownership_label: Label = Label.new()
		ownership_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ownership_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(ownership_label)

		var purchase_button: Button = Button.new()
		purchase_button.name = "PurchaseButton"
		purchase_button.custom_minimum_size = Vector2(120.0, 0.0)
		purchase_button.pressed.connect(_on_upgrade_purchase_pressed.bind(String(definition.id)))
		header.add_child(purchase_button)

		var description_label: Label = Label.new()
		description_label.text = definition.description
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(description_label)

		var impact_label: Label = Label.new()
		impact_label.modulate = Color(0.75, 0.82, 0.9)
		card.add_child(impact_label)

		upgrade_rows.add_child(card)
		card.name = String(definition.id)
		_upgrade_views[String(definition.id)] = {
			"ownership": ownership_label,
			"button": purchase_button,
			"impact": impact_label,
		}


func _refresh_all() -> void:
	_refresh_money()
	_refresh_processed_items()
	_refresh_playtime()
	_refresh_production()
	_refresh_upgrade_shop()


func _refresh_money() -> void:
	money_value.text = str(GameState.get_money())


func _refresh_processed_items() -> void:
	processed_items_value.text = str(GameState.get_total_processed_items())


func _refresh_playtime() -> void:
	var total_seconds: int = int(GameState.get_total_playtime())
	var hours: int = int(total_seconds / 3600.0)
	var minutes: int = int((total_seconds % 3600) / 60.0)
	var seconds: int = total_seconds % 60
	playtime_value.text = "%02d:%02d:%02d" % [hours, minutes, seconds]


func _refresh_production() -> void:
	var production_line: ProductionLine = SimulationManager.get_production_line()
	var bottleneck: MachineRuntime = production_line.get_bottleneck()

	for stage: MachineRuntime in production_line.get_stages():
		var view: Dictionary = _stage_views[String(stage.get_id())] as Dictionary
		var capacity_label: Label = view["capacity"] as Label
		var utilization_label: Label = view["utilization"] as Label
		var state_label: Label = view["state"] as Label
		var toggle_button: Button = view["toggle"] as Button

		capacity_label.text = "%.2f/s" % stage.get_configured_capacity()
		utilization_label.text = (
			"%.1f%%" % (production_line.get_stage_utilization(stage.get_id()) * 100.0)
		)
		toggle_button.text = "ON" if stage.is_enabled() else "OFF"

		if not stage.is_enabled():
			state_label.text = "DISABLED"
		elif bottleneck == stage:
			state_label.text = "BOTTLENECK"
		else:
			state_label.text = ""

	throughput_value.text = "%.2f items/sec" % SimulationManager.get_effective_throughput()
	credits_per_second_value.text = "%.2f" % SimulationManager.get_credits_per_second()
	fractional_progress_value.text = "%.4f" % production_line.get_fractional_progress()
	bottleneck_value.text = (
		"None (line stopped)" if bottleneck == null else bottleneck.get_definition().display_name
	)


func _refresh_upgrade_shop() -> void:
	var owned_names: PackedStringArray = []
	for owned_definition: UpgradeDefinition in SimulationManager.get_owned_upgrade_definitions():
		owned_names.append(owned_definition.display_name)
	owned_upgrades_value.text = "None" if owned_names.is_empty() else ", ".join(owned_names)

	for definition: UpgradeDefinition in SimulationManager.get_upgrade_definitions():
		var view: Dictionary = _upgrade_views[String(definition.id)] as Dictionary
		var ownership_label: Label = view["ownership"] as Label
		var purchase_button: Button = view["button"] as Button
		var impact_label: Label = view["impact"] as Label
		var owned: bool = SimulationManager.owns_upgrade(String(definition.id))

		purchase_button.disabled = owned
		purchase_button.text = "Owned" if owned else "Purchase"
		if owned:
			ownership_label.text = "OWNED"
			impact_label.text = "Installed on %s (×%.2f)." % [
				definition.target_machine_id, definition.capacity_multiplier
			]
			continue

		ownership_label.text = (
			"AVAILABLE" if Economy.can_afford(definition.cost) else "NEED %d MORE" % (
				definition.cost - GameState.get_money()
			)
		)
		var impact: Dictionary = SimulationManager.get_upgrade_impact(String(definition.id))
		if impact.is_empty():
			impact_label.text = "Impact unavailable."
		elif bool(impact["improves_throughput"]):
			impact_label.text = "Raises throughput to %.2f/s; next bottleneck: %s." % [
				float(impact["projected_throughput"]), impact["projected_bottleneck"]
			]
		else:
			impact_label.text = "Throughput remains %.2f/s; bottleneck: %s." % [
				float(impact["projected_throughput"]), impact["projected_bottleneck"]
			]
