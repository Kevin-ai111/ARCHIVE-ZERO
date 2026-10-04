extends Node

# Opt-in graphical evidence tool. It never runs in the game or headless suite.
# Example: Godot --path . tests/archive_room_polish_capture.tscn -- --size=1280x720 --out=C:/temp/proof
const ROOM: PackedScene = preload("res://scenes/world/archive_room.tscn")
var options := {}


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a real graphical renderer.")
		get_tree().quit(1)
		return
	var dimensions := String(options.get("size", "1920x1080")).split("x")
	var output := String(options.get("out", "user://phase4i-proof"))
	DirAccess.make_dir_recursive_absolute(output)
	get_window().size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	GameState.restore_state(0, 0, 0, 0.0)
	SimulationManager.restore_production_save_data(SimulationManager.get_default_production_save_data())
	var room := ROOM.instantiate() as Node2D
	add_child(room)
	for node_name in ["Conveyor", "ReceivingDesk", "BasicScanner", "BasicSorter", "ArchiveIntake"]:
		room.get_node("%" + node_name).set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var environment := room.get_node("%EnvironmentArt") as Node2D
	if options.has("baseline"):
		room.remove_child(environment)
		environment.free()
		environment = (load(options["baseline"]) as PackedScene).instantiate() as Node2D
		room.add_child(environment)
	if options.get("filter", "linear") == "nearest":
		environment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var variant := String(options.get("variant", "room"))
	if variant == "environment":
		for path in ["Machines", "Conveyors", "GameplayHUD"]:
			if path == "GameplayHUD":
				(room.get_node(path) as CanvasLayer).hide()
			else:
				(room.get_node(path) as CanvasItem).hide()
	if variant == "shop":
		room.get_node("GameplayHUD").open_upgrade_shop()
	var conveyor := room.get_node("%Conveyor") as ConveyorPlaceholderVisual
	var desk := room.get_node("%ReceivingDesk") as ReceivingDeskVisual
	var scanner := room.get_node("%BasicScanner") as BasicScannerVisual
	var sorter := room.get_node("%BasicSorter") as BasicSorterVisual
	var intake := room.get_node("%ArchiveIntake") as ArchiveIntakeVisual
	var frames := int(options.get("frames", "1"))
	var phase := float(options.get("phase", "0.0"))
	conveyor.advance_visuals(phase)
	for index in range(20):
		await get_tree().process_frame
	var measurements: Array[Dictionary] = []
	for index in range(frames):
		if index > 0:
			conveyor.advance_visuals(0.15)
			desk.advance_visual_animation(0.15)
			scanner.set_scan_phase_for_preview(fposmod(float(index) * 0.15, 1.0))
			sorter.advance_visual_animation(0.15)
			intake.advance_visual_animation(0.15)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(output.path_join("frame_%03d.png" % index))
		if error != OK:
			push_error("Could not save capture: %s" % error)
			get_tree().quit(1)
			return
		measurements.append({
			"frame": index,
			"parcel_centres": str(conveyor.get_item_positions()),
			"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
			"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		})
	var metadata := {
		"godot": Engine.get_version_info(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"size": str(get_window().size),
		"filter": options.get("filter", "linear"),
		"variant": variant,
		"phase_start": phase,
		"motion_step_seconds": 0.15,
		"environment": environment.get_layout_snapshot() if environment.has_method("get_layout_snapshot") else {"baseline": true},
		"frames": measurements,
	}
	var file := FileAccess.open(output.path_join("metadata.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("Graphical evidence captured: %s, %d frames; %s" % [output, frames, measurements[0]])
	get_tree().quit(0)
