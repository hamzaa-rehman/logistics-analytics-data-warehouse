/*
===============================================================================
GOLD REPORTING VIEW - FLEET PERFORMANCE
===============================================================================

Purpose:
    Provide a trip-grain reporting dataset for fleet activity, distance,
    fuel consumption, fuel efficiency, and idle-time analysis.

View grain:
    One row per trip (trip_id).

Approved business definitions:
    - Total Trips = COUNT of trip records.
    - Total Distance = SUM(actual_distance_miles).
    - Total Trip Fuel Consumed = SUM(fuel_gallons_used).
    - Weighted Fleet MPG =
      SUM(actual_distance_miles) / NULLIF(SUM(fuel_gallons_used), 0).
    - Average Trip MPG = AVG(average_mpg).
      This is different from weighted fleet MPG.
    - Average Idle Time per Trip = AVG(idle_time_hours).
    - Truck-level analysis excludes trips without an assigned truck.
    - Overall fleet totals retain trips without an assigned truck.

Important limitations:
    - 1,672 trips have no assigned truck. Retain them in overall fleet totals.
    - The dataset does not provide a reliable vehicle availability denominator.
      Do not label trip activity or trips per day as a true utilization rate.
    - Trip fuel consumed is not the same measure as fuel purchased.
    - The source does not establish a historical truck-attribute snapshot.
      Truck attributes reflect the current Type 1 dimension.
    - No route relationship is added: fact_trips has no route_key.

Join strategy:
    - dim_date is an INNER JOIN because dispatch_date_key is mandatory.
    - Truck, driver, and trailer are LEFT JOINs because their assignments
      are optional and their fact keys can be NULL.
    - Dimension joins preserve the one-row-per-trip grain.

Deployment:
    - Connect DBeaver to the LogisticsAnalytics database before execution.
    - This script intentionally contains no batch separators.
    - CREATE VIEW is the first statement in the script, as required by SQL
      Server. The remaining statements validate and query the created view.
    - This script creates or alters the view; it does not modify fact data.
===============================================================================
*/

CREATE OR ALTER VIEW gold.vw_fleet_performance
AS
SELECT
    -- Trip identity and source relationship
    f.trip_fact_key,
    f.trip_id,
    f.load_id,

    -- Dispatch date attributes
    f.dispatch_date_key,
    d.full_date AS dispatch_date,
    d.day_name AS dispatch_day_name,
    d.day_of_week AS dispatch_day_of_week,
    d.week_of_year AS dispatch_iso_week_number,
    d.iso_week_year AS dispatch_iso_week_year,
    d.month_number AS dispatch_month_number,
    d.month_name AS dispatch_month_name,
    d.quarter_number AS dispatch_quarter_number,
    d.year_number AS dispatch_calendar_year,
    d.year_month AS dispatch_year_month,
    d.is_weekend AS is_dispatch_weekend,

    -- Truck attributes
    f.truck_key,
    t.truck_id,
    t.unit_number,
    t.make AS truck_make,
    t.model_year AS truck_model_year,
    t.fuel_type AS truck_fuel_type,
    t.status AS truck_status,
    t.home_terminal AS truck_home_terminal,

    -- Driver attributes
    f.driver_key,
    dr.driver_id,
    dr.first_name AS driver_first_name,
    dr.last_name AS driver_last_name,
    dr.employment_status AS driver_employment_status,

    -- Trailer attributes
    f.trailer_key,
    tr.trailer_id,
    tr.trailer_number,
    tr.trailer_type,

    -- Trip descriptors
    f.trip_status,

    -- Additive trip activity and assignment indicators
    CONVERT(BIGINT, 1) AS trip_count,

    CASE
        WHEN f.truck_key IS NOT NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS assigned_truck_trip_count,

    CASE
        WHEN f.truck_key IS NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS unassigned_truck_trip_count,

    CASE
        WHEN f.driver_key IS NOT NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS assigned_driver_trip_count,

    CASE
        WHEN f.driver_key IS NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS unassigned_driver_trip_count,

    CASE
        WHEN f.trailer_key IS NOT NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS assigned_trailer_trip_count,

    CASE
        WHEN f.trailer_key IS NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS unassigned_trailer_trip_count,

    -- Trip-level operational measures
    f.actual_distance_miles,
    f.actual_duration_hours,
    f.fuel_gallons_used,
    f.average_mpg,
    f.idle_time_hours

FROM gold.fact_trips AS f
INNER JOIN gold.dim_date AS d
    ON f.dispatch_date_key = d.date_key
LEFT JOIN gold.dim_truck AS t
    ON f.truck_key = t.truck_key
LEFT JOIN gold.dim_driver AS dr
    ON f.driver_key = dr.driver_key
LEFT JOIN gold.dim_trailer AS tr
    ON f.trailer_key = tr.trailer_key;

-- ============================================================================
-- VIEW VALIDATION
-- Expected:
--   - View row count equals fact_trips row count.
--   - One view row per trip_id.
--   - Trip measures and assignment counts reconcile to fact_trips.
-- ============================================================================

IF
(
    SELECT COUNT_BIG(*)
    FROM gold.vw_fleet_performance
)
<>
(
    SELECT COUNT_BIG(*)
    FROM gold.fact_trips
)
    THROW 51121, 'vw_fleet_performance row count does not match fact_trips.', 1;

IF EXISTS
(
    SELECT trip_id
    FROM gold.vw_fleet_performance
    GROUP BY trip_id
    HAVING COUNT_BIG(*) <> 1
)
    THROW 51122, 'vw_fleet_performance does not preserve one row per trip.', 1;

-- Check both directions. This catches a mismatch whether an aggregate
-- result exists only in fact_trips or only in the reporting view.
IF EXISTS
(
    SELECT
        COUNT_BIG(*) AS trip_rows,
        SUM(CASE
            WHEN truck_key IS NOT NULL THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END) AS assigned_truck_trips,
        SUM(CASE
            WHEN truck_key IS NULL THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END) AS unassigned_truck_trips,
        SUM(actual_distance_miles) AS total_actual_distance_miles,
        SUM(fuel_gallons_used) AS total_fuel_gallons_used,
        COUNT(average_mpg) AS nonnull_trip_mpg_count,
        SUM(average_mpg) AS sum_trip_mpg,
        COUNT(idle_time_hours) AS nonnull_idle_time_count,
        SUM(idle_time_hours) AS total_idle_time_hours
    FROM gold.fact_trips

    EXCEPT

    SELECT
        COUNT_BIG(*) AS trip_rows,
        SUM(assigned_truck_trip_count) AS assigned_truck_trips,
        SUM(unassigned_truck_trip_count) AS unassigned_truck_trips,
        SUM(actual_distance_miles) AS total_actual_distance_miles,
        SUM(fuel_gallons_used) AS total_fuel_gallons_used,
        COUNT(average_mpg) AS nonnull_trip_mpg_count,
        SUM(average_mpg) AS sum_trip_mpg,
        COUNT(idle_time_hours) AS nonnull_idle_time_count,
        SUM(idle_time_hours) AS total_idle_time_hours
    FROM gold.vw_fleet_performance
)
OR EXISTS
(
    SELECT
        COUNT_BIG(*) AS trip_rows,
        SUM(assigned_truck_trip_count) AS assigned_truck_trips,
        SUM(unassigned_truck_trip_count) AS unassigned_truck_trips,
        SUM(actual_distance_miles) AS total_actual_distance_miles,
        SUM(fuel_gallons_used) AS total_fuel_gallons_used,
        COUNT(average_mpg) AS nonnull_trip_mpg_count,
        SUM(average_mpg) AS sum_trip_mpg,
        COUNT(idle_time_hours) AS nonnull_idle_time_count,
        SUM(idle_time_hours) AS total_idle_time_hours
    FROM gold.vw_fleet_performance

    EXCEPT

    SELECT
        COUNT_BIG(*) AS trip_rows,
        SUM(CASE
            WHEN truck_key IS NOT NULL THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END) AS assigned_truck_trips,
        SUM(CASE
            WHEN truck_key IS NULL THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END) AS unassigned_truck_trips,
        SUM(actual_distance_miles) AS total_actual_distance_miles,
        SUM(fuel_gallons_used) AS total_fuel_gallons_used,
        COUNT(average_mpg) AS nonnull_trip_mpg_count,
        SUM(average_mpg) AS sum_trip_mpg,
        COUNT(idle_time_hours) AS nonnull_idle_time_count,
        SUM(idle_time_hours) AS total_idle_time_hours
    FROM gold.fact_trips
)
    THROW 51123, 'vw_fleet_performance measures or assignment counts do not reconcile to fact_trips.', 1;

-- ============================================================================
-- 1. OVERALL FLEET PERFORMANCE
-- Includes trips without an assigned truck.
-- Weighted Fleet MPG = total distance / total fuel.
-- ============================================================================

SELECT
    COUNT_BIG(*) AS total_trips,
    COUNT(DISTINCT truck_id) AS trucks_with_recorded_trips,
    SUM(assigned_truck_trip_count) AS trips_with_assigned_truck,
    SUM(unassigned_truck_trip_count) AS trips_without_assigned_truck,
    SUM(actual_distance_miles) AS total_actual_distance_miles,
    SUM(fuel_gallons_used) AS total_fuel_gallons_used,
    CAST(
        SUM(actual_distance_miles)
        / NULLIF(SUM(fuel_gallons_used), 0)
        AS DECIMAL(12,6)
    ) AS weighted_fleet_mpg,
    AVG(average_mpg) AS average_recorded_trip_mpg,
    AVG(idle_time_hours) AS average_idle_hours_per_trip
FROM gold.vw_fleet_performance;

-- ============================================================================
-- 2. TRUCK-LEVEL PERFORMANCE
-- Only trips with an assigned truck are included.
-- Overall fleet totals above retain unassigned-truck trips.
-- ============================================================================

SELECT
    truck_id,
    unit_number,
    truck_make,
    truck_model_year,
    truck_fuel_type,
    truck_status,
    COUNT_BIG(*) AS total_trips,
    SUM(actual_distance_miles) AS total_actual_distance_miles,
    SUM(fuel_gallons_used) AS total_fuel_gallons_used,
    CAST(
        SUM(actual_distance_miles)
        / NULLIF(SUM(fuel_gallons_used), 0)
        AS DECIMAL(12,6)
    ) AS weighted_truck_mpg,
    AVG(average_mpg) AS average_recorded_trip_mpg,
    AVG(idle_time_hours) AS average_idle_hours_per_trip
FROM gold.vw_fleet_performance
WHERE truck_id IS NOT NULL
GROUP BY
    truck_id,
    unit_number,
    truck_make,
    truck_model_year,
    truck_fuel_type,
    truck_status
ORDER BY total_actual_distance_miles DESC;

-- ============================================================================
-- 3. ANNUAL FLEET ACTIVITY TREND
-- Includes all trips, including those without an assigned truck.
-- ============================================================================

SELECT
    dispatch_calendar_year,
    COUNT_BIG(*) AS total_trips,
    COUNT(DISTINCT truck_id) AS trucks_with_recorded_trips,
    SUM(actual_distance_miles) AS total_actual_distance_miles,
    SUM(fuel_gallons_used) AS total_fuel_gallons_used,
    CAST(
        SUM(actual_distance_miles)
        / NULLIF(SUM(fuel_gallons_used), 0)
        AS DECIMAL(12,6)
    ) AS weighted_fleet_mpg,
    AVG(idle_time_hours) AS average_idle_hours_per_trip
FROM gold.vw_fleet_performance
GROUP BY dispatch_calendar_year
ORDER BY dispatch_calendar_year;

-- Independent annual check against the underlying fact table.
SELECT
    d.year_number,
    COUNT_BIG(*) AS total_trips,
    COUNT(DISTINCT f.truck_key) AS trucks_with_recorded_trips
FROM gold.fact_trips AS f
INNER JOIN gold.dim_date AS d
    ON f.dispatch_date_key = d.date_key
GROUP BY d.year_number
ORDER BY d.year_number;
