class_name MachineRuntime
extends RefCounted

const DEFAULT_CAPACITY_MULTIPLIER: float = 1.0

var _definition: MachineDefinition
var _enabled: bool = true
var _runtime_capacity_multiplier: float = DEFAULT_CAPACITY_MULTIPLIER
var _upgrade_capacity_multiplier: float = DEFAULT_CAPACITY_MULTIPLIER


func _init(definition: MachineDefinition) -> void:
	_definition = definition


func get_definition() -> MachineDefinition:
	return _definition


func get_id() -> StringName:
	return _definition.id


func is_enabled() -> bool:
	return _enabled


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func get_capacity_multiplier() -> float:
	return _runtime_capacity_multiplier * _upgrade_capacity_multiplier


func set_capacity_multiplier(multiplier: float) -> bool:
	return set_runtime_capacity_multiplier(multiplier)


func get_runtime_capacity_multiplier() -> float:
	return _runtime_capacity_multiplier


func set_runtime_capacity_multiplier(multiplier: float) -> bool:
	if not is_finite(multiplier) or multiplier < 0.0:
		return false

	_runtime_capacity_multiplier = multiplier
	return true


func get_upgrade_capacity_multiplier() -> float:
	return _upgrade_capacity_multiplier


func set_upgrade_capacity_multiplier(multiplier: float) -> bool:
	if not is_finite(multiplier) or multiplier <= 0.0:
		return false

	_upgrade_capacity_multiplier = multiplier
	return true


func get_configured_capacity() -> float:
	return maxf(_definition.base_processing_rate * get_capacity_multiplier(), 0.0)


func get_effective_capacity() -> float:
	if not _enabled:
		return 0.0
	return get_configured_capacity()


func get_save_data() -> Dictionary:
	return {
		"enabled": _enabled,
		"runtime_capacity_multiplier": _runtime_capacity_multiplier,
	}
