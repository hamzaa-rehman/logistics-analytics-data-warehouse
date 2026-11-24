# Logistics Analytics Data Warehouse
A SQL Server data warehouse project using the Medallion Architecture (Bronze, Silver, Gold) to prepare logistics operations data for business analytics. Bronze ingestion and profiling, Silver transformation and validation, and Gold KPI and relationship investigations are complete. The Gold dimensional schema has been created and validated; Gold data loading, reporting views, and Power BI reporting remain in progress.

## Repository Structure

The tree below reflects the current repository contents. Bronze ingestion and profiling, and the Silver schema, loading procedure, and validation work are complete. Gold KPI and relationship discovery are documented, and the Gold dimensional tables are created and validated. Gold data loading and Power BI reporting remain in progress.

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
│   │   ├── numeric_profiling.md
│   │   ├── date_datetime_profiling.md
│   │   ├── category_profiling.md
│   │   ├── identifier_profiling.md
│   │   ├── text_profiling.md
│   │   └── investigations/
│   │       ├── geographic_consistency_investigation.md
│   │       ├── detention_minutes_investigation.md
│   │       ├── on_time_delivery_rate_investigation.md
│   │       ├── on_time_flag_investigation.md
│   │       ├── safety_incident_financials_investigation.md
│   │       └── truck_utilization_maintenance_investigation.md
│   ├── silver/
│   │   └── readme.md
│   ├── gold/
│   │   ├── gold_kpi_investigations.md
│   │   └── gold_relationship_investigations.md
│   ├── data_inventory/
│   │   └── Logistics_Data_Inventory_Bronze.xlsx
│   └── diagrams/
│       ├── silver_erd.drawio
│       └── silver_erd.png
├── scripts/
│   ├── bronze/
│   │   ├── ddl_bronze.sql
│   │   ├── load_bronze.sql
│   │   ├── profile_bronze.sql
│   │   ├── profiling_config.sql
│   │   ├── profile_numeric.sql
│   │   ├── profile_date_datetime.sql
│   │   ├── profile_category.sql
│   │   ├── profile_identifier.sql
│   │   ├── profile_text_columns.sql
│   │   └── investigations/
│   │       ├── investigate_detention_minutes.sql
│   │       ├── investigate_on_time_delivery_rate.sql
│   │       ├── investigate_on_time_flag.sql
│   │       ├── investigate_safety_incident_financials.sql
│   │       ├── investigate_truck_utilization_maintenance.sql
│   │       ├── investigate_utilization_rate.sql
│   │       ├── investigate_january_2025_timestamps.sql
│   │       ├── investigate_geographic_consistency.sql
│   │       └── investigate_identifier_integrity.sql
│   ├── silver/
│   │   ├── ddl_silver.sql
│   │   └── load_silver.sql
│   └── gold/
│       ├── ddl_gold.sql
│       ├── reset_gold.sql
│       ├── gold_kpi_investigations.sql
│       └── gold_relationship_investigations.sql
├── tests/
│   └── validate_bronze.sql
├── LICENSE
└── README.md
```

## Project Data Assets

- [Dataset files, source-to-table mapping, and profiling configuration](datasets/README.md)
- [Bronze data inventory and profiling workbook](docs/data_inventory/Logistics_Data_Inventory_Bronze.xlsx)
- [Bronze layer documentation](docs/bronze/readme.md)
- [Silver layer documentation](docs/silver/readme.md)
- [Silver layer ERD (PNG)](docs/diagrams/silver_erd.png) | [Editable Draw.io source](docs/diagrams/silver_erd.drawio)
- [Gold dimensional model DDL](scripts/gold/ddl_gold.sql)
- [Gold data dictionary and dimensional mapping](docs/gold/gold_data_dictionary.md)
- [Gold reset script](scripts/gold/reset_gold.sql) — use only for a full Gold rebuild
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
