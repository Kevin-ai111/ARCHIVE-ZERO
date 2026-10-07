extends Node

const ROOM := preload("res://scenes/world/archive_room.tscn")
const SUPPORT := preload("res://tests/commissioning_test_support.gd")
const LIGHTING_FIX := preload("res://tests/lighting_fix_test_support.gd")
var _checks := 0
var _failures := 0
var _room: Node2D
var _approved: Dictionary


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	call_deferred("_run")


func _run() -> void:
	_approved = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/phase5d_state_matrix.json"))
	_check(CommissioningManager.get_stage() == 3 and not CaseManager.has_active_case(), "Normal boot remains full line/no case")
	var baseline := _simulate_hundred()
	_room = ROOM.instantiate()
	add_child(_room)
	await _settle()
	_check(not _room.get_node("CasePanel/Panel").visible, "Normal case panel hidden")
	var layout: Dictionary = _room.get_layout_snapshot()
	var environment := _room.get_node("%EnvironmentArt") as ArchiveRoomEnvironmentVisual
	_check(not environment.is_processing(), "No per-frame environment controller")
	_test_assets()
	for disabled: bool in [false, true]:
		SUPPORT.prepare_isolation_fixture(disabled)
		GameState.add_money(100)
		SimulationManager.purchase_upgrade("scanner_motor_1")
		var before := SUPPORT.authority_snapshot()
		for stage: int in range(4):
			SUPPORT.restore_stage(stage)
			await _settle()
			_test_environment(stage)
			_test_machines(stage, disabled)
			await _test_conveyor(stage, disabled)
			var applications := environment.state_application_count
			for _index: int in range(5):
				SimulationManager.simulation_updated.emit(0, 0, 0.25)
				SimulationManager.production_line_changed.emit()
				SimulationManager.upgrades_changed.emit()
				GameState.state_restored.emit()
			_check(environment.state_application_count == applications, "Repeated runtime refresh does not reapply environment")
			_test_environment(stage)
			_test_machines(stage, disabled)
			_check(_room.get_layout_snapshot() == layout, "All room geometry/Z/filter/assets remain unchanged")
			_check(SUPPORT.authority_snapshot() == before, "Room refresh/stage switching leaves production and cases unchanged")
			var panel := _room.get_node("CasePanel") as ManualCasePanel
			_check(panel.panel.visible and not panel.release_button.disabled and panel.status.text == "CLASSIFIED", "Existing case panel/selected authority survives stage switch")
		print("Progressive presentation isolation (%s): flags/credits/fraction/pending/upgrades/cases/save UNCHANGED" % ["stopped" if disabled else "running"])
	await _test_true_disabled()
	for stage: int in range(4):
		SUPPORT.restore_stage(stage)
		_check(_simulate_hundred() == baseline, "100-second invariance at stage " + CommissioningManager.STAGE_LABELS[stage])
	_check(baseline.money == 150 and baseline.items == 75 and baseline.fraction == 0.0 and baseline.throughput == 0.75, "Established numeric invariants")
	print("All-stage room/no-room invariance: items=75 credits=150 throughput=0.75 fraction=0.00000")
	SUPPORT.restore_stage(3)
	CaseManager.reset_cases()
	_room.queue_free()
	await _settle()
	if _failures == 0:
		print("Progressive room states tests passed: %d checks; 29 elements x 4 stages, 86 immutable PNGs + 2 approved lighting replacements." % _checks)
	else:
		push_error("Progressive room states tests failed: %d/%d" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_environment(stage: int) -> void:
	var snapshot: Dictionary = _room.get_node("%EnvironmentArt").get_commissioning_snapshot()
	_check(snapshot.stage == stage and snapshot.elements.size() == _approved.elements.size() and snapshot.elements.size() == 29, "Complete approved environment matrix")
	for element: String in _approved.elements:
		var expected: Dictionary = _approved.elements[element].states[_approved.states[stage]]
		# Only PR17's nine lighting alpha entries differ; original matrix is retained.
		expected = expected.duplicate(true)
		expected.alpha_multiplier = LIGHTING_FIX.expected_alpha(element, stage, expected.alpha_multiplier)
		var rgba: Array = expected.modulate_rgba
		var tint := Color(rgba[0], rgba[1], rgba[2], rgba[3] * expected.alpha_multiplier)
		var actual: Dictionary = snapshot.elements[element]
		_check(is_equal_approx(actual.alpha_multiplier, expected.alpha_multiplier), "Exact approved alpha multiplier: " + element)
		_check(not actual.targets.is_empty(), "Every matrix element mapped to named nodes: " + element)
		for target: Dictionary in actual.targets:
			_check(target.visible == expected.visible and target.visible_in_tree == expected.visible, "Exact visibility: " + element)
			_check((target.effective_modulate as Color).is_equal_approx(tint), "Actual inherited modulation matches ART: " + element)
			if stage == 3 and element != "optional_sconces":
				_check(target.visible and target.effective_modulate == tint, "Full line restores original response plus explicit PR17 lighting alpha")


func _test_machines(stage: int, disabled: bool) -> void:
	var desk := _room.get_node("%ReceivingDesk") as ReceivingDeskVisual
	_check(desk.machine_enabled and desk.idle_emissive.visible, "Receiving always commissioned and runtime enabled")
	var machines: Array[Node] = [_room.get_node("%BasicScanner"), _room.get_node("%BasicSorter"), _room.get_node("%ArchiveIntake")]
	for index: int in range(machines.size()):
		var machine := machines[index]
		var expected_commissioned := stage > index
		var state: Dictionary = machine.get_state_snapshot()
		_check(state.commissioned == expected_commissioned, "Correct machine commissioning stage")
		_check(state.enabled == (not disabled or index != 2), "Runtime enabled flag stays independent")
		var phase_key: String = ["scan_offset_y", "gate_angle", "carrier_offset_y"][index]
		var phase: float = state[phase_key]
		if not expected_commissioned:
			_check(state.casing_modulate == Color(0.62, 0.68, 0.72, 1), "Exact dormant casing tint")
			_check(not state.active and not state.bottleneck and not state.fault_visible and not machine.is_processing(), "Dormant has no animation/highlight/fault")
			for key: String in ["idle_visible", "scan_visible", "header_visible", "bays_visible", "upgrade_visible"]:
				if state.has(key):
					_check(not state[key], "Dormant hides emissive/upgrade: " + key)
			machine.advance_visual_animation(0.37)
			_check(is_equal_approx(machine.get_state_snapshot()[phase_key], phase), "Dormant direct animation call is frozen")
		else:
			_check(state.fault_visible == (disabled and index == 2), "Commissioned actual-disabled retains fault semantic")
			_check(state.casing_modulate == (Color(0.42, 0.48, 0.52, 1) if disabled and index == 2 else Color.WHITE), "Commissioned casing matches existing runtime response")
			_check(state.active == not disabled, "Commissioned animation still obeys actual throughput")


func _test_conveyor(stage: int, disabled: bool) -> void:
	var conveyor := _room.get_node("%Conveyor") as ConveyorPlaceholderVisual
	var should_run := stage >= 2 and not disabled
	_check(conveyor.is_running == should_run, "Single continuous belt stage policy")
	_check(_room.get_node("%DecorativeParcels").visible == (stage == 3), "Parcels only visible at full line")
	var positions := conveyor.get_item_positions()
	var offset := conveyor.get_slat_offset()
	conveyor.advance_visuals(0.15)
	if should_run:
		_check(conveyor.get_item_positions() != positions and not is_equal_approx(conveyor.get_slat_offset(), offset), "Existing single conveyor clock advances")
	else:
		_check(conveyor.get_item_positions() == positions and is_equal_approx(conveyor.get_slat_offset(), offset), "Stopped presentation clock loses no motion")
	await _settle()
	var geometry := conveyor.get_draw_geometry_snapshot()
	_check(geometry.parcel_size == Vector2(42, 30) and geometry.parcel_bottom_y == 703 and geometry.contact_gap == 0, "Parcel contact/size unchanged")
	_check(conveyor.path_start_x == 436 and conveyor.path_end_x == 1668 and conveyor.item_path_y == 688 and conveyor.ground_baseline_y == 920, "Conveyor endpoints/centreline/baseline unchanged")


func _test_true_disabled() -> void:
	SimulationManager.restore_production_save_data(SimulationManager.get_default_production_save_data())
	for index: int in range(3):
		var machine_id: StringName = [&"basic_scanner", &"basic_sorter", &"archive_intake"][index]
		var machine := _room.get_node(["%BasicScanner", "%BasicSorter", "%ArchiveIntake"][index])
		SimulationManager.set_machine_enabled(machine_id, false)
		SUPPORT.restore_stage(0)
		_check(not machine.get_state_snapshot().fault_visible and machine.get_state_snapshot().casing_modulate == Color(0.62, 0.68, 0.72, 1), "Runtime-disabled but uncommissioned still dormant, no red fault")
		SUPPORT.restore_stage(3)
		await _settle()
		_check(machine.get_state_snapshot().fault_visible and machine.get_state_snapshot().casing_modulate == Color(0.42, 0.48, 0.52, 1), "True disabled/fault returns after commissioning")
		SimulationManager.set_machine_enabled(machine_id, true)
		_check(not machine.get_state_snapshot().fault_visible, "Actual enable clears original fault")


func _test_assets() -> void:
	var locked: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/phase5d_base_asset_hashes.json"))
	_check(locked.png_count == 88 and locked.assets.size() == 88, "Base locks every existing runtime texture")
	for asset: Dictionary in locked.assets:
		_check(FileAccess.get_sha256("res://" + asset.path) == LIGHTING_FIX.expected_asset_hash(asset.path, asset.sha256), "Base PNG unchanged or exact approved lighting replacement: " + asset.path)
	_check(_count_pngs("res://assets") == 88, "Zero new runtime PNGs")


func _count_pngs(path: String) -> int:
	var count := 0
	for filename: String in DirAccess.get_files_at(path):
		if filename.ends_with(".png"):
			count += 1
	for directory: String in DirAccess.get_directories_at(path):
		count += _count_pngs(path.path_join(directory))
	return count


func _simulate_hundred() -> Dictionary:
	SimulationManager.restore_production_save_data(SimulationManager.get_default_production_save_data())
	GameState.restore_state(0, 0, 0, 0)
	CaseManager.reset_cases()
	SimulationManager.simulate_elapsed(100.0)
	return SUPPORT.authority_snapshot()


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _check(value: bool, context: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error("FAIL: " + context)
