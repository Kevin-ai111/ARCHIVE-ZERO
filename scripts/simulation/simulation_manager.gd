extends Node

signal simulation_updated(items_processed: int, credits_earned: int, elapsed_seconds: float)
signal production_line_changed
signal scanner_upgrades_changed

const DEFAULT_TICK_INTERVAL: float = 0.25
const MINIMUM_TICK_INTERVAL: float = 0.01
const PROTOTYPE_CREDITS_PER_ITEM: int = 2
const BASIC_SCANNER_ID: StringName = &"basic_scanner"

var _tick_interval: float = DEFAULT_TICK_INTERVAL
var _tick_accumulator: float = 0.0
var _production_line: ProductionLine = ProductionLineFactory.create_initial_line()
var _owned_scanner_upgrades: Array[String] = []


func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	_tick_accumulator += delta
	var completed_ticks: int = int(floor(_tick_accumulator / _tick_interval))
	if completed_ticks <= 0:
		return

	var elapsed_to_simulate: float = completed_ticks * _tick_interval
	_tick_accumulator -= elapsed_to_simulate
	simulate_elapsed(elapsed_to_simulate)


func simulate_elapsed(elapsed_seconds: float) -> Dictionary:
	if not is_finite(elapsed_seconds) or elapsed_seconds <= 0.0:
		return {
			"items_processed": 0,
			"credits_earned": 0,
			"elapsed_seconds": 0.0,
		}

	var items_processed: int = _production_line.simulate_elapsed(elapsed_seconds)
	var credits_earned: int = _commit_production(items_processed)
	var result: Dictionary = {
		"items_processed": items_processed,
		"credits_earned": credits_earned,
		"elapsed_seconds": elapsed_seconds,
	}

	simulation_updated.emit(items_processed, credits_earned, elapsed_seconds)
	return result


func process_manual_items(amount: int) -> bool:
	if amount <= 0:
		return false

	var credits_earned: int = _commit_production(amount)
	simulation_updated.emit(amount, credits_earned, 0.0)
	return credits_earned > 0


func purchase_scanner_upgrade(upgrade_id: String) -> bool:
	if _owned_scanner_upgrades.has(upgrade_id):
		return false

	var definition: Dictionary = ScannerUpgrades.get_definition(upgrade_id)
	if definition.is_empty():
		return false

	flush_pending_simulation()
	if not Economy.spend_money(int(definition["cost"])):
		return false

	_owned_scanner_upgrades.append(upgrade_id)
	_apply_scanner_upgrades()
	production_line_changed.emit()
	scanner_upgrades_changed.emit()
	return true


func owns_scanner_upgrade(upgrade_id: String) -> bool:
	return _owned_scanner_upgrades.has(upgrade_id)


func get_owned_scanner_upgrades() -> Array[String]:
	return _owned_scanner_upgrades.duplicate()


func get_scanner_throughput_multiplier() -> float:
	var scanner: MachineRuntime = _production_line.get_stage(BASIC_SCANNER_ID)
	if scanner == null:
		return 0.0
	return scanner.get_capacity_multiplier()


func set_tick_interval(interval_seconds: float) -> bool:
	if not is_finite(interval_seconds) or interval_seconds < MINIMUM_TICK_INTERVAL:
		return false

	flush_pending_simulation()
	_tick_interval = interval_seconds
	return true


func get_tick_interval() -> float:
	return _tick_interval


func get_production_line() -> ProductionLine:
	return _production_line


func set_machine_enabled(machine_id: StringName, enabled: bool) -> bool:
	var stage: MachineRuntime = _production_line.get_stage(machine_id)
	if stage == null or stage.is_enabled() == enabled:
		return stage != null

	flush_pending_simulation()
	_production_line.set_stage_enabled(machine_id, enabled)
	production_line_changed.emit()
	return true


func set_basic_scanner_enabled(enabled: bool) -> void:
	set_machine_enabled(BASIC_SCANNER_ID, enabled)


func is_basic_scanner_enabled() -> bool:
	var scanner: MachineRuntime = _production_line.get_stage(BASIC_SCANNER_ID)
	return scanner != null and scanner.is_enabled()


func set_machine_capacity_multiplier(machine_id: StringName, multiplier: float) -> bool:
	var stage: MachineRuntime = _production_line.get_stage(machine_id)
	if stage == null or not is_finite(multiplier) or multiplier < 0.0:
		return false
	# Scanner capacity is derived from owned upgrades. Allowing this generic debug
	# seam to write it would create a state that changes after save/load.
	if machine_id == BASIC_SCANNER_ID:
		return false
	if is_equal_approx(stage.get_capacity_multiplier(), multiplier):
		return true

	flush_pending_simulation()
	_production_line.set_stage_capacity_multiplier(machine_id, multiplier)
	production_line_changed.emit()
	return true


func get_scanner_capacity_per_minute() -> float:
	return _production_line.get_stage_capacity(BASIC_SCANNER_ID) * 60.0


func get_effective_throughput() -> float:
	return _production_line.get_effective_throughput()


func get_credits_per_second() -> float:
	return get_effective_throughput() * PROTOTYPE_CREDITS_PER_ITEM


func flush_pending_simulation() -> void:
	if _tick_accumulator <= 0.0:
		return

	var pending_seconds: float = _tick_accumulator
	_tick_accumulator = 0.0
	simulate_elapsed(pending_seconds)


func get_production_save_data() -> Dictionary:
	var save_data: Dictionary = _production_line.get_save_data()
	save_data["scanner_upgrades"] = _owned_scanner_upgrades.duplicate()
	return save_data


func get_default_production_save_data() -> Dictionary:
	var save_data: Dictionary = ProductionLineFactory.create_initial_line().get_save_data()
	save_data["scanner_upgrades"] = []
	return save_data


func migrate_production_save_data(save_data: Dictionary) -> Dictionary:
	if save_data.has("machines"):
		var current_data: Dictionary = save_data.duplicate(true)
		if not current_data.has("scanner_upgrades"):
			current_data["scanner_upgrades"] = []
		if not _normalize_scanner_multiplier(current_data):
			return {}
		return current_data if is_valid_production_save_data(current_data) else {}

	var legacy_fields: Array[String] = [
		"scanner_enabled",
		"scanner_upgrades",
		"incoming_item_buffer",
		"processed_item_fraction",
	]
	for field: String in legacy_fields:
		if not save_data.has(field):
			return {}

	var migrated_data: Dictionary = get_default_production_save_data()
	var scanner_state: Dictionary = migrated_data["machines"][String(BASIC_SCANNER_ID)]
	scanner_state["enabled"] = save_data["scanner_enabled"]
	scanner_state["capacity_multiplier"] = ScannerUpgrades.get_scanner_multiplier(
		_array_to_strings(save_data["scanner_upgrades"])
	)
	migrated_data["fractional_progress"] = save_data["processed_item_fraction"]
	migrated_data["scanner_upgrades"] = save_data["scanner_upgrades"]
	return migrated_data if is_valid_production_save_data(migrated_data) else {}


func is_valid_production_save_data(save_data: Dictionary) -> bool:
	if not _production_line.is_valid_save_data(save_data):
		return false
	if not save_data.has("scanner_upgrades"):
		return false
	if not _is_valid_scanner_upgrades(save_data["scanner_upgrades"]):
		return false

	var machines: Dictionary = save_data["machines"] as Dictionary
	var scanner_key: String = String(BASIC_SCANNER_ID)
	if not machines.has(scanner_key) or typeof(machines[scanner_key]) != TYPE_DICTIONARY:
		return false
	var scanner_state: Dictionary = machines[scanner_key] as Dictionary
	var expected_multiplier: float = ScannerUpgrades.get_scanner_multiplier(
		_array_to_strings(save_data["scanner_upgrades"])
	)
	return is_equal_approx(float(scanner_state["capacity_multiplier"]), expected_multiplier)


func restore_production_save_data(save_data: Dictionary) -> bool:
	if not is_valid_production_save_data(save_data):
		return false
	if not _production_line.restore_save_data(save_data):
		return false

	_owned_scanner_upgrades.assign(save_data["scanner_upgrades"])
	_apply_scanner_upgrades()
	_tick_accumulator = 0.0
	production_line_changed.emit()
	scanner_upgrades_changed.emit()
	return true


func _apply_scanner_upgrades() -> void:
	_production_line.set_stage_capacity_multiplier(
		BASIC_SCANNER_ID,
		ScannerUpgrades.get_scanner_multiplier(_owned_scanner_upgrades)
	)


func _normalize_scanner_multiplier(save_data: Dictionary) -> bool:
	if typeof(save_data.get("machines")) != TYPE_DICTIONARY:
		return false
	if typeof(save_data.get("scanner_upgrades")) != TYPE_ARRAY:
		return false
	if not _is_valid_scanner_upgrades(save_data["scanner_upgrades"]):
		return false

	var serialized_upgrades: Array = save_data["scanner_upgrades"] as Array
	var owned_upgrades: Array[String] = _array_to_strings(serialized_upgrades)

	var machines: Dictionary = save_data["machines"] as Dictionary
	var scanner_key: String = String(BASIC_SCANNER_ID)
	if not machines.has(scanner_key) or typeof(machines[scanner_key]) != TYPE_DICTIONARY:
		return false
	var scanner_state: Dictionary = machines[scanner_key] as Dictionary
	if not scanner_state.has("capacity_multiplier"):
		return false

	# Upgrade ownership is authoritative; normalize the redundant runtime field
	# so reconciled saves cannot retain or apply the Scanner modifier separately.
	scanner_state["capacity_multiplier"] = ScannerUpgrades.get_scanner_multiplier(owned_upgrades)
	return true


func _is_valid_scanner_upgrades(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false

	var seen_upgrade_ids: Dictionary = {}
	for upgrade_id: Variant in value:
		if typeof(upgrade_id) != TYPE_STRING or not ScannerUpgrades.DEFINITIONS.has(upgrade_id):
			return false
		if seen_upgrade_ids.has(upgrade_id):
			return false
		seen_upgrade_ids[upgrade_id] = true
	return true


func _array_to_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry: Variant in value:
		if typeof(entry) != TYPE_STRING:
			return []
		result.append(entry)
	return result


func _commit_production(items_processed: int) -> int:
	if items_processed <= 0:
		return 0

	var credits_earned: int = items_processed * PROTOTYPE_CREDITS_PER_ITEM
	GameState.register_processed_items(items_processed)
	Economy.add_money(credits_earned)
	return credits_earned
