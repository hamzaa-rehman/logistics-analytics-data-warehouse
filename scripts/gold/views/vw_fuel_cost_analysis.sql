/*
===============================================================================
GOLD REPORTING VIEW - FUEL COST ANALYSIS
===============================================================================

Purpose:
    Provide a purchase-grain reporting dataset for fuel purchasing activity,
    recorded fuel costs, unit prices, and truck/driver assignment analysis.

View grain:
    One row per fuel purchase (fuel_purchase_id).

Approved business definitions:
    - Fuel Purchases = COUNT of purchase records.
    - Total Gallons Purchased = SUM(gallons).
    - Recorded Fuel Cost = SUM(total_cost).
    - Weighted Average Recorded Cost per Gallon =
      SUM(total_cost) / NULLIF(SUM(gallons), 0).
    - Average Recorded Price per Gallon = AVG(price_per_gallon).
      This is a simple average of purchase-level prices and differs from
      the weighted average.
    - Truck/driver rankings include only purchases with the respective
      entity assignment.
    - Overall totals retain purchases with missing truck or driver assignment.

Important limitations:
    - Use the recorded total_cost; do not recalculate it from gallons and
      price_per_gallon. A prior investigation identified 2,478 records with
      a one-cent difference after recalculation and rounding.
    - Fuel purchased is not the same measure as fuel consumed on trips.
      Do not interpret purchase totals as fuel usage, loss, or wastage.
    - 3,880 purchases have no truck assignment and 3,988 have no driver
      assignment. These purchases remain in overall totals.
    - January 2025 contains only 201 purchases and is a partial period.
    - Source currency has not been confirmed. Do not add a currency symbol.
    - No fact-to-fact joins are used.

Join strategy:
    - dim_date is an INNER JOIN because purchase_date_key is mandatory.
    - Truck and driver are LEFT JOINs because assignments are optional.
    - Dimension joins use unique surrogate keys and preserve purchase grain.

Deployment:
    - Connect DBeaver to the LogisticsAnalytics database before execution.
    - This script contains no GO batch separators or USE statement.
    - CREATE OR ALTER VIEW is the first SQL statement in the batch.
===============================================================================
*/

CREATE OR ALTER VIEW gold.vw_fuel_cost_analysis
AS
SELECT
    -- Purchase identity and source traceability
    f.fuel_purchase_fact_key,
    f.fuel_purchase_id,
    f.trip_id,

    -- Truck attributes (optional assignment)
    f.truck_key,
    t.truck_id,
    t.unit_number,
    t.make AS truck_make,
    t.model_year AS truck_model_year,
    t.fuel_type AS truck_fuel_type,
    t.status AS truck_status,

    -- Driver attributes (optional assignment)
    f.driver_key,
    dr.driver_id,
    dr.first_name AS driver_first_name,
    dr.last_name AS driver_last_name,
    dr.employment_status AS driver_employment_status,

    -- Purchase date attributes
    f.purchase_date_key,
    f.purchase_date,
    d.full_date AS purchase_calendar_date,
    d.day_name AS purchase_day_name,
    d.day_of_week AS purchase_day_of_week,
    d.week_of_year AS purchase_iso_week_number,
    d.iso_week_year AS purchase_iso_week_year,
    d.month_number AS purchase_month_number,
    d.month_name AS purchase_month_name,
    d.quarter_number AS purchase_quarter_number,
    d.year_number AS purchase_calendar_year,
    d.year_month AS purchase_year_month,

    -- Purchase location
    f.location_city,
    f.location_state,

    -- Recorded purchase measures
    f.gallons,
    f.price_per_gallon,
    f.total_cost AS recorded_fuel_cost,

    -- Additive purchase and assignment indicators
    CONVERT(BIGINT, 1) AS fuel_purchase_count,

    CASE
        WHEN f.truck_key IS NOT NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS truck_assigned_purchase_count,

    CASE
        WHEN f.truck_key IS NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS truck_unassigned_purchase_count,

    CASE
        WHEN f.driver_key IS NOT NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS driver_assigned_purchase_count,

    CASE
        WHEN f.driver_key IS NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS driver_unassigned_purchase_count

FROM gold.fact_fuel_purchases AS f
INNER JOIN gold.dim_date AS d
    ON f.purchase_date_key = d.date_key
LEFT JOIN gold.dim_truck AS t
    ON f.truck_key = t.truck_key
LEFT JOIN gold.dim_driver AS dr
    ON f.driver_key = dr.driver_key;


-- ============================================================================
-- VIEW VALIDATION
-- Expected:
--   - View row count equals fact_fuel_purchases row count.
--   - One view row per fuel_purchase_id.
--   - Purchase counts, assignments, gallons and recorded cost reconcile.
-- ============================================================================

IF
(
    SELECT COUNT_BIG(*)
    FROM gold.vw_fuel_cost_analysis
)
<>
(
    SELECT COUNT_BIG(*)
    FROM gold.fact_fuel_purchases
)
    THROW 51141, 'vw_fuel_cost_analysis row count does not match fact_fuel_purchases.', 1;


IF EXISTS
(
    SELECT fuel_purchase_id
    FROM gold.vw_fuel_cost_analysis
    GROUP BY fuel_purchase_id
    HAVING COUNT_BIG(*) <> 1
)
    THROW 51142, 'vw_fuel_cost_analysis does not preserve one row per fuel_purchase_id.', 1;


-- The source fact and view are compared at aggregate level.
-- Dimension joins use unique primary keys; the row-count and business-key
-- checks above also verify that the view preserves purchase grain.
IF EXISTS
(
    SELECT
        COUNT_BIG(*) AS total_purchases,
        SUM(CASE
            WHEN truck_key IS NOT NULL THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END) AS truck_assigned_purchases,
        SUM(CASE
            WHEN truck_key IS NULL THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END) AS truck_unassigned_purchases,
        SUM(CASE
            WHEN driver_key IS NOT NULL THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END) AS driver_assigned_purchases,
        SUM(CASE
            WHEN driver_key IS NULL THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END) AS driver_unassigned_purchases,
        SUM(gallons) AS total_gallons,
        SUM(total_cost) AS total_recorded_fuel_cost
    FROM gold.fact_fuel_purchases

    EXCEPT

    SELECT
        SUM(fuel_purchase_count) AS total_purchases,
        SUM(truck_assigned_purchase_count) AS truck_assigned_purchases,
        SUM(truck_unassigned_purchase_count) AS truck_unassigned_purchases,
        SUM(driver_assigned_purchase_count) AS driver_assigned_purchases,
        SUM(driver_unassigned_purchase_count) AS driver_unassigned_purchases,
        SUM(gallons) AS total_gallons,
        SUM(recorded_fuel_cost) AS total_recorded_fuel_cost
    FROM gold.vw_fuel_cost_analysis
)
    THROW 51143, 'vw_fuel_cost_analysis measures or assignment counts do not reconcile to fact_fuel_purchases.', 1;


-- ============================================================================
-- 1. OVERALL FUEL PURCHASE PERFORMANCE
-- Includes purchases with missing truck or driver assignments.
-- Weighted average price = recorded cost / total gallons.
-- ============================================================================

SELECT
    COUNT_BIG(*) AS total_fuel_purchases,
    SUM(gallons) AS total_gallons_purchased,
    SUM(recorded_fuel_cost) AS total_recorded_fuel_cost,
    CAST(
        SUM(recorded_fuel_cost) / NULLIF(SUM(gallons), 0)
        AS DECIMAL(12,4)
    ) AS weighted_average_recorded_cost_per_gallon,
    CAST(
        AVG(price_per_gallon)
        AS DECIMAL(12,4)
    ) AS simple_average_recorded_price_per_gallon,
    SUM(truck_assigned_purchase_count) AS purchases_with_assigned_truck,
    SUM(truck_unassigned_purchase_count) AS purchases_without_assigned_truck,
    SUM(driver_assigned_purchase_count) AS purchases_with_assigned_driver,
    SUM(driver_unassigned_purchase_count) AS purchases_without_assigned_driver
FROM gold.vw_fuel_cost_analysis;


-- ============================================================================
-- 2. MONTHLY FUEL PURCHASE TREND
-- January 2025 is a partial period; do not compare it with full months/years.
-- ============================================================================

SELECT
    purchase_calendar_year,
    purchase_month_number,
    purchase_month_name,
    purchase_year_month,
    COUNT_BIG(*) AS total_fuel_purchases,
    SUM(gallons) AS total_gallons_purchased,
    SUM(recorded_fuel_cost) AS total_recorded_fuel_cost,
    CAST(
        SUM(recorded_fuel_cost) / NULLIF(SUM(gallons), 0)
        AS DECIMAL(12,4)
    ) AS weighted_average_recorded_cost_per_gallon,
    CAST(
        AVG(price_per_gallon)
        AS DECIMAL(12,4)
    ) AS simple_average_recorded_price_per_gallon
FROM gold.vw_fuel_cost_analysis
GROUP BY
    purchase_calendar_year,
    purchase_month_number,
    purchase_month_name,
    purchase_year_month
ORDER BY
    purchase_calendar_year,
    purchase_month_number;


-- ============================================================================
-- 3. TRUCK-LEVEL FUEL PURCHASE SUMMARY
-- Only purchases with an assigned truck are included.
-- Overall totals above retain unassigned-truck purchases.
-- ============================================================================

SELECT
    truck_id,
    unit_number,
    truck_make,
    truck_model_year,
    truck_fuel_type,
    truck_status,
    COUNT_BIG(*) AS total_fuel_purchases,
    SUM(gallons) AS total_gallons_purchased,
    SUM(recorded_fuel_cost) AS total_recorded_fuel_cost,
    CAST(
        SUM(recorded_fuel_cost) / NULLIF(SUM(gallons), 0)
        AS DECIMAL(12,4)
    ) AS weighted_average_recorded_cost_per_gallon
FROM gold.vw_fuel_cost_analysis
WHERE truck_key IS NOT NULL
GROUP BY
    truck_id,
    unit_number,
    truck_make,
    truck_model_year,
    truck_fuel_type,
    truck_status
ORDER BY total_recorded_fuel_cost DESC;


-- ============================================================================
-- 4. DRIVER-LEVEL FUEL PURCHASE SUMMARY
-- Only purchases with an assigned driver are included.
-- Overall totals above retain unassigned-driver purchases.
-- Names are descriptive attributes; driver_id is the unique identity.
-- ============================================================================

SELECT
    driver_id,
    driver_first_name,
    driver_last_name,
    driver_employment_status,
    COUNT_BIG(*) AS total_fuel_purchases,
    SUM(gallons) AS total_gallons_purchased,
    SUM(recorded_fuel_cost) AS total_recorded_fuel_cost,
    CAST(
        SUM(recorded_fuel_cost) / NULLIF(SUM(gallons), 0)
        AS DECIMAL(12,4)
    ) AS weighted_average_recorded_cost_per_gallon
FROM gold.vw_fuel_cost_analysis
WHERE driver_key IS NOT NULL
GROUP BY
    driver_id,
    driver_first_name,
    driver_last_name,
    driver_employment_status
ORDER BY total_recorded_fuel_cost DESC;


-- ============================================================================
-- 5. TRUCK / DRIVER ASSIGNMENT BREAKDOWN
-- All four assignment combinations are retained.
-- ============================================================================

SELECT
    CASE
        WHEN truck_key IS NULL THEN 'Unassigned'
        ELSE 'Assigned'
    END AS truck_assignment,
    CASE
        WHEN driver_key IS NULL THEN 'Unassigned'
        ELSE 'Assigned'
    END AS driver_assignment,
    COUNT_BIG(*) AS total_fuel_purchases,
    SUM(gallons) AS total_gallons_purchased,
    SUM(recorded_fuel_cost) AS total_recorded_fuel_cost
FROM gold.vw_fuel_cost_analysis
GROUP BY
    CASE
        WHEN truck_key IS NULL THEN 'Unassigned'
        ELSE 'Assigned'
    END,
    CASE
        WHEN driver_key IS NULL THEN 'Unassigned'
        ELSE 'Assigned'
    END
ORDER BY
    truck_assignment,
    driver_assignment;
