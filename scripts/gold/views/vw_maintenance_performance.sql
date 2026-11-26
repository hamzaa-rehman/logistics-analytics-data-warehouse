/*
===============================================================================
GOLD REPORTING VIEW - MAINTENANCE PERFORMANCE
===============================================================================

Purpose:
    Provide a maintenance-record reporting dataset for maintenance activity,
    recorded costs, labor, downtime, truck attribution, and date trends.

View grain:
    One row per maintenance record (maintenance_id).

Business definitions:
    - Maintenance Records = COUNT of maintenance records.
    - Recorded Maintenance Cost = SUM(source total_cost).
    - Labor Cost and Parts Cost remain separate component measures.
    - Downtime Hours = SUM(source downtime_hours).
    - Average Downtime per Record = AVG(downtime_hours).
    - Truck-level analysis includes only records with an assigned truck.
    - Overall measures retain records without a truck assignment.

Important limitations:
    - Use source total_cost as the recorded total. Do not add labor_cost
      and parts_cost to total_cost.
    - facility_location is source text, not a facility_id. Do not join it
      to dim_facility.
    - Summed downtime is not fleet unavailability.
    - Currency is not established by the source.
    - Do not join raw maintenance records to other fact tables.

Deployment:
    - Connect DBeaver to LogisticsAnalytics before execution.
    - No GO batch separators or USE statement.
    - CREATE OR ALTER VIEW is the first SQL statement.
===============================================================================
*/

CREATE OR ALTER VIEW gold.vw_maintenance_performance
AS
SELECT
    -- Maintenance record identity
    f.maintenance_fact_key,
    f.maintenance_id,

    -- Optional truck assignment
    f.truck_key,
    t.truck_id,
    t.unit_number,
    t.make AS truck_make,
    t.model_year AS truck_model_year,
    t.fuel_type AS truck_fuel_type,
    t.status AS truck_status,

    -- Maintenance date attributes
    f.maintenance_date_key,
    d.full_date AS maintenance_date,
    d.day_name AS maintenance_day_name,
    d.day_of_week AS maintenance_day_of_week,
    d.week_of_year AS maintenance_iso_week_number,
    d.iso_week_year AS maintenance_iso_week_year,
    d.month_number AS maintenance_month_number,
    d.month_name AS maintenance_month_name,
    d.quarter_number AS maintenance_quarter_number,
    d.year_number AS maintenance_calendar_year,
    d.year_month AS maintenance_year_month,

    -- Maintenance details
    f.maintenance_type,
    f.odometer_reading,
    f.facility_location,
    f.service_description,

    -- Recorded measures
    f.labor_hours,
    f.labor_cost,
    f.parts_cost,
    f.total_cost AS recorded_maintenance_cost,
    f.downtime_hours,

    -- Additive record indicator
    CONVERT(BIGINT, 1) AS maintenance_record_count,

    CASE
        WHEN f.truck_key IS NOT NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS truck_assigned_record_count,

    CASE
        WHEN f.truck_key IS NULL THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END AS truck_unassigned_record_count

FROM gold.fact_maintenance_records AS f
INNER JOIN gold.dim_date AS d
    ON f.maintenance_date_key = d.date_key
LEFT JOIN gold.dim_truck AS t
    ON f.truck_key = t.truck_key;


-- ============================================================================
-- VIEW VALIDATION
-- ============================================================================

IF
(
    SELECT COUNT_BIG(*)
    FROM gold.vw_maintenance_performance
)
<>
(
    SELECT COUNT_BIG(*)
    FROM gold.fact_maintenance_records
)
    THROW 51151, 'vw_maintenance_performance row count does not match fact_maintenance_records.', 1;


IF EXISTS
(
    SELECT maintenance_id
    FROM gold.vw_maintenance_performance
    GROUP BY maintenance_id
    HAVING COUNT_BIG(*) <> 1
)
    THROW 51152, 'vw_maintenance_performance does not preserve one row per maintenance_id.', 1;


IF EXISTS
(
    SELECT
        COUNT_BIG(*) AS maintenance_records,
        SUM(CASE WHEN truck_key IS NOT NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END) AS truck_assigned_records,
        SUM(CASE WHEN truck_key IS NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END) AS truck_unassigned_records,
        SUM(labor_hours) AS total_labor_hours,
        SUM(labor_cost) AS total_labor_cost,
        SUM(parts_cost) AS total_parts_cost,
        SUM(total_cost) AS total_recorded_maintenance_cost,
        SUM(downtime_hours) AS total_downtime_hours
    FROM gold.fact_maintenance_records

    EXCEPT

    SELECT
        SUM(maintenance_record_count) AS maintenance_records,
        SUM(truck_assigned_record_count) AS truck_assigned_records,
        SUM(truck_unassigned_record_count) AS truck_unassigned_records,
        SUM(labor_hours) AS total_labor_hours,
        SUM(labor_cost) AS total_labor_cost,
        SUM(parts_cost) AS total_parts_cost,
        SUM(recorded_maintenance_cost) AS total_recorded_maintenance_cost,
        SUM(downtime_hours) AS total_downtime_hours
    FROM gold.vw_maintenance_performance
)
    THROW 51153, 'vw_maintenance_performance measures or truck assignment counts do not reconcile to fact_maintenance_records.', 1;


-- ============================================================================
-- 1. OVERALL MAINTENANCE SUMMARY
-- ============================================================================

SELECT
    COUNT_BIG(*) AS total_maintenance_records,
    SUM(recorded_maintenance_cost) AS total_recorded_maintenance_cost,
    SUM(labor_cost) AS total_labor_cost,
    SUM(parts_cost) AS total_parts_cost,
    SUM(labor_hours) AS total_labor_hours,
    SUM(downtime_hours) AS total_downtime_hours,
    CAST(AVG(downtime_hours) AS DECIMAL(12,2)) AS average_downtime_hours_per_record,
    SUM(truck_assigned_record_count) AS records_with_assigned_truck,
    SUM(truck_unassigned_record_count) AS records_without_assigned_truck
FROM gold.vw_maintenance_performance;


-- ============================================================================
-- 2. MONTHLY MAINTENANCE TREND
-- ============================================================================

SELECT
    maintenance_calendar_year,
    maintenance_month_number,
    maintenance_month_name,
    maintenance_year_month,
    COUNT_BIG(*) AS total_maintenance_records,
    SUM(recorded_maintenance_cost) AS total_recorded_maintenance_cost,
    SUM(labor_cost) AS total_labor_cost,
    SUM(parts_cost) AS total_parts_cost,
    SUM(labor_hours) AS total_labor_hours,
    SUM(downtime_hours) AS total_downtime_hours,
    CAST(AVG(downtime_hours) AS DECIMAL(12,2)) AS average_downtime_hours_per_record
FROM gold.vw_maintenance_performance
GROUP BY
    maintenance_calendar_year,
    maintenance_month_number,
    maintenance_month_name,
    maintenance_year_month
ORDER BY
    maintenance_calendar_year,
    maintenance_month_number;


-- ============================================================================
-- 3. MAINTENANCE TYPE ANALYSIS
-- NULL maintenance types remain visible as their own group.
-- ============================================================================

SELECT
    COALESCE(maintenance_type, 'Unspecified') AS maintenance_type,
    COUNT_BIG(*) AS total_maintenance_records,
    SUM(recorded_maintenance_cost) AS total_recorded_maintenance_cost,
    CAST(AVG(recorded_maintenance_cost) AS DECIMAL(12,2)) AS average_recorded_cost_per_record,
    SUM(labor_hours) AS total_labor_hours,
    SUM(downtime_hours) AS total_downtime_hours,
    CAST(AVG(downtime_hours) AS DECIMAL(12,2)) AS average_downtime_hours_per_record
FROM gold.vw_maintenance_performance
GROUP BY maintenance_type
ORDER BY total_recorded_maintenance_cost DESC;


-- ============================================================================
-- 4. TRUCK-LEVEL MAINTENANCE SUMMARY
-- Only records with an assigned truck are included.
-- ============================================================================

SELECT
    truck_id,
    unit_number,
    truck_make,
    truck_model_year,
    truck_status,
    COUNT_BIG(*) AS total_maintenance_records,
    SUM(recorded_maintenance_cost) AS total_recorded_maintenance_cost,
    SUM(labor_hours) AS total_labor_hours,
    SUM(downtime_hours) AS total_downtime_hours,
    CAST(AVG(downtime_hours) AS DECIMAL(12,2)) AS average_downtime_hours_per_record
FROM gold.vw_maintenance_performance
WHERE truck_key IS NOT NULL
GROUP BY
    truck_id,
    unit_number,
    truck_make,
    truck_model_year,
    truck_status
ORDER BY total_recorded_maintenance_cost DESC;


-- ============================================================================
-- 5. MAINTENANCE LOCATION SUMMARY
-- facility_location is source text, not a validated facility dimension key.
-- NULL locations remain visible.
-- ============================================================================

SELECT
    COALESCE(facility_location, 'Unspecified') AS facility_location,
    COUNT_BIG(*) AS total_maintenance_records,
    SUM(recorded_maintenance_cost) AS total_recorded_maintenance_cost,
    SUM(labor_hours) AS total_labor_hours,
    SUM(downtime_hours) AS total_downtime_hours
FROM gold.vw_maintenance_performance
GROUP BY facility_location
ORDER BY total_recorded_maintenance_cost DESC;
