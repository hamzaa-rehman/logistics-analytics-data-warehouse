
/*
    ============================================================
    SILVER LAYER - RESET SCRIPT
    ============================================================

    Purpose:
    Remove existing Silver tables to prepare for a complete
    rebuild of the Silver layer.

    Scope:
    - Drops all 14 Silver tables.
    - Preserves the Silver schema.
    - Does not modify Bronze tables or data.
    - Does not create tables or load data.

    Execution:
    - Tables are dropped in child-to-parent dependency order.
    - Conditional DROP statements allow the script to run
      even when some or all Silver tables do not exist.

    IMPORTANT:
    - DROP TABLE permanently deletes the table and its data.
    - Run only when a deliberate Silver reset or full rebuild
      is required.
    - Do not run as part of normal Silver deployment.
    - After resetting, execute ddl_silver.sql to recreate
      the Silver table structures.

    Database: LogisticsAnalytics
    Schema:   silver
    Tables:   14
*/

-- ============================================================
-- 1. DROP TABLES
-- Child-to-parent dependency order
-- ============================================================

-- Delivery events reference loads, trips and facilities.
IF OBJECT_ID('silver.delivery_events', 'U') IS NOT NULL
    DROP TABLE silver.delivery_events;

-- Safety incidents reference trips, trucks and drivers.
IF OBJECT_ID('silver.safety_incidents', 'U') IS NOT NULL
    DROP TABLE silver.safety_incidents;

-- Fuel purchases reference trips, trucks and drivers.
IF OBJECT_ID('silver.fuel_purchases', 'U') IS NOT NULL
    DROP TABLE silver.fuel_purchases;

-- Maintenance records reference trucks.
IF OBJECT_ID('silver.maintenance_records', 'U') IS NOT NULL
    DROP TABLE silver.maintenance_records;

-- Driver monthly metrics reference drivers.
IF OBJECT_ID('silver.driver_monthly_metrics', 'U') IS NOT NULL
    DROP TABLE silver.driver_monthly_metrics;

-- Truck utilization metrics reference trucks.
IF OBJECT_ID('silver.truck_utilization_metrics', 'U') IS NOT NULL
    DROP TABLE silver.truck_utilization_metrics;

-- Trips reference loads, drivers, trucks and trailers.
IF OBJECT_ID('silver.trips', 'U') IS NOT NULL
    DROP TABLE silver.trips;

-- Loads reference customers and routes.
IF OBJECT_ID('silver.loads', 'U') IS NOT NULL
    DROP TABLE silver.loads;

-- Independent parent entities.
IF OBJECT_ID('silver.trailers', 'U') IS NOT NULL
    DROP TABLE silver.trailers;

IF OBJECT_ID('silver.trucks', 'U') IS NOT NULL
    DROP TABLE silver.trucks;

IF OBJECT_ID('silver.routes', 'U') IS NOT NULL
    DROP TABLE silver.routes;

IF OBJECT_ID('silver.facilities', 'U') IS NOT NULL
    DROP TABLE silver.facilities;

IF OBJECT_ID('silver.drivers', 'U') IS NOT NULL
    DROP TABLE silver.drivers;

IF OBJECT_ID('silver.customers', 'U') IS NOT NULL
    DROP TABLE silver.customers;


-- ============================================================
-- 2. COMPLETION
-- ============================================================

PRINT 'Silver layer reset completed.';
PRINT 'Existing Silver tables have been dropped if present.';
PRINT 'The Silver schema has been preserved.';
PRINT 'Run ddl_silver.sql to recreate the Silver tables.';
