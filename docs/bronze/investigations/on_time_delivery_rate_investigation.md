# Investigation: `driver_monthly_metrics` on-time delivery rate

## 1. Objective

Investigate the single zero value identified in `bronze.driver_monthly_metrics.on_time_delivery_rate` and determine whether it is supported by the underlying delivery-event records.

The investigation also validates the monthly source metric against delivery events across the complete set of 4,464 driver-month records.

## 2. Source tables and grain

### `bronze.driver_monthly_metrics`

The monthly source table contains one record per driver and reporting month. Relevant columns:

- `driver_id`
- `month`
- `trips_completed`
- `on_time_delivery_rate`

### `bronze.trips`

Relevant columns:

- `trip_id`
- `driver_id`
- `dispatch_date`

### `bronze.delivery_events`

Relevant columns:

- `trip_id`
- `event_type`
- `on_time_flag`

Bronze columns are stored as `VARCHAR`. The investigation used `TRY_CONVERT` to interpret dates and numeric values for analysis without changing the Bronze source data.

## 3. Initial profiling finding

Numeric profiling identified one zero value in `driver_monthly_metrics.on_time_delivery_rate`.

| Field | Value |
|---|---|
| `driver_id` | DRV00074 |
| `month` | 2024-09-01 |
| `trips_completed` | 10 |
| `on_time_delivery_rate` | 0.0 |

The driver had 10 completed trips in the monthly record. The zero could not be explained simply by an absence of trips, so the underlying delivery events were inspected.

## 4. Driver-level investigation

The driver's September 2024 trips were joined to `bronze.delivery_events` using `trip_id`. The results were grouped by event type and source on-time flag.

| Event type | Total events | False flags | True flags |
|---|---:|---:|---:|
| Delivery | 10 | 10 | 0 |
| Pickup | 10 | 3 | 7 |

All 10 Delivery events were marked `False`. Pickup events were not included in the on-time delivery rate calculation.

The resulting rate was:

**On-time delivery rate = On-time Delivery events / Total Delivery events**

**For DRV00074 (September 2024):**

On-time delivery rate = 0 / 10 = 0.000 (0%)

This agrees with the stored monthly value of zero.

## 5. Full-dataset validation

### 5.1 Calculation and month assignment

The monthly rate was independently recalculated from the event-level records:

**On-time delivery rate = Delivery events with `on_time_flag = True` / All Delivery events**

The validation process:

1. Joined `bronze.trips` to `bronze.delivery_events` using `trip_id`.
2. Included only rows where `event_type = 'Delivery'`.
3. Assigned each event to the month derived from the trip's `dispatch_date`.
4. Grouped by `driver_id` and dispatch month.
5. Counted total Delivery events and events marked `True`.
6. Calculated the rate and compared it with the stored monthly metric.

The source metric's month was also converted directly from its complete date value (for example, `2024-09-01`) for the comparison.

A `LEFT JOIN` from the monthly source table to the calculated results retained every source monthly record. This allowed the validation to identify monthly records without matching delivery-event data rather than silently excluding them.

### 5.2 Standard rounding comparison

The first complete comparison used SQL Server `ROUND(CalculatedRate, 3)` and compared the result with the source value.

| Validation status | Records | Percentage |
|---|---:|---:|
| Match after rounding to three decimal places | 4,383 | 98.19% |
| Mismatch after rounding | 81 | 1.81% |
| Records without matching Delivery events | 0 | 0.00% |
| **Total monthly records** | **4,464** | **100%** |

The 81 mismatches were then inspected individually. The supplied mismatch output showed repeated precision-boundary examples, including:

| Total deliveries | On-time deliveries | Calculated rate | SQL Server rounded rate | Source rate |
|---:|---:|---:|---:|---:|
| 16 | 5 | 0.3125 | 0.313 | 0.312 |
| 16 | 9 | 0.5625 | 0.563 | 0.562 |

### 5.3 Truncation comparison

A separate full-dataset test compared the source values with the calculated rate truncated to three decimal places.

This test was deliberately treated as a diagnostic comparison, not as an assumption about the source-generation rule.

| Validation status | Records |
|---|---:|
| Match after truncation across all monthly records | 2,741 |
| Mismatch after truncation across all monthly records | 1,723 |
| Records without matching Delivery events | 0 |
| **Total monthly records** | **4,464** |

Applying truncation as a universal rule therefore performed worse than standard rounding and did not reproduce the source metric across the complete dataset.

### 5.4 Classification of the 81 standard-rounding mismatches

The 81 records that failed the standard-rounding comparison were isolated. Each was then checked against the truncated rate.

| Difference classification | Records |
|---|---:|
| Matched after truncation | 81 |
| Other differences | 0 |
| **Total standard-rounding mismatches classified** | **81** |

The observed results show that the 81 exceptions are reproduced by truncating the calculated values to three decimal places. The examples inspected include exact halfway values such as 0.3125 and 0.5625.

This does **not** prove that the source-generation process universally uses truncation. The original source code and documented precision rule were not available. A specific rounding implementation cannot be inferred conclusively from the observed output alone.

## 6. Findings

1. The zero value for DRV00074 in September 2024 is supported by the underlying event records: the driver had 10 Delivery events and none were marked on time.
2. Pickup events were excluded from the delivery-rate calculation.
3. All 4,464 monthly source records had corresponding Delivery-event summaries when grouped by driver and the month derived from `trips.dispatch_date`.
4. Standard rounding to three decimal places reproduced 4,383 source values.
5. The remaining 81 values matched the truncated calculated rate; no other differences remained.
6. Truncation applied to the entire dataset was not a suitable universal comparison rule: it matched 2,741 records and differed from 1,723.
7. The precise source-generation precision convention remains unverified.

## 7. Silver-layer considerations

The investigation supports the following considerations for future Silver-layer design:

- Preserve `on_time_delivery_rate` as a numeric decimal value.
- Preserve the observed zero as zero; do not convert it to `NULL` or impute a replacement value.
- Retain the original Bronze source value for traceability.
- Document the calculation basis and the observed three-decimal precision behavior.
- Do not impose a universal truncation rule or claim a specific rounding implementation until the source-generation convention is confirmed.

These are recommendations for future implementation. No Silver transformation is performed by this investigation.

## 8. Limitations

- The original code or business documentation that generates `on_time_delivery_rate` was not available.
- The results establish that the source values reconcile with the tested event-based calculation and the observed precision comparisons. They do not establish the exact rounding implementation used by the source system.
- The reconciliation checks consistency with the available delivery-event records. It does not independently establish that every real-world delivery event was captured.
- The month assignment was tested using `trips.dispatch_date`; this is the month basis that reproduced the complete set of monthly source records.

## 9. Reproducibility and related files

**Investigation SQL:**  
[`investigate_on_time_delivery_rate.sql`](../../../scripts/bronze/investigations/investigate_on_time_delivery_rate.sql)

**Numeric profiling record:**  
[`driver_monthly_metrics.on_time_delivery_rate`](../numeric_profiling.md#55-zero-on-time-delivery-rate)

**Execution note:** The query logic was executed by the project author in SQL Server, and the outputs were supplied and reviewed during the investigation. The consolidated GitHub script has not been independently re-executed end-to-end after formatting. Re-run it against the project database to reproduce the results in your environment.

## 10. Conclusion

The single zero value in `driver_monthly_metrics.on_time_delivery_rate` is supported by the underlying delivery-event records. The driver had 10 Delivery events in September 2024, with none marked on time.

The complete validation covered all 4,464 monthly records. Standard rounding matched 4,383 records; the remaining 81 matched the truncated calculated rate, with no other differences or unmatched monthly records.

The metric is internally consistent with the tested event-based calculation. The exact source precision-handling convention remains unverified and should not be assumed during Silver-layer implementation.

**Investigation status: Completed.**
