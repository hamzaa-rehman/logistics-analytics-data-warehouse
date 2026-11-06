
-- =============================================
-- BRONZE LAYER: NULL AND BLANK VALUE PROFILING
-- Purpose: Profile every column in the Bronze schema.
-- Method: Dynamic SQL + STRING_AGG()
-- =============================================

DECLARE @SQL NVARCHAR(MAX);
-- STEP 1: Read all Bronze table and column names
-- and dynamically generate a profiling query for each column.

SELECT
    @SQL = STRING_AGG(
        CAST(
            N'SELECT
                N''' + REPLACE(t.name, '''', '''''') + N''' AS TableName,

                N''' + REPLACE(c.name, '''', '''''') + N''' AS ColumnName,

                COUNT_BIG(*) AS TotalRows,

                COUNT_BIG(
                    CASE WHEN ' + QUOTENAME(c.name) + N' IS NULL
                    THEN 1 END
                ) AS NullCount,

                COUNT_BIG(
                    CASE WHEN ' + QUOTENAME(c.name) + N' IS NOT NULL
                    AND DATALENGTH(' + QUOTENAME(c.name) + N') = 0
                    THEN 1 END
                ) AS EmptyCount,

                COUNT_BIG(
                    CASE WHEN ' + QUOTENAME(c.name) + N' IS NOT NULL
                    AND DATALENGTH(' + QUOTENAME(c.name) + N') > 0
                    AND DATALENGTH(LTRIM(RTRIM(' + QUOTENAME(c.name) + N'))) = 0
                    THEN 1 END
                ) AS WhitespaceCount

            FROM ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name)

            AS NVARCHAR(MAX) 
            ),
        N' UNION ALL '
    )

FROM sys.tables t
INNER JOIN sys.schemas s
    ON t.schema_id = s.schema_id
INNER JOIN sys.columns c
    ON t.object_id = c.object_id
WHERE s.name = 'bronze';


-- STEP 2: Add sorting to the generated query.

SET @SQL = @SQL + N'
ORDER BY TableName, ColumnName;';


-- STEP 3: Execute the generated SQL.

EXEC sys.sp_executesql @SQL;
