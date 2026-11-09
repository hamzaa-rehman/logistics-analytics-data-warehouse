# Investigation: `delivery_events.on_time_flag`

## 1. Objective

Determine how the source `on_time_flag` relates to the scheduled and actual event timestamps in the Bronze layer.

The investigation compares the stored flag with the signed difference between `actual_datetime` and `scheduled_datetime`.

## 2. Source columns

| Table | Column | Purpose |
|---|---|---|
| `delivery_events` | `event_id` | Event identifier |
| `delivery_events` | `event_type` | Pickup or delivery event |
| `delivery_events` | `scheduled_datetime` | Scheduled event timestamp |
| `delivery_events` | `actual_datetime` | Actual event timestamp |
| `delivery_events` | `on_time_flag` | Source on-time indicator |

Bronze stores source fields as `VARCHAR`. Timestamp values were temporarily converted with `TRY_CONVERT(DATETIME2(6), ...)` for this investigation; the Bronze source values were not modified.

## 3. Investigation approach

The investigation proceeded in stages:

1. Checked whether scheduled timestamps, actual timestamps, and source flags could be interpreted.
2. Compared the source flag with a strict rule in which an event is on time only when its actual timestamp is on or before its scheduled timestamp.
3. Separated mismatches into events marked True but occurring late, and events marked False but occurring early or on schedule.
4. Measured the signed time differences and reviewed their distribution.
5. Inspected the six apparent exceptions near the 120-minute boundary.
6. Tested a candidate tolerance rule against every event using microsecond precision.

The signed difference is:

`actual_datetime - scheduled_datetime`

- Negative difference: actual event occurred before schedule (early).
- Zero: actual event occurred exactly on schedule.
- Positive difference: actual event occurred after schedule (late).

## 4. Findings

### 4.1 Timestamp and flag validity

| Check | Result |
|---|---:|
| Total events | 170,820 |
| Invalid scheduled timestamps | 0 |
| Invalid actual timestamps | 0 |
| Invalid or NULL source flags | 0 |

### 4.2 Strict schedule comparison

The simple rule `actual_datetime <= scheduled_datetime` did not explain the source flag.

| Metric | Result |
|---|---:|
| Events | 170,820 |
| Actual on or before schedule | 56,993 |
| Source flag True | 95,095 |
| Mismatches against strict comparison | 56,866 |

The mismatch directions were:

| Mismatch type | Events |
|---|---:|
| Source flag True, actual event after schedule | 47,484 |
| Source flag False, actual event on or before schedule | 9,382 |
| **Total** | **56,866** |

### 4.3 Time-difference patterns

For events marked True but occurring after schedule:

| Metric | Result |
|---|---:|
| Events | 47,484 |
| Minimum lateness | 0 minutes |
| Maximum lateness | 120 minutes |
| Average lateness | 59.844984 minutes |

For events marked False but occurring before or on schedule, the early-time calculation used the reverse timestamp order (`scheduled_datetime - actual_datetime`):

| Metric | Result |
|---|---:|
| Events | 9,382 |
| Minimum earliness | 120 minutes |
| Maximum earliness | 180 minutes |
| Average earliness | 150.138641 minutes |

A signed time-difference breakdown showed that events within approximately 120 minutes before or after schedule were overwhelmingly marked True, while events more than 120 minutes early or late were marked False.

### 4.4 Boundary exceptions

Six records initially appeared to be exceptions when differences were displayed in whole-minute precision. Inspection at timestamp precision showed that these records were fractionally outside the 120-minute boundary:

| Event ID | Event type | Signed difference (minutes, approximately) | Source flag |
|---|---|---:|---|
| EVT00009212 | Delivery | +120.002769 | False |
| EVT00058241 | Pickup | +120.012394 | False |
| EVT00068233 | Pickup | +120.013702 | False |
| EVT00137856 | Delivery | -120.000741 | False |
| EVT00146935 | Pickup | +120.005228 | False |
| EVT00163154 | Delivery | -120.007790 | False |

These examples demonstrate why the final boundary check must use timestamp precision rather than a rounded whole-minute value.

## 5. Final validation

The candidate rule was tested against all 170,820 records using `DATEDIFF_BIG(MICROSECOND, ...)`.

The candidate rule is:

- True when the actual event timestamp is within 120 minutes before or after the scheduled timestamp, inclusive.
- False when the actual event timestamp is more than 120 minutes before or after the scheduled timestamp.

The inclusive threshold is 7,200,000,000 microseconds in either direction.

| Validation metric | Result |
|---|---:|
| Total events | 170,820 |
| Matching rows | 170,820 |
| Mismatching rows | 0 |
| Match rate | 100% |

**Conclusion:** All 170,820 source flags matched the candidate ±120-minute tolerance rule at microsecond precision.

## 6. Interpretation and limitations

The source `on_time_flag` does not represent strict punctuality relative to the scheduled timestamp. It represents whether the event timestamp falls within a two-hour tolerance window before or after the scheduled timestamp, based on the rule observed and validated in this dataset.

This is a data-derived definition. The investigation establishes the rule followed by the available records; it does not independently establish that the two-hour tolerance is an operationally approved logistics standard.

The flag should therefore be interpreted with its tolerance clearly documented. Do not describe it as arrival exactly on schedule. The source field is preserved in Bronze.

## 7. Silver-layer consideration

Preserve the original source flag and timestamp fields. If the Silver layer exposes a business-facing interpretation, document the ±120-minute tolerance explicitly and retain traceability to the Bronze source.

No transformation or renaming decision is made by this investigation alone.

## 8. Investigation status

**Status: Completed — dataset rule validated.**

The separate investigation of `delivery_events.detention_minutes` remains in progress. This report does not establish the business definition of detention or its relationship to the on-time flag.

## 9. Reproducibility

The investigation queries are available in:

[`scripts/bronze/investigations/investigate_on_time_flag.sql`](../../../scripts/bronze/investigations/investigate_on_time_flag.sql)

The script contains the diagnostic comparisons, mismatch breakdown, time-difference analysis, boundary inspection, and final full-record validation.

**Execution note:** The findings above reflect query results supplied from the project's SQL Server investigation. Adding the script to GitHub does not execute it. Re-run the script against the project database to reproduce the results in your environment.
