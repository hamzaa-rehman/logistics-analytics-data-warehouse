# Bronze Layer — CATEGORY Data Profiling

## 1. Overview

CATEGORY profiling examines columns whose values represent labels, statuses, types, flags, locations, and other descriptive groupings. The purpose is to understand the raw values, their distributions, and inconsistencies that may require validation or standardization in Silver.

**Scope:** 39 columns classified as CATEGORY in bronze.profiling_config.

The profiling reads Bronze VARCHAR values and does not modify source data.

## 2. Methodology

Metadata-driven SQL generated profiling statements for every configured CATEGORY column using STRING_AGG, UNION ALL, QUOTENAME, and sp_executesql.

Three checks were performed:

1. Distinct category counts and NULL counts.
2. Category frequencies and percentages within each column.
3. Case-sensitive distinct-count comparison using binary collation and leading/trailing ordinary-space checks using LTRIM, RTRIM, and DATALENGTH.

The reusable script is [profile_category.sql](../../scripts/bronze/profile_category.sql).

The whitespace check does not cover every Unicode whitespace character. Frequency distributions are descriptive and do not by themselves establish business validity.

## 3. Profiling Summary

| Metric | Result |
|---|---:|
| CATEGORY columns profiled | 39 |
| NULL values | 0 |
| Columns with NULL values | 0 |
| Case-sensitive distinct-count differences | 0 |
| Leading/trailing ordinary spaces | 0 |

## 4. Distinct Category Counts

| Table | Column | Distinct values |
|---|---|---:|
| customers | account_status | 2 |
| customers | customer_type | 3 |
| customers | primary_freight_type | 6 |
| delivery_events | event_type | 2 |
| delivery_events | location_city | 20 |
| delivery_events | location_state | 19 |
| delivery_events | on_time_flag | 2 |
| drivers | cdl_class | 1 |
| drivers | employment_status | 2 |
| drivers | home_terminal | 25 |
| drivers | license_state | 23 |
| facilities | city | 21 |
| facilities | facility_type | 4 |
| facilities | state | 20 |
| fuel_purchases | location_city | 25 |
| fuel_purchases | location_state | 23 |
| loads | booking_type | 3 |
| loads | load_status | 1 |
| loads | load_type | 2 |
| maintenance_records | facility_location | 25 |
| maintenance_records | maintenance_type | 7 |
| routes | destination_city | 19 |
| routes | destination_state | 18 |
| routes | origin_city | 18 |
| routes | origin_state | 17 |
| safety_incidents | at_fault_flag | 2 |
| safety_incidents | incident_type | 5 |
| safety_incidents | injury_flag | 2 |
| safety_incidents | location_city | 25 |
| safety_incidents | location_state | 23 |
| safety_incidents | preventable_flag | 2 |
| trailers | current_location | 25 |
| trailers | status | 1 |
| trailers | trailer_type | 2 |
| trips | trip_status | 1 |
| trucks | fuel_type | 1 |
| trucks | home_terminal | 24 |
| trucks | make | 6 |
| trucks | status | 3 |

## 5. Distribution Observations

Selected distributions from the completed frequency output:

| Column | Observed distribution |
|---|---|
| customers.account_status | Active 168 (84%); Inactive 32 (16%) |
| customers.customer_type | Contract 75 (37.50%); Spot 63 (31.50%); Dedicated 62 (31.00%) |
| delivery_events.event_type | Delivery 85,410 (50%); Pickup 85,410 (50%) |
| delivery_events.on_time_flag | True 95,095 (55.67%); False 75,725 (44.33%) |
| drivers.employment_status | Active 124 (82.67%); Terminated 26 (17.33%) |
| facilities.facility_type | Cross-Dock 20 (40%); Distribution Center 13 (26%); Terminal 10 (20%); Warehouse 7 (14%) |
| loads.booking_type | Dedicated 42,337 (49.57%); Contract 21,545 (25.23%); Spot 21,528 (25.21%) |
| loads.load_status | Completed 85,410 (100%) |
| loads.load_type | Refrigerated 42,946 (50.28%); Dry Van 42,464 (49.72%) |
| maintenance_records.maintenance_type | Seven categories, each approximately 13.77%–14.79% |
| safety_incidents.at_fault_flag | False 116 (68.24%); True 54 (31.76%) |
| safety_incidents.injury_flag | False 137 (80.59%); True 33 (19.41%) |
| safety_incidents.preventable_flag | False 106 (62.35%); True 64 (37.65%) |
| trailers.status | Active 180 (100%) |
| trailers.trailer_type | Dry Van 94 (52.22%); Refrigerated 86 (47.78%) |
| trips.trip_status | Completed 85,410 (100%) |
| trucks.fuel_type | Diesel 120 (100%) |
| trucks.status | Active 92 (76.67%); Maintenance 15 (12.50%); Inactive 13 (10.83%) |
| trucks.make | Six manufacturers, ranging from 12.50% to 20.00% |

### 5.1 Single-value columns

Five columns contained only one distinct value:

| Column | Value | Rows |
|---|---|---:|
| drivers.cdl_class | A | 150 |
| loads.load_status | Completed | 85,410 |
| trailers.status | Active | 180 |
| trips.trip_status | Completed | 85,410 |
| trucks.fuel_type | Diesel | 120 |

These are dataset observations, not automatically data-quality defects. They may reflect the source dataset's scope or snapshot and provide limited category variation in the current data.

### 5.2 Related-column observations

- drivers.employment_status contains 124 Active and 26 Terminated drivers. These counts align with the 124 NULL and 26 populated values previously observed in drivers.termination_date. Count-level alignment does not prove row-level consistency.
- delivery_events.event_type is evenly split between Pickup and Delivery, consistent with the event counts reviewed during earlier investigations.
- Load and trailer type distributions are broadly balanced between Dry Van and Refrigerated.
- delivery_events.on_time_flag had already been investigated separately; that investigation is not duplicated here.

## 6. Geographic Consistency Investigation

Frequency distributions alone cannot establish whether each city is consistently associated with the same state. Internal city/state checks and a cross-table comparison were therefore performed.

The SQL is [investigate_geographic_consistency.sql](../../scripts/bronze/investigations/investigate_geographic_consistency.sql).

### 6.1 Internal city/state mapping results

| Source | Distinct cities | Distinct city/state pairs | Internal result |
|---|---:|---:|---|
| delivery_events | 20 | 20 | No city mapped to multiple states |
| fuel_purchases | 25 | 575 | Each city paired with all 23 states |
| facilities | 21 | 21 | No city mapped to multiple states |
| safety_incidents | 25 | 145 | Cities mapped to multiple states |
| routes — origin | 18 | 18 | No city mapped to multiple states |
| routes — destination | 19 | 19 | No city mapped to multiple states |

fuel_purchases contains 25 cities and 23 states, producing all 575 possible city/state combinations. safety_incidents contains 145 distinct city/state pairs across 25 cities and 23 states.

### 6.2 Cross-table comparison

Internally consistent mappings from delivery_events, facilities, and routes (origin and destination) were combined into an internal reference mapping. Distinct pairs from fuel_purchases and safety_incidents were compared against it.

| Source table | Matches reference | Mismatches | Total distinct pairs |
|---|---:|---:|---:|
| fuel_purchases | 25 | 550 | 575 |
| safety_incidents | 7 | 138 | 145 |

These are distinct city/state-pair counts, not affected purchase or incident row counts.

The results establish substantial disagreement with the internal reference mappings. They do not establish the root cause or independently prove which source contains geographically correct values. The reference mappings have not been validated against an authoritative external geographic source.

### 6.3 Downstream handling

- Preserve the original Bronze values.
- Obtain an approved geographic reference source or documented business rule.
- Validate city/state pairs against that reference.
- Standardize or correct values in Silver only through traceable, documented rules.
- Retain lineage between original and standardized values.

No source values were changed during this investigation.

## 7. Findings and Decisions

| Finding | Assessment | Downstream consideration |
|---|---|---|
| No NULLs in CATEGORY columns | No NULL issue detected in this profiling scope | Continue with other quality checks |
| No case variants detected by binary comparison | No case inconsistency detected by this check | Standardize only if required |
| No leading/trailing ordinary spaces detected | No ordinary boundary-space issue detected | Unicode whitespace is outside this check's coverage |
| Five single-value columns | Dataset observation, not automatically an error | Consider analytical usefulness and source scope |
| fuel_purchases city/state mappings | Substantial disagreement with internal reference mappings | Validate against approved geographic reference |
| safety_incidents city/state mappings | Substantial disagreement with internal reference mappings | Validate against approved geographic reference |

## 8. Limitations

- Internal reference mappings are based on consistency among available source tables, not an authoritative geographic database.
- Comparison is at distinct city/state-pair level, not transaction or incident row level.
- The checks do not establish the root cause of geographic inconsistencies.
- Case and whitespace checks do not cover every Unicode normalization or whitespace issue.
- Category frequency distributions do not establish business correctness.
- Results describe the current loaded dataset and may change after a source refresh.

## 9. Conclusion

CATEGORY profiling covered all 39 configured columns. No NULL values, case-sensitive distinct-count differences, or leading/trailing ordinary spaces were detected by the checks performed.

Five columns contained only one distinct value; these were recorded as observations rather than defects.

The geographic investigation identified substantial cross-table disagreement in fuel_purchases and safety_incidents. These findings are documented for downstream Silver-layer validation. External authoritative geographic validation remains outstanding.

The core CATEGORY profiling and internal cross-table comparison are complete. Authoritative geographic verification remains a follow-up validation task.

## 10. Related Documentation and Scripts

- [Bronze Layer README](readme.md)
- [Numeric Profiling](numeric_profiling.md)
- [DATE and DATETIME Profiling](date_datetime_profiling.md)
- [CATEGORY profiling SQL](../../scripts/bronze/profile_category.sql)
- [Geographic consistency investigation SQL](../../scripts/bronze/investigations/investigate_geographic_consistency.sql)
