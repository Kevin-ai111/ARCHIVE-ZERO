extends Node

# This domain owns only stage/order. Production, cases and live saves stay separate.
enum Stage { MANUAL_SHIFT, SCANNER_ONLINE, SORTER_ONLINE, FULL_LINE_ONLINE }
signal commissioning_stage_changed(stage: Stage)

const COMMISSIONING_SAVE_VERSION := 1
const STAGE_LABELS: Array[String] = ["MANUAL_SHIFT", "SCANNER_ONLINE", "SORTER_ONLINE", "FULL_LINE_ONLINE"]
const MACHINE_STAGES := {&"receiving_desk": Stage.MANUAL_SHIFT, &"basic_scanner": Stage.SCANNER_ONLINE, &"basic_sorter": Stage.SORTER_ONLINE, &"archive_intake": Stage.FULL_LINE_ONLINE}

var _stage: Stage = Stage.FULL_LINE_ONLINE
var _publishing := false


func get_stage() -> Stage:
	return _stage


func is_machine_commissioned(machine_id: StringName) -> bool:
	return MACHINE_STAGES.has(machine_id) and _stage >= int(MACHINE_STAGES[machine_id])


func reset_to_manual_shift() -> bool:
	return _commit(Stage.MANUAL_SHIFT)


func commission_scanner() -> bool:
	return _advance(Stage.MANUAL_SHIFT, Stage.SCANNER_ONLINE)


func commission_sorter() -> bool:
	return _advance(Stage.SCANNER_ONLINE, Stage.SORTER_ONLINE)


func commission_intake() -> bool:
	return _advance(Stage.SORTER_ONLINE, Stage.FULL_LINE_ONLINE)


func _advance(expected: Stage, next: Stage) -> bool:
	return _commit(next) if _stage == expected else false


func _commit(next: Stage) -> bool:
	if _publishing or next == _stage or next < Stage.MANUAL_SHIFT or next > Stage.FULL_LINE_ONLINE:
		return false
	_stage = next
	_publishing = true
	commissioning_stage_changed.emit(_stage)
	_publishing = false
	return true


func get_default_commissioning_save_data() -> Dictionary:
	return {"commissioning_save_version": COMMISSIONING_SAVE_VERSION, "stage": "FULL_LINE_ONLINE"}


func get_commissioning_save_data() -> Dictionary:
	return {"commissioning_save_version": COMMISSIONING_SAVE_VERSION, "stage": STAGE_LABELS[_stage]}


func is_valid_commissioning_save_data(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.size() != 2:
		return false
	if not data.has("commissioning_save_version") or not data.has("stage"):
		return false
	for key: Variant in data:
		if typeof(key) != TYPE_STRING:
			return false
	# JSON integral 1.0 is accepted; bool, strings, fractions and nonfinite fail.
	var version: Variant = data["commissioning_save_version"]
	return typeof(version) in [TYPE_INT, TYPE_FLOAT] and version == COMMISSIONING_SAVE_VERSION and typeof(data["stage"]) == TYPE_STRING and data["stage"] in STAGE_LABELS


func restore_commissioning_save_data(data: Variant) -> bool:
	if _publishing or not is_valid_commissioning_save_data(data):
		return false
	var replacement: Stage = STAGE_LABELS.find(data["stage"]) as Stage
	if replacement != _stage:
		_commit(replacement)
	return true
