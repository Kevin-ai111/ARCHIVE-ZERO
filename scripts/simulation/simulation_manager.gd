extends Node

signal simulation_updated(items_processed: int, credits_earned: int, elapsed_seconds: float)
signal production_line_changed

const DEFAULT_TICK_INTERVAL: float = 0.25
const MINIMUM_TICK_INTERVAL: float = 0.01
const PROTOTYPE_CREDITS_PER_ITEM: int = 2

var _tick_interval: float = DEFAULT_TICK_INTERVAL
var _tick_accumulator: float = 0.0
var _production_line: ProductionLine = ProductionLineFactory.create_initial_line()


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


func set_machine_capacity_multiplier(machine_id: StringName, multiplier: float) -> bool:
	var stage: MachineRuntime = _production_line.get_stage(machine_id)
	if stage == null or not is_finite(multiplier) or multiplier < 0.0:
		return false
	if is_equal_approx(stage.get_capacity_multiplier(), multiplier):
		return true

	flush_pending_simulation()
	_production_line.set_stage_capacity_multiplier(machine_id, multiplier)
	production_line_changed.emit()
	return true


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
	return _production_line.get_save_data()


func get_default_production_save_data() -> Dictionary:
	return ProductionLineFactory.create_initial_line().get_save_data()


func is_valid_production_save_data(save_data: Dictionary) -> bool:
	return _production_line.is_valid_save_data(save_data)


func restore_production_save_data(save_data: Dictionary) -> bool:
	if not _production_line.restore_save_data(save_data):
		return false

	_tick_accumulator = 0.0
	production_line_changed.emit()
	return true


func _commit_production(items_processed: int) -> int:
	if items_processed <= 0:
		return 0

	var credits_earned: int = items_processed * PROTOTYPE_CREDITS_PER_ITEM
	GameState.register_processed_items(items_processed)
	Economy.add_money(credits_earned)
	return credits_earned
