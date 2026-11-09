/*
    Investigation: delivery_events.on_time_flag
    Project: Logistics Analytics Data Warehouse
    Layer: Bronze

    Purpose:
      Investigate how on_time_flag relates to scheduled_datetime
      and actual_datetime.

    Source:
      bronze.delivery_events

    Finding validated against the user's SQL Server results:
      All 170,820 rows match a +/- 120-minute tolerance rule
      when the timestamp difference is evaluated at microsecond precision.

    Important:
      This script is a reproducible investigation record. It has not
      been independently executed against the user's SQL Server as part
      of this GitHub update.
*/

USE LogisticsAnalytics;


/* 1. Inspect timestamp conversion and flag values. */
WITH EventTiming AS
(
    SELECT
        event_id,
        on_time_flag,
        TRY_CONVERT(DATETIME2(6), scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2(6), actual_datetime) AS actual_time
    FROM bronze.delivery_events
)
SELECT
    COUNT(*) AS TotalEvents,
    SUM(CASE WHEN scheduled_time IS NULL THEN 1 ELSE 0 END) AS InvalidScheduledTimes,
    SUM(CASE WHEN actual_time IS NULL THEN 1 ELSE 0 END) AS InvalidActualTimes,
    SUM(CASE
        WHEN on_time_flag NOT IN ('True', 'False') OR on_time_flag IS NULL
        THEN 1 ELSE 0
    END) AS InvalidOnTimeFlags
FROM EventTiming;


/* 2. Compare the source flag with a strict actual <= scheduled rule.
      This is an initial diagnostic comparison, not the final rule. */
WITH EventTiming AS
(
    SELECT
        event_id,
        on_time_flag,
        TRY_CONVERT(DATETIME2(6), scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2(6), actual_datetime) AS actual_time
    FROM bronze.delivery_events
)
SELECT
    COUNT(*) AS TotalEvents,
    SUM(CASE WHEN actual_time <= scheduled_time THEN 1 ELSE 0 END)
        AS ActualOnOrBeforeSchedule,
    SUM(CASE WHEN on_time_flag = 'True' THEN 1 ELSE 0 END)
        AS FlaggedOnTime,
    SUM(CASE
        WHEN (on_time_flag = 'True' AND actual_time > scheduled_time)
          OR (on_time_flag = 'False' AND actual_time <= scheduled_time)
        THEN 1 ELSE 0
    END) AS MismatchesAgainstStrictScheduleRule
FROM EventTiming;


/* 3. Break down the two mismatch directions. */
WITH EventTiming AS
(
    SELECT
        on_time_flag,
        TRY_CONVERT(DATETIME2(6), scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2(6), actual_datetime) AS actual_time
    FROM bronze.delivery_events
)
SELECT
    SUM(CASE
        WHEN on_time_flag = 'True' AND actual_time > scheduled_time
        THEN 1 ELSE 0
    END) AS FlaggedTrueButActuallyLate,
    SUM(CASE
        WHEN on_time_flag = 'False' AND actual_time <= scheduled_time
        THEN 1 ELSE 0
    END) AS FlaggedFalseButActuallyOnOrBeforeSchedule
FROM EventTiming;


/* 4. Measure lateness for events marked True but occurring after schedule. */
WITH EventTiming AS
(
    SELECT
        on_time_flag,
        TRY_CONVERT(DATETIME2(6), scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2(6), actual_datetime) AS actual_time
    FROM bronze.delivery_events
)
SELECT
    COUNT(*) AS EventCount,
    MIN(DATEDIFF_BIG(MICROSECOND, scheduled_time, actual_time) / 60000000.0)
        AS MinimumLateMinutes,
    MAX(DATEDIFF_BIG(MICROSECOND, scheduled_time, actual_time) / 60000000.0)
        AS MaximumLateMinutes,
    AVG(DATEDIFF_BIG(MICROSECOND, scheduled_time, actual_time) / 60000000.0)
        AS AverageLateMinutes
FROM EventTiming
WHERE on_time_flag = 'True'
  AND actual_time > scheduled_time;


/* 5. Measure earliness for events marked False but occurring before schedule. */
WITH EventTiming AS
(
    SELECT
        on_time_flag,
        TRY_CONVERT(DATETIME2(6), scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2(6), actual_datetime) AS actual_time
    FROM bronze.delivery_events
)
SELECT
    COUNT(*) AS EventCount,
    MIN(DATEDIFF_BIG(MICROSECOND, actual_time, scheduled_time) / 60000000.0)
        AS MinimumMinutesEarly,
    MAX(DATEDIFF_BIG(MICROSECOND, actual_time, scheduled_time) / 60000000.0)
        AS MaximumMinutesEarly,
    AVG(DATEDIFF_BIG(MICROSECOND, actual_time, scheduled_time) / 60000000.0)
        AS AverageMinutesEarly
FROM EventTiming
WHERE on_time_flag = 'False'
  AND actual_time <= scheduled_time;


/* 6. Inspect flag distribution across signed time-difference ranges.
      Positive = actual event occurred after schedule (late).
      Negative = actual event occurred before schedule (early).
      The CASE ranges are diagnostic buckets, not a business definition. */
WITH EventTiming AS
(
    SELECT
        on_time_flag,
        DATEDIFF_BIG(
            MICROSECOND,
            TRY_CONVERT(DATETIME2(6), scheduled_datetime),
            TRY_CONVERT(DATETIME2(6), actual_datetime)
        ) / 60000000.0 AS DifferenceMinutes
    FROM bronze.delivery_events
),
BucketedEvents AS
(
    SELECT
        on_time_flag,
        CASE
            WHEN DifferenceMinutes < -180 THEN 'Earlier than 180 min'
            WHEN DifferenceMinutes < -120 THEN '120 to 180 min early'
            WHEN DifferenceMinutes < 0 THEN '0 to 120 min early'
            WHEN DifferenceMinutes = 0 THEN 'Exactly on schedule'
            WHEN DifferenceMinutes <= 120 THEN '0 to 120 min late'
            WHEN DifferenceMinutes <= 180 THEN '120 to 180 min late'
            ELSE 'Later than 180 min'
        END AS TimeDifferenceRange
    FROM EventTiming
)
SELECT
    TimeDifferenceRange,
    COUNT(*) AS TotalEvents,
    SUM(CASE WHEN on_time_flag = 'True' THEN 1 ELSE 0 END) AS TrueFlags,
    SUM(CASE WHEN on_time_flag = 'False' THEN 1 ELSE 0 END) AS FalseFlags
FROM BucketedEvents
GROUP BY TimeDifferenceRange
ORDER BY TimeDifferenceRange;


/* 7. Inspect events inside the apparent +/- 120-minute window
      that are nevertheless flagged False. */
WITH EventTiming AS
(
    SELECT
        event_id,
        event_type,
        scheduled_datetime,
        actual_datetime,
        on_time_flag,
        DATEDIFF_BIG(
            MICROSECOND,
            TRY_CONVERT(DATETIME2(6), scheduled_datetime),
            TRY_CONVERT(DATETIME2(6), actual_datetime)
        ) AS DifferenceMicroseconds
    FROM bronze.delivery_events
)
SELECT
    event_id,
    event_type,
    scheduled_datetime,
    actual_datetime,
    on_time_flag,
    DifferenceMicroseconds / 60000000.0 AS DifferenceMinutes
FROM EventTiming
WHERE on_time_flag = 'False'
  AND DifferenceMicroseconds BETWEEN -7200000000 AND 7200000000
ORDER BY event_id;


/* 8. Final validation at microsecond precision.
      The hypothesized rule is inclusive: -120 to +120 minutes.
      7,200,000,000 microseconds = 120 minutes. */
WITH EventTiming AS
(
    SELECT
        on_time_flag,
        DATEDIFF_BIG(
            MICROSECOND,
            TRY_CONVERT(DATETIME2(6), scheduled_datetime),
            TRY_CONVERT(DATETIME2(6), actual_datetime)
        ) AS DifferenceMicroseconds
    FROM bronze.delivery_events
),
RuleCheck AS
(
    SELECT
        on_time_flag,
        CASE
            WHEN DifferenceMicroseconds BETWEEN -7200000000 AND 7200000000
            THEN 'True'
            ELSE 'False'
        END AS ExpectedFlag
    FROM EventTiming
)
SELECT
    COUNT(*) AS TotalEvents,
    SUM(CASE WHEN on_time_flag = ExpectedFlag THEN 1 ELSE 0 END)
        AS MatchingRows,
    SUM(CASE WHEN on_time_flag <> ExpectedFlag THEN 1 ELSE 0 END)
        AS MismatchingRows
FROM RuleCheck;

