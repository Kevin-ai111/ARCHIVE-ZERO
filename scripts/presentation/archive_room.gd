extends Node2D

const SCANNER_MACHINE_ID := &"basic_scanner"

@onready var receiving_desk: MachinePlaceholderVisual = %ReceivingDesk
@onready var scanner: BasicScannerVisual = %BasicScanner
@onready var sorter: MachinePlaceholderVisual = %BasicSorter
@onready var archive_intake: MachinePlaceholderVisual = %ArchiveIntake
@onready var conveyor: ConveyorPlaceholderVisual = %Conveyor
@onready var environment_art: ArchiveRoomEnvironmentVisual = %EnvironmentArt


func _ready() -> void:
	SimulationManager.production_line_changed.connect(_refresh_visual_state)
	SimulationManager.upgrades_changed.connect(_refresh_visual_state)
	SimulationManager.simulation_updated.connect(_on_simulation_updated)
	GameState.state_restored.connect(_refresh_visual_state)
	_refresh_visual_state()


func _exit_tree() -> void:
	if SimulationManager.production_line_changed.is_connected(_refresh_visual_state):
		SimulationManager.production_line_changed.disconnect(_refresh_visual_state)
	if SimulationManager.upgrades_changed.is_connected(_refresh_visual_state):
		SimulationManager.upgrades_changed.disconnect(_refresh_visual_state)
	if SimulationManager.simulation_updated.is_connected(_on_simulation_updated):
		SimulationManager.simulation_updated.disconnect(_on_simulation_updated)
	if GameState.state_restored.is_connected(_refresh_visual_state):
		GameState.state_restored.disconnect(_refresh_visual_state)


func _on_simulation_updated(_items_processed: int, _credits_earned: int, _elapsed_seconds: float) -> void:
	_refresh_visual_state()


func _refresh_visual_state() -> void:
	if not is_node_ready():
		return

	var line := SimulationManager.get_production_line()
	var bottleneck: MachineRuntime = line.get_bottleneck()
	var bottleneck_id: StringName = &"" if bottleneck == null else bottleneck.get_id()
	var throughput := SimulationManager.get_effective_throughput()

	var receiving_stage := line.get_stage(&"receiving_desk")
	var scanner_stage := line.get_stage(SCANNER_MACHINE_ID)
	var sorter_stage := line.get_stage(&"basic_sorter")
	var intake_stage := line.get_stage(&"archive_intake")

	receiving_desk.apply_visual_state(receiving_stage.is_enabled(), bottleneck_id == receiving_desk.machine_id, false)
	scanner.apply_visual_state(
		scanner_stage.is_enabled(),
		throughput > 0.0,
		SimulationManager.owns_upgrade("scanner_motor_1"),
		bottleneck_id == SCANNER_MACHINE_ID
	)
	sorter.apply_visual_state(
		sorter_stage.is_enabled(),
		bottleneck_id == sorter.machine_id,
		SimulationManager.owns_upgrade("sorter_motor_1")
	)
	archive_intake.apply_visual_state(intake_stage.is_enabled(), bottleneck_id == archive_intake.machine_id, false)
	conveyor.set_visual_state(throughput > 0.0, throughput)


func get_layout_snapshot() -> Dictionary:
	return {
		"camera_center": %RoomCamera.position,
		"receiving_desk": {"pivot": receiving_desk.position, "size": receiving_desk.visual_size},
		"basic_scanner": {"pivot": scanner.position, "size": scanner.visual_size},
		"basic_sorter": {"pivot": sorter.position, "size": sorter.visual_size},
		"archive_intake": {"pivot": archive_intake.position, "size": archive_intake.visual_size},
		"conveyor": conveyor.get_layout_snapshot(),
		"environment": environment_art.get_layout_snapshot(),
	}
