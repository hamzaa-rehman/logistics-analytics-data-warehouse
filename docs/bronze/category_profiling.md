# Bronze Layer — CATEGORY Profiling

## 1. Purpose and scope

CATEGORY profiling examines columns whose values represent labels or groupings, including statuses, types, flags, city names, and state codes. It describes the values present in the Bronze extract; it does not by itself establish business correctness.

The profiling covered all **39 columns classified as `CATEGORY`** in `bronze.profiling_config`, across the 14 Bronze tables. Bronze values were not modified.

Reusable SQL: [`profile_category.sql`](../../scripts/bronze/profile_category.sql).

## 2. Methodology

The script reads CATEGORY entries from the profiling configuration, validates configured schema/table/column names against SQL Server metadata, and generates one statement per column. `STRING_AGG` combines statements with `UNION ALL`; `QUOTENAME` delimits object identifiers; and `sys.sp_executesql` executes the generated batch.

Three outputs are produced:

1. **Summary:** total rows, distinct non-NULL values, and NULL count for each configured column.
2. **Frequency distribution:** each non-NULL category value, its row count, and its percentage of non-NULL values within that column.
3. **Text checks:** distinct counts under the database's normal collation and `Latin1_General_100_BIN2` binary collation, plus a check for leading/trailing ordinary spaces using `LTRIM`, `RTRIM`, and `DATALENGTH`.

The frequency percentages are calculated separately for each table/column. The binary-collation comparison can reveal distinctions (such as case variants) that the normal collation treats as equal. The whitespace check is limited to ordinary boundary spaces; it is not a universal Unicode-whitespace test.

## 3. Overall results

| Check | Result |
|---|---:|
| Configured CATEGORY columns | 39 |
| Columns included in profiling | 39 |
| NULL values across CATEGORY columns | 0 |
| Columns with normal/binary distinct-count differences | 0 |
| Columns with leading/trailing ordinary spaces | 0 |

No NULL values, detected case-sensitive distinct-count differences, or leading/trailing ordinary spaces were reported within the checks' stated scope.

## 4. Distinct-value profile

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

## 5. Selected frequency observations

The frequency output was reviewed for all 39 columns. Selected distributions are summarized below; the complete category-level output can be reproduced by running the frequency section of the SQL script.

| Column | Observed distribution |
|---|---|
| `customers.account_status` | Active 168 (84%); Inactive 32 (16%) |
| `customers.customer_type` | Contract 75 (37.50%); Spot 63 (31.50%); Dedicated 62 (31.00%) |
| `delivery_events.event_type` | Delivery 85,410 (50%); Pickup 85,410 (50%) |
| `delivery_events.on_time_flag` | True 95,095 (55.67%); False 75,725 (44.33%) |
| `drivers.employment_status` | Active 124 (82.67%); Terminated 26 (17.33%) |
| `facilities.facility_type` | Cross-Dock 20 (40%); Distribution Center 13 (26%); Terminal 10 (20%); Warehouse 7 (14%) |
| `loads.booking_type` | Dedicated 42,337 (49.57%); Contract 21,545 (25.23%); Spot 21,528 (25.21%) |
| `loads.load_status` | Completed 85,410 (100%) |
| `loads.load_type` | Refrigerated 42,946 (50.28%); Dry Van 42,464 (49.72%) |
| `safety_incidents.at_fault_flag` | False 116 (68.24%); True 54 (31.76%) |
| `safety_incidents.injury_flag` | False 137 (80.59%); True 33 (19.41%) |
| `safety_incidents.preventable_flag` | False 106 (62.35%); True 64 (37.65%) |
| `trailers.trailer_type` | Dry Van 94 (52.22%); Refrigerated 86 (47.78%) |
| `trucks.status` | Active 92 (76.67%); Maintenance 15 (12.50%); Inactive 13 (10.83%) |
| `trucks.make` | Six manufacturers; individual shares range from 12.50% to 20.00% |

### 5.1 Columns with one distinct value

Five columns contained a single distinct value in the current extract:

| Column | Observed value | Rows |
|---|---|---:|
| `drivers.cdl_class` | A | 150 |
| `loads.load_status` | Completed | 85,410 |
| `trailers.status` | Active | 180 |
| `trips.trip_status` | Completed | 85,410 |
| `trucks.fuel_type` | Diesel | 120 |

These are observations, not confirmed defects. They may reflect the dataset's scope, generation process, or snapshot. They provide no category variation in this extract, but that alone does not establish that the values are incorrect.

### 5.2 Related-column observations

- The 124 Active and 26 Terminated drivers align at aggregate level with 124 NULL and 26 populated `termination_date` values. This does not prove row-level agreement between each driver's status and termination date.
- `delivery_events.event_type` is evenly split between Pickup and Delivery.
- Load and trailer type distributions are broadly balanced between Dry Van and Refrigerated.
- `delivery_events.on_time_flag` was investigated separately; see the [on-time flag investigation](investigations/on_time_flag_investigation.md).

## 6. Findings and follow-up

| Finding | Assessment | Follow-up |
|---|---|---|
| No NULLs in the 39 CATEGORY columns | No NULLs detected in this profiling scope | No NULL-specific action identified by this check |
| No normal/binary distinct-count differences | No case variants detected by this comparison | Retain values unless a business rule requires standardization |
| No leading/trailing ordinary spaces | No ordinary boundary spaces detected | Broader Unicode whitespace validation was not performed |
| Five single-value columns | Dataset observations, not automatically defects | Consider limited category variation when designing Gold metrics |
| City/state relationships disagree in two sources | Requires relationship-level validation | See the [geographic consistency investigation](investigations/geographic_consistency_investigation.md) |

## 7. Limitations

1. **Descriptive profiling:** Distinct counts and frequencies do not establish business validity.
2. **Collation scope:** The selected binary comparison is not a complete Unicode normalization audit.
3. **Whitespace scope:** Tabs, line breaks, non-breaking spaces, and all Unicode whitespace were not comprehensively tested.
4. **Current extract:** Results describe the Bronze data at the time of profiling and may change after a refresh.
5. **Relationship validation:** Category frequencies do not validate relationships between columns or across tables; city/state relationships were assessed separately.

## 8. Conclusion

All 39 configured CATEGORY columns were profiled. The checks reported zero NULLs, no normal/binary distinct-count differences, and no leading/trailing ordinary spaces within their detection scope. Five columns contained one distinct value; these were documented as observations rather than presumed defects.

The geographic attributes required a separate relationship-level investigation. Core CATEGORY profiling is complete for the current Bronze extract; authoritative geographic validation remains a downstream follow-up.

## 9. Related resources

- [Bronze Layer README](readme.md)
- [Numeric profiling](numeric_profiling.md)
- [DATE and DATETIME profiling](date_datetime_profiling.md)
- [CATEGORY profiling SQL](../../scripts/bronze/profile_category.sql)
- [Geographic consistency investigation report](investigations/geographic_consistency_investigation.md)
- [Geographic consistency investigation SQL](../../scripts/bronze/investigations/investigate_geographic_consistency.sql)
