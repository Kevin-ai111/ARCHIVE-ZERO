extends Node

const ROOM_SCENE := preload("res://scenes/world/archive_room.tscn")

var _checks := 0
var _failures := 0
var _money_signal_count := 0
var _original_save_exists := false
var _original_save_contents := ""


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	call_deferred("_run")


func _run() -> void:
	_backup_save()
	_test_directives()
	_test_mutable_classification_and_case_v1()
	await _test_result_publication_and_ui()
	await _test_mixed_first_shift_economy()
	_restore_save_backup()
	if _failures == 0:
		print("Archive inspection/rules tests passed: %d checks." % _checks)
	else:
		push_error("Archive inspection/rules tests failed: %d/%d" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_directives() -> void:
	var catalog := ArchiveDirectiveCatalog.new()
	_check(catalog.is_valid(), "Default Directive catalog is valid")
	var directives := catalog.get_directives()
	_check(directives.size() == 4, "Exactly four core Directives are available")
	var ids := {}
	var priorities: Array[int] = []
	for directive: ArchiveDirectiveDefinition in directives:
		_check(directive.is_valid([&"PERS", &"ELEC", &"DOCS", &"BAG"]), "Structured Directive is valid: " + String(directive.directive_id))
		_check(not ids.has(directive.directive_id), "Directive ID is unique: " + String(directive.directive_id))
		_check(directive.target_category_id in [&"PERS", &"ELEC", &"DOCS", &"BAG"], "Directive category reference exists")
		ids[directive.directive_id] = true
		priorities.append(directive.priority)
	_check(priorities == [400, 300, 200, 100], "Priority ordering is deterministic")

	var cases := CaseCatalog.new()
	for case_id: StringName in CaseCatalog.DIRECTIVE_VALIDATED_CASE_IDS:
		var definition := cases.get_case(case_id)
		_check(catalog.evaluate(definition) == definition.expected_category_id, "Normal First Shift Directive result matches authority: " + String(case_id))
	var plain_tote := cases.get_case(&"CASE_0006")
	var document_tote := cases.get_case(&"CASE_0011")
	_check(plain_tote.item_id == document_tote.item_id, "CASE_0006 and CASE_0011 use the same visual item")
	_check(catalog.evaluate(plain_tote) == &"BAG" and catalog.evaluate(document_tote) == &"DOCS", "Document priority overrides identical container form")
	_check(document_tote.inspection_identifier == "File reference" and document_tote.inspection_risk == "Sensitive", "Evidence-dependent tote remains mundane and explicit")
	var excluded := cases.get_case(&"CASE_0010")
	_check(excluded.routing_policy == CaseDefinition.MANUAL_REVIEW and excluded.expected_category_id == &"PERS", "CASE_0010 remains unchanged and excluded")
	_check(catalog.evaluate(excluded).is_empty(), "CASE_0010 is not normalized by ordinary Directives")

	var valid := directives[0].duplicate(true) as ArchiveDirectiveDefinition
	var duplicate_id := directives[1].duplicate(true) as ArchiveDirectiveDefinition
	duplicate_id.directive_id = valid.directive_id
	_check(not ArchiveDirectiveCatalog.is_valid_catalog_data([valid, duplicate_id], [&"PERS", &"ELEC", &"DOCS", &"BAG"]), "Duplicate Directive IDs are rejected")
	var duplicate_priority := directives[1].duplicate(true) as ArchiveDirectiveDefinition
	duplicate_priority.priority = valid.priority
	_check(not ArchiveDirectiveCatalog.is_valid_catalog_data([valid, duplicate_priority], [&"PERS", &"ELEC", &"DOCS", &"BAG"]), "Ambiguous Directive priorities are rejected")
	var invalid_field := valid.duplicate(true) as ArchiveDirectiveDefinition
	invalid_field.evidence_field = &"invented_field"
	_check(not ArchiveDirectiveCatalog.is_valid_catalog_data([invalid_field], [&"PERS", &"ELEC", &"DOCS", &"BAG"]), "Unknown evidence fields are rejected")
	var invalid_category := valid.duplicate(true) as ArchiveDirectiveDefinition
	invalid_category.target_category_id = &"UNKNOWN"
	_check(not ArchiveDirectiveCatalog.is_valid_catalog_data([invalid_category], [&"PERS", &"ELEC", &"DOCS", &"BAG"]), "Unknown Directive category references are rejected")


func _test_mutable_classification_and_case_v1() -> void:
	if not CaseManager.get_case_save_data().progress.is_empty():
		CaseManager.reset_cases()
	_check(CaseManager.enqueue_case(&"CASE_0001"), "Mutable-classification fixture enqueues")
	_check(CaseManager.activate_next_case() != null and CaseManager.mark_active_case_inspected(), "Case reaches INSPECTED")
	_check(CaseManager.set_active_case_classification(&"PERS"), "INSPECTED to PERS succeeds")
	_check(CaseManager.get_active_case().get_state() == CaseProgress.State.CLASSIFIED, "First selection enters CLASSIFIED")
	_check(CaseManager.set_active_case_classification(&"ELEC"), "PERS to ELEC succeeds")
	_check(CaseManager.get_active_case().get_state() == CaseProgress.State.CLASSIFIED, "Reclassification remains CLASSIFIED")
	_check(CaseManager.set_active_case_classification(&"DOCS"), "ELEC to DOCS succeeds")
	_check(CaseManager.set_active_case_classification(&"DOCS"), "Same-category selection is a successful no-op")
	var latest := CaseManager.get_case_save_data()
	_check(latest.case_save_version == 1 and latest.progress[0].selected_category_id == "DOCS", "Case Save v1 stores the latest editable choice")
	_check(CaseManager.set_active_case_classification(&"BAG"), "Fixture can diverge after save")
	_check(CaseManager.restore_case_save_data(latest), "Existing Case Save v1 restores")
	_check(CaseManager.get_active_case().get_selected_category_id() == &"DOCS", "Load restores the latest saved selection")
	_check(CaseManager.archive_active_case(), "Archive commits the latest selection")
	_check(CaseManager.get_case_progress(&"CASE_0001").get_selected_category_id() == &"DOCS", "Archived selection remains final")
	_check(not CaseManager.set_active_case_classification(&"PERS"), "Post-Archive reclassification is rejected")
	CaseManager.reset_cases()


func _test_result_publication_and_ui() -> void:
	_check(FirstShiftManager.start_new_game(), "Result fixture starts fresh")
	var room := ROOM_SCENE.instantiate()
	add_child(room)
	await _settle()
	var panel := room.get_node("CasePanel") as ManualCasePanel
	_check(FirstShiftManager.activate_next_case() != null, "Correct result Case activates")
	CaseManager.mark_active_case_inspected()
	CaseManager.set_active_case_classification(&"PERS")
	await _settle()
	_check(FirstShiftManager.get_last_committed_case_result().is_empty(), "No result exists before Archive")
	_check(not panel.result_overlay.visible and not _visible_text(panel.panel).contains("CORRECT"), "Presentation exposes no correctness before commit")
	panel.directives_button.pressed.emit()
	_check(panel.directives_drawer.visible, "Directives drawer opens without changing Case state")
	_check(CaseManager.get_active_case().get_selected_category_id() == &"PERS", "Opening Directives preserves classification")
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = size
		await _settle()
		_check(panel.panel.get_global_rect().encloses(panel.directives_drawer.get_global_rect()), "Directive drawer fits Case Panel at " + str(size))
		_check(panel.release_button.visible and not panel.release_button.disabled, "Archive remains available beside Directives at " + str(size))
		_check((panel.category_buttons[&"PERS"] as Button).get_meta("selected") and not (panel.category_buttons[&"ELEC"] as Button).disabled, "Selected state and alternatives remain readable at " + str(size))
		for child: Node in panel.directives_drawer.find_children("Directive*", "Label", true, false):
			var directive_label := child as Label
			_check(directive_label.get_theme_font_size("font_size") >= 18, "Directive text keeps readable logical typography at " + str(size))
			_check(panel.directives_drawer.get_global_rect().encloses(directive_label.get_global_rect()), "Directive text is unclipped at " + str(size))
			_check(directive_label.get_visible_line_count() == directive_label.get_line_count(), "Every Directive line is visible at " + str(size))
	panel.directives_button.pressed.emit()
	_check(not panel.directives_drawer.visible, "Directives drawer returns to the Case")
	_check(CaseManager.archive_active_case(), "Correct Case archives")
	await _settle()
	var correct := FirstShiftManager.get_last_committed_case_result()
	_check(not CaseManager.has_active_case() and correct.case_id == "CASE_0001", "Result snapshot refers to archived Case without keeping it active")
	_check(correct.correct and correct.reward == 5 and GameState.get_money() == 5, "Correct result commits +5 C")
	_check(panel.result_overlay.visible and panel.result_classification.text == "CLASSIFICATION: CORRECT", "Restrained correct result is visible")
	_check(not panel.result_detail.text.contains("EXPECTED"), "Correct result shows no expected mismatch detail")

	_check(FirstShiftManager.activate_next_case() != null, "Opening the next Case succeeds")
	await _settle()
	_check(FirstShiftManager.get_last_committed_case_result().is_empty() and not panel.result_overlay.visible, "Next Case clears only the prior presentation snapshot")
	CaseManager.mark_active_case_inspected()
	CaseManager.set_active_case_classification(&"PERS")
	_money_signal_count = 0
	GameState.money_changed.connect(_count_money_signal)
	_check(CaseManager.archive_active_case(), "Misrouted Case archives")
	GameState.money_changed.disconnect(_count_money_signal)
	await _settle()
	var wrong := FirstShiftManager.get_last_committed_case_result()
	_check(not wrong.correct and wrong.reward == 0 and GameState.get_money() == 5, "Misrouted result commits +0 C")
	_check(_money_signal_count == 0, "Zero reward makes no Economy/GameState money call")
	_check(wrong.selected_category_id == "PERS" and wrong.expected_category_id == "ELEC", "Misrouted result preserves selected and expected categories")
	_check(panel.result_overlay.visible and panel.result_classification.text == "CLASSIFICATION: MISROUTED", "Institutional misrouted result is visible")
	_check(panel.result_detail.text.contains("SELECTED: PERS") and panel.result_detail.text.contains("EXPECTED: ELEC"), "Misrouted UI shows the committed mismatch")
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = size
		await _settle()
		_check(panel.panel.get_global_rect().encloses(panel.result_overlay.get_global_rect()), "Result panel is not clipped at " + str(size))
		_check(panel.result_classification.get_theme_font_size("font_size") >= 28 and panel.result_reward.get_theme_font_size("font_size") >= 30, "Result typography remains readable at " + str(size))
		_check(panel.result_overlay.get_global_rect().encloses(panel.result_detail.get_global_rect()), "Selected/expected detail stays inside result panel at " + str(size))
	_check(FirstShiftManager.get_claimed_reward_case_ids() == [&"CASE_0001", &"CASE_0002"], "Zero-credit reward claim persists exactly once")
	_check(SaveManager.save_game(), "Wrong-result coherent save succeeds")
	_check(SaveManager.load_game(), "Wrong-result v4 save reloads")
	await _settle()
	_check(GameState.get_money() == 5 and FirstShiftManager.get_claimed_reward_case_ids() == [&"CASE_0001", &"CASE_0002"], "Save/load preserves the zero-credit claim without rebalance")
	FirstShiftManager._on_case_progress_changed(&"CASE_0002")
	_check(GameState.get_money() == 5 and FirstShiftManager.get_claimed_reward_case_ids().count(&"CASE_0002") == 1, "Wrong archive replay is reward-idempotent")
	room.queue_free()
	await _settle()


func _test_mixed_first_shift_economy() -> void:
	_check(FirstShiftManager.start_new_game(), "Mixed-economy fixture starts fresh")
	var correct_count := 0
	for index: int in FirstShiftManager.FIRST_SHIFT_CASE_IDS.size():
		if FirstShiftManager.get_phase() == FirstShiftManager.Phase.SCANNER_READY:
			var before_scanner := GameState.get_transaction_snapshot()
			_check(FirstShiftManager.commission_scanner() == FirstShiftManager.CommissionResult.SUCCESS, "Mixed path commissions Scanner at zero cost")
			_check(GameState.get_transaction_snapshot() == before_scanner, "Scanner commissioning leaves GameState exactly unchanged")
		elif FirstShiftManager.get_phase() == FirstShiftManager.Phase.SORTER_READY:
			var before_sorter := GameState.get_transaction_snapshot()
			_check(FirstShiftManager.commission_sorter() == FirstShiftManager.CommissionResult.SUCCESS, "Mixed path commissions Sorter at zero cost")
			_check(GameState.get_transaction_snapshot() == before_sorter, "Sorter commissioning leaves GameState exactly unchanged")
		var case_id: StringName = FirstShiftManager.FIRST_SHIFT_CASE_IDS[index]
		var should_be_correct := index % 2 == 0
		if should_be_correct:
			correct_count += 1
		await _process_case(case_id, should_be_correct)
	var before_intake := GameState.get_transaction_snapshot()
	_check(FirstShiftManager.get_phase() == FirstShiftManager.Phase.INTAKE_READY, "Mixed path reaches Intake gate")
	_check(FirstShiftManager.commission_intake() == FirstShiftManager.CommissionResult.SUCCESS, "Mixed path commissions Intake at zero cost")
	_check(GameState.get_transaction_snapshot() == before_intake, "Intake commissioning leaves GameState exactly unchanged")
	_check(FirstShiftManager.is_complete(), "Mixed First Shift completes")
	_check(correct_count == 7 and GameState.get_money() == 35, "Mixed reward is exactly 5 C times seven correct Cases")
	_check(FirstShiftManager.get_claimed_reward_case_ids().size() == 14, "Correct and zero-credit claims cover all fourteen Cases")


func _process_case(case_id: StringName, correct: bool) -> void:
	var progress := FirstShiftManager.activate_next_case()
	_check(progress != null and progress.get_case_id() == case_id, "FIFO activates " + String(case_id))
	await _settle()
	progress = CaseManager.get_active_case()
	if progress.get_state() == CaseProgress.State.ACTIVE:
		CaseManager.mark_active_case_inspected()
		progress = CaseManager.get_active_case()
	_check(progress.get_state() == CaseProgress.State.INSPECTED, "Assistance never owns classification: " + String(case_id))
	var expected := CaseManager.get_case_definition(case_id).expected_category_id
	var category := expected if correct else _wrong_category(expected)
	_check(CaseManager.set_active_case_classification(category), "Player classifies " + String(case_id))
	_check(CaseManager.archive_active_case(), "Player archives " + String(case_id))


func _wrong_category(expected: StringName) -> StringName:
	for candidate: StringName in [&"PERS", &"ELEC", &"DOCS", &"BAG"]:
		if candidate != expected:
			return candidate
	return &""


func _visible_text(root: Node) -> String:
	var values: Array[String] = []
	for child: Node in root.find_children("*", "Label", true, false):
		var label := child as Label
		if label.is_visible_in_tree():
			values.append(label.text)
	return "\n".join(values)


func _count_money_signal(_money: int) -> void:
	_money_signal_count += 1


func _backup_save() -> void:
	_original_save_exists = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _original_save_exists:
		_original_save_contents = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)


func _restore_save_backup() -> void:
	if _original_save_exists:
		var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		file.store_string(_original_save_contents)
		file.close()
	elif FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(SaveManager.SAVE_PATH)


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _check(condition_value: bool, context: String) -> void:
	_checks += 1
	if not condition_value:
		_failures += 1
		push_error("FAIL: " + context)
