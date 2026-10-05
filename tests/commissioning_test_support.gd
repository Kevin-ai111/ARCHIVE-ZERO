extends RefCounted


static func authority_snapshot() -> Dictionary:
	var line: ProductionLine = SimulationManager.get_production_line()
	var flags := {}
	for stage: MachineRuntime in line.get_stages():
		flags[String(stage.get_id())] = stage.is_enabled()
	return {"money": GameState.get_money(), "earned": GameState.get_total_money_earned(), "items": GameState.get_total_processed_items(), "playtime": GameState.get_total_playtime(), "fraction": line.get_fractional_progress(), "pending": SimulationManager.get_pending_simulation_seconds(), "throughput": line.get_effective_throughput(), "upgrades": SimulationManager.get_owned_upgrade_ids(), "machine_flags": flags, "production_save": SimulationManager.get_production_save_data(), "case_save": CaseManager.get_case_save_data()}


static func prepare_isolation_fixture(disabled: bool = false) -> void:
	SimulationManager.restore_production_save_data(SimulationManager.get_default_production_save_data())
	GameState.restore_state(200, 300, 7, 12.0)
	SimulationManager.purchase_upgrade("sorter_motor_1")
	SimulationManager.simulate_elapsed(0.45)
	if disabled:
		SimulationManager.set_machine_enabled(&"archive_intake", false)
	SimulationManager._process(0.2)
	CaseManager.reset_cases()
	CaseManager.enqueue_cases([&"CASE_0001", &"CASE_0002"])
	CaseManager.activate_next_case()
	CaseManager.mark_active_case_inspected()
	CaseManager.classify_active_case(&"ELEC")


static func restore_stage(stage: int) -> bool:
	return CommissioningManager.restore_commissioning_save_data({"commissioning_save_version": 1, "stage": CommissioningManager.STAGE_LABELS[stage]})
