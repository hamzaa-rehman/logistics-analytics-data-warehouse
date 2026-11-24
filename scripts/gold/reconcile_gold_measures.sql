/*
===============================================================================
GOLD LAYER - MEASURE RECONCILIATION (SILVER -> GOLD)
===============================================================================
Database: LogisticsAnalytics
Source:   silver
Target:   gold

Purpose:
    Compare each source fact row with its Gold counterpart using the source
    business identifier and verify every measure is preserved exactly.

How to read:
    - Each result set reports source rows, Gold rows, matched rows and
      measure-mismatch rows.
    - A zero mismatch count means all listed measures match row by row,
      including NULL-to-NULL comparisons.
    - Missing source/Gold counterparts are reported separately.
    - Exact row-level comparison is stronger than comparing SUM totals:
      offsetting errors cannot hide each other.
    - Run after gold.load_gold has completed successfully.

Important modelling notes:
    - Fuel purchased (fuel_purchases.gallons) is distinct from trip fuel used.
    - average_mpg and price_per_gallon are non-additive; they are compared
      row by row and must not be summed in reporting.
    - No cross-fact joins are used.
    - No COALESCE-to-zero is applied; source NULLs must remain NULL.
    - This script validates preservation, not whether source business
      calculations (e.g. total_cost) are economically correct.

===============================================================================
*/

USE LogisticsAnalytics;
SET NOCOUNT ON;

-- ============================================================================
-- 1. LOADS
-- Grain: one row per load.
-- Measures: weight, pieces, revenue, fuel surcharge, accessorial charges.
-- ============================================================================

;WITH comparison AS
(
    SELECT
        COALESCE(s.load_id, g.load_id) AS business_key,
        CASE WHEN s.load_id IS NULL THEN 0 ELSE 1 END AS source_exists,
        CASE WHEN g.load_id IS NULL THEN 0 ELSE 1 END AS gold_exists,
        CASE WHEN EXISTS
        (
            SELECT s.weight_lbs, s.pieces, s.revenue,
                   s.fuel_surcharge, s.accessorial_charges
            EXCEPT
            SELECT g.weight_lbs, g.pieces, g.revenue,
                   g.fuel_surcharge, g.accessorial_charges
        ) THEN 1 ELSE 0 END AS measures_differ
    FROM silver.loads AS s
    FULL OUTER JOIN gold.fact_loads AS g
        ON s.load_id = g.load_id
)
SELECT
    'fact_loads' AS fact_table,
    COUNT_BIG(*) AS compared_business_keys,
    SUM(source_exists) AS source_rows,
    SUM(gold_exists) AS gold_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN 1 ELSE 0 END) AS matched_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 0 THEN 1 ELSE 0 END) AS missing_in_gold,
    SUM(CASE WHEN source_exists = 0 AND gold_exists = 1 THEN 1 ELSE 0 END) AS missing_in_silver,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN measures_differ ELSE 0 END) AS measure_mismatch_rows
FROM comparison;

-- ============================================================================
-- 2. TRIPS
-- Grain: one row per trip.
-- Measures: distance, duration, fuel used, average MPG, idle time.
-- ============================================================================

;WITH comparison AS
(
    SELECT
        COALESCE(s.trip_id, g.trip_id) AS business_key,
        CASE WHEN s.trip_id IS NULL THEN 0 ELSE 1 END AS source_exists,
        CASE WHEN g.trip_id IS NULL THEN 0 ELSE 1 END AS gold_exists,
        CASE WHEN EXISTS
        (
            SELECT s.actual_distance_miles, s.actual_duration_hours,
                   s.fuel_gallons_used, s.average_mpg, s.idle_time_hours
            EXCEPT
            SELECT g.actual_distance_miles, g.actual_duration_hours,
                   g.fuel_gallons_used, g.average_mpg, g.idle_time_hours
        ) THEN 1 ELSE 0 END AS measures_differ
    FROM silver.trips AS s
    FULL OUTER JOIN gold.fact_trips AS g
        ON s.trip_id = g.trip_id
)
SELECT
    'fact_trips' AS fact_table,
    COUNT_BIG(*) AS compared_business_keys,
    SUM(source_exists) AS source_rows,
    SUM(gold_exists) AS gold_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN 1 ELSE 0 END) AS matched_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 0 THEN 1 ELSE 0 END) AS missing_in_gold,
    SUM(CASE WHEN source_exists = 0 AND gold_exists = 1 THEN 1 ELSE 0 END) AS missing_in_silver,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN measures_differ ELSE 0 END) AS measure_mismatch_rows
FROM comparison;

-- ============================================================================
-- 3. FUEL PURCHASES
-- Grain: one row per fuel purchase.
-- Measures: gallons purchased, unit price, total purchase cost.
-- ============================================================================

;WITH comparison AS
(
    SELECT
        COALESCE(s.fuel_purchase_id, g.fuel_purchase_id) AS business_key,
        CASE WHEN s.fuel_purchase_id IS NULL THEN 0 ELSE 1 END AS source_exists,
        CASE WHEN g.fuel_purchase_id IS NULL THEN 0 ELSE 1 END AS gold_exists,
        CASE WHEN EXISTS
        (
            SELECT s.gallons, s.price_per_gallon, s.total_cost
            EXCEPT
            SELECT g.gallons, g.price_per_gallon, g.total_cost
        ) THEN 1 ELSE 0 END AS measures_differ
    FROM silver.fuel_purchases AS s
    FULL OUTER JOIN gold.fact_fuel_purchases AS g
        ON s.fuel_purchase_id = g.fuel_purchase_id
)
SELECT
    'fact_fuel_purchases' AS fact_table,
    COUNT_BIG(*) AS compared_business_keys,
    SUM(source_exists) AS source_rows,
    SUM(gold_exists) AS gold_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN 1 ELSE 0 END) AS matched_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 0 THEN 1 ELSE 0 END) AS missing_in_gold,
    SUM(CASE WHEN source_exists = 0 AND gold_exists = 1 THEN 1 ELSE 0 END) AS missing_in_silver,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN measures_differ ELSE 0 END) AS measure_mismatch_rows
FROM comparison;

-- ============================================================================
-- 4. MAINTENANCE RECORDS
-- Grain: one row per maintenance record.
-- Measures: labor hours/cost, parts cost, total cost, downtime.
-- ============================================================================

;WITH comparison AS
(
    SELECT
        COALESCE(s.maintenance_id, g.maintenance_id) AS business_key,
        CASE WHEN s.maintenance_id IS NULL THEN 0 ELSE 1 END AS source_exists,
        CASE WHEN g.maintenance_id IS NULL THEN 0 ELSE 1 END AS gold_exists,
        CASE WHEN EXISTS
        (
            SELECT s.labor_hours, s.labor_cost, s.parts_cost,
                   s.total_cost, s.downtime_hours
            EXCEPT
            SELECT g.labor_hours, g.labor_cost, g.parts_cost,
                   g.total_cost, g.downtime_hours
        ) THEN 1 ELSE 0 END AS measures_differ
    FROM silver.maintenance_records AS s
    FULL OUTER JOIN gold.fact_maintenance_records AS g
        ON s.maintenance_id = g.maintenance_id
)
SELECT
    'fact_maintenance_records' AS fact_table,
    COUNT_BIG(*) AS compared_business_keys,
    SUM(source_exists) AS source_rows,
    SUM(gold_exists) AS gold_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN 1 ELSE 0 END) AS matched_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 0 THEN 1 ELSE 0 END) AS missing_in_gold,
    SUM(CASE WHEN source_exists = 0 AND gold_exists = 1 THEN 1 ELSE 0 END) AS missing_in_silver,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN measures_differ ELSE 0 END) AS measure_mismatch_rows
FROM comparison;

-- ============================================================================
-- 5. SAFETY INCIDENTS
-- Grain: one row per safety incident.
-- Measures: vehicle damage, cargo damage, claim amount.
-- ============================================================================

;WITH comparison AS
(
    SELECT
        COALESCE(s.incident_id, g.incident_id) AS business_key,
        CASE WHEN s.incident_id IS NULL THEN 0 ELSE 1 END AS source_exists,
        CASE WHEN g.incident_id IS NULL THEN 0 ELSE 1 END AS gold_exists,
        CASE WHEN EXISTS
        (
            SELECT s.vehicle_damage_cost, s.cargo_damage_cost, s.claim_amount
            EXCEPT
            SELECT g.vehicle_damage_cost, g.cargo_damage_cost, g.claim_amount
        ) THEN 1 ELSE 0 END AS measures_differ
    FROM silver.safety_incidents AS s
    FULL OUTER JOIN gold.fact_safety_incidents AS g
        ON s.incident_id = g.incident_id
)
SELECT
    'fact_safety_incidents' AS fact_table,
    COUNT_BIG(*) AS compared_business_keys,
    SUM(source_exists) AS source_rows,
    SUM(gold_exists) AS gold_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN 1 ELSE 0 END) AS matched_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 0 THEN 1 ELSE 0 END) AS missing_in_gold,
    SUM(CASE WHEN source_exists = 0 AND gold_exists = 1 THEN 1 ELSE 0 END) AS missing_in_silver,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN measures_differ ELSE 0 END) AS measure_mismatch_rows
FROM comparison;

-- ============================================================================
-- 6. DELIVERY EVENTS
-- Grain: one row per delivery event.
-- Measures/indicators: detention minutes and on-time flag.
-- ============================================================================

;WITH comparison AS
(
    SELECT
        COALESCE(s.event_id, g.event_id) AS business_key,
        CASE WHEN s.event_id IS NULL THEN 0 ELSE 1 END AS source_exists,
        CASE WHEN g.event_id IS NULL THEN 0 ELSE 1 END AS gold_exists,
        CASE WHEN EXISTS
        (
            SELECT s.detention_minutes, s.on_time_flag
            EXCEPT
            SELECT g.detention_minutes, g.on_time_flag
        ) THEN 1 ELSE 0 END AS measures_differ
    FROM silver.delivery_events AS s
    FULL OUTER JOIN gold.fact_delivery_events AS g
        ON s.event_id = g.event_id
)
SELECT
    'fact_delivery_events' AS fact_table,
    COUNT_BIG(*) AS compared_business_keys,
    SUM(source_exists) AS source_rows,
    SUM(gold_exists) AS gold_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN 1 ELSE 0 END) AS matched_rows,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 0 THEN 1 ELSE 0 END) AS missing_in_gold,
    SUM(CASE WHEN source_exists = 0 AND gold_exists = 1 THEN 1 ELSE 0 END) AS missing_in_silver,
    SUM(CASE WHEN source_exists = 1 AND gold_exists = 1 THEN measures_differ ELSE 0 END) AS measure_mismatch_rows
FROM comparison;

-- ============================================================================
-- 7. DETAIL: SHOW THE EXACT ROWS WITH MEASURE DIFFERENCES
--    Run only for a fact table whose measure_mismatch_rows is greater than 0.
--    Example below: loads. Change the source/target/key/measure columns as
--    needed for the affected fact, using the mappings in sections 1-6.
-- ============================================================================

-- SELECT
--     s.load_id,
--     s.weight_lbs AS silver_weight_lbs,
--     g.weight_lbs AS gold_weight_lbs,
--     s.pieces AS silver_pieces,
--     g.pieces AS gold_pieces,
--     s.revenue AS silver_revenue,
--     g.revenue AS gold_revenue,
--     s.fuel_surcharge AS silver_fuel_surcharge,
--     g.fuel_surcharge AS gold_fuel_surcharge,
--     s.accessorial_charges AS silver_accessorial_charges,
--     g.accessorial_charges AS gold_accessorial_charges
-- FROM silver.loads AS s
-- INNER JOIN gold.fact_loads AS g ON s.load_id = g.load_id
-- WHERE EXISTS
-- (
--     SELECT s.weight_lbs, s.pieces, s.revenue,
--            s.fuel_surcharge, s.accessorial_charges
--     EXCEPT
--     SELECT g.weight_lbs, g.pieces, g.revenue,
--            g.fuel_surcharge, g.accessorial_charges
-- )
-- ORDER BY s.load_id;

-- ============================================================================
-- END
-- ============================================================================
