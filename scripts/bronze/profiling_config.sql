/*
================================================================================
Project:        Logistics Analytics Data Warehouse
Layer:          Bronze
Script:         profiling_config.sql
Purpose:        Create and validate the metadata table used for column profiling.

Description:
    Stores one profiling category for each configured Bronze column.
    The profiling scripts use this metadata to select the appropriate checks.

Supported categories:
    NUMERIC, DATE, DATETIME, IDENTIFIER, CATEGORY, TEXT

Prerequisite:
    The bronze schema must already exist.

Execution:
    Run once to create the table. Import the 150 configuration rows separately
    from the prepared CSV file. The validation queries can be rerun at any time.
================================================================================
*/

-- STEP 1: Create the profiling configuration table if it does not exist.
IF OBJECT_ID(N'bronze.profiling_config', N'U') IS NULL
BEGIN
    CREATE TABLE bronze.profiling_config
    (
        SchemaName     VARCHAR(128) NOT NULL,
        TableName      VARCHAR(128) NOT NULL,
        ColumnName     VARCHAR(128) NOT NULL,
        ProfilingType  VARCHAR(20)  NOT NULL,

        -- A Bronze column can have only one profiling configuration.
        CONSTRAINT PK_profiling_config
            PRIMARY KEY (SchemaName, TableName, ColumnName),

        -- Allow only the profiling categories supported by this project.
        CONSTRAINT CK_profiling_config_ProfilingType
            CHECK
            (
                ProfilingType IN
                (
                    'NUMERIC',
                    'DATE',
                    'DATETIME',
                    'IDENTIFIER',
                    'CATEGORY',
                    'TEXT'
                )
            )
    );

    PRINT 'Profiling configuration table created successfully.';
END;
ELSE
BEGIN
    PRINT 'Profiling configuration table already exists. No changes made.';
END;
GO


/*
================================================================================
STEP 2: Validate the imported configuration
================================================================================
*/

-- Check the total number of configured columns.
SELECT
    COUNT(*) AS TotalConfiguredColumns
FROM bronze.profiling_config;


-- Check for duplicate schema/table/column combinations.
-- Expected result: no rows.
SELECT
    SchemaName,
    TableName,
    ColumnName,
    COUNT(*) AS DuplicateCount
FROM bronze.profiling_config
GROUP BY
    SchemaName,
    TableName,
    ColumnName
HAVING COUNT(*) > 1;


-- Review the number of columns assigned to each profiling category.
SELECT
    ProfilingType,
    COUNT(*) AS ColumnCount
FROM bronze.profiling_config
GROUP BY ProfilingType
ORDER BY ProfilingType;


-- Review the columns configured for numeric profiling.
SELECT
    SchemaName,
    TableName,
    ColumnName
FROM bronze.profiling_config
WHERE ProfilingType = 'NUMERIC'
ORDER BY
    TableName,
    ColumnName;
