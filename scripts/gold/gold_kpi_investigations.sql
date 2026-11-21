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
     - This collection contains the Gold KPI investigation SQL through Safety Performance (08A–08K).

   ============================================================================ */

USE LogisticsAnalytics;


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

SELECT
    COUNT_BIG(*) AS total_purchases,
    COUNT(trip_id) AS purchases_with_trip_id,
    COUNT(truck_id) AS purchases_with_truck_id,
    COUNT(driver_id) AS purchases_with_driver_id,
    SUM(CASE WHEN trip_id IS NULL THEN 1 ELSE 0 END) AS purchases_without_trip_id,
    SUM(CASE WHEN truck_id IS NULL THEN 1 ELSE 0 END) AS purchases_without_truck_id,
    SUM(CASE WHEN driver_id IS NULL THEN 1 ELSE 0 END) AS purchases_without_driver_id,
    SUM(CASE WHEN purchase_date IS NULL THEN 1 ELSE 0 END) AS null_purchase_dates,
    SUM(CASE WHEN gallons IS NULL THEN 1 ELSE 0 END) AS null_gallons,
    SUM(CASE WHEN price_per_gallon IS NULL THEN 1 ELSE 0 END) AS null_unit_prices,
    SUM(CASE WHEN total_cost IS NULL THEN 1 ELSE 0 END) AS null_total_costs,
    MIN(purchase_date) AS earliest_purchase,
    MAX(purchase_date) AS latest_purchase,
    SUM(gallons) AS total_gallons,
    SUM(total_cost) AS total_fuel_cost,
    MIN(gallons) AS minimum_gallons,
    MAX(gallons) AS maximum_gallons,
    MIN(price_per_gallon) AS minimum_price_per_gallon,
    MAX(price_per_gallon) AS maximum_price_per_gallon
FROM silver.fuel_purchases;

-- GOLD INVESTIGATION 07B — Fuel Purchase Cost Validation
WITH FuelCostCheck AS
(
    SELECT
        fuel_purchase_id,
        gallons,
        price_per_gallon,
        total_cost,
        CAST(ROUND(gallons * price_per_gallon, 2) AS DECIMAL(18,2)) AS calculated_total_cost
    FROM silver.fuel_purchases
)
SELECT
    COUNT_BIG(*) AS total_purchases,
    SUM(CASE WHEN total_cost = calculated_total_cost THEN 1 ELSE 0 END) AS matching_costs,
    SUM(CASE WHEN total_cost <> calculated_total_cost THEN 1 ELSE 0 END) AS mismatching_costs,
    CAST(MAX(ABS(total_cost - calculated_total_cost)) AS DECIMAL(18,2)) AS maximum_absolute_difference,
    CAST(SUM(total_cost - calculated_total_cost) AS DECIMAL(18,2)) AS total_cost_difference
FROM FuelCostCheck;

-- GOLD INVESTIGATION 07C — Fuel Cost Mismatch Analysis
WITH FuelCostCheck AS
(
    SELECT
        fuel_purchase_id,
        gallons,
        price_per_gallon,
        total_cost,
        CAST(ROUND(gallons * price_per_gallon, 2) AS DECIMAL(18,2)) AS calculated_total_cost
    FROM silver.fuel_purchases
)
SELECT
    total_cost - calculated_total_cost AS cost_difference,
    COUNT_BIG(*) AS affected_purchases
FROM FuelCostCheck
WHERE total_cost <> calculated_total_cost
GROUP BY total_cost - calculated_total_cost
ORDER BY cost_difference;

-- Sample mismatching purchase records
WITH FuelCostCheck AS
(
    SELECT
        fuel_purchase_id,
        gallons,
        price_per_gallon,
        total_cost,
        CAST(ROUND(gallons * price_per_gallon, 2) AS DECIMAL(18,2)) AS calculated_total_cost
    FROM silver.fuel_purchases
)
SELECT TOP (20)
    fuel_purchase_id,
    gallons,
    price_per_gallon,
    total_cost,
    calculated_total_cost,
    total_cost - calculated_total_cost AS cost_difference
FROM FuelCostCheck
WHERE total_cost <> calculated_total_cost
ORDER BY fuel_purchase_id;

-- GOLD INVESTIGATION 07D — Fuel Purchase and Trip Assignment Reconciliation
WITH FuelTripComparison AS
(
    SELECT
        f.fuel_purchase_id,
        f.truck_id AS purchase_truck_id,
        t.truck_id AS trip_truck_id,
        f.driver_id AS purchase_driver_id,
        t.driver_id AS trip_driver_id
    FROM silver.fuel_purchases f
    INNER JOIN silver.trips t
        ON f.trip_id = t.trip_id
)
SELECT
    'Truck' AS assignment_type,
    COUNT_BIG(*) AS total_purchases,
    SUM(CASE WHEN purchase_truck_id = trip_truck_id THEN 1 ELSE 0 END) AS matching_assignments,
    SUM(CASE WHEN purchase_truck_id IS NULL AND trip_truck_id IS NOT NULL THEN 1 ELSE 0 END) AS purchase_assignment_missing,
    SUM(CASE WHEN purchase_truck_id IS NOT NULL AND trip_truck_id IS NULL THEN 1 ELSE 0 END) AS trip_assignment_missing,
    SUM(CASE WHEN purchase_truck_id IS NULL AND trip_truck_id IS NULL THEN 1 ELSE 0 END) AS both_missing,
    SUM(CASE WHEN purchase_truck_id IS NOT NULL AND trip_truck_id IS NOT NULL AND purchase_truck_id <> trip_truck_id THEN 1 ELSE 0 END) AS mismatching_assignments
FROM FuelTripComparison
UNION ALL
SELECT
    'Driver',
    COUNT_BIG(*),
    SUM(CASE WHEN purchase_driver_id = trip_driver_id THEN 1 ELSE 0 END),
    SUM(CASE WHEN purchase_driver_id IS NULL AND trip_driver_id IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN purchase_driver_id IS NOT NULL AND trip_driver_id IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN purchase_driver_id IS NULL AND trip_driver_id IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN purchase_driver_id IS NOT NULL AND trip_driver_id IS NOT NULL AND purchase_driver_id <> trip_driver_id THEN 1 ELSE 0 END)
FROM FuelTripComparison;

-- GOLD INVESTIGATION 07E — Fuel Purchase Quantity and Monthly Patterns

-- 07E.1 Overall purchase quantity distribution
SELECT
    COUNT_BIG(*) AS total_purchases,
    MIN(gallons) AS minimum_gallons,
    MAX(gallons) AS maximum_gallons,
    AVG(gallons) AS average_gallons,
    STDEV(gallons) AS standard_deviation_gallons,
    COUNT(DISTINCT gallons) AS distinct_purchase_quantities,
    SUM(CASE WHEN gallons = 50 THEN 1 ELSE 0 END) AS purchases_of_50_gallons,
    SUM(CASE WHEN gallons = 200 THEN 1 ELSE 0 END) AS purchases_of_200_gallons
FROM silver.fuel_purchases;

-- 07E.2 Purchase quantity frequency distribution
SELECT
    gallons,
    COUNT_BIG(*) AS purchase_count
FROM silver.fuel_purchases
GROUP BY gallons
ORDER BY purchase_count DESC;

-- 07E.3 Monthly fuel purchasing trend
SELECT
    YEAR(purchase_date) AS purchase_year,
    MONTH(purchase_date) AS purchase_month,
    COUNT_BIG(*) AS purchase_count,
    SUM(gallons) AS total_gallons,
    SUM(total_cost) AS total_fuel_cost,
    AVG(gallons) AS average_gallons_per_purchase,
    AVG(price_per_gallon) AS average_price_per_gallon
FROM silver.fuel_purchases
GROUP BY YEAR(purchase_date), MONTH(purchase_date)
ORDER BY purchase_year, purchase_month;

-- 07F — Monthly Fuel Purchased vs. Trip-Recorded Fuel Consumption
WITH MonthlyFuelPurchases AS
(
    SELECT
        YEAR(purchase_date) AS purchase_year,
        MONTH(purchase_date) AS purchase_month,
        COUNT_BIG(*) AS purchase_count,
        SUM(gallons) AS purchased_gallons,
        SUM(total_cost) AS fuel_purchase_cost
    FROM silver.fuel_purchases
    GROUP BY YEAR(purchase_date), MONTH(purchase_date)
),
MonthlyTripFuel AS
(
    SELECT
        YEAR(dispatch_date) AS dispatch_year,
        MONTH(dispatch_date) AS dispatch_month,
        COUNT_BIG(*) AS trip_count,
        SUM(fuel_gallons_used) AS consumed_gallons
    FROM silver.trips
    GROUP BY YEAR(dispatch_date), MONTH(dispatch_date)
)
SELECT
    COALESCE(p.purchase_year, t.dispatch_year) AS [year],
    COALESCE(p.purchase_month, t.dispatch_month) AS [month],
    p.purchase_count,
    t.trip_count,
    p.purchased_gallons,
    t.consumed_gallons,
    p.purchased_gallons - t.consumed_gallons AS monthly_difference_gallons,
    p.fuel_purchase_cost
FROM MonthlyFuelPurchases p
FULL OUTER JOIN MonthlyTripFuel t
    ON p.purchase_year = t.dispatch_year
    AND p.purchase_month = t.dispatch_month
ORDER BY [year], [month];

-- 07F SUPPORTING — Trip-level aggregate purchase/consumption totals
WITH PurchaseByTrip AS
(
    SELECT
        trip_id,
        COUNT_BIG(*) AS purchase_count,
        SUM(gallons) AS purchased_gallons,
        SUM(total_cost) AS purchase_cost
    FROM silver.fuel_purchases
    GROUP BY trip_id
),
TripFuel AS
(
    SELECT
        trip_id,
        fuel_gallons_used,
        actual_distance_miles,
        truck_id
    FROM silver.trips
)
SELECT
    COUNT_BIG(*) AS total_trips,
    SUM(CASE WHEN p.trip_id IS NOT NULL THEN 1 ELSE 0 END) AS trips_with_purchases,
    SUM(CASE WHEN p.trip_id IS NULL THEN 1 ELSE 0 END) AS trips_without_purchases,
    SUM(COALESCE(p.purchase_count, 0)) AS total_purchase_records,
    SUM(COALESCE(p.purchased_gallons, 0)) AS total_purchased_gallons,
    SUM(t.fuel_gallons_used) AS total_trip_fuel_consumption,
    SUM(CASE WHEN p.trip_id IS NOT NULL THEN t.fuel_gallons_used ELSE 0 END) AS consumption_for_trips_with_purchases,
    SUM(CASE WHEN p.trip_id IS NULL THEN t.fuel_gallons_used ELSE 0 END) AS consumption_for_trips_without_purchases,
    SUM(COALESCE(p.purchased_gallons, 0)) - SUM(t.fuel_gallons_used) AS purchase_vs_consumption_difference
FROM TripFuel t
LEFT JOIN PurchaseByTrip p
    ON t.trip_id = p.trip_id;

-- GOLD INVESTIGATION 07G — Trip-Level Fuel Purchase vs. Consumption Reconciliation
WITH FuelPurchasesByTrip AS
(
    SELECT
        trip_id,
        COUNT_BIG(*) AS purchase_count,
        SUM(gallons) AS purchased_gallons
    FROM silver.fuel_purchases
    GROUP BY trip_id
),
TripFuelComparison AS
(
    SELECT
        t.trip_id,
        t.fuel_gallons_used,
        COALESCE(f.purchase_count, 0) AS purchase_count,
        COALESCE(f.purchased_gallons, 0) AS purchased_gallons,
        CASE
            WHEN f.trip_id IS NULL THEN 'No Purchase Record'
            WHEN f.purchased_gallons > t.fuel_gallons_used THEN 'Purchased > Consumed'
            WHEN f.purchased_gallons < t.fuel_gallons_used THEN 'Purchased < Consumed'
            ELSE 'Purchased = Consumed'
        END AS reconciliation_status
    FROM silver.trips t
    LEFT JOIN FuelPurchasesByTrip f
        ON t.trip_id = f.trip_id
)
SELECT
    reconciliation_status,
    COUNT_BIG(*) AS trip_count,
    SUM(purchase_count) AS total_purchase_records,
    SUM(purchased_gallons) AS total_purchased_gallons,
    SUM(fuel_gallons_used) AS total_consumed_gallons,
    SUM(purchased_gallons - fuel_gallons_used) AS net_gallon_difference
FROM TripFuelComparison
GROUP BY reconciliation_status
ORDER BY reconciliation_status;

-- 07G SUPPORTING CHECK — Trip Fuel Consumption Quality
SELECT
    COUNT_BIG(*) AS total_trips,
    SUM(CASE WHEN fuel_gallons_used IS NULL THEN 1 ELSE 0 END) AS null_consumption,
    SUM(CASE WHEN fuel_gallons_used = 0 THEN 1 ELSE 0 END) AS zero_consumption,
    SUM(CASE WHEN fuel_gallons_used < 0 THEN 1 ELSE 0 END) AS negative_consumption,
    MIN(fuel_gallons_used) AS minimum_consumption,
    MAX(fuel_gallons_used) AS maximum_consumption
FROM silver.trips;

-- GOLD INVESTIGATION 07H — Fuel Cost Attribution by Truck and Driver
SELECT
    CASE WHEN truck_id IS NULL THEN 'Unassigned' ELSE 'Assigned' END AS truck_assignment,
    CASE WHEN driver_id IS NULL THEN 'Unassigned' ELSE 'Assigned' END AS driver_assignment,
    COUNT_BIG(*) AS purchase_count,
    COUNT(DISTINCT truck_id) AS distinct_trucks,
    COUNT(DISTINCT driver_id) AS distinct_drivers,
    SUM(gallons) AS total_gallons,
    SUM(total_cost) AS total_fuel_cost,
    AVG(price_per_gallon) AS avg_price_per_gallon
FROM silver.fuel_purchases
GROUP BY
    CASE WHEN truck_id IS NULL THEN 'Unassigned' ELSE 'Assigned' END,
    CASE WHEN driver_id IS NULL THEN 'Unassigned' ELSE 'Assigned' END
ORDER BY truck_assignment, driver_assignment;

/* ============================================================
   GOLD KPI INVESTIGATION 08 — MAINTENANCE PERFORMANCE AND COST
   Source: silver.maintenance_records
   Grain: one row per maintenance event
   ============================================================ */

-- 08A — Maintenance completeness, cost profile, and validity
SELECT
    COUNT_BIG(*) AS total_records,
    COUNT(truck_id) AS records_with_truck_id,
    COUNT_BIG(*) - COUNT(truck_id) AS records_without_truck_id,
    COUNT(maintenance_date) AS records_with_maintenance_date,
    COUNT(maintenance_type) AS records_with_maintenance_type,
    COUNT(labor_hours) AS records_with_labor_hours,
    COUNT(labor_cost) AS records_with_labor_cost,
    COUNT(parts_cost) AS records_with_parts_cost,
    COUNT(total_cost) AS records_with_total_cost,
    COUNT(downtime_hours) AS records_with_downtime,
    SUM(total_cost) AS total_recorded_maintenance_cost,
    SUM(labor_cost) AS total_labor_cost,
    SUM(parts_cost) AS total_parts_cost,
    MIN(maintenance_date) AS earliest_maintenance_date,
    MAX(maintenance_date) AS latest_maintenance_date,
    MIN(total_cost) AS minimum_total_cost,
    MAX(total_cost) AS maximum_total_cost,
    MIN(downtime_hours) AS minimum_downtime_hours,
    MAX(downtime_hours) AS maximum_downtime_hours,
    SUM(CASE WHEN total_cost < 0 THEN 1 ELSE 0 END) AS negative_total_cost_records,
    SUM(CASE WHEN labor_cost < 0 THEN 1 ELSE 0 END) AS negative_labor_cost_records,
    SUM(CASE WHEN parts_cost < 0 THEN 1 ELSE 0 END) AS negative_parts_cost_records,
    SUM(CASE WHEN downtime_hours < 0 THEN 1 ELSE 0 END) AS negative_downtime_records,
    SUM(CASE WHEN total_cost IS NOT NULL AND labor_cost IS NOT NULL AND parts_cost IS NOT NULL
        AND ABS(total_cost - (labor_cost + parts_cost)) > 0.01 THEN 1 ELSE 0 END)
        AS cost_component_mismatches
FROM silver.maintenance_records;

-- 08B — Truck-level maintenance events, cost, and downtime
SELECT
    truck_id,
    COUNT_BIG(*) AS maintenance_events,
    SUM(total_cost) AS total_maintenance_cost,
    AVG(total_cost) AS average_cost_per_event,
    SUM(labor_cost) AS total_labor_cost,
    SUM(parts_cost) AS total_parts_cost,
    SUM(downtime_hours) AS total_downtime_hours,
    AVG(downtime_hours) AS average_downtime_per_event,
    MIN(maintenance_date) AS first_maintenance_date,
    MAX(maintenance_date) AS latest_maintenance_date
FROM silver.maintenance_records
GROUP BY truck_id
ORDER BY total_maintenance_cost DESC;

-- 08C — Maintenance cost and downtime by maintenance type
SELECT
    maintenance_type,
    COUNT_BIG(*) AS maintenance_events,
    SUM(total_cost) AS total_maintenance_cost,
    AVG(total_cost) AS average_cost_per_event,
    SUM(labor_cost) AS total_labor_cost,
    SUM(parts_cost) AS total_parts_cost,
    SUM(downtime_hours) AS total_downtime_hours,
    AVG(downtime_hours) AS average_downtime_per_event
FROM silver.maintenance_records
GROUP BY maintenance_type
ORDER BY total_maintenance_cost DESC;


/* ============================================================
   GOLD KPI INVESTIGATION 09 — SAFETY PERFORMANCE
   Source: silver.safety_incidents
   Incident grain: one row per safety incident
   Related exposure source: silver.trips
   Purpose: Profile safety records, validate claims and attribution,
            analyse incident patterns, and calculate descriptive
            exposure-adjusted rates.
   ============================================================ */

-- 08A — Safety incident completeness, date coverage, and recorded amounts
SELECT
    COUNT_BIG(*) AS total_incidents,
    COUNT(incident_date) AS incidents_with_date,
    COUNT(incident_type) AS incidents_with_type,
    COUNT(trip_id) AS incidents_with_trip_id,
    COUNT(truck_id) AS incidents_with_truck_id,
    COUNT(driver_id) AS incidents_with_driver_id,
    COUNT(at_fault_flag) AS incidents_with_at_fault_flag,
    COUNT(injury_flag) AS incidents_with_injury_flag,
    COUNT(preventable_flag) AS incidents_with_preventable_flag,
    COUNT(vehicle_damage_cost) AS incidents_with_vehicle_damage_cost,
    COUNT(cargo_damage_cost) AS incidents_with_cargo_damage_cost,
    COUNT(claim_amount) AS incidents_with_claim_amount,
    MIN(incident_date) AS earliest_incident_date,
    MAX(incident_date) AS latest_incident_date,
    SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,
    SUM(cargo_damage_cost) AS total_cargo_damage_cost,
    SUM(claim_amount) AS total_claim_amount,
    MIN(claim_amount) AS minimum_claim_amount,
    MAX(claim_amount) AS maximum_claim_amount
FROM silver.safety_incidents;

-- 08B — Validate claim amount against vehicle and cargo damage per incident
SELECT
    COUNT_BIG(*) AS total_incidents,
    SUM(
        CASE
            WHEN ABS(
                claim_amount -
                (vehicle_damage_cost + cargo_damage_cost)
            ) <= 0.01
            THEN 1 ELSE 0
        END
    ) AS matching_incidents,
    SUM(
        CASE
            WHEN ABS(
                claim_amount -
                (vehicle_damage_cost + cargo_damage_cost)
            ) > 0.01
            THEN 1 ELSE 0
        END
    ) AS mismatching_incidents,
    MAX(
        ABS(
            claim_amount -
            (vehicle_damage_cost + cargo_damage_cost)
        )
    ) AS maximum_absolute_difference,
    SUM(
        claim_amount -
        (vehicle_damage_cost + cargo_damage_cost)
    ) AS total_difference
FROM silver.safety_incidents;

-- 08C — Identify incidents missing truck or driver attribution
SELECT
    incident_id,
    trip_id,
    truck_id,
    driver_id,
    incident_date,
    incident_type
FROM silver.safety_incidents
WHERE truck_id IS NULL
   OR driver_id IS NULL;

-- 08D — Incident frequency, classifications, and recorded financial impact by type
SELECT
    incident_type,
    COUNT_BIG(*) AS total_incidents,
    SUM(CASE WHEN at_fault_flag = 1 THEN 1 ELSE 0 END) AS at_fault_incidents,
    SUM(CASE WHEN injury_flag = 1 THEN 1 ELSE 0 END) AS injury_incidents,
    SUM(CASE WHEN preventable_flag = 1 THEN 1 ELSE 0 END) AS preventable_incidents,
    SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,
    SUM(cargo_damage_cost) AS total_cargo_damage_cost,
    SUM(claim_amount) AS total_claim_amount
FROM silver.safety_incidents
GROUP BY incident_type
ORDER BY total_incidents DESC;

-- 08E — Compare missing incident truck/driver IDs with the associated trip
SELECT
    s.incident_id,
    s.trip_id,
    s.truck_id AS incident_truck_id,
    t.truck_id AS trip_truck_id,
    s.driver_id AS incident_driver_id,
    t.driver_id AS trip_driver_id,
    t.dispatch_date,
    s.incident_date,
    DATEDIFF(
        DAY,
        t.dispatch_date,
        CAST(s.incident_date AS DATE)
    ) AS days_between_dispatch_and_incident
FROM silver.safety_incidents AS s
LEFT JOIN silver.trips AS t
    ON s.trip_id = t.trip_id
WHERE s.truck_id IS NULL
   OR s.driver_id IS NULL;

-- 08F — Check incident-record to distinct-trip relationship and trip matching
SELECT
    COUNT_BIG(*) AS total_incident_records,
    COUNT(DISTINCT s.trip_id) AS distinct_trips_with_incidents,
    COUNT_BIG(*) - COUNT(DISTINCT s.trip_id)
        AS additional_incident_records,
    COUNT(DISTINCT CASE
        WHEN t.trip_id IS NOT NULL THEN s.trip_id
    END) AS incidents_linked_to_existing_trips,
    COUNT(DISTINCT CASE
        WHEN t.trip_id IS NULL THEN s.trip_id
    END) AS incident_trip_ids_not_found
FROM silver.safety_incidents AS s
LEFT JOIN silver.trips AS t
    ON s.trip_id = t.trip_id;

-- 08G — Overall safety rates using completed trips and trip miles as exposure
WITH TripSummary AS
(
    SELECT
        COUNT_BIG(*) AS total_trips,
        SUM(actual_distance_miles) AS total_trip_miles
    FROM silver.trips
),
IncidentSummary AS
(
    SELECT
        COUNT_BIG(*) AS total_incidents,
        COUNT(DISTINCT trip_id) AS trips_with_incidents
    FROM silver.safety_incidents
)
SELECT
    i.total_incidents,
    i.trips_with_incidents,
    t.total_trips,
    t.total_trip_miles,
    CAST(
        i.total_incidents * 1000.0 / t.total_trips
        AS DECIMAL(10,4)
    ) AS incidents_per_1000_trips,
    CAST(
        i.total_incidents * 1000000.0 / t.total_trip_miles
        AS DECIMAL(10,4)
    ) AS incidents_per_million_miles,
    CAST(
        i.trips_with_incidents * 100.0 / t.total_trips
        AS DECIMAL(10,4)
    ) AS percentage_of_trips_with_incidents
FROM TripSummary AS t
CROSS JOIN IncidentSummary AS i;

-- 08H — Annual incident counts and exposure-adjusted rates
WITH AnnualIncidents AS
(
    SELECT
        YEAR(incident_date) AS reporting_year,
        COUNT_BIG(*) AS total_incidents
    FROM silver.safety_incidents
    GROUP BY YEAR(incident_date)
),
AnnualTrips AS
(
    SELECT
        YEAR(dispatch_date) AS reporting_year,
        COUNT_BIG(*) AS total_trips,
        SUM(actual_distance_miles) AS total_trip_miles
    FROM silver.trips
    GROUP BY YEAR(dispatch_date)
)
SELECT
    t.reporting_year,
    COALESCE(i.total_incidents, 0) AS total_incidents,
    t.total_trips,
    t.total_trip_miles,
    CAST(
        COALESCE(i.total_incidents, 0) * 1000.0
        / NULLIF(t.total_trips, 0)
        AS DECIMAL(10,4)
    ) AS incidents_per_1000_trips,
    CAST(
        COALESCE(i.total_incidents, 0) * 1000000.0
        / NULLIF(t.total_trip_miles, 0)
        AS DECIMAL(10,4)
    ) AS incidents_per_million_miles
FROM AnnualTrips AS t
LEFT JOIN AnnualIncidents AS i
    ON t.reporting_year = i.reporting_year
ORDER BY t.reporting_year;

-- 08I — Analyse overlap among at-fault, injury, and preventable classifications
SELECT
    at_fault_flag,
    injury_flag,
    preventable_flag,
    COUNT_BIG(*) AS total_incidents,
    SUM(claim_amount) AS total_claim_amount,
    AVG(claim_amount) AS average_claim_amount,
    SUM(vehicle_damage_cost) AS total_vehicle_damage_cost,
    SUM(cargo_damage_cost) AS total_cargo_damage_cost
FROM silver.safety_incidents
GROUP BY
    at_fault_flag,
    injury_flag,
    preventable_flag
ORDER BY
    total_incidents DESC;

-- 08J — Validate incident year against associated trip dispatch year
SELECT
    COUNT_BIG(*) AS total_incidents,
    SUM(CASE
        WHEN YEAR(s.incident_date) = YEAR(t.dispatch_date)
        THEN 1 ELSE 0
    END) AS same_year_incidents,
    SUM(CASE
        WHEN YEAR(s.incident_date) <> YEAR(t.dispatch_date)
        THEN 1 ELSE 0
    END) AS different_year_incidents,
    MIN(DATEDIFF(
        DAY,
        t.dispatch_date,
        CAST(s.incident_date AS DATE)
    )) AS minimum_days_after_dispatch,
    MAX(DATEDIFF(
        DAY,
        t.dispatch_date,
        CAST(s.incident_date AS DATE)
    )) AS maximum_days_after_dispatch,
    AVG(CAST(DATEDIFF(
        DAY,
        t.dispatch_date,
        CAST(s.incident_date AS DATE)
    ) AS DECIMAL(10,2))) AS average_days_after_dispatch
FROM silver.safety_incidents AS s
INNER JOIN silver.trips AS t
    ON s.trip_id = t.trip_id;

-- 08K — Overall driver and truck attribution coverage
SELECT
    COUNT_BIG(*) AS total_incidents,
    COUNT(DISTINCT driver_id) AS distinct_drivers_involved,
    COUNT(DISTINCT truck_id) AS distinct_trucks_involved,
    SUM(CASE
        WHEN driver_id IS NULL THEN 1
        ELSE 0
    END) AS incidents_without_driver,
    SUM(CASE
        WHEN truck_id IS NULL THEN 1
        ELSE 0
    END) AS incidents_without_truck,
    COUNT(DISTINCT trip_id) AS distinct_trips_involved
FROM silver.safety_incidents;
