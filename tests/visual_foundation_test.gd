extends Node

const EPSILON := 0.00001
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const TARGET_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1280, 720),
	Vector2i(960, 540),
]
const LINEAR_ALPHA_SAMPLE_STEP := 0.25
const LINEAR_ALPHA_EPSILON := 1.0 / 65535.0
const TRANSPARENT_MASK_ALPHA_LIMIT := 1.0 / 255.0
const PARCEL_FILTER_EDGE_ALLOWANCE := 0.5
const ARCHIVE_ROOM_SCENE: PackedScene = preload("res://scenes/world/archive_room.tscn")

var _failures := 0


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_project_configuration()
	var room := await _test_archive_room_layout_and_hud()
	_test_environment_art_and_lighting(room)
	_test_modular_conveyor(room)
	_test_receiving_desk_asset_layers_and_handoff(room)
	await _test_receiving_desk_visual_states(room)
	_test_sorter_asset_layers_and_occlusion(room)
	await _test_sorter_visual_states_and_restoration(room)
	await _test_scanner_asset_layers_and_occlusion(room)
	await _test_scanner_visual_states(room)
	await _test_gameplay_hud_purchase(room)
	_test_sorter_gate_parcel_clearance(room)
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


func _test_environment_art_and_lighting(room: Node2D) -> void:
	var environment := room.get_node("%EnvironmentArt") as ArchiveRoomEnvironmentVisual
	var layout := environment.get_layout_snapshot()
	_expect_equal(layout["runtime_texture_count"], 13, "Environment scene references all 13 non-conveyor runtime textures")
	_expect_equal(layout["decoded_texture_bytes"], 6_985_816, "Documented package texture residency remains exact")
	_expect_equal(layout["distant_z"], -100, "Distant archive uses absolute rear Z")
	_expect_equal(layout["rear_wall_z"], -82, "Rear wall uses manifest Z")
	_expect_equal(layout["catwalk_z"], -79, "Catwalk uses manifest Z")
	_expect_equal(layout["roof_z"], -71, "Roof uses manifest Z")
	_expect_equal(layout["pillars_z"], -70, "Pillars use manifest Z")
	_expect_equal(layout["cables_z"], -69, "Cables use manifest Z")
	_expect_equal(layout["decor_z"], -65, "Background decor uses manifest Z")
	_expect_equal(layout["light_cones_z"], -52, "Transparent cones remain behind lamp housings")
	_expect_equal(layout["lamp_housings_z"], -51, "Lamp housings retain independent draw order")
	_expect_equal(layout["floor_z"], -10, "Floor starts at machine baseline layer")
	_expect_equal(layout["floor_reflections_z"], -9, "Floor reflections remain independently layered")
	_expect_equal(layout["wall_tile_count"], 16, "Rear wall repeats two rows of eight shared tiles")
	_expect_equal(layout["catwalk_tile_count"], 8, "Catwalk fills the fixed camera width")
	_expect_equal(layout["roof_tile_count"], 8, "Roof fills the fixed camera width")
	_expect_equal(layout["floor_tile_count"], 8, "Floor fills the fixed camera width")
	_expect_equal(layout["pillar_positions"], PackedVector2Array([Vector2(86, 162), Vector2(900, 162), Vector2(1710, 162)]), "Pillars follow placement manifest")
	_expect_equal(layout["lamp_positions"], PackedVector2Array([Vector2(190, 146), Vector2(1020, 146), Vector2(1520, 146)]), "Lamp housings use top-left positions derived from manifest centres")
	_expect_equal(layout["light_cone_positions"], PackedVector2Array([Vector2(104, 262), Vector2(934, 262), Vector2(1434, 262)]), "Light cones align independently below lamp centres")
	_expect_equal(layout["floor_reflection_positions"], PackedVector2Array([Vector2(48, 920), Vector2(878, 920), Vector2(1378, 920)]), "Floor pools align to the ground baseline")

	for placeholder_layer in ["DistantBackground", "ArchitecturalMidground", "PlayableGround", "Foreground"]:
		var layer := room.get_node(placeholder_layer)
		_expect_equal(layer.get_child_count(), 0, "%s no longer contains greybox ColorRect artwork" % placeholder_layer)

	environment.set_light_cones_visible(false)
	_expect_true(not environment.light_cones.visible and environment.lamp_housings.visible, "Light cones toggle independently from housings")
	environment.set_floor_reflections_visible(false)
	_expect_true(not environment.floor_reflections.visible and environment.lamp_housings.visible, "Floor reflections toggle independently from housings")
	environment.set_light_housings_visible(false)
	_expect_true(not environment.lamp_housings.visible and not environment.wall_sconces.visible, "Lamp housings and sconces share only their housing toggle")
	environment.set_light_cones_visible(true)
	environment.set_floor_reflections_visible(true)
	environment.set_light_housings_visible(true)


func _test_modular_conveyor(room: Node2D) -> void:
	var conveyor := room.get_node("%Conveyor") as ConveyorPlaceholderVisual
	var surface_modules := conveyor.get_node("%SurfaceModules") as Node2D
	var supports := conveyor.get_node("Supports") as Node2D
	var layout := conveyor.get_layout_snapshot()
	var geometry := conveyor.get_draw_geometry_snapshot()
	_expect_equal(surface_modules.get_child_count(), 11, "Conveyor uses one left cap, nine straights, and one right cap")
	_expect_equal(supports.get_child_count(), 8, "Conveyor supports remain independent reusable modules")
	_expect_equal(layout["module_xs"], ConveyorPlaceholderVisual.BELT_MODULE_XS, "Conveyor module origins follow the package manifest")
	_expect_equal(layout["module_widths"], ConveyorPlaceholderVisual.BELT_MODULE_WIDTHS, "Conveyor module widths follow the package manifest")
	_expect_equal(layout["support_xs"], ConveyorPlaceholderVisual.SUPPORT_XS, "Support positions follow the package manifest")
	_expect_close(float(geometry["asset_top_y"]), 703.0, "Conveyor art begins at the approved contact surface")
	_expect_close(float(geometry["assembled_width"]), 1232.0, "Modular conveyor assembles to exact approved width")

	var expected_x := conveyor.path_start_x
	for index in surface_modules.get_child_count():
		var module := surface_modules.get_child(index) as Sprite2D
		var expected_width := float(ConveyorPlaceholderVisual.BELT_MODULE_WIDTHS[index])
		_expect_close(module.position.x, expected_x, "%s begins without a seam" % module.name)
		_expect_close(module.position.y, 703.0, "%s shares exact contact Y" % module.name)
		_expect_vector(module.scale, Vector2(0.5, 0.5), "%s uses the common 2x-to-logical transform" % module.name)
		_expect_true(not module.centered and not module.z_as_relative and module.z_index == 4, "%s uses top-left absolute conveyor ordering" % module.name)
		_expect_close(module.texture.get_width() * module.scale.x, expected_width, "%s displays at its manifest width" % module.name)
		expected_x += expected_width
	_expect_close(expected_x, conveyor.path_end_x, "Module edges finish at exact conveyor end without gaps")

	var slats := conveyor.slat_overlay.get_geometry_snapshot()
	_expect_vector(slats["texture_size"], Vector2(128, 88), "Animated slats use verified 2x runtime texture")
	_expect_equal(slats["window"], Rect2(476, 716, 1152, 44), "Animated slats are clipped between conveyor caps")
	_expect_vector(slats["tile_display_size"], Vector2(64, 44), "Animated slats use native logical tile size")
	var moving_offset := conveyor.get_slat_offset()
	conveyor.advance_visuals(0.25)
	_expect_true(not is_equal_approx(conveyor.get_slat_offset(), moving_offset), "Existing presentation clock advances slat artwork")
	conveyor.set_visual_state(false, 0.0)
	var frozen_offset := conveyor.get_slat_offset()
	conveyor.advance_visuals(2.0)
	_expect_close(conveyor.get_slat_offset(), frozen_offset, "Stopped conveyor freezes slats without a second clock")
	_expect_true(not conveyor.is_processing(), "Stopped conveyor avoids unnecessary continuous processing")
	conveyor.set_visual_state(true, 0.75)
	_expect_true(conveyor.is_processing(), "Running conveyor resumes the existing presentation process")


func _test_receiving_desk_asset_layers_and_handoff(room: Node2D) -> void:
	var desk := room.get_node("%ReceivingDesk") as ReceivingDeskVisual
	var parcels := room.get_node("%DecorativeParcels") as DecorativeParcelVisual
	var conveyor := room.get_node("%Conveyor") as ConveyorPlaceholderVisual
	var geometry := desk.get_asset_geometry_snapshot()

	_expect_vector(desk.position, Vector2(268.0, 920.0), "Receiving Desk art preserves approved world pivot")
	_expect_vector(geometry["display_size"], Vector2(336.0, 352.0), "Receiving Desk keeps approved logical footprint")
	_expect_vector(geometry["back_export_size"], Vector2(672.0, 704.0), "Rear casing uses verified 2x export")
	_expect_vector(geometry["back_position"], Vector2(-168.0, -352.0), "Rear casing uses manifest top-left")
	_expect_vector(geometry["back_scale"], Vector2(0.5, 0.5), "Rear casing resolves to logical size")
	_expect_vector(geometry["paper_export_size"], Vector2(384.0, 100.0), "Paperwork uses verified cropped export")
	_expect_vector(geometry["paper_position"], Vector2(-136.0, -244.0), "Paperwork uses manifest top-left")
	_expect_vector(geometry["paper_scale"], Vector2(0.5, 0.5), "Paperwork resolves to logical size")
	_expect_vector(geometry["emissive_export_size"], Vector2(576.0, 162.0), "Idle lighting uses verified cropped export")
	_expect_vector(geometry["emissive_position"], Vector2(-120.0, -280.0), "Idle lighting uses manifest top-left")
	_expect_vector(geometry["emissive_scale"], Vector2(0.5, 0.5), "Idle lighting resolves to logical size")
	_expect_vector(geometry["wheel_export_size"], Vector2(96.0, 96.0), "Feed wheel uses verified cropped export")
	_expect_vector(geometry["wheel_pivot"], Vector2(116.0, -173.0), "Feed wheel rotates around documented centre")
	_expect_vector(geometry["wheel_scale"], Vector2(0.5, 0.5), "Feed wheel resolves to logical size")
	_expect_true(bool(geometry["wheel_centered"]), "Feed wheel texture is centred on its rotation pivot")
	_expect_vector(geometry["front_export_size"], Vector2(672.0, 704.0), "Front guard uses verified 2x export")
	_expect_vector(geometry["front_position"], Vector2(-168.0, -352.0), "Front guard shares approved machine bounds")
	_expect_vector(geometry["front_scale"], Vector2(0.5, 0.5), "Front guard resolves to logical size")
	_expect_equal(desk.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "Receiving Desk matches scanner linear filtering")
	_expect_equal(int(geometry["back_z"]), 5, "Rear casing keeps manifest absolute Z")
	_expect_equal(int(geometry["paper_z"]), 5, "Paperwork keeps manifest absolute Z")
	_expect_equal(int(geometry["emissive_z"]), 7, "Idle lighting keeps manifest absolute Z")
	_expect_equal(int(geometry["wheel_z"]), 8, "Feed wheel keeps manifest absolute Z")
	_expect_equal(int(geometry["front_z"]), 10, "Front guard keeps manifest absolute Z")

	for layer: CanvasItem in [desk.rear_casing, desk.static_paperwork, desk.idle_emissive, desk.feed_wheel_pivot, desk.front_mask]:
		_expect_true(not layer.z_as_relative, "%s avoids inherited Machines-node Z" % layer.name)
	_expect_true(int(geometry["back_z"]) < parcels.z_index, "Parcels render in front of Receiving Desk rear casing")
	_expect_true(parcels.z_index < int(geometry["emissive_z"]), "Receiving Desk lighting can illuminate passing parcels")
	_expect_true(parcels.z_index < int(geometry["front_z"]), "Parcels render behind Receiving Desk front guard")
	_expect_true(conveyor.z_index < parcels.z_index, "Receiving Desk hand-off keeps parcels separate from belt artwork")

	_expect_close(desk.position.x + float(geometry["conveyor_handoff_local_x"]), 436.0, "Receiving Desk outlet meets conveyor at X=436")
	_expect_close(desk.position.y + float(geometry["parcel_center_local_y"]), 688.0, "Receiving Desk outlet aligns to parcel centreline")
	_expect_close(desk.position.y + float(geometry["conveyor_contact_local_y"]), 703.0, "Receiving Desk outlet aligns to conveyor contact surface")
	_expect_close(conveyor.path_start_x, 436.0, "Existing decorative parcel path begins at the Receiving Desk hand-off")
	_expect_close(conveyor.item_path_y, 688.0, "Existing decorative parcel path crosses the Receiving Desk outlet")
	_expect_equal(parcels.get_item_positions(), conveyor.get_item_positions(), "Receiving Desk reuses the existing parcel renderer")
	_expect_equal(room.find_children("*", "DecorativeParcelVisual", true, false).size(), 1, "ArchiveRoom contains no duplicate parcel renderer")

	var front_image := desk.front_mask.texture.get_image()
	var back_image := desk.rear_casing.texture.get_image()
	_expect_close(front_image.get_pixel(656, 240).a, 0.0, "Front guard leaves the parcel approach transparent")
	_expect_true(front_image.get_pixel(658, 240).a > 0.0, "Front guard begins occluding the parcel at the outlet edge")
	_expect_true(back_image.get_pixel(656, 240).a > 0.0, "Rear casing remains visible behind the outlet parcel")


func _test_receiving_desk_visual_states(room: Node2D) -> void:
	_reset_simulation()
	await get_tree().process_frame
	var desk := room.get_node("%ReceivingDesk") as ReceivingDeskVisual
	var state := desk.get_state_snapshot()
	_expect_true(bool(state["enabled"]), "Receiving Desk visual starts enabled")
	_expect_true(bool(state["active"]), "Receiving Desk responds to active production")
	_expect_true(bool(state["idle_visible"]), "Enabled Receiving Desk shows independent idle lighting")
	_expect_true(bool(state["wheel_visible"]), "Optional feed wheel remains independently layered")
	_expect_true(bool(state["wheel_processing"]), "Feed wheel animates while the line runs")
	_expect_true(not desk.has_upgrade, "Receiving Desk does not invent an upgrade")

	desk.set_process(false)
	var start_angle := float(desk.get_state_snapshot()["wheel_angle"])
	desk.advance_visual_animation(0.5)
	_expect_true(not is_equal_approx(float(desk.get_state_snapshot()["wheel_angle"]), start_angle), "Feed wheel advances around its documented centre")
	desk.set_idle_lighting_enabled(false)
	_expect_true(not bool(desk.get_state_snapshot()["idle_visible"]), "Idle lighting can be controlled independently")
	desk.set_idle_lighting_enabled(true)
	_expect_true(bool(desk.get_state_snapshot()["idle_visible"]), "Idle lighting restores independently")

	SimulationManager.set_machine_enabled(&"basic_scanner", false)
	await get_tree().process_frame
	state = desk.get_state_snapshot()
	_expect_true(bool(state["enabled"]) and not bool(state["active"]), "Receiving Desk stays enabled when a downstream stage stops the line")
	_expect_true(not bool(state["wheel_processing"]), "Feed wheel stops when the production line is stopped")
	var frozen_angle := float(state["wheel_angle"])
	desk.advance_visual_animation(1.0)
	_expect_close(float(desk.get_state_snapshot()["wheel_angle"]), frozen_angle, "Stopped feed wheel cannot advance through presentation calls")

	SimulationManager.set_machine_enabled(&"basic_scanner", true)
	SimulationManager.set_machine_enabled(&"receiving_desk", false)
	await get_tree().process_frame
	state = desk.get_state_snapshot()
	_expect_true(not bool(state["enabled"]) and not bool(state["active"]), "Receiving Desk art responds to disabled state")
	_expect_true(not bool(state["idle_visible"]), "Disabled Receiving Desk turns off idle lighting")
	_expect_true(desk.rear_casing.self_modulate != Color.WHITE and desk.front_mask.self_modulate != Color.WHITE, "Disabled state dims both casing layers")

	_reset_simulation(75)
	SimulationManager.purchase_upgrade("sorter_motor_1")
	SimulationManager.purchase_upgrade("scanner_motor_1")
	await get_tree().process_frame
	state = desk.get_state_snapshot()
	_expect_true(bool(state["bottleneck"]), "Receiving Desk receives existing bottleneck feedback")
	_expect_true(not desk.has_upgrade, "Bottleneck feedback does not create a Receiving Desk upgrade")

	_reset_simulation()
	await get_tree().process_frame


func _test_sorter_asset_layers_and_occlusion(room: Node2D) -> void:
	var sorter := room.get_node("%BasicSorter") as BasicSorterVisual
	var parcels := room.get_node("%DecorativeParcels") as DecorativeParcelVisual
	var conveyor := room.get_node("%Conveyor") as ConveyorPlaceholderVisual
	var geometry := sorter.get_asset_geometry_snapshot()

	_expect_vector(sorter.position, Vector2(1204.0, 920.0), "Basic Sorter art preserves approved world pivot")
	_expect_vector(geometry["display_size"], Vector2(480.0, 360.0), "Basic Sorter keeps approved logical footprint")
	_expect_vector(geometry["back_export_size"], Vector2(960.0, 720.0), "Sorter rear housing uses verified 2x export")
	_expect_vector(geometry["back_position"], Vector2(-240.0, -360.0), "Sorter rear housing uses bottom-centre alignment")
	_expect_vector(geometry["back_scale"], Vector2(0.5, 0.5), "Sorter rear housing resolves to logical size")
	_expect_vector(geometry["header_export_size"], Vector2(728.0, 104.0), "Sorter header indicators use verified cropped export")
	_expect_vector(geometry["header_position"], Vector2(-178.0, -288.0), "Sorter header indicators use manifest offset")
	_expect_vector(geometry["header_scale"], Vector2(0.5, 0.5), "Sorter header indicators resolve to logical size")
	_expect_vector(geometry["bays_export_size"], Vector2(538.0, 22.0), "Sorter bay indicators use verified cropped export")
	_expect_vector(geometry["bays_position"], Vector2(-134.0, -183.0), "Sorter bay indicators use manifest offset")
	_expect_vector(geometry["bays_scale"], Vector2(0.5, 0.5), "Sorter bay indicators resolve to logical size")
	_expect_vector(geometry["gate_export_size"], Vector2(192.0, 192.0), "Sorting gate uses verified cropped export")
	_expect_vector(geometry["gate_pivot"], Vector2(18.0, -266.0), "Sorting gate uses documented root-local pivot")
	_expect_vector(geometry["gate_child_position"], Vector2(-42.0, -22.0), "Sorting gate texture offsets around its pivot")
	_expect_vector(geometry["gate_scale"], Vector2(0.5, 0.5), "Sorting gate resolves to logical size")
	_expect_true(not bool(geometry["gate_centered"]), "Sorting gate uses explicit top-left crop positioning")
	_expect_vector(geometry["front_export_size"], Vector2(960.0, 720.0), "Sorter front frame uses verified 2x export")
	_expect_vector(geometry["front_position"], Vector2(-240.0, -360.0), "Sorter front frame shares bottom-centre alignment")
	_expect_vector(geometry["front_scale"], Vector2(0.5, 0.5), "Sorter front frame resolves to logical size")
	_expect_vector(geometry["upgrade_export_size"], Vector2(188.0, 260.0), "Sorter Motor I uses verified cropped export")
	_expect_vector(geometry["upgrade_position"], Vector2(125.0, -150.0), "Sorter Motor I uses manifest offset")
	_expect_vector(geometry["upgrade_scale"], Vector2(0.5, 0.5), "Sorter Motor I resolves to logical size")
	_expect_equal(sorter.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "Basic Sorter matches completed machines' linear filtering")

	_expect_equal(int(geometry["back_z"]), 5, "Sorter rear housing keeps manifest absolute Z")
	_expect_equal(int(geometry["header_z"]), 7, "Sorter header indicators keep manifest absolute Z")
	_expect_equal(int(geometry["bays_z"]), 7, "Sorter bay indicators keep manifest absolute Z")
	_expect_equal(int(geometry["gate_z"]), 8, "Sorting gate keeps manifest absolute Z")
	_expect_equal(int(geometry["front_z"]), 10, "Sorter front frame keeps manifest absolute Z")
	_expect_equal(int(geometry["upgrade_z"]), 11, "Sorter Motor I keeps manifest absolute Z")
	for layer: CanvasItem in [sorter.rear_housing, sorter.header_emissive, sorter.bay_emissive, sorter.sorting_gate_pivot, sorter.front_mask, sorter.motor_upgrade]:
		_expect_true(not layer.z_as_relative, "%s avoids inherited Machines-node Z" % layer.name)
	_expect_true(conveyor.z_index < int(geometry["back_z"]), "Conveyor surface remains behind Sorter housing")
	_expect_true(int(geometry["back_z"]) < parcels.z_index, "Parcels render in front of Sorter rear housing")
	_expect_true(parcels.z_index < int(geometry["front_z"]), "Parcels render behind Sorter front frame")
	_expect_true(int(geometry["front_z"]) < int(geometry["upgrade_z"]), "Sorter Motor I remains above the front frame")
	_expect_close(sorter.position.y + float(geometry["parcel_center_local_y"]), 688.0, "Sorter passage aligns to parcel centreline")
	_expect_close(sorter.position.y + float(geometry["conveyor_contact_local_y"]), 703.0, "Sorter passage aligns to conveyor contact surface")
	_expect_equal(parcels.get_item_positions(), conveyor.get_item_positions(), "Sorter reuses the single decorative parcel renderer")
	_expect_equal(room.find_children("*", "DecorativeParcelVisual", true, false).size(), 1, "Sorter integration adds no parcel renderer")

	var layers: Array[Sprite2D] = [
		sorter.rear_housing,
		sorter.header_emissive,
		sorter.bay_emissive,
		sorter.sorting_gate,
		sorter.front_mask,
		sorter.motor_upgrade,
	]
	for layer: Sprite2D in layers:
		var image := layer.texture.get_image()
		_expect_true(image.get_used_rect() != Rect2i(Vector2i.ZERO, image.get_size()), "%s retains genuine transparent pixels" % layer.name)

	var front_image := sorter.front_mask.texture.get_image()
	var back_image := sorter.rear_housing.texture.get_image()
	_expect_true(front_image.get_pixel(40, 256).a > 0.0, "Sorter entrance guard occludes passing parcel edges")
	_expect_close(front_image.get_pixel(480, 256).a, 0.0, "Sorter interior remains open at parcel centre")
	_expect_true(front_image.get_pixel(920, 256).a > 0.0, "Sorter exit guard occludes passing parcel edges")
	_expect_true(back_image.get_pixel(480, 256).a > 0.0, "Sorter rear channel stays visible behind passing parcels")
	_expect_close(front_image.get_pixel(480, 286).a, 0.0, "Sorter front frame stays clear through approved parcel contact height")
	_expect_true(front_image.get_pixel(480, 290).a > 0.0, "Sorter lower rail begins below the parcel contact surface")


func _test_sorter_gate_parcel_clearance(room: Node2D) -> void:
	var sorter := room.get_node("%BasicSorter") as BasicSorterVisual
	var parcels := room.get_node("%DecorativeParcels") as DecorativeParcelVisual
	var conveyor := room.get_node("%Conveyor") as ConveyorPlaceholderVisual
	var parcel_center_start := parcels.to_global(Vector2(conveyor.path_start_x, conveyor.item_path_y))
	var parcel_center_end := parcels.to_global(Vector2(conveyor.path_end_x, conveyor.item_path_y))
	var parcel_sweep := Rect2(
		Vector2(minf(parcel_center_start.x, parcel_center_end.x), parcel_center_start.y) - ConveyorPlaceholderVisual.PARCEL_SIZE * 0.5,
		Vector2(absf(parcel_center_end.x - parcel_center_start.x) + ConveyorPlaceholderVisual.PARCEL_SIZE.x, ConveyorPlaceholderVisual.PARCEL_SIZE.y)
	).grow(PARCEL_FILTER_EDGE_ALLOWANCE)
	var swept_parcel_rects: Array[Rect2] = [parcel_sweep]

	sorter.set_process(false)
	var fixed_angles := [
		{"label": "-16 degrees", "phase": 0.75},
		{"label": "0 degrees", "phase": 0.0},
		{"label": "+16 degrees", "phase": 0.25},
	]
	for angle_case: Dictionary in fixed_angles:
		sorter.set_gate_phase_for_preview(float(angle_case["phase"]))
		var result := _measure_visible_gate_parcel_overlap(sorter, swept_parcel_rects)
		print(
			"Sorter gate clearance %s: overlap_samples=%d, lowest_visible_y=%.2f, parcel_top=%.2f"
			% [
				angle_case["label"],
				int(result["overlap_samples"]),
				float(result["lowest_visible_gate_y"]),
				parcel_sweep.position.y,
			]
		)
		_expect_equal(
			int(result["overlap_samples"]),
			0,
			"Visible gate alpha stays out of the linear-filtered moving-parcel sweep at %s" % angle_case["label"]
		)

	var coupled_times := [0.0, 0.37, 0.83, 1.41, 2.05, 2.77, 3.62, 4.48, 5.31, 6.74, 8.19, 10.03, 12.0]
	var previous_time := 0.0
	var coupled_overlap_samples := 0
	for coupled_time: float in coupled_times:
		conveyor.advance_visuals(coupled_time - previous_time)
		previous_time = coupled_time
		sorter.set_gate_phase_for_preview(fposmod(coupled_time * BasicSorterVisual.GATE_ANGULAR_SPEED / TAU, 1.0))
		var moving_parcel_rects: Array[Rect2] = []
		for parcel_position: Vector2 in parcels.get_item_positions():
			moving_parcel_rects.append(_parcel_world_rect(parcels, parcel_position).grow(PARCEL_FILTER_EDGE_ALLOWANCE))
		var coupled_result := _measure_visible_gate_parcel_overlap(sorter, moving_parcel_rects)
		coupled_overlap_samples += int(coupled_result["overlap_samples"])
	print(
		"Sorter gate coupled clearance: phases=%d, duration=%.2f, overlap_samples=%d"
		% [coupled_times.size(), float(coupled_times[-1]), coupled_overlap_samples]
	)
	_expect_equal(
		coupled_overlap_samples,
		0,
		"Visible gate alpha never intersects actual parcel rectangles across coupled gate/conveyor phases"
	)


func _measure_visible_gate_parcel_overlap(sorter: BasicSorterVisual, parcel_rects: Array[Rect2]) -> Dictionary:
	var gate_image := sorter.sorting_gate.texture.get_image()
	var front_image := sorter.front_mask.texture.get_image()
	var gate_bounds := _sprite_world_bounds(sorter.sorting_gate)
	var sample_min := Vector2(
		floorf(gate_bounds.position.x / LINEAR_ALPHA_SAMPLE_STEP) * LINEAR_ALPHA_SAMPLE_STEP,
		floorf(gate_bounds.position.y / LINEAR_ALPHA_SAMPLE_STEP) * LINEAR_ALPHA_SAMPLE_STEP
	)
	var sample_max := Vector2(
		ceilf(gate_bounds.end.x / LINEAR_ALPHA_SAMPLE_STEP) * LINEAR_ALPHA_SAMPLE_STEP,
		ceilf(gate_bounds.end.y / LINEAR_ALPHA_SAMPLE_STEP) * LINEAR_ALPHA_SAMPLE_STEP
	)
	var x_samples := int(roundf((sample_max.x - sample_min.x) / LINEAR_ALPHA_SAMPLE_STEP)) + 1
	var y_samples := int(roundf((sample_max.y - sample_min.y) / LINEAR_ALPHA_SAMPLE_STEP)) + 1
	var overlap_samples := 0
	var lowest_visible_gate_y := -INF

	for y_index in range(y_samples):
		var world_y := sample_min.y + float(y_index) * LINEAR_ALPHA_SAMPLE_STEP
		for x_index in range(x_samples):
			var world_point := Vector2(sample_min.x + float(x_index) * LINEAR_ALPHA_SAMPLE_STEP, world_y)
			var gate_alpha := _sample_sprite_linear_alpha(sorter.sorting_gate, gate_image, world_point)
			if gate_alpha <= LINEAR_ALPHA_EPSILON:
				continue
			var front_alpha := _sample_sprite_linear_alpha(sorter.front_mask, front_image, world_point)
			if front_alpha >= TRANSPARENT_MASK_ALPHA_LIMIT:
				continue
			lowest_visible_gate_y = maxf(lowest_visible_gate_y, world_y)
			if _point_is_inside_any_rect(world_point, parcel_rects):
				overlap_samples += 1

	return {
		"overlap_samples": overlap_samples,
		"lowest_visible_gate_y": lowest_visible_gate_y,
	}


func _sample_sprite_linear_alpha(sprite: Sprite2D, image: Image, world_point: Vector2) -> float:
	var texture_point := sprite.to_local(world_point) - sprite.offset
	if sprite.centered:
		texture_point += Vector2(image.get_size()) * 0.5
	var sample_point := texture_point - Vector2(0.5, 0.5)
	var x0 := floori(sample_point.x)
	var y0 := floori(sample_point.y)
	var x_mix := sample_point.x - float(x0)
	var y_mix := sample_point.y - float(y0)
	var top := lerpf(_image_alpha_or_zero(image, x0, y0), _image_alpha_or_zero(image, x0 + 1, y0), x_mix)
	var bottom := lerpf(_image_alpha_or_zero(image, x0, y0 + 1), _image_alpha_or_zero(image, x0 + 1, y0 + 1), x_mix)
	return lerpf(top, bottom, y_mix)


func _image_alpha_or_zero(image: Image, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return 0.0
	return image.get_pixel(x, y).a


func _sprite_world_bounds(sprite: Sprite2D) -> Rect2:
	var texture_size := sprite.texture.get_size()
	var top_left := sprite.offset
	if sprite.centered:
		top_left -= texture_size * 0.5
	var local_corners := [
		top_left,
		top_left + Vector2(texture_size.x, 0.0),
		top_left + texture_size,
		top_left + Vector2(0.0, texture_size.y),
	]
	var world_min := sprite.to_global(local_corners[0])
	var world_max := world_min
	for local_corner: Vector2 in local_corners:
		var world_corner := sprite.to_global(local_corner)
		world_min = Vector2(minf(world_min.x, world_corner.x), minf(world_min.y, world_corner.y))
		world_max = Vector2(maxf(world_max.x, world_corner.x), maxf(world_max.y, world_corner.y))
	return Rect2(world_min, world_max - world_min)


func _parcel_world_rect(parcels: DecorativeParcelVisual, local_center: Vector2) -> Rect2:
	var half_size := ConveyorPlaceholderVisual.PARCEL_SIZE * 0.5
	var local_corners := [
		local_center - half_size,
		local_center + Vector2(half_size.x, -half_size.y),
		local_center + half_size,
		local_center + Vector2(-half_size.x, half_size.y),
	]
	var world_min := parcels.to_global(local_corners[0])
	var world_max := world_min
	for local_corner: Vector2 in local_corners:
		var world_corner := parcels.to_global(local_corner)
		world_min = Vector2(minf(world_min.x, world_corner.x), minf(world_min.y, world_corner.y))
		world_max = Vector2(maxf(world_max.x, world_corner.x), maxf(world_max.y, world_corner.y))
	return Rect2(world_min, world_max - world_min)


func _point_is_inside_any_rect(point: Vector2, rects: Array[Rect2]) -> bool:
	for rect: Rect2 in rects:
		if rect.has_point(point):
			return true
	return false


func _test_sorter_visual_states_and_restoration(room: Node2D) -> void:
	_reset_simulation()
	await get_tree().process_frame
	var sorter := room.get_node("%BasicSorter") as BasicSorterVisual
	var state := sorter.get_state_snapshot()
	_expect_true(bool(state["enabled"]), "Basic Sorter visual starts enabled")
	_expect_true(bool(state["active"]), "Basic Sorter gate responds to active production")
	_expect_true(bool(state["bottleneck"]), "Basic Sorter keeps initial bottleneck feedback")
	_expect_true(bool(state["header_visible"]) and bool(state["bays_visible"]), "Enabled Sorter shows both indicator layers")
	_expect_true(bool(state["gate_processing"]), "Sorting gate processes only while the line runs")
	_expect_true(not bool(state["upgrade_visible"]), "Sorter Motor I starts hidden while unowned")

	sorter.set_process(false)
	sorter.set_gate_phase_for_preview(0.25)
	_expect_close(float(sorter.get_state_snapshot()["gate_angle"]), BasicSorterVisual.GATE_MAX_ANGLE, "Sorting gate reaches documented positive swing")
	sorter.set_gate_phase_for_preview(0.75)
	_expect_close(float(sorter.get_state_snapshot()["gate_angle"]), -BasicSorterVisual.GATE_MAX_ANGLE, "Sorting gate reaches documented negative swing")
	sorter.set_gate_phase_for_preview(0.0)
	var neutral_angle := float(sorter.get_state_snapshot()["gate_angle"])
	sorter.advance_visual_animation(0.25)
	_expect_true(not is_equal_approx(float(sorter.get_state_snapshot()["gate_angle"]), neutral_angle), "Sorting gate advances from presentation time")
	sorter.set_header_lighting_enabled(false)
	_expect_true(not bool(sorter.get_state_snapshot()["header_visible"]) and bool(sorter.get_state_snapshot()["bays_visible"]), "Sorter header indicators toggle independently")
	sorter.set_header_lighting_enabled(true)
	sorter.set_bay_lighting_enabled(false)
	_expect_true(bool(sorter.get_state_snapshot()["header_visible"]) and not bool(sorter.get_state_snapshot()["bays_visible"]), "Sorter bay indicators toggle independently")
	sorter.set_bay_lighting_enabled(true)

	SimulationManager.set_machine_enabled(&"basic_scanner", false)
	await get_tree().process_frame
	state = sorter.get_state_snapshot()
	_expect_true(bool(state["enabled"]) and not bool(state["active"]), "Sorter remains enabled when a downstream stage stops the line")
	_expect_true(not bool(state["gate_processing"]), "Sorting gate stops when the production line stops")
	var frozen_angle := float(state["gate_angle"])
	sorter.advance_visual_animation(1.0)
	_expect_close(float(sorter.get_state_snapshot()["gate_angle"]), frozen_angle, "Stopped sorting gate cannot advance through presentation calls")
	SimulationManager.set_machine_enabled(&"basic_scanner", true)
	await get_tree().process_frame
	_expect_true(bool(sorter.get_state_snapshot()["gate_processing"]), "Sorting gate resumes when production restarts")

	GameState.restore_state(25, 25, 0, 0.0)
	var purchase_result := SimulationManager.purchase_upgrade("sorter_motor_1")
	await get_tree().process_frame
	state = sorter.get_state_snapshot()
	_expect_equal(purchase_result, SimulationManager.PurchaseResult.SUCCESS, "Existing Sorter Motor I purchase succeeds")
	_expect_true(bool(state["upgraded"]) and bool(state["upgrade_visible"]), "Owned Sorter Motor I appears on the machine")

	SimulationManager.set_machine_enabled(&"basic_sorter", false)
	await get_tree().process_frame
	state = sorter.get_state_snapshot()
	_expect_true(not bool(state["enabled"]) and not bool(state["active"]), "Sorter art responds to disabled state")
	_expect_true(not bool(state["header_visible"]) and not bool(state["bays_visible"]), "Disabled Sorter turns off both indicator layers")
	_expect_true(not bool(state["gate_processing"]), "Disabled Sorter gate is frozen")
	_expect_true(bool(state["upgrade_visible"]), "Sorter Motor I remains installed while disabled")
	_expect_true(sorter.rear_housing.self_modulate != Color.WHITE and sorter.front_mask.self_modulate != Color.WHITE, "Disabled state dims both Sorter casing layers")
	_expect_true(sorter.sorting_gate.self_modulate != Color.WHITE and sorter.motor_upgrade.self_modulate != Color.WHITE, "Disabled state dims gate and installed Motor I")

	var saved_production := SimulationManager.get_production_save_data().duplicate(true)
	_reset_simulation()
	_expect_true(SimulationManager.restore_production_save_data(saved_production), "Sorter upgrade and disabled state restore from save data")
	var restored_room := ARCHIVE_ROOM_SCENE.instantiate() as Node2D
	add_child(restored_room)
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_sorter := restored_room.get_node("%BasicSorter") as BasicSorterVisual
	var restored_state := restored_sorter.get_state_snapshot()
	_expect_true(not bool(restored_state["enabled"]), "New ArchiveRoom reflects restored disabled Sorter state")
	_expect_true(bool(restored_state["upgraded"]) and bool(restored_state["upgrade_visible"]), "New ArchiveRoom reflects restored Motor I ownership")
	_expect_true(restored_sorter.motor_upgrade.self_modulate != Color.WHITE, "Restored disabled Motor I remains visibly dimmed")
	restored_room.queue_free()
	await get_tree().process_frame

	_reset_simulation()
	await get_tree().process_frame


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
	var sorter: BasicSorterVisual = room_with_visuals.get_node("%BasicSorter") as BasicSorterVisual
	var before_visual_advance := _simulation_snapshot()
	var item_positions_before := conveyor.get_item_positions()
	var gate_angle_before := float(sorter.get_state_snapshot()["gate_angle"])
	conveyor.advance_visuals(12.0)
	sorter.advance_visual_animation(0.25)
	var item_positions_after := conveyor.get_item_positions()
	_expect_true(item_positions_before != item_positions_after, "Decorative conveyor items animate")
	_expect_true(not is_equal_approx(float(sorter.get_state_snapshot()["gate_angle"]), gate_angle_before), "Decorative sorting gate animates")
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
