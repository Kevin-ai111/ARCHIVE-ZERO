class_name CaseCatalog
extends RefCounted

const DEFAULT_CATEGORIES: Array[Resource] = [
	preload("res://data/cases/categories/pers.tres"),
	preload("res://data/cases/categories/elec.tres"),
	preload("res://data/cases/categories/docs.tres"),
	preload("res://data/cases/categories/bag.tres"),
]
const DEFAULT_ITEMS: Array[Resource] = [
	preload("res://data/cases/items/red_folding_umbrella.tres"),
	preload("res://data/cases/items/smartphone.tres"),
	preload("res://data/cases/items/backpack.tres"),
	preload("res://data/cases/items/passport_wallet.tres"),
	preload("res://data/cases/items/wireless_earbuds.tres"),
	preload("res://data/cases/items/canvas_tote_bag.tres"),
	preload("res://data/cases/items/house_keys.tres"),
	preload("res://data/cases/items/tablet.tres"),
	preload("res://data/cases/items/document_folder.tres"),
	preload("res://data/cases/items/black_hotel_keycard.tres"),
]
const DEFAULT_CASES: Array[Resource] = [
	preload("res://data/cases/records/case_0001.tres"),
	preload("res://data/cases/records/case_0002.tres"),
	preload("res://data/cases/records/case_0003.tres"),
	preload("res://data/cases/records/case_0004.tres"),
	preload("res://data/cases/records/case_0005.tres"),
	preload("res://data/cases/records/case_0006.tres"),
	preload("res://data/cases/records/case_0007.tres"),
	preload("res://data/cases/records/case_0008.tres"),
	preload("res://data/cases/records/case_0009.tres"),
	preload("res://data/cases/records/case_0010.tres"),
]

var _categories: Dictionary = {}
var _items: Dictionary = {}
var _cases: Dictionary = {}
var _case_ids: Array[StringName] = []
var _valid := false


func _init(categories: Array = DEFAULT_CATEGORIES, items: Array = DEFAULT_ITEMS, cases: Array = DEFAULT_CASES) -> void:
	if not is_valid_catalog_data(categories, items, cases):
		return
	for category: CaseCategoryDefinition in categories:
		_categories[category.category_id] = category.duplicate(true)
	for item: ArchiveItemDefinition in items:
		_items[item.item_id] = item.duplicate(true)
	for definition: CaseDefinition in cases:
		_cases[definition.case_id] = definition.duplicate(true)
		_case_ids.append(definition.case_id)
	_valid = true


static func is_valid_catalog_data(categories: Array, items: Array, cases: Array) -> bool:
	if categories.is_empty() or items.is_empty() or cases.is_empty():
		return false
	var category_ids := {}
	for value: Variant in categories:
		if not value is CaseCategoryDefinition:
			return false
		var category := value as CaseCategoryDefinition
		if not category.is_valid() or category_ids.has(category.category_id):
			return false
		category_ids[category.category_id] = true
	var item_ids := {}
	for value: Variant in items:
		if not value is ArchiveItemDefinition:
			return false
		var item := value as ArchiveItemDefinition
		if not item.is_valid() or item_ids.has(item.item_id) or not category_ids.has(item.category_id):
			return false
		item_ids[item.item_id] = item.category_id
	var case_ids := {}
	for value: Variant in cases:
		if not value is CaseDefinition:
			return false
		var definition := value as CaseDefinition
		if not definition.is_valid() or case_ids.has(definition.case_id):
			return false
		if not item_ids.has(definition.item_id) or not category_ids.has(definition.expected_category_id):
			return false
		if definition.expected_category_id != item_ids[definition.item_id]:
			return false
		case_ids[definition.case_id] = true
	return true


func is_valid() -> bool:
	return _valid


func get_case_ids() -> Array[StringName]:
	return _case_ids.duplicate()


func get_category_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_categories.keys())
	return result


func get_category(category_id: StringName) -> CaseCategoryDefinition:
	var definition := _categories.get(category_id) as CaseCategoryDefinition
	return null if definition == null else definition.duplicate(true) as CaseCategoryDefinition


func get_item(item_id: StringName) -> ArchiveItemDefinition:
	var definition := _items.get(item_id) as ArchiveItemDefinition
	return null if definition == null else definition.duplicate(true) as ArchiveItemDefinition


func get_case(case_id: StringName) -> CaseDefinition:
	var definition := _cases.get(case_id) as CaseDefinition
	return null if definition == null else definition.duplicate(true) as CaseDefinition


func has_case(case_id: StringName) -> bool:
	return _cases.has(case_id)


func has_category(category_id: StringName) -> bool:
	return _categories.has(category_id)
