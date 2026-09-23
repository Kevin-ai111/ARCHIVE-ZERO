extends Node

signal simulation_updated(items_processed: int, credits_earned: int, elapsed_seconds: float)
signal basic_scanner_enabled_changed(enabled: bool)
signal scanner_upgrades_changed

const DEFAULT_TICK_INTERVAL: float = 0.25
const MINIMUM_TICK_INTERVAL: float = 0.01
const DEFAULT_INCOMING_ITEMS_PER_MINUTE: float = 90.0
const DEFAULT_CREDITS_PER_PROCESSED_ITEM: int = 2

var _tick_interval: float = DEFAULT_TICK_INTERVAL
var _tick_accumulator: float = 0.0
var _incoming_items_per_minute: float = DEFAULT_INCOMING_ITEMS_PER_MINUTE
var _credits_per_processed_item: int = DEFAULT_CREDITS_PER_PROCESSED_ITEM
var _incoming_item_buffer: float = 0.0
var _processed_item_fraction: float = 0.0
var _basic_scanner: BasicScanner = BasicScanner.new()
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
	if elapsed_seconds <= 0.0:
		return {"items_processed": 0, "credits_earned": 0, "elapsed_seconds": 0.0}

	_incoming_item_buffer += _incoming_items_per_minute * elapsed_seconds / 60.0
	var processed_amount: float = _basic_scanner.process_available(
		_incoming_item_buffer, elapsed_seconds
	)
	_incoming_item_buffer -= processed_amount
	_processed_item_fraction += processed_amount
	var items_processed: int = int(floor(_processed_item_fraction + 0.000000001))
	_processed_item_fraction -= items_processed
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
	if definition.is_empty() or not Economy.spend_money(int(definition["cost"])):
		return false
	_owned_scanner_upgrades.append(upgrade_id)
	_apply_scanner_upgrades()
	scanner_upgrades_changed.emit()
	return true


func owns_scanner_upgrade(upgrade_id: String) -> bool:
	return _owned_scanner_upgrades.has(upgrade_id)


func get_owned_scanner_upgrades() -> Array[String]:
	return _owned_scanner_upgrades.duplicate()


func set_tick_interval(interval_seconds: float) -> bool:
	if interval_seconds < MINIMUM_TICK_INTERVAL:
		return false
	_tick_interval = interval_seconds
	_tick_accumulator = 0.0
	return true


func get_tick_interval() -> float:
	return _tick_interval


func set_basic_scanner_enabled(enabled: bool) -> void:
	if _basic_scanner.is_enabled() == enabled:
		return
	_basic_scanner.set_enabled(enabled)
	basic_scanner_enabled_changed.emit(enabled)


func is_basic_scanner_enabled() -> bool:
	return _basic_scanner.is_enabled()


func get_incoming_items_per_minute() -> float:
	return _incoming_items_per_minute


func set_incoming_items_per_minute(items_per_minute: float) -> bool:
	if items_per_minute < 0.0:
		return false
	_incoming_items_per_minute = items_per_minute
	return true


func set_credits_per_processed_item(credits: int) -> bool:
	if credits <= 0:
		return false
	_credits_per_processed_item = credits
	return true


func get_credits_per_processed_item() -> int:
	return _credits_per_processed_item


func get_scanner_capacity_per_minute() -> float:
	return _basic_scanner.get_effective_throughput_per_minute()


func get_processed_items_per_minute() -> float:
	return minf(_incoming_items_per_minute, get_scanner_capacity_per_minute())


func get_credits_per_minute() -> float:
	return get_processed_items_per_minute() * _credits_per_processed_item


func get_scanner_throughput_multiplier() -> float:
	return _basic_scanner.get_throughput_multiplier()


func get_bottleneck() -> String:
	if not _basic_scanner.is_enabled():
		return "Scanner disabled"
	if get_scanner_capacity_per_minute() < _incoming_items_per_minute:
		return "Scanner"
	return "Incoming items"


func get_production_save_data() -> Dictionary:
	return {
		"scanner_enabled": _basic_scanner.is_enabled(),
		"scanner_upgrades": _owned_scanner_upgrades.duplicate(),
		"incoming_item_buffer": _incoming_item_buffer,
		"processed_item_fraction": _processed_item_fraction,
	}


func restore_production_state(data: Dictionary) -> bool:
	if not is_valid_production_state(data):
		return false
	_basic_scanner.set_enabled(bool(data["scanner_enabled"]))
	_owned_scanner_upgrades.assign(data["scanner_upgrades"])
	_incoming_item_buffer = float(data["incoming_item_buffer"])
	_processed_item_fraction = float(data["processed_item_fraction"])
	_tick_accumulator = 0.0
	_apply_scanner_upgrades()
	basic_scanner_enabled_changed.emit(_basic_scanner.is_enabled())
	scanner_upgrades_changed.emit()
	return true


func reset_transient_progress() -> void:
	_tick_accumulator = 0.0


func _apply_scanner_upgrades() -> void:
	_basic_scanner.set_throughput_multiplier(
		ScannerUpgrades.get_scanner_multiplier(_owned_scanner_upgrades)
	)


func _commit_production(items_processed: int) -> int:
	if items_processed <= 0:
		return 0
	var credits_earned: int = items_processed * _credits_per_processed_item
	GameState.register_processed_items(items_processed)
	Economy.add_money(credits_earned)
	return credits_earned


func is_valid_production_state(data: Dictionary) -> bool:
	if not (
		data.has("scanner_enabled")
		and data.has("scanner_upgrades")
		and data.has("incoming_item_buffer")
		and data.has("processed_item_fraction")
	):
		return false
	if typeof(data["scanner_enabled"]) != TYPE_BOOL or typeof(data["scanner_upgrades"]) != TYPE_ARRAY:
		return false
	for upgrade_id: Variant in data["scanner_upgrades"]:
		if typeof(upgrade_id) != TYPE_STRING or not ScannerUpgrades.DEFINITIONS.has(upgrade_id):
			return false
	return (
		_is_non_negative_number(data["incoming_item_buffer"])
		and _is_non_negative_number(data["processed_item_fraction"])
		and float(data["processed_item_fraction"]) < 1.0
	)


func _is_non_negative_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and float(value) >= 0.0
