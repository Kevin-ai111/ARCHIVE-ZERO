extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_scanner_throughput_and_credit_production()
	_test_disabled_scanner()
	_test_upgrade_purchase_and_modifier()
	_test_save_load_upgrade_state()
	SaveManager.delete_save()
	if _failures == 0:
		print("Production pipeline tests passed.")
	quit(_failures)


func _reset_state(money: int = 0) -> void:
	GameState.restore_state(money, money, 0, 0.0)
	SimulationManager.set_incoming_items_per_minute(
		SimulationManager.DEFAULT_INCOMING_ITEMS_PER_MINUTE
	)
	SimulationManager.set_credits_per_processed_item(
		SimulationManager.DEFAULT_CREDITS_PER_PROCESSED_ITEM
	)
	SimulationManager.restore_production_state(
		{
			"scanner_enabled": true,
			"scanner_upgrades": [],
			"incoming_item_buffer": 0.0,
			"processed_item_fraction": 0.0,
		}
	)


func _test_scanner_throughput_and_credit_production() -> void:
	_reset_state()
	var result: Dictionary = SimulationManager.simulate_elapsed(60.0)
	_expect_equal(result["items_processed"], 60, "scanner limits one minute to base capacity")
	_expect_equal(result["credits_earned"], 120, "processed items generate credits")
	_expect_equal(GameState.get_money(), 120, "credits use authoritative game state")


func _test_disabled_scanner() -> void:
	_reset_state()
	SimulationManager.set_basic_scanner_enabled(false)
	var result: Dictionary = SimulationManager.simulate_elapsed(60.0)
	_expect_equal(result["items_processed"], 0, "disabled scanner produces no output")
	_expect_equal(GameState.get_money(), 0, "disabled scanner produces no credits")


func _test_upgrade_purchase_and_modifier() -> void:
	_reset_state(50)
	_expect_true(
		SimulationManager.purchase_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"affordable scanner upgrade can be purchased"
	)
	_expect_equal(GameState.get_money(), 0, "upgrade purchase spends through Economy")
	_expect_approx(
		SimulationManager.get_scanner_throughput_multiplier(), 1.25, "upgrade applies multiplier"
	)
	var result: Dictionary = SimulationManager.simulate_elapsed(60.0)
	_expect_equal(result["items_processed"], 75, "upgrade increases scanner throughput")


func _test_save_load_upgrade_state() -> void:
	_reset_state(50)
	SimulationManager.purchase_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID)
	SimulationManager.set_basic_scanner_enabled(false)
	_expect_true(SaveManager.save_game(), "production state saves")
	_reset_state()
	_expect_true(SaveManager.load_game(), "production state loads")
	_expect_true(
		SimulationManager.owns_scanner_upgrade(ScannerUpgrades.MOTOR_I_ID),
		"load restores upgrade ownership"
	)
	_expect_true(not SimulationManager.is_basic_scanner_enabled(), "load restores scanner state")
	_expect_approx(
		SimulationManager.get_scanner_throughput_multiplier(), 1.25, "load reapplies upgrade"
	)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("%s: expected %s, got %s" % [message, expected, actual])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error("%s: expected true" % message)


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures += 1
		push_error("%s: expected %f, got %f" % [message, expected, actual])
