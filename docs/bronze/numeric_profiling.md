# Bronze Layer – Numeric Data Profiling

## 1. Overview

Numeric data profiling was performed on the Bronze layer of the Logistics Analytics Data Warehouse to assess the quality, validity, distribution, and general characteristics of numeric source values before applying transformations in the Silver layer.

The profiling covered **53 numeric columns across all 14 Bronze tables**. Since Bronze stores source data as `VARCHAR`, numeric values were temporarily converted during profiling to evaluate their convertibility and calculate numerical statistics. The original Bronze data was not modified.

The objective was to identify:
- NULL values and missing numeric data.
- Values that cannot be converted into numeric types.
- Minimum, maximum, and average values.
- Negative and zero values.
- Unusual distributions and patterns that may require business-context investigation.
- Potential considerations for Silver-layer data types and transformations.

## 2. Profiling Methodology

### 2.1 Metadata-driven profiling

Instead of writing separate profiling queries for every numeric column, a metadata-driven SQL approach was implemented.

The profiling configuration was maintained in `bronze.profiling_config`, which identifies each column's profiling category.

The numeric profiling process:
1. Retrieves columns classified as `NUMERIC` from the profiling configuration.
2. Generates a profiling query for each configured column.
3. Uses `STRING_AGG()` to combine the generated queries with `UNION ALL`.
4. Uses `TRY_CONVERT(DECIMAL(18,4), column)` to evaluate numeric convertibility without interrupting execution when an individual value cannot be converted.
5. Executes the generated SQL using `sp_executesql`.
6. Returns a consolidated result set containing the profiling metrics for all numeric columns.

This approach allows the same profiling logic to be reused across multiple tables and columns without manually writing individual queries.

### 2.2 Profiling metrics

The following metrics were calculated for each numeric column:

| Metric | Description |
|---|---|
| Total Rows | Total records in the source table. |
| Non-NULL Values | Number of records containing a non-NULL value in the column. |
| NULL Values | Number of records containing NULL. |
| Invalid Numeric Values | Non-NULL source values that could not be converted to `DECIMAL(18,4)`. |
| Minimum Value | Lowest successfully converted numeric value. |
| Maximum Value | Highest successfully converted numeric value. |
| Average Value | Average of successfully converted numeric values. |
| Negative Values | Number of values below zero. |
| Zero Values | Number of values equal to zero. |

**Important:** `DECIMAL(18,4)` was used as a common profiling conversion type. It is a profiling mechanism, not an automatic decision that every Silver column should use this exact data type. Final Silver data types must reflect the precision, scale, and business meaning of individual columns.

## 3. Overall Profiling Results

A total of 53 numeric columns were profiled.

| Metric | Result |
|---|---:|
| Numeric columns profiled | 53 |
| Tables covered | 14 |
| Column-value observations | 549,706 |
| Columns containing NULL values | 0 |
| Total NULL values | 0 |
| Columns containing invalid numeric values | 0 |
| Total invalid numeric values | 0 |
| Columns containing negative values | 1 |
| Total negative occurrences | 50 |
| Columns containing zero values | 9 |
| Total zero occurrences | 59,924 |

**Interpretation:**

- All 53 numeric columns successfully passed the numeric conversion check.
- No NULL values were found in the profiled numeric columns.
- No invalid numeric values were detected using the profiling conversion.
- Negative values occurred in only one column: `facilities.longitude`.
- Nine columns contained at least one zero value.

The 549,706 observations represent the sum of the row counts across the 53 profiled columns. They do not represent 549,706 unique records.

Similarly, 59,924 represents the total number of zero occurrences across the nine columns. It does not represent 59,924 unique records, because a single record can contain zero values in multiple columns.

## 4. Detailed Numeric Profiling Results

The following table contains the results returned by the profiling query.

| Table | Column | Rows | Min | Max | Average | Negative | Zero |
|---|---|---:|---:|---:|---:|---:|---:|
| customers | annual_revenue_potential | 200 | 101641.0000 | 4990599.0000 | 2688236.745000 | 0 | 0 |
| customers | credit_terms_days | 200 | 15.0000 | 60.0000 | 37.650000 | 0 | 0 |
| delivery_events | detention_minutes | 170820 | 0.0000 | 239.0000 | 91.537460 | 0 | 22472 |
| driver_monthly_metrics | average_idle_hours | 4464 | 4.4000 | 9.7000 | 7.011738 | 0 | 0 |
| driver_monthly_metrics | average_mpg | 4464 | 6.0100 | 7.0700 | 6.501861 | 0 | 0 |
| driver_monthly_metrics | on_time_delivery_rate | 4464 | 0.0000 | 0.8330 | 0.445995 | 0 | 1 |
| driver_monthly_metrics | total_fuel_gallons | 4464 | 521.9000 | 9007.5000 | 4158.631698 | 0 | 0 |
| driver_monthly_metrics | total_miles | 4464 | 3310.0000 | 57954.0000 | 26812.792338 | 0 | 0 |
| driver_monthly_metrics | total_revenue | 4464 | 7096.5600 | 124579.5300 | 57630.947712 | 0 | 0 |
| driver_monthly_metrics | trips_completed | 4464 | 5.0000 | 37.0000 | 18.749103 | 0 | 0 |
| drivers | years_experience | 150 | 2.0000 | 25.0000 | 13.493333 | 0 | 0 |
| facilities | dock_doors | 50 | 16.0000 | 150.0000 | 78.580000 | 0 | 0 |
| facilities | latitude | 50 | 25.7617 | 45.5152 | 36.869320 | 0 | 0 |
| facilities | longitude | 50 | -122.6784 | -74.0060 | -93.260216 | 50 | 0 |
| fuel_purchases | gallons | 196442 | 50.0000 | 200.0000 | 124.815659 | 0 | 0 |
| fuel_purchases | price_per_gallon | 196442 | 3.1500 | 5.0000 | 3.898418 | 0 | 0 |
| fuel_purchases | total_cost | 196442 | 158.5000 | 997.9000 | 486.621964 | 0 | 0 |
| loads | accessorial_charges | 85410 | 0.0000 | 200.0000 | 71.643835 | 0 | 32186 |
| loads | fuel_surcharge | 85410 | 13.8000 | 891.8200 | 350.972118 | 0 | 0 |
| loads | pieces | 85410 | 1.0000 | 28.0000 | 14.470530 | 0 | 0 |
| loads | revenue | 85410 | 125.9300 | 8125.2200 | 3073.712683 | 0 | 0 |
| loads | weight_lbs | 85410 | 10000.0000 | 45000.0000 | 27477.495304 | 0 | 0 |
| maintenance_records | downtime_hours | 2920 | 2.0000 | 48.0000 | 24.736472 | 0 | 0 |
| maintenance_records | labor_cost | 2920 | 43.2800 | 976.8700 | 438.529825 | 0 | 0 |
| maintenance_records | labor_hours | 2920 | 0.5000 | 8.0000 | 4.178458 | 0 | 0 |
| maintenance_records | odometer_reading | 2920 | 50156.0000 | 749875.0000 | 401534.787671 | 0 | 0 |
| maintenance_records | parts_cost | 2920 | 0.1400 | 3498.6100 | 1523.995270 | 0 | 0 |
| maintenance_records | total_cost | 2920 | 60.8200 | 4426.5700 | 1962.525095 | 0 | 0 |
| routes | base_rate_per_mile | 58 | 1.5200 | 2.7900 | 2.196724 | 0 | 0 |
| routes | fuel_surcharge_rate | 58 | 0.1500 | 0.3400 | 0.248793 | 0 | 0 |
| routes | typical_distance_miles | 58 | 92.0000 | 3141.0000 | 1391.500000 | 0 | 0 |
| routes | typical_transit_days | 58 | 1.0000 | 5.0000 | 2.120689 | 0 | 0 |
| safety_incidents | cargo_damage_cost | 170 | 0.0000 | 49744.0700 | 6174.180647 | 0 | 122 |
| safety_incidents | claim_amount | 170 | 0.0000 | 64245.7200 | 15606.893058 | 0 | 39 |
| safety_incidents | vehicle_damage_cost | 170 | 0.0000 | 24614.1600 | 9432.712411 | 0 | 52 |
| trailers | length_feet | 180 | 53.0000 | 53.0000 | 53.000000 | 0 | 0 |
| trailers | model_year | 180 | 2015.0000 | 2024.0000 | 2019.144444 | 0 | 0 |
| trips | actual_distance_miles | 85410 | 90.0000 | 3391.0000 | 1430.268130 | 0 | 0 |
| trips | actual_duration_hours | 85410 | 1.4000 | 67.8000 | 25.014673 | 0 | 0 |
| trips | average_mpg | 85410 | 5.5000 | 7.5000 | 6.501462 | 0 | 0 |
| trips | fuel_gallons_used | 85410 | 12.0000 | 611.9000 | 221.827421 | 0 | 0 |
| trips | idle_time_hours | 85410 | 2.0000 | 12.0000 | 7.010783 | 0 | 0 |
| truck_utilization_metrics | average_mpg | 3312 | 6.0100 | 6.8600 | 6.500975 | 0 | 0 |
| truck_utilization_metrics | downtime_hours | 3312 | 0.0000 | 152.2000 | 16.549577 | 0 | 1684 |
| truck_utilization_metrics | maintenance_cost | 3312 | 0.0000 | 10414.6600 | 1307.187629 | 0 | 1684 |
| truck_utilization_metrics | maintenance_events | 3312 | 0.0000 | 4.0000 | 0.673309 | 0 | 1684 |
| truck_utilization_metrics | total_miles | 3312 | 12680.0000 | 71177.0000 | 36152.230072 | 0 | 0 |
| truck_utilization_metrics | total_revenue | 3312 | 27876.1800 | 144891.1000 | 77700.561564 | 0 | 0 |
| truck_utilization_metrics | trips_completed | 3312 | 11.0000 | 46.0000 | 25.283212 | 0 | 0 |
| truck_utilization_metrics | utilization_rate | 3312 | 0.3870 | 1.4840 | 0.830447 | 0 | 0 |
| trucks | acquisition_mileage | 120 | 227.0000 | 49556.0000 | 26058.216666 | 0 | 0 |
| trucks | model_year | 120 | 2015.0000 | 2021.0000 | 2015.891666 | 0 | 0 |
| trucks | tank_capacity_gallons | 120 | 150.0000 | 250.0000 | 201.666666 | 0 | 0 |

All 53 columns had zero NULL values and zero invalid numeric conversions. These two metrics are summarized above rather than repeated in every row.

## 5. Findings Requiring Further Investigation

Profiling identified several patterns that require business-context validation. These are observations, not confirmed data-quality errors.

### 5.1 Facility coordinate validation and geographic precision

**Columns:** `facilities.latitude`, `facilities.longitude`

#### 5.1.1 Numeric and range validation

- Facility records inspected: 50
- Latitude range: 25.7617 to 45.5152
- Longitude range: -122.6784 to -74.0060
- Negative longitude values: 50

The inspected records had latitude and longitude values within the valid numeric coordinate ranges (latitude: -90 to +90; longitude: -180 to +180). Negative longitude values are geographically valid and indicate locations west of the Prime Meridian; they are not, by themselves, a data-quality error.

#### 5.1.2 Repeated city-level coordinate pairs

Coordinates were grouped by city, state, latitude, and longitude. The 50 facility records produced 21 distinct city/state/coordinate combinations. Facilities within the same city and state shared the same coordinate pair.

A further grouping by latitude and longitude showed that multiple facilities shared coordinate pairs. This pattern suggests that the source uses city-level reference coordinates rather than precise coordinates for each physical facility.

#### 5.1.3 Repeated facility names and operational attributes

Repeated facility names within the same city and state were inspected. The inspected records had different `facility_id` values and differing operational attributes, including facility type, dock-door count, and operating hours.

Examples included:
- `Nashville Distribution Center`: four records with three distinct facility types.
- `Atlanta Warehouse`: three records with two distinct facility types.
- `Detroit Hub`: three records with two distinct facility types.
- `Houston` coordinate group: three facilities with three distinct names and three distinct facility types.

These patterns do not establish that the records are duplicates. They may represent separate facilities that share a generic city-based name. The source does not provide street-level addresses, so the physical uniqueness and exact location of each facility cannot be independently verified from the available columns.

#### 5.1.4 Analytical implications

- Use `facility_id` as the facility identifier for facility counts, relationships, and facility-level aggregations.
- Do not treat `facility_name` as a unique identifier.
- Do not classify records as duplicates solely because they share a name, city, state, or coordinate pair.
- Treat the coordinates as city-level reference points unless more precise location data becomes available. Facility-level distance calculations and map placement may therefore be imprecise.

**Investigation status:** Numeric range and within-dataset pattern checks completed. Exact physical-location accuracy remains unverified because street-level addresses or an authoritative facility-location reference are not available.

### 5.2 Constant trailer length

**Column:** `trailers.length_feet`

- Total values: 180
- Minimum: 53
- Maximum: 53
- Average: 53

Every trailer has the same recorded length. The value was examined by trailer type and model year:

| Grouping | Records | Distinct lengths | Minimum | Maximum |
|---|---:|---:|---:|---:|
| Dry Van | 94 | 1 | 53 | 53 |
| Refrigerated | 86 | 1 | 53 | 53 |
| All trailers | 180 | 1 | 53 | 53 |

The same value was observed across all model years represented in the source (2015–2024). This confirms that the source attribute is constant in the available dataset. It does not independently verify the physical length of each trailer or establish whether the value is a standardized fleet assumption or a default source-data value.

**Investigation status:** Descriptive investigation completed. Physical correctness remains unverified.

### 5.3 Zero detention minutes

**Column:** `delivery_events.detention_minutes`

- Total values: 170,820
- Zero values: 22,472 (approximately 13.15%)
- Positive values: 148,348
- Minimum: 0
- Maximum: 239
- Average: 91.537460

The descriptive investigation examined detention by event type, facility, `on_time_flag`, and schedule-deviation band.

Delivery events had consistently higher average detention (approximately 105–107 minutes) than Pickup events (approximately 76–77 minutes). Within each event type, average and median detention were relatively stable across populated schedule-deviation bands. Zero-detention proportions were also relatively consistent across those bands. The exactly-on-schedule groups were very small (five Delivery events and three Pickup events) and were not used for broad comparisons.

No strong observable association between schedule deviation and detention was identified in this descriptive analysis. This is not proof of statistical independence or causation.

**Investigation status:** Descriptive investigation completed. The precise operational definition of `detention_minutes` remains unresolved; the available source data does not establish whether it represents total waiting time, time beyond an allowed free period, or another measure. See [Detention Minutes Investigation](investigations/detention_minutes_investigation.md) for methodology, detailed results, limitations, and Silver-layer considerations.

**Related completed investigation:** The separate `delivery_events.on_time_flag` investigation verified that the source flag follows an inclusive ±120-minute tolerance rule across all 170,820 events, with zero mismatches at microsecond precision. This does not establish the business definition of `detention_minutes`. See [On-Time Flag Investigation](investigations/on_time_flag_investigation.md).

### 5.4 Zero accessorial charges

**Column:** `loads.accessorial_charges`

- Total values: 85,410
- Zero values: 32,186 (37.69%)
- Positive values: 53,224 (62.31%)
- Negative values: 0
- Minimum: 0
- Maximum: 200
- Average: 71.643835

The investigation compared zero and positive accessorial-charge records across load type, booking type, customer, route, shipment weight, piece count, revenue, and fuel surcharge.

Key observations:

- All six load-type/booking-type combinations contained both zero and positive charges. Zero proportions were similar across the groups (approximately 37.0%–38.1%).
- All 200 customers and all 58 routes had both zero-charge and positive-charge loads.
- Shipment weight, piece count, revenue, and fuel surcharge were broadly similar between zero-charge and positive-charge groups.
- No obvious data-quality anomaly or strong operational concentration explained the zero values.

**Conclusion and Silver-layer consideration:** Preserve zero values as zero. Do not convert them to `NULL`, impute replacement charges, or infer that a zero is commercially correct without supporting charge definitions or contracts. The available dataset does not establish the commercial correctness of each charge.

**Investigation status:** Analytical investigation completed. The business definition and commercial correctness remain unverified.

### 5.5 Zero on-time delivery rate

**Column:** `driver_monthly_metrics.on_time_delivery_rate`

- Total values: 4,464
- Zero values: 1
- Minimum: 0
- Maximum: 0.833

The zero occurred for driver `DRV00074` in September 2024. The monthly record showed 10 completed trips. The underlying event review found 10 Delivery events, all marked `False`, and 10 Pickup events. Since Pickup events are excluded from the delivery-rate calculation:

`0 on-time Delivery events / 10 total Delivery events = 0.000`

The full dataset was reconciled using Delivery events grouped by driver and the month derived from `trips.dispatch_date`.

| Validation result | Records |
|---|---:|
| Match after standard rounding to three decimal places | 4,383 |
| Remaining standard-rounding mismatches reproduced by truncation | 81 |
| Other differences | 0 |
| Monthly records without matching Delivery events | 0 |
| **Total monthly records** | **4,464** |

Applying truncation to every record was not an appropriate universal comparison rule: it matched 2,741 records and differed from 1,723. The 81 exceptions to standard rounding matched the truncated calculated values. The original source-generation code was not available, so the exact precision-handling convention remains unverified.

**Conclusion and Silver-layer consideration:** The single zero is supported by the underlying delivery records. Preserve zero as a numeric value; do not convert it to `NULL` or impute a replacement. Retain the source value and do not impose a universal truncation or rounding rule in Silver until the source precision convention is confirmed.

**Investigation status:** Completed. See [On-Time Delivery Rate Investigation](investigations/on_time_delivery_rate_investigation.md) for the detailed methodology, validation results, limitations, and Silver-layer considerations.

### 5.6 Incident-related financial values

**Columns:** `safety_incidents.cargo_damage_cost`, `safety_incidents.claim_amount`, `safety_incidents.vehicle_damage_cost`

| Column | Zero occurrences |
|---|---:|
| `cargo_damage_cost` | 122 |
| `claim_amount` | 39 |
| `vehicle_damage_cost` | 52 |

The investigation examined zero-value combinations, incident categories and flags, positive damage amounts, and the row-level relationship between the three financial fields.

#### Zero-value patterns

| Cargo damage is zero | Claim amount is zero | Vehicle damage is zero | Incidents |
|---:|---:|---:|---:|
| Yes | No | No | 83 |
| Yes | Yes | Yes | 39 |
| No | No | No | 35 |
| No | No | Yes | 13 |

All 39 incidents with a zero claim amount also had zero cargo and vehicle damage costs. No incident had a zero claim amount alongside positive damage costs.

#### Additional findings

- Zero values occurred across all five incident types and across the `at_fault_flag`, `injury_flag`, and `preventable_flag` categories. No single category explained the zero-value pattern.
- Across all 170 incidents, `claim_amount` equalled `vehicle_damage_cost + cargo_damage_cost`; there were 170 matches and no mismatches.
- The arithmetic relationship confirms internal consistency in the dataset. It does not independently establish the business definition of `claim_amount`.
- The currency unit and commercial correctness of the recorded amounts could not be verified from the available source data.

**Conclusion and Silver-layer consideration:** Preserve the three financial fields and their zero values. Do not convert zeros to NULL or impute replacement values. Do not remove or redefine `claim_amount` until its business definition is confirmed.

**Investigation status:** Completed. See [Safety Incident Financials Investigation](investigations/safety_incident_financials_investigation.md) for the detailed methodology, results, limitations, and Silver-layer considerations.

### 5.7 Zero truck downtime and maintenance metrics

The following columns in `truck_utilization_metrics` each contain 1,684 zero values:

| Column | Zero occurrences |
|---|---:|
| `downtime_hours` | 1,684 |
| `maintenance_cost` | 1,684 |
| `maintenance_events` | 1,684 |

The three columns shared the same zero/non-zero pattern: 1,684 truck-months had zero across all three metrics, while 1,628 truck-months had positive values across all three.

The investigation compared the monthly metrics with detailed records in `bronze.maintenance_records`, aggregated by truck and calendar month. All 3,312 truck-months reconciled exactly:

- Maintenance event counts matched the number of detailed maintenance records.
- Maintenance costs matched the sum of detailed `total_cost`.
- Downtime hours matched the sum of detailed `downtime_hours`.

The 1,684 zero-value truck-months had no corresponding detailed maintenance records. The remaining 1,628 truck-months matched the detailed records for all three metrics.

**Conclusion:** The zero values are internally consistent with the detailed maintenance records. This does not independently establish that every real-world maintenance activity was captured in the source system.

**Investigation status:** Completed. See [Truck Utilization Maintenance Investigation](investigations/truck_utilization_maintenance_investigation.md) for the methodology, reconciliation results, limitations, and Silver-layer considerations.

## 6. Confirmed Investigation: Utilization Rate Business Meaning

**Column:** `truck_utilization_metrics.utilization_rate`

The initial profiling results showed values ranging from 0.387 to 1.484, with an average of 0.830447.

Values greater than 1.0 initially appeared unusual if the column represented a utilization percentage or ratio. Therefore, the source calculation was investigated.

### 6.1 Investigation approach

The recorded values were compared against the following calculation:

`trips_completed / number_of_calendar_days_in_month`

The calculation was performed for all 3,312 records.

### 6.2 Investigation results

| Metric | Result |
|---|---:|
| Total records tested | 3,312 |
| Matching records | 3,312 |
| Mismatching records | 0 |

Every record matched the calculated result.

### 6.3 Conclusion

The source metric represents the average number of completed trips per calendar day, rather than a utilization percentage.

Consequently, values greater than 1.0 are valid and do not indicate utilization exceeding 100%.

### 6.4 Silver-layer consideration

Consider renaming the Silver column to `trips_per_day` to make its meaning clearer.

The original Bronze column name should remain unchanged to preserve source traceability.

**Investigation status:** Completed and verified.

## 7. Analytical Decisions

This section records decisions made from profiling and investigation findings. These decisions are distinct from raw observations: profiling records what was found, while this section records how the project will use or interpret that information.

### AD-001 — Use `facility_id` as the facility identifier

| Field | Decision record |
|---|---|
| Decision ID | AD-001 |
| Table | `facilities` |
| Relevant columns | `facility_id`, `facility_name` |
| Decision | Use `facility_id` to identify and count facilities. Do not use `facility_name` as a unique identifier. |
| Reason | Facility names are reused within the same city and state. The inspected records have different IDs and differing operational attributes, so repeated names alone do not prove duplicate facilities. |
| Analytical impact | Use `facility_id` for facility counts, joins/relationships, and facility-level aggregations. Treat `facility_name` as a descriptive attribute. |
| Status | Accepted |

### AD-002 — Do not infer duplicate facilities from shared names or coordinates alone

| Field | Decision record |
|---|---|
| Decision ID | AD-002 |
| Table | `facilities` |
| Relevant columns | `facility_name`, `city`, `state`, `latitude`, `longitude`, `facility_type`, `dock_doors`, `operating_hours` |
| Decision | Do not classify facilities as duplicates solely because they share a name, city/state, or coordinate pair. |
| Reason | The inspected records have distinct facility IDs and differing operational attributes. We do not have street-level addresses, so we cannot conclusively establish whether these records represent separate physical facilities. |
| Analytical impact | Preserve the records unless stronger evidence establishes duplication. Treat city-level coordinates as insufficient for precise facility-level geographic analysis. |
| Status | Accepted, subject to review if better source-location data becomes available |

These are project-level analytical decisions based on the available source data. They do not assert that the physical locations have been independently verified.

## 8. Implications for the Silver Layer

The profiling results provide useful information for designing Silver-layer transformations.

The following principles will guide the next stage:

1. **Data type conversion:** Numeric columns can be evaluated for conversion into appropriate SQL Server numeric types. Final precision and scale should be selected according to each column's meaning and observed range.

2. **Preserve valid zero values:** Zero values must not automatically be converted into NULLs. Their business meaning must be established first.

3. **Handle negative values according to context:** Negative longitude values are not inherently invalid. Geographic validation is required before making any transformation decisions.

4. **Preserve source traceability:** Original Bronze column names should remain unchanged. Any improved business-facing names should be introduced in Silver where appropriate.

5. **Document transformation rules:** Any cleaning, standardization, renaming, or handling of unusual values should be supported by an investigation and documented business rule.

6. **Avoid premature assumptions:** Unusual patterns should be investigated before being classified as errors or corrected.

## 9. Profiling Completion Status

Numeric profiling and the investigations documented in this report are complete for the current Bronze extract.

Completed work includes:

- Metadata-driven profiling of all 53 configured numeric columns across 14 tables.
- Validation of NULL counts, numeric convertibility, minimum/maximum/average values, and negative/zero occurrences.
- Investigation of facility coordinate ranges and repeated city-level coordinate patterns.
- Investigation of the constant 53-foot trailer-length value.
- Descriptive investigation of detention minutes and the source on-time flag.
- Investigation and reconciliation of truck-month maintenance metrics against detailed maintenance records.
- Investigation of zero accessorial charges and the single zero monthly on-time delivery rate.
- Investigation of safety-incident financial values and their row-level arithmetic relationship.
- Recording the facility identifier and duplicate-assessment decisions (AD-001 and AD-002).

The following are **source-context limitations**, not outstanding numeric profiling tasks:

- Exact physical facility locations cannot be verified without street-level addresses or an authoritative geospatial reference.
- The precise operational definition of `delivery_events.detention_minutes` remains unverified; clarification requires reliable source documentation or business-owner confirmation.
- The physical correctness of the constant 53-foot trailer length cannot be independently confirmed from this dataset alone.
- The commercial correctness of zero accessorial charges and some financial values cannot be established from the available source data.
- The exact source-generation precision convention for `on_time_delivery_rate` remains unverified for the 81 records that matched truncation rather than standard rounding.

No further numeric profiling queries are currently identified as outstanding for the current extract. If the Bronze data is refreshed or new source documentation becomes available, rerun the relevant checks and revise the findings where necessary.
