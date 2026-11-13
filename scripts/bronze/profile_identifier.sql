/*
    Bronze Identifier Profiling
    ----------------------------
    Purpose:
      Profile every column classified as IDENTIFIER in bronze.profiling_config.

    Output per configured column:
      Total rows, non-NULL values, NULL values, distinct non-NULL values,
      and duplicate occurrences (non-NULL count - distinct count).

    This is a reusable metadata-driven script. It does not alter Bronze data.
    SQL Server 2017+ is required for STRING_AGG.
*/

USE LogisticsAnalytics;
GO

SET NOCOUNT ON;

IF OBJECT_ID('bronze.profiling_config', 'U') IS NULL
    THROW 50001, 'bronze.profiling_config does not exist.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM bronze.profiling_config
    WHERE ProfilingType = 'IDENTIFIER'
)
    THROW 50002, 'No IDENTIFIER columns are configured.', 1;

-- Validate that every configured identifier points to an existing column.
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
    WHERE pc.ProfilingType = 'IDENTIFIER'
      AND c.column_id IS NULL
)
    THROW 50003, 'One or more IDENTIFIER configuration entries do not match a database column.', 1;

DECLARE @sql NVARCHAR(MAX);

SELECT @sql =
    STRING_AGG
    (
        CAST
        (
            N'SELECT ' +
            N'''' + REPLACE(pc.SchemaName, '''', '''''') + N''' AS schema_name, ' +
            N'''' + REPLACE(pc.TableName, '''', '''''') + N''' AS table_name, ' +
            N'''' + REPLACE(pc.ColumnName, '''', '''''') + N''' AS column_name, ' +
            N'COUNT_BIG(*) AS total_rows, ' +
            N'COUNT_BIG(' + QUOTENAME(pc.ColumnName) + N') AS non_null_count, ' +
            N'COUNT_BIG(*) - COUNT_BIG(' + QUOTENAME(pc.ColumnName) + N') AS null_count, ' +
            N'COUNT_BIG(DISTINCT ' + QUOTENAME(pc.ColumnName) + N') AS distinct_count, ' +
            N'COUNT_BIG(' + QUOTENAME(pc.ColumnName) + N') - COUNT_BIG(DISTINCT ' +
                QUOTENAME(pc.ColumnName) + N') AS duplicate_count ' +
            N'FROM ' + QUOTENAME(pc.SchemaName) + N'.' + QUOTENAME(pc.TableName)
            AS NVARCHAR(MAX)
        ),
        N' UNION ALL '
    )
FROM bronze.profiling_config AS pc
WHERE pc.ProfilingType = 'IDENTIFIER';

SET @sql = N'SELECT * FROM (' + @sql +
           N') AS identifier_profile ORDER BY schema_name, table_name, column_name;';

EXEC sys.sp_executesql @sql;
GO
