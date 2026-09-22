class_name BasicScanner
extends RefCounted

const ITEMS_PER_SECOND: float = 1.0
const CREDITS_PER_ITEM: int = 2

var _enabled: bool = true
var _fractional_items: float = 0.0


func process_elapsed(elapsed_seconds: float) -> int:
	if not _enabled or elapsed_seconds <= 0.0:
		return 0

	_fractional_items += ITEMS_PER_SECOND * elapsed_seconds
	var completed_items: int = int(floor(_fractional_items))
	_fractional_items -= completed_items
	return completed_items


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func is_enabled() -> bool:
	return _enabled


func reset_progress() -> void:
	_fractional_items = 0.0
