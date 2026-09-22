extends Node

signal game_saved
signal game_loaded

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://archive_zero_save.json"
const TEMP_SAVE_PATH: String = "user://archive_zero_save.tmp"


func save_game() -> bool:
	var save_data: Dictionary = {
		"save_version": SAVE_VERSION,
		"money": GameState.get_money(),
		"total_money_earned": GameState.get_total_money_earned(),
		"total_processed_items": GameState.get_total_processed_items(),
		"total_playtime": GameState.get_total_playtime(),
		"save_timestamp": int(Time.get_unix_time_from_system()),
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

	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_error("Could not open save file for reading. Error: %s" % FileAccess.get_open_error())
		return false

	var serialized_data: String = save_file.get_as_text()
	save_file.close()

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(serialized_data)
	if parse_error != OK:
		push_warning(
			(
				"Save file is invalid JSON at line %d: %s"
				% [json.get_error_line(), json.get_error_message()]
			)
		)
		return false

	var save_data: Variant = json.data
	if typeof(save_data) != TYPE_DICTIONARY or not _is_valid_save(save_data as Dictionary):
		push_warning("Save file has an unsupported or invalid structure.")
		return false

	var validated_data: Dictionary = save_data as Dictionary
	GameState.restore_state(
		int(validated_data["money"]),
		int(validated_data["total_money_earned"]),
		int(validated_data["total_processed_items"]),
		float(validated_data["total_playtime"])
	)
	SimulationManager.reset_transient_progress()
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


func _remove_temporary_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE_PATH))


func _is_valid_save(save_data: Dictionary) -> bool:
	var required_fields: Array[String] = [
		"save_version",
		"money",
		"total_money_earned",
		"total_processed_items",
		"total_playtime",
		"save_timestamp",
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
		return value >= 0.0 and value == floor(value)
	return false


func _is_non_negative_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and value >= 0.0
