/*
===============================================================================
GOLD REPORTING VIEW - DELIVERY PERFORMANCE
===============================================================================
Purpose:
    Provide an event-grain reporting dataset for pickup and delivery analysis,
    with additive indicators for correctly calculating delivery-only KPIs.

View grain:
    One row per delivery event (event_id).

Approved business definitions:
    - On-Time Delivery Rate =
      on-time Delivery events / all Delivery events * 100.
    - Only event_type = 'Delivery' contributes to the delivery KPI.
    - Pickup events remain available for separate operational analysis.
    - Use actual_datetime for event-time trends.
    - Average detention for the delivery KPI must use Delivery events only.
    - NULL on_time_flag values remain visible and are not counted as on-time.
      The delivery-event denominator still includes every Delivery event.

Join strategy:
    - Scheduled and actual dates are separate roles of gold.dim_date.
    - Both date keys are mandatory foreign keys, so INNER JOINs are used.
    - Facility is optional, so gold.dim_facility is a LEFT JOIN.
    - Event location text is retained separately from facility master location.
    - No fact-to-fact joins are used.

Interpretation:
    - detention_minutes and on_time_flag showed an observed association around
      an approximate +/-120-minute window in prior investigation. This is not
      a causal finding or an approved business threshold.
    - January 2025 is partial-period data and should not be compared with full
      years as though it were a complete month.

Deployment:
    Run against the existing Gold schema after the Gold load.
    This script creates or alters the view; it does not modify fact data.
===============================================================================
*/

USE LogisticsAnalytics;


CREATE OR ALTER VIEW gold.vw_delivery_performance
AS
SELECT
    -- Event identity and source relationships
    f.delivery_event_fact_key,
    f.event_id,
    f.load_id,
    f.trip_id,

    -- Event and timestamp details
    f.event_type,
    f.scheduled_datetime,
    f.actual_datetime,
    f.detention_minutes,
    f.on_time_flag,

    -- Scheduled date attributes
    f.scheduled_date_key,
    ds.full_date AS scheduled_date,
    ds.day_name AS scheduled_day_name,
    ds.week_of_year AS scheduled_iso_week_number,
    ds.iso_week_year AS scheduled_iso_week_year,
    ds.month_number AS scheduled_month_number,
    ds.month_name AS scheduled_month_name,
    ds.quarter_number AS scheduled_quarter_number,
    ds.year_number AS scheduled_calendar_year,

    -- Actual date attributes
    f.actual_date_key,
    da.full_date AS actual_date,
    da.day_name AS actual_day_name,
    da.week_of_year AS actual_iso_week_number,
    da.iso_week_year AS actual_iso_week_year,
    da.month_number AS actual_month_number,
    da.month_name AS actual_month_name,
    da.quarter_number AS actual_quarter_number,
    da.year_number AS actual_calendar_year,
    da.year_month AS actual_year_month,

    -- Facility master attributes; event location remains separate below
    f.facility_key,
    fac.facility_id,
    fac.facility_name,
    fac.facility_type,
    fac.city AS facility_city,
    fac.state AS facility_state,

    -- Event-reported location (not assumed to be the facility master location)
    f.location_city AS event_location_city,
    f.location_state AS event_location_state,

    -- Additive delivery KPI indicators.
    -- Aggregate these indicators before calculating rates.
    CASE WHEN f.event_type = 'Delivery' THEN 1 ELSE 0 END
        AS delivery_event_count,

    CASE
        WHEN f.event_type = 'Delivery' AND f.on_time_flag = 1 THEN 1
        ELSE 0
    END AS on_time_delivery_count,

    CASE
        WHEN f.event_type = 'Delivery' AND f.on_time_flag = 0 THEN 1
        ELSE 0
    END AS late_delivery_count,

    CASE
        WHEN f.event_type = 'Delivery' AND f.on_time_flag IS NULL THEN 1
        ELSE 0
    END AS delivery_event_missing_on_time_flag_count,

    CASE
        WHEN f.event_type = 'Delivery' THEN f.detention_minutes
        ELSE NULL
    END AS delivery_detention_minutes

FROM gold.fact_delivery_events AS f
INNER JOIN gold.dim_date AS ds
    ON f.scheduled_date_key = ds.date_key
INNER JOIN gold.dim_date AS da
    ON f.actual_date_key = da.date_key
LEFT JOIN gold.dim_facility AS fac
    ON f.facility_key = fac.facility_key;



-- ============================================================================
-- VIEW VALIDATION
-- Expected:
--   - View row count equals fact_delivery_events row count.
--   - One view row per event_id.
--   - Event counts and delivery KPI indicators reconcile to the fact table.
-- ============================================================================

IF
(
    SELECT COUNT_BIG(*)
    FROM gold.vw_delivery_performance
) <>
(
    SELECT COUNT_BIG(*)
    FROM gold.fact_delivery_events
)
    THROW 51111, 'vw_delivery_performance row count does not match fact_delivery_events.', 1;

IF EXISTS
(
    SELECT event_id
    FROM gold.vw_delivery_performance
    GROUP BY event_id
    HAVING COUNT_BIG(*) <> 1
)
    THROW 51112, 'vw_delivery_performance does not preserve one row per event.', 1;

IF EXISTS
(
    SELECT
        COUNT_BIG(*) AS event_rows,
        SUM(CASE WHEN event_type = 'Delivery' THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END) AS delivery_events,
        SUM(CASE WHEN event_type = 'Delivery' AND on_time_flag = 1 THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END) AS on_time_deliveries,
        SUM(CASE WHEN event_type = 'Delivery' AND on_time_flag = 0 THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END) AS late_deliveries,
        SUM(CASE WHEN event_type = 'Delivery' AND on_time_flag IS NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END) AS missing_delivery_flags
    FROM gold.fact_delivery_events

    EXCEPT

    SELECT
        COUNT_BIG(*) AS event_rows,
        SUM(CONVERT(BIGINT, delivery_event_count)) AS delivery_events,
        SUM(CONVERT(BIGINT, on_time_delivery_count)) AS on_time_deliveries,
        SUM(CONVERT(BIGINT, late_delivery_count)) AS late_deliveries,
        SUM(CONVERT(BIGINT, delivery_event_missing_on_time_flag_count)) AS missing_delivery_flags
    FROM gold.vw_delivery_performance
)
    THROW 51113, 'vw_delivery_performance event or delivery KPI counts do not reconcile to the fact table.', 1;


-- Overall delivery KPI. Denominator includes every Delivery event.
SELECT
    COUNT_BIG(*) AS view_rows,
    COUNT(DISTINCT event_id) AS distinct_events,
    SUM(delivery_event_count) AS delivery_events,
    SUM(on_time_delivery_count) AS on_time_deliveries,
    SUM(late_delivery_count) AS late_deliveries,
    SUM(delivery_event_missing_on_time_flag_count) AS missing_delivery_flags,
    CAST(
        100.0 * SUM(on_time_delivery_count)
        / NULLIF(SUM(delivery_event_count), 0)
        AS DECIMAL(6,2)
    ) AS on_time_delivery_rate_pct,
    AVG(CONVERT(DECIMAL(10,2), delivery_detention_minutes)) AS average_delivery_detention_minutes
FROM gold.vw_delivery_performance;


-- Annual delivery trend. January 2025 is a partial period.
SELECT
    actual_calendar_year,
    COUNT_BIG(*) AS delivery_events,
    SUM(on_time_delivery_count) AS on_time_deliveries,
    CAST(
        100.0 * SUM(on_time_delivery_count)
        / NULLIF(SUM(delivery_event_count), 0)
        AS DECIMAL(6,2)
    ) AS on_time_delivery_rate_pct,
    AVG(CONVERT(DECIMAL(10,2), delivery_detention_minutes)) AS average_delivery_detention_minutes
FROM gold.vw_delivery_performance
WHERE event_type = 'Delivery'
GROUP BY actual_calendar_year
ORDER BY actual_calendar_year;

