# Datasets

This directory contains the source files used to build and profile the Bronze layer of the Logistics Analytics Data Warehouse.

## Directory structure

```text
datasets/
├── README.md
├── logistics_operations_database/
│   ├── customers.csv
│   ├── delivery_events.csv
│   ├── driver_monthly_metrics.csv
│   ├── drivers.csv
│   ├── facilities.csv
│   ├── fuel_purchases.csv
│   ├── loads.csv
│   ├── maintenance_records.csv
│   ├── routes.csv
│   ├── safety_incidents.csv
│   ├── trailers.csv
│   ├── trips.csv
│   ├── truck_utilization_metrics.csv
│   └── trucks.csv
└── profiling_config/
    └── bronze_profiling_config.csv
```

## Source dataset

The `logistics_operations_database/` directory contains the 14 CSV source files for the Logistics Operations Database dataset, identified in this project as a Kaggle dataset.

These files are the raw inputs for the Bronze ingestion process. The Bronze layer preserves the source values as text in VARCHAR columns; data cleaning, standardization, and type conversion are deferred to the Silver layer.

| Source CSV | Bronze table |
|---|---|
| `customers.csv` | `bronze.customers` |
| `delivery_events.csv` | `bronze.delivery_events` |
| `driver_monthly_metrics.csv` | `bronze.driver_monthly_metrics` |
| `drivers.csv` | `bronze.drivers` |
| `facilities.csv` | `bronze.facilities` |
| `fuel_purchases.csv` | `bronze.fuel_purchases` |
| `loads.csv` | `bronze.loads` |
| `maintenance_records.csv` | `bronze.maintenance_records` |
| `routes.csv` | `bronze.routes` |
| `safety_incidents.csv` | `bronze.safety_incidents` |
| `trailers.csv` | `bronze.trailers` |
| `trips.csv` | `bronze.trips` |
| `truck_utilization_metrics.csv` | `bronze.truck_utilization_metrics` |
| `trucks.csv` | `bronze.trucks` |

The source files are mapped explicitly in [`load_bronze.sql`](../scripts/bronze/load_bronze.sql). The loading procedure expects all 14 files to be present in the directory supplied through its `@DataFolder` parameter. That directory must be accessible to the SQL Server instance; a path on the developer's local machine is not automatically accessible to SQL Server, including when SQL Server runs in Docker.

## Bronze profiling configuration

The `profiling_config/` directory contains `bronze_profiling_config.csv`. This file supplies the metadata records used to populate `bronze.profiling_config`.

The CSV contains 150 Bronze column classifications across 14 tables and uses four fields:

| Field | Description |
|---|---|
| `SchemaName` | Source schema name (`bronze`) |
| `TableName` | Bronze table name |
| `ColumnName` | Column being profiled |
| `ProfilingType` | Assigned profiling category |

The current configuration contains:

| Profiling type | Configured columns |
|---|---:|
| CATEGORY | 39 |
| DATE | 11 |
| DATETIME | 4 |
| IDENTIFIER | 36 |
| NUMERIC | 53 |
| TEXT | 7 |
| **Total** | **150** |

### Importing the configuration

1. Execute [`profiling_config.sql`](../scripts/bronze/profiling_config.sql) to create `bronze.profiling_config` (after the Bronze schema exists).
2. Import the four columns from `profiling_config/bronze_profiling_config.csv` into `bronze.profiling_config`, mapping each CSV field to the matching table column.
3. Run the validation queries in `profiling_config.sql`.
4. Confirm that 150 records are present, that the six profiling-type counts match the table above, and that no duplicate schema/table/column combinations are returned.

The CSV is configuration metadata, not source business data and not a profiling-results export. The metadata-driven profiling scripts use it to determine which checks to run for each Bronze column.

## Related documentation

- [Bronze layer documentation](../docs/bronze/readme.md)
- [Bronze data inventory and profiling workbook](../docs/data_inventory/Logistics_Data_Inventory_Bronze.xlsx)
- [Bronze profiling configuration SQL](../scripts/bronze/profiling_config.sql)
- [Bronze loading procedure](../scripts/bronze/load_bronze.sql)

## Source attribution and usage

The source dataset is identified in this project as **Logistics Operations Database (Kaggle)**. Before redistributing or reusing the CSV files, users should consult the original dataset listing and its licence/usage terms. The repository should retain the original source attribution and any licence requirements that apply to the dataset.

The profiling configuration CSV is a project-maintained metadata asset created to support this warehouse's Bronze profiling workflow.
