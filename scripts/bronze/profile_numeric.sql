/*
================================================================================
Project:        Logistics Analytics Data Warehouse
Layer:          Bronze
Script:         profile_numeric.sql
Purpose:        Perform metadata-driven numeric profiling across Bronze tables.

Description:
    Reads columns classified as NUMERIC from bronze.profiling_config.
    Generates one profiling SELECT statement for each configured column.
    Combines the statements using STRING_AGG and UNION ALL.
    Executes the consolidated query using sp_executesql.

Metrics:
    - Total rows
    - Non-NULL values
    - NULL values
    - Invalid numeric values
    - Minimum value
    - Maximum value
    - Average value
    - Negative values
    - Zero values

Conversion:
    TRY_CONVERT(DECIMAL(18,4)) is used for profiling only.
    Original Bronze values are not modified.

Important:
    DECIMAL(18,4) is a common profiling conversion type. It does not determine
    the final Silver-layer data type; that decision depends on each column's
    business meaning, precision, scale, and validation requirements.

Prerequisite:
    bronze.profiling_config must exist and contain valid NUMERIC column entries.
================================================================================
*/


/*
================================================================================
STEP 1: Validate configured numeric columns against SQL Server metadata
================================================================================

If a configured schema, table, or column does not exist, stop before building
the dynamic query. This prevents an incomplete profiling run caused by
incorrect configuration metadata.
*/

IF EXISTS
(
    SELECT 1
    FROM bronze.profiling_config AS pc
    LEFT JOIN sys.schemas AS s
        ON pc.SchemaName = s.name
    LEFT JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
       AND pc.TableName = t.name
    LEFT JOIN sys.columns AS c
        ON c.object_id = t.object_id
       AND pc.ColumnName = c.name
    WHERE pc.ProfilingType = 'NUMERIC'
      AND c.column_id IS NULL
)
BEGIN
    THROW 50001,
          'Numeric profiling configuration contains an invalid schema, table, or column.',
          1;
END;


/*
================================================================================
STEP 2: Declare the dynamic SQL variable
================================================================================
*/

DECLARE @SQL NVARCHAR(MAX);


/*
================================================================================
STEP 3: Generate one profiling query for every NUMERIC column
================================================================================

STRING_AGG:
    Combines the generated SELECT statements into one SQL statement.

UNION ALL:
    Combines the profiling results from different columns.

QUOTENAME:
    Delimits schema, table, and column identifiers safely.

REPLACE:
    Escapes apostrophes in metadata values inserted as SQL string literals.

TRY_CONVERT:
    Attempts numeric conversion without failing the entire query because of
    an individual value that cannot be converted.
*/

SELECT
    @SQL = STRING_AGG
    (
        CAST
        (
            N'
            SELECT
                N''' +
                REPLACE(SchemaName + N'.' + TableName, N'''', N'''''') +
                N''' AS TableName,

                N''' +
                REPLACE(ColumnName, N'''', N'''''') +
                N''' AS ColumnName,

                COUNT_BIG(*) AS TotalRows,

                COUNT_BIG(' + QUOTENAME(ColumnName) + N')
                    AS NonNullValues,

                COUNT_BIG(*) - COUNT_BIG(' + QUOTENAME(ColumnName) + N')
                    AS NullValues,

                SUM
                (
                    CASE
                        WHEN ' + QUOTENAME(ColumnName) + N' IS NOT NULL
                         AND TRY_CONVERT(DECIMAL(18,4), ' +
                             QUOTENAME(ColumnName) + N') IS NULL
                        THEN CONVERT(BIGINT, 1)
                        ELSE CONVERT(BIGINT, 0)
                    END
                ) AS InvalidNumericValues,

                MIN
                (
                    TRY_CONVERT(DECIMAL(18,4), ' +
                    QUOTENAME(ColumnName) + N')
                ) AS MinimumValue,

                MAX
                (
                    TRY_CONVERT(DECIMAL(18,4), ' +
                    QUOTENAME(ColumnName) + N')
                ) AS MaximumValue,

                AVG
                (
                    TRY_CONVERT(DECIMAL(18,4), ' +
                    QUOTENAME(ColumnName) + N')
                ) AS AverageValue,

                SUM
                (
                    CASE
                        WHEN TRY_CONVERT(DECIMAL(18,4), ' +
                             QUOTENAME(ColumnName) + N') < 0
                        THEN CONVERT(BIGINT, 1)
                        ELSE CONVERT(BIGINT, 0)
                    END
                ) AS NegativeValues,

                SUM
                (
                    CASE
                        WHEN TRY_CONVERT(DECIMAL(18,4), ' +
                             QUOTENAME(ColumnName) + N') = 0
                        THEN CONVERT(BIGINT, 1)
                        ELSE CONVERT(BIGINT, 0)
                    END
                ) AS ZeroValues

            FROM ' +
                QUOTENAME(SchemaName) + N'.' +
                QUOTENAME(TableName)
            AS NVARCHAR(MAX)
        ),
        N'
        UNION ALL
        '
    ) WITHIN GROUP (ORDER BY TableName, ColumnName)

FROM bronze.profiling_config
WHERE ProfilingType = 'NUMERIC';


/*
================================================================================
STEP 4: Execute the generated profiling query
================================================================================
*/

-- Stop if no columns are configured for numeric profiling.
IF @SQL IS NULL
BEGIN
    THROW 50002,
          'No columns are configured for numeric profiling.',
          1;
END;


-- Wrap the combined query to return results in a consistent order.
SET @SQL =
    N'
    SELECT *
    FROM
    (
        ' + @SQL + N'
    ) AS NumericProfile
    ORDER BY TableName, ColumnName;
    ';


-- Execute the consolidated profiling query.
EXEC sys.sp_executesql @SQL;
