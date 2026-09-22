class_name ProductionLineFactory
extends RefCounted

const RECEIVING_DESK = preload("res://data/machines/receiving_desk.tres")
const BASIC_SCANNER = preload("res://data/machines/basic_scanner.tres")
const BASIC_SORTER = preload("res://data/machines/basic_sorter.tres")
const ARCHIVE_INTAKE = preload("res://data/machines/archive_intake.tres")


static func create_initial_line() -> ProductionLine:
	var definitions: Array[MachineDefinition] = [
		RECEIVING_DESK,
		BASIC_SCANNER,
		BASIC_SORTER,
		ARCHIVE_INTAKE,
	]
	return ProductionLine.new(definitions)
