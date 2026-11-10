# Investigation: `delivery_events.detention_minutes`

## 1. Objective

Investigate the source `detention_minutes` values, compare Pickup and Delivery events, and examine whether detention varies with schedule deviation.

The investigation is descriptive. It does not assume that the source field follows a particular industry definition of detention.

## 2. Source and initial profiling

**Source:** `bronze.delivery_events.detention_minutes`  
**Source table grain:** one delivery event record per row.

| Metric | Result |
|---|---:|
| Total events | 170,820 |
| NULL values | 0 |
| Invalid numeric values | 0 |
| Minimum numeric value | 0 |
| Maximum numeric value | 239 |
| Average | 91.537460 |
| Zero values | 22,472 (13.15%) |
| Positive values | 148,348 (86.85%) |

All 170,820 values were successfully converted during numeric profiling using `TRY_CONVERT(DECIMAL(18,4), ...)`.

**Data-type consideration:** Bronze stores this column as `VARCHAR`. Aggregates such as `MIN()` and `MAX()` applied directly to the text column use text ordering, not numeric ordering. Numeric extrema and calculations must use a numeric conversion. This explains why the original grouped exploratory queries can show a text-based maximum that differs from the numeric maximum of 239.

## 3. Initial distribution analysis

### 3.1 Event type

| Event type | Events | Average detention (minutes) |
|---|---:|---:|
| Delivery | 85,410 | 106.602201 |
| Pickup | 85,410 | 76.472719 |

Delivery events had a higher average detention value than Pickup events in this dataset.

### 3.2 Facility

Detention was also summarized by facility and event type. All 50 facilities had both zero and positive detention observations. Average detention varied across facilities; this analysis did not establish the operational reasons for those differences.

### 3.3 Zero and positive values by event type and on-time flag

| Event type | `on_time_flag` | Events | Zero detention | Positive detention | Average (minutes) |
|---|---|---:|---:|---:|---:|
| Delivery | False | 47,308 | 5,327 | 41,981 | 106.889151 |
| Delivery | True | 38,102 | 4,368 | 33,734 | 106.245918 |
| Pickup | False | 28,417 | 4,268 | 24,149 | 76.295069 |
| Pickup | True | 56,993 | 8,509 | 48,484 | 76.561297 |

Within each event type, average detention was similar for records with True and False source flags. This is a descriptive comparison, not a statistical test.

The source `on_time_flag` was separately investigated and matched an inclusive ±120-minute tolerance around the scheduled timestamp for all 170,820 records. Therefore, True does not mean that an event occurred exactly at its scheduled time. See [On-Time Flag Investigation](on_time_flag_investigation.md).

## 4. Schedule-deviation analysis

### 4.1 Method

The signed schedule deviation was calculated as:

`actual_datetime - scheduled_datetime`

- Negative: actual event occurred early.
- Zero: actual event occurred exactly on schedule.
- Positive: actual event occurred late.

Because Bronze stores timestamps and detention values as `VARCHAR`, the investigation used `TRY_CONVERT` to convert them for calculations without modifying Bronze.

Schedule deviation was calculated using:

`DATEDIFF_BIG(SECOND, scheduled_datetime, actual_datetime) / 60.0`

This produces minute values with **one-second resolution**; it is not microsecond-precision. The schedule bands were:

1. More than 120 minutes early
2. 61–120 minutes early
3. 1–60 minutes early
4. Exactly on schedule
5. 1–60 minutes late
6. 61–120 minutes late
7. More than 120 minutes late

The results were grouped separately by event type. Average detention, median detention, event counts, and zero/positive counts were calculated for each populated group.

### 4.2 Average and median detention by schedule band

| Event type | Schedule-deviation band | Events | Average (minutes) | Median (minutes) |
|---|---|---:|---:|---:|
| Delivery | More than 120 min early | 9,380 | 106.737420 | 105.5 |
| Delivery | 61–120 min early | 9,472 | 106.761190 | 106 |
| Delivery | 1–60 min early | 9,568 | 106.194920 | 104 |
| Delivery | Exactly on schedule | 5 | 111.800000 | 75 |
| Delivery | 1–60 min late | 9,598 | 104.952281 | 102 |
| Delivery | 61–120 min late | 9,462 | 107.084654 | 106 |
| Delivery | More than 120 min late | 37,925 | 106.928305 | 106 |
| Pickup | 61–120 min early | 14,243 | 77.138945 | 75 |
| Pickup | 1–60 min early | 14,328 | 76.829075 | 75 |
| Pickup | Exactly on schedule | 3 | 7.666666 | 0 |
| Pickup | 1–60 min late | 14,307 | 76.039141 | 73 |
| Pickup | 61–120 min late | 14,115 | 76.253630 | 74 |
| Pickup | More than 120 min late | 28,414 | 76.293482 | 73 |

The exactly-on-schedule groups contain only five Delivery events and three Pickup events. Their averages and medians are highly sensitive to individual records and should not be compared with the much larger groups.

### 4.3 Zero and positive detention by schedule band

The zero/positive breakdown showed:

- Delivery zero-detention proportions were approximately 11.2%–11.8% across populated schedule bands.
- Pickup zero-detention proportions were approximately 14.4%–15.4% across populated schedule bands.
- The exactly-on-schedule groups were too small for meaningful generalization.

The counts reconciled within every group: total events equalled zero-detention events plus positive-detention events.

### 4.4 Interpretation

Across the populated schedule bands:

- Delivery average detention was generally around 105–107 minutes, with medians around 102–106 minutes.
- Pickup average detention was generally around 76–77 minutes, with medians around 73–75 minutes.
- Zero-detention proportions were relatively consistent across the populated bands.
- Delivery detention was consistently higher than Pickup detention.

The descriptive results do not show a strong observable association between schedule deviation and detention duration within either event type. They do not establish statistical independence, statistical significance, or causation.

## 5. Key findings

1. All 170,820 source values were non-NULL and convertible to the numeric profiling type.
2. 22,472 events (13.15%) had zero detention; 148,348 (86.85%) had positive detention.
3. Delivery events had a higher average detention value than Pickup events.
4. Average and median detention were relatively stable across populated schedule-deviation bands within each event type.
5. Zero-detention proportions were also relatively stable across those bands.
6. No strong observable association between schedule deviation and detention was identified in this descriptive analysis.
7. The precise business definition of `detention_minutes` remains unverified.

## 6. Limitations and unresolved business definition

In freight operations, detention commonly refers to time a driver or vehicle is held at a facility beyond an allowed free period. It should not automatically be interpreted as the total loading or unloading duration.

The source data and investigation do not establish whether this particular field represents:

- Total waiting time at a facility.
- Time beyond an allowed free period.
- Another dataset-specific operational measure.

No verified source documentation or business rule was available to resolve this question. The report therefore describes the values and observed patterns without assigning an unverified operational meaning.

The analysis is descriptive; no formal statistical significance test, causal analysis, or adjustment for other operational factors was performed.

## 7. Silver-layer considerations

Until the source definition is confirmed:

- Preserve the original values in Bronze.
- Convert the field to an appropriate numeric type in Silver after validation.
- Preserve zero as a valid observed value; do not convert it to NULL or treat it as missing by default.
- Do not label the field as total loading time, total waiting time, or detention beyond free time without supporting business documentation.
- Document any later business interpretation and transformation rule with its source.

This investigation does not identify a reason to remove or alter valid source values.

## 8. Reproducibility and related files

**Investigation SQL:**  
`scripts/bronze/investigations/investigate_detention_minutes.sql`

**Related investigation:**  
[On-Time Flag Investigation](on_time_flag_investigation.md)

**Profiling record:**  
The `delivery_events.detention_minutes` entry in the project's Data Profiling workbook.

**Execution note:** The investigation queries were executed by the project author in SQL Server, and the resulting outputs were supplied and reviewed during the investigation. The organized GitHub script has not yet been independently re-executed as one complete file from top to bottom. Re-run it against the project database to verify the committed file end-to-end.

## 9. Conclusion

The dataset shows consistently higher detention values for Delivery than Pickup events, while average and median detention remain relatively stable across schedule-deviation bands within each event type. The descriptive analysis did not identify a strong observable association between schedule deviation and detention.

The field's exact operational definition remains unresolved. It should be retained and typed in Silver without imposing an unsupported business interpretation.
