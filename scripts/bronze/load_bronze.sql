
/*
======================================================================
 Stored Procedure: Load Bronze Layer (Source -> Bronze)
======================================================================

Script Purpose:
    This stored procedure loads data into the 'bronze' schema
    from external CSV files located inside a specified folder.

    It performs the following actions:
    - Truncates the existing Bronze tables before loading new data.
    - Uses BULK INSERT to load data from CSV files into Bronze tables.
    - Tracks the number of rows loaded into each table.
    - Measures the loading duration for each table and the entire batch.
    - Displays a summary of the loading process.
    - Handles errors and reports the table where loading failed.

Parameters:
    @DataFolder NVARCHAR(4000)
        Specifies the folder path containing all source CSV files.
        The path must be accessible from inside the SQL Server Docker container.

Usage Example:
    EXEC bronze.load_bronze
        @DataFolder = N'/var/opt/mssql/logistics/';

======================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze
    @DataFolder NVARCHAR(4000)
AS
BEGIN

    -- =============================================
    -- 1. INITIALIZE VARIABLES
    -- =============================================

    -- Prevent SQL Server from displaying unnecessary
    -- messages such as "(14 rows affected)".
    SET NOCOUNT ON;

    -- Store the start time of the entire loading process.
    DECLARE @BatchStartTime DATETIME = GETDATE();

    -- Store the start time of each individual table load.
    DECLARE @TableStartTime DATETIME;

    -- Counter used to move through the file mapping.
    DECLARE @Counter INT = 1;

    -- Total number of tables/files to load.
    DECLARE @TotalTables INT;

    -- Variables for the current table and CSV file.
    DECLARE @TableName SYSNAME;
    DECLARE @FileName NVARCHAR(255);

    -- Variables for constructing the complete file path.
    DECLARE @FilePath NVARCHAR(4000);
    DECLARE @EscapedFilePath NVARCHAR(4000);

    -- Variable used to store dynamically constructed SQL.
    DECLARE @SQL NVARCHAR(MAX);

    -- Store the number of rows loaded into each table.
    DECLARE @Rows BIGINT;

    -- Store the combined number of rows loaded.
    DECLARE @TotalRows BIGINT = 0;


    -- =============================================
    -- 2. VALIDATE AND PREPARE FOLDER PATH
    -- =============================================

    -- Check whether the folder path is missing or empty.
    IF @DataFolder IS NULL OR LTRIM(RTRIM(@DataFolder)) = ''
    BEGIN
        THROW 50001, 'Data folder path is required.', 1;
    END;

    -- Remove unnecessary spaces from the beginning and end.
    SET @DataFolder = LTRIM(RTRIM(@DataFolder));

    -- Add a trailing slash if the folder path does not
    -- already end with a slash or backslash.
    IF RIGHT(@DataFolder, 1) NOT IN ('/', '\')
    BEGIN
        SET @DataFolder = @DataFolder +
            CASE
                -- Use backslash for Windows paths.
                WHEN CHARINDEX('\', @DataFolder) > 0
                 AND CHARINDEX('/', @DataFolder) = 0
                THEN '\'

                -- Use forward slash for Linux/macOS paths.
                ELSE '/'
            END;
    END;


    -- =============================================
    -- 3. CREATE FILE MAPPING
    -- =============================================

    -- Create a temporary table variable to store
    -- the relationship between Bronze tables and CSV files.
    DECLARE @Files TABLE
    (
        -- Automatically generate sequential IDs (1, 2, 3...).
        ID INT IDENTITY(1,1),

        -- Name of the corresponding Bronze table.
        TableName SYSNAME,

        -- Name of the source CSV file.
        FileName NVARCHAR(255)
    );

    -- Insert all 14 table and CSV file mappings.
    INSERT INTO @Files (TableName, FileName)
    VALUES
        ('customers', 'customers.csv'),
        ('delivery_events', 'delivery_events.csv'),
        ('driver_monthly_metrics', 'driver_monthly_metrics.csv'),
        ('drivers', 'drivers.csv'),
        ('facilities', 'facilities.csv'),
        ('fuel_purchases', 'fuel_purchases.csv'),
        ('loads', 'loads.csv'),
        ('maintenance_records', 'maintenance_records.csv'),
        ('routes', 'routes.csv'),
        ('safety_incidents', 'safety_incidents.csv'),
        ('trailers', 'trailers.csv'),
        ('trips', 'trips.csv'),
        ('truck_utilization_metrics', 'truck_utilization_metrics.csv'),
        ('trucks', 'trucks.csv');

    -- Count how many tables/files need to be processed.
    SELECT @TotalTables = COUNT(*)
    FROM @Files;


    -- =============================================
    -- 4. LOAD BRONZE TABLES
    -- =============================================

    -- TRY block contains the loading process.
    -- If an error occurs, execution moves to CATCH.
    BEGIN TRY

        -- Repeat until all mapped tables have been processed.
        WHILE @Counter <= @TotalTables
        BEGIN

            -- Get the table name and CSV filename
            -- corresponding to the current counter.
            SELECT
                @TableName = TableName,
                @FileName = FileName
            FROM @Files
            WHERE ID = @Counter;


            -- Construct the complete CSV file path
            -- by combining the folder path and filename.
            SET @FilePath = @DataFolder + @FileName;

            -- Escape single quotes in the file path
            -- to prevent errors when constructing dynamic SQL.
            SET @EscapedFilePath = REPLACE(@FilePath, '''', '''''');


            -- Record the starting time for this table.
            SET @TableStartTime = GETDATE();

            PRINT '----------------------------------------';
            PRINT 'Loading table: ' + @TableName;


            -- Empty the existing Bronze table before reloading.
            -- TRUNCATE removes all rows but keeps the table structure.
            SET @SQL =
                N'TRUNCATE TABLE bronze.' + QUOTENAME(@TableName) + N';';

            EXEC sys.sp_executesql @SQL;


            -- Load the CSV file into its corresponding Bronze table.
            SET @SQL =
                N'BULK INSERT bronze.' + QUOTENAME(@TableName) +
                N' FROM ''' + @EscapedFilePath + N'''
                  WITH
                  (
                      FORMAT = ''CSV'',
                      FIRSTROW = 2,
                      TABLOCK
                  );';

            -- Execute the BULK INSERT command.
            EXEC sys.sp_executesql @SQL;


            -- Count the rows loaded into the current Bronze table.
            SET @SQL =
                N'SELECT @RowCount = COUNT_BIG(*)
                  FROM bronze.' + QUOTENAME(@TableName) + N';';

            -- Execute the row-count query and return its result
            -- into the @Rows variable.
            EXEC sys.sp_executesql
                @SQL,
                N'@RowCount BIGINT OUTPUT',
                @RowCount = @Rows OUTPUT;


            -- Add the current table's row count to the overall total.
            SET @TotalRows = @TotalRows + @Rows;


            -- Display the number of rows loaded into this table.
            PRINT 'Loaded rows: ' + CAST(@Rows AS VARCHAR(30));

            -- Display how many seconds this table took to load.
            PRINT 'Duration: ' +
                CAST(DATEDIFF(SECOND, @TableStartTime, GETDATE()) AS VARCHAR(20))
                + ' seconds';


            -- Increase the counter to process the next table.
            SET @Counter = @Counter + 1;

        END;


        -- =============================================
        -- 5. DISPLAY FINAL SUMMARY
        -- =============================================

        -- Display a summary after all tables are loaded.
        PRINT '========================================';
        PRINT 'BRONZE LOADING COMPLETED';

        PRINT 'Total tables loaded: ' + CAST(@TotalTables AS VARCHAR(10));

        PRINT 'Total rows loaded: ' + CAST(@TotalRows AS VARCHAR(30));

        -- Display the total duration of the loading process.
        PRINT 'Total duration: ' +
            CAST(DATEDIFF(SECOND, @BatchStartTime, GETDATE()) AS VARCHAR(20))
            + ' seconds';

        PRINT '========================================';


    END TRY

    -- CATCH block executes if an error occurs in the TRY block.
    BEGIN CATCH

        PRINT '========================================';
        PRINT 'BRONZE LOADING FAILED';

        -- Display the table that was being processed when the error occurred.
        PRINT 'Table being processed: ' + COALESCE(@TableName, 'Unknown');

        -- Display the actual SQL Server error message.
        PRINT 'Error: ' + ERROR_MESSAGE();

        PRINT '========================================';

        -- Re-raise the original error so it is not silently ignored.
        THROW;

    END CATCH;

END;

-- =============================================
-- EXECUTE BRONZE LOADING PROCEDURE
-- =============================================

-- Load all 14 CSV files from the folder inside
-- the Docker SQL Server container into Bronze tables.
-- The folder was populated by copying the CSV files
-- from the Mac into the Docker container.

EXEC bronze.load_bronze
    @DataFolder = N'/var/opt/mssql/logistics/';


