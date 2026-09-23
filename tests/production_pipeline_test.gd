extends SceneTree

const EPSILON: float = 0.00001
const BASIC_SCANNER_ID: StringName = &"basic_scanner"
const BASIC_SORTER_ID: StringName = &"basic_sorter"
const SimulationManagerScript = preload("res://scripts/simulation/simulation_manager.gd")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_initial_pipeline()
	_test_sorter_multiplier()
	_test_disabled_stage()
	_test_hundred_second_simulation()
	_test_fractional_continuity()
	_test_runtime_state_round_trip()

	if _failures == 0:
		print("Production pipeline tests passed.")
		quit(0)
	else:
		push_error("Production pipeline tests failed: %d" % _failures)
		quit(1)


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
	var credits: int = completed_items * SimulationManagerScript.PROTOTYPE_CREDITS_PER_ITEM
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
