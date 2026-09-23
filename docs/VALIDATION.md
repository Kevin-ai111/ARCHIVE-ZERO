# Production Pipeline Validation

## Automated domain test

From the repository root, run:

```bash
godot --headless --path . tests/production_pipeline_test.tscn
```

The command must exit with code `0` and print `Production pipeline tests passed.`
It validates initial throughput and utilization, dynamic bottlenecks, disabled
stages, 100-second output, fractional continuity, runtime-state restoration,
Scanner upgrade purchase rules, save/load, and legacy save migration.

## Manual runtime check

1. Open `project.godot` in Godot 4.7.x and run the project.
2. Confirm the initial line reports `0.75 items/sec`, `1.50 credits/sec`, and
   `Basic Sorter` as the bottleneck.
3. Confirm utilization is 60%, 75%, 100%, and 37.5% in stage order.
4. Select `Sorter x2`. Throughput must become `1.00 items/sec` and the Basic
   Scanner must become the bottleneck.
5. Add 50 Credits and buy Scanner Motor I. Scanner capacity must increase from
   `1.00/s` to `1.25/s`; a second purchase must not spend more Credits.
6. Turn the Basic Scanner off. Throughput and credits per second must become 0.
   Turn it on again and confirm production resumes.
7. Turn one stage off, set the Sorter to x2, and save. Change both settings,
   then load. The saved enabled state and multiplier must return.
8. Leave the line running and confirm money and processed-item totals increase
   while no visual item Nodes are created.
