extends Node

var _checks := 0
var _failures := 0
var _queue_events := 0
var _active_events := 0
var _progress_events: Array[StringName] = []
var _event_states_valid := true
var _attempt_reentry := false
var _reentry_rejected := false


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	CaseManager.queue_changed.connect(_on_queue_changed)
	CaseManager.active_case_changed.connect(_on_active_changed)
	CaseManager.case_progress_changed.connect(_on_progress_changed)
	_check(CaseManager.get_case_save_data() == CaseManager.get_default_case_save_data(), "Startup is empty, including the later hook")
	_check(SaveManager.SAVE_VERSION == 4, "Global save version advances to 4")
	_check(SimulationManager.PROTOTYPE_CREDITS_PER_ITEM == 2, "Aggregate reward stays 2")
	for stage: MachineRuntime in SimulationManager.get_production_line().get_stages():
		_check(stage.is_enabled(), "Default enabled state: " + String(stage.get_id()))
	_test_catalog()
	_test_queue_and_lifecycle()
	_test_serialization()
	_test_isolation(false)
	_test_isolation(true)
	CaseManager.reset_cases()
	_check(_event_states_valid, "Every signal observer sees a complete valid state")
	if _failures == 0:
		print("Case foundation tests passed: %d checks." % _checks)
	else:
		push_error("Case foundation tests failed: %d/%d" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_catalog() -> void:
	var catalog := CaseCatalog.new()
	_check(catalog.is_valid(), "Default catalog is valid")
	_check(catalog.get_category_ids() == [&"PERS", &"ELEC", &"DOCS", &"BAG"], "Stable extensible category IDs")
	var names := ["Red Folding Umbrella", "Smartphone", "Backpack", "Passport Wallet", "Wireless Earbuds", "Canvas Tote Bag", "House Keys", "Tablet", "Document Folder", "Black Hotel Keycard"]
	var categories := [&"PERS", &"ELEC", &"BAG", &"DOCS", &"ELEC", &"BAG", &"PERS", &"ELEC", &"DOCS", &"PERS"]
	_check(catalog.get_case_ids().size() == 15, "Exactly fifteen authored cases")
	var seen_items := {}
	for index: int in range(10):
		var case_id := StringName("CASE_%04d" % (index + 1))
		var definition := catalog.get_case(case_id)
		_check(definition != null and definition.is_valid(), "Valid case " + String(case_id))
		if definition == null:
			continue
		_check(catalog.get_case_ids()[index] == case_id, "Deterministic unique case IDs")
		var item := catalog.get_item(definition.item_id)
		_check(item != null and item.is_valid(), "Valid referenced item")
		_check(not seen_items.has(definition.item_id), "Unique initial item IDs")
		seen_items[definition.item_id] = true
		_check(item.display_name == names[index] and item.category_id == categories[index], "Authored item/category " + String(case_id))
		_check(definition.expected_category_id == categories[index] and catalog.has_category(categories[index]), "Known expected category")
		_check(definition.routing_policy == (CaseDefinition.MANUAL_REVIEW if index == 9 else CaseDefinition.NORMAL), "Data-only routing policy")
	var umbrella := catalog.get_case(&"CASE_0001")
	_check(umbrella.found_location == "Central Station — Platform 4" and umbrella.found_time_label == "22:41" and umbrella.condition_text == "Wet / minor wear", "Exact umbrella metadata")
	_check(catalog.get_case(&"CASE_0010").found_location == "Archive Sector A1", "Later hook location")
	var added_cases := [
		[&"CASE_0011", &"canvas_tote_bag", "City Bus 42 — Rear Seat", "23:01", "Dry / minor staining", &"BAG"],
		[&"CASE_0012", &"red_folding_umbrella", "East Concourse — Bench 12", "23:05", "Dry / minor wear", &"PERS"],
		[&"CASE_0013", &"wireless_earbuds", "Platform 6 — Ticket Machine", "23:09", "Case scratched / intact", &"ELEC"],
		[&"CASE_0014", &"passport_wallet", "Taxi Rank — Lane 2", "23:13", "Closed / light wear", &"DOCS"],
		[&"CASE_0015", &"backpack", "Central Station — Locker Hall", "23:18", "Zipped / surface wear", &"BAG"],
	]
	for expected: Array in added_cases:
		var added := catalog.get_case(expected[0])
		_check(added != null and [added.item_id, added.found_location, added.found_time_label, added.condition_text, added.expected_category_id] == expected.slice(1), "Exact ordinary definition " + String(expected[0]))
		_check(added.routing_policy == CaseDefinition.NORMAL, "Normal routing " + String(expected[0]))
	umbrella.found_location = "Modified by caller"
	_check(catalog.get_case(&"CASE_0001").found_location == "Central Station — Platform 4", "Case definitions are detached")
	var item_copy := catalog.get_item(&"smartphone")
	item_copy.category_id = &"BAD"
	_check(catalog.get_item(&"smartphone").category_id == &"ELEC", "Item definitions are detached")
	var category_copy := catalog.get_category(&"PERS")
	category_copy.display_name = "Modified"
	_check(catalog.get_category(&"PERS").display_name == "Personal Items", "Category definitions are detached")
	var ids_copy := catalog.get_case_ids()
	ids_copy.clear()
	_check(catalog.get_case_ids().size() == 15, "Catalog ID snapshots are detached")
	_check(catalog.get_case(&"UNKNOWN") == null and catalog.get_item(&"UNKNOWN") == null and catalog.get_category(&"UNKNOWN") == null, "Unknown definition queries are safe")
	var category := CaseCategoryDefinition.new()
	category.category_id = &"CLOTH"
	category.display_name = "Clothing"
	var item := ArchiveItemDefinition.new()
	item.item_id = &"scarf"
	item.display_name = "Scarf"
	item.description = "A wool scarf."
	item.category_id = category.category_id
	var definition := CaseDefinition.new()
	definition.case_id = &"CASE_EXTRA"
	definition.item_id = item.item_id
	definition.expected_category_id = category.category_id
	definition.found_location = "Waiting Room"
	definition.found_time_label = "12:00"
	definition.condition_text = "Dry"
	definition.inspection_material = "Wool"
	definition.inspection_identifier = "None"
	definition.inspection_risk = "Normal"
	var extended := CaseCatalog.new([category], [item], [definition])
	_check(extended.is_valid() and extended.has_category(&"CLOTH"), "New categories need no enum change")
	item.display_name = "Changed input"
	_check(extended.get_item(&"scarf").display_name == "Scarf", "Catalog copies input resources")
	_check(not CaseCatalog.is_valid_catalog_data([], [item], [definition]), "Empty category catalog rejected")
	_check(not CaseCatalog.is_valid_catalog_data([category, category], [item], [definition]), "Duplicate category IDs rejected")
	_check(not CaseCatalog.is_valid_catalog_data([category], [item, item], [definition]), "Duplicate item IDs rejected")
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition, definition]), "Duplicate case IDs rejected")
	_check(not CaseCatalog.is_valid_catalog_data(["wrong type"], [item], [definition]), "Wrong category resource type rejected")
	_check(not CaseCatalog.is_valid_catalog_data([category], [null], [definition]), "Wrong item resource type rejected")
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [42]), "Wrong case resource type rejected")
	definition.item_id = &"missing"
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Unknown item reference rejected")
	definition.item_id = item.item_id
	definition.expected_category_id = &"UNKNOWN"
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Unknown expected category rejected")
	definition.expected_category_id = category.category_id
	definition.routing_policy = &"UNKNOWN"
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Unknown routing rejected")
	definition.routing_policy = CaseDefinition.NORMAL
	definition.condition_text = " "
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Blank metadata rejected")
	definition.condition_text = "Dry"
	for field: String in ["inspection_material", "inspection_identifier", "inspection_risk"]:
		var original: String = definition.get(field)
		definition.set(field, " ")
		_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Blank authored inspection field rejected: " + field)
		definition.set(field, original)
	item.category_id = &"UNKNOWN"
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Unknown item category rejected")
	item.category_id = category.category_id
	var second_category := CaseCategoryDefinition.new()
	second_category.category_id = &"OTHER"
	second_category.display_name = "Other"
	definition.expected_category_id = second_category.category_id
	_check(not CaseCatalog.is_valid_catalog_data([category, second_category], [item], [definition]), "Expected category must match authored item type")
	definition.expected_category_id = category.category_id
	item.description = " "
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Blank item description rejected")
	item.description = "A wool scarf."
	item.item_id = &""
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Empty item ID rejected")
	item.item_id = definition.item_id
	definition.case_id = &""
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Empty case ID rejected")
	definition.case_id = &"CASE_EXTRA"
	category.display_name = " "
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Blank category display rejected")
	category.display_name = "Clothing"
	category.category_id = &"invalid id"
	_check(not CaseCatalog.is_valid_catalog_data([category], [item], [definition]), "Malformed stable ID rejected")
	_check(not CaseCatalog.new([], [], []).is_valid(), "Invalid catalog stays unusable")


func _test_queue_and_lifecycle() -> void:
	CaseManager.reset_cases()
	_clear_events()
	_check(not CaseManager.reset_cases(), "Empty reset is a no-op")
	_check(CaseManager.activate_next_case() == null, "Empty queue cannot activate")
	_check(not CaseManager.mark_active_case_inspected(), "No active case cannot inspect")
	_check(not CaseManager.classify_active_case(&"PERS"), "No active case cannot classify")
	_check(not CaseManager.archive_active_case(), "No active case cannot archive")
	_check(not CaseManager.enqueue_case(&"UNKNOWN"), "Unknown enqueue rejected")
	_check(not CaseManager.enqueue_cases([]) and not CaseManager.enqueue_cases("CASE_0001"), "Empty/wrong-type batch rejected")
	_check(not CaseManager.enqueue_cases([&"CASE_0001", &"UNKNOWN"]), "Invalid batch is atomic")
	_check(not CaseManager.enqueue_cases([&"CASE_0001", &"CASE_0001"]), "Duplicate within batch rejected")
	_check(not CaseManager.enqueue_cases([&"CASE_0001", 42]), "Wrong ID type rejected atomically")
	_expect_events(0, 0, [], "All empty-state rejections are silent")
	_check(CaseManager.get_queue_snapshot().is_empty(), "Rejected batches commit no prefix")
	_attempt_reentry = true
	_check(CaseManager.enqueue_cases([&"CASE_0002", &"CASE_0001", &"CASE_0003"]), "Ordered batch enqueue")
	_attempt_reentry = false
	_check(_reentry_rejected, "Reentrant mutation rejected during notification")
	_expect_events(1, 0, [&"CASE_0001", &"CASE_0002", &"CASE_0003"], "Batch publishes once per changed component")
	_check(CaseManager.get_queue_snapshot() == [&"CASE_0002", &"CASE_0001", &"CASE_0003"], "Insertion order is authoritative")
	var queue_copy := CaseManager.get_queue_snapshot()
	queue_copy.clear()
	var progress_copy := CaseManager.get_case_progress(&"CASE_0002")
	progress_copy._state = CaseProgress.State.ARCHIVED
	_check(CaseManager.get_case_progress(&"CASE_0002").get_state() == CaseProgress.State.QUEUED, "Progress queries are detached")
	_check(CaseManager.get_queue_snapshot().size() == 3, "Queue queries are detached")
	_clear_events()
	_check(not CaseManager.enqueue_case(&"CASE_0001"), "Already queued case rejected")
	var queued_before := CaseManager.get_case_save_data()
	_check(not CaseManager.enqueue_cases([&"CASE_0004", &"CASE_0001"]), "Batch rejects a new prefix followed by an existing ID")
	_check(CaseManager.get_case_save_data() == queued_before, "Failed batch preserves a nonempty queue")
	_expect_events(0, 0, [], "Duplicate enqueue is silent")
	var active := CaseManager.activate_next_case()
	_check(active != null and active.get_case_id() == &"CASE_0002" and active.get_state() == CaseProgress.State.ACTIVE, "Activate first queued case")
	_expect_events(1, 1, [&"CASE_0002"], "Activation signals")
	_check(CaseManager.get_queue_snapshot() == [&"CASE_0001", &"CASE_0003"], "Activation consumes queue head")
	_check(active.get_selected_category_id().is_empty(), "Selection empty before classification")
	active._selected_category_id = &"DOCS"
	_check(CaseManager.get_active_case().get_selected_category_id().is_empty(), "Active return value cannot mutate authority")
	var definition_copy := CaseManager.get_case_definition(&"CASE_0002")
	definition_copy.expected_category_id = &"PERS"
	_check(CaseManager.get_case_definition(&"CASE_0002").expected_category_id == &"ELEC", "Manager definition queries remain immutable")
	_clear_events()
	_check(CaseManager.activate_next_case() == null, "Only one active case")
	_check(not CaseManager.enqueue_case(&"CASE_0002"), "Active case enqueue rejected")
	_check(not CaseManager.classify_active_case(&"PERS") and not CaseManager.archive_active_case(), "No skipping inspection/classification")
	_expect_events(0, 0, [], "Active-state rejections are silent")
	_check(CaseManager.mark_active_case_inspected(), "Inspect active case")
	_expect_events(0, 0, [&"CASE_0002"], "Inspection signals")
	_clear_events()
	_check(not CaseManager.mark_active_case_inspected(), "Cannot inspect twice or go backwards")
	_check(not CaseManager.classify_active_case(&"UNKNOWN") and not CaseManager.classify_active_case(&""), "Unknown/empty selected category rejected")
	_check(not CaseManager.archive_active_case(), "Cannot archive inspected case")
	_expect_events(0, 0, [], "Inspected-state rejections are silent")
	_check(CaseManager.classify_active_case(&"PERS"), "Wrong but known category accepted")
	_expect_events(0, 0, [&"CASE_0002"], "Classification signals")
	_check(not CaseManager.is_case_classification_correct(&"CASE_0002"), "Incorrect choice detected: ELEC vs PERS")
	_check(CaseManager.get_active_case().get_selected_category_id() == &"PERS", "Player choice retained")
	_clear_events()
	_check(not CaseManager.classify_active_case(&"ELEC") and not CaseManager.mark_active_case_inspected(), "Cannot reclassify or rewind")
	_expect_events(0, 0, [], "Classified-state rejections are silent")
	_check(CaseManager.archive_active_case(), "Archive classified case")
	_expect_events(0, 1, [&"CASE_0002"], "Archival signals")
	_check(not CaseManager.has_active_case() and CaseManager.get_active_case() == null, "Archival clears active slot")
	_check(CaseManager.get_archived_case_ids() == [&"CASE_0002"], "Archived case remains recorded")
	_clear_events()
	_check(not CaseManager.enqueue_case(&"CASE_0002") and not CaseManager.archive_active_case(), "Archived case cannot return or archive twice")
	_expect_events(0, 0, [], "Archived-state rejections are silent")
	_check(CaseManager.activate_next_case().get_case_id() == &"CASE_0001", "Next activation keeps insertion order")
	_check(CaseManager.mark_active_case_inspected() and CaseManager.classify_active_case(&"PERS"), "Correct classification accepted")
	_check(CaseManager.is_case_classification_correct(&"CASE_0001"), "Correct choice detected")
	_check(not CaseManager.is_case_classification_correct(&"CASE_0003") and not CaseManager.is_case_classification_correct(&"UNKNOWN"), "Unclassified/unknown correctness query is false")
	_check(CaseManager.archive_active_case(), "Second archival succeeds")
	_check(CaseManager.get_archived_case_ids() == [&"CASE_0001", &"CASE_0002"], "Archived query uses deterministic catalog order")
	_clear_events()
	_check(CaseManager.reset_cases(), "Explicit new-session reset clears history")
	_expect_events(1, 0, [&"CASE_0001", &"CASE_0002", &"CASE_0003"], "Reset signals for removed progress")
	_check(CaseManager.get_case_save_data() == CaseManager.get_default_case_save_data(), "Reset empty contract")


func _test_serialization() -> void:
	var valid := {
		"case_save_version": 1,
		"queue": ["CASE_0009", "CASE_0001"],
		"active_case_id": "CASE_0003",
		"progress": [
			_entry("CASE_0009", "QUEUED"), _entry("CASE_0003", "CLASSIFIED", "ELEC"),
			_entry("CASE_0001", "QUEUED"), _entry("CASE_0002", "ARCHIVED", "PERS"),
		],
	}
	_clear_events()
	_check(CaseManager.restore_case_save_data(valid), "Restore mixed queued/active/archived state")
	_expect_events(1, 1, [&"CASE_0001", &"CASE_0002", &"CASE_0003", &"CASE_0009"], "Atomic restore signals")
	var canonical := CaseManager.get_case_save_data()
	_check(canonical.queue == valid.queue and canonical.active_case_id == valid.active_case_id, "Queue order and active slot round-trip")
	_check(canonical.progress[0].case_id == "CASE_0001" and canonical.progress[3].case_id == "CASE_0009", "Canonical progress catalog order")
	_check(canonical.size() == 4 and canonical.progress[0].size() == 3, "Save contains only runtime fields")
	_check(CaseManager.get_active_case().get_selected_category_id() == &"ELEC" and not CaseManager.is_case_classification_correct(&"CASE_0003"), "Wrong classification survives restore")
	_clear_events()
	var json_data: Variant = JSON.parse_string(JSON.stringify(canonical))
	_check(CaseManager.restore_case_save_data(json_data), "Actual JSON number/string round-trip")
	_check(CaseManager.get_case_save_data() == canonical, "Round-trip preserves entire snapshot")
	_expect_events(0, 0, [], "Identical restore emits no events")
	var detached := CaseManager.get_case_save_data()
	detached.progress[0].state = "ARCHIVED"
	detached.queue.clear()
	valid.progress.clear()
	_check(CaseManager.get_case_save_data() == canonical, "Save payloads and restore inputs cannot mutate authority")
	var invalid: Array = [null, [], "invalid", true, 1]
	for version: Variant in [0, 2, -1, 1.5, "1", true, null, INF, NAN]:
		invalid.append(_changed(canonical, "case_save_version", version))
	for field: String in ["queue", "progress"]:
		invalid.append(_changed(canonical, field, {}))
		invalid.append(_changed(canonical, field, null))
	for active_value: Variant in [null, 3, &"CASE_0003", "UNKNOWN", "", "CASE_0001", "CASE_0002"]:
		invalid.append(_changed(canonical, "active_case_id", active_value))
	for queue_value: Array in [["UNKNOWN"], ["CASE_0001", "CASE_0001"], ["CASE_0003"], ["CASE_0002"], ["CASE_0010"], [4], [&"CASE_0001"], []]:
		invalid.append(_changed(canonical, "queue", queue_value))
	var duplicate := _json_copy(canonical)
	duplicate.progress.append(duplicate.progress[0].duplicate(true))
	invalid.append(duplicate)
	var multiple := _json_copy(canonical)
	multiple.progress.append(_entry("CASE_0004", "ACTIVE"))
	invalid.append(multiple)
	for replacement: Variant in [null, 42, "entry", {}, _entry("UNKNOWN", "QUEUED"), _entry("CASE_0001", "ACTIVE"), _entry("CASE_0001", "ARCHIVED", "PERS")]:
		var candidate := _json_copy(canonical)
		candidate.progress[0] = replacement
		invalid.append(candidate)
	for field: String in ["case_id", "state", "selected_category_id"]:
		for value: Variant in [null, 0, true, &"NAME", [], {}]:
			var candidate := _json_copy(canonical)
			candidate.progress[0][field] = value
			invalid.append(candidate)
	for state: String in ["UNKNOWN", "", "ACTIVE", "INSPECTED", "CLASSIFIED", "ARCHIVED"]:
		var candidate := _json_copy(canonical)
		candidate.progress[0].state = state
		invalid.append(candidate)
	for state: String in ["QUEUED", "ACTIVE", "INSPECTED", "CLASSIFIED", "ARCHIVED"]:
		var candidate := CaseManager.get_default_case_save_data()
		candidate.progress = [_entry("CASE_0001", state, "PERS" if state in ["QUEUED", "ACTIVE", "INSPECTED"] else "")]
		candidate.queue = ["CASE_0001"] if state == "QUEUED" else []
		candidate.active_case_id = "CASE_0001" if state in ["ACTIVE", "INSPECTED", "CLASSIFIED"] else ""
		invalid.append(candidate)
	var unknown_category := _json_copy(canonical)
	unknown_category.progress[1].selected_category_id = "UNKNOWN"
	invalid.append(unknown_category)
	var missing := _json_copy(canonical)
	missing.progress.remove_at(2)
	invalid.append(missing)
	var extra := _json_copy(canonical)
	extra["definition_text"] = "not runtime state"
	invalid.append(extra)
	extra = _json_copy(canonical)
	extra.progress[0]["found_location"] = "not runtime state"
	invalid.append(extra)
	for key: String in canonical.keys():
		var candidate := _json_copy(canonical)
		candidate.erase(key)
		invalid.append(candidate)
	for candidate: Variant in invalid:
		_check(not CaseManager.is_valid_case_save_data(candidate), "Corrupt schema rejected")
		_check(not CaseManager.restore_case_save_data(candidate), "Corrupt restore rejected")
		_check(CaseManager.get_case_save_data() == canonical, "Corrupt restore is atomic")
	_expect_events(0, 0, [], "All corrupt restores are silent")
	print("Strict case-save rejection corpus: %d invalid payloads checked for rejection and atomicity." % invalid.size())
	for state: String in CaseProgress.STATE_LABELS:
		var candidate := CaseManager.get_default_case_save_data()
		candidate.progress = [_entry("CASE_0001", state, "DOCS" if state in ["CLASSIFIED", "ARCHIVED"] else "")]
		candidate.queue = ["CASE_0001"] if state == "QUEUED" else []
		candidate.active_case_id = "CASE_0001" if state in ["ACTIVE", "INSPECTED", "CLASSIFIED"] else ""
		_check(CaseManager.is_valid_case_save_data(candidate), "Valid save representation: " + state)
		_check(CaseManager.restore_case_save_data(candidate), "Valid restore: " + state)
		_check(CaseManager.get_case_save_data() == candidate, "Restored exact state: " + state)
	_check(CaseManager.restore_case_save_data(CaseManager.get_default_case_save_data()), "Empty save can clear existing history")
	_check(CaseManager.enqueue_case(&"CASE_0010"), "Hook can be explicitly queued, never automatic")
	CaseManager.reset_cases()


func _test_isolation(disabled: bool) -> void:
	_check(SimulationManager.restore_production_save_data(SimulationManager.get_default_production_save_data()), "Prepare aggregate isolation state")
	_check(GameState.restore_state(200, 300, 7, 12.0), "Prepare nonzero totals")
	_check(SimulationManager.purchase_upgrade("sorter_motor_1") == 0, "Prepare owned upgrade")
	SimulationManager.simulate_elapsed(0.45)
	if disabled:
		_check(SimulationManager.set_machine_enabled(&"archive_intake", false), "Prepare disabled-stage variant")
	SimulationManager._process(0.2)
	var before := _production_snapshot()
	CaseManager.reset_cases()
	_check(CaseManager.enqueue_case(&"CASE_0001"), "Isolated enqueue")
	_check(CaseManager.activate_next_case() != null, "Isolated activate")
	_check(CaseManager.mark_active_case_inspected(), "Isolated inspect")
	_check(CaseManager.classify_active_case(&"PERS"), "Isolated classify")
	_check(CaseManager.archive_active_case(), "Isolated archive")
	var checkpoint := CaseManager.get_case_save_data()
	_check(CaseManager.reset_cases() and CaseManager.restore_case_save_data(checkpoint), "Isolated reset/restore")
	var after := _production_snapshot()
	for key: String in before.keys():
		_check(before[key] == after[key], "Authority untouched: " + key)
	_check(before == after, "Entire aggregate snapshot unchanged")
	print("Case authority isolation (%s): %s" % ["disabled stage" if disabled else "enabled line", JSON.stringify(after)])
	CaseManager.reset_cases()


func _production_snapshot() -> Dictionary:
	var line: ProductionLine = SimulationManager.get_production_line()
	var enabled := {}
	for stage: MachineRuntime in line.get_stages():
		enabled[String(stage.get_id())] = stage.is_enabled()
	return {
		"money": GameState.get_money(),
		"total_money_earned": GameState.get_total_money_earned(),
		"total_processed_items": GameState.get_total_processed_items(),
		"fraction": line.get_fractional_progress(),
		"pending_seconds": SimulationManager.get_pending_simulation_seconds(),
		"throughput": SimulationManager.get_effective_throughput(),
		"owned_upgrades": SimulationManager.get_owned_upgrade_ids(),
		"enabled": enabled,
		"production_save": SimulationManager.get_production_save_data(),
		"playtime": GameState.get_total_playtime(),
	}


func _entry(case_id: String, state: String, category: String = "") -> Dictionary:
	return {"case_id": case_id, "state": state, "selected_category_id": category}


func _changed(source: Dictionary, key: String, value: Variant) -> Dictionary:
	var result := _json_copy(source)
	result[key] = value
	return result


func _json_copy(source: Dictionary) -> Dictionary:
	# Untyped JSON arrays allow corrupt element fixtures without a TypedArray
	# rejecting the test assignment before the domain validator can inspect it.
	return JSON.parse_string(JSON.stringify(source))


func _clear_events() -> void:
	_queue_events = 0
	_active_events = 0
	_progress_events.clear()


func _expect_events(queue: int, active: int, progress: Array, context: String) -> void:
	_check(_queue_events == queue and _active_events == active and _progress_events == progress, context)


func _on_queue_changed() -> void:
	_queue_events += 1
	_observe_committed_state()
	if _attempt_reentry:
		_reentry_rejected = not CaseManager.enqueue_case(&"CASE_0010") and not CaseManager.reset_cases() and CaseManager.activate_next_case() == null and not CaseManager.restore_case_save_data(CaseManager.get_default_case_save_data())


func _on_active_changed() -> void:
	_active_events += 1
	_observe_committed_state()


func _on_progress_changed(case_id: StringName) -> void:
	_progress_events.append(case_id)
	_observe_committed_state()


func _observe_committed_state() -> void:
	_event_states_valid = _event_states_valid and CaseManager.is_valid_case_save_data(CaseManager.get_case_save_data())


func _check(condition: bool, context: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + context)
