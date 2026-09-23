class_name Machine
extends RefCounted

var _base_throughput_per_minute: float
var _enabled: bool = true
var _throughput_multiplier: float = 1.0


func _init(base_throughput_per_minute: float) -> void:
	_base_throughput_per_minute = maxf(base_throughput_per_minute, 0.0)


func get_base_throughput_per_minute() -> float:
	return _base_throughput_per_minute


func get_effective_throughput_per_minute() -> float:
	if not _enabled:
		return 0.0
	return _base_throughput_per_minute * _throughput_multiplier


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func is_enabled() -> bool:
	return _enabled


func set_throughput_multiplier(multiplier: float) -> bool:
	if multiplier <= 0.0:
		return false
	_throughput_multiplier = multiplier
	return true


func get_throughput_multiplier() -> float:
	return _throughput_multiplier
