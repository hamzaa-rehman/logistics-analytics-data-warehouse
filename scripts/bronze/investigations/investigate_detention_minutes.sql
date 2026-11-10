/*
    Investigation: delivery_events.detention_minutes
    Project: Logistics Analytics Data Warehouse
    Layer: Bronze

    Purpose:
      Explore detention values and investigate whether detention differs
      across schedule-deviation bands, separately for Pickup and Delivery.

    Important data-type note:
      Bronze columns are VARCHAR. MIN() and MAX() applied directly to
      detention_minutes therefore sort text, not numeric values.
      The original exploratory queries are retained as executed, but their
      text-based min/max outputs must not be interpreted as numeric extrema.
      Numeric profiling identified an overall numeric maximum of 239.

    Schedule-deviation sign convention:
      Negative minutes = Early
      Positive minutes = Late
      Zero             = Exactly on schedule

    Investigation findings supplied from the author's SQL Server execution:
      - Average and median detention were relatively stable across
        schedule-deviation bands within each event type.
      - Delivery average detention was approximately 105-107 minutes
        (median 102-106), excluding the very small exactly-on-schedule group.
      - Pickup average detention was approximately 76-77 minutes
        (median 73-75), excluding the very small exactly-on-schedule group.
      - Zero-detention proportions were approximately 11.2%-11.8% for
        Delivery and 14.4%-15.4% for Pickup across the populated bands.
      - No strong observable association between schedule deviation and
        detention was identified in this descriptive analysis.
      - The precise business definition of detention_minutes remains
        unverified.

    Runtime note:
      The author executed the investigation queries in SQL Server and
      supplied the resulting outputs. The committed script has not been
      independently re-executed from GitHub.
*/

USE LogisticsAnalytics;



/* ============================================================
   1. Frequency distribution of the source detention values.
      ORDER BY follows VARCHAR/text ordering.
   ============================================================ */

SELECT
    detention_minutes,
    COUNT(*) AS record_count
FROM bronze.delivery_events
GROUP BY detention_minutes
ORDER BY detention_minutes;


 /* ============================================================
    2. Detention distribution by event type.
       MIN/MAX are retained as originally executed; they sort
       VARCHAR text rather than numeric values.
    ============================================================ */

SELECT
    event_type,
    COUNT(*) AS total_events,
    SUM(CASE WHEN detention_minutes = 0 THEN 1 ELSE 0 END) AS zero_detention,
    SUM(CASE WHEN detention_minutes > 0 THEN 1 ELSE 0 END) AS positive_detention,
    MIN(detention_minutes) AS min_detention,
    MAX(detention_minutes) AS max_detention,
    AVG(CAST(detention_minutes AS DECIMAL(10,2))) AS avg_detention
FROM bronze.delivery_events
GROUP BY event_type
ORDER BY event_type;


 /* ============================================================
    3. Detention by facility and event type.
       MAX is retained as originally executed; it sorts VARCHAR text.
    ============================================================ */

SELECT
    facility_id,
    event_type,
    COUNT(*) AS total_events,
    SUM(CASE WHEN detention_minutes = 0 THEN 1 ELSE 0 END) AS zero_detention,
    AVG(CAST(detention_minutes AS DECIMAL(10,2))) AS avg_detention,
    MAX(detention_minutes) AS max_detention
FROM bronze.delivery_events
GROUP BY
    facility_id,
    event_type
ORDER BY
    facility_id,
    event_type;


 /* ============================================================
    4. Inspect delivery_events column names and data types.
    ============================================================ */

SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bronze'
  AND TABLE_NAME = 'delivery_events'
ORDER BY ORDINAL_POSITION;


 /* ============================================================
    5. Detention by event type and on-time flag.
    ============================================================ */

SELECT
    event_type,
    on_time_flag,
    COUNT(*) AS total_events,
    SUM(CASE WHEN detention_minutes = 0 THEN 1 ELSE 0 END) AS zero_detention,
    SUM(CASE WHEN detention_minutes > 0 THEN 1 ELSE 0 END) AS positive_detention,
    AVG(CAST(detention_minutes AS DECIMAL(10,2))) AS avg_detention
FROM bronze.delivery_events
GROUP BY
    event_type,
    on_time_flag
ORDER BY
    event_type,
    on_time_flag;


 /* ============================================================
    6. Inspect the first 20 delivery event records.
    ============================================================ */

SELECT TOP 20
    event_id,
    event_type,
    scheduled_datetime,
    actual_datetime,
    on_time_flag,
    detention_minutes
FROM bronze.delivery_events
ORDER BY event_id;


 /* ============================================================
    7. Compare detention with schedule deviation.

       Schedule deviation is calculated in fractional minutes:
         actual_datetime - scheduled_datetime

       DATEDIFF_BIG(SECOND) avoids the minute-boundary counting
       behavior of DATEDIFF(MINUTE).

       TRY_CONVERT is used because Bronze stores these columns
       as VARCHAR. This query assumes converted values are valid;
       previous profiling/validation found no invalid detention
       values or timestamp conversions for this dataset.
    ============================================================ */

WITH ConvertedEvents AS
(
    SELECT
        event_type,
        TRY_CONVERT(DECIMAL(10, 6), detention_minutes) AS detention_minutes,
        TRY_CONVERT(DATETIME2, actual_datetime) AS actual_datetime,
        TRY_CONVERT(DATETIME2, scheduled_datetime) AS scheduled_datetime
    FROM bronze.delivery_events
),

ScheduleDeviation AS
(
    SELECT
        event_type,
        detention_minutes,
        DATEDIFF_BIG(
            SECOND,
            scheduled_datetime,
            actual_datetime
        ) / 60.0 AS schedule_deviation_minutes
    FROM ConvertedEvents
),

ClassifiedEvents AS
(
    SELECT
        event_type,
        detention_minutes,
        schedule_deviation_minutes,

        CASE
            WHEN schedule_deviation_minutes > 120
                THEN 'More than 120 min late'
            WHEN schedule_deviation_minutes > 60
                THEN '61-120 min late'
            WHEN schedule_deviation_minutes > 0
                THEN '1-60 min late'
            WHEN schedule_deviation_minutes = 0
                THEN 'Exactly on schedule'
            WHEN schedule_deviation_minutes >= -60
                THEN '1-60 min early'
            WHEN schedule_deviation_minutes >= -120
                THEN '61-120 min early'
            WHEN schedule_deviation_minutes < -120
                THEN 'More than 120 min early'
        END AS schedule_deviation_band

    FROM ScheduleDeviation
),

/* Calculate the median separately for each event type and band.
   PERCENTILE_CONT is a window function, so DISTINCT reduces the
   repeated partition-level median to one row per group. */
MedianByGroup AS
(
    SELECT DISTINCT
        event_type,
        schedule_deviation_band,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY detention_minutes)
            OVER (
                PARTITION BY
                    event_type,
                    schedule_deviation_band
            ) AS median_detention_minutes

    FROM ClassifiedEvents
    WHERE detention_minutes IS NOT NULL
),

/* Summarize event counts and detention averages for each group. */
GroupSummary AS
(
    SELECT
        event_type,
        schedule_deviation_band,
        COUNT(*) AS total_events,

        SUM(
            CASE
                WHEN detention_minutes = 0 THEN 1
                ELSE 0
            END
        ) AS zero_detention_events,

        SUM(
            CASE
                WHEN detention_minutes > 0 THEN 1
                ELSE 0
            END
        ) AS positive_detention_events,

        AVG(detention_minutes) AS average_detention_minutes

    FROM ClassifiedEvents
    GROUP BY
        event_type,
        schedule_deviation_band
)

SELECT
    G.event_type,
    G.schedule_deviation_band,
    G.total_events,
    G.zero_detention_events,
    G.positive_detention_events,
    G.average_detention_minutes,
    M.median_detention_minutes

FROM GroupSummary AS G

INNER JOIN MedianByGroup AS M
    ON G.event_type = M.event_type
    AND G.schedule_deviation_band = M.schedule_deviation_band

ORDER BY
    G.event_type,
    CASE G.schedule_deviation_band
        WHEN 'More than 120 min early' THEN 1
        WHEN '61-120 min early'        THEN 2
        WHEN '1-60 min early'          THEN 3
        WHEN 'Exactly on schedule'     THEN 4
        WHEN '1-60 min late'           THEN 5
        WHEN '61-120 min late'         THEN 6
        WHEN 'More than 120 min late'  THEN 7
    END;
