# Bronze Layer — Logistics Analytics Data Warehouse

## 1. Overview

The Bronze layer is the initial ingestion layer of the Logistics Analytics Data Warehouse. Its primary responsibility is to store raw data from the source CSV files while preserving the original textual values without applying data cleaning, standardization, or business transformations.

It provides a foundation for subsequent processing in the Silver and Gold layers and maintains a raw representation of the source data for traceability, validation, and investigation.

### Project scope

| Metric | Result |
|---|---:|
| Source tables | 14 |
| Total records loaded | 549,706 |
| Total columns | 150 |
| Bronze columns stored as | VARCHAR |
| Loading strategy | Full refresh |

**Source dataset:** Kaggle — Logistics Operations Database.

## 2. Data Warehouse Architecture

The project is designed around the Medallion Architecture, separating data ingestion, data transformation, and business-level modelling into three layers. The Bronze layer has been implemented; the Silver and Gold layers represent the planned next stages.

![Logistics Analytics Data Warehouse Architecture](../diagrams/Logistics_Data_Warehouse_Architecture.png)

*Figure 1: High-level architecture of the Logistics Analytics Data Warehouse.*

Each layer has a clearly defined responsibility:

- **Bronze:** Preserves raw source data.
- **Silver:** Cleans, standardizes, validates, and converts data into appropriate data types.
- **Gold:** Applies business logic and prepares analytical datasets for reporting and decision-making.

This separation makes the pipeline modular, maintainable, easier to troubleshoot, and easier to extend.

## 3. Source Data Inventory

The Bronze layer contains 14 source tables.

| Source table | Loaded rows |
|---|---:|
| CUSTOMERS | 200 |
| DRIVERS | 150 |
| TRUCKS | 120 |
| TRAILERS | 180 |
| FACILITIES | 50 |
| ROUTES | 58 |
| LOADS | 85,410 |
| TRIPS | 85,410 |
| FUEL_PURCHASES | 196,442 |
| MAINTENANCE_RECORDS | 2,920 |
| DELIVERY_EVENTS | 170,820 |
| SAFETY_INCIDENTS | 170 |
| DRIVER_MONTHLY_METRICS | 4,464 |
| TRUCK_UTILIZATION_METRICS | 3,312 |
| **Total** | **549,706** |

## 4. Bronze Design Decisions

### 4.1 Raw data preservation

All Bronze columns are defined as VARCHAR to retain ingested source values in textual form and avoid premature data type conversions.

For example:

- A date value such as `unknown` may cause an error if directly converted into a `DATE`.
- An identifier such as `001` may lose its leading zeros if converted into an `INT`.

Appropriate data type conversions and validation are therefore handled in the Silver layer.

### 4.2 No data cleaning or business transformations

The Bronze layer does not intentionally:

- Replace or impute NULL values.
- Remove duplicate records.
- Standardize text values.
- Convert source columns into business-specific data types.
- Apply business rules or calculations.

Its purpose is to retain the raw source representation for downstream processing.

### 4.3 Full refresh loading strategy

The Bronze loading procedure uses a full refresh approach.

For each source file, the corresponding Bronze table is truncated using `TRUNCATE TABLE`, followed by a `BULK INSERT` of the source file's contents.

This prevents records from accumulating across repeated executions and allows each table to be reloaded from the current source file.

## 5. Bronze Loading Process

The Bronze ingestion process consists of the following steps:

1. Create the database and Bronze table structures.
2. Make the source CSV files accessible to SQL Server.
3. Execute the Bronze loading procedure.
4. Truncate the corresponding Bronze tables.
5. Bulk load the source CSV files.
6. Validate the loaded tables and profile their contents.

### Loading procedure

The stored procedure `bronze.load_bronze` accepts a data-folder path through the `@DataFolder` parameter.

Example execution:

```sql
USE LogisticsAnalytics;
GO

EXEC bronze.load_bronze
    @DataFolder = N'<SQL Server accessible CSV directory>';
GO
```

The directory must be accessible to the SQL Server environment, and the SQL Server service must have the required file-access permissions.

## 6. Repository Structure

The Bronze implementation is organized into SQL scripts and validation tests.

```text
Logistics-Analytics/
│
├── scripts/
│   └── bronze/
│       ├── ddl_bronze.sql
│       ├── load_proc.sql
│       └── profile_bronze.sql
│
├── tests/
│   └── validate_bronze.sql
│
└── docs/
    └── bronze/
        └── README.md
```

| File | Responsibility |
|---|---|
| `ddl_bronze.sql` | Creates the Bronze schema and raw tables. |
| `load_proc.sql` | Defines the stored procedure responsible for loading source CSV files. |
| `profile_bronze.sql` | Dynamically profiles Bronze columns for NULL, empty-string, and whitespace-only values. |
| `validate_bronze.sql` | Checks Bronze table existence, expected row counts, column counts, and data types. |

## 7. Bronze Validation Results

Structural validation and data profiling were performed after ingestion.

### 7.1 Structural validation

| Validation check | Result |
|---|---|
| Expected Bronze tables | 14 |
| Tables found | 14 |
| Total loaded records | 549,706 |
| Total columns | 150 |
| Non-VARCHAR columns | 0 |
| Initial technical validation | 14/14 passed |

The initial validation confirmed that all expected tables existed and met the tested row-count, column-count, and data-type requirements.

CSV column names and their order were also checked against the corresponding Bronze table definitions.

### 7.2 Column-level data profiling

All 150 columns across the 14 Bronze tables were profiled for:

- NULL values.
- Empty strings.
- Whitespace-only values.

**Profiling summary**

| Finding | Count |
|---|---:|
| Total NULL values | 13,060 |
| Columns containing NULLs | 8 |
| Empty strings | 0 |
| Whitespace-only values detected | 0 |

### 7.3 NULL findings

NULL values were identified in the following columns:

| Table | Column | NULL count |
|---|---|---:|
| drivers | termination_date | 124 |
| fuel_purchases | driver_id | 3,988 |
| fuel_purchases | truck_id | 3,880 |
| safety_incidents | driver_id | 1 |
| safety_incidents | truck_id | 1 |
| trips | driver_id | 1,714 |
| trips | trailer_id | 1,680 |
| trips | truck_id | 1,672 |
| **Total** | | **13,060** |

These findings were investigated rather than automatically treated as errors.

NULL values can have different meanings depending on the business context. For example, a missing termination date may be consistent with an active driver, while a missing driver or truck reference requires further investigation.

The Bronze layer preserves these values. Decisions about their treatment belong in the Silver layer.

**Profiling note:** The whitespace check used `LTRIM`, `RTRIM`, and `DATALENGTH` to detect ordinary space-only values. It does not guarantee detection of every possible Unicode whitespace character.

## 8. Known Limitations

The current Bronze implementation has the following limitations:

1. **Hardcoded file mapping:** Source files and their corresponding Bronze tables are explicitly defined in the loading procedure. Changes to file names or mappings require manual updates.

2. **Column-order dependency:** `BULK INSERT` loads data by column position rather than matching CSV header names. A change in source column order can result in loading errors or incorrectly mapped values.

3. **Partial loading risk:** The current procedure does not use a single transaction across all 14 tables. If execution fails partway through, previously processed tables may already contain refreshed data, while the table being processed may be empty or partially loaded, depending on where the failure occurs. Subsequent tables may remain unchanged.

4. **Full refresh strategy:** Existing table contents are removed before reloading. The process is not an incremental loading implementation.

5. **Source-file dependency:** Missing, inaccessible, or incorrectly formatted CSV files can interrupt the ingestion process.

These limitations should be considered when maintaining or extending the ingestion pipeline.

## 9. Execution Prerequisites

Before running the Bronze ingestion process, ensure that:

- SQL Server is available and the `LogisticsAnalytics` database exists.
- The Bronze schema and all 14 raw tables have been created using `ddl_bronze.sql`.
- All required source CSV files are available.
- SQL Server can access the source-file directory and has the necessary permissions.
- The loading procedure has been created using `load_proc.sql`.
- CSV column names and column order match the corresponding Bronze table definitions.

### Recommended execution order

1. Execute `ddl_bronze.sql`.
2. Execute `load_proc.sql`.
3. Place the CSV files in a SQL Server-accessible directory.
4. Execute `bronze.load_bronze` with the appropriate directory path.
5. Execute `validate_bronze.sql`.
6. Execute `profile_bronze.sql`.
7. Review and document any validation or profiling findings.

## 10. Next Stage

After completing Bronze ingestion, validation, and profiling, the next stage is the **Silver layer**.

The Silver layer will be responsible for:

- Data type conversions and validation.
- Handling missing and invalid values according to business rules.
- Standardizing inconsistent values.
- Investigating and resolving data-quality issues.
- Validating primary and foreign key relationships.
- Preparing clean, consistent data for Gold-layer modelling.

The raw Bronze data will remain available as the reference point for downstream transformations and data-quality investigations.
