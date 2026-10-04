class_name CaseProgress
extends RefCounted

enum State { QUEUED, ACTIVE, INSPECTED, CLASSIFIED, ARCHIVED }
const STATE_LABELS: Array[String] = ["QUEUED", "ACTIVE", "INSPECTED", "CLASSIFIED", "ARCHIVED"]

# Public queries return detached copies, never CaseManager's authority.
var _case_id: StringName
var _state: State
var _selected_category_id: StringName


func _init(case_id: StringName, state: State = State.QUEUED, category_id: StringName = &"") -> void:
	_case_id = case_id
	_state = state
	_selected_category_id = category_id


func get_case_id() -> StringName:
	return _case_id


func get_state() -> State:
	return _state


func get_selected_category_id() -> StringName:
	return _selected_category_id


func get_save_data() -> Dictionary:
	return {
		"case_id": String(_case_id),
		"state": STATE_LABELS[_state],
		"selected_category_id": String(_selected_category_id),
	}


func copy() -> CaseProgress:
	return CaseProgress.new(_case_id, _state, _selected_category_id)
