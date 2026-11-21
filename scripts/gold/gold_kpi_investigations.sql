/* ============================================================================
   GOLD LAYER — KPI INVESTIGATION QUERIES

   Project: Logistics Analytics Data Warehouse
   Database: LogisticsAnalytics
   Source layer: Silver

   Purpose:
     Preserve the SQL investigations executed during Gold KPI discovery.
     These queries support the findings documented in:
       docs/gold/gold_kpi_investigations.md

   Notes:
     - These are investigation queries, not Gold production SQL.
     - Results and business interpretations are documented separately.
     - Route pricing comparisons are indicative, not proof of billing rules.
     - trips_per_day is not a true fleet-utilization percentage.
     - On-time delivery rate must use Delivery events, not Pickup events.
     - This collection contains investigations 01–06D supplied so far.

   ============================================================================ */

USE LogisticsAnalytics;
GO

/* ============================================================

   GOLD INVESTIGATION 01

   Subject: Load Revenue

   Source: silver.loads

   Purpose:

   1. Understand revenue and charge completeness.

   2. Inspect date coverage and unusual values.

   3. Compare revenue components by load status.

   ============================================================ */

/* ------------------------------------------------------------

   1. Overall revenue and charge profile

   ------------------------------------------------------------ */

SELECT

    COUNT_BIG(*) AS total_loads,

    COUNT(revenue) AS loads_with_revenue,

    SUM(CASE WHEN revenue IS NULL THEN 1 ELSE 0 END)

        AS null_revenue_count,

    SUM(CASE WHEN revenue = 0 THEN 1 ELSE 0 END)

        AS zero_revenue_count,

    SUM(CASE WHEN revenue < 0 THEN 1 ELSE 0 END)

        AS negative_revenue_count,

    MIN(load_date) AS first_load_date,

    MAX(load_date) AS last_load_date,

    MIN(revenue) AS minimum_revenue,

    MAX(revenue) AS maximum_revenue,

    SUM(revenue) AS total_reported_revenue,

    SUM(fuel_surcharge) AS total_fuel_surcharge,

    SUM(accessorial_charges) AS total_accessorial_charges,

    SUM(

        COALESCE(revenue, 0)

        + COALESCE(fuel_surcharge, 0)

        + COALESCE(accessorial_charges, 0)

    ) AS combined_amount_for_comparison

FROM silver.loads;

/* ------------------------------------------------------------

   2. Revenue and charge profile by load status

   ------------------------------------------------------------ */

SELECT

    load_status,

    COUNT_BIG(*) AS load_count,

    SUM(CASE WHEN revenue IS NULL THEN 1 ELSE 0 END)

        AS null_revenue_count,

    SUM(CASE WHEN revenue = 0 THEN 1 ELSE 0 END)

        AS zero_revenue_count,

    SUM(revenue) AS total_reported_revenue,

    AVG(revenue) AS average_reported_revenue,

    SUM(fuel_surcharge) AS total_fuel_surcharge,

    SUM(accessorial_charges) AS total_accessorial_charges,

    SUM(

        COALESCE(revenue, 0)

        + COALESCE(fuel_surcharge, 0)

        + COALESCE(accessorial_charges, 0)

    ) AS combined_amount_for_comparison

FROM silver.loads

GROUP BY load_status

ORDER BY load_count DESC;

/* ------------------------------------------------------------

   3. Monthly revenue trend

   ------------------------------------------------------------ */

SELECT

    DATEFROMPARTS(

        YEAR(load_date),

        MONTH(load_date),

        1

    ) AS reporting_month,

    COUNT_BIG(*) AS load_count,

    SUM(revenue) AS total_reported_revenue,

    AVG(revenue) AS average_reported_revenue,

    SUM(fuel_surcharge) AS total_fuel_surcharge,

    SUM(accessorial_charges) AS total_accessorial_charges

FROM silver.loads

WHERE load_date IS NOT NULL

GROUP BY

    YEAR(load_date),

    MONTH(load_date)

ORDER BY reporting_month;

/* GOLD INVESTIGATION 02 — Revenue and Route Pricing

   Compare recorded load revenue with indicative route pricing.

   This is an analytical comparison, not proof of billing rules.

*/

-- 1. How many loads have a usable route and pricing reference?

SELECT

    COUNT_BIG(*) AS total_loads,

    SUM(CASE WHEN l.route_id IS NOT NULL THEN 1 ELSE 0 END)

        AS loads_with_route,

    SUM(CASE WHEN r.route_id IS NOT NULL THEN 1 ELSE 0 END)

        AS loads_with_matching_route,

    SUM(CASE

            WHEN r.typical_distance_miles IS NOT NULL

             AND r.base_rate_per_mile IS NOT NULL

            THEN 1 ELSE 0

        END) AS loads_with_route_pricing

FROM silver.loads AS l

LEFT JOIN silver.routes AS r

    ON l.route_id = r.route_id;

-- 2. Compare recorded revenue with indicative route pricing.

WITH RevenueComparison AS

(

    SELECT

        l.load_id,

        l.route_id,

        l.revenue,

        l.fuel_surcharge,

        l.accessorial_charges,

        r.typical_distance_miles,

        r.base_rate_per_mile,

        r.fuel_surcharge_rate,

        CAST(

            r.typical_distance_miles * r.base_rate_per_mile

            AS DECIMAL(18,2)

        ) AS estimated_base_freight

    FROM silver.loads AS l

    LEFT JOIN silver.routes AS r

        ON l.route_id = r.route_id

)

SELECT

    COUNT_BIG(*) AS loads_with_pricing,

    AVG(revenue) AS average_recorded_revenue,

    AVG(estimated_base_freight) AS average_estimated_base_freight,

    AVG(fuel_surcharge) AS average_fuel_surcharge,

    AVG(accessorial_charges) AS average_accessorial_charges,

    AVG(revenue - estimated_base_freight)

        AS average_revenue_minus_estimated_base,

    SUM(CASE

            WHEN revenue > estimated_base_freight THEN 1

            ELSE 0

        END) AS revenue_above_estimated_base,

    SUM(CASE

            WHEN revenue = estimated_base_freight THEN 1

            ELSE 0

        END) AS revenue_equal_to_estimated_base,

    SUM(CASE

            WHEN revenue < estimated_base_freight THEN 1

            ELSE 0

        END) AS revenue_below_estimated_base

FROM RevenueComparison

WHERE estimated_base_freight IS NOT NULL;

-- 3. Inspect individual examples to understand the relationship.

SELECT TOP (25)

    l.load_id,

    l.load_date,

    l.route_id,

    l.revenue,

    l.fuel_surcharge,

    l.accessorial_charges,

    r.typical_distance_miles,

    r.base_rate_per_mile,

    r.fuel_surcharge_rate,

    CAST(

        r.typical_distance_miles * r.base_rate_per_mile

        AS DECIMAL(18,2)

    ) AS estimated_base_freight

FROM silver.loads AS l

LEFT JOIN silver.routes AS r

    ON l.route_id = r.route_id

WHERE r.route_id IS NOT NULL

ORDER BY l.load_id;

USE LogisticsAnalytics;

/* GOLD INVESTIGATION 02

   Validate route-based fuel surcharge calculation.

*/

WITH PricingComparison AS

(

    SELECT

        l.load_id,

        l.fuel_surcharge,

        r.typical_distance_miles,

        r.fuel_surcharge_rate,

        CAST(

            r.typical_distance_miles * r.fuel_surcharge_rate

            AS DECIMAL(18,2)

        ) AS estimated_fuel_surcharge

    FROM silver.loads AS l

    INNER JOIN silver.routes AS r

        ON l.route_id = r.route_id

)

SELECT

    COUNT_BIG(*) AS loads_compared,

    AVG(fuel_surcharge) AS average_recorded_surcharge,

    AVG(estimated_fuel_surcharge) AS average_estimated_surcharge,

    AVG(fuel_surcharge - estimated_fuel_surcharge)

        AS average_difference,

    SUM(CASE

        WHEN ABS(fuel_surcharge - estimated_fuel_surcharge) <= 0.01

        THEN 1 ELSE 0

    END) AS matching_surcharge,

    SUM(CASE

        WHEN fuel_surcharge > estimated_fuel_surcharge + 0.01

        THEN 1 ELSE 0

    END) AS surcharge_above_estimate,

    SUM(CASE

        WHEN fuel_surcharge < estimated_fuel_surcharge - 0.01

        THEN 1 ELSE 0

    END) AS surcharge_below_estimate

FROM PricingComparison;

USE LogisticsAnalytics;

/* GOLD INVESTIGATION 03 — Trip Activity */

-- 1. Overall trip profile

SELECT

    COUNT_BIG(*) AS total_trips,

    COUNT(dispatch_date) AS trips_with_dispatch_date,

    SUM(CASE WHEN dispatch_date IS NULL THEN 1 ELSE 0 END)

        AS null_dispatch_dates,

    MIN(dispatch_date) AS first_dispatch_date,

    MAX(dispatch_date) AS last_dispatch_date,

    COUNT(DISTINCT trip_status) AS distinct_trip_statuses,

    SUM(actual_distance_miles) AS total_distance_miles,

    AVG(actual_distance_miles) AS average_distance_per_trip,

    AVG(actual_duration_hours) AS average_duration_hours

FROM silver.trips;

-- 2. Trip status breakdown

SELECT

    trip_status,

    COUNT_BIG(*) AS trip_count,

    AVG(actual_distance_miles) AS average_distance_miles,

    AVG(actual_duration_hours) AS average_duration_hours

FROM silver.trips

GROUP BY trip_status

ORDER BY trip_count DESC;

-- 3. Monthly trip activity

SELECT

    DATEFROMPARTS(YEAR(dispatch_date), MONTH(dispatch_date), 1)

        AS reporting_month,

    COUNT_BIG(*) AS trip_count,

    SUM(actual_distance_miles) AS total_distance_miles,

    AVG(actual_distance_miles) AS average_distance_miles,

    AVG(actual_duration_hours) AS average_duration_hours

FROM silver.trips

WHERE dispatch_date IS NOT NULL

GROUP BY YEAR(dispatch_date), MONTH(dispatch_date)

ORDER BY reporting_month;

USE LogisticsAnalytics;

GO

/* GOLD INVESTIGATION 04 — Fleet Performance */

-- 1. Overall truck activity

SELECT

    COUNT_BIG(*) AS total_trips,

    COUNT(DISTINCT truck_id) AS trucks_used,

    SUM(CASE WHEN truck_id IS NULL THEN 1 ELSE 0 END)

        AS trips_without_truck,

    SUM(actual_distance_miles) AS total_distance_miles,

    AVG(actual_distance_miles) AS average_distance_per_trip,

    SUM(fuel_gallons_used) AS total_fuel_gallons,

    AVG(average_mpg) AS average_recorded_mpg,

    AVG(idle_time_hours) AS average_idle_hours_per_trip

FROM silver.trips;

-- 2. Monthly fleet activity

SELECT

    DATEFROMPARTS(YEAR(dispatch_date), MONTH(dispatch_date), 1)

        AS reporting_month,

    COUNT_BIG(*) AS trip_count,

    COUNT(DISTINCT truck_id) AS trucks_used,

    SUM(actual_distance_miles) AS total_distance_miles,

    SUM(fuel_gallons_used) AS total_fuel_gallons,

    AVG(average_mpg) AS average_recorded_mpg,

    AVG(idle_time_hours) AS average_idle_hours_per_trip

FROM silver.trips

WHERE dispatch_date IS NOT NULL

GROUP BY YEAR(dispatch_date), MONTH(dispatch_date)

ORDER BY reporting_month;

-- 3. Truck-level activity

SELECT

    truck_id,

    COUNT_BIG(*) AS trip_count,

    SUM(actual_distance_miles) AS total_distance_miles,

    SUM(fuel_gallons_used) AS total_fuel_gallons,

    AVG(average_mpg) AS average_recorded_mpg,

    AVG(idle_time_hours) AS average_idle_hours_per_trip

FROM silver.trips

GROUP BY truck_id

ORDER BY trip_count DESC;

-- GOLD INVESTIGATION 04B — Truck-Level Aggregate MPG
-- This query calculates aggregate MPG separately for each truck.
-- It is not the overall fleet-wide weighted MPG calculation.

SELECT

    truck_id,

    COUNT(*) AS trip_count,

    SUM(actual_distance_miles) AS total_distance_miles,

    SUM(fuel_gallons_used) AS total_fuel_gallons,

    CAST(

        SUM(actual_distance_miles)

        / NULLIF(SUM(fuel_gallons_used), 0)

        AS DECIMAL(10,3)

    ) AS aggregate_mpg

FROM silver.trips

WHERE truck_id IS NOT NULL

GROUP BY truck_id

ORDER BY aggregate_mpg DESC;

-- GOLD INVESTIGATION 05A

-- Delivery Event Quality and On-Time Performance

SELECT

    event_type,

    COUNT_BIG(*) AS total_events,

    SUM(CASE

        WHEN on_time_flag = 1 THEN 1 ELSE 0

    END) AS on_time_events,

    SUM(CASE

        WHEN on_time_flag = 0 THEN 1 ELSE 0

    END) AS late_events,

    SUM(CASE

        WHEN on_time_flag IS NULL THEN 1 ELSE 0

    END) AS missing_on_time_flags,

    CAST(

        100.0 * SUM(CASE

            WHEN on_time_flag = 1 THEN 1 ELSE 0

        END)

        / NULLIF(COUNT_BIG(*), 0)

        AS DECIMAL(6,2)

    ) AS on_time_rate_pct

FROM silver.delivery_events

GROUP BY event_type

ORDER BY event_type;

-- GOLD INVESTIGATION 05B — Monthly On-Time Delivery Trend

SELECT

    YEAR(actual_datetime) AS delivery_year,

    MONTH(actual_datetime) AS delivery_month,

    COUNT_BIG(*) AS total_deliveries,

    SUM(CASE WHEN on_time_flag = 1 THEN 1 ELSE 0 END) AS on_time_deliveries,

    SUM(CASE WHEN on_time_flag = 0 THEN 1 ELSE 0 END) AS late_deliveries,

    CAST(

        100.0 * SUM(CASE WHEN on_time_flag = 1 THEN 1 ELSE 0 END)

        / NULLIF(COUNT_BIG(*), 0)

        AS DECIMAL(6,2)

    ) AS on_time_delivery_rate,

    CAST(AVG(CAST(detention_minutes AS DECIMAL(10,2))) AS DECIMAL(10,2))

        AS average_detention_minutes

FROM silver.delivery_events

WHERE event_type = 'Delivery'

GROUP BY

    YEAR(actual_datetime),

    MONTH(actual_datetime)

ORDER BY

    delivery_year,

    delivery_month;

-- GOLD INVESTIGATION 06A — Customer Revenue Contribution

SELECT

    c.customer_id,

    c.customer_name,

    c.customer_type,

    c.account_status,

    c.contract_start_date,

    COUNT(l.load_id) AS total_loads,

    CAST(

        SUM(l.revenue) AS DECIMAL(18,2)

    ) AS reported_load_revenue,

    CAST(

        AVG(l.revenue) AS DECIMAL(18,2)

    ) AS average_revenue_per_load,

    CAST(

        SUM(l.revenue) * 100.0

        / NULLIF(

            (SELECT SUM(revenue) FROM silver.loads),

            0

        )

        AS DECIMAL(6,2)

    ) AS revenue_contribution_pct

FROM silver.customers c

LEFT JOIN silver.loads l

    ON c.customer_id = l.customer_id

GROUP BY

    c.customer_id,

    c.customer_name,

    c.customer_type,

    c.account_status,

    c.contract_start_date

ORDER BY

    reported_load_revenue DESC;

    -- GOLD INVESTIGATION 06B — Customer Coverage & Revenue Concentration

WITH CustomerRevenue AS

(

    SELECT

        c.customer_id,

        COUNT_BIG(l.load_id) AS total_loads,

        SUM(l.revenue) AS customer_revenue

    FROM silver.customers c

    LEFT JOIN silver.loads l

        ON c.customer_id = l.customer_id

    GROUP BY c.customer_id

),

RankedCustomers AS

(

    SELECT

        customer_id,

        total_loads,

        customer_revenue,

        ROW_NUMBER() OVER (

            ORDER BY customer_revenue DESC

        ) AS revenue_rank

    FROM CustomerRevenue

)

SELECT

    (SELECT COUNT_BIG(*) FROM silver.customers)

        AS total_customers,

    (SELECT COUNT_BIG(*) FROM RankedCustomers

     WHERE total_loads > 0)

        AS customers_with_loads,

    (SELECT COUNT_BIG(*) FROM RankedCustomers

     WHERE total_loads = 0)

        AS customers_without_loads,

    (SELECT COUNT_BIG(*) FROM silver.loads)

        AS total_loads,

    (SELECT COUNT_BIG(*) FROM silver.loads

     WHERE customer_id IS NULL)

        AS loads_without_customer,

    (SELECT SUM(revenue) FROM silver.loads

     WHERE customer_id IS NULL)

        AS unassigned_load_revenue,

    (SELECT SUM(revenue) FROM silver.loads)

        AS total_reported_load_revenue,

    (SELECT SUM(customer_revenue) FROM RankedCustomers

     WHERE revenue_rank <= 10)

        AS top_10_customer_revenue,

    (SELECT SUM(customer_revenue) FROM RankedCustomers

     WHERE revenue_rank <= 20)

        AS top_20_customer_revenue;

    -- GOLD INVESTIGATION 06C — Customer Type Performance

SELECT

    c.customer_type,

    COUNT(DISTINCT c.customer_id) AS total_customers,

    COUNT_BIG(l.load_id) AS total_loads,

    CAST(

        SUM(l.revenue) AS DECIMAL(18,2)

    ) AS reported_load_revenue,

    CAST(

        AVG(l.revenue) AS DECIMAL(18,2)

    ) AS average_revenue_per_load,

    CAST(

        SUM(l.revenue) * 100.0

        / NULLIF((SELECT SUM(revenue) FROM silver.loads), 0)

        AS DECIMAL(6,2)

    ) AS revenue_contribution_pct

FROM silver.customers c

INNER JOIN silver.loads l

    ON c.customer_id = l.customer_id

GROUP BY c.customer_type

ORDER BY reported_load_revenue DESC;

-- GOLD INVESTIGATION 06D — Contract Start vs First Observed Load

WITH FirstCustomerLoad AS

(

    SELECT

        customer_id,

        MIN(load_date) AS first_observed_load_date,

        COUNT_BIG(*) AS total_loads

    FROM silver.loads

    GROUP BY customer_id

)

SELECT

    COUNT_BIG(*) AS total_customers,

    SUM(CASE

        WHEN f.first_observed_load_date < c.contract_start_date

        THEN 1 ELSE 0

    END) AS first_load_before_contract,

    SUM(CASE

        WHEN f.first_observed_load_date = c.contract_start_date

        THEN 1 ELSE 0

    END) AS first_load_on_contract_start,

    SUM(CASE

        WHEN f.first_observed_load_date > c.contract_start_date

        THEN 1 ELSE 0

    END) AS first_load_after_contract,

    MIN(c.contract_start_date) AS earliest_contract_start,

    MAX(c.contract_start_date) AS latest_contract_start,

    MIN(f.first_observed_load_date) AS earliest_first_load,

    MAX(f.first_observed_load_date) AS latest_first_load

FROM silver.customers c

INNER JOIN FirstCustomerLoad f

    ON c.customer_id = f.customer_id;
