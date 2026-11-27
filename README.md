# Logistics Analytics Data Warehouse
A SQL Server data warehouse project using the Medallion Architecture (Bronze, Silver, Gold) to prepare logistics operations data for business analytics. Bronze ingestion and profiling, Silver transformation and validation, and Gold dimensional modelling and full-refresh loading are implemented. Gold structural, relationship, fact-grain, row-count, and selected measure-preservation validations have passed across all six fact tables. Eight Gold reporting views have also been implemented and validated; Power BI reporting is the next development stage.

## Repository Structure

The tree below reflects the current repository contents. Bronze and Silver implementation and validation are complete. The Gold dimensional model, full-refresh loading procedure, and eight reporting views are implemented. Gold structural, relationship, fact business-key, row-count, and selected measure-reconciliation checks are complete; Power BI reporting remains planned.

```text
logistics-analytics-data-warehouse/
├── datasets/
│   ├── README.md
│   ├── logistics_operations_database/
│   │   ├── customers.csv
│   │   ├── delivery_events.csv
│   │   ├── driver_monthly_metrics.csv
│   │   ├── drivers.csv
│   │   ├── facilities.csv
│   │   ├── fuel_purchases.csv
│   │   ├── loads.csv
│   │   ├── maintenance_records.csv
│   │   ├── routes.csv
│   │   ├── safety_incidents.csv
│   │   ├── trailers.csv
│   │   ├── trips.csv
│   │   ├── truck_utilization_metrics.csv
│   │   └── trucks.csv
│   └── profiling_config/
│       └── bronze_profiling_config.csv
├── docs/
│   ├── bronze/
│   │   ├── readme.md
│   │   ├── category_profiling.md
│   │   ├── date_datetime_profiling.md
│   │   ├── identifier_profiling.md
│   │   ├── numeric_profiling.md
│   │   ├── text_profiling.md
│   │   └── investigations/
│   │       ├── detention_minutes_investigation.md
│   │       ├── geographic_consistency_investigation.md
│   │       ├── on_time_delivery_rate_investigation.md
│   │       ├── on_time_flag_investigation.md
│   │       ├── safety_incident_financials_investigation.md
│   │       └── truck_utilization_maintenance_investigation.md
│   ├── data_inventory/
│   │   └── Logistics_Data_Inventory_Bronze.xlsx
│   ├── diagrams/
│   │   ├── Logistics_Data_Warehouse_Architecture (1).drawio
│   │   ├── Logistics_Data_Warehouse_Architecture (1).png
│   │   ├── silver_erd.drawio
│   │   └── silver_erd.png
│   ├── gold/
│   │   ├── gold_data_dictionary.md
│   │   ├── gold_kpi_investigations.md
│   │   ├── gold_relationship_investigations.md
│   │   ├── gold_reporting_views.md
│   │   └── gold_validation.md
│   └── silver/
│       └── readme.md
├── scripts/
│   ├── bronze/
│   │   ├── ddl_bronze.sql
│   │   ├── load_bronze.sql
│   │   ├── profile_bronze.sql
│   │   ├── profiling_config.sql
│   │   ├── profile_category.sql
│   │   ├── profile_date_datetime.sql
│   │   ├── profile_identifier.sql
│   │   ├── profile_numeric.sql
│   │   ├── profile_text_columns.sql
│   │   └── investigations/
│   │       ├── investigate_detention_minutes.sql
│   │       ├── investigate_geographic_consistency.sql
│   │       ├── investigate_identifier_integrity.sql
│   │       ├── investigate_january_2025_timestamps.sql
│   │       ├── investigate_on_time_delivery_rate.sql
│   │       ├── investigate_on_time_flag.sql
│   │       ├── investigate_safety_incident_financials.sql
│   │       ├── investigate_truck_utilization_maintenance.sql
│   │       └── investigate_utilization_rate.sql
│   ├── gold/
│   │   ├── ddl_gold.sql
│   │   ├── gold_kpi_investigations.sql
│   │   ├── gold_relationship_investigations.sql
│   │   ├── load_gold.sql
│   │   ├── reconcile_gold_measures.sql
│   │   ├── reset_gold.sql
│   │   ├── validate_gold.sql
│   │   └── views/
│   │       ├── vw_customer_performance.sql
│   │       ├── vw_delivery_performance.sql
│   │       ├── vw_fleet_performance.sql
│   │       ├── vw_fuel_cost_analysis.sql
│   │       ├── vw_maintenance_performance.sql
│   │       ├── vw_revenue_performance.sql
│   │       ├── vw_safety_performance.sql
│   │       └── vw_truck_cost_efficiency.sql
│   └── silver/
│       ├── ddl_silver.sql
│       ├── load_silver.sql
│       └── reset_silver.sql
├── tests/
│   ├── inspect_silver_schema.sql
│   ├── validate_bronze.sql
│   └── validate_silver.sql
├── LICENSE
└── README.md
```

## Project Data Assets

- [Dataset files, source-to-table mapping, and profiling configuration](datasets/README.md)
- [Bronze data inventory and profiling workbook](docs/data_inventory/Logistics_Data_Inventory_Bronze.xlsx)
- [Bronze layer documentation](docs/bronze/readme.md)
- [Silver layer documentation](docs/silver/readme.md)
- [Warehouse architecture diagram (PNG)](docs/diagrams/Logistics_Data_Warehouse_Architecture%20(1).png) | [Editable Draw.io source](docs/diagrams/Logistics_Data_Warehouse_Architecture%20(1).drawio)
- [Silver layer ERD (PNG)](docs/diagrams/silver_erd.png) | [Editable Draw.io source](docs/diagrams/silver_erd.drawio)
- [Gold dimensional model DDL](scripts/gold/ddl_gold.sql)
- [Gold full-refresh loading procedure](scripts/gold/load_gold.sql)
- [Gold reset script](scripts/gold/reset_gold.sql) — use only for a full Gold rebuild
- [Gold structural and fact validation SQL](scripts/gold/validate_gold.sql)
- [Gold Silver-to-Gold measure reconciliation SQL](scripts/gold/reconcile_gold_measures.sql)
- [Gold validation record and sign-off evidence](docs/gold/gold_validation.md)
- [Gold reporting views documentation](docs/gold/gold_reporting_views.md)
- [Gold reporting view SQL scripts](scripts/gold/views/)
- [Gold data dictionary and dimensional mapping](docs/gold/gold_data_dictionary.md)
- [Gold KPI investigations and business rules](docs/gold/gold_kpi_investigations.md)
- [Gold relationship investigations and modelling decisions](docs/gold/gold_relationship_investigations.md)
- [Gold KPI investigation SQL](scripts/gold/gold_kpi_investigations.sql)
- [Gold relationship investigation SQL](scripts/gold/gold_relationship_investigations.sql)
## Bronze CATEGORY Profiling

CATEGORY profiling covers all 39 columns configured as CATEGORY in the Bronze profiling metadata. The automated script calculates distinct values, NULL counts, category frequencies, and percentages. A separate investigation checks city/state consistency across source tables.

- [CATEGORY Profiling Report](docs/bronze/category_profiling.md)
- [CATEGORY Profiling SQL](scripts/bronze/profile_category.sql)
- [Geographic Consistency Investigation Report](docs/bronze/investigations/geographic_consistency_investigation.md)
- [Geographic Consistency Investigation SQL](scripts/bronze/investigations/investigate_geographic_consistency.sql)

## Bronze Numeric Profiling

Numeric profiling covers all 53 configured numeric columns across the 14 Bronze tables. The report records conversion checks, descriptive statistics, zero/negative patterns, completed investigations, analytical decisions, and source-context limitations.

- [Numeric Profiling Report](docs/bronze/numeric_profiling.md)
- [Numeric Profiling SQL](scripts/bronze/profile_numeric.sql)

## Bronze Identifier Profiling

Identifier profiling covers all 36 configured identifier columns. Candidate row identifiers, 18 child-to-parent relationships, six business identifiers, trailer-number repeats, and the driver-month/truck-month candidate grains are documented separately.

- [Identifier Profiling Report](docs/bronze/identifier_profiling.md)
- [Reusable Identifier Profiling SQL](scripts/bronze/profile_identifier.sql)
- [Identifier Integrity Investigation SQL](scripts/bronze/investigations/investigate_identifier_integrity.sql)


## Bronze DATE and DATETIME Profiling

DATE and DATETIME profiling covers all 15 columns configured for temporal profiling across the 14 Bronze tables: 11 columns classified as `DATE` and 4 classified as `DATETIME`. The metadata-driven SQL uses `TRY_CONVERT` to assess technical convertibility, NULL and invalid values, and minimum and maximum dates or timestamps. These checks profile the original VARCHAR values without modifying the Bronze data.

- [DATE and DATETIME Profiling Report](docs/bronze/date_datetime_profiling.md)
- [DATE and DATETIME Profiling SQL](scripts/bronze/profile_date_datetime.sql)

## Bronze TEXT Profiling

TEXT profiling covers all 7 columns classified as TEXT in the Bronze profiling metadata. The reusable SQL reports completeness, distinct values, and text-length metrics, with frequency distributions for selected descriptive fields.

- [TEXT Profiling Report](docs/bronze/text_profiling.md)
- [TEXT Profiling SQL](scripts/bronze/profile_text_columns.sql)
