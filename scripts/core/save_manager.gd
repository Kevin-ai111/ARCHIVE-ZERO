extends Node

signal game_saved
signal game_loaded

const SAVE_VERSION: int = 3
const PREVIOUS_SAVE_VERSION: int = 2
const LEGACY_SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://archive_zero_save.json"
const TEMP_SAVE_PATH: String = "user://archive_zero_save.tmp"


func save_game() -> bool:
	SimulationManager.flush_pending_simulation()
	var save_data: Dictionary = {
		"save_version": SAVE_VERSION,
		"money": GameState.get_money(),
		"total_money_earned": GameState.get_total_money_earned(),
		"total_processed_items": GameState.get_total_processed_items(),
		"total_playtime": GameState.get_total_playtime(),
		"save_timestamp": int(Time.get_unix_time_from_system()),
		"production_line": SimulationManager.get_production_save_data(),
	}

	var save_file: FileAccess = FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("Could not open save file for writing. Error: %s" % FileAccess.get_open_error())
		return false

	save_file.store_string(JSON.stringify(save_data, "\t"))
	var write_error: Error = save_file.get_error()
	save_file.close()
	if write_error != OK:
		push_error("Could not finish writing the save file. Error: %s" % write_error)
		_remove_temporary_save()
		return false

	var temporary_path: String = ProjectSettings.globalize_path(TEMP_SAVE_PATH)
	var final_path: String = ProjectSettings.globalize_path(SAVE_PATH)
	var replace_error: Error = DirAccess.rename_absolute(temporary_path, final_path)
	if replace_error != OK:
		push_error("Could not replace the save file. Error: %s" % replace_error)
		_remove_temporary_save()
		return false

	game_saved.emit()
	return true


func load_game() -> bool:
	if not has_save():
		push_warning("No ARCHIVE ZERO save file exists yet.")
		return false

	var serialized_data: String = _read_save_file()
	if serialized_data.is_empty():
		return false

	var save_data: Dictionary = _parse_and_prepare_save_data(serialized_data)
	if save_data.is_empty() or not _is_valid_complete_save(save_data):
		return false
	if not _restore_save_data(save_data):
		return false

	game_loaded.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> bool:
	if not has_save():
		return true

	var absolute_path: String = ProjectSettings.globalize_path(SAVE_PATH)
	var result: Error = DirAccess.remove_absolute(absolute_path)
	if result != OK:
		push_error("Could not delete save file. Error: %s" % result)
		return false
	return true


func _read_save_file() -> String:
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_error("Could not open save file for reading. Error: %s" % FileAccess.get_open_error())
		return ""

	var serialized_data: String = save_file.get_as_text()
	save_file.close()
	return serialized_data


func _parse_and_prepare_save_data(serialized_data: String) -> Dictionary:
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(serialized_data)
	if parse_error != OK:
		push_warning(
			(
				"Save file is invalid JSON at line %d: %s"
				% [json.get_error_line(), json.get_error_message()]
			)
		)
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Save file root must be a dictionary.")
		return {}

	return _prepare_save_data(json.data as Dictionary)


func _is_valid_complete_save(save_data: Dictionary) -> bool:
	if not _is_valid_base_save(save_data):
		push_warning("Save file has an unsupported or invalid structure.")
		return false
	if typeof(save_data["production_line"]) != TYPE_DICTIONARY:
		push_warning("Save file contains invalid production state.")
		return false

	var production_data: Dictionary = save_data["production_line"] as Dictionary
	if not SimulationManager.is_valid_production_save_data(production_data):
		push_warning("Save file contains invalid production state.")
		return false
	return true


func _restore_save_data(save_data: Dictionary) -> bool:
	if not GameState.restore_state(
		int(save_data["money"]),
		int(save_data["total_money_earned"]),
		int(save_data["total_processed_items"]),
		float(save_data["total_playtime"])
	):
		push_warning("Save file contains invalid game state.")
		return false

	var production_data: Dictionary = save_data["production_line"] as Dictionary
	if not SimulationManager.restore_production_save_data(production_data):
		push_error("Validated production state could not be restored.")
		return false
	return true


func _prepare_save_data(save_data: Dictionary) -> Dictionary:
	if not save_data.has("save_version") or not _is_non_negative_integer(save_data["save_version"]):
		return {}

	var version: int = int(save_data["save_version"])
	if version == LEGACY_SAVE_VERSION:
		var legacy_data: Dictionary = save_data.duplicate(true)
		legacy_data["save_version"] = SAVE_VERSION
		legacy_data["production_line"] = SimulationManager.get_default_production_save_data()
		return legacy_data
	if version != PREVIOUS_SAVE_VERSION and version != SAVE_VERSION:
		return {}

	var migrated_data: Dictionary = save_data.duplicate(true)
	var production_data: Variant = migrated_data.get(
		"production_line", migrated_data.get("production", null)
	)
	if typeof(production_data) != TYPE_DICTIONARY:
		return {}

	var migrated_production: Dictionary = SimulationManager.migrate_production_save_data(
		production_data as Dictionary, version
	)
	if migrated_production.is_empty():
		return {}

	migrated_data["production_line"] = migrated_production
	migrated_data["save_version"] = SAVE_VERSION
	migrated_data.erase("production")
	return migrated_data


func _remove_temporary_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE_PATH))


func _is_valid_base_save(save_data: Dictionary) -> bool:
	var required_fields: Array[String] = [
		"save_version",
		"money",
		"total_money_earned",
		"total_processed_items",
		"total_playtime",
		"save_timestamp",
		"production_line",
	]
	for field: String in required_fields:
		if not save_data.has(field):
			return false

	return (
		_is_non_negative_integer(save_data["save_version"])
		and int(save_data["save_version"]) == SAVE_VERSION
		and _is_non_negative_integer(save_data["money"])
		and _is_non_negative_integer(save_data["total_money_earned"])
		and _is_non_negative_integer(save_data["total_processed_items"])
		and _is_non_negative_number(save_data["total_playtime"])
		and _is_non_negative_integer(save_data["save_timestamp"])
	)


func _is_non_negative_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= 0
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value >= 0.0 and value == floor(value)
	return false


func _is_non_negative_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and value >= 0.0
