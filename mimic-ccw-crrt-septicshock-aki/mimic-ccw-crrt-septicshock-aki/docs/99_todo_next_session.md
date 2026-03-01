# TODO (next session)

1) Verify derived table availability:
   - urine_output table name
   - complete_blood_count table name (if missing, implement CBC via labevents + itemid mapping)

2) Implement analysis-ready merged dataset:
   - join cohort_baseline_v1 + ccw_clone_long_0_24h_1h_v2 + outcomes_28d_renal_v1
   - export to csv for R modeling

3) Add sensitivity analyses:
   - shock stricter proxy: add lactate > 2 at baseline
   - baseline Scr proxy window: [t0-7d, t0]
   - grace period sensitivity: 12h vs 24h

4) Produce Figure: flowchart numbers via attrition_counts_v1