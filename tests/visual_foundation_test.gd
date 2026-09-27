extends Node

const EPSILON := 0.00001
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const TARGET_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1280, 720),
	Vector2i(960, 540),
]
const ARCHIVE_ROOM_SCENE: PackedScene = preload("res://scenes/world/archive_room.tscn")

var _failures := 0


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_project_configuration()
	var room := await _test_archive_room_layout_and_hud()
	await _test_scanner_asset_layers_and_occlusion(room)
	await _test_scanner_visual_states(room)
	await _test_gameplay_hud_purchase(room)
	await _test_presentation_does_not_change_simulation(room)

	if _failures == 0:
		print("Visual foundation tests passed for 1920x1080, 1280x720, and 960x540.")
		get_tree().quit(0)
	else:
		push_error("Visual foundation tests failed: %d" % _failures)
		get_tree().quit(1)


func _test_project_configuration() -> void:
	_expect_equal(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920, "Logical width is Full HD")
	_expect_equal(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080, "Logical height is Full HD")
	_expect_equal(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "Canvas-items stretching is enabled")
	_expect_equal(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep", "Aspect ratio is preserved")
	_expect_equal(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "fractional", "Fractional scaling is enabled")
	_expect_equal(ProjectSettings.get_setting("display/window/size/window_width_override"), 1280, "Development window fits common displays")
	_expect_equal(ProjectSettings.get_setting("display/window/size/window_height_override"), 720, "Development window uses a 16:9 size")
	_expect_true(bool(ProjectSettings.get_setting("display/window/size/resizable")), "Windowed mode is resizable")


func _test_archive_room_layout_and_hud() -> Node2D:
	_reset_simulation()
	var room := ARCHIVE_ROOM_SCENE.instantiate() as Node2D
	add_child(room)
	await get_tree().process_frame
	await get_tree().process_frame

	for required_path in [
		"DistantBackground",
		"ArchitecturalMidground",
		"PlayableGround",
		"Conveyors",
		"Machines",
		"Foreground",
		"EffectsLayer",
		"RoomCamera",
		"GameplayHUD",
	]:
		_expect_true(room.has_node(required_path), "ArchiveRoom contains %s" % required_path)

	var layout: Dictionary = room.get_layout_snapshot()
	_expect_vector(layout["camera_center"], Vector2(960.0, 540.0), "Fixed camera is centered on the room")
	_expect_machine_layout(layout, "receiving_desk", Vector2(268.0, 920.0), Vector2(336.0, 352.0))
	_expect_machine_layout(layout, "basic_scanner", Vector2(708.0, 920.0), Vector2(384.0, 416.0))
	_expect_machine_layout(layout, "basic_sorter", Vector2(1204.0, 920.0), Vector2(480.0, 360.0))
	_expect_machine_layout(layout, "archive_intake", Vector2(1668.0, 920.0), Vector2(304.0, 464.0))
	var conveyor_layout: Dictionary = layout["conveyor"] as Dictionary
	_expect_close(float(conveyor_layout["item_path_y"]), 688.0, "Conveyor item path uses approved Y")
	_expect_close(float(conveyor_layout["ground_baseline_y"]), 920.0, "Machines share approved ground baseline")
	var conveyor: ConveyorPlaceholderVisual = room.get_node("%Conveyor") as ConveyorPlaceholderVisual
	var draw_geometry := conveyor.get_draw_geometry_snapshot()
	_expect_close(float(draw_geometry["parcel_bottom_y"]), 703.0, "Parcel drawing keeps the approved path-centered height")
	_expect_close(float(draw_geometry["visible_belt_surface_y"]), 703.0, "Visible conveyor surface reaches the parcel bottom")
	_expect_close(float(draw_geometry["contact_gap"]), 0.0, "Parcels meet the conveyor without floating or sinking")

	var camera := room.get_node("RoomCamera") as Camera2D
	_expect_true(camera.enabled, "Room camera is enabled")
	_expect_true(not camera.position_smoothing_enabled, "First room camera remains fixed")
	_expect_equal(camera.limit_left, 0, "Camera left limit is fixed")
	_expect_equal(camera.limit_right, 1920, "Camera right limit is fixed")

	var hud: CanvasLayer = room.get_node("GameplayHUD") as CanvasLayer
	var credits: Label = hud.get_node("%CreditsValue") as Label
	var throughput: Label = hud.get_node("%ThroughputValue") as Label
	var bottleneck: Label = hud.get_node("%BottleneckValue") as Label
	var upgrade_button: Button = hud.get_node("%UpgradeButton") as Button
	var display_button: Button = hud.get_node("%DisplayModeButton") as Button
	_expect_true(credits != null and not credits.text.is_empty(), "HUD shows Credits")
	_expect_true(throughput != null and throughput.text.contains("items/sec"), "HUD shows throughput")
	_expect_true(bottleneck != null and not bottleneck.text.is_empty(), "HUD shows bottleneck")
	_expect_true(upgrade_button != null and upgrade_button.visible, "HUD exposes upgrade shop")
	_expect_true(display_button != null and display_button.visible, "HUD exposes fullscreen/windowed switching")

	hud.open_upgrade_shop()
	await get_tree().process_frame
	var shop: PanelContainer = hud.get_node("%UpgradePanel") as PanelContainer
	var scroll: ScrollContainer = hud.get_node("%UpgradeScroll") as ScrollContainer
	var rows: VBoxContainer = hud.get_node("%UpgradeRows") as VBoxContainer
	_expect_equal(rows.get_child_count(), 2, "Upgrade shop contains exactly the two existing upgrades")
	_expect_equal(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "Upgrade shop disables horizontal scrolling")
	_expect_equal(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "Upgrade shop supports vertical scrolling")
	_expect_true(shop.size.x <= DESIGN_SIZE.x and shop.size.y <= DESIGN_SIZE.y, "Upgrade panel fits logical design frame")

	var readability: Dictionary = hud.get_readability_snapshot()
	for resolution: Vector2i in TARGET_RESOLUTIONS:
		var scale := minf(float(resolution.x) / DESIGN_SIZE.x, float(resolution.y) / DESIGN_SIZE.y)
		var physical_font_size := float(readability["minimum_font_size"]) * scale
		var physical_button_size: Vector2 = (readability["primary_button_size"] as Vector2) * scale
		var physical_shop_size: Vector2 = (readability["shop_panel_size"] as Vector2) * scale
		_expect_true(physical_font_size >= 12.0, "%s keeps UI text at least 12 physical pixels" % resolution)
		_expect_true(physical_button_size.x >= 120.0 and physical_button_size.y >= 32.0, "%s keeps primary button readable and clickable" % resolution)
		_expect_true(physical_shop_size.x <= resolution.x and physical_shop_size.y <= resolution.y, "%s keeps upgrade shop inside the display" % resolution)
		for machine_id in ["receiving_desk", "basic_scanner", "basic_sorter", "archive_intake"]:
			var machine: Dictionary = layout[machine_id] as Dictionary
			var physical_size: Vector2 = (machine["size"] as Vector2) * scale
			_expect_true(physical_size.x >= 150.0 and physical_size.y >= 176.0, "%s keeps %s visible at usable scale" % [resolution, machine_id])

	hud.close_upgrade_shop()
	return room


func _test_scanner_visual_states(room: Node2D) -> void:
	_reset_simulation()
	await get_tree().process_frame
	var scanner: BasicScannerVisual = room.get_node("%BasicScanner") as BasicScannerVisual
	var state := scanner.get_state_snapshot()
	_expect_true(bool(state["enabled"]), "Scanner visual starts enabled")
	_expect_true(bool(state["active"]), "Scanner visual responds to active production")
	_expect_true(not bool(state["upgraded"]), "Scanner visual starts without Motor I")
	_expect_true(bool(state["idle_visible"]), "Enabled scanner shows its independent idle lighting")
	_expect_true(bool(state["scan_visible"]), "Active production shows the cyan scan beam")
	_expect_true(not bool(state["upgrade_visible"]), "Motor I layer starts hidden")

	GameState.restore_state(25, 25, 0, 0.0)
	SimulationManager.purchase_upgrade("sorter_motor_1")
	await get_tree().process_frame
	state = scanner.get_state_snapshot()
	_expect_true(bool(state["bottleneck"]), "Scanner art receives bottleneck feedback after Sorter Motor I")

	_reset_simulation()
	await get_tree().process_frame

	SimulationManager.set_machine_enabled(&"basic_scanner", false)
	await get_tree().process_frame
	state = scanner.get_state_snapshot()
	_expect_true(not bool(state["enabled"]) and not bool(state["active"]), "Scanner visual responds to disabled state")
	_expect_true(not bool(state["idle_visible"]) and not bool(state["scan_visible"]), "Disabled scanner turns off lighting and scan layers")
	_expect_true(scanner.scanner_back.self_modulate != Color.WHITE, "Disabled scanner dims the rear casing")
	_expect_true(scanner.scanner_front.self_modulate != Color.WHITE, "Disabled scanner dims the front frame")

	SimulationManager.set_machine_enabled(&"basic_scanner", true)
	GameState.restore_state(50, 50, 0, 0.0)
	var purchase_result := SimulationManager.purchase_upgrade("scanner_motor_1")
	await get_tree().process_frame
	state = scanner.get_state_snapshot()
	_expect_equal(purchase_result, SimulationManager.PurchaseResult.SUCCESS, "Scanner upgrade purchase succeeds")
	_expect_true(bool(state["upgraded"]), "Scanner visual displays owned Motor I")
	_expect_true(bool(state["upgrade_visible"]), "Motor I owns an independently toggleable render layer")
	_expect_true(bool(state["active"]), "Scanner remains active after upgrade")

	SimulationManager.set_machine_enabled(&"basic_scanner", false)
	await get_tree().process_frame
	state = scanner.get_state_snapshot()
	_expect_true(bool(state["upgrade_visible"]), "Motor I remains installed while scanner is disabled")
	_expect_true(not bool(state["scan_visible"]), "Motor I visibility does not force active scanning")


func _test_scanner_asset_layers_and_occlusion(room: Node2D) -> void:
	var scanner: BasicScannerVisual = room.get_node("%BasicScanner") as BasicScannerVisual
	var parcels: DecorativeParcelVisual = room.get_node("%DecorativeParcels") as DecorativeParcelVisual
	var conveyor: ConveyorPlaceholderVisual = room.get_node("%Conveyor") as ConveyorPlaceholderVisual
	var geometry := scanner.get_asset_geometry_snapshot()

	_expect_vector(scanner.position, Vector2(708.0, 920.0), "Scanner art preserves approved world pivot")
	_expect_vector(geometry["export_size"], Vector2(768.0, 832.0), "Scanner layers use the verified 768x832 export canvas")
	_expect_vector(geometry["display_size"], Vector2(384.0, 416.0), "Scanner layers display at approved 384x416 size")
	_expect_vector(geometry["layer_center"], Vector2(0.0, -208.0), "Scanner layer centre produces a bottom-centre pivot")
	_expect_vector(geometry["layer_scale"], Vector2(0.5, 0.5), "Scanner 2x exports resolve to native logical size")
	_expect_close(scanner.position.y + float(geometry["parcel_center_local_y"]), 688.0, "Scanner opening aligns to parcel centreline")
	_expect_close(scanner.position.y + float(geometry["conveyor_contact_local_y"]), 703.0, "Scanner opening aligns to conveyor contact surface")
	_expect_equal(scanner.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "Scanner uses linear filtering for fractional display scaling")

	var layers: Array[Sprite2D] = [
		scanner.scanner_back,
		scanner.idle_emissive,
		scanner.scan_beam,
		scanner.scanner_front,
		scanner.motor_upgrade,
	]
	for layer: Sprite2D in layers:
		_expect_vector(layer.texture.get_size(), Vector2(768.0, 832.0), "%s keeps the shared export canvas" % layer.name)
		_expect_vector(layer.scale, Vector2(0.5, 0.5), "%s keeps shared display scale" % layer.name)
		_expect_true(not layer.z_as_relative, "%s uses explicit presentation-layer ordering" % layer.name)

	_expect_true(int(geometry["back_z"]) < parcels.z_index, "Parcels render in front of scanner rear casing")
	_expect_true(parcels.z_index < int(geometry["idle_z"]), "Scanner lighting can illuminate parcels")
	_expect_true(parcels.z_index < int(geometry["front_z"]), "Parcels render behind scanner front frame")
	_expect_true(int(geometry["front_z"]) < int(geometry["upgrade_z"]), "Motor I remains above the front frame")
	_expect_true(room.get_node("Conveyors").z_index < parcels.z_index, "Parcels are separated from the conveyor surface layer")

	var front_image := scanner.scanner_front.texture.get_image()
	var back_image := scanner.scanner_back.texture.get_image()
	var motor_image := scanner.motor_upgrade.texture.get_image()
	_expect_close(front_image.get_pixel(384, 368).a, 0.0, "Front mask is transparent at parcel centre in the scanner opening")
	_expect_true(front_image.get_pixel(150, 368).a > 0.0, "Front mask retains opaque side-frame occlusion")
	_expect_true(back_image.get_pixel(384, 368).a > 0.0, "Rear casing provides the visible chamber behind parcels")
	_expect_close(motor_image.get_pixel(384, 368).a, 0.0, "Motor I layer does not obstruct the scanner opening")

	var parcel_inside_opening := false
	for item_position: Vector2 in parcels.get_item_positions():
		if item_position.x > 607.0 and item_position.x < 809.0 and is_equal_approx(item_position.y, 688.0):
			parcel_inside_opening = true
			break
	_expect_true(parcel_inside_opening, "Decorative parcel path crosses the transparent scanner opening")
	_expect_equal(parcels.get_item_positions(), conveyor.get_item_positions(), "Parcel renderer reads positions without owning simulation")

	scanner.set_process(false)
	scanner.set_scan_phase_for_preview(0.25)
	var high_offset := float(scanner.get_state_snapshot()["scan_offset_y"])
	scanner.set_scan_phase_for_preview(0.75)
	var low_offset := float(scanner.get_state_snapshot()["scan_offset_y"])
	_expect_close(high_offset, 47.0, "Active scan line reaches approved lower travel")
	_expect_close(low_offset, -47.0, "Active scan line reaches approved upper travel")
	scanner.set_scan_phase_for_preview(0.0)
	scanner.set_process(true)


func _test_gameplay_hud_purchase(room: Node2D) -> void:
	_reset_simulation(25)
	await get_tree().process_frame
	var hud: CanvasLayer = room.get_node("GameplayHUD") as CanvasLayer
	hud.open_upgrade_shop()
	await get_tree().process_frame
	var sorter_purchase := hud.get_node("%UpgradeRows").find_child("Purchase_sorter_motor_1", true, false) as Button
	_expect_true(sorter_purchase != null and not sorter_purchase.disabled, "Sorter purchase is reachable from gameplay HUD")
	if sorter_purchase != null:
		sorter_purchase.pressed.emit()
		await get_tree().process_frame
		_expect_true(SimulationManager.owns_upgrade("sorter_motor_1"), "Gameplay HUD purchase installs Sorter Motor I")
		_expect_equal(GameState.get_money(), 0, "Gameplay HUD purchase deducts exactly 25 Credits")
	hud.close_upgrade_shop()


func _test_presentation_does_not_change_simulation(room: Node2D) -> void:
	room.queue_free()
	await get_tree().process_frame
	_reset_simulation()
	SimulationManager.simulate_elapsed(100.0)
	var without_room := _simulation_snapshot()

	_reset_simulation()
	var room_with_visuals := ARCHIVE_ROOM_SCENE.instantiate() as Node2D
	add_child(room_with_visuals)
	await get_tree().process_frame
	var conveyor: ConveyorPlaceholderVisual = room_with_visuals.get_node("%Conveyor") as ConveyorPlaceholderVisual
	var before_visual_advance := _simulation_snapshot()
	var item_positions_before := conveyor.get_item_positions()
	conveyor.advance_visuals(12.0)
	var item_positions_after := conveyor.get_item_positions()
	_expect_true(item_positions_before != item_positions_after, "Decorative conveyor items animate")
	_expect_equal(_simulation_snapshot(), before_visual_advance, "Decorative animation cannot mutate production or Credits")
	SimulationManager.simulate_elapsed(100.0)
	var with_room := _simulation_snapshot()
	_expect_equal(with_room, without_room, "Simulation results are identical with ArchiveRoom active or inactive")
	print(
		"ArchiveRoom invariance: items=%d, credits=%d, fraction=%.5f, throughput=%.2f" % [
			with_room["items"], with_room["credits"], with_room["fraction"], with_room["throughput"]
		]
	)
	room_with_visuals.queue_free()


func _simulation_snapshot() -> Dictionary:
	return {
		"credits": GameState.get_money(),
		"items": GameState.get_total_processed_items(),
		"fraction": SimulationManager.get_production_line().get_fractional_progress(),
		"throughput": SimulationManager.get_effective_throughput(),
		"owned": SimulationManager.get_owned_upgrade_ids(),
	}


func _reset_simulation(money: int = 0) -> void:
	GameState.restore_state(money, money, 0, 0.0)
	SimulationManager.restore_production_save_data(SimulationManager.get_default_production_save_data())


func _expect_machine_layout(layout: Dictionary, machine_id: String, expected_pivot: Vector2, expected_size: Vector2) -> void:
	var machine: Dictionary = layout[machine_id] as Dictionary
	_expect_vector(machine["pivot"], expected_pivot, "%s uses approved pivot" % machine_id)
	_expect_vector(machine["size"], expected_size, "%s uses approved visual size" % machine_id)
	var pivot: Vector2 = machine["pivot"] as Vector2
	var size: Vector2 = machine["size"] as Vector2
	var rect := Rect2(pivot - Vector2(size.x * 0.5, size.y), size)
	_expect_true(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= DESIGN_SIZE.x and rect.end.y <= DESIGN_SIZE.y, "%s stays inside camera frame" % machine_id)


func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failures += 1
	push_error("FAILED: %s" % message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	push_error("FAILED: %s (expected %s, got %s)" % [message, expected, actual])


func _expect_close(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) <= EPSILON:
		return
	_failures += 1
	push_error("FAILED: %s (expected %.5f, got %.5f)" % [message, expected, actual])


func _expect_vector(actual: Vector2, expected: Vector2, message: String) -> void:
	if actual.is_equal_approx(expected):
		return
	_failures += 1
	push_error("FAILED: %s (expected %s, got %s)" % [message, expected, actual])
