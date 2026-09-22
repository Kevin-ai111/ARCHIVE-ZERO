extends Node

signal simulation_updated(items_processed: int, credits_earned: int, elapsed_seconds: float)
signal basic_scanner_enabled_changed(enabled: bool)

const DEFAULT_TICK_INTERVAL: float = 0.25
const MINIMUM_TICK_INTERVAL: float = 0.01

var _tick_interval: float = DEFAULT_TICK_INTERVAL
var _tick_accumulator: float = 0.0
var _basic_scanner: BasicScanner = BasicScanner.new()


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
		return {
			"items_processed": 0,
			"credits_earned": 0,
			"elapsed_seconds": 0.0,
		}

	var items_processed: int = _basic_scanner.process_elapsed(elapsed_seconds)
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


func get_items_per_second() -> float:
	if not _basic_scanner.is_enabled():
		return 0.0
	return BasicScanner.ITEMS_PER_SECOND


func get_credits_per_second() -> float:
	return get_items_per_second() * BasicScanner.CREDITS_PER_ITEM


func reset_transient_progress() -> void:
	_tick_accumulator = 0.0
	_basic_scanner.reset_progress()


func _commit_production(items_processed: int) -> int:
	if items_processed <= 0:
		return 0

	var credits_earned: int = items_processed * BasicScanner.CREDITS_PER_ITEM
	GameState.register_processed_items(items_processed)
	Economy.add_money(credits_earned)
	return credits_earned
