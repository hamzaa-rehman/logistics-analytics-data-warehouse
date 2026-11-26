/*
===============================================================================
GOLD REPORTING VIEW - CUSTOMER PERFORMANCE
===============================================================================

Purpose:
    Provide a customer-grain reporting dataset for customer activity,
    reported load revenue, revenue contribution and customer-type analysis.

View grain:
    One row per customer (customer_id).

Approved business definitions:
    - Total Customer Loads = COUNT of assigned load records.
    - Reported Load Revenue = SUM(fact_loads.revenue).
    - Average Reported Revenue per Load =
      customer reported load revenue / customer load count.
    - Revenue Contribution % =
      customer reported load revenue / total reported load revenue * 100.
    - First Observed Load Date = earliest load date available in Gold.
      It is not a verified customer acquisition date.
    - Fuel surcharge and accessorial charges remain separate measures.
      Do not combine them with reported load revenue.

Important limitations:
    - Customer identity is customer_id, not customer_name.
      Repeated customer names exist.
    - Contract start date is not a verified customer acquisition date.
    - Load history begins on 2022-01-01, while contract dates extend back
      to 2020.
    - The source currency has not been confirmed. Do not add a currency symbol.
    - Customer dimension attributes reflect current Type 1 records.

Join strategy:
    - Aggregate fact_loads by customer_key before joining to dim_customer.
    - Use LEFT JOIN to retain customers even if they have no load activity.
    - Join dim_date separately for contract start and first observed load dates.
    - No fact-to-fact joins are used.

Deployment:
    - Connect DBeaver to the LogisticsAnalytics database before execution.
    - This script contains no GO batch separators or USE statement.
===============================================================================
*/

CREATE OR ALTER VIEW gold.vw_customer_performance
AS

WITH customer_load_summary AS
(
    SELECT
        f.customer_key,
        COUNT_BIG(*) AS customer_load_count,
        SUM(f.revenue) AS reported_load_revenue,
        SUM(f.fuel_surcharge) AS fuel_surcharge_amount,
        SUM(f.accessorial_charges) AS accessorial_charges_amount,
        MIN(f.load_date_key) AS first_observed_load_date_key
    FROM gold.fact_loads AS f
    WHERE f.customer_key IS NOT NULL
    GROUP BY
        f.customer_key
),

customer_metrics AS
(
    SELECT
        c.customer_key,
        c.customer_id,
        c.customer_name,
        c.customer_type,
        c.account_status,
        c.primary_freight_type,
        c.credit_terms_days,
        c.annual_revenue_potential,
        c.contract_start_date,

        COALESCE(
            l.customer_load_count,
            CONVERT(BIGINT, 0)
        ) AS customer_load_count,

        l.reported_load_revenue,
        l.fuel_surcharge_amount,
        l.accessorial_charges_amount,
        l.first_observed_load_date_key,

        SUM(l.reported_load_revenue) OVER ()
            AS total_customer_reported_load_revenue,

        ROW_NUMBER() OVER
        (
            ORDER BY
                l.reported_load_revenue DESC,
                c.customer_id
        ) AS customer_revenue_rank

    FROM gold.dim_customer AS c
    LEFT JOIN customer_load_summary AS l
        ON c.customer_key = l.customer_key
)

SELECT
    -- Customer identity
    cm.customer_key,
    cm.customer_id,
    cm.customer_name,

    -- Customer profile
    cm.customer_type,
    cm.account_status,
    cm.primary_freight_type,
    cm.credit_terms_days,
    cm.annual_revenue_potential,

    -- Contract start date attributes
    cm.contract_start_date,
    contract_date.year_number AS contract_start_calendar_year,
    contract_date.month_number AS contract_start_month_number,
    contract_date.month_name AS contract_start_month_name,

    -- First observed load date attributes
    cm.first_observed_load_date_key,
    first_load_date.full_date AS first_observed_load_date,
    first_load_date.year_number AS first_observed_load_calendar_year,
    first_load_date.month_number AS first_observed_load_month_number,
    first_load_date.month_name AS first_observed_load_month_name,

    -- Customer activity
    cm.customer_load_count,

    -- Financial measures kept separate
    cm.reported_load_revenue,
    cm.fuel_surcharge_amount,
    cm.accessorial_charges_amount,

    -- Customer revenue metrics
    CAST(
        cm.reported_load_revenue
        / NULLIF(cm.customer_load_count, 0)
        AS DECIMAL(18,2)
    ) AS average_reported_revenue_per_load,

    CAST(
        100.0 * cm.reported_load_revenue
        / NULLIF(cm.total_customer_reported_load_revenue, 0)
        AS DECIMAL(6,2)
    ) AS reported_load_revenue_contribution_pct,

    cm.customer_revenue_rank

FROM customer_metrics AS cm
LEFT JOIN gold.dim_date AS contract_date
    ON cm.contract_start_date = contract_date.full_date
LEFT JOIN gold.dim_date AS first_load_date
    ON cm.first_observed_load_date_key = first_load_date.date_key;


-- ============================================================================
-- VIEW VALIDATION
-- Expected:
--   - One row per customer in dim_customer.
--   - No duplicate customer_id values.
--   - All fact_loads records are assigned to a customer.
--   - Customer load counts and financial measures reconcile to fact_loads.
-- ============================================================================

IF
(
    SELECT COUNT_BIG(*)
    FROM gold.vw_customer_performance
)
<>
(
    SELECT COUNT_BIG(*)
    FROM gold.dim_customer
)
    THROW 51131, 'vw_customer_performance row count does not match dim_customer.', 1;


IF EXISTS
(
    SELECT customer_id
    FROM gold.vw_customer_performance
    GROUP BY customer_id
    HAVING COUNT_BIG(*) <> 1
)
    THROW 51132, 'vw_customer_performance does not preserve one row per customer.', 1;


IF EXISTS
(
    SELECT
        COUNT_BIG(*) AS total_loads,
        COUNT_BIG(customer_key) AS assigned_customer_loads,
        COUNT_BIG(*) - COUNT_BIG(customer_key) AS unassigned_customer_loads,
        SUM(revenue) AS reported_load_revenue,
        SUM(fuel_surcharge) AS fuel_surcharge_amount,
        SUM(accessorial_charges) AS accessorial_charges_amount
    FROM gold.fact_loads

    EXCEPT

    SELECT
        SUM(customer_load_count) AS total_loads,
        SUM(customer_load_count) AS assigned_customer_loads,
        CONVERT(BIGINT, 0) AS unassigned_customer_loads,
        SUM(reported_load_revenue) AS reported_load_revenue,
        SUM(fuel_surcharge_amount) AS fuel_surcharge_amount,
        SUM(accessorial_charges_amount) AS accessorial_charges_amount
    FROM gold.vw_customer_performance
)
    THROW 51133, 'vw_customer_performance measures or customer assignments do not reconcile to fact_loads.', 1;


-- ============================================================================
-- 1. OVERALL CUSTOMER PERFORMANCE
-- ============================================================================

SELECT
    COUNT_BIG(*) AS total_customers,
    SUM(CASE
        WHEN customer_load_count > 0 THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END) AS customers_with_loads,
    SUM(CASE
        WHEN customer_load_count = 0 THEN CONVERT(BIGINT, 1)
        ELSE CONVERT(BIGINT, 0)
    END) AS customers_without_loads,
    SUM(customer_load_count) AS total_loads,
    SUM(reported_load_revenue) AS total_reported_load_revenue,
    SUM(fuel_surcharge_amount) AS total_fuel_surcharge,
    SUM(accessorial_charges_amount) AS total_accessorial_charges,
    SUM(CASE
        WHEN customer_revenue_rank <= 10
        THEN reported_load_revenue
        ELSE 0
    END) AS top_10_customer_revenue,
    SUM(CASE
        WHEN customer_revenue_rank <= 20
        THEN reported_load_revenue
        ELSE 0
    END) AS top_20_customer_revenue
FROM gold.vw_customer_performance;


-- ============================================================================
-- 2. CUSTOMER TYPE PERFORMANCE
-- Average revenue per load is calculated as total type revenue / total loads.
-- ============================================================================

WITH customer_type_summary AS
(
    SELECT
        customer_type,
        COUNT_BIG(*) AS customer_count,
        SUM(customer_load_count) AS total_loads,
        SUM(reported_load_revenue) AS reported_load_revenue
    FROM gold.vw_customer_performance
    GROUP BY customer_type
)

SELECT
    customer_type,
    customer_count,
    total_loads,
    reported_load_revenue,
    CAST(
        reported_load_revenue / NULLIF(total_loads, 0)
        AS DECIMAL(18,2)
    ) AS average_reported_revenue_per_load,
    CAST(
        100.0 * reported_load_revenue
        / NULLIF(SUM(reported_load_revenue) OVER (), 0)
        AS DECIMAL(6,2)
    ) AS revenue_contribution_pct
FROM customer_type_summary
ORDER BY reported_load_revenue DESC;


-- ============================================================================
-- 3. TOP 20 CUSTOMERS BY REPORTED LOAD REVENUE
-- ============================================================================

SELECT TOP (20)
    customer_revenue_rank,
    customer_id,
    customer_name,
    customer_type,
    customer_load_count,
    reported_load_revenue,
    reported_load_revenue_contribution_pct,
    first_observed_load_date
FROM gold.vw_customer_performance
ORDER BY customer_revenue_rank;
