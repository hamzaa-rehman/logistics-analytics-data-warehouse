# logistics-analytics-data-warehouse
An end-to-end Logistics Analytics Data Warehouse built using SQL Server and Medallion Architecture (Bronze, Silver, Gold), transforming raw logistics data into actionable business insights through data engineering, analytics, and Power BI.

## Repository Structure

The tree below reflects the current repository contents. The presence of Silver and Gold files or folders does not mean those layers have been implemented; their development and documentation will be covered when work begins on those stages.

```text
logistics-analytics-data-warehouse/
├── datasets/
│   └── README.md
├── docs/
│   ├── architecture/
│   │   └── placeholder.txt
│   ├── bronze/
│   │   ├── readme.md
│   │   ├── numeric_profiling.md
│   │   ├── date_datetime_profiling.md
│   │   └── investigations/
│   │       ├── detention_minutes_investigation.md
│   │       ├── on_time_delivery_rate_investigation.md
│   │       ├── on_time_flag_investigation.md
│   │       ├── safety_incident_financials_investigation.md
│   │       └── truck_utilization_maintenance_investigation.md
│   ├── data_dictionary/
│   │   └── placeholder.txt
│   ├── data_inventory/
│   │   └── placeholder.txt
│   └── diagrams/
│       ├── Logistics_Data_Warehouse_Architecture.drawio
│       └── Logistics_Data_Warehouse_Architecture.png
├── scripts/
│   ├── bronze/
│   │   ├── ddl_bronze.sql
│   │   ├── load_bronze.sql
│   │   ├── profile_bronze.sql
│   │   ├── profiling_config.sql
│   │   ├── profile_numeric.sql
│   │   ├── profile_date_datetime.sql
│   │   └── investigations/
│   │       ├── investigate_detention_minutes.sql
│   │       ├── investigate_on_time_delivery_rate.sql
│   │       ├── investigate_on_time_flag.sql
│   │       ├── investigate_safety_incident_financials.sql
│   │       ├── investigate_truck_utilization_maintenance.sql
│   │       └── investigate_utilization_rate.sql
│   ├── gold/
│   │   └── readme.md
│   └── silver/
│       ├── ddl_silver.sql
│       └── readme.txt
├── tests/
│   └── validate_bronze.sql
├── LICENSE
└── README.md
```


## Bronze CATEGORY Profiling

CATEGORY profiling covers all 39 columns configured as CATEGORY in the Bronze profiling metadata. The automated script calculates distinct values, NULL counts, category frequencies, and percentages. A separate investigation checks city/state consistency across source tables.

- [CATEGORY Profiling Report](docs/bronze/category_profiling.md)
- [CATEGORY Profiling SQL](scripts/bronze/profile_category.sql)
- [Geographic Consistency Investigation SQL](scripts/bronze/investigations/investigate_geographic_consistency.sql)
