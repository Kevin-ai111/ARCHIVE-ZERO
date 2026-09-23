# Production Pipeline Validation

## Automated domain test

From the repository root, run:

```bash
godot --headless --path . --script tests/production_pipeline_test.gd
```

The command must exit with code `0` and print `Production pipeline tests passed.`
It validates initial throughput and utilization, dynamic bottlenecks, disabled
stages, 100-second output, fractional continuity, and runtime-state restoration.

## Manual runtime check

1. Open `project.godot` in Godot 4.7.x and run the project.
2. Confirm the initial line reports `0.75 items/sec`, `1.50 credits/sec`, and
   `Basic Sorter` as the bottleneck.
3. Confirm utilization is 60%, 75%, 100%, and 37.5% in stage order.
4. Select `Sorter x2`. Throughput must become `1.00 items/sec` and the Basic
   Scanner must become the bottleneck.
5. Turn the Basic Scanner off. Throughput and credits per second must become 0.
   Turn it on again and confirm production resumes.
6. Turn one stage off, set the Sorter to x2, and save. Change both settings,
   then load. The saved enabled state and multiplier must return.
7. Leave the line running and confirm money and processed-item totals increase
   while no visual item Nodes are created.
