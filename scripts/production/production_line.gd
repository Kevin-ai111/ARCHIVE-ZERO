class_name ProductionLine
extends RefCounted

var _stages: Array[MachineRuntime] = []
var _stages_by_id: Dictionary = {}
var _fractional_progress: float = 0.0


func _init(definitions: Array[MachineDefinition] = []) -> void:
	for definition: MachineDefinition in definitions:
		_add_stage(definition)


func get_stages() -> Array[MachineRuntime]:
	var stages_copy: Array[MachineRuntime] = []
	stages_copy.assign(_stages)
	return stages_copy


func get_stage(machine_id: StringName) -> MachineRuntime:
	return _stages_by_id.get(machine_id) as MachineRuntime


func get_stage_capacity(machine_id: StringName) -> float:
	var stage: MachineRuntime = get_stage(machine_id)
	if stage == null:
		return 0.0
	return stage.get_effective_capacity()


func set_stage_enabled(machine_id: StringName, enabled: bool) -> bool:
	var stage: MachineRuntime = get_stage(machine_id)
	if stage == null:
		return false

	stage.set_enabled(enabled)
	return true


func set_stage_capacity_multiplier(machine_id: StringName, multiplier: float) -> bool:
	var stage: MachineRuntime = get_stage(machine_id)
	if stage == null:
		return false

	return stage.set_capacity_multiplier(multiplier)


func get_effective_throughput() -> float:
	if _stages.is_empty():
		return 0.0

	var throughput: float = INF
	for stage: MachineRuntime in _stages:
		var capacity: float = stage.get_effective_capacity()
		if capacity <= 0.0:
			return 0.0
		throughput = minf(throughput, capacity)

	return throughput


func get_bottleneck() -> MachineRuntime:
	var throughput: float = get_effective_throughput()
	if throughput <= 0.0:
		return null

	for stage: MachineRuntime in _stages:
		if is_equal_approx(stage.get_effective_capacity(), throughput):
			return stage

	return null


func get_stage_utilization(machine_id: StringName) -> float:
	var stage: MachineRuntime = get_stage(machine_id)
	var throughput: float = get_effective_throughput()
	if stage == null or not stage.is_enabled() or throughput <= 0.0:
		return 0.0

	var capacity: float = stage.get_effective_capacity()
	if capacity <= 0.0:
		return 0.0

	return clampf(throughput / capacity, 0.0, 1.0)


func simulate_elapsed(elapsed_seconds: float) -> int:
	if not is_finite(elapsed_seconds) or elapsed_seconds <= 0.0:
		return 0

	var throughput: float = get_effective_throughput()
	if throughput <= 0.0:
		return 0

	_fractional_progress += throughput * elapsed_seconds
	var completed_items: int = int(floor(_fractional_progress))
	_fractional_progress -= completed_items
	return completed_items


func get_fractional_progress() -> float:
	return _fractional_progress


func get_save_data() -> Dictionary:
	var machine_states: Dictionary = {}
	for stage: MachineRuntime in _stages:
		machine_states[String(stage.get_id())] = stage.get_save_data()

	return {
		"fractional_progress": _fractional_progress,
		"machines": machine_states,
	}


func is_valid_save_data(save_data: Dictionary) -> bool:
	if not save_data.has("fractional_progress") or not save_data.has("machines"):
		return false
	if not _is_valid_fractional_progress(save_data["fractional_progress"]):
		return false
	if typeof(save_data["machines"]) != TYPE_DICTIONARY:
		return false

	var machine_states: Dictionary = save_data["machines"] as Dictionary
	for stage: MachineRuntime in _stages:
		var machine_key: String = String(stage.get_id())
		if not machine_states.has(machine_key):
			return false
		if not _is_valid_machine_state(machine_states[machine_key]):
			return false

	return true


func restore_save_data(save_data: Dictionary) -> bool:
	if not is_valid_save_data(save_data):
		return false

	var machine_states: Dictionary = save_data["machines"] as Dictionary
	for stage: MachineRuntime in _stages:
		var machine_state: Dictionary = machine_states[String(stage.get_id())] as Dictionary
		stage.set_enabled(bool(machine_state["enabled"]))
		stage.set_runtime_capacity_multiplier(float(machine_state["runtime_capacity_multiplier"]))

	_fractional_progress = float(save_data["fractional_progress"])
	return true


func _add_stage(definition: MachineDefinition) -> void:
	if definition == null or not definition.is_valid():
		push_error("Cannot add an invalid machine definition to a production line.")
		return
	if _stages_by_id.has(definition.id):
		push_error("Duplicate machine ID in production line: %s" % definition.id)
		return

	var runtime: MachineRuntime = MachineRuntime.new(definition)
	_stages.append(runtime)
	_stages_by_id[definition.id] = runtime


func _is_valid_fractional_progress(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var progress: float = float(value)
	return is_finite(progress) and progress >= 0.0 and progress < 1.0


func _is_valid_machine_state(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false

	var state: Dictionary = value as Dictionary
	if not state.has("enabled") or typeof(state["enabled"]) != TYPE_BOOL:
		return false
	if not state.has("runtime_capacity_multiplier"):
		return false
	if (
		typeof(state["runtime_capacity_multiplier"]) != TYPE_INT
		and typeof(state["runtime_capacity_multiplier"]) != TYPE_FLOAT
	):
		return false

	var multiplier: float = float(state["runtime_capacity_multiplier"])
	return is_finite(multiplier) and multiplier >= 0.0
