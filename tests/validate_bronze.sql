
-- =============================================
-- BRONZE LAYER VALIDATION
-- Purpose:
-- Check table existence, row counts, column counts,
-- and whether all columns use VARCHAR.
--
-- The script compares expected values with actual
-- values stored in the Bronze layer.
-- =============================================


-- STEP 1: Store the expected details for each Bronze table.
-- These values come from the source CSV files and
-- the expected Bronze table structures.

DECLARE @Expected TABLE
(
    TableName SYSNAME,
    ExpectedRows BIGINT,
    ExpectedColumns INT
);

-- Insert the expected row and column counts for all 14 tables.

INSERT INTO @Expected
VALUES
    ('customers', 200, 8),
    ('delivery_events', 170820, 11),
    ('driver_monthly_metrics', 4464, 9),
    ('drivers', 150, 12),
    ('facilities', 50, 9),
    ('fuel_purchases', 196442, 11),
    ('loads', 85410, 12),
    ('maintenance_records', 2920, 12),
    ('routes', 58, 9),
    ('safety_incidents', 170, 15),
    ('trailers', 180, 9),
    ('trips', 85410, 12),
    ('truck_utilization_metrics', 3312, 10),
    ('trucks', 120, 11);


-- STEP 2: Create a temporary table variable to collect
-- the actual validation results for each Bronze table.
-- It exists only while this script is executing.

DECLARE @Results TABLE
(
    TableName SYSNAME,
    ExpectedRows BIGINT,
    ActualRows BIGINT NULL,
    ExpectedColumns INT,
    ActualColumns INT NULL,
    NonVarcharColumns INT NULL
);


-- STEP 3: Declare variables used during validation.
-- These variables hold the details of the table currently
-- being checked and its actual validation results.

DECLARE @TableName SYSNAME;
DECLARE @ExpectedRows BIGINT;
DECLARE @ExpectedColumns INT;
DECLARE @ActualRows BIGINT;
DECLARE @ActualColumns INT;
DECLARE @NonVarcharColumns INT;
DECLARE @SQL NVARCHAR(MAX);


-- STEP 4: Create a cursor.
-- The cursor reads the expected table details one row
-- at a time, allowing us to validate each table separately.

DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR

SELECT TableName, ExpectedRows, ExpectedColumns
FROM @Expected;


-- STEP 5: Start the cursor and retrieve the first table's
-- expected details into the variables.

OPEN table_cursor;

FETCH NEXT FROM table_cursor
INTO @TableName, @ExpectedRows, @ExpectedColumns;


-- STEP 6: Repeat the validation while the cursor
-- successfully retrieves another table.

WHILE @@FETCH_STATUS = 0

BEGIN

    -- Reset actual values before checking the next table.
    -- This prevents results from the previous table
    -- from carrying over.

    SET @ActualRows = NULL;
    SET @ActualColumns = NULL;
    SET @NonVarcharColumns = NULL;


    -- STEP 7: Check whether the current table exists
    -- in the Bronze schema.
    -- OBJECT_ID returns an object ID if the table exists;
    -- otherwise, it returns NULL.

    IF OBJECT_ID(N'bronze.' + @TableName, N'U') IS NOT NULL

    BEGIN

        -- STEP 8: Build a dynamic SQL query to count
        -- the rows in the current Bronze table.
        -- The table name changes during each cursor iteration.

        SET @SQL =
            N'SELECT @Rows = COUNT_BIG(*)
              FROM bronze.' + QUOTENAME(@TableName) + N';';


        -- Execute the generated SQL.
        -- The OUTPUT parameter sends the row count
        -- back into the @ActualRows variable.

        EXEC sys.sp_executesql
            @SQL,
            N'@Rows BIGINT OUTPUT',
            @Rows = @ActualRows OUTPUT;


        -- STEP 9: Check the current table's column structure.
        -- sys.columns contains metadata about database columns.
        --
        -- COUNT(*) counts the columns.
        -- SUM(CASE...) counts columns whose data type
        -- is not VARCHAR.

        SELECT
            @ActualColumns = COUNT(*),
            @NonVarcharColumns =
                SUM(CASE
                    WHEN TYPE_NAME(user_type_id) <> 'varchar'
                    THEN 1
                    ELSE 0
                END)
        FROM sys.columns
        
        -- Restrict the metadata check to the current table.
        WHERE object_id = OBJECT_ID(N'bronze.' + @TableName);
    END;

    -- STEP 10: Store the expected and actual values
    -- in the results table variable.
    -- If the table does not exist, actual values remain NULL.
    
    INSERT INTO @Results
    VALUES
    (
        @TableName,
        @ExpectedRows,
        @ActualRows,
        @ExpectedColumns,
        @ActualColumns,
        @NonVarcharColumns
    );
    -- STEP 11: Move the cursor to the next table
    -- and load its expected details into the variables.
    FETCH NEXT FROM table_cursor
    INTO @TableName, @ExpectedRows, @ExpectedColumns;
END;

-- STEP 12: Close and release the cursor after
-- all expected tables have been processed.
CLOSE table_cursor;
DEALLOCATE table_cursor;

-- =============================================
-- STEP 13: DISPLAY THE FINAL VALIDATION REPORT
-- Compare expected values against actual values
-- and assign a validation status to each table.
-- =============================================

SELECT
    TableName,
    ExpectedRows,
    ActualRows,
    -- Difference between actual and expected row counts.
    -- Zero means the counts match.
    ActualRows - ExpectedRows AS RowDifference,
    ExpectedColumns,
    ActualColumns,
    NonVarcharColumns,
    -- Assign a status based on the validation results.
    -- SQL checks each WHEN condition in order.
    CASE
        WHEN ActualRows IS NULL 
        	THEN 'TABLE MISSING'
        WHEN ActualRows <> ExpectedRows
            THEN 'ROW COUNT MISMATCH'
        WHEN ActualColumns <> ExpectedColumns
            THEN 'COLUMN COUNT MISMATCH'
        WHEN NonVarcharColumns <> 0
            THEN 'NON-VARCHAR COLUMNS FOUND'
        ELSE 'CHECKS PASSED'
    END AS ValidationStatus
FROM @Results
ORDER BY TableName;


-- =============================================
-- STEP 14: DISPLAY BRONZE COLUMN DETAILS
-- This query provides a column-level inventory
-- of all tables in the Bronze schema.
--
-- It displays column names, their positions,
-- data types, and maximum lengths.
-- =============================================

SELECT
    t.name AS TableName,
    c.column_id AS ColumnPosition,
    c.name AS ColumnName,
    TYPE_NAME(c.user_type_id) AS DataType,
    c.max_length AS MaxLength
FROM sys.tables t
-- Connect each table to its schema.
INNER JOIN sys.schemas s
    ON t.schema_id = s.schema_id
-- Connect each table to its individual columns.
INNER JOIN sys.columns c
    ON t.object_id = c.object_id
-- Only display tables belonging to the Bronze schema.
WHERE s.name = 'bronze'
-- Sort by table name and then by column position.
ORDER BY
    t.name,
    c.column_id;
