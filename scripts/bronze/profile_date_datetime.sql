/*
===============================================================================
Script:      profile_date_datetime.sql
Purpose:     Metadata-driven DATE and DATETIME profiling for the Bronze layer
Database:    LogisticsAnalytics
Schema:      bronze

Description:
    Profiles all columns configured as DATE or DATETIME in
    bronze.profiling_config.

    Metrics:
      - Total rows
      - NULL values
      - Invalid conversions
      - Valid conversions
      - Minimum and maximum values
      - Future values at execution time

    Bronze source values remain VARCHAR. TRY_CONVERT is used only for
    profiling; this script does not update or transform Bronze data.

Execution:
    Run the complete script in SQL Server after the Bronze data and
    bronze.profiling_config have been loaded.

Notes:
    - DATE source format was inspected as YYYY-MM-DD; style 23 is used.
    - DATETIME values are converted to DATETIME2 using the default
      seven-digit fractional-second precision.
    - The final result sets are ordered by table and column.
===============================================================================
*/

USE LogisticsAnalytics;
GO

/*=============================================================================
  1. CONFIGURATION CHECKS
=============================================================================*/

-- Review the configured DATE and DATETIME columns.
SELECT
    SchemaName,
    TableName,
    ColumnName,
    ProfilingType
FROM bronze.profiling_config
WHERE ProfilingType IN ('DATE', 'DATETIME')
ORDER BY
    ProfilingType,
    SchemaName,
    TableName,
    ColumnName;
GO

-- Review the number of configured columns in each profiling category.
SELECT
    ProfilingType,
    COUNT(*) AS ColumnCount
FROM bronze.profiling_config
GROUP BY ProfilingType
ORDER BY ProfilingType;
GO

/*
Expected configuration:
    DATE       11 columns
    DATETIME    4 columns

The configuration table contains 150 columns across all six profiling types.
*/

/*=============================================================================
  2. DATE SOURCE-FORMAT INSPECTION
=============================================================================*/

-- Inspect representative raw values from all configured DATE columns.
-- This is a diagnostic sample, not a complete validation.
SELECT TOP (10)
    N'customers' AS TableName,
    N'contract_start_date' AS ColumnName,
    contract_start_date AS RawValue
FROM bronze.customers

UNION ALL

SELECT TOP (10)
    N'driver_monthly_metrics',
    N'month',
    month
FROM bronze.driver_monthly_metrics

UNION ALL

SELECT TOP (10)
    N'drivers',
    N'date_of_birth',
    date_of_birth
FROM bronze.drivers

UNION ALL

SELECT TOP (10)
    N'drivers',
    N'hire_date',
    hire_date
FROM bronze.drivers

UNION ALL

SELECT TOP (10)
    N'drivers',
    N'termination_date',
    termination_date
FROM bronze.drivers

UNION ALL

SELECT TOP (10)
    N'loads',
    N'load_date',
    load_date
FROM bronze.loads

UNION ALL

SELECT TOP (10)
    N'maintenance_records',
    N'maintenance_date',
    maintenance_date
FROM bronze.maintenance_records

UNION ALL

SELECT TOP (10)
    N'trailers',
    N'acquisition_date',
    acquisition_date
FROM bronze.trailers

UNION ALL

SELECT TOP (10)
    N'trips',
    N'dispatch_date',
    dispatch_date
FROM bronze.trips

UNION ALL

SELECT TOP (10)
    N'truck_utilization_metrics',
    N'month',
    month
FROM bronze.truck_utilization_metrics

UNION ALL

SELECT TOP (10)
    N'trucks',
    N'acquisition_date',
    acquisition_date
FROM bronze.trucks;
GO

/*
Observed source format:
    YYYY-MM-DD

Style 23 is therefore used for DATE conversion.
*/

/*=============================================================================
  3. DATE PROFILING
=============================================================================*/

DECLARE @DateSQL NVARCHAR(MAX);

SELECT
    @DateSQL =
        STRING_AGG
        (
            CAST
            (
                N'SELECT
                    N''' + REPLACE(SchemaName, '''', '''''') + N''' AS SchemaName,
                    N''' + REPLACE(TableName, '''', '''''') + N''' AS TableName,
                    N''' + REPLACE(ColumnName, '''', '''''') + N''' AS ColumnName,

                    COUNT_BIG(*) AS TotalRows,

                    COUNT_BIG(CASE
                        WHEN ' + QUOTENAME(ColumnName) + N' IS NULL
                        THEN 1
                    END) AS NullValues,

                    COUNT_BIG(CASE
                        WHEN ' + QUOTENAME(ColumnName) + N' IS NOT NULL
                         AND TRY_CONVERT(DATE, ' + QUOTENAME(ColumnName) + N', 23) IS NULL
                        THEN 1
                    END) AS InvalidDateValues,

                    COUNT_BIG(CASE
                        WHEN TRY_CONVERT(DATE, ' + QUOTENAME(ColumnName) + N', 23) IS NOT NULL
                        THEN 1
                    END) AS ValidDateValues,

                    MIN(TRY_CONVERT(DATE, ' + QUOTENAME(ColumnName) + N', 23)) AS MinimumDate,

                    MAX(TRY_CONVERT(DATE, ' + QUOTENAME(ColumnName) + N', 23)) AS MaximumDate,

                    COUNT_BIG(CASE
                        WHEN TRY_CONVERT(DATE, ' + QUOTENAME(ColumnName) + N', 23) > CAST(GETDATE() AS DATE)
                        THEN 1
                    END) AS FutureDateCount

                FROM ' + QUOTENAME(SchemaName) + N'.' + QUOTENAME(TableName)
                AS NVARCHAR(MAX)
            ),
            N' UNION ALL '
        )
FROM bronze.profiling_config
WHERE ProfilingType = 'DATE';

IF @DateSQL IS NULL
BEGIN
    THROW 50001, 'No DATE columns were found in bronze.profiling_config.', 1;
END;

SET @DateSQL += N' ORDER BY TableName, ColumnName;';

EXEC sys.sp_executesql @DateSQL;
GO

/*
DATE profiling results:
    11 columns
    549,706 column-value observations
    124 NULL values
    0 invalid date values
    549,582 valid date values
    0 future dates

All 124 NULL values were found in drivers.termination_date.
*/

/*=============================================================================
  4. DATETIME SOURCE-FORMAT AND PRECISION INSPECTION
=============================================================================*/

-- Inspect representative non-NULL raw timestamp values.
SELECT TOP (5)
    actual_datetime AS RawValue
FROM bronze.delivery_events
WHERE actual_datetime IS NOT NULL;

SELECT TOP (5)
    scheduled_datetime AS RawValue
FROM bronze.delivery_events
WHERE scheduled_datetime IS NOT NULL;

SELECT TOP (5)
    purchase_date AS RawValue
FROM bronze.fuel_purchases
WHERE purchase_date IS NOT NULL;

SELECT TOP (5)
    incident_date AS RawValue
FROM bronze.safety_incidents
WHERE incident_date IS NOT NULL;
GO

-- Compare original text with its DATETIME2 conversion.
-- The VARCHAR output makes fractional-second precision visible.
SELECT TOP (5)
    actual_datetime AS OriginalValue,
    CONVERT
    (
        VARCHAR(40),
        TRY_CONVERT(DATETIME2(7), actual_datetime),
        121
    ) AS ConvertedValue
FROM bronze.delivery_events
WHERE actual_datetime IS NOT NULL;
GO

/*
The source sample contained six fractional-second digits for delivery
timestamps. Conversion to DATETIME2(7) preserved those digits and represented
the seventh fractional digit as zero.

The SQL Server result grid may display fewer fractional digits depending on
the client. Formatting the converted value as VARCHAR with style 121 makes
the full precision visible.
*/

/*=============================================================================
  5. DATETIME PROFILING
=============================================================================*/

DECLARE @DateTimeSQL NVARCHAR(MAX);

SELECT
    @DateTimeSQL =
        STRING_AGG
        (
            CAST
            (
                N'SELECT
                    N''' + REPLACE(SchemaName, '''', '''''') + N''' AS SchemaName,
                    N''' + REPLACE(TableName, '''', '''''') + N''' AS TableName,
                    N''' + REPLACE(ColumnName, '''', '''''') + N''' AS ColumnName,

                    COUNT_BIG(*) AS TotalRows,

                    COUNT_BIG(CASE
                        WHEN ' + QUOTENAME(ColumnName) + N' IS NULL
                        THEN 1
                    END) AS NullValues,

                    COUNT_BIG(CASE
                        WHEN ' + QUOTENAME(ColumnName) + N' IS NOT NULL
                         AND TRY_CONVERT(DATETIME2, ' + QUOTENAME(ColumnName) + N') IS NULL
                        THEN 1
                    END) AS InvalidDateTimeValues,

                    COUNT_BIG(CASE
                        WHEN TRY_CONVERT(DATETIME2, ' + QUOTENAME(ColumnName) + N') IS NOT NULL
                        THEN 1
                    END) AS ValidDateTimeValues,

                    MIN(TRY_CONVERT(DATETIME2, ' + QUOTENAME(ColumnName) + N')) AS MinimumDateTime,

                    MAX(TRY_CONVERT(DATETIME2, ' + QUOTENAME(ColumnName) + N')) AS MaximumDateTime,

                    COUNT_BIG(CASE
                        WHEN TRY_CONVERT(DATETIME2, ' + QUOTENAME(ColumnName) + N') > SYSDATETIME()
                        THEN 1
                    END) AS FutureDateTimeCount

                FROM ' + QUOTENAME(SchemaName) + N'.' + QUOTENAME(TableName)
                AS NVARCHAR(MAX)
            ),
            N' UNION ALL '
        )
FROM bronze.profiling_config
WHERE ProfilingType = 'DATETIME';

IF @DateTimeSQL IS NULL
BEGIN
    THROW 50002, 'No DATETIME columns were found in bronze.profiling_config.', 1;
END;

SET @DateTimeSQL += N' ORDER BY TableName, ColumnName;';

EXEC sys.sp_executesql @DateTimeSQL;
GO

/*
DATETIME profiling results:
    4 columns
    538,252 column-value observations
    0 NULL values
    0 invalid datetime values
    538,252 valid datetime values
    0 future timestamps

The minimum and maximum values are returned as DATETIME2. If the client
truncates the displayed fractional seconds, use the precision-display query
below to inspect the full seven-digit representation.
*/

/*=============================================================================
  6. FULL-PRECISION MINIMUM AND MAXIMUM DISPLAY
=============================================================================*/

SELECT
    N'delivery_events' AS TableName,
    N'actual_datetime' AS ColumnName,
    CONVERT
    (
        VARCHAR(30),
        MIN(TRY_CONVERT(DATETIME2(7), actual_datetime)),
        121
    ) AS MinimumDateTime,
    CONVERT
    (
        VARCHAR(30),
        MAX(TRY_CONVERT(DATETIME2(7), actual_datetime)),
        121
    ) AS MaximumDateTime
FROM bronze.delivery_events

UNION ALL

SELECT
    N'delivery_events',
    N'scheduled_datetime',
    CONVERT(VARCHAR(30), MIN(TRY_CONVERT(DATETIME2(7), scheduled_datetime)), 121),
    CONVERT(VARCHAR(30), MAX(TRY_CONVERT(DATETIME2(7), scheduled_datetime)), 121)
FROM bronze.delivery_events

UNION ALL

SELECT
    N'fuel_purchases',
    N'purchase_date',
    CONVERT(VARCHAR(30), MIN(TRY_CONVERT(DATETIME2(7), purchase_date)), 121),
    CONVERT(VARCHAR(30), MAX(TRY_CONVERT(DATETIME2(7), purchase_date)), 121)
FROM bronze.fuel_purchases

UNION ALL

SELECT
    N'safety_incidents',
    N'incident_date',
    CONVERT(VARCHAR(30), MIN(TRY_CONVERT(DATETIME2(7), incident_date)), 121),
    CONVERT(VARCHAR(30), MAX(TRY_CONVERT(DATETIME2(7), incident_date)), 121)
FROM bronze.safety_incidents;
GO

/*
===============================================================================
END OF DATE AND DATETIME PROFILING
===============================================================================
*/
