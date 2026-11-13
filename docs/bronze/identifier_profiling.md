# Bronze Identifier Profiling and Integrity Checks

## 1. Purpose and scope

This document records the identifier profiling and integrity checks performed on the current Bronze extract of the Logistics Analytics Data Warehouse.

The profiling configuration classifies **36 columns** as `IDENTIFIER`. The work covers three complementary roles:

- 12 candidate row identifiers assessed for non-NULL values and uniqueness.
- 18 child-to-parent identifier relationships assessed for NULL and orphan references.
- 6 business identifiers assessed for uniqueness and repeated values.

The checks are descriptive and read-only. They do not add primary-key or foreign-key constraints to Bronze.

## 2. Scripts

| Script | Purpose |
|---|---|
| [`profile_identifier.sql`](../../scripts/bronze/profile_identifier.sql) | Reusable, metadata-driven summary of all configured IDENTIFIER columns: row count, non-NULL count, NULL count, distinct count, and duplicate count. |
| [`investigate_identifier_integrity.sql`](../../scripts/bronze/investigations/investigate_identifier_integrity.sql) | Targeted candidate-key, foreign-key, business-identifier, trailer-number, and composite-key checks. |

The reusable profiling script is newly prepared for repeatable execution. The integrity investigation script consolidates the checks supplied from the original analysis, removes a duplicated `safety_incidents.trip_id` relationship check, and strengthens composite-key validation by using `GROUP BY` and separate NULL-component checks. Run both scripts against the intended Bronze database before relying on their current output.

## 3. Methodology

### 3.1 Candidate primary keys

For each candidate identifier, the checks compare total rows, non-NULL values, distinct values, and duplicate occurrences. A candidate passed the extract-level test when it had no NULLs and no repeated values.

A successful result supports treating the column as a candidate primary key for this extract. It does not establish a formal database constraint or guarantee uniqueness in future source extracts.

### 3.2 Foreign-key integrity

Each child identifier was left-joined to its referenced parent identifier. The checks report total rows, non-NULL references, NULL references, and non-NULL child values without a matching parent (orphans).

NULL references and orphan references are different conditions. A NULL may be valid or may require business clarification; an orphan is a non-NULL reference that does not resolve to the referenced parent in the tested extract.

### 3.3 Business identifiers

Business identifiers such as licence numbers, vehicle unit numbers, VINs, trailer numbers, and fuel-card numbers were checked for repeated values. Uniqueness is not assumed to be a requirement for every business identifier.

### 3.4 Composite identifiers

The driver-month and truck-month candidate grains were checked by grouping on both component columns and looking for groups with more than one row. NULL component counts are reported separately. This is safer than relying only on concatenated values, which can hide NULL components or introduce ambiguous combinations.

## 4. Results from the original investigation

The following figures are the results previously observed from the user's executed checks. Re-run the committed scripts to confirm the current database still produces the same results.

### 4.1 Candidate primary keys

All 12 candidate identifiers had zero NULLs and zero duplicate values in the extract.

| Candidate identifier | Rows | Distinct | NULLs | Duplicates |
|---|---:|---:|---:|---:|
| customers.customer_id | 200 | 200 | 0 | 0 |
| delivery_events.event_id | 170,820 | 170,820 | 0 | 0 |
| drivers.driver_id | 150 | 150 | 0 | 0 |
| facilities.facility_id | 50 | 50 | 0 | 0 |
| fuel_purchases.fuel_purchase_id | 196,442 | 196,442 | 0 | 0 |
| loads.load_id | 85,410 | 85,410 | 0 | 0 |
| maintenance_records.maintenance_id | 2,920 | 2,920 | 0 | 0 |
| routes.route_id | 58 | 58 | 0 | 0 |
| safety_incidents.incident_id | 170 | 170 | 0 | 0 |
| trailers.trailer_id | 180 | 180 | 0 | 0 |
| trips.trip_id | 85,410 | 85,410 | 0 | 0 |
| trucks.truck_id | 120 | 120 | 0 | 0 |

### 4.2 Foreign-key integrity

All **18 unique relationships** had zero orphan references in the observed extract.

| Child reference | Parent reference | Rows | NULL references | Orphans |
|---|---|---:|---:|---:|
| trips.driver_id | drivers.driver_id | 85,410 | 1,714 | 0 |
| trips.load_id | loads.load_id | 85,410 | 0 | 0 |
| trips.truck_id | trucks.truck_id | 85,410 | 1,672 | 0 |
| trips.trailer_id | trailers.trailer_id | 85,410 | 1,680 | 0 |
| loads.customer_id | customers.customer_id | 85,410 | 0 | 0 |
| loads.route_id | routes.route_id | 85,410 | 0 | 0 |
| delivery_events.load_id | loads.load_id | 170,820 | 0 | 0 |
| delivery_events.trip_id | trips.trip_id | 170,820 | 0 | 0 |
| delivery_events.facility_id | facilities.facility_id | 170,820 | 0 | 0 |
| fuel_purchases.driver_id | drivers.driver_id | 196,442 | 3,988 | 0 |
| fuel_purchases.truck_id | trucks.truck_id | 196,442 | 3,880 | 0 |
| maintenance_records.truck_id | trucks.truck_id | 2,920 | 0 | 0 |
| safety_incidents.driver_id | drivers.driver_id | 170 | 1 | 0 |
| safety_incidents.truck_id | trucks.truck_id | 170 | 1 | 0 |
| safety_incidents.trip_id | trips.trip_id | 170 | 0 | 0 |
| driver_monthly_metrics.driver_id | drivers.driver_id | 4,464 | 0 | 0 |
| truck_utilization_metrics.truck_id | trucks.truck_id | 3,312 | 0 | 0 |
| fuel_purchases.trip_id | trips.trip_id | 196,442 | 0 | 0 |

The seven child columns containing NULL references were already identified during the general Bronze NULL profiling. The relationship checks did not identify any additional NULL-bearing columns. These NULLs should not automatically be classified as errors; their meaning must be established from source/business rules before Silver-layer handling.

### 4.3 Business identifiers

| Business identifier | Rows | Distinct | Duplicate occurrences | Assessment |
|---|---:|---:|---:|---|
| drivers.license_number | 150 | 150 | 0 | Unique in extract |
| fuel_purchases.fuel_card_number | 196,442 | 176,645 | 19,797 | Repeated values; consistent with card reuse across purchases, but confirm the business rule |
| trailers.trailer_number | 180 | 176 | 4 | Four repeated occurrences; investigated below |
| trailers.vin | 180 | 180 | 0 | Unique in extract |
| trucks.unit_number | 120 | 120 | 0 | Unique in extract |
| trucks.vin | 120 | 120 | 0 | Unique in extract |

Duplicate occurrences are calculated as non-NULL values minus distinct non-NULL values. They are not necessarily the number of duplicated groups.

### 4.4 Trailer-number investigation

Four trailer numbers each appeared twice and mapped to two different trailer IDs and VINs:

| Trailer number | Trailer ID | VIN | Status | Type | Model year |
|---|---|---|---|---|---:|
| 2791 | TRL00046 | 1AT416301915343103 | Active | Refrigerated | 2023 |
| 2791 | TRL00096 | 1BV585623495338920 | Active | Dry Van | 2017 |
| 6620 | TRL00079 | 1BV367959048807113 | Active | Refrigerated | 2016 |
| 6620 | TRL00095 | 1BV790905555865061 | Active | Dry Van | 2024 |
| 7703 | TRL00025 | 1AT519104629229467 | Active | Dry Van | 2015 |
| 7703 | TRL00177 | 1AT732143483864478 | Active | Dry Van | 2017 |
| 9796 | TRL00044 | 1CU404484784600217 | Active | Refrigerated | 2018 |
| 9796 | TRL00122 | 1AU139100155215109 | Active | Refrigerated | 2020 |

Each repeated number belongs to two different trailer records with different VINs. The extract alone does not establish whether these are legitimate number reassignments or source-data issues. Do not treat `trailer_number` as a unique key until its business definition and effective-date rules are confirmed.

### 4.5 Composite candidate keys

The original checks observed:

| Candidate grain | Rows | Distinct combinations | Duplicate combinations |
|---|---:|---:|---:|
| driver_monthly_metrics: (driver_id, month) | 4,464 | 4,464 | 0 |
| truck_utilization_metrics: (truck_id, month) | 3,312 | 3,312 | 0 |

The original queries used `COUNT(DISTINCT CONCAT(...))`. The committed investigation script instead uses grouped duplicate detection and separately counts NULL key components. Run the updated checks to validate both uniqueness and key completeness.

## 5. Interpretation and Silver-layer considerations

1. The 12 candidate primary identifiers passed non-NULL and uniqueness checks in the current extract.
2. All 18 tested relationships resolved without orphan references. NULL foreign-key values remain a separate business-rule question.
3. The repeated fuel-card values should be treated as a non-unique business identifier unless the source owner confirms otherwise.
4. Trailer numbers are not unique in the current extract. Preserve the stable trailer ID as the row identifier; investigate whether trailer numbers can be reassigned or reused before defining a business key.
5. Driver-month and truck-month appear unique at their observed grains. Confirm the NULL-component checks when rerunning the updated script.
6. These checks validate the current extract only. They do not enforce referential integrity or guarantee future source files will satisfy the same conditions.

## 6. Re-execution checklist

1. Confirm the intended database is `LogisticsAnalytics` and the Bronze tables are loaded.
2. Run [`profile_identifier.sql`](../../scripts/bronze/profile_identifier.sql). Confirm it returns all 36 configured identifier columns.
3. Run [`investigate_identifier_integrity.sql`](../../scripts/bronze/investigations/investigate_identifier_integrity.sql).
4. Confirm 12 candidate-key rows, 18 FK relationship rows, and 6 business-identifier rows are returned.
5. Check that the FK orphan counts remain zero and review NULL counts separately.
6. Review the trailer-number duplicate records and the composite-key duplicate/NULL-component outputs.
7. If results differ from this document, investigate the difference and update the documented results rather than assuming the prior figures still apply.

## 7. Limitations

- The checks use the current Bronze extract and do not inspect source-system constraint definitions.
- Candidate primary keys and relationships are inferred from the dataset structure and tested values; formal PK/FK constraints were not verified.
- No external source was used to determine whether trailer-number reuse is legitimate.
- Repeated fuel-card values are consistent with repeated purchases using the same card, but that interpretation requires business confirmation.
- The reusable profile script reports exact distinct counts; on very large datasets, exact distinct counting may be more expensive than approximate alternatives.
