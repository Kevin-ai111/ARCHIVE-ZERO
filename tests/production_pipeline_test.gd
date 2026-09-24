extends Node

const EPSILON: float = 0.00001
const BASIC_SCANNER_ID: StringName = &"basic_scanner"
const BASIC_SORTER_ID: StringName = &"basic_sorter"
var _failures: int = 0
var _original_save_exists: bool = false
var _original_save_contents: String = ""
var _game_state: Variant
var _simulation_manager: Variant
var _save_manager: Variant


func _ready() -> void:
	_game_state = get_tree().root.get_node_or_null("GameState")
	_simulation_manager = get_tree().root.get_node_or_null("SimulationManager")
	_save_manager = get_tree().root.get_node_or_null("SaveManager")
	if _game_state == null or _simulation_manager == null or _save_manager == null:
		push_error("Required project Autoloads are unavailable to the test runner.")
		get_tree().quit(1)
		return
	call_deferred("_run_tests")


func _run_tests() -> void:
	_backup_save()
	_test_initial_pipeline()
	_test_sorter_multiplier()
	_test_disabled_stage()
	_test_hundred_second_simulation()
	_test_fractional_continuity()
	_test_runtime_state_round_trip()
	_test_scanner_upgrade_purchase()
	_test_scanner_upgrade_rejections()
	_test_scanner_multiplier_is_upgrade_owned()
	_test_save_load_upgrade_state()
	_test_current_save_normalizes_scanner_multiplier()
	_test_duplicate_upgrade_save_is_rejected()
	_test_legacy_feature_save_migration()
	_test_version_one_save_migration()
	_restore_save_backup()

	if _failures == 0:
		print("Production pipeline tests passed.")
		get_tree().quit(0)
	else:
		push_error("Production pipeline tests failed: %d" % _failures)
		get_tree().quit(1)


func _test_initial_pipeline() -> void:
	var line: ProductionLine = ProductionLineFactory.create_initial_line()
	_expect_equal(line.get_stages().size(), 4, "Initial line loads four definitions")
	_expect_close(line.get_effective_throughput(), 0.75, "Initial throughput")
	_expect_equal(line.get_bottleneck().get_id(), BASIC_SORTER_ID, "Initial bottleneck")
	_expect_close(line.get_stage_utilization(&"receiving_desk"), 0.60, "Receiving utilization")
	_expect_close(line.get_stage_utilization(BASIC_SCANNER_ID), 0.75, "Scanner utilization")
	_expect_close(line.get_stage_utilization(BASIC_SORTER_ID), 1.0, "Sorter utilization")
	_expect_close(line.get_stage_utilization(&"archive_intake"), 0.375, "Intake utilization")


func _test_sorter_multiplier() -> void:
	var line: ProductionLine = ProductionLineFactory.create_initial_line()
	_expect_true(
		line.set_stage_capacity_multiplier(BASIC_SORTER_ID, 2.0), "Sorter accepts x2 modifier"
	)
	_expect_close(line.get_stage_capacity(BASIC_SORTER_ID), 1.50, "Modified sorter capacity")
	_expect_close(line.get_effective_throughput(), 1.0, "Throughput after sorter modifier")
	_expect_equal(line.get_bottleneck().get_id(), BASIC_SCANNER_ID, "Updated bottleneck")


func _test_disabled_stage() -> void:
	var line: ProductionLine = ProductionLineFactory.create_initial_line()
	_expect_true(line.set_stage_enabled(BASIC_SCANNER_ID, false), "Scanner can be disabled")
	_expect_close(line.get_effective_throughput(), 0.0, "Disabled scanner stops production")
	_expect_close(line.get_stage_utilization(BASIC_SORTER_ID), 0.0, "Stopped line utilization")
	_expect_equal(line.simulate_elapsed(100.0), 0, "Stopped line produces no items")
	_expect_true(line.set_stage_enabled(BASIC_SCANNER_ID, true), "Scanner can be re-enabled")
	_expect_close(line.get_effective_throughput(), 0.75, "Re-enabled line resumes")


func _test_hundred_second_simulation() -> void:
	var line: ProductionLine = ProductionLineFactory.create_initial_line()
	var completed_items: int = line.simulate_elapsed(100.0)
	var credits: int = completed_items * _simulation_manager.PROTOTYPE_CREDITS_PER_ITEM
	_expect_equal(completed_items, 75, "100 seconds completes 75 items")
	_expect_equal(credits, 150, "75 items award 150 credits")
	_expect_close(line.get_fractional_progress(), 0.0, "100 seconds leaves no fraction")


func _test_fractional_continuity() -> void:
	var fractional_line: ProductionLine = ProductionLineFactory.create_initial_line()
	_expect_equal(fractional_line.simulate_elapsed(1.0), 0, "First second completes no item")
	_expect_close(fractional_line.get_fractional_progress(), 0.75, "First second keeps fraction")
	_expect_equal(fractional_line.simulate_elapsed(1.0), 1, "Second second completes one item")
	_expect_close(fractional_line.get_fractional_progress(), 0.50, "Second fraction is retained")

	var small_steps_line: ProductionLine = ProductionLineFactory.create_initial_line()
	var small_steps_total: int = 0
	for _step: int in range(100):
		small_steps_total += small_steps_line.simulate_elapsed(1.0)

	var large_step_line: ProductionLine = ProductionLineFactory.create_initial_line()
	var large_step_total: int = large_step_line.simulate_elapsed(100.0)
	_expect_equal(small_steps_total, large_step_total, "Small and large elapsed steps agree")
	_expect_close(
		small_steps_line.get_fractional_progress(),
		large_step_line.get_fractional_progress(),
		"Small and large elapsed steps retain the same fraction"
	)


func _test_runtime_state_round_trip() -> void:
	var line: ProductionLine = ProductionLineFactory.create_initial_line()
	line.simulate_elapsed(1.0)
	line.set_stage_enabled(BASIC_SCANNER_ID, false)
	line.set_stage_capacity_multiplier(BASIC_SORTER_ID, 2.0)
	var saved_state: Dictionary = line.get_save_data()

	line.set_stage_enabled(BASIC_SCANNER_ID, true)
	line.set_stage_capacity_multiplier(BASIC_SORTER_ID, 1.0)
	_expect_true(line.restore_save_data(saved_state), "Production state restores")
	_expect_true(not line.get_stage(BASIC_SCANNER_ID).is_enabled(), "Scanner state restores")
	_expect_close(
		line.get_stage(BASIC_SORTER_ID).get_capacity_multiplier(), 2.0, "Sorter modifier restores"
	)
	_expect_close(line.get_fractional_progress(), 0.75, "Fractional progress restores")


func _test_scanner_upgrade_purchase() -> void:
	_reset_manager_state(50)
	_expect_true(
		_simulation_manager.purchase_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"Affordable scanner upgrade can be purchased"
	)
	_expect_equal(_game_state.get_money(), 0, "Upgrade purchase spends through Economy")
	_expect_close(
		_simulation_manager.get_scanner_throughput_multiplier(), 1.25, "Upgrade applies multiplier"
	)
	_expect_close(_simulation_manager.get_scanner_capacity_per_minute(), 75.0, "Scanner reaches 75/min")
	_simulation_manager.set_machine_capacity_multiplier(BASIC_SORTER_ID, 2.0)
	var result: Dictionary = _simulation_manager.simulate_elapsed(60.0)
	_expect_equal(result["items_processed"], 75, "Upgraded line can process 75 items/min")


func _test_scanner_upgrade_rejections() -> void:
	_reset_manager_state(49)
	_expect_true(
		not _simulation_manager.purchase_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"Unaffordable scanner upgrade is rejected"
	)
	_expect_equal(_game_state.get_money(), 49, "Rejected purchase does not spend credits")

	_reset_manager_state(100)
	_expect_true(
		_simulation_manager.purchase_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"First scanner upgrade purchase succeeds"
	)
	_expect_true(
		not _simulation_manager.purchase_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"Duplicate scanner upgrade purchase is rejected"
	)
	_expect_equal(_game_state.get_money(), 50, "Duplicate purchase does not spend credits")
	_expect_close(
		_simulation_manager.get_scanner_throughput_multiplier(),
		1.25,
		"Duplicate purchase does not stack the multiplier"
	)


func _test_scanner_multiplier_is_upgrade_owned() -> void:
	_reset_manager_state()
	_expect_true(
		not _simulation_manager.set_machine_capacity_multiplier(BASIC_SCANNER_ID, 2.0),
		"Generic modifier cannot override upgrade-managed Scanner capacity"
	)
	_expect_close(
		_simulation_manager.get_scanner_throughput_multiplier(),
		1.0,
		"Rejected Scanner modifier leaves base capacity unchanged"
	)


func _test_save_load_upgrade_state() -> void:
	_reset_manager_state(50)
	_simulation_manager.purchase_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID)
	_simulation_manager.simulate_elapsed(1.0)
	_simulation_manager.set_machine_enabled(BASIC_SCANNER_ID, false)
	_simulation_manager.set_machine_capacity_multiplier(BASIC_SORTER_ID, 2.0)
	_expect_true(_save_manager.save_game(), "Production state saves")

	_reset_manager_state()
	_expect_true(_save_manager.load_game(), "Production state loads")
	_expect_true(
		_simulation_manager.owns_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"Load restores upgrade ownership"
	)
	_expect_true(not _simulation_manager.is_basic_scanner_enabled(), "Load restores scanner state")
	_expect_close(
		_simulation_manager.get_scanner_throughput_multiplier(), 1.25, "Load reapplies upgrade"
	)
	_expect_close(
		_simulation_manager.get_production_line().get_stage(BASIC_SORTER_ID).get_capacity_multiplier(),
		2.0,
		"Load preserves current-main machine state"
	)
	_expect_close(
		_simulation_manager.get_production_line().get_fractional_progress(),
		0.75,
		"Load preserves fractional production progress"
	)


func _test_current_save_normalizes_scanner_multiplier() -> void:
	var production_data: Dictionary = _simulation_manager.get_default_production_save_data()
	production_data["scanner_upgrades"] = [ScannerUpgrades.MOTOR_I_ID]
	production_data["machines"][String(BASIC_SCANNER_ID)]["capacity_multiplier"] = 4.0
	production_data["machines"][String(BASIC_SORTER_ID)]["capacity_multiplier"] = 2.0
	var save_data: Dictionary = _make_complete_save(production_data)
	_expect_true(_write_save(save_data), "Current save with stale Scanner modifier can be prepared")

	_reset_manager_state()
	_expect_true(_save_manager.load_game(), "Current save normalizes its derived Scanner modifier")
	_expect_true(
		_simulation_manager.owns_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"Normalized save preserves Scanner upgrade ownership"
	)
	_expect_close(
		_simulation_manager.get_scanner_throughput_multiplier(),
		1.25,
		"Owned upgrades determine restored Scanner multiplier"
	)
	_expect_close(
		_simulation_manager.get_production_line().get_stage(BASIC_SORTER_ID).get_capacity_multiplier(),
		2.0,
		"Normalization does not alter unrelated machine modifiers"
	)


func _test_duplicate_upgrade_save_is_rejected() -> void:
	var production_data: Dictionary = _simulation_manager.get_default_production_save_data()
	production_data["scanner_upgrades"] = [
		ScannerUpgrades.MOTOR_I_ID,
		ScannerUpgrades.MOTOR_I_ID,
	]
	var save_data: Dictionary = _make_complete_save(production_data)
	_expect_true(_write_save(save_data), "Duplicate-upgrade save can be prepared")

	_reset_manager_state(50)
	_simulation_manager.purchase_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID)
	_expect_true(not _save_manager.load_game(), "Duplicate-upgrade save is rejected")
	_expect_true(
		_simulation_manager.owns_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"Rejected save leaves existing upgrade ownership unchanged"
	)
	_expect_close(
		_simulation_manager.get_scanner_throughput_multiplier(),
		1.25,
		"Rejected save cannot apply the same upgrade twice"
	)


func _test_legacy_feature_save_migration() -> void:
	var legacy_save: Dictionary = {
		"save_version": 2,
		"money": 10,
		"total_money_earned": 60,
		"total_processed_items": 25,
		"total_playtime": 12.5,
		"save_timestamp": 1,
		"production": {
			"scanner_enabled": false,
			"scanner_upgrades": [ScannerUpgrades.MOTOR_I_ID],
			"incoming_item_buffer": 4.0,
			"processed_item_fraction": 0.5,
		},
	}
	if not _write_save(legacy_save):
		_expect_true(false, "Legacy feature save can be prepared")
		return

	_reset_manager_state()
	_expect_true(_save_manager.load_game(), "Legacy feature save migrates")
	_expect_true(not _simulation_manager.is_basic_scanner_enabled(), "Migration restores scanner state")
	_expect_true(
		_simulation_manager.owns_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"Migration restores upgrade ownership"
	)
	_expect_close(
		_simulation_manager.get_production_line().get_fractional_progress(),
		0.5,
		"Migration preserves fractional progress"
	)
	_expect_close(
		_simulation_manager.get_scanner_throughput_multiplier(),
		1.25,
		"Legacy ownership restores exactly one Scanner modifier"
	)


func _test_version_one_save_migration() -> void:
	var legacy_save: Dictionary = {
		"save_version": 1,
		"money": 12,
		"total_money_earned": 40,
		"total_processed_items": 14,
		"total_playtime": 8.0,
		"save_timestamp": 1,
	}
	if not _write_save(legacy_save):
		_expect_true(false, "Version-one save can be prepared")
		return

	_reset_manager_state(50)
	_simulation_manager.purchase_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID)
	_expect_true(_save_manager.load_game(), "Version-one save migrates to default production state")
	_expect_equal(_game_state.get_money(), 12, "Version-one migration restores base game state")
	_expect_true(
		not _simulation_manager.owns_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"Version-one migration starts without Scanner upgrades"
	)
	_expect_close(
		_simulation_manager.get_scanner_throughput_multiplier(),
		1.0,
		"Version-one migration restores base Scanner multiplier"
	)
	_expect_close(
		_simulation_manager.get_effective_throughput(),
		0.75,
		"Version-one migration restores the default production line"
	)


func _reset_manager_state(money: int = 0) -> void:
	_game_state.restore_state(money, money, 0, 0.0)
	_simulation_manager.restore_production_save_data(
		_simulation_manager.get_default_production_save_data()
	)


func _backup_save() -> void:
	_original_save_exists = _save_manager.has_save()
	if not _original_save_exists:
		return
	var save_file: FileAccess = FileAccess.open(_save_manager.SAVE_PATH, FileAccess.READ)
	if save_file != null:
		_original_save_contents = save_file.get_as_text()
		save_file.close()


func _restore_save_backup() -> void:
	_save_manager.delete_save()
	if not _original_save_exists:
		return
	var save_file: FileAccess = FileAccess.open(_save_manager.SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(_original_save_contents)
		save_file.close()


func _make_complete_save(production_data: Dictionary) -> Dictionary:
	return {
		"save_version": _save_manager.SAVE_VERSION,
		"money": 0,
		"total_money_earned": 0,
		"total_processed_items": 0,
		"total_playtime": 0.0,
		"save_timestamp": 1,
		"production_line": production_data,
	}


func _write_save(save_data: Dictionary) -> bool:
	var save_file: FileAccess = FileAccess.open(_save_manager.SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		return false
	save_file.store_string(JSON.stringify(save_data))
	var write_error: Error = save_file.get_error()
	save_file.close()
	return write_error == OK


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("%s: expected %s, got %s" % [message, expected, actual])


func _expect_close(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > EPSILON:
		_failures += 1
		push_error("%s: expected %.5f, got %.5f" % [message, expected, actual])
