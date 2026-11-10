# Investigation: `truck_utilization_metrics.maintenance_events`, `truck_utilization_metrics.maintenance_cost`, and `truck_utilization_metrics.downtime_hours`

## 1. Objective

Investigate the zero values in the following columns of `bronze.truck_utilization_metrics`:

- `maintenance_events`
- `maintenance_cost`
- `downtime_hours`

The objective was to determine whether the zero values are consistent with the detailed maintenance records in `bronze.maintenance_records`, using truck and calendar month as the comparison grain.

## 2. Initial profiling results

Each of the three columns contained 1,684 zero values across 3,312 truck-month records.

| Metric | Zero values | Total records |
|---|---:|---:|
| `maintenance_events` | 1,684 | 3,312 |
| `maintenance_cost` | 1,684 | 3,312 |
| `downtime_hours` | 1,684 | 3,312 |

A combination analysis showed only two patterns:

| Maintenance events | Maintenance cost | Downtime hours | Records |
|---|---|---|---:|
| Zero | Zero | Zero | 1,684 |
| Positive | Positive | Positive | 1,628 |

No mixed zero/non-zero combinations were observed.

## 3. Distribution across months and trucks

The utilization metrics cover 36 months from January 2022 through December 2024, with 92 truck-month records per month.

All 36 months contained both zero-maintenance and positive-maintenance records. The monthly zero-maintenance share ranged from 40.22% to 60.87%; no month consisted entirely, or almost entirely, of zero-maintenance records.

The truck-level review covered 92 trucks, each with 36 monthly records. Every truck had both zero-maintenance and positive-maintenance months. The zero-maintenance share ranged from 27.78% to 75.00%. No truck had zero maintenance across all 36 months.

These distributions show that the zero pattern recurs across the reporting period and fleet rather than being confined to a single month or a group of trucks.

## 4. Detailed maintenance records

The detailed `bronze.maintenance_records` table was examined as the source for the monthly summary comparison.

Validation results:

| Check | Result |
|---|---:|
| Detailed maintenance records | 2,920 |
| Invalid maintenance dates | 0 |
| Invalid total costs | 0 |
| Invalid downtime values | 0 |
| Missing truck IDs | 0 |
| Distinct trucks with maintenance records | 120 |
| Truck-month combinations with maintenance records | 2,129 |
| Maintenance records in a truck-month | 1 to 4 |

The maintenance dates cover January 2022 through December 2024 (36 distinct months). All 92 trucks appearing in `truck_utilization_metrics` were also present in `maintenance_records`. The detailed table additionally contains maintenance records for trucks outside the 92-truck utilization-metrics population.

## 5. Reconciliation methodology

Detailed maintenance records were aggregated by:

- `truck_id`
- Calendar year of `maintenance_date`
- Calendar month of `maintenance_date`

For each truck-month, the investigation calculated:

- The number of detailed maintenance records.
- The sum of `total_cost`.
- The sum of `downtime_hours`.

These values were compared with `maintenance_events`, `maintenance_cost`, and `downtime_hours` in `truck_utilization_metrics`.

**Date handling:** The `truck_utilization_metrics.month` values are already complete date strings, such as `2022-01-01`. They were converted directly using `TRY_CONVERT(DATE, month)`. Appending `'-01'` would produce an invalid value such as `2022-01-01-01` and prevent the month join from matching.

## 6. Reconciliation results

The corrected truck-month reconciliation produced the following event-count classification:

| Reconciliation status | Truck-month records |
|---|---:|
| Both show zero | 1,684 |
| Event counts match | 1,628 |
| **Total** | **3,312** |

The full metric comparison returned:

| Validation | Matching truck-months | Total truck-months |
|---|---:|---:|
| Maintenance event counts | 3,312 | 3,312 |
| Maintenance costs | 3,312 | 3,312 |
| Downtime hours | 3,312 | 3,312 |
| All three metrics simultaneously | 3,312 | 3,312 |

All three monthly summary metrics reconciled exactly with the detailed maintenance records for all 3,312 truck-months.

## 7. Findings and conclusion

- All 1,684 truck-months with zero maintenance events also had zero maintenance cost and zero downtime hours.
- No corresponding detailed maintenance records were found for those truck-months.
- The remaining 1,628 truck-months had positive maintenance metrics that matched the detailed records.
- Event counts, maintenance costs, and downtime hours reconciled across all 3,312 truck-months.

**Conclusion:** The zero values are internally consistent with the detailed maintenance records. No discrepancy was identified between the three monthly summary metrics and the detailed maintenance records at truck-month grain.

This is a cross-table consistency finding, not independent proof that every real-world maintenance activity was captured by the source system.

## 8. Silver-layer considerations

Based on the evidence available in this dataset:

- Preserve these zero values as zero.
- Do not convert them to NULL.
- Do not impute replacement values.
- Retain the three monthly maintenance metrics, which reconcile with the detailed maintenance records.

These are recommendations for the later Silver implementation; no Silver transformation has been performed as part of this investigation.

## 9. Reproducibility and execution note

The investigation queries were executed by the author in SQL Server, and the resulting outputs were supplied for review. The consolidated GitHub script organizes the investigation queries into a reproducible sequence but has not been independently re-executed end-to-end after consolidation.

See [investigate_truck_utilization_maintenance.sql](../../../scripts/bronze/investigations/investigate_truck_utilization_maintenance.sql) for the SQL queries.
