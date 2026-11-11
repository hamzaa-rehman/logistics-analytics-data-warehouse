# Bronze Layer – DATE and DATETIME Profiling

## 1. Overview

DATE and DATETIME profiling was performed on the Bronze layer of the Logistics Analytics Data Warehouse to assess the completeness, technical convertibility, temporal range, and potential date-related anomalies in source values before Silver-layer transformations.

The profiling covered **15 columns across 14 Bronze tables**:

- 11 columns classified as `DATE`.
- 4 columns classified as `DATETIME`.

All Bronze source columns are stored as `VARCHAR`. Profiling temporarily converted source values to SQL Server `DATE` or `DATETIME2` values for validation and analysis. The original Bronze values were not modified.

The objectives were to identify NULL and invalid values, establish minimum and maximum dates/timestamps, detect future values at execution time, and investigate unusual temporal patterns before making transformation decisions.

## 2. Profiling Methodology

### 2.1 Metadata-driven approach

The profiling configuration in `bronze.profiling_config` identifies each column's assigned profiling category. The DATE and DATETIME profiling queries used this configuration to generate a query for each relevant column.

The process:

1. Retrieves columns classified as `DATE` or `DATETIME`.
2. Generates a profiling SELECT statement for each configured column.
3. Combines the generated statements using `STRING_AGG()` and `UNION ALL`.
4. Uses `TRY_CONVERT()` to attempt conversion without terminating the complete profiling query when a value cannot be converted.
5. Executes the generated SQL using `sp_executesql`.
6. Returns consolidated results for all configured columns in the selected category.

This avoids writing and maintaining a separate profiling query for every column.

### 2.2 DATE conversion

DATE values were converted using:

```sql
TRY_CONVERT(DATE, column_name, 23)
```

Style `23` represents the source format `YYYY-MM-DD`. Sample values from all 11 configured DATE columns were inspected and were consistent with this format.

### 2.3 DATETIME conversion

DATETIME values were converted using:

```sql
TRY_CONVERT(DATETIME2, column_name)
```

The source values converted successfully to SQL Server `DATETIME2`. The default precision of `DATETIME2` is seven fractional-second digits. Source values containing six fractional-second digits retained those digits, with a trailing zero in the seventh position.

The SQL Server result grid initially displayed only three fractional digits. To verify the stored conversion precision, the converted values were formatted as text using style 121. This confirmed preservation of the six source fractional digits.

### 2.4 Metrics

| Metric | Description |
|---|---|
| Total Rows | Total records in the source table. |
| NULL Values | Records with a NULL in the profiled column. |
| Invalid Values | Non-NULL source values that could not be converted to the target DATE or DATETIME2 type. |
| Valid Values | Non-NULL source values successfully converted. |
| Minimum Value | Earliest successfully converted date or timestamp. |
| Maximum Value | Latest successfully converted date or timestamp. |
| Future Values | Successfully converted values later than the date/time when profiling was executed. |

Successful conversion establishes technical convertibility; it does not, by itself, prove that a value is correct according to business rules.

## 3. Overall Results

| Metric | DATE | DATETIME | Combined |
|---|---:|---:|---:|
| Columns profiled | 11 | 4 | 15 |
| Column-value observations | 549,706 | 538,252 | 1,087,958 |
| NULL values | 124 | 0 | 124 |
| Valid values | 549,582 | 538,252 | 1,087,834 |
| Invalid values | 0 | 0 | 0 |
| Future values | 0 | 0 | 0 |

The 1,087,958 observations represent the sum of row counts across the 15 profiled columns. They are column-value observations, not unique records.

Key results:

- All 15 columns were successfully profiled.
- No invalid DATE or DATETIME conversions were detected.
- All 538,252 DATETIME observations were non-NULL and successfully converted.
- The only DATE NULL values were 124 values in `drivers.termination_date`.
- No future dates or timestamps were detected at the time of profiling.

## 4. DATE Profiling Results

All 11 configured DATE columns were profiled using `TRY_CONVERT(DATE, ..., 23)`.

| Table | Column | Total Rows | NULL | Invalid | Valid | Minimum Date | Maximum Date |
|---|---|---:|---:|---:|---:|---|---|
| customers | contract_start_date | 200 | 0 | 0 | 200 | 2020-01-07 | 2022-01-01 |
| driver_monthly_metrics | month | 4,464 | 0 | 0 | 4,464 | 2022-01-01 | 2024-12-01 |
| drivers | date_of_birth | 150 | 0 | 0 | 150 | 1960-05-24 | 1995-07-03 |
| drivers | hire_date | 150 | 0 | 0 | 150 | 2012-01-28 | 2021-12-06 |
| drivers | termination_date | 150 | 124 | 0 | 26 | 2013-01-08 | 2022-05-05 |
| loads | load_date | 85,410 | 0 | 0 | 85,410 | 2022-01-01 | 2024-12-31 |
| maintenance_records | maintenance_date | 2,920 | 0 | 0 | 2,920 | 2022-01-01 | 2024-12-31 |
| trailers | acquisition_date | 180 | 0 | 0 | 180 | 2015-01-06 | 2021-12-16 |
| trips | dispatch_date | 85,410 | 0 | 0 | 85,410 | 2022-01-01 | 2024-12-31 |
| truck_utilization_metrics | month | 3,312 | 0 | 0 | 3,312 | 2022-01-01 | 2024-12-01 |
| trucks | acquisition_date | 120 | 0 | 0 | 120 | 2015-01-27 | 2021-10-08 |

### 4.1 DATE findings

- All 11 columns converted successfully.
- No invalid date values were detected.
- No future dates were detected.
- The only NULL values occurred in `drivers.termination_date`.

#### Missing termination dates

`drivers.termination_date` contains 124 NULL values among 150 driver records; the remaining 26 records contain valid dates.

These NULLs may represent drivers without recorded termination dates, but active employment status has not been independently verified.

The NULLs should not automatically be treated as errors or replaced with assumed dates. Any Silver-layer treatment should preserve the missingness unless a supported business rule establishes otherwise.

#### Monthly date fields

`driver_monthly_metrics.month` and `truck_utilization_metrics.month` contain monthly reporting periods represented as DATE values. Both range from January 2022 through December 2024 and use the first day of each month.

This is consistent with representing a monthly period as a DATE rather than a timestamp.

## 5. DATETIME Profiling Results

All four configured DATETIME columns were profiled using `TRY_CONVERT(DATETIME2, ...)`.

| Table | Column | Total Rows | NULL | Invalid | Valid | Minimum Timestamp | Maximum Timestamp |
|---|---|---:|---:|---:|---:|---|---|
| delivery_events | actual_datetime | 170,820 | 0 | 0 | 170,820 | 2022-01-01 06:13:28.8923730 | 2025-01-03 00:29:47.4033500 |
| delivery_events | scheduled_datetime | 170,820 | 0 | 0 | 170,820 | 2022-01-01 07:00:00.0000000 | 2025-01-02 19:21:42.6298330 |
| fuel_purchases | purchase_date | 196,442 | 0 | 0 | 196,442 | 2022-01-01 00:00:00.0000000 | 2025-01-02 23:00:00.0000000 |
| safety_incidents | incident_date | 170 | 0 | 0 | 170 | 2022-01-05 02:00:00.0000000 | 2024-12-24 09:00:00.0000000 |

### 5.1 DATETIME findings

- All four columns converted successfully to `DATETIME2`.
- No NULL values were detected.
- No invalid datetime values were detected.
- No future timestamps were detected at the time of profiling.
- Fractional-second precision from the source was preserved during conversion.

### 5.2 Investigation of January 2025 timestamps

The maximum values in three columns extend into January 2025:

- `delivery_events.actual_datetime`: January 3, 2025.
- `delivery_events.scheduled_datetime`: January 2, 2025.
- `fuel_purchases.purchase_date`: January 2, 2025.

These timestamps were investigated because the dataset's main operational date range is 2022–2024. The detailed investigation is summarized below; the query-level evidence and limitations belong in the companion investigation report.

#### Delivery events

The investigation identified 87 distinct Delivery events with an actual or scheduled timestamp in January 2025.

| Finding | Result |
|---|---:|
| January actual timestamps | 86 |
| January scheduled timestamps | 77 |
| Distinct Delivery events involved | 87 |
| Events with both timestamps in January | 76 |
| Events with actual timestamp only in January | 10 |
| Events with scheduled timestamp only in January | 1 |
| Trips without Pickup events | 0 |
| Trips without Delivery events | 0 |
| Trips with Pickup actual before Delivery actual | 87 |
| Invalid actual event sequences | 0 |

All 87 associated trips and loads were dated December 30 or December 31, 2024. Each trip had one Pickup and one Delivery event, and every Pickup actual timestamp preceded its corresponding Delivery actual timestamp.

**Conclusion:** The January timestamps are consistent with cross-year trip activity. No confirmed timestamp error was identified.

#### Fuel purchases

A total of 201 fuel purchases occurred in January 2025.

| Purchase date | Purchases | Distinct trucks | Distinct drivers |
|---|---:|---:|---:|
| 2025-01-01 | 137 | 52 | 70 |
| 2025-01-02 | 64 | 33 | 32 |
| **Total** | **201** | — | — |

Further investigation found:

- The 201 purchases referenced 115 distinct trips.
- Associated trip dispatch dates ranged from December 29 through December 31, 2024.
- All 201 purchases occurred after their associated trip dispatch dates.
- All 201 had a matching Delivery event.
- 52 purchases occurred before actual delivery; 149 occurred on or after actual delivery.
- All 201 truck associations matched the truck assigned to the referenced trip.
- 199 records had matching, non-NULL driver associations.
- Two records had NULL driver IDs in both the fuel purchase and its associated trip: `FUEL00193404` / `TRIP00085249` and `FUEL00035251` / `TRIP00085366`.

The purchase-to-delivery time differences were:

| Purchase timing | Count | Minimum minutes from delivery | Maximum minutes from delivery | Average minutes from delivery |
|---|---:|---:|---:|---:|
| Before delivery | 52 | -2,009 | -30 | -735.634615 |
| On or after delivery | 149 | 8 | 3,631 | 1,406.986577 |

**Conclusion:** The January purchase timestamps are plausibly associated with year-end operations. No timestamp error was established. However, the business meaning of the `trip_id` association, particularly for purchases occurring after delivery, remains unverified. Matching truck and driver identifiers establish internal identifier consistency, not necessarily the operational meaning of the purchase-to-trip relationship.

## 6. Overall Findings

1. All 15 configured DATE and DATETIME columns were profiled successfully.
2. No invalid date or datetime conversions were detected.
3. All DATETIME values were non-NULL.
4. The only missing DATE values were the 124 NULLs in `drivers.termination_date`.
5. No future dates or timestamps were detected at the time of profiling.
6. The January 2025 timestamps were investigated against associated operational records. No confirmed timestamp error was identified.
7. Some business meanings remain unverified, including the employment status implied by missing termination dates and the operational meaning of fuel-purchase-to-trip associations.

These results establish technical convertibility and describe the observed temporal patterns. They do not independently establish the business correctness of every source value or relationship.

## 7. Silver-Layer Recommendations

The following are recommendations for future Silver-layer design. They are not claims that Silver transformations have already been implemented.

| Area | Recommendation | Reason / qualification |
|---|---|---|
| DATE columns | Convert to SQL Server `DATE` after applying the validated source format. | All 11 configured columns converted successfully using style 23 (`YYYY-MM-DD`). |
| DATETIME columns | Convert to an appropriate `DATETIME2` precision. | All four columns converted successfully, and source fractional-second precision was preserved. |
| Missing termination dates | Preserve the 124 NULL values unless a documented business rule supports another treatment. | Active employment status has not been independently verified. |
| Monthly reporting periods | Preserve the first-of-month DATE representation unless a downstream modelling requirement justifies a different representation. | Both monthly columns consistently use the first day of each month. |
| January 2025 timestamps | Preserve the original timestamps; do not shift them into December 2024. | Investigation found cross-year trip activity and no confirmed timestamp error. |
| Fuel purchase associations | Do not infer that a fuel purchase occurred during the referenced trip solely from `trip_id`. | 149 purchases occurred on or after actual delivery; the business meaning of the association remains unverified. |
| Traceability | Keep Bronze source values unchanged and document any Silver conversion or business rule. | Maintains a reproducible link to the raw source representation. |

## 8. Limitations

- Successful conversion establishes technical convertibility, not business correctness.
- The 124 missing termination dates have not been independently checked against employment-status records.
- The source-generation logic for January 2025 timestamps is unavailable.
- The business meaning of fuel-purchase-to-trip associations, particularly purchases after delivery, remains unverified.
- No external authoritative source was used to independently validate operational dates or timestamps.
- Future-value checks reflect the date and time when profiling was executed; they are not permanent assertions about the dataset.
- No Silver transformations were implemented as part of this profiling work.

## Related Documentation

- [Numeric Profiling](numeric_profiling.md) — methodology, results, and completed numeric investigations.
- [Bronze Layer Overview](readme.md) — Bronze architecture, ingestion, validation, and profiling documentation.

