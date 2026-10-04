extends Node

const ROOM := preload("res://scenes/world/archive_room.tscn")
var _checks := 0
var _failures := 0
var _room: Node2D
var _panel: ManualCasePanel
var _mutation_events := 0


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	call_deferred("_run")


func _run() -> void:
	var before := _aggregate_snapshot()
	_check(CaseManager.get_case_save_data() == CaseManager.get_default_case_save_data(), "Startup cases empty")
	_room = ROOM.instantiate()
	add_child(_room)
	await _settle()
	_panel = _room.get_node("CasePanel") as ManualCasePanel
	_check(not _panel.panel.visible, "Main scene does not automatically open case UI")
	_check(_aggregate_snapshot() == before, "Instantiating room/UI preserves aggregate state")
	_check(not _panel.open_panel(), "Empty authority cannot open panel")
	_check(SaveManager.SAVE_VERSION == 3 and CaseManager.CASE_SAVE_VERSION == 1, "Both save versions unchanged")
	_test_assets_and_inspection_data()
	for disabled: bool in [false, true]:
		await _test_lifecycle_and_isolation(disabled)
	await _test_restore_and_manual_review()
	await _test_native_input()
	await _test_layout()
	CaseManager.reset_cases()
	_room.queue_free()
	await get_tree().process_frame
	if _failures == 0:
		print("Manual case processing tests passed: %d checks." % _checks)
	else:
		push_error("Manual case processing tests failed: %d/%d" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_assets_and_inspection_data() -> void:
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/CASE_PANEL_ASSETS.json"))
	_check(provenance.assets.size() == 31, "Exact asset provenance count")
	for asset: Dictionary in provenance.assets:
		_check(FileAccess.get_sha256("res://" + asset.path) == asset.sha256, "Unmodified v1.1 runtime PNG: " + asset.path)
		var bytes := FileAccess.get_file_as_bytes("res://" + asset.path)
		_check(bytes.size() > 26 and bytes[24] == 8 and bytes[25] == 6, "Original PNG is 8-bit RGBA")
		var decoded := Image.new()
		_check(decoded.load_png_from_buffer(bytes) == OK and decoded.get_size() == Vector2i(int(asset.export_dimensions[0]), int(asset.export_dimensions[1])), "PNG decodes with exact export dimensions")
	var expected := [
		["Fabric / Nylon", "None", "Normal"], ["Glass / Aluminum", "Device serial", "Normal"],
		["Nylon / Polyester", "Luggage tag", "Normal"], ["Leather / Paper", "Document ID", "Sensitive"],
		["Plastic / Electronics", "Device serial", "Normal"], ["Canvas / Cotton", "None", "Normal"],
		["Steel / Brass", "None", "Normal"], ["Glass / Aluminum", "Device serial", "Normal"],
		["Paper / Cardboard", "File reference", "Sensitive"], ["PVC / RFID", "Unresolved", "Normal"],
	]
	for index: int in range(10):
		var definition := CaseManager.get_case_definition(StringName("CASE_%04d" % (index + 1)))
		_check([definition.inspection_material, definition.inspection_identifier, definition.inspection_risk] == expected[index], "Exact immutable inspection values")
		var texture := CaseItemPresentationCatalog.get_texture(definition.item_id)
		_check(texture != null and texture.get_size() == Vector2(512, 512), "Canonical item maps to 512x512 texture")
		var image := texture.get_image()
		_check(image.get_format() == Image.FORMAT_RGBA8 and image.detect_alpha() != Image.ALPHA_NONE, "Source RGBA transparency retained")
	var paths := DirAccess.get_files_at("res://assets/ui/case_panel")
	var png_count := 0
	for file_name: String in paths:
		if file_name.ends_with(".png"):
			png_count += 1
	_check(png_count == 21 and CaseItemPresentationCatalog.TEXTURES.size() == 10, "Exactly 31 runtime PNGs")
	for directory: String in ["res://assets/ui/case_panel", "res://assets/cases/items"]:
		for file_name: String in DirAccess.get_files_at(directory):
			if not file_name.ends_with(".png"):
				continue
			var config := ConfigFile.new()
			_check(config.load(directory.path_join(file_name + ".import")) == OK, "Runtime PNG has committed import settings")
			_check(config.get_value("params", "compress/mode") == 0 and config.get_value("params", "mipmaps/generate") == false, "Lossless import, no mipmaps")
			_check(config.get_value("params", "process/premult_alpha") == false and config.get_value("params", "process/channel_remap/alpha") == 3, "Import preserves alpha channel")
	_check(_panel.panel.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "Panel and all inherited textures use linear filtering")
	var patch := _panel.panel.get_node("PanelSurface") as NinePatchRect
	_check(patch.patch_margin_left == 36 and patch.scale == Vector2(0.5, 0.5), "2x texture margins become 18 logical pixels")
	_check(_panel.item_texture.size == Vector2(256, 256) and _panel.item_texture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Uniform centered item footprint")


func _test_lifecycle_and_isolation(disabled: bool) -> void:
	CaseManager.reset_cases()
	SimulationManager.restore_production_save_data(SimulationManager.get_default_production_save_data())
	GameState.restore_state(200, 300, 7, 12.0)
	SimulationManager.purchase_upgrade("sorter_motor_1")
	SimulationManager.simulate_elapsed(0.45)
	if disabled:
		SimulationManager.set_machine_enabled(&"archive_intake", false)
	SimulationManager._process(0.2)
	var before := _aggregate_snapshot()
	_check(CaseManager.enqueue_cases([&"CASE_0001", &"CASE_0002"]), "Explicit QA enqueue")
	CaseManager.activate_next_case()
	await _settle()
	_check(_panel.panel.visible and _panel.case_number.text == "CASE #0001", "Activation opens the correct case")
	_check(_panel.item_name.text == "Red Folding Umbrella" and _panel.found.text == "Central Station — Platform 4", "Exact item/found text")
	_check(_panel.time.text == "22:41" and _panel.condition.text == "Wet / minor wear", "Exact time/condition text")
	_check(_panel.item_texture.texture == CaseItemPresentationCatalog.get_texture(&"red_folding_umbrella"), "Correct item texture")
	_check(_panel.status.text == "ACTIVE RECORD" and _panel.pending.visible, "ACTIVE pending presentation")
	_check(_panel.material.text.is_empty() and not _panel.material.visible, "No scan data leaked before inspection")
	_check(not _panel.inspect_button.disabled and _panel.release_button.disabled, "ACTIVE action availability")
	for category_id: StringName in ManualCasePanel.CATEGORY_IDS:
		var button := _panel.category_buttons[category_id] as Button
		_check(button.disabled and button.focus_mode == Control.FOCUS_NONE, "ACTIVE categories disabled/skipped")
		button.pressed.emit()
	_panel.release_button.pressed.emit()
	_check(CaseManager.get_active_case().get_state() == CaseProgress.State.ACTIVE, "Fabricated disabled clicks do nothing")
	_test_close_reopen(CaseProgress.State.ACTIVE)
	_panel.inspect_button.pressed.emit()
	await _settle()
	_check(CaseManager.get_active_case().get_state() == CaseProgress.State.INSPECTED, "Inspect uses CaseManager authority")
	_check(_panel.material.text == "Fabric / Nylon" and _panel.identifier.text == "None" and _panel.risk.text == "Normal", "Exact scan data rendered")
	_check(_panel.inspection_check.visible and not _panel.pending.visible, "Restrained inspection confirmation")
	_check(_panel.inspect_button.disabled and _panel.release_button.disabled, "INSPECTED buttons")
	for category_id: StringName in ManualCasePanel.CATEGORY_IDS:
		var button := _panel.category_buttons[category_id] as Button
		_check(not button.disabled and not bool(button.get_meta("selected")), "All categories equally legitimate, none privileged")
		var expected_surface := "category_hover_9patch_2x.png" if button.has_focus() or button.is_hovered() else "category_base_9patch_2x.png"
		_check((button.get_node("Surface") as NinePatchRect).texture.resource_path.ends_with(expected_surface), "Only native hover/focus, never expected-answer highlighting")
	_test_close_reopen(CaseProgress.State.INSPECTED)
	(_panel.category_buttons[&"ELEC"] as Button).pressed.emit()
	await _settle()
	_check(CaseManager.get_active_case().get_state() == CaseProgress.State.CLASSIFIED and CaseManager.get_active_case().get_selected_category_id() == &"ELEC", "Wrong but valid category accepted")
	_check(not CaseManager.is_case_classification_correct(&"CASE_0001"), "QA confirms deliberately wrong classification")
	_check(not _panel.release_button.disabled and _panel.inspect_button.disabled, "CLASSIFIED release enabled")
	for category_id: StringName in ManualCasePanel.CATEGORY_IDS:
		var button := _panel.category_buttons[category_id] as Button
		_check(button.disabled and bool(button.get_meta("selected")) == (category_id == &"ELEC"), "Only chosen category selected; all noneditable")
	_check((_panel.category_buttons[&"ELEC"] as Button).get_node("Code").text == "✓ ELEC", "Selected state is not color-only")
	_check(_panel.status.text == "CLASSIFIED", "Status carries no correctness feedback")
	_test_close_reopen(CaseProgress.State.CLASSIFIED)
	(_panel.category_buttons[&"PERS"] as Button).pressed.emit()
	_panel.inspect_button.pressed.emit()
	_check(CaseManager.get_active_case().get_selected_category_id() == &"ELEC", "Disabled reclassification/reinspection harmless")
	_panel.release_button.pressed.emit()
	await _settle()
	_check(CaseManager.get_case_progress(&"CASE_0001").get_state() == CaseProgress.State.ARCHIVED, "Release archives through authority")
	_check(not CaseManager.has_active_case() and not _panel.panel.visible, "Archive clears active and closes UI")
	_check(CaseManager.get_queue_snapshot() == [&"CASE_0002"], "No automatic next case")
	for key: String in before.keys():
		_check(before[key] == _aggregate_snapshot()[key], "UI authority isolation: " + key)
	_check(before == _aggregate_snapshot(), "All aggregate values unchanged by complete UI processing")
	print("Manual UI isolation (%s): money=175 earned=300 items=7 fraction=0.45 pending=0.2 throughput=%.1f owned=sorter_motor_1 flags/save=UNCHANGED" % ["stopped" if disabled else "running", float(before.throughput)])
	CaseManager.reset_cases()


func _test_close_reopen(expected_state: CaseProgress.State) -> void:
	var before := CaseManager.get_case_save_data()
	_panel.close_button.pressed.emit()
	_check(not _panel.panel.visible and CaseManager.get_case_save_data() == before, "Close is presentation-only")
	_check(_panel.open_panel(), "Existing active case can reopen")
	_check(CaseManager.get_active_case().get_state() == expected_state and CaseManager.get_case_save_data() == before, "Reopen preserves authoritative progress/selection")
	_check(_panel.status.text == ("ACTIVE RECORD" if expected_state == CaseProgress.State.ACTIVE else CaseProgress.STATE_LABELS[expected_state]), "Reopen reconstructs exact presentation")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	_panel._unhandled_key_input(cancel)
	_check(not _panel.panel.visible and CaseManager.get_case_save_data() == before, "Escape only closes")
	_panel.open_panel()


func _test_restore_and_manual_review() -> void:
	CaseManager.reset_cases()
	var restored := {
		"case_save_version": 1, "queue": [], "active_case_id": "CASE_0001",
		"progress": [{"case_id": "CASE_0001", "state": "CLASSIFIED", "selected_category_id": "DOCS"}],
	}
	CaseManager.queue_changed.connect(_count_mutation)
	CaseManager.active_case_changed.connect(_count_mutation)
	CaseManager.case_progress_changed.connect(_count_progress)
	_mutation_events = 0
	var before := _aggregate_snapshot()
	_check(CaseManager.restore_case_save_data(restored), "Valid classified restore accepted")
	await _settle()
	_check(_mutation_events == 2, "Only restore's active/progress notifications; UI adds no mutation")
	_check(not _panel.release_button.disabled and bool((_panel.category_buttons[&"DOCS"] as Button).get_meta("selected")), "Restore renders chosen category and release")
	var saved := CaseManager.get_case_save_data()
	for _index: int in range(5):
		_panel.refresh_from_authority()
	_check(_mutation_events == 2 and CaseManager.get_case_save_data() == saved, "Repeated refresh is read-only")
	_check(_aggregate_snapshot() == before, "Signal-driven refresh/restore gives no rewards")
	_check(saved.size() == 4 and saved.progress[0].size() == 3 and not JSON.stringify(saved).contains("inspection_"), "Inspection definitions absent from unchanged case-save v1")
	CaseManager.queue_changed.disconnect(_count_mutation)
	CaseManager.active_case_changed.disconnect(_count_mutation)
	CaseManager.case_progress_changed.disconnect(_count_progress)
	CaseManager.reset_cases()
	CaseManager.enqueue_case(&"CASE_0010")
	CaseManager.activate_next_case()
	await _settle()
	_check(_panel.case_number.text == "CASE #0010" and _panel.item_name.text == "Black Hotel Keycard", "Exact manual-review case/item")
	_check(_panel.found.text == "Archive Sector A1" and _panel.time.text == "23:34" and _panel.condition.text == "Dry / light edge wear", "Exact manual-review metadata")
	_check(_panel.manual_review.visible and _panel.manual_review.get_node("Label").text == "MANUAL REVIEW", "Administrative-only amber treatment")
	_panel.inspect_button.pressed.emit()
	_check(_panel.material.text == "PVC / RFID" and _panel.identifier.text == "Unresolved" and _panel.risk.text == "Normal", "Keycard scan data is ordinary authored text")
	_check(_aggregate_snapshot() == before, "Manual review has no production effects")
	CaseManager.reset_cases()


func _test_layout() -> void:
	for index: int in range(10):
		CaseManager.reset_cases()
		CaseManager.enqueue_case(StringName("CASE_%04d" % (index + 1)))
		CaseManager.activate_next_case()
		await _settle()
		_check(_panel.found.get_line_count() <= 2, "Every authored FOUND fits two lines")
		_check(_panel.condition.get_theme_font("font").get_string_size(_panel.condition.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x <= _panel.condition.size.x, "Full authored CONDITION fits without cropping")
		CaseManager.mark_active_case_inspected()
		_check((_panel.category_buttons[&"PERS"] as Button).has_focus(), "Initial category focus is always PERS, independent of expected answer")
		for label: Label in [_panel.material, _panel.identifier, _panel.risk]:
			_check(label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x <= label.size.x, "Authored inspection text fits without cropping")
	CaseManager.reset_cases()
	CaseManager.enqueue_case(&"CASE_0001")
	CaseManager.activate_next_case()
	for physical_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = physical_size
		await _settle()
		_check(_panel.panel.get_rect() == Rect2(1028, 176, 824, 708), "Approved logical panel bounds remain fixed")
		_check(_panel.panel.get_global_rect().end.x <= 1920 and _panel.panel.get_global_rect().end.y <= 1080, "Panel in logical canvas")
		for control: Control in [_panel.close_button, _panel.inspect_button, _panel.release_button, _panel.item_texture, _panel.item_name, _panel.found, _panel.material]:
			_check(_panel.panel.get_global_rect().encloses(control.get_global_rect()), "Relevant control fits panel at " + str(physical_size))
		_check(_panel.found.size.y >= _panel.found.get_line_height() * 2, "FOUND has two readable lines")
		_check(_panel.item_name.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "Long item names ellipsize")
		var scale := float(physical_size.x) / 1920.0
		for button: Button in _panel.category_buttons.values():
			_check(button.size.y * scale >= 52 and button.size.x * scale >= 87, "Large category hit targets")
			_check((button.get_node("Subtitle") as Label).get_theme_font_size("font_size") * scale >= 8, "Category subtitle meets package minimum")
		for path: String in ["%CreditsValue", "%ThroughputValue", "%BottleneckValue", "%UpgradeButton", "%DebugDashboardButton"]:
			var hud_control := _room.get_node("GameplayHUD").get_node(path) as Control
			_check(not hud_control.get_global_rect().intersects(_panel.panel.get_global_rect()), "Panel does not overlap existing HUD: " + path)
		_check((_room.get_node("GameplayHUD") as CanvasLayer).layer > _panel.layer, "HUD/modal upgrade shop remains above case panel")
		var hud := _room.get_node("GameplayHUD")
		hud.open_upgrade_shop()
		_check(hud.upgrade_overlay.visible and _panel.panel.visible, "Existing shop usable without mutating case visibility")
		hud.close_upgrade_shop()
		_check(_panel.inspect_button.get_node(_panel.inspect_button.focus_next) == _panel.close_button, "ACTIVE deterministic focus skips disabled categories/release")
		print("Manual UI layout %dx%d PASS: approved bounds, controls/HUD accessible, minimum physical subtitle %.1fpx" % [physical_size.x, physical_size.y, 16.0 * scale])
	# Rebuild a second panel with an already classified authority: no UI cache needed.
	CaseManager.mark_active_case_inspected()
	CaseManager.classify_active_case(&"BAG")
	var recreated := (load("res://scenes/ui/case_panel.tscn") as PackedScene).instantiate() as ManualCasePanel
	add_child(recreated)
	await _settle()
	_check(recreated.panel.visible and not recreated.release_button.disabled and bool((recreated.category_buttons[&"BAG"] as Button).get_meta("selected")), "Fresh instance reconstructs existing classified authority")
	recreated.queue_free()
	await get_tree().process_frame


func _test_native_input() -> void:
	CaseManager.enqueue_case(&"CASE_0001")
	CaseManager.activate_next_case()
	await _settle()
	_check(_panel.inspect_button.has_focus(), "Opening ACTIVE panel focuses Inspect")
	await _key(KEY_TAB)
	_check(_panel.close_button.has_focus(), "Tab skips disabled categories/release")
	await _key(KEY_TAB)
	_check(_panel.inspect_button.has_focus(), "Tab wraps deterministically")
	await _key(KEY_ENTER)
	_check(CaseManager.get_active_case().get_state() == CaseProgress.State.INSPECTED, "Real Godot key event invokes native Inspect button")
	_check((_panel.category_buttons[&"PERS"] as Button).has_focus(), "Inspection transfers focus to first enabled category")
	(_panel.category_buttons[&"ELEC"] as Button).grab_focus()
	await _key(KEY_SPACE)
	_check(CaseManager.get_active_case().get_selected_category_id() == &"ELEC", "Space invokes focused category without correctness gating")
	_check(_panel.release_button.has_focus(), "Classification transfers focus to enabled Release")
	_panel.release_button.grab_focus()
	await _key(KEY_ESCAPE)
	_check(not _panel.panel.visible and CaseManager.get_active_case().get_state() == CaseProgress.State.CLASSIFIED, "Native Escape closes without archiving")
	_panel.open_panel()
	await _key(KEY_ENTER)
	_check(not CaseManager.has_active_case() and not _panel.panel.visible, "Native Enter invokes focused Release")
	CaseManager.reset_cases()
	CaseManager.enqueue_case(&"CASE_0001")
	CaseManager.activate_next_case()
	await _settle()
	await _mouse(_panel.category_buttons[&"ELEC"] as Button)
	_check(CaseManager.get_active_case().get_state() == CaseProgress.State.ACTIVE, "Native mouse click on disabled category is harmless")
	await _mouse(_panel.inspect_button)
	_check(CaseManager.get_active_case().get_state() == CaseProgress.State.INSPECTED, "Native mouse hit test reaches Inspect through HUD")
	await _mouse(_panel.category_buttons[&"ELEC"] as Button)
	_check(CaseManager.get_active_case().get_state() == CaseProgress.State.CLASSIFIED and CaseManager.get_active_case().get_selected_category_id() == &"ELEC", "Native category click classifies wrong answer")
	await _mouse(_panel.release_button)
	_check(not CaseManager.has_active_case() and not _panel.panel.visible, "Native Release mouse click archives")
	CaseManager.reset_cases()
	CaseManager.enqueue_case(&"CASE_0001")
	CaseManager.activate_next_case()
	var checkpoint := CaseManager.get_case_save_data()
	var hud := _room.get_node("GameplayHUD")
	await _mouse(hud.get_node("%UpgradeButton") as Button)
	_check(hud.upgrade_overlay.visible and CaseManager.get_case_save_data() == checkpoint, "Native mouse still reaches existing Upgrade shop while case open")
	await _mouse(hud.get_node("%CloseShopButton") as Button)
	_check(not hud.upgrade_overlay.visible and _panel.panel.visible and CaseManager.get_case_save_data() == checkpoint, "Native shop close leaves case untouched")
	CaseManager.reset_cases()


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	get_viewport().push_input(event)
	event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = false
	get_viewport().push_input(event)
	await _settle()


func _mouse(button: Button) -> void:
	# push_input(..., true) expects local viewport/canvas coordinates, not
	# physical window pixels (headless windows can default to just 64x64).
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = false
	get_viewport().push_input(event, true)
	await _settle()


func _aggregate_snapshot() -> Dictionary:
	var line: ProductionLine = SimulationManager.get_production_line()
	var flags := {}
	for stage: MachineRuntime in line.get_stages():
		flags[String(stage.get_id())] = stage.is_enabled()
	return {"money": GameState.get_money(), "earned": GameState.get_total_money_earned(), "items": GameState.get_total_processed_items(), "fraction": line.get_fractional_progress(), "pending": SimulationManager.get_pending_simulation_seconds(), "throughput": line.get_effective_throughput(), "upgrades": SimulationManager.get_owned_upgrade_ids(), "flags": flags, "production_save": SimulationManager.get_production_save_data()}


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _count_mutation() -> void:
	_mutation_events += 1


func _count_progress(_case_id: StringName) -> void:
	_mutation_events += 1


func _check(condition_value: bool, context: String) -> void:
	_checks += 1
	if not condition_value:
		_failures += 1
		push_error("FAIL: " + context)
