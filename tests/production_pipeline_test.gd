extends Node

const EPSILON: float = 0.00001
const RECEIVING_DESK_ID: StringName = &"receiving_desk"
const BASIC_SCANNER_ID: StringName = &"basic_scanner"
const BASIC_SORTER_ID: StringName = &"basic_sorter"
const ARCHIVE_INTAKE_ID: StringName = &"archive_intake"
const DASHBOARD_SCENE: PackedScene = preload("res://scenes/debug/debug_dashboard.tscn")

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
	_simulation_manager.set_process(false)
	call_deferred("_run_tests")


func _run_tests() -> void:
	_backup_save()
	_test_initial_pipeline()
	_test_sorter_runtime_multiplier()
	_test_disabled_stage()
	_test_hundred_second_simulation()
	_test_fractional_continuity()
	_test_runtime_state_round_trip()
	_test_upgrade_definitions()
	_test_upgrade_purchase_progression()
	_test_pending_production_funds_purchase()
	_test_purchase_rejections()
	_test_upgrade_managed_machines_reject_free_overrides()
	_test_save_load_round_trip()
	_test_duplicate_upgrade_save_is_rejected()
	_test_unknown_upgrade_save_is_rejected()
	_test_version_two_line_migration_maps_sorter_x2()
	_test_version_two_line_migration_preserves_unrelated_modifier()
	_test_legacy_scanner_only_migration()
	_test_version_one_save_migration()
	await _test_dashboard_scroll_layout(Vector2i(960, 540))
	await _test_dashboard_scroll_layout(Vector2i(960, 720))
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
	_expect_close(line.get_stage_capacity(RECEIVING_DESK_ID), 1.25, "Receiving capacity")
	_expect_close(line.get_stage_capacity(BASIC_SCANNER_ID), 1.0, "Scanner capacity")
	_expect_close(line.get_stage_capacity(BASIC_SORTER_ID), 0.75, "Sorter capacity")
	_expect_close(line.get_stage_capacity(ARCHIVE_INTAKE_ID), 2.0, "Archive capacity")
	_expect_close(line.get_effective_throughput(), 0.75, "Initial throughput")
	_expect_equal(line.get_bottleneck().get_id(), BASIC_SORTER_ID, "Initial bottleneck")
	_expect_close(line.get_stage_utilization(RECEIVING_DESK_ID), 0.60, "Receiving utilization")
	_expect_close(line.get_stage_utilization(BASIC_SCANNER_ID), 0.75, "Scanner utilization")
	_expect_close(line.get_stage_utilization(BASIC_SORTER_ID), 1.0, "Sorter utilization")
	_expect_close(line.get_stage_utilization(ARCHIVE_INTAKE_ID), 0.375, "Intake utilization")


func _test_sorter_runtime_multiplier() -> void:
	var line: ProductionLine = ProductionLineFactory.create_initial_line()
	_expect_true(
		line.set_stage_capacity_multiplier(BASIC_SORTER_ID, 2.0),
		"Production domain accepts an unrelated Sorter runtime modifier"
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
	_expect_equal(credits, 150, "75 items award 150 Credits")
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
	line.set_stage_capacity_multiplier(ARCHIVE_INTAKE_ID, 1.5)
	var saved_state: Dictionary = line.get_save_data()

	line.set_stage_enabled(BASIC_SCANNER_ID, true)
	line.set_stage_capacity_multiplier(ARCHIVE_INTAKE_ID, 1.0)
	_expect_true(line.restore_save_data(saved_state), "Production state restores")
	_expect_true(not line.get_stage(BASIC_SCANNER_ID).is_enabled(), "Scanner state restores")
	_expect_close(
		line.get_stage(ARCHIVE_INTAKE_ID).get_runtime_capacity_multiplier(),
		1.5,
		"Unrelated runtime modifier restores"
	)
	_expect_close(line.get_fractional_progress(), 0.75, "Fractional progress restores")


func _test_upgrade_definitions() -> void:
	var definitions: Array[UpgradeDefinition] = UpgradeCatalog.get_definitions()
	_expect_equal(definitions.size(), 2, "Exactly two player upgrades are defined")
	var sorter_upgrade: UpgradeDefinition = UpgradeCatalog.get_definition(
		UpgradeCatalog.SORTER_MOTOR_I_ID
	)
	var scanner_upgrade: UpgradeDefinition = UpgradeCatalog.get_definition(
		UpgradeCatalog.SCANNER_MOTOR_I_ID
	)
	_expect_true(sorter_upgrade != null and sorter_upgrade.is_valid(), "Sorter upgrade is valid")
	_expect_true(scanner_upgrade != null and scanner_upgrade.is_valid(), "Scanner upgrade is valid")
	_expect_equal(sorter_upgrade.target_machine_id, BASIC_SORTER_ID, "Sorter upgrade target")
	_expect_equal(sorter_upgrade.cost, 25, "Sorter upgrade price")
	_expect_close(sorter_upgrade.capacity_multiplier, 2.0, "Sorter upgrade multiplier")
	_expect_equal(scanner_upgrade.target_machine_id, BASIC_SCANNER_ID, "Scanner upgrade target")
	_expect_equal(scanner_upgrade.cost, 50, "Scanner upgrade price")
	_expect_close(scanner_upgrade.capacity_multiplier, 1.25, "Scanner upgrade multiplier")


func _test_upgrade_purchase_progression() -> void:
	_reset_manager_state(75)
	var sorter_result: int = _simulation_manager.purchase_upgrade(
		UpgradeCatalog.SORTER_MOTOR_I_ID
	)
	_expect_equal(sorter_result, _purchase_result("SUCCESS"), "Sorter Motor I purchase succeeds")
	_expect_equal(_game_state.get_money(), 50, "Sorter purchase deducts exactly 25 Credits")
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID),
		"Sorter ownership records exactly once"
	)
	_expect_equal(_simulation_manager.get_owned_upgrade_ids().size(), 1, "One upgrade is owned")
	_expect_close(
		_simulation_manager.get_machine_upgrade_multiplier(BASIC_SORTER_ID),
		2.0,
		"Sorter upgrade multiplier applies once"
	)
	_expect_close(_simulation_manager.get_effective_throughput(), 1.0, "Sorter upgrade throughput")
	_expect_equal(
		_simulation_manager.get_production_line().get_bottleneck().get_id(),
		BASIC_SCANNER_ID,
		"Scanner becomes bottleneck"
	)

	var scanner_result: int = _simulation_manager.purchase_upgrade(
		UpgradeCatalog.SCANNER_MOTOR_I_ID
	)
	_expect_equal(scanner_result, _purchase_result("SUCCESS"), "Scanner Motor I purchase succeeds")
	_expect_equal(_game_state.get_money(), 0, "Scanner purchase deducts exactly 50 Credits")
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SCANNER_MOTOR_I_ID),
		"Existing Scanner stable ID is owned"
	)
	_expect_equal(_simulation_manager.get_owned_upgrade_ids().size(), 2, "Two upgrades are owned")
	_expect_close(
		_simulation_manager.get_machine_upgrade_multiplier(BASIC_SCANNER_ID),
		1.25,
		"Scanner upgrade multiplier applies once"
	)
	_expect_close(_simulation_manager.get_effective_throughput(), 1.25, "Final progression throughput")
	_expect_equal(
		_simulation_manager.get_production_line().get_bottleneck().get_id(),
		RECEIVING_DESK_ID,
		"Ordered first minimum wins deterministic Receiving/Scanner tie"
	)


func _test_pending_production_funds_purchase() -> void:
	_reset_manager_state(24)
	var production_data: Dictionary = _simulation_manager.get_default_production_save_data()
	production_data["fractional_progress"] = 0.9
	_expect_true(
		_simulation_manager.restore_production_save_data(production_data),
		"Pending-purchase fixture restores 0.9 fractional progress"
	)
	_expect_true(_simulation_manager.set_tick_interval(1.0), "Test tick interval is accepted")
	_simulation_manager._process(0.2)

	_expect_equal(_game_state.get_money(), 24, "Pending production is not committed before purchase")
	_expect_close(
		_simulation_manager.get_pending_simulation_seconds(),
		0.2,
		"Exactly 0.2 seconds are pending before purchase"
	)
	var purchase_result: int = _simulation_manager.purchase_upgrade(
		UpgradeCatalog.SORTER_MOTOR_I_ID
	)

	_expect_equal(purchase_result, _purchase_result("SUCCESS"), "Pending Credits enable purchase")
	_expect_equal(_game_state.get_money(), 1, "24 + 2 pending Credits - 25 cost leaves 1 Credit")
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID),
		"Sorter upgrade is owned after pending-Credits purchase"
	)
	_expect_equal(_simulation_manager.get_owned_upgrade_ids().size(), 1, "Ownership records once")
	_expect_close(
		_simulation_manager.get_machine_upgrade_multiplier(BASIC_SORTER_ID),
		2.0,
		"Sorter multiplier applies exactly once"
	)
	_expect_close(
		_simulation_manager.get_production_line().get_fractional_progress(),
		0.05,
		"Old 0.75 items/sec configuration leaves 0.05 fractional progress"
	)
	_expect_close(
		_simulation_manager.get_pending_simulation_seconds(),
		0.0,
		"Pending time is fully consumed exactly once"
	)
	print(
		"Pending purchase regression: balance=%d, owned=%s, multiplier=%.2f, fraction=%.5f, pending=%.2f"
		% [
			_game_state.get_money(),
			_simulation_manager.owns_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID),
			_simulation_manager.get_machine_upgrade_multiplier(BASIC_SORTER_ID),
			_simulation_manager.get_production_line().get_fractional_progress(),
			_simulation_manager.get_pending_simulation_seconds(),
		]
	)
	_expect_true(
		_simulation_manager.set_tick_interval(_simulation_manager.DEFAULT_TICK_INTERVAL),
		"Default tick interval is restored"
	)


func _test_dashboard_scroll_layout(viewport_size: Vector2i) -> void:
	_reset_manager_state()
	var test_viewport: SubViewport = SubViewport.new()
	test_viewport.size = viewport_size
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(test_viewport)
	var dashboard: Control = DASHBOARD_SCENE.instantiate() as Control
	test_viewport.add_child(dashboard)
	await get_tree().process_frame
	await get_tree().process_frame

	var scroll_container: ScrollContainer = dashboard.get_node("DashboardScroll") as ScrollContainer
	var content_center: CenterContainer = dashboard.get_node("DashboardScroll/ContentCenter") as CenterContainer
	var panel: PanelContainer = dashboard.get_node("DashboardScroll/ContentCenter/PanelContainer") as PanelContainer
	var stage_rows: VBoxContainer = dashboard.get_node(
		"DashboardScroll/ContentCenter/PanelContainer/MarginContainer/Content/StageRows"
	) as VBoxContainer
	var upgrade_rows: VBoxContainer = dashboard.get_node(
		"DashboardScroll/ContentCenter/PanelContainer/MarginContainer/Content/UpgradeRows"
	) as VBoxContainer
	_expect_true(scroll_container != null, "%s uses a ScrollContainer" % viewport_size)
	_expect_equal(
		scroll_container.horizontal_scroll_mode,
		ScrollContainer.SCROLL_MODE_DISABLED,
		"%s disables horizontal scrolling" % viewport_size
	)
	_expect_equal(
		scroll_container.vertical_scroll_mode,
		ScrollContainer.SCROLL_MODE_AUTO,
		"%s enables automatic vertical scrolling" % viewport_size
	)
	_expect_equal(stage_rows.get_child_count(), 4, "%s keeps all production rows" % viewport_size)
	_expect_equal(upgrade_rows.get_child_count(), 2, "%s keeps both upgrade cards" % viewport_size)
	_expect_close(panel.position.y, 0.0, "%s keeps dashboard content top-aligned" % viewport_size)
	_expect_close(
		panel.position.x,
		(content_center.size.x - panel.size.x) * 0.5,
		"%s keeps dashboard content horizontally centered" % viewport_size
	)
	_expect_true(
		not scroll_container.get_h_scroll_bar().visible,
		"%s has no horizontal scrollbar or clipping" % viewport_size
	)
	_expect_true(
		scroll_container.get_v_scroll_bar().max_value
			> scroll_container.get_v_scroll_bar().page,
		"%s exposes vertical overflow through scrolling" % viewport_size
	)
	scroll_container.scroll_vertical = 0
	var wheel_event: InputEventMouseButton = InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_event.pressed = true
	wheel_event.position = scroll_container.get_global_rect().get_center()
	wheel_event.global_position = wheel_event.position
	test_viewport.push_input(wheel_event)
	await get_tree().process_frame
	_expect_true(
		scroll_container.scroll_vertical > 0,
		"%s responds to mouse-wheel scrolling" % viewport_size
	)

	var sorter_purchase_button: Button = upgrade_rows.get_child(0).find_child(
		"PurchaseButton", true, false
	) as Button
	var scanner_purchase_button: Button = upgrade_rows.get_child(1).find_child(
		"PurchaseButton", true, false
	) as Button
	var reachable_controls: Array[Control] = [
		dashboard.get_node("DashboardScroll/ContentCenter/PanelContainer/MarginContainer/Content/Title") as Control,
		stage_rows,
		upgrade_rows.get_child(0) as Control,
		sorter_purchase_button,
		upgrade_rows.get_child(1) as Control,
		scanner_purchase_button,
		dashboard.get_node(
			"DashboardScroll/ContentCenter/PanelContainer/MarginContainer/Content/TransactionButtons"
		) as Control,
		dashboard.get_node(
			"DashboardScroll/ContentCenter/PanelContainer/MarginContainer/Content/SaveButtons/SaveButton"
		) as Control,
		dashboard.get_node(
			"DashboardScroll/ContentCenter/PanelContainer/MarginContainer/Content/SaveButtons/LoadButton"
		) as Control,
		dashboard.get_node(
			"DashboardScroll/ContentCenter/PanelContainer/MarginContainer/Content/StatusValue"
		) as Control,
	]
	for control: Control in reachable_controls:
		_expect_true(scroll_container.is_ancestor_of(control), "%s remains inside scrolling content" % control.name)
		scroll_container.ensure_control_visible(control)
		await get_tree().process_frame
		_expect_true(
			scroll_container.get_global_rect().intersects(control.get_global_rect()),
			"%s is reachable at %s" % [control.name, viewport_size]
		)

	_game_state.restore_state(25, 25, 0, 0.0)
	sorter_purchase_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID),
		"Sorter purchase button works at %s" % viewport_size
	)
	_expect_equal(_game_state.get_money(), 0, "Purchase button deducts cost at %s" % viewport_size)
	_expect_true(
		String(dashboard.get_node("%StatusValue").text).begins_with("Purchased Sorter Motor I"),
		"Purchase status is visible at %s" % viewport_size
	)

	test_viewport.queue_free()
	await get_tree().process_frame


func _test_purchase_rejections() -> void:
	_reset_manager_state(24)
	var insufficient_result: int = _simulation_manager.purchase_upgrade(
		UpgradeCatalog.SORTER_MOTOR_I_ID
	)
	_expect_equal(
		insufficient_result,
		_purchase_result("INSUFFICIENT_FUNDS"),
		"Unaffordable upgrade is rejected"
	)
	_expect_equal(_game_state.get_money(), 24, "Rejected purchase does not deduct Credits")
	_expect_equal(_simulation_manager.get_owned_upgrade_ids().size(), 0, "Rejected purchase owns nothing")

	var invalid_result: int = _simulation_manager.purchase_upgrade("missing_upgrade")
	_expect_equal(invalid_result, _purchase_result("INVALID_UPGRADE"), "Invalid upgrade ID is rejected")
	_expect_equal(_game_state.get_money(), 24, "Invalid ID does not deduct Credits")

	_reset_manager_state(100)
	_expect_equal(
		_simulation_manager.purchase_upgrade(UpgradeCatalog.SCANNER_MOTOR_I_ID),
		_purchase_result("SUCCESS"),
		"Initial Scanner purchase succeeds"
	)
	var duplicate_result: int = _simulation_manager.purchase_upgrade(
		UpgradeCatalog.SCANNER_MOTOR_I_ID
	)
	_expect_equal(duplicate_result, _purchase_result("ALREADY_OWNED"), "Duplicate is rejected")
	_expect_equal(_game_state.get_money(), 50, "Duplicate does not deduct Credits")
	_expect_equal(_simulation_manager.get_owned_upgrade_ids().size(), 1, "Ownership has no duplicate")
	_expect_close(
		_simulation_manager.get_machine_upgrade_multiplier(BASIC_SCANNER_ID),
		1.25,
		"Duplicate does not stack multiplier"
	)


func _test_upgrade_managed_machines_reject_free_overrides() -> void:
	_reset_manager_state()
	_expect_true(
		not _simulation_manager.set_machine_capacity_multiplier(BASIC_SORTER_ID, 2.0),
		"Free Sorter override is rejected"
	)
	_expect_true(
		not _simulation_manager.set_machine_capacity_multiplier(BASIC_SCANNER_ID, 1.25),
		"Free Scanner override is rejected"
	)
	_expect_close(_simulation_manager.get_effective_throughput(), 0.75, "Overrides do not alter line")
	_expect_equal(_simulation_manager.get_owned_upgrade_ids().size(), 0, "Overrides grant no ownership")


func _test_save_load_round_trip() -> void:
	_reset_manager_state(75)
	_simulation_manager.purchase_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID)
	_simulation_manager.purchase_upgrade(UpgradeCatalog.SCANNER_MOTOR_I_ID)
	_simulation_manager.simulate_elapsed(1.0)
	_simulation_manager.set_machine_enabled(BASIC_SCANNER_ID, false)
	_expect_true(
		_simulation_manager.set_machine_capacity_multiplier(ARCHIVE_INTAKE_ID, 1.5),
		"Unrelated Archive runtime modifier is accepted"
	)
	_expect_true(_save_manager.save_game(), "Generic upgrade state saves")

	_reset_manager_state()
	_expect_true(_save_manager.load_game(), "Generic upgrade state loads")
	_expect_equal(_simulation_manager.get_owned_upgrade_ids().size(), 2, "Both upgrades restore")
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID),
		"Sorter ownership restores"
	)
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SCANNER_MOTOR_I_ID),
		"Scanner ownership restores"
	)
	_expect_true(
		not _simulation_manager.get_production_line().get_stage(BASIC_SCANNER_ID).is_enabled(),
		"Disabled machine state restores"
	)
	_expect_close(
		_simulation_manager.get_production_line().get_fractional_progress(),
		0.25,
		"Fractional progress restores"
	)
	var archive: MachineRuntime = _simulation_manager.get_production_line().get_stage(ARCHIVE_INTAKE_ID)
	_expect_close(archive.get_runtime_capacity_multiplier(), 1.5, "Unrelated runtime modifier restores")
	_expect_close(
		_simulation_manager.get_production_line().get_stage(BASIC_SORTER_ID).get_runtime_capacity_multiplier(),
		1.0,
		"Sorter upgrade is not copied into runtime modifier"
	)
	_expect_close(
		_simulation_manager.get_machine_upgrade_multiplier(BASIC_SORTER_ID),
		2.0,
		"Sorter upgrade is derived once after load"
	)


func _test_duplicate_upgrade_save_is_rejected() -> void:
	var production_data: Dictionary = _simulation_manager.get_default_production_save_data()
	production_data["owned_upgrade_ids"] = [
		UpgradeCatalog.SCANNER_MOTOR_I_ID,
		UpgradeCatalog.SCANNER_MOTOR_I_ID,
	]
	_expect_true(_write_save(_make_complete_save(production_data, 3)), "Duplicate save is prepared")

	_reset_manager_state(25)
	_simulation_manager.purchase_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID)
	_expect_true(not _save_manager.load_game(), "Duplicate upgrade ownership is rejected")
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID),
		"Rejected save leaves live ownership unchanged"
	)


func _test_unknown_upgrade_save_is_rejected() -> void:
	var production_data: Dictionary = _simulation_manager.get_default_production_save_data()
	production_data["owned_upgrade_ids"] = ["unknown_upgrade"]
	_expect_true(_write_save(_make_complete_save(production_data, 3)), "Unknown-ID save is prepared")

	_reset_manager_state(50)
	_simulation_manager.purchase_upgrade(UpgradeCatalog.SCANNER_MOTOR_I_ID)
	_expect_true(not _save_manager.load_game(), "Unknown upgrade ownership is rejected")
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SCANNER_MOTOR_I_ID),
		"Malformed save cannot mutate live ownership"
	)


func _test_version_two_line_migration_maps_sorter_x2() -> void:
	var production_data: Dictionary = _make_version_two_production()
	production_data["fractional_progress"] = 0.5
	production_data["scanner_upgrades"] = [UpgradeCatalog.SCANNER_MOTOR_I_ID]
	production_data["machines"][String(BASIC_SCANNER_ID)]["enabled"] = false
	production_data["machines"][String(BASIC_SCANNER_ID)]["capacity_multiplier"] = 1.25
	production_data["machines"][String(BASIC_SORTER_ID)]["capacity_multiplier"] = 2.0
	_expect_true(_write_save(_make_complete_save(production_data, 2)), "Version-two line save is prepared")

	_reset_manager_state()
	_expect_true(_save_manager.load_game(), "Version-two line save migrates")
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SCANNER_MOTOR_I_ID),
		"Existing Scanner ownership migrates"
	)
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID),
		"Exact legacy Sorter x2 maps to Sorter Motor I"
	)
	var sorter: MachineRuntime = _simulation_manager.get_production_line().get_stage(BASIC_SORTER_ID)
	_expect_close(sorter.get_runtime_capacity_multiplier(), 1.0, "Legacy Sorter x2 runtime field is cleared")
	_expect_close(sorter.get_capacity_multiplier(), 2.0, "Migrated Sorter multiplier applies exactly once")
	_expect_close(
		_simulation_manager.get_production_line().get_stage(BASIC_SCANNER_ID).get_capacity_multiplier(),
		1.25,
		"Migrated Scanner multiplier applies exactly once"
	)
	_expect_close(
		_simulation_manager.get_production_line().get_fractional_progress(),
		0.5,
		"Version-two migration preserves fractional progress"
	)
	_expect_true(not _simulation_manager.get_production_line().get_stage(BASIC_SCANNER_ID).is_enabled(), "Version-two migration preserves enabled state")


func _test_version_two_line_migration_preserves_unrelated_modifier() -> void:
	var production_data: Dictionary = _make_version_two_production()
	production_data["machines"][String(BASIC_SORTER_ID)]["capacity_multiplier"] = 1.5
	_expect_true(_write_save(_make_complete_save(production_data, 2)), "Non-x2 legacy save is prepared")

	_reset_manager_state()
	_expect_true(_save_manager.load_game(), "Non-x2 legacy modifier migrates")
	_expect_true(
		not _simulation_manager.owns_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID),
		"Non-x2 legacy modifier does not grant Sorter Motor I"
	)
	var sorter: MachineRuntime = _simulation_manager.get_production_line().get_stage(BASIC_SORTER_ID)
	_expect_close(sorter.get_runtime_capacity_multiplier(), 1.5, "Unrelated legacy modifier is preserved")
	_expect_close(sorter.get_upgrade_capacity_multiplier(), 1.0, "No upgrade multiplier is inferred")


func _test_legacy_scanner_only_migration() -> void:
	var legacy_save: Dictionary = {
		"save_version": 2,
		"money": 10,
		"total_money_earned": 60,
		"total_processed_items": 25,
		"total_playtime": 12.5,
		"save_timestamp": 1,
		"production": {
			"scanner_enabled": false,
			"scanner_upgrades": [UpgradeCatalog.SCANNER_MOTOR_I_ID],
			"incoming_item_buffer": 4.0,
			"processed_item_fraction": 0.5,
		},
	}
	_expect_true(_write_save(legacy_save), "Legacy Scanner-only save is prepared")

	_reset_manager_state()
	_expect_true(_save_manager.load_game(), "Legacy Scanner-only save migrates")
	_expect_true(not _simulation_manager.get_production_line().get_stage(BASIC_SCANNER_ID).is_enabled(), "Legacy Scanner enabled state restores")
	_expect_true(
		_simulation_manager.owns_upgrade(UpgradeCatalog.SCANNER_MOTOR_I_ID),
		"Legacy Scanner stable ID restores"
	)
	_expect_true(
		not _simulation_manager.owns_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID),
		"Scanner-only save does not grant Sorter upgrade"
	)
	_expect_close(
		_simulation_manager.get_machine_upgrade_multiplier(BASIC_SCANNER_ID),
		1.25,
		"Legacy Scanner modifier derives exactly once"
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
	_expect_true(_write_save(legacy_save), "Version-one save is prepared")

	_reset_manager_state(75)
	_simulation_manager.purchase_upgrade(UpgradeCatalog.SORTER_MOTOR_I_ID)
	_simulation_manager.purchase_upgrade(UpgradeCatalog.SCANNER_MOTOR_I_ID)
	_expect_true(_save_manager.load_game(), "Version-one save migrates to defaults")
	_expect_equal(_game_state.get_money(), 12, "Version-one migration restores base game state")
	_expect_equal(_simulation_manager.get_owned_upgrade_ids().size(), 0, "Version-one has no upgrades")
	_expect_close(_simulation_manager.get_effective_throughput(), 0.75, "Version-one restores default line")


func _purchase_result(name: String) -> int:
	return int(_simulation_manager.PurchaseResult[name])


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


func _make_complete_save(production_data: Dictionary, version: int) -> Dictionary:
	return {
		"save_version": version,
		"money": 0,
		"total_money_earned": 0,
		"total_processed_items": 0,
		"total_playtime": 0.0,
		"save_timestamp": 1,
		"production_line": production_data,
	}


func _make_version_two_production() -> Dictionary:
	return {
		"fractional_progress": 0.0,
		"machines": {
			String(RECEIVING_DESK_ID): {"enabled": true, "capacity_multiplier": 1.0},
			String(BASIC_SCANNER_ID): {"enabled": true, "capacity_multiplier": 1.0},
			String(BASIC_SORTER_ID): {"enabled": true, "capacity_multiplier": 1.0},
			String(ARCHIVE_INTAKE_ID): {"enabled": true, "capacity_multiplier": 1.0},
		},
		"scanner_upgrades": [],
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
