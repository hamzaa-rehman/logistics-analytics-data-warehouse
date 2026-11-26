/*

===============================================================================

GOLD REPORTING VIEW - SAFETY PERFORMANCE

===============================================================================


Purpose:

    Provide an incident-grain reporting dataset for safety incidents,

    incident classifications, responsibility, injuries, preventability,

    recorded damage amounts, claims, and date trends.


View grain:

    One row per safety incident (incident_id).


Business definitions:

    - Safety Incidents = COUNT of incident records.

    - At-Fault Incidents = incidents where at_fault_flag = 1.

    - Injury Incidents = incidents where injury_flag = 1.

    - Preventable Incidents = incidents where preventable_flag = 1.

    - Rates should use only records with a known value for the relevant flag.

    - Claim Amount = SUM(source claim_amount).

    - Vehicle and cargo damage costs remain separate measures.


Important limitations:

    - NULL safety flags are unknown, not equivalent to FALSE.

    - claim_amount must not be added to vehicle_damage_cost or

      cargo_damage_cost.

    - Truck and driver assignments are optional.

    - Incident location is source-reported text, not a facility relationship.

    - No fact-to-fact joins are used.

    - Currency is not established by the source.


Deployment:

    - Connect DBeaver to LogisticsAnalytics before execution.

    - No GO batch separators or USE statement.

    - CREATE OR ALTER VIEW is the first SQL statement.

===============================================================================

*/


CREATE OR ALTER VIEW gold.vw_safety_performance

AS

SELECT

    -- Incident identity and source relationship

    f.safety_incident_fact_key,

    f.incident_id,

    f.trip_id,


    -- Optional truck assignment

    f.truck_key,

    t.truck_id,

    t.unit_number,

    t.make AS truck_make,

    t.model_year AS truck_model_year,

    t.status AS truck_status,


    -- Optional driver assignment

    f.driver_key,

    dr.driver_id,

    dr.first_name AS driver_first_name,

    dr.last_name AS driver_last_name,

    dr.employment_status AS driver_employment_status,

    dr.home_terminal AS driver_home_terminal,


    -- Incident date attributes

    f.incident_date_key,

    f.incident_date,

    d.full_date AS incident_calendar_date,

    d.day_name AS incident_day_name,

    d.day_of_week AS incident_day_of_week,

    d.week_of_year AS incident_iso_week_number,

    d.iso_week_year AS incident_iso_week_year,

    d.month_number AS incident_month_number,

    d.month_name AS incident_month_name,

    d.quarter_number AS incident_quarter_number,

    d.year_number AS incident_calendar_year,

    d.year_month AS incident_year_month,


    -- Incident details

    f.incident_type,

    f.location_city,

    f.location_state,


    -- Original safety flags; NULL remains unknown

    f.at_fault_flag,

    f.injury_flag,

    f.preventable_flag,


    -- Recorded financial measures; kept separate

    f.vehicle_damage_cost,

    f.cargo_damage_cost,

    f.claim_amount,


    -- Additive incident indicator

    CONVERT(BIGINT, 1) AS safety_incident_count,


    -- At-fault indicators

    CASE

        WHEN f.at_fault_flag IS NOT NULL THEN CONVERT(BIGINT, 1)

        ELSE CONVERT(BIGINT, 0)

    END AS at_fault_flag_known_count,


    CASE

        WHEN f.at_fault_flag = 1 THEN CONVERT(BIGINT, 1)

        ELSE CONVERT(BIGINT, 0)

    END AS at_fault_incident_count,


    -- Injury indicators

    CASE

        WHEN f.injury_flag IS NOT NULL THEN CONVERT(BIGINT, 1)

        ELSE CONVERT(BIGINT, 0)

    END AS injury_flag_known_count,


    CASE

        WHEN f.injury_flag = 1 THEN CONVERT(BIGINT, 1)

        ELSE CONVERT(BIGINT, 0)

    END AS injury_incident_count,


    -- Preventability indicators

    CASE

        WHEN f.preventable_flag IS NOT NULL THEN CONVERT(BIGINT, 1)

        ELSE CONVERT(BIGINT, 0)

    END AS preventable_flag_known_count,


    CASE

        WHEN f.preventable_flag = 1 THEN CONVERT(BIGINT, 1)

        ELSE CONVERT(BIGINT, 0)

    END AS preventable_incident_count,


    -- Assignment indicators

    CASE

        WHEN f.truck_key IS NOT NULL THEN CONVERT(BIGINT, 1)

        ELSE CONVERT(BIGINT, 0)

    END AS truck_assigned_incident_count,


    CASE

        WHEN f.driver_key IS NOT NULL THEN CONVERT(BIGINT, 1)

        ELSE CONVERT(BIGINT, 0)

    END AS driver_assigned_incident_count


FROM gold.fact_safety_incidents AS f

INNER JOIN gold.dim_date AS d

    ON f.incident_date_key = d.date_key

LEFT JOIN gold.dim_truck AS t

    ON f.truck_key = t.truck_key

LEFT JOIN gold.dim_driver AS dr

    ON f.driver_key = dr.driver_key;


-- ============================================================================

-- VIEW VALIDATION

-- ============================================================================


IF

(

    SELECT COUNT_BIG(*)

    FROM gold.vw_safety_performance

)

<>

(

    SELECT COUNT_BIG(*)

    FROM gold.fact_safety_incidents

)

    THROW 51161, 'vw_safety_performance row count does not match fact_safety_incidents.', 1;


IF EXISTS

(

    SELECT incident_id

    FROM gold.vw_safety_performance

    GROUP BY incident_id

    HAVING COUNT_BIG(*) <> 1

)

    THROW 51162, 'vw_safety_performance does not preserve one row per incident_id.', 1;


IF EXISTS

(

    SELECT

        COUNT_BIG(*) AS incident_records,


        SUM(CASE WHEN at_fault_flag IS NOT NULL

            THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)

            AS at_fault_known_records,


        SUM(CASE WHEN at_fault_flag = 1

            THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)

            AS at_fault_incidents,


        SUM(CASE WHEN injury_flag IS NOT NULL

            THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)

            AS injury_known_records,


        SUM(CASE WHEN injury_flag = 1

            THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)

            AS injury_incidents,


        SUM(CASE WHEN preventable_flag IS NOT NULL

            THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)

            AS preventable_known_records,


        SUM(CASE WHEN preventable_flag = 1

            THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)

            AS preventable_incidents,


        SUM(CASE WHEN truck_key IS NOT NULL

            THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)

            AS truck_assigned_incidents,


        SUM(CASE WHEN driver_key IS NOT NULL

            THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END)

            AS driver_assigned_incidents,


        SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,

        SUM(cargo_damage_cost) AS total_cargo_damage_cost,

        SUM(claim_amount) AS total_claim_amount


    FROM gold.fact_safety_incidents


    EXCEPT


    SELECT

        SUM(safety_incident_count) AS incident_records,


        SUM(at_fault_flag_known_count) AS at_fault_known_records,

        SUM(at_fault_incident_count) AS at_fault_incidents,


        SUM(injury_flag_known_count) AS injury_known_records,

        SUM(injury_incident_count) AS injury_incidents,


        SUM(preventable_flag_known_count) AS preventable_known_records,

        SUM(preventable_incident_count) AS preventable_incidents,


        SUM(truck_assigned_incident_count) AS truck_assigned_incidents,

        SUM(driver_assigned_incident_count) AS driver_assigned_incidents,


        SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,

        SUM(cargo_damage_cost) AS total_cargo_damage_cost,

        SUM(claim_amount) AS total_claim_amount


    FROM gold.vw_safety_performance

)

    THROW 51163, 'vw_safety_performance measures or indicators do not reconcile to fact_safety_incidents.', 1;


-- ============================================================================

-- 1. OVERALL SAFETY SUMMARY

-- Rates use known flag values as their denominators.

-- ============================================================================


SELECT

    COUNT_BIG(*) AS total_safety_incidents,


    SUM(at_fault_incident_count) AS at_fault_incidents,

    SUM(at_fault_flag_known_count) AS incidents_with_known_at_fault_flag,


    CAST(

        100.0 * SUM(at_fault_incident_count)

        / NULLIF(SUM(at_fault_flag_known_count), 0)

        AS DECIMAL(6,2)

    ) AS at_fault_rate_pct,


    SUM(injury_incident_count) AS injury_incidents,

    SUM(injury_flag_known_count) AS incidents_with_known_injury_flag,


    CAST(

        100.0 * SUM(injury_incident_count)

        / NULLIF(SUM(injury_flag_known_count), 0)

        AS DECIMAL(6,2)

    ) AS injury_incident_rate_pct,


    SUM(preventable_incident_count) AS preventable_incidents,

    SUM(preventable_flag_known_count) AS incidents_with_known_preventable_flag,


    CAST(

        100.0 * SUM(preventable_incident_count)

        / NULLIF(SUM(preventable_flag_known_count), 0)

        AS DECIMAL(6,2)

    ) AS preventable_incident_rate_pct,


    SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,

    SUM(cargo_damage_cost) AS total_cargo_damage_cost,

    SUM(claim_amount) AS total_claim_amount,


    SUM(truck_assigned_incident_count) AS incidents_with_assigned_truck,

    SUM(driver_assigned_incident_count) AS incidents_with_assigned_driver


FROM gold.vw_safety_performance;


-- ============================================================================

-- 2. ANNUAL SAFETY TREND

-- ============================================================================


SELECT

    incident_calendar_year,

    COUNT_BIG(*) AS total_safety_incidents,


    SUM(at_fault_incident_count) AS at_fault_incidents,

    SUM(injury_incident_count) AS injury_incidents,

    SUM(preventable_incident_count) AS preventable_incidents,


    SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,

    SUM(cargo_damage_cost) AS total_cargo_damage_cost,

    SUM(claim_amount) AS total_claim_amount


FROM gold.vw_safety_performance

GROUP BY incident_calendar_year

ORDER BY incident_calendar_year;


-- ============================================================================

-- 3. INCIDENT TYPE ANALYSIS

-- NULL incident types remain visible as their own group.

-- ============================================================================


SELECT

    COALESCE(incident_type, 'Unspecified') AS incident_type,

    COUNT_BIG(*) AS total_safety_incidents,


    SUM(at_fault_incident_count) AS at_fault_incidents,

    SUM(injury_incident_count) AS injury_incidents,

    SUM(preventable_incident_count) AS preventable_incidents,


    SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,

    SUM(cargo_damage_cost) AS total_cargo_damage_cost,

    SUM(claim_amount) AS total_claim_amount


FROM gold.vw_safety_performance

GROUP BY incident_type

ORDER BY total_safety_incidents DESC;


-- ============================================================================

-- 4. TRUCK-LEVEL SAFETY SUMMARY

-- Only incidents with an assigned truck are included.

-- ============================================================================


SELECT

    truck_id,

    unit_number,

    truck_make,

    truck_model_year,

    truck_status,


    COUNT_BIG(*) AS total_safety_incidents,

    SUM(at_fault_incident_count) AS at_fault_incidents,

    SUM(injury_incident_count) AS injury_incidents,

    SUM(preventable_incident_count) AS preventable_incidents,


    SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,

    SUM(cargo_damage_cost) AS total_cargo_damage_cost,

    SUM(claim_amount) AS total_claim_amount


FROM gold.vw_safety_performance

WHERE truck_key IS NOT NULL

GROUP BY

    truck_id,

    unit_number,

    truck_make,

    truck_model_year,

    truck_status

ORDER BY total_safety_incidents DESC;


-- ============================================================================

-- 5. DRIVER-LEVEL SAFETY SUMMARY

-- Only incidents with an assigned driver are included.

-- ============================================================================


SELECT

    driver_id,

    driver_first_name,

    driver_last_name,

    driver_employment_status,

    driver_home_terminal,


    COUNT_BIG(*) AS total_safety_incidents,

    SUM(at_fault_incident_count) AS at_fault_incidents,

    SUM(injury_incident_count) AS injury_incidents,

    SUM(preventable_incident_count) AS preventable_incidents,


    SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,

    SUM(cargo_damage_cost) AS total_cargo_damage_cost,

    SUM(claim_amount) AS total_claim_amount


FROM gold.vw_safety_performance

WHERE driver_key IS NOT NULL

GROUP BY

    driver_id,

    driver_first_name,

    driver_last_name,

    driver_employment_status,

    driver_home_terminal

ORDER BY total_safety_incidents DESC;


-- ============================================================================

-- 6. INCIDENT LOCATION SUMMARY

-- Source-reported location, not a facility dimension relationship.

-- NULL locations remain visible.

-- ============================================================================


SELECT

    COALESCE(location_city, 'Unspecified') AS location_city,

    COALESCE(location_state, 'Unspecified') AS location_state,


    COUNT_BIG(*) AS total_safety_incidents,

    SUM(injury_incident_count) AS injury_incidents,

    SUM(preventable_incident_count) AS preventable_incidents,


    SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,

    SUM(cargo_damage_cost) AS total_cargo_damage_cost,

    SUM(claim_amount) AS total_claim_amount


FROM gold.vw_safety_performance

GROUP BY

    location_city,

    location_state

ORDER BY total_safety_incidents DESC;
