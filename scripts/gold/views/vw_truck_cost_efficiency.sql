/*
===============================================================================
GOLD REPORTING VIEW - TRUCK COST EFFICIENCY
===============================================================================
Purpose:
    Combine truck-level trip, fuel purchase, and maintenance measures
    for comparable operating periods.

View grain:
    One row per truck in gold.dim_truck.

Reporting period:
    Calendar years 2022-2024 inclusive.

Design:
    - Aggregate each fact independently by truck_key.
    - Join the three aggregated results to dim_truck.
    - Retain all trucks, including those with no activity in a fact.
    - Exclude unassigned fact records from truck-level attribution.
      Reconcile unassigned records separately.

Important definitions:
    - Trip fuel consumed and fuel gallons purchased are separate measures.
    - Recorded fuel cost uses fact_fuel_purchases.total_cost.
    - Recorded maintenance cost uses fact_maintenance_records.total_cost.
    - Combined recorded spend = recorded fuel purchase cost
      + recorded maintenance cost.
    - Combined recorded spend per actual mile is a descriptive proxy,
      not true operating cost per mile or profitability.
    - No currency is assumed.
    - Truck attributes reflect the current Type 1 dimension.

Deployment:
    Connect DBeaver to LogisticsAnalytics before execution.
    No USE statement or GO batch separator.
    CREATE OR ALTER VIEW is the first SQL statement.
===============================================================================
*/

CREATE OR ALTER VIEW gold.vw_truck_cost_efficiency
AS
WITH trip_metrics AS
(
    SELECT
        f.truck_key,
        COUNT_BIG(*) AS total_trips,
        SUM(f.actual_distance_miles) AS total_actual_distance_miles,
        SUM(f.fuel_gallons_used) AS total_trip_fuel_gallons_consumed,
        CAST(
            SUM(f.actual_distance_miles)
            / NULLIF(SUM(f.fuel_gallons_used), 0)
            AS DECIMAL(12,6)
        ) AS weighted_truck_mpg,
        AVG(f.average_mpg) AS average_recorded_trip_mpg,
        AVG(f.idle_time_hours) AS average_idle_hours_per_trip
    FROM gold.fact_trips AS f
    INNER JOIN gold.dim_date AS d
        ON f.dispatch_date_key = d.date_key
    WHERE f.truck_key IS NOT NULL
      AND d.year_number BETWEEN 2022 AND 2024
    GROUP BY f.truck_key
),
fuel_purchase_metrics AS
(
    SELECT
        f.truck_key,
        COUNT_BIG(*) AS total_fuel_purchases,
        SUM(f.gallons) AS total_gallons_purchased,
        SUM(f.total_cost) AS total_recorded_fuel_cost,
        CAST(
            SUM(f.total_cost)
            / NULLIF(SUM(f.gallons), 0)
            AS DECIMAL(12,4)
        ) AS weighted_recorded_purchase_cost_per_gallon
    FROM gold.fact_fuel_purchases AS f
    INNER JOIN gold.dim_date AS d
        ON f.purchase_date_key = d.date_key
    WHERE f.truck_key IS NOT NULL
      AND d.year_number BETWEEN 2022 AND 2024
    GROUP BY f.truck_key
),
maintenance_metrics AS
(
    SELECT
        f.truck_key,
        COUNT_BIG(*) AS total_maintenance_records,
        SUM(f.total_cost) AS total_recorded_maintenance_cost,
        SUM(f.labor_cost) AS total_labor_cost,
        SUM(f.parts_cost) AS total_parts_cost,
        SUM(f.downtime_hours) AS total_downtime_hours,
        AVG(f.downtime_hours) AS average_downtime_hours_per_record
    FROM gold.fact_maintenance_records AS f
    INNER JOIN gold.dim_date AS d
        ON f.maintenance_date_key = d.date_key
    WHERE f.truck_key IS NOT NULL
      AND d.year_number BETWEEN 2022 AND 2024
    GROUP BY f.truck_key
)
SELECT
    -- Truck identity and descriptive attributes
    t.truck_key,
    t.truck_id,
    t.unit_number,
    t.make AS truck_make,
    t.model_year AS truck_model_year,
    t.fuel_type AS truck_fuel_type,
    t.status AS truck_status,
    t.home_terminal AS truck_home_terminal,

    -- Trip activity and efficiency
    COALESCE(tm.total_trips, CONVERT(BIGINT, 0)) AS total_trips,
    tm.total_actual_distance_miles,
    tm.total_trip_fuel_gallons_consumed,
    tm.weighted_truck_mpg,
    tm.average_recorded_trip_mpg,
    tm.average_idle_hours_per_trip,

    -- Fuel purchase measures
    COALESCE(fm.total_fuel_purchases, CONVERT(BIGINT, 0))
        AS total_fuel_purchases,
    fm.total_gallons_purchased,
    fm.total_recorded_fuel_cost,
    fm.weighted_recorded_purchase_cost_per_gallon,

    -- Maintenance measures
    COALESCE(mm.total_maintenance_records, CONVERT(BIGINT, 0))
        AS total_maintenance_records,
    mm.total_recorded_maintenance_cost,
    mm.total_labor_cost,
    mm.total_parts_cost,
    mm.total_downtime_hours,
    mm.average_downtime_hours_per_record,

    -- Combined recorded spend.
    -- NULL means neither fuel purchases nor maintenance records exist
    -- for this truck in the reporting period.
    CASE
        WHEN COALESCE(fm.total_fuel_purchases, 0)
           + COALESCE(mm.total_maintenance_records, 0) = 0
            THEN NULL
        ELSE
            COALESCE(fm.total_recorded_fuel_cost, 0)
            + COALESCE(mm.total_recorded_maintenance_cost, 0)
    END AS combined_recorded_fuel_and_maintenance_cost,

    -- Descriptive proxy only; not a true operating cost per mile.
    CAST(
        (
            COALESCE(fm.total_recorded_fuel_cost, 0)
            + COALESCE(mm.total_recorded_maintenance_cost, 0)
        )
        / NULLIF(tm.total_actual_distance_miles, 0)
        AS DECIMAL(12,4)
    ) AS combined_recorded_spend_per_actual_mile_proxy
FROM gold.dim_truck AS t
LEFT JOIN trip_metrics AS tm
    ON t.truck_key = tm.truck_key
LEFT JOIN fuel_purchase_metrics AS fm
    ON t.truck_key = fm.truck_key
LEFT JOIN maintenance_metrics AS mm
    ON t.truck_key = mm.truck_key;

/*
===============================================================================
VIEW VALIDATION
===============================================================================
*/

-- 1. The view must retain every truck in dim_truck.
IF
(
    SELECT COUNT_BIG(*)
    FROM gold.vw_truck_cost_efficiency
)
<>
(
    SELECT COUNT_BIG(*)
    FROM gold.dim_truck
)
    THROW 51161, 'vw_truck_cost_efficiency row count does not match dim_truck.', 1;

-- 2. One row per truck_id.
IF EXISTS
(
    SELECT truck_id
    FROM gold.vw_truck_cost_efficiency
    GROUP BY truck_id
    HAVING COUNT_BIG(*) <> 1
)
    THROW 51162, 'vw_truck_cost_efficiency does not preserve one row per truck.', 1;

-- 3. Trip measures reconcile by truck.
IF EXISTS
(
    SELECT
        f.truck_key,
        COUNT_BIG(*) AS total_trips,
        SUM(f.actual_distance_miles) AS total_actual_distance_miles,
        SUM(f.fuel_gallons_used) AS total_trip_fuel_gallons_consumed
    FROM gold.fact_trips AS f
    INNER JOIN gold.dim_date AS d
        ON f.dispatch_date_key = d.date_key
    WHERE f.truck_key IS NOT NULL
      AND d.year_number BETWEEN 2022 AND 2024
    GROUP BY f.truck_key
    EXCEPT
    SELECT
        truck_key,
        total_trips,
        total_actual_distance_miles,
        total_trip_fuel_gallons_consumed
    FROM gold.vw_truck_cost_efficiency
    WHERE total_trips > 0
)
    THROW 51163, 'Truck trip measures do not reconcile to fact_trips.', 1;

-- 4. Fuel purchase measures reconcile by truck.
IF EXISTS
(
    SELECT
        f.truck_key,
        COUNT_BIG(*) AS total_fuel_purchases,
        SUM(f.gallons) AS total_gallons_purchased,
        SUM(f.total_cost) AS total_recorded_fuel_cost
    FROM gold.fact_fuel_purchases AS f
    INNER JOIN gold.dim_date AS d
        ON f.purchase_date_key = d.date_key
    WHERE f.truck_key IS NOT NULL
      AND d.year_number BETWEEN 2022 AND 2024
    GROUP BY f.truck_key
    EXCEPT
    SELECT
        truck_key,
        total_fuel_purchases,
        total_gallons_purchased,
        total_recorded_fuel_cost
    FROM gold.vw_truck_cost_efficiency
    WHERE total_fuel_purchases > 0
)
    THROW 51164, 'Truck fuel purchase measures do not reconcile to fact_fuel_purchases.', 1;

-- 5. Maintenance measures reconcile by truck.
IF EXISTS
(
    SELECT
        f.truck_key,
        COUNT_BIG(*) AS total_maintenance_records,
        SUM(f.total_cost) AS total_recorded_maintenance_cost,
        SUM(f.labor_cost) AS total_labor_cost,
        SUM(f.parts_cost) AS total_parts_cost,
        SUM(f.downtime_hours) AS total_downtime_hours
    FROM gold.fact_maintenance_records AS f
    INNER JOIN gold.dim_date AS d
        ON f.maintenance_date_key = d.date_key
    WHERE f.truck_key IS NOT NULL
      AND d.year_number BETWEEN 2022 AND 2024
    GROUP BY f.truck_key
    EXCEPT
    SELECT
        truck_key,
        total_maintenance_records,
        total_recorded_maintenance_cost,
        total_labor_cost,
        total_parts_cost,
        total_downtime_hours
    FROM gold.vw_truck_cost_efficiency
    WHERE total_maintenance_records > 0
)
    THROW 51165, 'Truck maintenance measures do not reconcile to fact_maintenance_records.', 1;

/*
===============================================================================
ANALYSIS QUERIES
===============================================================================
*/

-- 1. Overall truck-level summary.
-- Only truck-assigned records are represented in this view.
SELECT
    COUNT_BIG(*) AS total_trucks,
    SUM(total_trips) AS assigned_truck_trips,
    SUM(total_actual_distance_miles) AS total_actual_distance_miles,
    SUM(total_trip_fuel_gallons_consumed) AS total_trip_fuel_gallons_consumed,
    SUM(total_fuel_purchases) AS assigned_truck_fuel_purchases,
    SUM(total_gallons_purchased) AS total_gallons_purchased,
    SUM(total_recorded_fuel_cost) AS total_recorded_fuel_cost,
    SUM(total_maintenance_records) AS assigned_truck_maintenance_records,
    SUM(total_recorded_maintenance_cost) AS total_recorded_maintenance_cost,
    SUM(combined_recorded_fuel_and_maintenance_cost)
        AS combined_recorded_fuel_and_maintenance_cost
FROM gold.vw_truck_cost_efficiency;

-- 2. Truck-level cost and efficiency comparison.
SELECT
    truck_id,
    unit_number,
    truck_make,
    truck_model_year,
    truck_fuel_type,
    truck_status,
    total_trips,
    total_actual_distance_miles,
    total_trip_fuel_gallons_consumed,
    weighted_truck_mpg,
    total_gallons_purchased,
    total_recorded_fuel_cost,
    weighted_recorded_purchase_cost_per_gallon,
    total_maintenance_records,
    total_recorded_maintenance_cost,
    total_downtime_hours,
    combined_recorded_fuel_and_maintenance_cost,
    combined_recorded_spend_per_actual_mile_proxy
FROM gold.vw_truck_cost_efficiency
ORDER BY combined_recorded_spend_per_actual_mile_proxy DESC;

-- 3. Truck assignment coverage in the reporting period.
-- These checks retain records that cannot be attributed to a truck.
SELECT
    'Trips' AS source_fact,
    COUNT_BIG(*) AS total_records,
    SUM(CASE WHEN f.truck_key IS NOT NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)
        AS records_with_truck,
    SUM(CASE WHEN f.truck_key IS NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)
        AS records_without_truck
FROM gold.fact_trips AS f
INNER JOIN gold.dim_date AS d
    ON f.dispatch_date_key = d.date_key
WHERE d.year_number BETWEEN 2022 AND 2024

UNION ALL

SELECT
    'Fuel purchases',
    COUNT_BIG(*),
    SUM(CASE WHEN f.truck_key IS NOT NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END),
    SUM(CASE WHEN f.truck_key IS NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)
FROM gold.fact_fuel_purchases AS f
INNER JOIN gold.dim_date AS d
    ON f.purchase_date_key = d.date_key
WHERE d.year_number BETWEEN 2022 AND 2024

UNION ALL

SELECT
    'Maintenance',
    COUNT_BIG(*),
    SUM(CASE WHEN f.truck_key IS NOT NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END),
    SUM(CASE WHEN f.truck_key IS NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)
FROM gold.fact_maintenance_records AS f
INNER JOIN gold.dim_date AS d
    ON f.maintenance_date_key = d.date_key
WHERE d.year_number BETWEEN 2022 AND 2024;
