extends Control

@onready var money_value: Label = %MoneyValue
@onready var processed_items_value: Label = %ProcessedItemsValue
@onready var playtime_value: Label = %PlaytimeValue
@onready var incoming_rate_value: Label = %IncomingRateValue
@onready var scanner_capacity_value: Label = %ScannerCapacityValue
@onready var processed_rate_value: Label = %ProcessedRateValue
@onready var credits_rate_value: Label = %CreditsRateValue
@onready var bottleneck_value: Label = %BottleneckValue
@onready var scanner_upgrade_value: Label = %ScannerUpgradeValue
@onready var scanner_upgrade_button: Button = %ScannerUpgradeButton
@onready var scanner_toggle_button: Button = %ScannerToggleButton
@onready var status_value: Label = %StatusValue


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.processed_items_changed.connect(_on_processed_items_changed)
	GameState.state_restored.connect(_refresh_all)
	SimulationManager.simulation_updated.connect(_on_simulation_updated)
	SimulationManager.basic_scanner_enabled_changed.connect(_on_scanner_enabled_changed)
	SimulationManager.scanner_upgrades_changed.connect(_on_scanner_upgrades_changed)
	SaveManager.game_saved.connect(_on_game_saved)
	SaveManager.game_loaded.connect(_on_game_loaded)
	_refresh_all()


func _on_process_item_button_pressed() -> void:
	SimulationManager.process_manual_items(1)


func _on_add_credits_button_pressed() -> void:
	Economy.add_money(10)


func _on_spend_credits_button_pressed() -> void:
	if Economy.spend_money(5):
		status_value.text = "Spent 5 credits."
	else:
		status_value.text = "Cannot afford 5 credits."


func _on_scanner_toggle_button_pressed() -> void:
	SimulationManager.set_basic_scanner_enabled(not SimulationManager.is_basic_scanner_enabled())


func _on_scanner_upgrade_button_pressed() -> void:
	if SimulationManager.purchase_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID):
		status_value.text = "Purchased Scanner Motor I."
	else:
		status_value.text = "Scanner Motor I is owned or unaffordable."


func _on_save_button_pressed() -> void:
	if not SaveManager.save_game():
		status_value.text = "Save failed. See the debugger output."


func _on_load_button_pressed() -> void:
	if not SaveManager.load_game():
		status_value.text = "No valid save could be loaded."


func _on_money_changed(_current_money: int) -> void:
	_refresh_money()


func _on_processed_items_changed(_total_processed_items: int) -> void:
	_refresh_processed_items()


func _on_simulation_updated(
	_items_processed: int, _credits_earned: int, _elapsed_seconds: float
) -> void:
	_refresh_playtime()
	_refresh_production()


func _on_scanner_enabled_changed(_enabled: bool) -> void:
	_refresh_production()
	_refresh_scanner_button()


func _on_scanner_upgrades_changed() -> void:
	_refresh_production()
	_refresh_upgrade()


func _on_game_saved() -> void:
	status_value.text = "Game saved."


func _on_game_loaded() -> void:
	status_value.text = "Game loaded."
	_refresh_all()


func _refresh_all() -> void:
	_refresh_money()
	_refresh_processed_items()
	_refresh_playtime()
	_refresh_production()
	_refresh_scanner_button()
	_refresh_upgrade()


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
	incoming_rate_value.text = "%.2f" % SimulationManager.get_incoming_items_per_minute()
	scanner_capacity_value.text = "%.2f" % SimulationManager.get_scanner_capacity_per_minute()
	processed_rate_value.text = "%.2f" % SimulationManager.get_processed_items_per_minute()
	credits_rate_value.text = "%.2f" % SimulationManager.get_credits_per_minute()
	bottleneck_value.text = SimulationManager.get_bottleneck()


func _refresh_scanner_button() -> void:
	if SimulationManager.is_basic_scanner_enabled():
		scanner_toggle_button.text = "Disable Basic Scanner"
	else:
		scanner_toggle_button.text = "Enable Basic Scanner"


func _refresh_upgrade() -> void:
	var owned: bool = SimulationManager.owns_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID)
	scanner_upgrade_value.text = "%.2fx (%s)" % [
		SimulationManager.get_scanner_throughput_multiplier(),
		"Motor I" if owned else "Base",
	]
	scanner_upgrade_button.disabled = owned
	scanner_upgrade_button.text = (
		"Scanner Motor I — Owned" if owned else "Buy Scanner Motor I — 50 Credits"
	)
