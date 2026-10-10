extends Node

# Opening-shift orchestration only. Case lifecycle, commissioning, production,
# machine runtime, upgrades and Credits remain in their existing authorities.

signal first_shift_state_changed(phase: Phase)
signal case_reward_granted(case_id: StringName, credits: int)

enum Phase {
	MANUAL_CASES,
	SCANNER_READY,
	SCANNER_CASES,
	SORTER_READY,
	SORTER_CASES,
	INTAKE_READY,
	COMPLETE,
}

enum CommissionResult {
	SUCCESS,
	WRONG_PHASE,
	INSUFFICIENT_FUNDS,
	ALREADY_COMMISSIONED,
	TRANSACTION_FAILED,
}

const FIRST_SHIFT_SAVE_VERSION := 1
const PHASE_LABELS: Array[String] = [
	"MANUAL_CASES",
	"SCANNER_READY",
	"SCANNER_CASES",
	"SORTER_READY",
	"SORTER_CASES",
	"INTAKE_READY",
	"COMPLETE",
]
const MANUAL_CASE_IDS: Array[StringName] = [
	&"CASE_0001", &"CASE_0002", &"CASE_0003", &"CASE_0004", &"CASE_0005", &"CASE_0006",
]
const SCANNER_CASE_IDS: Array[StringName] = [
	&"CASE_0007", &"CASE_0008", &"CASE_0009", &"CASE_0011",
]
const SORTER_CASE_IDS: Array[StringName] = [
	&"CASE_0012", &"CASE_0013", &"CASE_0014", &"CASE_0015",
]
const FIRST_SHIFT_CASE_IDS: Array[StringName] = [
	&"CASE_0001", &"CASE_0002", &"CASE_0003", &"CASE_0004", &"CASE_0005", &"CASE_0006",
	&"CASE_0007", &"CASE_0008", &"CASE_0009", &"CASE_0011",
	&"CASE_0012", &"CASE_0013", &"CASE_0014", &"CASE_0015",
]
const SCANNER_COST := 16
const SORTER_COST := 18
const INTAKE_COST := 20
const CASE_BASE_REWARD := 4
const CASE_ACCURACY_BONUS := 1
const RECEIVING_ID := &"receiving_desk"
const SCANNER_ID := &"basic_scanner"
const SORTER_ID := &"basic_sorter"
const INTAKE_ID := &"archive_intake"
const SAVE_KEYS: Array[String] = [
	"first_shift_save_version", "phase", "claimed_reward_case_ids", "completed",
]

var _phase: Phase = Phase.COMPLETE
var _claimed_reward_case_ids: Array[StringName] = []
var _session_initialized := false
var _mutating := false


func _ready() -> void:
	CaseManager.active_case_changed.connect(_on_active_case_changed)
	CaseManager.case_progress_changed.connect(_on_case_progress_changed)
	set_process(false)


func ensure_fresh_game_initialized() -> bool:
	if _session_initialized:
		return true
	return start_new_game()


func start_new_game() -> bool:
	if _mutating:
		return false
	_mutating = true
	var success := true
	if CaseManager.get_case_save_data() != CaseManager.get_default_case_save_data():
		success = CaseManager.reset_cases()
	if success:
		success = GameState.restore_state(0, 0, 0, 0.0)
	if success:
		success = SimulationManager.restore_production_save_data(
			SimulationManager.get_default_production_save_data()
		)
	if success:
		success = SimulationManager.set_machine_enabled(RECEIVING_ID, true)
	for machine_id: StringName in [SCANNER_ID, SORTER_ID, INTAKE_ID]:
		if success:
			success = SimulationManager.set_machine_enabled(machine_id, false)
	if success and CommissioningManager.get_stage() != CommissioningManager.Stage.MANUAL_SHIFT:
		success = CommissioningManager.reset_to_manual_shift()
	if success:
		success = CaseManager.enqueue_cases(FIRST_SHIFT_CASE_IDS)
	if success:
		_phase = Phase.MANUAL_CASES
		_claimed_reward_case_ids.clear()
		_session_initialized = true
	_mutating = false
	if success:
		first_shift_state_changed.emit(_phase)
	return success


func get_phase() -> Phase:
	return _phase


func get_phase_label() -> String:
	return PHASE_LABELS[_phase]


func is_initialized() -> bool:
	return _session_initialized


func is_complete() -> bool:
	return _phase == Phase.COMPLETE


func is_transaction_active() -> bool:
	return _mutating


func is_upgrade_purchasing_unlocked() -> bool:
	return is_complete()


func get_first_shift_case_ids() -> Array[StringName]:
	return FIRST_SHIFT_CASE_IDS.duplicate()


func get_claimed_reward_case_ids() -> Array[StringName]:
	return _claimed_reward_case_ids.duplicate()


func can_activate_next_case() -> bool:
	if not _session_initialized or CaseManager.has_active_case():
		return false
	var queue := CaseManager.get_queue_snapshot()
	if queue.is_empty():
		return false
	return queue[0] in _case_ids_for_phase(_phase)


func activate_next_case() -> CaseProgress:
	if _mutating or not can_activate_next_case():
		return null
	return CaseManager.activate_next_case()


func commission_scanner() -> CommissionResult:
	return _commission(
		Phase.SCANNER_READY,
		CommissioningManager.Stage.MANUAL_SHIFT,
		SCANNER_COST,
		SCANNER_ID,
		CommissioningManager.commission_scanner,
		Phase.SCANNER_CASES
	)


func commission_sorter() -> CommissionResult:
	return _commission(
		Phase.SORTER_READY,
		CommissioningManager.Stage.SCANNER_ONLINE,
		SORTER_COST,
		SORTER_ID,
		CommissioningManager.commission_sorter,
		Phase.SORTER_CASES
	)


func commission_intake() -> CommissionResult:
	return _commission(
		Phase.INTAKE_READY,
		CommissioningManager.Stage.SORTER_ONLINE,
		INTAKE_COST,
		INTAKE_ID,
		CommissioningManager.commission_intake,
		Phase.COMPLETE
	)


func get_primary_action_text() -> String:
	if CaseManager.has_active_case():
		return "OPEN ACTIVE CASE"
	match _phase:
		Phase.MANUAL_CASES, Phase.SCANNER_CASES, Phase.SORTER_CASES:
			return "CASE READY" if can_activate_next_case() else "CASE IN PROGRESS"
		Phase.SCANNER_READY:
			return "COMMISSION SCANNER — 16 C"
		Phase.SORTER_READY:
			return "COMMISSION SORTER — 18 C"
		Phase.INTAKE_READY:
			return "COMMISSION INTAKE — 20 C"
		_:
			return "FULL LINE ONLINE"


func get_objective_text() -> String:
	match _phase:
		Phase.MANUAL_CASES:
			return "FIRST SHIFT · PROCESS CASES MANUALLY"
		Phase.SCANNER_READY:
			return "FIRST SHIFT · SCANNER READY"
		Phase.SCANNER_CASES:
			return "FIRST SHIFT · SCANNER ASSISTANCE"
		Phase.SORTER_READY:
			return "FIRST SHIFT · SORTER READY"
		Phase.SORTER_CASES:
			return "FIRST SHIFT · SCANNER + SORTER"
		Phase.INTAKE_READY:
			return "FIRST SHIFT · INTAKE READY"
		_:
			return "FIRST SHIFT COMPLETE"


func get_commission_result_message(result: CommissionResult) -> String:
	match result:
		CommissionResult.SUCCESS:
			return "Commissioning complete."
		CommissionResult.INSUFFICIENT_FUNDS:
			return "Not enough Credits for commissioning."
		CommissionResult.ALREADY_COMMISSIONED:
			return "This machine is already commissioned."
		CommissionResult.TRANSACTION_FAILED:
			return "Commissioning could not be completed. No changes were applied."
		_:
			return "Complete the current First Shift objective first."


func get_default_first_shift_save_data() -> Dictionary:
	return {
		"first_shift_save_version": FIRST_SHIFT_SAVE_VERSION,
		"phase": PHASE_LABELS[Phase.MANUAL_CASES],
		"claimed_reward_case_ids": [],
		"completed": false,
	}


func get_legacy_complete_save_data() -> Dictionary:
	return {
		"first_shift_save_version": FIRST_SHIFT_SAVE_VERSION,
		"phase": PHASE_LABELS[Phase.COMPLETE],
		"claimed_reward_case_ids": [],
		"completed": true,
	}


func get_first_shift_save_data() -> Dictionary:
	var claimed: Array[String] = []
	for case_id: StringName in FIRST_SHIFT_CASE_IDS:
		if _claimed_reward_case_ids.has(case_id):
			claimed.append(String(case_id))
	return {
		"first_shift_save_version": FIRST_SHIFT_SAVE_VERSION,
		"phase": PHASE_LABELS[_phase],
		"claimed_reward_case_ids": claimed,
		"completed": is_complete(),
	}


func is_valid_first_shift_save_data(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.size() != SAVE_KEYS.size():
		return false
	for key: String in SAVE_KEYS:
		if not data.has(key):
			return false
	var version: Variant = data.first_shift_save_version
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or version != FIRST_SHIFT_SAVE_VERSION:
		return false
	if typeof(data.phase) != TYPE_STRING or data.phase not in PHASE_LABELS:
		return false
	if typeof(data.completed) != TYPE_BOOL or typeof(data.claimed_reward_case_ids) != TYPE_ARRAY:
		return false
	var phase: int = PHASE_LABELS.find(data.phase)
	if bool(data.completed) != (phase == Phase.COMPLETE):
		return false
	var claimed: Array[StringName] = []
	for value: Variant in data.claimed_reward_case_ids:
		if typeof(value) != TYPE_STRING:
			return false
		var case_id := StringName(value)
		if case_id not in FIRST_SHIFT_CASE_IDS or claimed.has(case_id):
			return false
		claimed.append(case_id)
	for index: int in claimed.size():
		if claimed[index] != FIRST_SHIFT_CASE_IDS[index]:
			return false
	if not _claim_count_matches_phase(claimed.size(), phase):
		return false
	return true


func is_valid_save_composition(
	first_shift_data: Variant, case_data: Variant, commissioning_data: Variant
) -> bool:
	if not is_valid_first_shift_save_data(first_shift_data):
		return false
	if not CaseManager.is_valid_case_save_data(case_data):
		return false
	if not CommissioningManager.is_valid_commissioning_save_data(commissioning_data):
		return false
	var first_shift: Dictionary = first_shift_data as Dictionary
	var claimed_values: Array = first_shift["claimed_reward_case_ids"] as Array
	# Empty COMPLETE claims are the explicit pre-v4 migration marker. Older
	# saves did not own First Shift/Case cross-domain history.
	if first_shift["phase"] == PHASE_LABELS[Phase.COMPLETE] and claimed_values.is_empty():
		return true

	var expected_stage_by_phase := {
		PHASE_LABELS[Phase.MANUAL_CASES]: CommissioningManager.STAGE_LABELS[CommissioningManager.Stage.MANUAL_SHIFT],
		PHASE_LABELS[Phase.SCANNER_READY]: CommissioningManager.STAGE_LABELS[CommissioningManager.Stage.MANUAL_SHIFT],
		PHASE_LABELS[Phase.SCANNER_CASES]: CommissioningManager.STAGE_LABELS[CommissioningManager.Stage.SCANNER_ONLINE],
		PHASE_LABELS[Phase.SORTER_READY]: CommissioningManager.STAGE_LABELS[CommissioningManager.Stage.SCANNER_ONLINE],
		PHASE_LABELS[Phase.SORTER_CASES]: CommissioningManager.STAGE_LABELS[CommissioningManager.Stage.SORTER_ONLINE],
		PHASE_LABELS[Phase.INTAKE_READY]: CommissioningManager.STAGE_LABELS[CommissioningManager.Stage.SORTER_ONLINE],
		PHASE_LABELS[Phase.COMPLETE]: CommissioningManager.STAGE_LABELS[CommissioningManager.Stage.FULL_LINE_ONLINE],
	}
	if commissioning_data["stage"] != expected_stage_by_phase.get(first_shift["phase"], ""):
		return false

	var claimed := {}
	for value: String in claimed_values:
		claimed[StringName(value)] = true
	var archived := {}
	for entry: Dictionary in case_data["progress"]:
		var case_id := StringName(entry["case_id"])
		if case_id in FIRST_SHIFT_CASE_IDS and entry["state"] == CaseProgress.STATE_LABELS[CaseProgress.State.ARCHIVED]:
			archived[case_id] = true
	for case_id: StringName in claimed:
		if not archived.has(case_id):
			return false
	for case_id: StringName in archived:
		if not claimed.has(case_id):
			return false
	return true


func restore_first_shift_save_data(data: Variant) -> bool:
	if _mutating or not is_valid_first_shift_save_data(data):
		return false
	var next_phase: int = PHASE_LABELS.find(data.phase)
	var next_claimed: Array[StringName] = []
	for value: String in data.claimed_reward_case_ids:
		next_claimed.append(StringName(value))
	var changed := _phase != next_phase or _claimed_reward_case_ids != next_claimed or not _session_initialized
	_phase = next_phase as Phase
	_claimed_reward_case_ids = next_claimed
	_session_initialized = true
	if changed:
		first_shift_state_changed.emit(_phase)
	return true


func _commission(
	expected_phase: Phase,
	expected_stage: int,
	cost: int,
	machine_id: StringName,
	advance: Callable,
	next_phase: Phase
) -> CommissionResult:
	if _mutating:
		return CommissionResult.TRANSACTION_FAILED
	if _phase > expected_phase or CommissioningManager.get_stage() > expected_stage:
		return CommissionResult.ALREADY_COMMISSIONED
	if _phase != expected_phase or CommissioningManager.get_stage() != expected_stage:
		return CommissionResult.WRONG_PHASE
	var stage: MachineRuntime = SimulationManager.get_production_line().get_stage(machine_id)
	if (
		stage == null
		or stage.is_enabled()
		or int(CommissioningManager.MACHINE_STAGES.get(machine_id, -1)) != expected_stage + 1
	):
		return CommissionResult.TRANSACTION_FAILED
	if not Economy.can_afford(cost):
		return CommissionResult.INSUFFICIENT_FUNDS
	var snapshot := _get_commission_snapshot()
	if snapshot.is_empty():
		return CommissionResult.TRANSACTION_FAILED
	_mutating = true
	var success := Economy.spend_money(cost)
	if success:
		success = bool(advance.call())
	if success:
		success = SimulationManager.set_machine_enabled(machine_id, true)
	if success:
		_phase = next_phase
	if success:
		success = _commission_postconditions_hold(snapshot, expected_stage + 1, cost, machine_id, next_phase)
	if not success:
		var rolled_back := _restore_commission_snapshot(snapshot)
		_mutating = false
		if not rolled_back:
			push_error("First Shift commissioning rollback failed to restore the exact pre-call state.")
		return CommissionResult.TRANSACTION_FAILED
	_mutating = false
	first_shift_state_changed.emit(_phase)
	return CommissionResult.SUCCESS


func _get_commission_snapshot() -> Dictionary:
	var simulation := SimulationManager.get_transaction_snapshot()
	if not SimulationManager.is_valid_transaction_snapshot(simulation):
		return {}
	return {
		"game": {
			"money": GameState.get_money(),
			"earned": GameState.get_total_money_earned(),
			"items": GameState.get_total_processed_items(),
			"playtime": GameState.get_total_playtime(),
		},
		"commissioning": CommissioningManager.get_commissioning_save_data(),
		"simulation": simulation,
		"phase": _phase,
	}


func _commission_postconditions_hold(
	snapshot: Dictionary,
	expected_stage: int,
	cost: int,
	machine_id: StringName,
	next_phase: Phase
) -> bool:
	var game: Dictionary = snapshot["game"] as Dictionary
	if (
		GameState.get_money() != int(game["money"]) - cost
		or GameState.get_total_money_earned() != int(game["earned"])
		or GameState.get_total_processed_items() != int(game["items"])
		or not is_equal_approx(GameState.get_total_playtime(), float(game["playtime"]))
		or CommissioningManager.get_stage() != expected_stage
		or _phase != next_phase
	):
		return false
	var runtime: MachineRuntime = SimulationManager.get_production_line().get_stage(machine_id)
	if runtime == null or not runtime.is_enabled():
		return false
	var simulation: Dictionary = snapshot["simulation"] as Dictionary
	var expected_production: Dictionary = (simulation["production_save"] as Dictionary).duplicate(true)
	var machines: Dictionary = expected_production["machines"] as Dictionary
	var machine_state: Dictionary = machines[String(machine_id)] as Dictionary
	machine_state["enabled"] = true
	return (
		SimulationManager.get_production_save_data() == expected_production
		and is_zero_approx(SimulationManager.get_pending_simulation_seconds())
		and is_equal_approx(SimulationManager.get_tick_interval(), float(simulation["tick_interval"]))
	)


func _restore_commission_snapshot(snapshot: Dictionary) -> bool:
	var simulation_ok := SimulationManager.restore_transaction_snapshot(snapshot["simulation"])
	var commissioning_ok := CommissioningManager.restore_commissioning_save_data(snapshot["commissioning"])
	var game: Dictionary = snapshot["game"] as Dictionary
	var game_ok := GameState.restore_state(
		int(game["money"]), int(game["earned"]), int(game["items"]), float(game["playtime"])
	)
	_phase = int(snapshot["phase"]) as Phase
	return (
		simulation_ok
		and commissioning_ok
		and game_ok
		and SimulationManager.get_transaction_snapshot() == snapshot["simulation"]
		and CommissioningManager.get_commissioning_save_data() == snapshot["commissioning"]
		and GameState.get_money() == int(game["money"])
		and GameState.get_total_money_earned() == int(game["earned"])
		and GameState.get_total_processed_items() == int(game["items"])
		and is_equal_approx(GameState.get_total_playtime(), float(game["playtime"]))
		and _phase == int(snapshot["phase"])
	)


func _on_active_case_changed() -> void:
	if _mutating or not _session_initialized or _phase == Phase.COMPLETE:
		return
	var progress := CaseManager.get_active_case()
	if progress == null:
		return
	if progress.get_case_id() not in _case_ids_for_phase(_phase):
		return
	# CaseManager publishes a committed snapshot while rejecting reentrant
	# lifecycle mutations. Defer assistance until that publication is complete.
	call_deferred("_apply_case_assistance", progress.get_case_id())


func _apply_case_assistance(case_id: StringName) -> void:
	if _mutating or not _session_initialized:
		return
	var progress := CaseManager.get_active_case()
	if progress == null or progress.get_case_id() != case_id:
		return
	if case_id not in _case_ids_for_phase(_phase):
		return
	if _phase in [Phase.SCANNER_CASES, Phase.SORTER_CASES] and progress.get_state() == CaseProgress.State.ACTIVE:
		if not CaseManager.mark_active_case_inspected():
			return
		progress = CaseManager.get_active_case()
	if _phase == Phase.SORTER_CASES and progress != null and progress.get_state() == CaseProgress.State.INSPECTED:
		var definition := CaseManager.get_case_definition(case_id)
		if definition != null:
			CaseManager.classify_active_case(definition.expected_category_id)


func _on_case_progress_changed(case_id: StringName) -> void:
	if _mutating or not _session_initialized or _phase == Phase.COMPLETE:
		return
	var progress := CaseManager.get_case_progress(case_id)
	if progress == null or progress.get_state() != CaseProgress.State.ARCHIVED:
		return
	if case_id not in FIRST_SHIFT_CASE_IDS or _claimed_reward_case_ids.has(case_id):
		return
	var reward := CASE_BASE_REWARD
	if CaseManager.is_case_classification_correct(case_id):
		reward += CASE_ACCURACY_BONUS
	var game_before := {
		"money": GameState.get_money(),
		"earned": GameState.get_total_money_earned(),
		"items": GameState.get_total_processed_items(),
		"playtime": GameState.get_total_playtime(),
	}
	var phase_before := _phase
	var claims_before := _claimed_reward_case_ids.duplicate()
	_mutating = true
	# Reserve before Economy emits money_changed, so no observer can see money
	# credited without the corresponding idempotency claim.
	_claimed_reward_case_ids.append(case_id)
	var success := Economy.add_money(reward)
	var phase_changed := false
	if success:
		phase_changed = _update_progression_gate()
		success = (
			GameState.get_money() == int(game_before["money"]) + reward
			and GameState.get_total_money_earned() == int(game_before["earned"]) + reward
			and GameState.get_total_processed_items() == int(game_before["items"])
			and is_equal_approx(GameState.get_total_playtime(), float(game_before["playtime"]))
			and _claimed_reward_case_ids.count(case_id) == 1
		)
	if not success:
		_claimed_reward_case_ids = claims_before
		_phase = phase_before
		var restored := GameState.restore_state(
			int(game_before["money"]),
			int(game_before["earned"]),
			int(game_before["items"]),
			float(game_before["playtime"])
		)
		_mutating = false
		if (
			not restored
			or _claimed_reward_case_ids != claims_before
			or _phase != phase_before
			or GameState.get_money() != int(game_before["money"])
			or GameState.get_total_money_earned() != int(game_before["earned"])
		):
			push_error("First Shift reward rollback failed to restore the exact pre-call state.")
		return
	_mutating = false
	case_reward_granted.emit(case_id, reward)
	if phase_changed:
		first_shift_state_changed.emit(_phase)


func _update_progression_gate() -> bool:
	var next_phase := _phase
	if _phase == Phase.MANUAL_CASES and _all_archived(MANUAL_CASE_IDS):
		next_phase = Phase.SCANNER_READY
	elif _phase == Phase.SCANNER_CASES and _all_archived(SCANNER_CASE_IDS):
		next_phase = Phase.SORTER_READY
	elif _phase == Phase.SORTER_CASES and _all_archived(SORTER_CASE_IDS):
		next_phase = Phase.INTAKE_READY
	if next_phase != _phase:
		_phase = next_phase
		return true
	return false


func _all_archived(case_ids: Array[StringName]) -> bool:
	for case_id: StringName in case_ids:
		var progress := CaseManager.get_case_progress(case_id)
		if progress == null or progress.get_state() != CaseProgress.State.ARCHIVED:
			return false
	return true


func _case_ids_for_phase(phase: Phase) -> Array[StringName]:
	match phase:
		Phase.MANUAL_CASES:
			return MANUAL_CASE_IDS
		Phase.SCANNER_CASES:
			return SCANNER_CASE_IDS
		Phase.SORTER_CASES:
			return SORTER_CASE_IDS
		_:
			return []


func _claim_count_matches_phase(count: int, phase: int) -> bool:
	match phase:
		Phase.MANUAL_CASES:
			return count >= 0 and count <= 5
		Phase.SCANNER_READY:
			return count == 6
		Phase.SCANNER_CASES:
			return count >= 6 and count <= 9
		Phase.SORTER_READY:
			return count == 10
		Phase.SORTER_CASES:
			return count >= 10 and count <= 13
		Phase.INTAKE_READY:
			return count == 14
		Phase.COMPLETE:
			# Empty is the explicit legacy-migration marker; fourteen is a
			# completed native First Shift. Partial completed claims are invalid.
			return count in [0, 14]
		_:
			return false
