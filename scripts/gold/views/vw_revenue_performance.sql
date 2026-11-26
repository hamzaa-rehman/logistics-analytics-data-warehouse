/*
===============================================================================
GOLD REPORTING VIEW - REVENUE PERFORMANCE
===============================================================================
Purpose:
    Provide a load-grain reporting dataset for reported load revenue analysis.

View grain:
    One row per load (load_id).

Business definitions:
    - Reported Load Revenue = fact_loads.revenue.
    - Fuel surcharge and accessorial charges remain separate measures.
    - Do not combine these three amounts into a "total revenue" measure:
      the source accounting definition does not establish whether the charges
      are already included in reported revenue.
    - Business date = dim_date.full_date via load_date_key.
    - Calendar-year reporting uses year_number.
    - ISO weekly reporting uses iso_week_year + week_of_year.

Join strategy:
    - dim_date is an INNER JOIN because load_date_key is mandatory and has an FK.
    - Customer and route are LEFT JOINs to preserve loads with optional
      dimension assignments.
    - Each dimension key is unique, so these joins preserve the one-row-per-load
      fact grain.

Currency:
    The source currency has not been confirmed. Amounts are intentionally
    labelled as reported amounts, without a currency symbol or currency name.

Deployment:
    Run against the existing Gold schema after the Gold load.
    This script creates or alters the view; it does not modify fact data.
===============================================================================
*/

USE LogisticsAnalytics;


CREATE OR ALTER VIEW gold.vw_revenue_performance
AS
SELECT
    -- Fact identity and business date
    f.load_fact_key,
    f.load_id,
    f.load_date_key,
    d.full_date AS load_date,
    d.day_name AS load_day_name,
    d.day_of_week AS load_day_of_week,
    d.week_of_year AS iso_week_number,
    d.iso_week_year,
    d.month_number AS load_month_number,
    d.month_name AS load_month_name,
    d.quarter_number AS load_quarter_number,
    d.year_number AS calendar_year,
    d.year_month AS load_year_month,
    d.is_weekend AS is_load_weekend,

    -- Customer attributes
    f.customer_key,
    c.customer_id,
    c.customer_name,
    c.customer_type,
    c.account_status,
    c.contract_start_date,

    -- Route attributes
    f.route_key,
    r.route_id,
    r.origin_city,
    r.origin_state,
    r.destination_city,
    r.destination_state,
    r.typical_distance_miles,
    r.base_rate_per_mile,

    -- Load descriptors
    f.load_type,
    f.load_status,
    f.booking_type,

    -- Additive measures at the one-row-per-load grain
    f.weight_lbs,
    f.pieces,
    f.revenue AS reported_load_revenue,
    f.fuel_surcharge AS fuel_surcharge_amount,
    f.accessorial_charges AS accessorial_charges_amount

FROM gold.fact_loads AS f
INNER JOIN gold.dim_date AS d
    ON f.load_date_key = d.date_key
LEFT JOIN gold.dim_customer AS c
    ON f.customer_key = c.customer_key
LEFT JOIN gold.dim_route AS r
    ON f.route_key = r.route_key;



-- ============================================================================
-- VIEW VALIDATION
-- Expected:
--   - View row count equals fact_loads row count.
--   - One view row per load_id.
--   - Fact and view totals match for all three separately reported amounts.
-- ============================================================================

IF
(
    SELECT COUNT_BIG(*)
    FROM gold.vw_revenue_performance
) <>
(
    SELECT COUNT_BIG(*)
    FROM gold.fact_loads
)
    THROW 51101, 'vw_revenue_performance row count does not match fact_loads.', 1;

IF EXISTS
(
    SELECT load_id
    FROM gold.vw_revenue_performance
    GROUP BY load_id
    HAVING COUNT_BIG(*) <> 1
)
    THROW 51102, 'vw_revenue_performance does not preserve one row per load.', 1;

IF EXISTS
(
    SELECT
        COUNT_BIG(*) AS row_count,
        SUM(revenue) AS reported_load_revenue,
        SUM(fuel_surcharge) AS fuel_surcharge_amount,
        SUM(accessorial_charges) AS accessorial_charges_amount
    FROM gold.fact_loads

    EXCEPT

    SELECT
        COUNT_BIG(*) AS row_count,
        SUM(reported_load_revenue) AS reported_load_revenue,
        SUM(fuel_surcharge_amount) AS fuel_surcharge_amount,
        SUM(accessorial_charges_amount) AS accessorial_charges_amount
    FROM gold.vw_revenue_performance
)
    THROW 51103, 'vw_revenue_performance measure totals do not match fact_loads.', 1;

SELECT
    COUNT_BIG(*) AS view_rows,
    COUNT(DISTINCT load_id) AS distinct_loads,
    SUM(reported_load_revenue) AS total_reported_load_revenue,
    SUM(fuel_surcharge_amount) AS total_fuel_surcharge,
    SUM(accessorial_charges_amount) AS total_accessorial_charges
FROM gold.vw_revenue_performance;

