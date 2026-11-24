# Gold Layer Validation Record

## 1. Purpose and status

This document records the Gold structural and row-count validation results reviewed during the initial Gold data-load milestone. The SQL used for repeatable checks is maintained in [validate_gold.sql](../../scripts/gold/validate_gold.sql).

**Current status:** Gold tables have been loaded. The structural, relationship, fact business-key, and fact row-count checks listed below have passed based on results shared by the project owner. Measure-level source-to-Gold reconciliation has not yet been completed; therefore, this is not the final Gold validation sign-off.

**Database:** `LogisticsAnalytics`  
**Source:** `silver`  
**Target:** `gold`

## 2. Foreign-key validation

The Gold model contains 18 fact-to-dimension foreign-key relationships.

| Check | Result |
|---|---:|
| Foreign-key relationships checked for orphan rows | 18 |
| Relationships with orphan rows | 0 |
| Foreign keys checked for constraint status | 18 |
| Disabled foreign keys | 0 |
| Untrusted foreign keys | 0 |

**Result:** All 18 foreign-key relationships passed both orphan-record validation and enabled/trusted constraint validation.

NULL values in optional foreign-key columns are preserved by design and are not counted as orphan records. Populated foreign-key values must resolve to a dimension row.

## 3. Primary-key validation

| Check | Result |
|---|---:|
| Gold tables | 13 |
| Primary keys present and enabled | 13/13 |
| Primary-key columns per table | 1 |
| Composite primary keys | 0 |

All seven dimensions and six fact tables have an enabled primary key. The primary-key inventory confirmed one key column per table.

## 4. Fact business-key and grain checks

Each fact table was checked for NULL business identifiers and duplicate business identifiers.

| Fact table | Business key | Rows | Distinct keys | NULL keys | Duplicate key rows |
|---|---|---:|---:|---:|---:|
| fact_delivery_events | event_id | 170,820 | 170,820 | 0 | 0 |
| fact_fuel_purchases | fuel_purchase_id | 196,442 | 196,442 | 0 | 0 |
| fact_loads | load_id | 85,410 | 85,410 | 0 | 0 |
| fact_maintenance_records | maintenance_id | 2,920 | 2,920 | 0 | 0 |
| fact_safety_incidents | incident_id | 170 | 170 | 0 | 0 |
| fact_trips | trip_id | 85,410 | 85,410 | 0 | 0 |
| **Total** | | **541,172** | **541,172** | **0** | **0** |

**Result:** All six fact tables contain one row per distinct, non-NULL source business identifier. This is consistent with their documented intended grains.

## 5. Fact row-count reconciliation

Gold fact-table row counts were compared directly with their corresponding Silver source tables.

| Silver source | Gold fact | Silver rows | Gold rows | Difference |
|---|---|---:|---:|---:|
| delivery_events | fact_delivery_events | 170,820 | 170,820 | 0 |
| fuel_purchases | fact_fuel_purchases | 196,442 | 196,442 | 0 |
| loads | fact_loads | 85,410 | 85,410 | 0 |
| maintenance_records | fact_maintenance_records | 2,920 | 2,920 | 0 |
| safety_incidents | fact_safety_incidents | 170 | 170 | 0 |
| trips | fact_trips | 85,410 | 85,410 | 0 |
| **Total** | | **541,172** | **541,172** | **0** |

**Result:** All six fact tables match their Silver source row counts exactly.

The date dimension is generated in Gold and is not expected to have a one-to-one Silver source-table row-count comparison.

## 6. Remaining validation

The following work remains before Gold can receive final validation sign-off:

- Measure-level reconciliation between Silver and Gold using the approved source-to-target mappings.
- Review and document any differences discovered during measure reconciliation.

Measure reconciliation must respect measure semantics. Additive amounts and quantities can generally be compared using appropriate totals, while ratios, averages, and unit rates (for example, average MPG and price per gallon) require separate validation rather than indiscriminate SUM comparisons.

After measure reconciliation is complete, update this record and the Gold data dictionary. Reporting views and Power BI development follow the Gold validation sign-off.

## 7. Related artifacts

- [Gold validation SQL](../../scripts/gold/validate_gold.sql)
- [Gold DDL](../../scripts/gold/ddl_gold.sql)
- [Gold load procedure](../../scripts/gold/load_gold.sql)
- [Gold data dictionary and mapping specification](gold_data_dictionary.md)
- [Gold KPI investigations](gold_kpi_investigations.md)
- [Gold relationship investigations](gold_relationship_investigations.md)
