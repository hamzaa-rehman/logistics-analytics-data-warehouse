/*
    Investigation: delivery_events.on_time_flag
    Project: Logistics Analytics Data Warehouse
    Layer: Bronze

    These are the author's executed investigation queries, organized
    into readable sections with explanatory comments. Query logic is
    retained.

    SQL Server results supplied by the author for the final validation:
      TotalEvents = 170,820
      MatchingRows = 170,820
      MismatchingRows = 0

    Candidate rule validated against the supplied results:
      True  = actual timestamp is within the inclusive +/- 120-minute window.
      False = actual timestamp is outside that window.

    The committed script has not itself been independently re-executed.
*/

USE LogisticsAnalytics;


/* 1. Initial comparison with a strict actual <= scheduled rule. */
WITH EventTiming AS
(
    SELECT
        event_id,
        on_time_flag,
        TRY_CONVERT(DATETIME2, scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2, actual_datetime) AS actual_time
    FROM bronze.delivery_events
)
SELECT
    COUNT(*) AS total_events,
    SUM(CASE WHEN actual_time <= scheduled_time THEN 1 ELSE 0 END)
        AS actual_on_or_before_schedule,
    SUM(CASE WHEN on_time_flag = 'True' THEN 1 ELSE 0 END)
        AS flagged_on_time,
    SUM(CASE
        WHEN (on_time_flag = 'True' AND actual_time > scheduled_time)
          OR (on_time_flag = 'False' AND actual_time <= scheduled_time)
        THEN 1 ELSE 0
    END) AS flag_mismatches
FROM EventTiming;


/* 2. Check timestamp conversions and source flag values. */
WITH EventTiming AS
(
    SELECT
        event_id,
        on_time_flag,
        TRY_CONVERT(DATETIME2, scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2, actual_datetime) AS actual_time
    FROM bronze.delivery_events
)
SELECT
    COUNT(*) AS TotalEvents,
    SUM(CASE WHEN scheduled_time IS NULL THEN 1 ELSE 0 END)
        AS InvalidScheduledTimes,
    SUM(CASE WHEN actual_time IS NULL THEN 1 ELSE 0 END)
        AS InvalidActualTimes,
    SUM(CASE
        WHEN on_time_flag NOT IN ('True', 'False')
             OR on_time_flag IS NULL THEN 1
        ELSE 0
    END) AS InvalidOnTimeFlags
FROM EventTiming;


/* 3. Break down the two mismatch directions. */
WITH EventTiming AS
(
    SELECT
        event_id,
        on_time_flag,
        TRY_CONVERT(DATETIME2, scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2, actual_datetime) AS actual_time
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
    END) AS FlaggedFalseButActuallyOnTime
FROM EventTiming;


/* 4. Measure lateness for events marked True but occurring after schedule. */
WITH EventTiming AS
(
    SELECT
        event_id,
        on_time_flag,
        TRY_CONVERT(DATETIME2, scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2, actual_datetime) AS actual_time
    FROM bronze.delivery_events
)
SELECT
    COUNT(*) AS EventCount,
    MIN(DATEDIFF(SECOND, scheduled_time, actual_time) / 60.0)
        AS MinimumLateMinutes,
    MAX(DATEDIFF(SECOND, scheduled_time, actual_time) / 60.0)
        AS MaximumLateMinutes,
    AVG(DATEDIFF(SECOND, scheduled_time, actual_time) / 60.0)
        AS AverageLateMinutes
FROM EventTiming
WHERE on_time_flag = 'True'
  AND actual_time > scheduled_time;


/* 5. Group late events marked True into delay ranges. */
WITH EventTiming AS
(
    SELECT
        event_id,
        on_time_flag,
        TRY_CONVERT(DATETIME2, scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2, actual_datetime) AS actual_time
    FROM bronze.delivery_events
),
LateEvents AS
(
    SELECT
        DATEDIFF(SECOND, scheduled_time, actual_time) / 60.0
            AS LateMinutes
    FROM EventTiming
    WHERE on_time_flag = 'True'
      AND actual_time > scheduled_time
)
SELECT
    CASE
        WHEN LateMinutes <= 15 THEN '01. 0-15 minutes'
        WHEN LateMinutes <= 30 THEN '02. 16-30 minutes'
        WHEN LateMinutes <= 60 THEN '03. 31-60 minutes'
        WHEN LateMinutes <= 90 THEN '04. 61-90 minutes'
        WHEN LateMinutes <= 120 THEN '05. 91-120 minutes'
        ELSE '06. Over 120 minutes'
    END AS DelayRange,
    COUNT(*) AS EventCount
FROM LateEvents
GROUP BY
    CASE
        WHEN LateMinutes <= 15 THEN '01. 0-15 minutes'
        WHEN LateMinutes <= 30 THEN '02. 16-30 minutes'
        WHEN LateMinutes <= 60 THEN '03. 31-60 minutes'
        WHEN LateMinutes <= 90 THEN '04. 61-90 minutes'
        WHEN LateMinutes <= 120 THEN '05. 91-120 minutes'
        ELSE '06. Over 120 minutes'
    END
ORDER BY DelayRange;


/* 6. Measure earliness for events marked False but occurring early. */
WITH EventTiming AS
(
    SELECT
        event_id,
        on_time_flag,
        TRY_CONVERT(DATETIME2, scheduled_datetime) AS scheduled_time,
        TRY_CONVERT(DATETIME2, actual_datetime) AS actual_time
    FROM bronze.delivery_events
)
SELECT
    COUNT(*) AS EventCount,
    MIN(DATEDIFF(SECOND, actual_time, scheduled_time) / 60.0)
        AS MinimumMinutesEarly,
    MAX(DATEDIFF(SECOND, actual_time, scheduled_time) / 60.0)
        AS MaximumMinutesEarly,
    AVG(DATEDIFF(SECOND, actual_time, scheduled_time) / 60.0)
        AS AverageMinutesEarly
FROM EventTiming
WHERE on_time_flag = 'False'
  AND actual_time <= scheduled_time;


/* 7. Compare True/False flags across signed time-difference ranges.
      Negative = early; zero = exactly on schedule; positive = late. */
WITH EventTiming AS
(
    SELECT
        on_time_flag,
        DATEDIFF(
            SECOND,
            TRY_CONVERT(DATETIME2, scheduled_datetime),
            TRY_CONVERT(DATETIME2, actual_datetime)
        ) / 60.0 AS TimeDifferenceMinutes
    FROM bronze.delivery_events
)
SELECT
    CASE
        WHEN TimeDifferenceMinutes < -180 THEN 'Earlier than 180 min'
        WHEN TimeDifferenceMinutes < -120 THEN '120 to 180 min early'
        WHEN TimeDifferenceMinutes < 0 THEN '0 to 120 min early'
        WHEN TimeDifferenceMinutes = 0 THEN 'Exactly on schedule'
        WHEN TimeDifferenceMinutes <= 120 THEN '0 to 120 min late'
        WHEN TimeDifferenceMinutes <= 180 THEN '120 to 180 min late'
        ELSE 'Later than 180 min'
    END AS TimeDifferenceRange,
    COUNT(*) AS TotalEvents,
    SUM(CASE WHEN on_time_flag = 'True' THEN 1 ELSE 0 END) AS TrueFlags,
    SUM(CASE WHEN on_time_flag = 'False' THEN 1 ELSE 0 END) AS FalseFlags
FROM EventTiming
GROUP BY
    CASE
        WHEN TimeDifferenceMinutes < -180 THEN 'Earlier than 180 min'
        WHEN TimeDifferenceMinutes < -120 THEN '120 to 180 min early'
        WHEN TimeDifferenceMinutes < 0 THEN '0 to 120 min early'
        WHEN TimeDifferenceMinutes = 0 THEN 'Exactly on schedule'
        WHEN TimeDifferenceMinutes <= 120 THEN '0 to 120 min late'
        WHEN TimeDifferenceMinutes <= 180 THEN '120 to 180 min late'
        ELSE 'Later than 180 min'
    END
ORDER BY TimeDifferenceRange;


/* 8. Inspect events inside the apparent +/- 120-minute window
      that were nevertheless marked False. This uses DATEDIFF(SECOND),
      so the final check below is needed for sub-second precision. */
WITH EventTiming AS
(
    SELECT
        event_id,
        event_type,
        scheduled_datetime,
        actual_datetime,
        on_time_flag,
        DATEDIFF(
            SECOND,
            TRY_CONVERT(DATETIME2, scheduled_datetime),
            TRY_CONVERT(DATETIME2, actual_datetime)
        ) / 60.0 AS TimeDifferenceMinutes
    FROM bronze.delivery_events
)
SELECT *
FROM EventTiming
WHERE
    (
        TimeDifferenceMinutes BETWEEN -120 AND 120
        AND on_time_flag = 'False'
    );


/* 9. Final full-table validation at microsecond precision.
      7,200,000,000 microseconds = 120 minutes; BETWEEN is inclusive. */
WITH EventTiming AS
(
    SELECT
        event_id,
        on_time_flag,
        DATEDIFF_BIG(
            MICROSECOND,
            TRY_CONVERT(DATETIME2(6), scheduled_datetime),
            TRY_CONVERT(DATETIME2(6), actual_datetime)
        ) AS DifferenceMicroseconds
    FROM bronze.delivery_events
)
SELECT
    COUNT(*) AS TotalEvents,
    SUM(CASE
        WHEN on_time_flag = 'True'
         AND DifferenceMicroseconds BETWEEN -7200000000 AND 7200000000
        THEN 1
        WHEN on_time_flag = 'False'
         AND DifferenceMicroseconds NOT BETWEEN -7200000000 AND 7200000000
        THEN 1
        ELSE 0
    END) AS MatchingRows,
    SUM(CASE
        WHEN (on_time_flag = 'True'
              AND DifferenceMicroseconds NOT BETWEEN -7200000000 AND 7200000000)
          OR (on_time_flag = 'False'
              AND DifferenceMicroseconds BETWEEN -7200000000 AND 7200000000)
        THEN 1
        ELSE 0
    END) AS MismatchingRows
FROM EventTiming;

