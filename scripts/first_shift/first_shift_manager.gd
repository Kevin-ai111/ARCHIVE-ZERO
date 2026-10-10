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
		return CommissionResult.WRONG_PHASE
	if _phase > expected_phase or CommissioningManager.get_stage() > expected_stage:
		return CommissionResult.ALREADY_COMMISSIONED
	if _phase != expected_phase or CommissioningManager.get_stage() != expected_stage:
		return CommissionResult.WRONG_PHASE
	if not Economy.can_afford(cost):
		return CommissionResult.INSUFFICIENT_FUNDS
	_mutating = true
	var success := Economy.spend_money(cost)
	if success:
		success = bool(advance.call())
	if success:
		success = SimulationManager.set_machine_enabled(machine_id, true)
	if success:
		_phase = next_phase
	_mutating = false
	if not success:
		push_error("Validated First Shift commissioning transaction failed.")
		return CommissionResult.WRONG_PHASE
	first_shift_state_changed.emit(_phase)
	return CommissionResult.SUCCESS


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
	if not Economy.add_money(reward):
		push_error("First Shift Case reward could not be committed.")
		return
	_claimed_reward_case_ids.append(case_id)
	case_reward_granted.emit(case_id, reward)
	_update_progression_gate()


func _update_progression_gate() -> void:
	var next_phase := _phase
	if _phase == Phase.MANUAL_CASES and _all_archived(MANUAL_CASE_IDS):
		next_phase = Phase.SCANNER_READY
	elif _phase == Phase.SCANNER_CASES and _all_archived(SCANNER_CASE_IDS):
		next_phase = Phase.SORTER_READY
	elif _phase == Phase.SORTER_CASES and _all_archived(SORTER_CASE_IDS):
		next_phase = Phase.INTAKE_READY
	if next_phase != _phase:
		_phase = next_phase
		first_shift_state_changed.emit(_phase)


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
