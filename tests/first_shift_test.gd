extends Node

const EPSILON := 0.00001
const SCANNER_UPGRADE := "scanner_motor_1"
const SORTER_UPGRADE := "sorter_motor_1"

var _checks := 0
var _failures := 0
var _original_save_exists := false
var _original_save_contents := ""


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	call_deferred("_run")


func _run() -> void:
	_backup_save()
	_test_first_shift_save_schema()
	await _test_minimum_path_and_authority()
	await _test_perfect_path_and_upgrade_unlock()
	await _test_save_restore_checkpoints()
	_test_legacy_migrations()
	_restore_save_backup()
	if _failures == 0:
		print("First Shift tests passed: %d checks." % _checks)
	else:
		push_error("First Shift tests failed: %d/%d" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_first_shift_save_schema() -> void:
	_check(FirstShiftManager.is_valid_first_shift_save_data(FirstShiftManager.get_default_first_shift_save_data()), "Fresh First Shift v1 payload is valid")
	_check(FirstShiftManager.is_valid_first_shift_save_data(FirstShiftManager.get_legacy_complete_save_data()), "Legacy-complete First Shift v1 payload is valid")
	var invalid: Array[Dictionary] = []
	var payload := FirstShiftManager.get_default_first_shift_save_data()
	var extra := payload.duplicate(true)
	extra["extra"] = true
	invalid.append(extra)
	var bad_case := payload.duplicate(true)
	bad_case.claimed_reward_case_ids = ["CASE_0010"]
	invalid.append(bad_case)
	var duplicate := payload.duplicate(true)
	duplicate.claimed_reward_case_ids = ["CASE_0001", "CASE_0001"]
	invalid.append(duplicate)
	var wrong_gate := payload.duplicate(true)
	wrong_gate.phase = "SCANNER_READY"
	wrong_gate.claimed_reward_case_ids = ["CASE_0001"]
	invalid.append(wrong_gate)
	var mismatched_complete := payload.duplicate(true)
	mismatched_complete.completed = true
	invalid.append(mismatched_complete)
	var partial_complete := FirstShiftManager.get_legacy_complete_save_data()
	partial_complete.claimed_reward_case_ids = ["CASE_0001"]
	invalid.append(partial_complete)
	for candidate: Dictionary in invalid:
		var before := FirstShiftManager.get_first_shift_save_data()
		_check(not FirstShiftManager.is_valid_first_shift_save_data(candidate), "Malformed First Shift v1 payload rejected")
		_check(not FirstShiftManager.restore_first_shift_save_data(candidate), "Malformed First Shift v1 restore rejected")
		_check(FirstShiftManager.get_first_shift_save_data() == before, "Malformed First Shift restore is atomic")


func _test_minimum_path_and_authority() -> void:
	_check(FirstShiftManager.start_new_game(), "Fresh game bootstrap succeeds")
	var expected_queue := [
		&"CASE_0001", &"CASE_0002", &"CASE_0003", &"CASE_0004", &"CASE_0005", &"CASE_0006",
		&"CASE_0007", &"CASE_0008", &"CASE_0009", &"CASE_0011",
		&"CASE_0012", &"CASE_0013", &"CASE_0014", &"CASE_0015",
	]
	_check(FirstShiftManager.get_phase() == FirstShiftManager.Phase.MANUAL_CASES, "Fresh phase is MANUAL_CASES")
	_check(CaseManager.get_queue_snapshot() == expected_queue, "Exact fourteen-Case FIFO queue")
	_check(not CaseManager.get_queue_snapshot().has(&"CASE_0010"), "CASE_0010 excluded from First Shift")
	_check(GameState.get_money() == 0 and GameState.get_total_processed_items() == 0, "Fresh economy and aggregate items are zero")
	_check(CommissioningManager.get_stage() == CommissioningManager.Stage.MANUAL_SHIFT, "Fresh commissioning stage is MANUAL_SHIFT")
	_check(_enabled(&"receiving_desk") and not _enabled(&"basic_scanner") and not _enabled(&"basic_sorter") and not _enabled(&"archive_intake"), "Only Receiving runtime is enabled")
	_check(_close(SimulationManager.get_effective_throughput(), 0.0), "Manual aggregate throughput is zero")
	_check(not CommissioningManager.is_machine_commissioned(&"basic_scanner") and not _enabled(&"basic_scanner"), "Uncommissioned Scanner is dormant, not a commissioned fault")
	var first_queue := CaseManager.get_queue_snapshot()
	_check(FirstShiftManager.ensure_fresh_game_initialized(), "Repeated bootstrap accepted")
	_check(CaseManager.get_queue_snapshot() == first_queue, "Repeated bootstrap does not duplicate queue")
	_check(SimulationManager.purchase_upgrade(SCANNER_UPGRADE) == SimulationManager.PurchaseResult.FIRST_SHIFT_LOCKED, "Authoritative upgrade guard rejects pre-completion purchase")

	var long_stop := SimulationManager.simulate_elapsed(300.0)
	_check(long_stop.items_processed == 0 and long_stop.credits_earned == 0, "Three hundred blocked seconds produce no aggregate output")
	_check(GameState.get_money() == 0 and GameState.get_total_processed_items() == 0, "Blocked time changes no aggregate authority")
	_check(_close(SimulationManager.get_production_line().get_fractional_progress(), 0.0), "Blocked time accumulates no fractional backlog")

	for case_id: StringName in FirstShiftManager.MANUAL_CASE_IDS:
		await _process_case(case_id, false)
	_check(GameState.get_money() == 24, "Six wrong manual classifications award 24 Credits")
	_check(FirstShiftManager.get_phase() == FirstShiftManager.Phase.SCANNER_READY, "Six manual archives open Scanner gate")
	_check(not FirstShiftManager.can_activate_next_case(), "CASE_0007 locked behind Scanner commissioning")
	_check(FirstShiftManager.commission_sorter() == FirstShiftManager.CommissionResult.WRONG_PHASE, "Out-of-order Sorter commissioning rejected")
	GameState.restore_state(15, 24, 0, 0.0)
	_check(FirstShiftManager.commission_scanner() == FirstShiftManager.CommissionResult.INSUFFICIENT_FUNDS, "Insufficient Scanner balance is rejected")
	_check(GameState.get_money() == 15 and CommissioningManager.get_stage() == CommissioningManager.Stage.MANUAL_SHIFT, "Rejected commissioning is atomic")
	GameState.restore_state(24, 24, 0, 0.0)
	_check(FirstShiftManager.commission_scanner() == FirstShiftManager.CommissionResult.SUCCESS, "Scanner commissioning succeeds")
	_check(GameState.get_money() == 8, "Scanner deducts exactly 16 Credits")
	_check(FirstShiftManager.commission_scanner() == FirstShiftManager.CommissionResult.ALREADY_COMMISSIONED, "Scanner double commissioning rejected")
	_check(GameState.get_money() == 8, "Scanner double action cannot double-charge")
	_check(CommissioningManager.get_stage() == CommissioningManager.Stage.SCANNER_ONLINE and _enabled(&"basic_scanner"), "Scanner authority and runtime advance together")
	_check(_close(SimulationManager.get_effective_throughput(), 0.0), "Scanner phase aggregate throughput remains zero")

	for case_id: StringName in FirstShiftManager.SCANNER_CASE_IDS:
		_check(FirstShiftManager.activate_next_case() != null, "Scanner phase activates FIFO " + String(case_id))
		_check(CaseManager.get_active_case().get_case_id() == case_id, "Scanner FIFO identity " + String(case_id))
		await _settle()
		_check(CaseManager.get_active_case().get_state() == CaseProgress.State.INSPECTED, "Scanner auto-inspects " + String(case_id))
		_check(CaseManager.classify_active_case(_wrong_category(case_id)), "Player classification retained in Scanner phase")
		_check(CaseManager.archive_active_case(), "Scanner-assisted Case archives")
	_check(GameState.get_money() == 24, "Four wrong Scanner-assisted Cases add 16 Credits")
	_check(FirstShiftManager.get_phase() == FirstShiftManager.Phase.SORTER_READY, "Scanner block opens Sorter gate")
	_check(not FirstShiftManager.can_activate_next_case(), "CASE_0012 locked behind Sorter commissioning")
	_check(FirstShiftManager.commission_sorter() == FirstShiftManager.CommissionResult.SUCCESS, "Sorter commissioning succeeds")
	_check(GameState.get_money() == 6, "Sorter deducts exactly 18 Credits")
	_check(FirstShiftManager.commission_sorter() == FirstShiftManager.CommissionResult.ALREADY_COMMISSIONED, "Sorter double commissioning rejected")
	_check(GameState.get_money() == 6, "Sorter double action cannot double-charge")
	_check(CommissioningManager.get_stage() == CommissioningManager.Stage.SORTER_ONLINE and _enabled(&"basic_sorter"), "Sorter authority and runtime advance together")
	_check(_close(SimulationManager.get_effective_throughput(), 0.0), "Sorter phase aggregate throughput remains zero")

	for case_id: StringName in FirstShiftManager.SORTER_CASE_IDS:
		_check(FirstShiftManager.activate_next_case() != null, "Sorter phase activates FIFO " + String(case_id))
		await _settle()
		var progress := CaseManager.get_active_case()
		_check(progress != null and progress.get_state() == CaseProgress.State.CLASSIFIED, "Sorter auto-inspects and classifies " + String(case_id))
		_check(progress.get_selected_category_id() == CaseManager.get_case_definition(case_id).expected_category_id, "Sorter uses expected authored category")
		_check(CaseManager.archive_active_case(), "Player releases Sorter-assisted Case")
	_check(GameState.get_money() == 26, "Four correctly automated Sorter Cases produce 26-Credit Intake balance")
	_check(FirstShiftManager.get_phase() == FirstShiftManager.Phase.INTAKE_READY, "Sorter block opens Intake gate")
	_check(GameState.get_total_processed_items() == 0, "Fourteen concrete Cases create zero aggregate items")
	_check(FirstShiftManager.get_claimed_reward_case_ids().size() == 14, "Every First Shift reward claimed once")
	var before_duplicate := GameState.get_money()
	FirstShiftManager._on_case_progress_changed(&"CASE_0015")
	FirstShiftManager._on_case_progress_changed(&"CASE_0015")
	_check(GameState.get_money() == before_duplicate, "Repeated archive signal cannot duplicate reward")
	_check(FirstShiftManager.commission_intake() == FirstShiftManager.CommissionResult.SUCCESS, "Archive Intake commissioning succeeds")
	_check(GameState.get_money() == 6, "Minimum economy path finishes with 6 Credits")
	_check(FirstShiftManager.commission_intake() == FirstShiftManager.CommissionResult.ALREADY_COMMISSIONED, "Intake double commissioning rejected")
	_check(GameState.get_money() == 6, "Intake double action cannot double-charge")
	_check(FirstShiftManager.is_complete() and CommissioningManager.get_stage() == CommissioningManager.Stage.FULL_LINE_ONLINE, "First Shift completes at authoritative Full Line")
	_check(_enabled(&"receiving_desk") and _enabled(&"basic_scanner") and _enabled(&"basic_sorter") and _enabled(&"archive_intake"), "All four runtimes enabled at completion")
	_check(_close(SimulationManager.get_effective_throughput(), 0.75), "Full Line derives 0.75 items/s")
	var first_second := SimulationManager.simulate_elapsed(1.0)
	_check(first_second.items_processed == 0 and _close(SimulationManager.get_production_line().get_fractional_progress(), 0.75), "First post-commissioning second is ordinary 0.75 progress with no backlog burst")
	var second_second := SimulationManager.simulate_elapsed(1.0)
	_check(second_second.items_processed == 1 and second_second.credits_earned == 2, "Second ordinary second completes one aggregate item")


func _test_perfect_path_and_upgrade_unlock() -> void:
	_check(FirstShiftManager.start_new_game(), "Perfect-path fresh game starts")
	for case_id: StringName in FirstShiftManager.MANUAL_CASE_IDS:
		await _process_case(case_id, true)
	_check(GameState.get_money() == 30, "Six correct manual Cases award 30 Credits")
	_check(FirstShiftManager.commission_scanner() == FirstShiftManager.CommissionResult.SUCCESS, "Perfect path commissions Scanner")
	for case_id: StringName in FirstShiftManager.SCANNER_CASE_IDS:
		await _process_case(case_id, true)
	_check(FirstShiftManager.commission_sorter() == FirstShiftManager.CommissionResult.SUCCESS, "Perfect path commissions Sorter")
	for case_id: StringName in FirstShiftManager.SORTER_CASE_IDS:
		await _process_case(case_id, true)
	_check(FirstShiftManager.commission_intake() == FirstShiftManager.CommissionResult.SUCCESS, "Perfect path commissions Intake")
	_check(GameState.get_money() == 16, "Perfect economy path finishes with 16 Credits")
	_check(FirstShiftManager.is_upgrade_purchasing_unlocked(), "Upgrade purchasing unlocks after completion")
	GameState.add_money(100)
	_check(SimulationManager.purchase_upgrade(SCANNER_UPGRADE) == SimulationManager.PurchaseResult.SUCCESS, "Existing upgrade purchase succeeds after First Shift")
	_check(SimulationManager.owns_upgrade(SCANNER_UPGRADE), "Purchased upgrade ownership remains authoritative")
	SimulationManager.restore_production_save_data(SimulationManager.get_default_production_save_data())
	GameState.restore_state(0, 0, 0, 0.0)
	var hundred := SimulationManager.simulate_elapsed(100.0)
	_check(hundred.items_processed == 75 and hundred.credits_earned == 150, "Full Line 100-second invariant remains 75 items / 150 Credits")
	_check(_close(SimulationManager.get_production_line().get_fractional_progress(), 0.0), "Full Line 100-second fraction remains zero")


func _test_save_restore_checkpoints() -> void:
	FirstShiftManager.start_new_game()
	await _process_case(&"CASE_0001", true)
	await _round_trip("mid-Manual")
	for case_id: StringName in [&"CASE_0002", &"CASE_0003", &"CASE_0004", &"CASE_0005", &"CASE_0006"]:
		await _process_case(case_id, true)
	await _round_trip("Scanner gate")
	FirstShiftManager.commission_scanner()
	await _process_case(&"CASE_0007", true)
	await _round_trip("mid-Scanner")
	for case_id: StringName in [&"CASE_0008", &"CASE_0009", &"CASE_0011"]:
		await _process_case(case_id, true)
	await _round_trip("Sorter gate")
	FirstShiftManager.commission_sorter()
	await _process_case(&"CASE_0012", true)
	await _round_trip("mid-Sorter")
	for case_id: StringName in [&"CASE_0013", &"CASE_0014", &"CASE_0015"]:
		await _process_case(case_id, true)
	await _round_trip("Intake gate")
	FirstShiftManager.commission_intake()
	await _round_trip("COMPLETE")
	var queue_before := CaseManager.get_queue_snapshot()
	_check(FirstShiftManager.ensure_fresh_game_initialized(), "Initialize after load is accepted")
	_check(CaseManager.get_queue_snapshot() == queue_before, "Load then initialize remains idempotent")
	_check(SaveManager.SAVE_VERSION == 4 and CaseManager.CASE_SAVE_VERSION == 1 and CommissioningManager.COMMISSIONING_SAVE_VERSION == 1 and FirstShiftManager.FIRST_SHIFT_SAVE_VERSION == 1, "Save contracts are Global v4 / Case v1 / Commissioning v1 / First Shift v1")


func _test_legacy_migrations() -> void:
	var base := {
		"money": 37, "total_money_earned": 91, "total_processed_items": 23,
		"total_playtime": 12.5, "save_timestamp": 1,
	}
	var v1 := base.duplicate(true)
	v1["save_version"] = 1
	_test_legacy_payload(v1, "Global v1")

	var v2_line := base.duplicate(true)
	v2_line["save_version"] = 2
	v2_line["production_line"] = _version_two_line()
	_test_legacy_payload(v2_line, "Global v2 line")

	var v2_scanner := base.duplicate(true)
	v2_scanner["save_version"] = 2
	v2_scanner["production"] = {
		"scanner_enabled": false, "scanner_upgrades": [SCANNER_UPGRADE],
		"incoming_item_buffer": 4.0, "processed_item_fraction": 0.5,
	}
	_test_legacy_payload(v2_scanner, "Global v2 Scanner-only")
	_check(SimulationManager.owns_upgrade(SCANNER_UPGRADE), "v2 Scanner-only migration preserves upgrade")

	FirstShiftManager.start_new_game()
	GameState.restore_state(37, 91, 23, 12.5)
	SimulationManager.restore_production_save_data(SimulationManager.get_default_production_save_data())
	SimulationManager.set_machine_enabled(&"archive_intake", false)
	var v3 := base.duplicate(true)
	v3["save_version"] = 3
	v3["production_line"] = SimulationManager.get_production_save_data()
	v3["case_save"] = CaseManager.get_case_save_data()
	v3["commissioning_save"] = CommissioningManager.get_commissioning_save_data()
	_test_legacy_payload(v3, "Global v3")
	_check(not _enabled(&"archive_intake"), "v3 migration preserves production runtime flags")
	_check(CaseManager.get_case_save_data() == v3.case_save, "v3 migration preserves valid Case v1 state")
	_check(CommissioningManager.get_commissioning_save_data() == v3.commissioning_save, "v3 migration preserves valid Commissioning v1 state")


func _test_legacy_payload(payload: Dictionary, label: String) -> void:
	_check(_write_save(payload), label + " fixture written")
	FirstShiftManager.start_new_game()
	GameState.restore_state(0, 0, 0, 0.0)
	_check(SaveManager.load_game(), label + " migrates to Global v4")
	_check(FirstShiftManager.is_complete() and FirstShiftManager.is_upgrade_purchasing_unlocked(), label + " skips First Shift and unlocks upgrades")
	_check(GameState.get_money() == 37 and GameState.get_total_money_earned() == 91 and GameState.get_total_processed_items() == 23, label + " preserves economy and processed items")


func _process_case(case_id: StringName, correct: bool) -> void:
	_check(FirstShiftManager.can_activate_next_case(), "Current phase exposes next Case " + String(case_id))
	var activated := FirstShiftManager.activate_next_case()
	_check(activated != null and activated.get_case_id() == case_id, "FIFO activates " + String(case_id))
	await _settle()
	var progress := CaseManager.get_active_case()
	if FirstShiftManager.get_phase() == FirstShiftManager.Phase.MANUAL_CASES:
		_check(progress.get_state() == CaseProgress.State.ACTIVE, "Manual Case remains ACTIVE pending player Inspect")
		_check(CaseManager.mark_active_case_inspected(), "Player inspects manual Case")
		progress = CaseManager.get_active_case()
	if progress.get_state() == CaseProgress.State.INSPECTED:
		var category := CaseManager.get_case_definition(case_id).expected_category_id if correct else _wrong_category(case_id)
		_check(CaseManager.classify_active_case(category), "Player classifies Case")
	else:
		_check(progress.get_state() == CaseProgress.State.CLASSIFIED, "Sorter assistance reaches CLASSIFIED")
	_check(CaseManager.archive_active_case(), "Player archives Case " + String(case_id))


func _round_trip(label: String) -> void:
	var before := _state_snapshot()
	_check(SaveManager.save_game(), label + " save succeeds")
	GameState.add_money(1)
	_check(SaveManager.load_game(), label + " load succeeds")
	await _settle()
	_check(_state_snapshot() == before, label + " restores all owned domains exactly")
	var money := GameState.get_money()
	for case_id: StringName in FirstShiftManager.get_claimed_reward_case_ids():
		FirstShiftManager._on_case_progress_changed(case_id)
	_check(GameState.get_money() == money, label + " replayed archive notifications are reward-idempotent")


func _state_snapshot() -> Dictionary:
	return {
		"money": GameState.get_money(),
		"earned": GameState.get_total_money_earned(),
		"items": GameState.get_total_processed_items(),
		"production": SimulationManager.get_production_save_data(),
		"cases": CaseManager.get_case_save_data(),
		"commissioning": CommissioningManager.get_commissioning_save_data(),
		"first_shift": FirstShiftManager.get_first_shift_save_data(),
	}


func _version_two_line() -> Dictionary:
	return {
		"fractional_progress": 0.25,
		"machines": {
			"receiving_desk": {"enabled": true, "capacity_multiplier": 1.0},
			"basic_scanner": {"enabled": true, "capacity_multiplier": 1.0},
			"basic_sorter": {"enabled": true, "capacity_multiplier": 1.0},
			"archive_intake": {"enabled": true, "capacity_multiplier": 1.0},
		},
		"scanner_upgrades": [],
	}


func _wrong_category(case_id: StringName) -> StringName:
	var expected := CaseManager.get_case_definition(case_id).expected_category_id
	for candidate: StringName in [&"PERS", &"ELEC", &"DOCS", &"BAG"]:
		if candidate != expected:
			return candidate
	return &""


func _enabled(machine_id: StringName) -> bool:
	return SimulationManager.get_production_line().get_stage(machine_id).is_enabled()


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _backup_save() -> void:
	_original_save_exists = SaveManager.has_save()
	if _original_save_exists:
		_original_save_contents = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)


func _restore_save_backup() -> void:
	SaveManager.delete_save()
	if _original_save_exists:
		var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_original_save_contents)
			file.close()


func _write_save(data: Dictionary) -> bool:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	var error := file.get_error()
	file.close()
	return error == OK


func _close(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= EPSILON


func _check(condition: bool, context: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + context)
