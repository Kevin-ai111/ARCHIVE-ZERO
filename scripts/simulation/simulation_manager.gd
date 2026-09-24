extends Node

signal simulation_updated(items_processed: int, credits_earned: int, elapsed_seconds: float)
signal production_line_changed
signal upgrades_changed

enum PurchaseResult {
	SUCCESS,
	INVALID_UPGRADE,
	ALREADY_OWNED,
	TARGET_UNAVAILABLE,
	INSUFFICIENT_FUNDS,
}

const DEFAULT_TICK_INTERVAL: float = 0.25
const MINIMUM_TICK_INTERVAL: float = 0.01
const PROTOTYPE_CREDITS_PER_ITEM: int = 2
const BASIC_SCANNER_ID: StringName = &"basic_scanner"
const BASIC_SORTER_ID: StringName = &"basic_sorter"
const CURRENT_SAVE_VERSION: int = 3
const PREVIOUS_SAVE_VERSION: int = 2

var _tick_interval: float = DEFAULT_TICK_INTERVAL
var _tick_accumulator: float = 0.0
var _production_line: ProductionLine = ProductionLineFactory.create_initial_line()
var _owned_upgrade_ids: Array[String] = []


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


func purchase_upgrade(upgrade_id: String) -> int:
	var definition: UpgradeDefinition = UpgradeCatalog.get_definition(upgrade_id)
	if definition == null or not definition.is_valid():
		return PurchaseResult.INVALID_UPGRADE
	if _owned_upgrade_ids.has(upgrade_id):
		return PurchaseResult.ALREADY_OWNED
	if _production_line.get_stage(definition.target_machine_id) == null:
		return PurchaseResult.TARGET_UNAVAILABLE
	if not Economy.can_afford(definition.cost):
		return PurchaseResult.INSUFFICIENT_FUNDS

	flush_pending_simulation()
	if not Economy.spend_money(definition.cost):
		return PurchaseResult.INSUFFICIENT_FUNDS

	_owned_upgrade_ids.append(upgrade_id)
	_apply_upgrade_multipliers()
	production_line_changed.emit()
	upgrades_changed.emit()
	return PurchaseResult.SUCCESS


func get_purchase_result_message(result: int, upgrade_id: String) -> String:
	var definition: UpgradeDefinition = UpgradeCatalog.get_definition(upgrade_id)
	var upgrade_name: String = upgrade_id if definition == null else definition.display_name
	match result:
		PurchaseResult.SUCCESS:
			return "Purchased %s." % upgrade_name
		PurchaseResult.ALREADY_OWNED:
			return "%s is already owned." % upgrade_name
		PurchaseResult.TARGET_UNAVAILABLE:
			return "%s cannot be installed because its machine is unavailable." % upgrade_name
		PurchaseResult.INSUFFICIENT_FUNDS:
			return "Not enough Credits to buy %s." % upgrade_name
		_:
			return "Unknown upgrade: %s." % upgrade_id


func get_upgrade_definitions() -> Array[UpgradeDefinition]:
	return UpgradeCatalog.get_definitions()


func get_owned_upgrade_ids() -> Array[String]:
	return _owned_upgrade_ids.duplicate()


func get_owned_upgrade_definitions() -> Array[UpgradeDefinition]:
	var owned_definitions: Array[UpgradeDefinition] = []
	for upgrade_id: String in _owned_upgrade_ids:
		var definition: UpgradeDefinition = UpgradeCatalog.get_definition(upgrade_id)
		if definition != null:
			owned_definitions.append(definition)
	return owned_definitions


func owns_upgrade(upgrade_id: String) -> bool:
	return _owned_upgrade_ids.has(upgrade_id)


func get_machine_upgrade_multiplier(machine_id: StringName) -> float:
	var stage: MachineRuntime = _production_line.get_stage(machine_id)
	if stage == null:
		return 0.0
	return stage.get_upgrade_capacity_multiplier()


func get_upgrade_impact(upgrade_id: String) -> Dictionary:
	var definition: UpgradeDefinition = UpgradeCatalog.get_definition(upgrade_id)
	if definition == null:
		return {}

	var current_throughput: float = _production_line.get_effective_throughput()
	var projected_throughput: float = INF
	var projected_bottleneck: MachineRuntime = null
	for stage: MachineRuntime in _production_line.get_stages():
		var capacity: float = stage.get_effective_capacity()
		if stage.get_id() == definition.target_machine_id and not owns_upgrade(upgrade_id):
			capacity *= definition.capacity_multiplier
		if capacity <= 0.0:
			return {
				"current_throughput": current_throughput,
				"projected_throughput": 0.0,
				"projected_bottleneck": "Line stopped",
				"improves_throughput": false,
			}
		if projected_bottleneck == null or capacity < projected_throughput:
			projected_throughput = capacity
			projected_bottleneck = stage

	return {
		"current_throughput": current_throughput,
		"projected_throughput": projected_throughput,
		"projected_bottleneck": projected_bottleneck.get_definition().display_name,
		"improves_throughput": projected_throughput > current_throughput,
	}


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
	if UpgradeCatalog.has_upgrade_for_machine(machine_id):
		return false
	if is_equal_approx(stage.get_runtime_capacity_multiplier(), multiplier):
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
	var save_data: Dictionary = _production_line.get_save_data()
	save_data["owned_upgrade_ids"] = _owned_upgrade_ids.duplicate()
	return save_data


func get_default_production_save_data() -> Dictionary:
	var save_data: Dictionary = ProductionLineFactory.create_initial_line().get_save_data()
	save_data["owned_upgrade_ids"] = []
	return save_data


func migrate_production_save_data(save_data: Dictionary, source_version: int) -> Dictionary:
	if source_version == CURRENT_SAVE_VERSION:
		var current_data: Dictionary = save_data.duplicate(true)
		return current_data if is_valid_production_save_data(current_data) else {}
	if source_version != PREVIOUS_SAVE_VERSION:
		return {}
	if save_data.has("machines"):
		return _migrate_version_two_line(save_data)
	return _migrate_version_two_scanner_only(save_data)


func is_valid_production_save_data(save_data: Dictionary) -> bool:
	if not _production_line.is_valid_save_data(save_data):
		return false
	if not save_data.has("owned_upgrade_ids"):
		return false
	if not UpgradeCatalog.are_valid_owned_upgrade_ids(save_data["owned_upgrade_ids"]):
		return false

	for upgrade_id: Variant in save_data["owned_upgrade_ids"]:
		var definition: UpgradeDefinition = UpgradeCatalog.get_definition(upgrade_id)
		if definition == null or _production_line.get_stage(definition.target_machine_id) == null:
			return false
	return true


func restore_production_save_data(save_data: Dictionary) -> bool:
	if not is_valid_production_save_data(save_data):
		return false
	if not _production_line.restore_save_data(save_data):
		return false

	_owned_upgrade_ids.assign(save_data["owned_upgrade_ids"])
	_apply_upgrade_multipliers()
	_tick_accumulator = 0.0
	production_line_changed.emit()
	upgrades_changed.emit()
	return true


func _apply_upgrade_multipliers() -> void:
	for stage: MachineRuntime in _production_line.get_stages():
		stage.set_upgrade_capacity_multiplier(
			UpgradeCatalog.get_capacity_multiplier(stage.get_id(), _owned_upgrade_ids)
		)


func _migrate_version_two_line(save_data: Dictionary) -> Dictionary:
	if not save_data.has("fractional_progress") or typeof(save_data.get("machines")) != TYPE_DICTIONARY:
		return {}

	var legacy_upgrade_ids: Variant = save_data.get("scanner_upgrades", [])
	if not UpgradeCatalog.are_valid_owned_upgrade_ids(legacy_upgrade_ids):
		return {}
	var owned_upgrade_ids: Array[String] = _array_to_strings(legacy_upgrade_ids)

	var migrated_data: Dictionary = get_default_production_save_data()
	migrated_data["fractional_progress"] = save_data["fractional_progress"]
	var old_machines: Dictionary = save_data["machines"] as Dictionary
	var new_machines: Dictionary = migrated_data["machines"] as Dictionary
	for stage: MachineRuntime in _production_line.get_stages():
		var machine_key: String = String(stage.get_id())
		if not old_machines.has(machine_key) or typeof(old_machines[machine_key]) != TYPE_DICTIONARY:
			return {}
		var old_state: Dictionary = old_machines[machine_key] as Dictionary
		if not old_state.has("enabled") or not old_state.has("capacity_multiplier"):
			return {}
		var new_state: Dictionary = new_machines[machine_key] as Dictionary
		new_state["enabled"] = old_state["enabled"]
		var legacy_multiplier: Variant = old_state["capacity_multiplier"]
		if typeof(legacy_multiplier) != TYPE_INT and typeof(legacy_multiplier) != TYPE_FLOAT:
			return {}
		var runtime_multiplier: float = float(legacy_multiplier)
		if not is_finite(runtime_multiplier) or runtime_multiplier < 0.0:
			return {}

		if stage.get_id() == BASIC_SCANNER_ID:
			runtime_multiplier = 1.0
		elif stage.get_id() == BASIC_SORTER_ID and is_equal_approx(runtime_multiplier, 2.0):
			runtime_multiplier = 1.0
			if not owned_upgrade_ids.has(UpgradeCatalog.SORTER_MOTOR_I_ID):
				owned_upgrade_ids.append(UpgradeCatalog.SORTER_MOTOR_I_ID)
		new_state["runtime_capacity_multiplier"] = runtime_multiplier

	migrated_data["owned_upgrade_ids"] = owned_upgrade_ids
	return migrated_data if is_valid_production_save_data(migrated_data) else {}


func _migrate_version_two_scanner_only(save_data: Dictionary) -> Dictionary:
	var required_fields: Array[String] = [
		"scanner_enabled",
		"scanner_upgrades",
		"incoming_item_buffer",
		"processed_item_fraction",
	]
	for field: String in required_fields:
		if not save_data.has(field):
			return {}
	if typeof(save_data["scanner_enabled"]) != TYPE_BOOL:
		return {}
	if not _is_non_negative_number(save_data["incoming_item_buffer"]):
		return {}
	if not UpgradeCatalog.are_valid_owned_upgrade_ids(save_data["scanner_upgrades"]):
		return {}

	var owned_upgrade_ids: Array[String] = _array_to_strings(save_data["scanner_upgrades"])
	for upgrade_id: String in owned_upgrade_ids:
		var definition: UpgradeDefinition = UpgradeCatalog.get_definition(upgrade_id)
		if definition == null or definition.target_machine_id != BASIC_SCANNER_ID:
			return {}

	var migrated_data: Dictionary = get_default_production_save_data()
	var scanner_state: Dictionary = migrated_data["machines"][String(BASIC_SCANNER_ID)]
	scanner_state["enabled"] = save_data["scanner_enabled"]
	migrated_data["fractional_progress"] = save_data["processed_item_fraction"]
	migrated_data["owned_upgrade_ids"] = owned_upgrade_ids
	return migrated_data if is_valid_production_save_data(migrated_data) else {}


func _array_to_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry: Variant in value:
		if typeof(entry) != TYPE_STRING:
			return []
		result.append(entry)
	return result


func _is_non_negative_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) >= 0.0


func _commit_production(items_processed: int) -> int:
	if items_processed <= 0:
		return 0

	var credits_earned: int = items_processed * PROTOTYPE_CREDITS_PER_ITEM
	GameState.register_processed_items(items_processed)
	Economy.add_money(credits_earned)
	return credits_earned
