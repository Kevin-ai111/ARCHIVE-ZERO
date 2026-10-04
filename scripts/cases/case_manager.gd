extends Node

# Concrete-case authority only: no production clock, rewards or live-save hook.

signal queue_changed
signal active_case_changed
signal case_progress_changed(case_id: StringName)

const CASE_SAVE_VERSION := 1
const SAVE_KEYS: Array[String] = ["case_save_version", "queue", "active_case_id", "progress"]
const PROGRESS_KEYS: Array[String] = ["case_id", "state", "selected_category_id"]

var _catalog: CaseCatalog = CaseCatalog.new()
var _queue: Array[StringName] = []
var _active_case_id: StringName = &""
var _progress: Dictionary = {}
var _publishing := false


func _ready() -> void:
	if not _catalog.is_valid():
		push_error("CaseManager requires a valid case catalog.")
	set_process(false)


func get_case_definition(case_id: StringName) -> CaseDefinition:
	return _catalog.get_case(case_id)


func get_item_definition(item_id: StringName) -> ArchiveItemDefinition:
	return _catalog.get_item(item_id)


func reset_cases() -> bool:
	if _publishing or _progress.is_empty():
		return false
	var before := get_case_save_data()
	_queue.clear()
	_active_case_id = &""
	_progress.clear()
	_publish_changes(before)
	return true


func enqueue_case(case_id: StringName) -> bool:
	return enqueue_cases([case_id])


func enqueue_cases(case_ids: Variant) -> bool:
	if _publishing or not _catalog.is_valid() or typeof(case_ids) != TYPE_ARRAY or case_ids.is_empty():
		return false
	var new_ids: Array[StringName] = []
	for value: Variant in case_ids:
		if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return false
		var case_id := StringName(value)
		if not _catalog.has_case(case_id) or _progress.has(case_id) or new_ids.has(case_id):
			return false
		new_ids.append(case_id)
	var before := get_case_save_data()
	for case_id: StringName in new_ids:
		_queue.append(case_id)
		_progress[case_id] = CaseProgress.new(case_id)
	_publish_changes(before)
	return true


func has_active_case() -> bool:
	return not _active_case_id.is_empty()


func get_active_case() -> CaseProgress:
	return get_case_progress(_active_case_id)


func get_case_progress(case_id: StringName) -> CaseProgress:
	var record := _progress.get(case_id) as CaseProgress
	return null if record == null else record.copy()


func get_queue_snapshot() -> Array[StringName]:
	return _queue.duplicate()


func get_archived_case_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for case_id: StringName in _catalog.get_case_ids():
		var record := _progress.get(case_id) as CaseProgress
		if record != null and record.get_state() == CaseProgress.State.ARCHIVED:
			ids.append(case_id)
	return ids


func activate_next_case() -> CaseProgress:
	if _publishing or has_active_case() or _queue.is_empty():
		return null
	var before := get_case_save_data()
	_active_case_id = _queue.pop_front()
	_progress[_active_case_id] = CaseProgress.new(_active_case_id, CaseProgress.State.ACTIVE)
	_publish_changes(before)
	return get_active_case()


func mark_active_case_inspected() -> bool:
	return _advance_active(CaseProgress.State.ACTIVE, CaseProgress.State.INSPECTED)


func classify_active_case(category_id: StringName) -> bool:
	if not _catalog.has_category(category_id):
		return false
	return _advance_active(CaseProgress.State.INSPECTED, CaseProgress.State.CLASSIFIED, category_id)


func archive_active_case() -> bool:
	var record := get_active_case()
	if record == null:
		return false
	return _advance_active(CaseProgress.State.CLASSIFIED, CaseProgress.State.ARCHIVED, record.get_selected_category_id())


func is_case_classification_correct(case_id: StringName) -> bool:
	var record := get_case_progress(case_id)
	var definition := _catalog.get_case(case_id)
	return (
		record != null and definition != null
		and record.get_state() >= CaseProgress.State.CLASSIFIED
		and record.get_selected_category_id() == definition.expected_category_id
	)


func _advance_active(expected: CaseProgress.State, next: CaseProgress.State, category_id: StringName = &"") -> bool:
	if _publishing:
		return false
	var record := get_active_case()
	if record == null or record.get_state() != expected:
		return false
	var before := get_case_save_data()
	_progress[_active_case_id] = CaseProgress.new(_active_case_id, next, category_id)
	if next == CaseProgress.State.ARCHIVED:
		_active_case_id = &""
	_publish_changes(before)
	return true


func get_default_case_save_data() -> Dictionary:
	return {"case_save_version": CASE_SAVE_VERSION, "queue": [], "active_case_id": "", "progress": []}


func get_case_save_data() -> Dictionary:
	var queue_ids: Array[String] = []
	for case_id: StringName in _queue:
		queue_ids.append(String(case_id))
	var entries: Array[Dictionary] = []
	# Catalog order is stable, independent of queue insertion or restore order.
	for case_id: StringName in _catalog.get_case_ids():
		if _progress.has(case_id):
			entries.append((_progress[case_id] as CaseProgress).get_save_data())
	return {
		"case_save_version": CASE_SAVE_VERSION,
		"queue": queue_ids,
		"active_case_id": String(_active_case_id),
		"progress": entries,
	}


func is_valid_case_save_data(data: Variant) -> bool:
	if not _catalog.is_valid() or typeof(data) != TYPE_DICTIONARY:
		return false
	if not _has_exact_keys(data, SAVE_KEYS):
		return false
	# Godot JSON parses numbers as floats. Accept only the integral version 1;
	# bools, strings, fractional/non-finite values and other versions fail.
	var version: Variant = data["case_save_version"]
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or version != CASE_SAVE_VERSION:
		return false
	if typeof(data["queue"]) != TYPE_ARRAY or typeof(data["progress"]) != TYPE_ARRAY:
		return false
	if typeof(data["active_case_id"]) != TYPE_STRING:
		return false
	var active_id := StringName(data["active_case_id"])
	if not active_id.is_empty() and not _catalog.has_case(active_id):
		return false
	var queued := {}
	for value: Variant in data["queue"]:
		if typeof(value) != TYPE_STRING:
			return false
		var case_id := StringName(value)
		if not _catalog.has_case(case_id) or queued.has(case_id) or case_id == active_id:
			return false
		queued[case_id] = true
	var seen := {}
	var active_count := 0
	for entry: Variant in data["progress"]:
		if typeof(entry) != TYPE_DICTIONARY or not _has_exact_keys(entry, PROGRESS_KEYS):
			return false
		for key: String in PROGRESS_KEYS:
			if typeof(entry[key]) != TYPE_STRING:
				return false
		var case_id := StringName(entry["case_id"])
		if not _catalog.has_case(case_id) or seen.has(case_id):
			return false
		seen[case_id] = true
		var state: int = CaseProgress.STATE_LABELS.find(entry["state"])
		if state < 0:
			return false
		var category_id := StringName(entry["selected_category_id"])
		if state < CaseProgress.State.CLASSIFIED:
			if not category_id.is_empty():
				return false
		elif category_id.is_empty() or not _catalog.has_category(category_id):
			return false
		match state:
			CaseProgress.State.QUEUED:
				if not queued.has(case_id):
					return false
			CaseProgress.State.ARCHIVED:
				if queued.has(case_id) or case_id == active_id:
					return false
			_:
				if case_id != active_id or queued.has(case_id):
					return false
				active_count += 1
	for case_id: StringName in queued:
		if not seen.has(case_id):
			return false
	return active_count == (0 if active_id.is_empty() else 1)


func restore_case_save_data(data: Variant) -> bool:
	if _publishing or not is_valid_case_save_data(data):
		return false
	# Build every replacement before touching live authority.
	var replacement_queue: Array[StringName] = []
	for value: String in data["queue"]:
		replacement_queue.append(StringName(value))
	var replacement_progress := {}
	for entry: Dictionary in data["progress"]:
		var case_id := StringName(entry["case_id"])
		replacement_progress[case_id] = CaseProgress.new(
			case_id, CaseProgress.STATE_LABELS.find(entry["state"]), StringName(entry["selected_category_id"])
		)
	var before := get_case_save_data()
	_queue = replacement_queue
	_active_case_id = StringName(data["active_case_id"])
	_progress = replacement_progress
	_publish_changes(before)
	return true


func _has_exact_keys(data: Dictionary, keys: Array[String]) -> bool:
	if data.size() != keys.size():
		return false
	for key: String in keys:
		if not data.has(key):
			return false
	return true


func _publish_changes(before: Dictionary) -> void:
	var after := get_case_save_data()
	var old_progress := {}
	var new_progress := {}
	for entry: Dictionary in before["progress"]:
		old_progress[StringName(entry["case_id"])] = entry
	for entry: Dictionary in after["progress"]:
		new_progress[StringName(entry["case_id"])] = entry
	var changed_ids: Array[StringName] = []
	for case_id: StringName in _catalog.get_case_ids():
		if old_progress.get(case_id) != new_progress.get(case_id):
			changed_ids.append(case_id)
	# Observers see a complete committed state. Reentrant mutations are rejected
	# until all notifications for this operation have been delivered.
	_publishing = true
	if before["queue"] != after["queue"]:
		queue_changed.emit()
	if before["active_case_id"] != after["active_case_id"]:
		active_case_changed.emit()
	for case_id: StringName in changed_ids:
		case_progress_changed.emit(case_id)
	_publishing = false
