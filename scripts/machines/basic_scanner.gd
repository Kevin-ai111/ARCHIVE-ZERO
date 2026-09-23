class_name BasicScanner
extends Machine

const BASE_THROUGHPUT_PER_MINUTE: float = 60.0
const CREDITS_PER_ITEM: int = 2


func _init() -> void:
	super(BASE_THROUGHPUT_PER_MINUTE)


func process_available(available_items: float, elapsed_seconds: float) -> float:
	if available_items <= 0.0 or elapsed_seconds <= 0.0 or not is_enabled():
		return 0.0
	var capacity: float = get_effective_throughput_per_minute() * elapsed_seconds / 60.0
	return minf(available_items, capacity)
