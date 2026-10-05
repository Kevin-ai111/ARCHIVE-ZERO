extends Node

const SUPPORT := preload("res://tests/commissioning_test_support.gd")
var _checks := 0
var _failures := 0
var _signals: Array[int] = []


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	call_deferred("_run")


func _run() -> void:
	var startup := SUPPORT.authority_snapshot()
	_check(CommissioningManager.get_stage() == CommissioningManager.Stage.FULL_LINE_ONLINE, "Default full-line startup")
	_check(CommissioningManager.get_commissioning_save_data() == CommissioningManager.get_default_commissioning_save_data(), "Default save represents compatibility stage")
	_check(CaseManager.get_case_save_data() == CaseManager.get_default_case_save_data(), "No case auto initialization")
	_check(CommissioningManager.is_machine_commissioned(&"receiving_desk") and not CommissioningManager.is_machine_commissioned(&"unknown"), "Known machine mapping only")
	CommissioningManager.commissioning_stage_changed.connect(_on_stage)
	_reject(CommissioningManager.commission_scanner, "Scanner from full line")
	_reject(CommissioningManager.commission_sorter, "Sorter from full line")
	_reject(CommissioningManager.commission_intake, "Intake duplicate")
	_check(SUPPORT.authority_snapshot() == startup, "Startup/order checks do not mutate existing domains")
	for disabled: bool in [false, true]:
		SUPPORT.prepare_isolation_fixture(disabled)
		var before := SUPPORT.authority_snapshot()
		var count := _signals.size()
		_check(CommissioningManager.reset_to_manual_shift(), "Explicit reset accepted")
		_reject(CommissioningManager.reset_to_manual_shift, "Repeated manual reset is silent")
		_reject(CommissioningManager.commission_sorter, "Sorter before scanner")
		_reject(CommissioningManager.commission_intake, "Intake before sorter")
		_check(CommissioningManager.commission_scanner(), "Scanner forward step")
		_reject(CommissioningManager.commission_scanner, "Scanner duplicate")
		_reject(CommissioningManager.commission_intake, "Intake before sorter, scanner stage")
		_check(CommissioningManager.commission_sorter(), "Sorter forward step")
		_reject(CommissioningManager.commission_sorter, "Sorter duplicate")
		_reject(CommissioningManager.commission_scanner, "Scanner backward step")
		_check(CommissioningManager.commission_intake(), "Intake forward step")
		_reject(CommissioningManager.commission_intake, "Intake duplicate, final stage")
		_check(_signals.slice(count) == [0, 1, 2, 3], "Exactly one signal per actual ordered mutation")
		for key: String in before:
			_check(SUPPORT.authority_snapshot()[key] == before[key], "Commissioning authority isolation: " + key)
		print("Commissioning isolation %s: %s" % ["stopped" if disabled else "running", JSON.stringify(before)])
	_test_serialization()
	_check(SaveManager.SAVE_VERSION == 3 and CaseManager.CASE_SAVE_VERSION == 1 and CommissioningManager.COMMISSIONING_SAVE_VERSION == 1, "Independent versions 3/1/1")
	_check(not FileAccess.get_file_as_string("res://scripts/core/save_manager.gd").contains("Commissioning"), "Commissioning not integrated into live SaveManager")
	CommissioningManager.commissioning_stage_changed.disconnect(_on_stage)
	SUPPORT.restore_stage(3)
	CaseManager.reset_cases()
	if _failures == 0:
		print("Commissioning tests passed: %d checks." % _checks)
	else:
		push_error("Commissioning tests failed: %d/%d" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_serialization() -> void:
	for stage: int in range(4):
		var expected := {"commissioning_save_version": 1, "stage": CommissioningManager.STAGE_LABELS[stage]}
		_check(CommissioningManager.restore_commissioning_save_data(expected), "Valid stage restore")
		_check(CommissioningManager.get_stage() == stage and CommissioningManager.get_commissioning_save_data() == expected, "Exact stage serialization")
		var count := _signals.size()
		_check(CommissioningManager.restore_commissioning_save_data(JSON.parse_string(JSON.stringify(expected))), "JSON float version roundtrip")
		_check(_signals.size() == count, "Identical valid restore accepted without signal")
		for machine_id: StringName in CommissioningManager.MACHINE_STAGES:
			_check(CommissioningManager.is_machine_commissioned(machine_id) == (stage >= int(CommissioningManager.MACHINE_STAGES[machine_id])), "Stage/machine mapping")
	var invalid: Array = [null, true, 1, "MANUAL_SHIFT", [], {}, {"stage": "MANUAL_SHIFT"}, {"commissioning_save_version": 1}, {"commissioning_save_version": 1, "stage": "MANUAL_SHIFT", "extra": 0}, {1: 1, "stage": "MANUAL_SHIFT"}, {&"commissioning_save_version": 1, &"stage": "MANUAL_SHIFT"}]
	for version: Variant in [0, 2, -1, 1.1, INF, -INF, NAN, true, false, "1", null, [], {}]:
		invalid.append({"commissioning_save_version": version, "stage": "MANUAL_SHIFT"})
	for stage: Variant in [-1, 0, 3, 4, true, false, null, [], {}, "", "manual_shift", "UNSUPPORTED", &"MANUAL_SHIFT"]:
		invalid.append({"commissioning_save_version": 1, "stage": stage})
	for payload: Variant in invalid:
		var before := CommissioningManager.get_commissioning_save_data()
		var authority := SUPPORT.authority_snapshot()
		var count := _signals.size()
		_check(not CommissioningManager.is_valid_commissioning_save_data(payload), "Invalid strict schema rejected")
		_check(not CommissioningManager.restore_commissioning_save_data(payload), "Invalid restore rejected")
		_check(CommissioningManager.get_commissioning_save_data() == before and _signals.size() == count, "Invalid restore atomic/silent")
		_check(SUPPORT.authority_snapshot() == authority, "Invalid commissioning payload leaves other authorities unchanged")
	print("Commissioning corrupt payload corpus: %d atomic silent rejections" % invalid.size())


func _reject(operation: Callable, context: String) -> void:
	var before := CommissioningManager.get_commissioning_save_data()
	var count := _signals.size()
	_check(not operation.call(), "Rejected: " + context)
	_check(CommissioningManager.get_commissioning_save_data() == before and _signals.size() == count, "Rejection unchanged and silent: " + context)


func _on_stage(stage: int) -> void:
	_signals.append(stage)
	_check(CommissioningManager.get_stage() == stage, "Observers see committed stage")
	_check(not CommissioningManager.reset_to_manual_shift(), "Reentrant reset rejected")
	_check(not CommissioningManager.restore_commissioning_save_data(CommissioningManager.get_default_commissioning_save_data()), "Reentrant restore rejected")


func _check(value: bool, context: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error("FAIL: " + context)
