extends Control

@onready var money_value: Label = %MoneyValue
@onready var processed_items_value: Label = %ProcessedItemsValue
@onready var playtime_value: Label = %PlaytimeValue
@onready var items_per_second_value: Label = %ItemsPerSecondValue
@onready var credits_per_second_value: Label = %CreditsPerSecondValue
@onready var scanner_toggle_button: Button = %ScannerToggleButton
@onready var status_value: Label = %StatusValue


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.processed_items_changed.connect(_on_processed_items_changed)
	GameState.state_restored.connect(_refresh_all)
	SimulationManager.simulation_updated.connect(_on_simulation_updated)
	SimulationManager.basic_scanner_enabled_changed.connect(_on_scanner_enabled_changed)
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
	items_per_second_value.text = "%.2f" % SimulationManager.get_items_per_second()
	credits_per_second_value.text = "%.2f" % SimulationManager.get_credits_per_second()


func _refresh_scanner_button() -> void:
	if SimulationManager.is_basic_scanner_enabled():
		scanner_toggle_button.text = "Disable Basic Scanner"
	else:
		scanner_toggle_button.text = "Enable Basic Scanner"
