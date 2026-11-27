# Gold Layer — Validation and Reconciliation Record

## 1. Purpose and validation scope

This document records the implemented Gold model's validation evidence for the `LogisticsAnalytics` database. It distinguishes structural integrity, fact-grain preservation, source-to-Gold row coverage, and selected measure preservation.

The repeatable SQL is maintained in:

- [Gold structural and fact validation SQL](../../scripts/gold/validate_gold.sql)
- [Gold measure reconciliation SQL](../../scripts/gold/reconcile_gold_measures.sql)

**Overall status:** The Gold structural, relationship, fact business-key, fact row-count, selected measure-reconciliation, and date-dimension checks documented here have passed based on SQL results executed and shared by the project owner. The eight Gold reporting views have since been implemented, validated, and documented in [Gold Reporting Views](gold_reporting_views.md). The Power BI semantic model and reports remain downstream work and are not represented as completed here.

**Database:** `LogisticsAnalytics`  
**Source layer:** `silver`  
**Target layer:** `gold`  
**Gold model:** 7 dimensions and 6 fact tables

## 2. Foreign-key integrity and constraint status

The Gold model contains 18 fact-to-dimension foreign-key relationships.

| Check | Result |
|---|---:|
| Relationships checked for orphan rows | 18 |
| Relationships with orphan rows | 0 |
| Foreign keys checked for enabled/trusted status | 18 |
| Disabled foreign keys | 0 |
| Untrusted foreign keys | 0 |

**Result: PASS.** All 18 relationships passed orphan-record validation, and all 18 foreign-key constraints were enabled and trusted.

NULL values in optional foreign-key columns are preserved by design and are not orphan records. Populated foreign-key values must resolve to a corresponding dimension row.

## 3. Primary-key validation

| Check | Result |
|---|---:|
| Gold tables | 13 |
| Tables with an enabled primary key | 13/13 |
| Primary-key columns per table | 1 |
| Composite primary keys | 0 |

**Result: PASS.** All seven dimensions and six fact tables have an enabled, single-column primary key.

## 4. Fact business-key and grain validation

Each fact table was checked for NULL business identifiers and duplicate business identifiers.

| Fact table | Business key | Rows | Distinct keys | NULL keys | Duplicate key rows |
|---|---|---:|---:|---:|---:|
| `fact_delivery_events` | `event_id` | 170,820 | 170,820 | 0 | 0 |
| `fact_fuel_purchases` | `fuel_purchase_id` | 196,442 | 196,442 | 0 | 0 |
| `fact_loads` | `load_id` | 85,410 | 85,410 | 0 | 0 |
| `fact_maintenance_records` | `maintenance_id` | 2,920 | 2,920 | 0 | 0 |
| `fact_safety_incidents` | `incident_id` | 170 | 170 | 0 | 0 |
| `fact_trips` | `trip_id` | 85,410 | 85,410 | 0 | 0 |
| **Total** | | **541,172** | **541,172** | **0** | **0** |

**Result: PASS.** Every fact table contains one row per distinct, non-NULL source business identifier, consistent with its documented grain.

## 5. Silver-to-Gold fact row-count reconciliation

Gold fact-table row counts were compared with their corresponding Silver source tables.

| Silver source | Gold fact | Silver rows | Gold rows | Difference |
|---|---|---:|---:|---:|
| `silver.delivery_events` | `gold.fact_delivery_events` | 170,820 | 170,820 | 0 |
| `silver.fuel_purchases` | `gold.fact_fuel_purchases` | 196,442 | 196,442 | 0 |
| `silver.loads` | `gold.fact_loads` | 85,410 | 85,410 | 0 |
| `silver.maintenance_records` | `gold.fact_maintenance_records` | 2,920 | 2,920 | 0 |
| `silver.safety_incidents` | `gold.fact_safety_incidents` | 170 | 170 | 0 |
| `silver.trips` | `gold.fact_trips` | 85,410 | 85,410 | 0 |
| **Total** | | **541,172** | **541,172** | **0** |

**Result: PASS.** All six Gold fact tables match their Silver source row counts exactly.

The date dimension is generated in Gold and is not expected to have a one-to-one Silver source-table row-count comparison.

## 6. Selected measure-level reconciliation

The script [`reconcile_gold_measures.sql`](../../scripts/gold/reconcile_gold_measures.sql) compares source and target records using their source business identifiers. It uses a full outer join to expose missing records on either side and an `EXCEPT` comparison to detect differences in the selected measures for matched records. The row-level comparison also handles NULL-to-NULL values as equal.

The six executed result sets reported:

| Gold fact table | Selected measures compared | Source rows | Gold rows | Matched rows | Missing in Gold | Missing in Silver | Measure mismatches |
|---|---|---:|---:|---:|---:|---:|---:|
| `fact_loads` | Weight, pieces, revenue, fuel surcharge, accessorial charges | 85,410 | 85,410 | 85,410 | 0 | 0 | 0 |
| `fact_trips` | Distance, duration, fuel used, average MPG, idle time | 85,410 | 85,410 | 85,410 | 0 | 0 | 0 |
| `fact_fuel_purchases` | Gallons, price per gallon, total cost | 196,442 | 196,442 | 196,442 | 0 | 0 | 0 |
| `fact_maintenance_records` | Labour hours/cost, parts cost, total cost, downtime | 2,920 | 2,920 | 2,920 | 0 | 0 | 0 |
| `fact_safety_incidents` | Vehicle damage cost, cargo damage cost, claim amount | 170 | 170 | 170 | 0 | 0 | 0 |
| `fact_delivery_events` | Detention minutes, on-time flag | 170,820 | 170,820 | 170,820 | 0 | 0 | 0 |
| **Total** | **Selected measures across six fact processes** | **541,172** | **541,172** | **541,172** | **0** | **0** | **0** |

**Result: PASS.** All 541,172 fact records matched between Silver and Gold, and every selected measure compared by the script matched row by row.

This is a preservation test: it demonstrates that the selected Silver values were carried into Gold unchanged. It does not independently prove that every upstream source value or business calculation is intrinsically correct. It also does not claim that every descriptive or non-measure column in all Gold tables has been individually reconciled.

### Measure semantics retained

- Fuel purchased in `fact_fuel_purchases` remains distinct from fuel consumed on trips in `fact_trips`.
- `average_mpg` and `price_per_gallon` are rates, not additive measures; row-level preservation does not make them suitable for summation.
- Source NULLs are not replaced with zero during reconciliation.
- No cross-fact joins are used in the reconciliation script.
- The validation checks preservation, not the economic correctness of source calculations such as `total_cost`.

## 7. Date dimension and ISO week-year validation

The Gold date dimension covers **2012-01-01 through 2025-12-31**, inclusive, and contains **5,114 dates**.

The date dimension keeps two separate concepts:

- `year_number`: calendar year of `full_date`.
- `iso_week_year`: ISO week-numbering year associated with `week_of_year`.

The ISO week-year is derived using the Thursday of the ISO week, independently of the session's `DATEFIRST` setting. This prevents incorrect weekly grouping around calendar-year boundaries.

The project owner executed the migration against the existing database and supplied these boundary results:

| Full date | Calendar year | ISO week | ISO week-year |
|---|---:|---:|---:|
| 2021-01-01 | 2021 | 53 | 2020 |
| 2021-01-04 | 2021 | 1 | 2021 |
| 2024-12-30 | 2024 | 1 | 2025 |
| 2024-12-31 | 2024 | 1 | 2025 |
| 2025-01-01 | 2025 | 1 | 2025 |

Full-dimension validation returned **5,114 total dates, 0 ISO week-year mismatches, and 0 NULL ISO week-years**.

**Result: PASS.** The existing database's `dim_date` ISO week-year values were verified. The canonical [Gold DDL](../../scripts/gold/ddl_gold.sql) now creates, populates, and validates `iso_week_year` directly for future Gold builds.

## 8. Validation interpretation and limits

The evidence above supports the following conclusions:

1. Gold primary and foreign-key constraints are deployed and validated.
2. All 18 declared fact-to-dimension relationships passed orphan checks and are enabled/trusted.
3. Each fact table preserves its intended one-row-per-source-business-key grain for the tested data.
4. All six Gold fact row counts match their Silver source tables.
5. The selected measures in the reconciliation script were preserved row by row across all 541,172 fact records.
6. The date dimension's ISO week-year values are correct across the tested full date range, including the supplied year-boundary cases.

The checks do **not** establish that every source business rule is correct, that all descriptive attributes have been exhaustively reconciled, or that future reporting calculations are automatically correct. The eight Gold reporting views apply the approved KPI definitions, aggregation grains, NULL treatment, and fanout-prevention strategies documented in [Gold Reporting Views](gold_reporting_views.md). Those principles must continue to be preserved in the Power BI semantic model and reports, which require their own validation.

## 9. Downstream work

The Gold structural and selected measure-preservation validation milestone is complete. The eight subject-specific Gold reporting views have also been implemented, validated, and documented. The next development stage is Power BI:

- Build the semantic model using the approved Gold reporting views and dimensional model.
- Define and validate report measures against the approved KPI definitions and aggregation grains.
- Design the report pages and visuals for the revenue, delivery, fleet, customer, fuel, maintenance, safety, and truck cost subjects.
- Test relationships, filter behaviour, totals, NULL handling, and the treatment of partial January 2025 data.

These are downstream reporting deliverables, not outstanding Gold structural or measure-reconciliation checks.

## 10. Related artifacts

- [Gold DDL](../../scripts/gold/ddl_gold.sql)
- [Gold loading procedure](../../scripts/gold/load_gold.sql)
- [Gold structural and fact validation SQL](../../scripts/gold/validate_gold.sql)
- [Gold measure reconciliation SQL](../../scripts/gold/reconcile_gold_measures.sql)
- [Gold data dictionary and mapping specification](gold_data_dictionary.md)
- [Gold KPI investigations and business rules](gold_kpi_investigations.md)
- [Gold relationship investigations and modelling decisions](gold_relationship_investigations.md)
- [Gold Reporting Views](gold_reporting_views.md)
