/*
===============================================================================
GOLD LAYER - RESET TABLES
===============================================================================
Purpose:
    Drop the Gold tables in dependency-safe reverse order for a full rebuild.

WARNING:
    This script permanently removes all data stored in the Gold tables.
    Run only when a full Gold rebuild is intended.
    It does not drop the gold schema and does not affect Bronze or Silver.

Database: LogisticsAnalytics
Schema:   gold
===============================================================================
*/

USE LogisticsAnalytics;

-- Facts first: they reference dimensions through foreign keys.
DROP TABLE IF EXISTS gold.fact_safety_incidents;
DROP TABLE IF EXISTS gold.fact_maintenance_records;
DROP TABLE IF EXISTS gold.fact_fuel_purchases;
DROP TABLE IF EXISTS gold.fact_delivery_events;
DROP TABLE IF EXISTS gold.fact_trips;
DROP TABLE IF EXISTS gold.fact_loads;

-- Dimensions after all dependent facts have been removed.
DROP TABLE IF EXISTS gold.dim_facility;
DROP TABLE IF EXISTS gold.dim_route;
DROP TABLE IF EXISTS gold.dim_trailer;
DROP TABLE IF EXISTS gold.dim_truck;
DROP TABLE IF EXISTS gold.dim_driver;
DROP TABLE IF EXISTS gold.dim_customer;
DROP TABLE IF EXISTS gold.dim_date;

PRINT 'Gold tables have been dropped. The gold schema remains in place.';