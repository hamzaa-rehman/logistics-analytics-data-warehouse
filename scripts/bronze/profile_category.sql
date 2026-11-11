/*
Bronze CATEGORY profiling
Database: LogisticsAnalytics
Prerequisite: bronze.profiling_config contains valid CATEGORY entries.

This script produces:
  1. Total rows, distinct category values, and NULL counts.
  2. Category frequencies and within-column percentages.
  3. Normal vs binary-collation distinct counts and ordinary boundary-space
     counts.

TRY_CONVERT is not required: CATEGORY source values remain VARCHAR and are
profiled without modifying Bronze data.
*/
USE LogisticsAnalytics;
GO

/* Validate configured objects. */
IF NOT EXISTS (SELECT 1 FROM bronze.profiling_config WHERE ProfilingType = 'CATEGORY')
    THROW 50001, 'No CATEGORY columns are configured.', 1;

IF EXISTS
(
    SELECT 1
    FROM bronze.profiling_config AS pc
    LEFT JOIN sys.schemas AS s ON pc.SchemaName = s.name
    LEFT JOIN sys.tables AS t ON t.schema_id = s.schema_id AND pc.TableName = t.name
    LEFT JOIN sys.columns AS c ON c.object_id = t.object_id AND pc.ColumnName = c.name
    WHERE pc.ProfilingType = 'CATEGORY'
      AND c.column_id IS NULL
)
    THROW 50002, 'CATEGORY configuration contains an invalid schema, table, or column.', 1;

/* 1. Distinct counts and NULL counts. */
DECLARE @SummarySQL NVARCHAR(MAX);

SELECT @SummarySQL = STRING_AGG
(
    CAST
    (
        N'SELECT
            N''' + REPLACE(SchemaName, '''', '''''') + N''' AS SchemaName,
            N''' + REPLACE(TableName, '''', '''''') + N''' AS TableName,
            N''' + REPLACE(ColumnName, '''', '''''') + N''' AS ColumnName,
            COUNT_BIG(*) AS TotalRows,
            COUNT_BIG(DISTINCT ' + QUOTENAME(ColumnName) + N') AS DistinctCount,
            COUNT_BIG(*) - COUNT_BIG(' + QUOTENAME(ColumnName) + N') AS NullCount
          FROM ' + QUOTENAME(SchemaName) + N'.' + QUOTENAME(TableName)
        AS NVARCHAR(MAX)
    ),
    N' UNION ALL '
) WITHIN GROUP (ORDER BY TableName, ColumnName)
FROM bronze.profiling_config
WHERE ProfilingType = 'CATEGORY';

IF @SummarySQL IS NULL
    THROW 50003, 'No CATEGORY summary statements could be generated.', 1;

SET @SummarySQL = N'SELECT * FROM (' + @SummarySQL +
                  N') AS CategorySummary ORDER BY TableName, ColumnName;';
EXEC sys.sp_executesql @SummarySQL;

/* 2. Frequencies and percentages for each non-NULL category value. */
DECLARE @FrequencySQL NVARCHAR(MAX);

SELECT @FrequencySQL = STRING_AGG
(
    CAST
    (
        N'SELECT
            N''' + REPLACE(SchemaName, '''', '''''') + N''' AS SchemaName,
            N''' + REPLACE(TableName, '''', '''''') + N''' AS TableName,
            N''' + REPLACE(ColumnName, '''', '''''') + N''' AS ColumnName,
            CONVERT(NVARCHAR(4000), ' + QUOTENAME(ColumnName) + N') AS CategoryValue,
            COUNT_BIG(*) AS CategoryCount
          FROM ' + QUOTENAME(SchemaName) + N'.' + QUOTENAME(TableName) + N'
          WHERE ' + QUOTENAME(ColumnName) + N' IS NOT NULL
          GROUP BY ' + QUOTENAME(ColumnName)
        AS NVARCHAR(MAX)
    ),
    N' UNION ALL '
) WITHIN GROUP (ORDER BY TableName, ColumnName)
FROM bronze.profiling_config
WHERE ProfilingType = 'CATEGORY';

IF @FrequencySQL IS NULL
    THROW 50004, 'No CATEGORY frequency statements could be generated.', 1;

SET @FrequencySQL = N'
WITH CategoryFrequencies AS
(
    ' + @FrequencySQL + N'
)
SELECT
    SchemaName,
    TableName,
    ColumnName,
    CategoryValue,
    CategoryCount,
    CAST
    (
        CategoryCount * 100.0 /
        SUM(CategoryCount) OVER (PARTITION BY SchemaName, TableName, ColumnName)
        AS DECIMAL(9,2)
    ) AS CategoryPercentage
FROM CategoryFrequencies
ORDER BY TableName, ColumnName, CategoryCount DESC, CategoryValue;';
EXEC sys.sp_executesql @FrequencySQL;

/* 3. Case-sensitive distinctness and ordinary leading/trailing spaces. */
DECLARE @TextCheckSQL NVARCHAR(MAX);

SELECT @TextCheckSQL = STRING_AGG
(
    CAST
    (
        N'SELECT
            N''' + REPLACE(SchemaName, '''', '''''') + N''' AS SchemaName,
            N''' + REPLACE(TableName, '''', '''''') + N''' AS TableName,
            N''' + REPLACE(ColumnName, '''', '''''') + N''' AS ColumnName,
            COUNT_BIG(DISTINCT ' + QUOTENAME(ColumnName) + N') AS NormalDistinctCount,
            COUNT_BIG(DISTINCT ' + QUOTENAME(ColumnName) +
            N' COLLATE Latin1_General_100_BIN2) AS BinaryDistinctCount,
            COUNT_BIG(CASE
                WHEN DATALENGTH(' + QUOTENAME(ColumnName) + N') <>
                     DATALENGTH(LTRIM(RTRIM(' + QUOTENAME(ColumnName) + N')))
                THEN 1 END) AS LeadingTrailingSpaceCount
          FROM ' + QUOTENAME(SchemaName) + N'.' + QUOTENAME(TableName)
        AS NVARCHAR(MAX)
    ),
    N' UNION ALL '
) WITHIN GROUP (ORDER BY TableName, ColumnName)
FROM bronze.profiling_config
WHERE ProfilingType = 'CATEGORY';

IF @TextCheckSQL IS NULL
    THROW 50005, 'No CATEGORY text-check statements could be generated.', 1;

SET @TextCheckSQL = N'SELECT * FROM (' + @TextCheckSQL +
                    N') AS CategoryTextChecks ORDER BY TableName, ColumnName;';
EXEC sys.sp_executesql @TextCheckSQL;

/*
Observed run:
  - 39 CATEGORY columns.
  - 0 NULL values.
  - No normal/binary distinct-count differences.
  - No leading/trailing ordinary spaces.
This whitespace check does not cover every Unicode whitespace character.
*/
