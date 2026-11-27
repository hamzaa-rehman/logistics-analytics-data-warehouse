# Logistics Analytics Data Warehouse

**A SQL Server data warehouse project that transforms raw logistics operations data into a validated dimensional model and eight business-focused reporting views.**

[Repository](https://github.com/hamzaa-rehman/logistics-analytics-data-warehouse) · [Architecture](docs/diagrams/Logistics_Data_Warehouse_Architecture%20%281%29.png) · [Gold reporting views](docs/gold/gold_reporting_views.md) · [Gold data dictionary](docs/gold/gold_data_dictionary.md) · [Validation evidence](docs/gold/gold_validation.md)

---

## Project at a glance

| Project component | Implemented result |
|---|---:|
| Source tables | **14** |
| Source records | **549,706** |
| Source columns | **150** |
| Warehouse layers | **Bronze, Silver, Gold** |
| Silver primary keys / foreign keys | **14 / 18** |
| Gold dimensions | **7** |
| Gold fact tables | **6** |
| Gold fact records | **541,172** |
| Gold fact-to-dimension relationships | **18** |
| Gold reporting views | **8** |
| Gold fact row-count and selected-measure reconciliation | **6 of 6 fact tables passed** |

This project develops a multi-table logistics dataset into a structured SQL Server analytics platform. It covers the engineering work required to make operational data usable for reporting: ingestion, profiling, investigation, data-type standardisation, relational modelling, dimensional design, reporting-layer development, and validation.

**Implementation boundary:** The SQL warehouse, Gold dimensional model, full-refresh loading procedures, and eight reporting views are implemented. The Power BI semantic model and dashboards are the planned downstream consumption layer and are not presented as completed work.

## Problem statement

Logistics operations depend on connected business processes: customer orders and loads, trips, pickup and delivery events, fleet assets, fuel purchases, maintenance activities, and safety incidents. These processes generate data at different levels of detail and often store related information in separate operational tables.

Simply having the data does not provide a reliable basis for management reporting. Without a structured analytical data platform, an organisation can struggle to answer basic operational and financial questions consistently. Joining records at incompatible levels of detail can multiply measures; incomplete asset and personnel assignments can distort attribution; inconsistent KPI definitions can produce misleading comparisons; and unexamined source values can be mistaken for valid business measures.

**The core problem this project addresses is:**

> How can raw, fragmented logistics operations data be transformed into a traceable, structurally reliable, and business-oriented analytical platform that supports consistent reporting while preserving the original data, controlling data-quality risks, and making the limits of the available evidence explicit?

This is a portfolio implementation using the dataset identified in the repository as the Logistics Operations Database. It is not a deployment for a named logistics company, and the project does not claim to have gathered requirements from real business stakeholders.

## Project objective

Design and implement an end-to-end SQL Server data warehouse that:

1. **Preserves source data** so that downstream transformations and findings can be traced back to the original extract.
2. **Profiles and investigates data quality** before deciding how source values should be typed, related, or interpreted.
3. **Creates a reliable relational layer** with explicit data types, keys, controlled NULL handling, and validated relationships.
4. **Builds an analytical dimensional model** around distinct logistics business processes and their natural grains.
5. **Defines reusable reporting datasets** with documented grains, measures, joins, KPI rules, and aggregation safeguards.
6. **Validates the implementation** through structural checks, key and relationship tests, row-count reconciliation, and selected measure-level comparisons.
7. **Documents limitations** so that downstream analysis does not claim more than the data can support.

### Business questions the warehouse is designed to support

| Business area | Questions the data can help investigate | Reporting foundation |
|---|---|---|
| Load revenue | How does reported load revenue vary over time, by customer, route, load type, or booking type? | Revenue Performance; Customer Performance |
| Delivery service | What proportion of Delivery events are on time? How does performance vary by period? How does detention relate to the on-time flag? | Delivery Performance |
| Fleet activity | How many trips are recorded? What distance and fuel consumption are associated with them? How does weighted MPG vary across the fleet? | Fleet Performance |
| Customer performance | Which customers generate recorded load activity and revenue? How concentrated is revenue across customers? | Customer Performance |
| Fuel purchasing | How much fuel is purchased, what cost is recorded, and how complete are truck and driver assignments? | Fuel Cost Analysis |
| Maintenance | What maintenance activity, recorded cost, and downtime appear in the available records? | Maintenance Performance |
| Safety | How are incidents classified? What injury, preventability, and damage fields are recorded? | Safety Performance |
| Truck-level cost comparison | How do independently aggregated trip, fuel-purchase, and maintenance measures compare by truck? | Truck Cost Efficiency |

These are analytical questions supported to varying degrees by the source. They are not claims that every operational decision can be answered. For example, the data does not provide a reliable denominator for true fleet utilisation, and recorded spend per mile is not verified profitability.

## Solution overview and architecture

The warehouse follows the Medallion Architecture. Each layer has a defined responsibility and a separate validation purpose.

![Logistics Analytics Data Warehouse architecture](docs/diagrams/Logistics_Data_Warehouse_Architecture%20%281%29.png)

| Layer | Purpose | Implemented design |
|---|---|---|
| **Bronze** | Preserve the source extract | 14 raw tables; all 150 columns stored as VARCHAR; full-refresh ingestion; metadata-driven profiling |
| **Silver** | Standardise and establish relational integrity | 14 typed tables; explicit source-to-target mappings; 14 primary keys; 18 foreign keys; transactional full-refresh load |
| **Gold** | Model business processes for analysis | 7 dimensions; 6 facts; surrogate keys; role-playing date relationships; 8 reporting views |

The flow is deliberate:

- Bronze retains the source representation and provides a stable point for profiling and investigation.
- Silver applies approved data types and targeted standardisation while preserving source entities and record grain.
- Gold organises the validated entities into facts and dimensions, then exposes subject-specific reporting datasets.
- BI tools can consume the Gold model and reporting views without rebuilding the core business logic in every report.

## Source dataset and inventory

The repository contains 14 CSV files identified as the **Logistics Operations Database** dataset from Kaggle. Together they contain **549,706 records across 150 columns**.

### Source table inventory

| Source table | Rows |
|---|---:|
| customers | 200 |
| drivers | 150 |
| facilities | 50 |
| routes | 58 |
| trucks | 120 |
| trailers | 180 |
| loads | 85,410 |
| trips | 85,410 |
| delivery_events | 170,820 |
| fuel_purchases | 196,442 |
| maintenance_records | 2,920 |
| safety_incidents | 170 |
| driver_monthly_metrics | 4,464 |
| truck_utilization_metrics | 3,312 |
| **Total** | **549,706** |

The tables cover master data, core load and trip operations, delivery events, fuel purchasing, maintenance, safety, and monthly driver/truck metrics.

Most transactional activity spans **1 January 2022 to 31 December 2024**. Delivery-event and fuel-purchase timestamps extend into **January 2025**, but that month is partial. The dataset also contains customer contract dates earlier than the observed load-history start date.

- [Dataset directory, source-file mapping, and configuration instructions](datasets/README.md)
- [14 source CSV files](datasets/logistics_operations_database/)
- [Bronze profiling configuration](datasets/profiling_config/bronze_profiling_config.csv)
- [Bronze data inventory workbook](docs/data_inventory/Logistics_Data_Inventory_Bronze.xlsx)

## Bronze layer — raw ingestion and data investigation

### Design

Bronze stores the 14 source tables with all 150 columns represented as VARCHAR. It preserves the imported textual values and does not intentionally apply business cleaning, deduplication, or type conversion.

The loading procedure maps each CSV file to its corresponding Bronze table and uses a full-refresh approach: each table is truncated and reloaded. The 14 table loads are performed one by one rather than within one transaction, so a failure partway through can leave the layer partially refreshed.

### Metadata-driven profiling

A project-maintained configuration classifies all 150 columns into six profiling groups:

| Profiling group | Configured columns |
|---|---:|
| CATEGORY | 39 |
| NUMERIC | 53 |
| IDENTIFIER | 36 |
| DATE | 11 |
| DATETIME | 4 |
| TEXT | 7 |
| **Total** | **150** |

Reusable SQL scripts profile completeness, distinct values, distributions, numeric ranges, date/time convertibility, identifier uniqueness, and text lengths. This profiling is supported by targeted investigation scripts and written findings; it is not limited to a single NULL-count check.

### Bronze validation and profiling findings

| Validation / profiling area | Recorded result |
|---|---|
| Expected source tables found | 14 of 14 |
| Loaded source records | 549,706 |
| Source columns | 150 |
| Bronze column data types | 150 VARCHAR columns |
| Initial structural validation | 14 of 14 tables passed |
| NULL values across all columns | 13,060 across 8 columns |
| Empty strings | 0 |
| Ordinary space-only values detected | 0 |
| Configured numeric columns convertible to DECIMAL(18,4) | 53 of 53; zero conversion failures |
| Configured identifier columns | 36 |

The 13,060 NULLs were concentrated in driver termination dates and optional truck, driver, and trailer assignments in fuel purchases, trips, and safety incidents. These values were investigated rather than automatically replaced.

Additional profiling and investigations informed downstream decisions, including:

- The source truck utilisation field was reconciled against trips completed per calendar day and found to represent a trips-per-day measure, not a utilisation percentage.
- The 50 negative facility longitude values were treated as potentially valid geographic coordinates, not automatically as errors.
- Four trailer numbers appeared against more than one trailer ID/VIN; the extract did not establish whether this was legitimate reuse or a source issue.
- Delivery detention was examined alongside event type, schedule deviation, and the on-time flag.
- Event-reported locations were compared with facility master data without assuming they must be identical.
- Safety incident financial fields and January 2025 fuel/delivery timestamps were investigated separately.

**Bronze validation scope:** these checks establish the tested table structure, source row counts, column counts, and profiling observations. They do not establish that every source value is correct or that every business definition is known.

- [Bronze layer documentation](docs/bronze/readme.md)
- [Profiling methodology and results](docs/bronze/)
- [Bronze investigations](docs/bronze/investigations/)
- [Bronze SQL implementation](scripts/bronze/)

## Silver layer — typed and relational data

### Design and transformation

Silver converts the raw VARCHAR representation into explicitly defined SQL Server data types while preserving all 14 source entities and their record grains. The loading procedure uses explicit target column lists and source mappings rather than relying on SELECT * or implicit column order.

Key design decisions include:

- Identifiers remain character values to preserve identifier semantics and leading zeros.
- Calendar dates use DATE; event timestamps use DATETIME2.
- Numeric fields use explicit integer or DECIMAL precision and scale; flags use BIT.
- Trimming and blank-to-NULL handling are applied selectively, especially to identifiers and nullable foreign keys.
- Non-empty values that fail strict conversion raise an error rather than silently becoming NULL.
- Optional relationships remain nullable; missing identifiers are not fabricated.
- Source rows are not deduplicated merely to make the model appear cleaner.

The Silver layer contains **549,706 rows across 14 tables**. Twelve tables have single-column primary keys; the driver-month and truck-month metric tables use composite primary keys to enforce their monthly grain.

### Silver relational integrity

- **14 primary keys** across the 14 Silver tables.
- **18 foreign-key relationships**, all documented as enabled and trusted.
- Composite keys enforce one record per driver/month and one record per truck/month.
- Nullable foreign keys preserve optional source relationships.

![Silver relational entity relationship diagram](docs/diagrams/silver_erd.png)

### Silver validation results

| Validation area | Executed result |
|---|---|
| Bronze-to-Silver row-count comparison | All 14 table counts matched; 549,706 rows in each layer |
| Primary-key validation | 0 NULL key rows and 0 duplicate key groups across 14 tables |
| Foreign-key orphan checks | 0 orphan rows across 18 relationships |
| Constraint status | 14 primary keys enabled; 18 foreign keys enabled and trusted |
| Two-way source-to-Silver key reconciliation | 28 directional checks; 0 issues |
| Targeted transformation checks | 3 checks; 0 mismatches |

The three targeted transformation checks covered the trips dispatch-date conversion, the mapping from source utilization_rate to Silver trips_per_day, and blank-to-NULL handling for fuel_purchases.truck_id.

These results demonstrate row-count, key, relationship, and selected transformation integrity. They do not claim that every non-key descriptive column has undergone a complete column-by-column comparison.

- [Silver layer documentation and table inventory](docs/silver/readme.md)
- [Silver ERD source](docs/diagrams/silver_erd.drawio)
- [Silver DDL](scripts/silver/ddl_silver.sql)
- [Silver transactional load procedure](scripts/silver/load_silver.sql)
- [Silver reset script](scripts/silver/reset_silver.sql)
- [Silver validation SQL](tests/validate_silver.sql)

## Gold layer — dimensional warehouse model

Gold organises the validated Silver data into a dimensional model based on six operational business processes. The implemented model contains **seven dimensions and six fact tables**.

### Dimensions

| Dimension | Purpose | Rows |
|---|---|---:|
| dim_customer | Customer identity and descriptive attributes | 200 |
| dim_date | Calendar and reporting-period attributes | 5,114 |
| dim_driver | Driver identity and descriptive attributes | 150 |
| dim_facility | Facility identity and location attributes | 50 |
| dim_route | Route identity, endpoints, and typical distance | 58 |
| dim_trailer | Trailer identity and descriptive attributes | 180 |
| dim_truck | Truck identity and descriptive attributes | 120 |

The date dimension covers **2012-01-01 through 2025-12-31**. It separates calendar year from ISO week-year so weekly reporting remains correct around calendar-year boundaries.

### Fact tables and their natural grains

| Fact table | Grain | Rows |
|---|---|---:|
| fact_loads | One row per load | 85,410 |
| fact_trips | One row per trip | 85,410 |
| fact_delivery_events | One row per pickup or delivery event | 170,820 |
| fact_fuel_purchases | One row per fuel purchase | 196,442 |
| fact_maintenance_records | One row per maintenance record | 2,920 |
| fact_safety_incidents | One row per safety incident | 170 |
| **Total** | **Six fact tables** | **541,172** |

Each fact retains its source business identifier and has a warehouse surrogate primary key. Dimension surrogate keys provide descriptive context. Optional entity assignments remain nullable where the source relationship is optional.

### Modelling decisions that matter

- **Different business processes remain separate.** Loads, trips, delivery events, fuel purchases, maintenance records, and safety incidents have different grains and are not flattened into one wide fact table.
- **No fact-to-fact foreign keys are created.** Source identifiers such as load_id and trip_id may be retained for traceability, but one fact is not treated as a dimension for another.
- **Role-playing dates are explicit.** Delivery events use separate scheduled-date and actual-date keys referencing dim_date.
- **Optional assignments are preserved.** Missing truck, driver, or trailer relationships are not replaced with invented dimension keys.
- **Routes are related to loads, not trips.** The source trip entity does not provide a route_id, so the model does not fabricate a trip-to-route relationship.
- **Location concepts are not conflated.** Event-reported location text is retained separately from facility master attributes. Maintenance facility_location and safety incident location fields are text, not facility foreign keys.
- **Monthly aggregate tables are not forced into transaction facts.** driver_monthly_metrics and truck_utilization_metrics remain in Silver; they are not implemented as standalone Gold facts in this model.
- **Current descriptive attributes are not historical snapshots.** The dimensions use Type 1 current attributes; the model does not claim slowly changing dimension history.

The Gold model contains 13 tables: seven dimensions and six facts. Its 18 fact-to-dimension foreign-key relationships are documented in the data dictionary and validation record.

- [Gold DDL](scripts/gold/ddl_gold.sql)
- [Gold full-refresh load procedure](scripts/gold/load_gold.sql)
- [Gold data dictionary and source-to-target mappings](docs/gold/gold_data_dictionary.md)
- [Gold relationship investigations and modelling decisions](docs/gold/gold_relationship_investigations.md)

## Gold reporting layer — eight analytical views

Eight subject-specific views expose the dimensional model through reusable reporting datasets. Each view has a documented purpose, source relationship strategy, row grain, measures, business definitions, and limitations.

![Gold reporting views overview](docs/diagrams/gold_reporting_views_overview.png)

| Reporting view | Row grain | Intended analysis |
|---|---|---|
| vw_revenue_performance | One row per load | Reported revenue, load characteristics, customer and route comparisons |
| vw_delivery_performance | One row per event | Pickup/delivery activity, delivery-only on-time KPI, detention |
| vw_fleet_performance | One row per trip | Trip activity, distance, fuel consumed, MPG, idle time |
| vw_customer_performance | One row per customer | Customer activity and reported revenue contribution |
| vw_fuel_cost_analysis | One row per fuel purchase | Purchased gallons, recorded fuel cost, unit price, assignment coverage |
| vw_maintenance_performance | One row per maintenance record | Maintenance activity, recorded costs, labour, downtime |
| vw_safety_performance | One row per incident | Incident classification, injury, preventability, recorded damage |
| vw_truck_cost_efficiency | One row per truck | Independent trip, fuel-purchase, and maintenance aggregates |

### Grain control and fanout prevention

The views intentionally do not share one common grain. A load, trip, delivery event, fuel purchase, maintenance record, incident, customer, and truck are different reporting entities. Joining raw fact tables directly can multiply records and inflate measures.

The customer view first aggregates load measures to customer grain. The truck cost view independently aggregates trip, fuel-purchase, and maintenance facts by truck before joining those summaries to the truck dimension.

![Fact fanout prevention through independent aggregation](docs/diagrams/fact_fanout_prevention.png)

This design preserves one row per customer or truck in those summary views and prevents cross-fact fanout from inflating the independently aggregated measures.

- [Reporting view specifications, grains, joins, and KPI rules](docs/gold/gold_reporting_views.md)
- [Reporting view SQL definitions](scripts/gold/views/)

## Business findings and KPI definitions

The investigations established business definitions and documented observed patterns before the reporting layer was finalised. The findings below are descriptive results from the supplied dataset, not causal explanations.

### Delivery performance

**Approved definition:** On-Time Delivery Rate = on-time Delivery events divided by all Delivery events. Pickup events are excluded from both numerator and denominator.

| Complete year | Delivery events | On-time deliveries | On-time rate |
|---|---:|---:|---:|
| 2022 | 28,489 | 12,730 | 44.68% |
| 2023 | 28,178 | 12,555 | 44.56% |
| 2024 | 28,657 | 12,783 | 44.61% |

The reviewed full-year results show a stable on-time delivery rate of approximately 44.6%. January 2025 contains 86 Delivery events and is partial; its 39.53% observed rate must not be compared with complete years as if it were a full period.

The detention investigation observed that events marked on time generally fell within an approximate ±120-minute window. This is an observed association in the supplied data, not proof of causation or an approved operational threshold.

### Revenue and customer performance

- The dataset contains **85,410 loads**, all with a recorded revenue value.
- Total reported load revenue is **262,525,800.29** in source currency units; the currency is not confirmed.
- Fuel surcharge and accessorial charges remain separate measures. The source accounting definition does not establish whether they are already included in reported revenue, so they are not automatically added to create a new total-revenue figure.
- All **200 customers** have recorded load activity in the observed period.
- The top 20 customers account for **11.20%** of reported load revenue.
- The earliest observed load history begins in January 2022, while customer contract dates extend earlier. First observed load date is therefore not a verified customer acquisition date.

### Fleet and fuel

- There are **85,410 trips**. A total of **1,672 trips** have no recorded truck assignment; these remain in overall trip measures but cannot be attributed to a specific truck.
- Weighted fleet MPG, calculated as total actual trip distance divided by total trip fuel consumed, is approximately **6.448**. It is not the same as a simple average of per-trip MPG.
- Fuel purchases total **24,519,037.80 gallons** and **95,592,992.04** in recorded source cost units.
- **2,478 fuel purchase records** have a one-cent difference between recorded total cost and the rounded gallons-times-price calculation. The recorded source total is preserved.
- Fuel purchased is not the same measure as fuel consumed on trips. A difference between the two does not, by itself, prove fuel loss, wastage, or theft.

### Maintenance and safety

The source contains **2,920 maintenance records** and **170 safety incidents**. The investigations examine maintenance cost and downtime, incident categories, injury and preventability flags, damage and claim amounts, and missing truck/driver attribution. Unknown safety flags remain unknown rather than being treated as FALSE. Claim amount is not added again to vehicle and cargo damage components.

### Important analytical limitations

- **Fleet utilisation:** a true utilisation percentage is not calculated because the dataset does not provide a reliable available-time or available-capacity denominator. The source utilisation_rate field was investigated and mapped to trips_per_day.
- **Truck cost efficiency:** combined recorded fuel-purchase and maintenance spend per actual mile is a descriptive comparison proxy, not verified operating cost per mile or profitability. Purchase and maintenance timing may not correspond exactly to the trips in the same calendar period.
- **Currency:** the source does not confirm a currency. Financial amounts are shown without a currency symbol or currency name.
- **Partial period:** January 2025 delivery and fuel activity is incomplete and must be labelled accordingly.
- **Missing assignments:** absent truck, driver, or trailer references remain visible and are not silently attributed.
- **Location differences:** event-reported, maintenance, incident, and facility master locations are not assumed to be interchangeable.
- **Historical attributes:** Gold descriptive dimensions represent current Type 1 attributes, not historical versions of driver, truck, customer, or other master records.

The detailed query results, definitions, investigation notes, and decisions are maintained in [Gold KPI Investigations](docs/gold/gold_kpi_investigations.md).

## Validation and reconciliation

Validation is performed at each layer. A successful load is not treated as proof of data correctness. The checks below distinguish structural validation, key and relationship integrity, row-count preservation, selected measure preservation, and reporting-view grain checks.

### Cross-layer validation scorecard

| Layer | Validation area | Recorded result |
|---|---|---|
| Bronze | Expected tables and initial structural checks | 14 of 14 tables passed |
| Bronze | Loaded source data | 549,706 rows across 150 VARCHAR columns |
| Bronze | NULL / empty / ordinary whitespace profiling | 13,060 NULLs across 8 columns; 0 empty strings; 0 ordinary space-only values detected |
| Silver | Bronze-to-Silver row counts | 14 of 14 tables matched; 549,706 rows |
| Silver | Primary-key integrity | 14 primary keys; 0 NULL key rows; 0 duplicate key groups |
| Silver | Foreign-key orphan checks | 18 of 18 relationships; 0 orphan rows |
| Silver | Constraint status | 14 primary keys enabled; 18 foreign keys enabled and trusted |
| Silver | Source-to-Silver key reconciliation | 28 directional checks; 0 issues |
| Silver | Targeted transformation checks | 3 checks; 0 mismatches |
| Gold | Primary-key structure | 13 of 13 tables have enabled single-column primary keys |
| Gold | Foreign-key orphan and constraint checks | 18 of 18 relationships passed; all enabled and trusted |
| Gold | Source-backed dimension row counts | 6 of 6 matched |
| Gold | Fact business-key uniqueness | 6 of 6 fact tables passed; 541,172 unique non-NULL keys |
| Gold | Silver-to-Gold fact row counts | 6 of 6 matched; 541,172 rows |
| Gold | Selected measure-level reconciliation | 6 of 6 fact tables; 541,172 matched records; 0 missing records; 0 selected-measure mismatches |
| Gold | Date dimension and ISO week-year | 5,114 dates; 0 tested ISO week-year mismatches; 0 NULL ISO week-years |
| Gold reporting | Subject-specific reporting views | 8 implemented; view-specific grain and measure checks documented and executed |

### What the Gold measure reconciliation establishes

The reconciliation uses source business identifiers to compare Silver and Gold records in both directions. It checks for missing records and compares selected measures row by row, including NULL-to-NULL handling.

The selected measures cover load weights and financial fields, trip distance and fuel measures, fuel-purchase quantities and costs, maintenance costs and downtime, safety financial fields, and delivery detention/on-time fields.

**Interpretation:** the checks demonstrate preservation of the selected Silver measures into Gold for all 541,172 fact records. They do not prove that every source business calculation is intrinsically correct or that every descriptive attribute across all tables has been exhaustively reconciled.

- [Gold validation record and detailed results](docs/gold/gold_validation.md)
- [Gold structural and fact validation SQL](scripts/gold/validate_gold.sql)
- [Silver-to-Gold measure reconciliation SQL](scripts/gold/reconcile_gold_measures.sql)
- [Bronze validation SQL](tests/validate_bronze.sql)
- [Silver validation SQL](tests/validate_silver.sql)
- [Reporting-view validation details](docs/gold/gold_reporting_views.md)

## Technology

| Technology | Role |
|---|---|
| **Microsoft SQL Server** | Relational database and warehouse platform |
| **T-SQL** | DDL, loading procedures, transformations, profiling, investigations, views, and validation |
| **DBeaver** | SQL development and execution environment |
| **Docker** | Local SQL Server development environment |
| **Git and GitHub** | Version control and project documentation |
| **Draw.io** | Architecture and entity-relationship diagrams |
| **Excel** | Source data inventory and profiling workbook |
| **Power BI** | Planned downstream semantic model and dashboard layer |

## Repository guide

| Directory / file | Contents |
|---|---|
| datasets/ | 14 source CSV files, source notes, and profiling configuration |
| docs/bronze/ | Bronze design, profiling methodology, results, and investigations |
| docs/silver/ | Silver schema, ERD, transformation decisions, and validation |
| docs/gold/ | Gold data dictionary, relationship investigations, KPI findings, reporting-view specifications, and validation evidence |
| docs/diagrams/ | Architecture, Silver ERD, reporting architecture, coverage, grain, and fanout diagrams |
| docs/data_inventory/ | Bronze data inventory workbook |
| scripts/bronze/ | Bronze DDL, loading, profiling, and investigation SQL |
| scripts/silver/ | Silver DDL, transactional loading, and reset SQL |
| scripts/gold/ | Gold DDL, loading, validation, reconciliation, investigations, and reporting views |
| tests/ | Bronze and Silver validation SQL |

### Key implementation files

| Purpose | File |
|---|---|
| Bronze schema | [ddl_bronze.sql](scripts/bronze/ddl_bronze.sql) |
| Bronze ingestion | [load_bronze.sql](scripts/bronze/load_bronze.sql) |
| Bronze profiling configuration | [profiling_config.sql](scripts/bronze/profiling_config.sql) |
| Silver schema | [ddl_silver.sql](scripts/silver/ddl_silver.sql) |
| Silver transformation and load | [load_silver.sql](scripts/silver/load_silver.sql) |
| Gold dimensional schema and date dimension | [ddl_gold.sql](scripts/gold/ddl_gold.sql) |
| Gold dimensional load | [load_gold.sql](scripts/gold/load_gold.sql) |
| Gold structural validation | [validate_gold.sql](scripts/gold/validate_gold.sql) |
| Gold measure reconciliation | [reconcile_gold_measures.sql](scripts/gold/reconcile_gold_measures.sql) |
| Gold reporting view definitions | [scripts/gold/views/](scripts/gold/views/) |

## Running the project

This repository contains SQL Server scripts and source files; it is not a one-click deployment package. Execution requires a SQL Server instance and source files in a directory accessible to that SQL Server instance.

### Recommended execution sequence

1. Review the source-file mapping and confirm that all 14 CSV files are available.
2. Create the Bronze schema and raw tables using the Bronze DDL.
3. Review the source-folder path in the Bronze load script, then execute the Bronze load.
4. Run Bronze structural validation.
5. Create the profiling configuration table, import the 150 metadata rows, and run the profiling scripts and relevant investigations.
6. Create the Silver schema and tables using the Silver DDL.
7. Execute the Silver full-refresh load procedure and run Silver validation.
8. Create the Gold dimensions and facts using the Gold DDL. The script also populates and validates the date dimension.
9. Execute the Gold full-refresh load procedure.
10. Create the eight Gold reporting views using the individual scripts under scripts/gold/views/.
11. Run Gold structural validation and Silver-to-Gold measure reconciliation.
12. Review the KPI definitions, reporting grains, and limitations before connecting a BI tool.

### Execution precautions

- Read each script before running it and follow its documented execution order.
- The Bronze DDL drops and recreates existing Bronze tables. The Bronze, Silver, and Gold reset scripts are destructive to their respective layers; use them only when a rebuild is intended.
- The Bronze load procedure truncates and reloads its tables one by one and does not wrap all 14 table loads in one transaction. A failure partway through can leave Bronze partially refreshed.
- The Silver load is transactional: a failure rolls back the refresh rather than leaving a committed partial load.
- The Gold load is also transactional and performs a full refresh; it is not an incremental or change-data-capture pipeline.
- Confirm the CSV path and permissions from the SQL Server service/container perspective. A path on the host machine is not automatically visible inside a Docker container.
- The scripts may require database-context, file-path, or permission adjustments for another SQL Server environment.

## Detailed documentation

The README provides the project overview. The following documents contain the implementation detail and evidence:

- [Dataset notes and source mapping](datasets/README.md)
- [Bronze layer design, profiling, and validation](docs/bronze/readme.md)
- [Silver layer design, transformations, and validation](docs/silver/readme.md)
- [Gold data dictionary and source-to-target mappings](docs/gold/gold_data_dictionary.md)
- [Gold relationship investigations and modelling decisions](docs/gold/gold_relationship_investigations.md)
- [Gold KPI investigations and business rules](docs/gold/gold_kpi_investigations.md)
- [Gold reporting views: grains, joins, measures, and validation](docs/gold/gold_reporting_views.md)
- [Gold validation and reconciliation record](docs/gold/gold_validation.md)

## Scope and limitations

This is an analytical data warehouse built over the supplied dataset, not a live production logistics system. The repository does not implement incremental ingestion, orchestration, automated scheduling, streaming, a production deployment pipeline, or a completed Power BI semantic model and dashboard.

The two monthly metric source tables are retained in Silver but are not standalone Gold facts in the implemented model. Gold dimensions use Type 1 current attributes rather than historical slowly changing dimension records. No true fleet utilisation percentage, verified customer acquisition date, confirmed currency, or profitability measure is claimed where the source does not support it.

The dataset also contains missing operational assignments, partial January 2025 activity, and location fields whose meanings are not fully interchangeable. These limitations are carried into the reporting documentation so that downstream analysis can qualify its conclusions rather than conceal uncertainty.

## Source attribution and licence

The source files are identified in this project as the **Logistics Operations Database** dataset from Kaggle. Consult the original dataset listing and its applicable licence and usage terms before reusing or redistributing the source data.

The repository's [MIT License](LICENSE) applies to the project code and documentation to the extent permitted. It does not replace or override the source dataset's licence or usage conditions.

---

**The intended outcome is a traceable and validated foundation for logistics analysis: raw data is preserved, transformations are explicit, business processes retain their correct grain, reporting measures are protected from common modelling errors, and the limits of the available evidence remain visible.**
