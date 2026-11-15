/*
Bronze TEXT profiling
Database: LogisticsAnalytics
Prerequisite: bronze.profiling_config contains valid TEXT entries.

Purpose:
  Profile configured free-form/descriptive text columns without modifying
  Bronze data.

Outputs:
  1. Row counts, NULL/empty/whitespace-only counts, distinct non-NULL values,
     and minimum, maximum, and average non-empty text lengths.
  2. Value frequencies for selected descriptive columns:
       facilities.operating_hours
       maintenance_records.service_description
       safety_incidents.description

Whitespace scope:
  Tabs, line feeds, and carriage returns are converted to ordinary spaces
  before TRIM. This detects values consisting only of those characters and
  ordinary spaces. It is not a universal Unicode-whitespace test.

Length scope:
  LEN returns character counts and ignores trailing ordinary spaces.
  Length statistics exclude NULL, empty, and detected whitespace-only values.
  DATALENGTH is used to distinguish a true zero-length VARCHAR value from a
  value containing only spaces (SQL Server string comparisons can pad spaces).

SQL Server 2017+ is required for STRING_AGG. TRIM requires SQL Server 2017+.
*/

USE LogisticsAnalytics;


SET NOCOUNT ON;

/* Validate the profiling configuration and configured database objects. */
IF OBJECT_ID(N'bronze.profiling_config', N'U') IS NULL
    THROW 50001, 'bronze.profiling_config does not exist.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM bronze.profiling_config
    WHERE ProfilingType = 'TEXT'
)
    THROW 50002, 'No TEXT columns are configured.', 1;

IF EXISTS
(
    SELECT 1
    FROM bronze.profiling_config AS pc
    LEFT JOIN sys.schemas AS s
        ON s.name = pc.SchemaName
    LEFT JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
       AND t.name = pc.TableName
    LEFT JOIN sys.columns AS c
        ON c.object_id = t.object_id
       AND c.name = pc.ColumnName
    WHERE pc.ProfilingType = 'TEXT'
      AND c.column_id IS NULL
)
    THROW 50003, 'TEXT configuration contains an invalid schema, table, or column.', 1;

/* 1. Summary metrics for every configured TEXT column. */
DECLARE @SummarySQL NVARCHAR(MAX);

SELECT
    @SummarySQL = STRING_AGG
    (
        CAST
        (
            N'SELECT
                N''' + REPLACE(pc.SchemaName, '''', '''''') + N''' AS SchemaName,
                N''' + REPLACE(pc.TableName, '''', '''''') + N''' AS TableName,
                N''' + REPLACE(pc.ColumnName, '''', '''''') + N''' AS ColumnName,
                COUNT_BIG(*) AS TotalRows,
                COUNT_BIG(CASE
                    WHEN ' + QUOTENAME(pc.ColumnName) + N' IS NULL
                    THEN 1 END) AS NullCount,
                COUNT_BIG(CASE
                    WHEN ' + QUOTENAME(pc.ColumnName) + N' IS NOT NULL
                     AND DATALENGTH(' + QUOTENAME(pc.ColumnName) + N') = 0
                    THEN 1 END) AS EmptyCount,
                COUNT_BIG(CASE
                    WHEN ' + QUOTENAME(pc.ColumnName) + N' IS NOT NULL
                     AND DATALENGTH(' + QUOTENAME(pc.ColumnName) + N') > 0
                     AND TRIM(REPLACE(REPLACE(REPLACE(' + QUOTENAME(pc.ColumnName) +
                        N', CHAR(9), '' ''), CHAR(10), '' ''), CHAR(13), '' '')) = ''''
                    THEN 1 END) AS WhitespaceOnlyCount,
                COUNT_BIG(DISTINCT ' + QUOTENAME(pc.ColumnName) + N') AS DistinctNonNullCount,
                MIN(CASE
                    WHEN ' + QUOTENAME(pc.ColumnName) + N' IS NOT NULL
                     AND DATALENGTH(' + QUOTENAME(pc.ColumnName) + N') > 0
                     AND TRIM(REPLACE(REPLACE(REPLACE(' + QUOTENAME(pc.ColumnName) +
                        N', CHAR(9), '' ''), CHAR(10), '' ''), CHAR(13), '' '')) <> ''''
                    THEN LEN(' + QUOTENAME(pc.ColumnName) + N') END) AS MinLength,
                MAX(CASE
                    WHEN ' + QUOTENAME(pc.ColumnName) + N' IS NOT NULL
                     AND DATALENGTH(' + QUOTENAME(pc.ColumnName) + N') > 0
                     AND TRIM(REPLACE(REPLACE(REPLACE(' + QUOTENAME(pc.ColumnName) +
                        N', CHAR(9), '' ''), CHAR(10), '' ''), CHAR(13), '' '')) <> ''''
                    THEN LEN(' + QUOTENAME(pc.ColumnName) + N') END) AS MaxLength,
                CAST(AVG(CASE
                    WHEN ' + QUOTENAME(pc.ColumnName) + N' IS NOT NULL
                     AND DATALENGTH(' + QUOTENAME(pc.ColumnName) + N') > 0
                     AND TRIM(REPLACE(REPLACE(REPLACE(' + QUOTENAME(pc.ColumnName) +
                        N', CHAR(9), '' ''), CHAR(10), '' ''), CHAR(13), '' '')) <> ''''
                    THEN CONVERT(DECIMAL(19,6), LEN(' + QUOTENAME(pc.ColumnName) + N'))
                END) AS DECIMAL(19,6)) AS AvgLength
              FROM ' + QUOTENAME(pc.SchemaName) + N'.' + QUOTENAME(pc.TableName)
            AS NVARCHAR(MAX)
        ),
        N' UNION ALL '
    ) WITHIN GROUP (ORDER BY pc.TableName, pc.ColumnName)
FROM bronze.profiling_config AS pc
WHERE pc.ProfilingType = 'TEXT';

IF @SummarySQL IS NULL
    THROW 50004, 'No TEXT summary statements could be generated.', 1;

SET @SummarySQL =
    N'SELECT *
      FROM (' + @SummarySQL + N') AS TextSummary
      ORDER BY TableName, ColumnName;';

EXEC sys.sp_executesql @SummarySQL;


/* 2. Frequency distribution: facility operating hours. */
SELECT
    N'facilities' AS TableName,
    N'operating_hours' AS ColumnName,
    operating_hours AS TextValue,
    COUNT_BIG(*) AS ValueCount
FROM bronze.facilities
GROUP BY operating_hours
ORDER BY ValueCount DESC, TextValue;


/* 3. Frequency distribution: maintenance service descriptions. */
SELECT
    N'maintenance_records' AS TableName,
    N'service_description' AS ColumnName,
    service_description AS TextValue,
    COUNT_BIG(*) AS ValueCount
FROM bronze.maintenance_records
GROUP BY service_description
ORDER BY ValueCount DESC, TextValue;


/* 4. Frequency distribution: safety incident descriptions. */
SELECT
    N'safety_incidents' AS TableName,
    N'description' AS ColumnName,
    description AS TextValue,
    COUNT_BIG(*) AS ValueCount
FROM bronze.safety_incidents
GROUP BY description
ORDER BY ValueCount DESC, TextValue;

