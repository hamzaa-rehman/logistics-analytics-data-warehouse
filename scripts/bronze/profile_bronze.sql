/*
    ============================================================
    BRONZE LAYER - COLUMN-LEVEL DATA PROFILING
    ============================================================

    Purpose:
    Profile every column in the Bronze schema using metadata-driven
    dynamic SQL.

    Current checks:
    - Total row count
    - NULL count and non-NULL count
    - Distinct non-NULL values
    - Duplicate occurrences among non-NULL values
    - Empty-string count
    - Whitespace-only value count

    Notes:
    - Bronze columns are stored as VARCHAR, so this script profiles
      their ingested textual values.
    - COUNT(DISTINCT column) excludes NULL values.
    - DuplicateCount = NonNullCount - DistinctCount. It measures
      repeated occurrences, not the number of duplicate groups
      or duplicate records.
    - Text comparisons follow the column/database collation.
      Under a case-insensitive collation, values differing only
      by letter case may be treated as equal.
    - WhitespaceCount detects values made only of ordinary spaces
      using LTRIM/RTRIM; it does not detect every Unicode whitespace.
    - This script does not calculate numeric/date minimums or
      maximums. Those will be added through the metadata-driven
      profiling enhancement.
*/

DECLARE @SQL NVARCHAR(MAX);

-- STEP 1:
-- Read Bronze table and column metadata from SQL Server system
-- catalog views, then generate one SELECT statement per column.
-- STRING_AGG combines those statements using UNION ALL.

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
                    THEN 1 END
                ) AS NonNullCount,

                COUNT_BIG(DISTINCT ' + QUOTENAME(c.name) + N')
                    AS DistinctCount,

                COUNT_BIG(' + QUOTENAME(c.name) + N')
                    - COUNT_BIG(DISTINCT ' + QUOTENAME(c.name) + N')
                    AS DuplicateCount,

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


-- STEP 2:
-- Add a consistent sort order to the combined profiling results.

SET @SQL = @SQL + N'
ORDER BY TableName, ColumnName;';


-- STEP 3:
-- Execute the generated profiling query.

EXEC sys.sp_executesql @SQL;
