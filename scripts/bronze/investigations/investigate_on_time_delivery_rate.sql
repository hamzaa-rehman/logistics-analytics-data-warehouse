/*
    Investigation: driver_monthly_metrics.on_time_delivery_rate
    Project: Logistics Analytics Data Warehouse
    Layer: Bronze

    Objective
    ---------
    Investigate the single zero value in
    bronze.driver_monthly_metrics.on_time_delivery_rate and reconcile
    the monthly source metric against the underlying delivery events.

    Calculation tested
    ------------------
    On-time delivery rate = on-time Delivery events / total Delivery events

    Month assignment tested
    -----------------------
    The reporting month is derived from bronze.trips.dispatch_date.

    Important
    ---------
    Bronze columns are VARCHAR. TRY_CONVERT is used for analysis only;
    this script does not modify Bronze data.

    Results supplied by the author from SQL Server execution:
      - DRV00074, September 2024: 10 Delivery events, 0 on time.
      - Full dataset: 4,464 monthly records.
      - Standard ROUND(..., 3) comparison: 4,383 matches, 81 mismatches.
      - Truncation comparison across all records: 2,741 matches,
        1,723 mismatches, 0 records without delivery events.
      - Among the 81 standard-rounding mismatches, all 81 matched the
        truncated rate; no other differences remained.

    Precision limitation
    --------------------
    The observed results do not establish the exact source-generation
    rounding implementation. Truncation reproduces the 81 exceptional
    stored values, but the original source code/business rule was not
    available for inspection. Do not assume a universal truncation rule
    in Silver without confirmation.

    Execution note
    --------------
    The queries below consolidate the investigation logic executed by
    the author. The consolidated GitHub file has not been independently
    re-executed end-to-end after formatting.
*/

USE LogisticsAnalytics;


/*=====================================================================
  1. Retrieve the monthly source record containing the zero rate.
=====================================================================*/

SELECT
    driver_id,
    [month],
    trips_completed,
    on_time_delivery_rate,
    total_miles,
    total_revenue,
    total_fuel_gallons,
    average_mpg,
    average_idle_hours
FROM bronze.driver_monthly_metrics
WHERE driver_id = 'DRV00074'
  AND TRY_CONVERT(DATE, [month]) = '2024-09-01';


/*=====================================================================
  2. Inspect Delivery and Pickup event flags for the driver's
     September 2024 dispatches.

     This is the aggregate query used to confirm the event counts.
     Only Delivery events are used in the on-time delivery rate.
=====================================================================*/

SELECT
    de.event_type,
    COUNT(*),
    SUM(CASE WHEN de.on_time_flag = 'False' THEN 1 ELSE 0 END) AS falseflag,
    SUM(CASE WHEN de.on_time_flag = 'True' THEN 1 ELSE 0 END) AS TRUEFLAG
FROM bronze.trips AS t
LEFT JOIN bronze.delivery_events AS de
    ON t.trip_id = de.trip_id
WHERE t.driver_id = 'DRV00074'
  AND TRY_CONVERT(DATE, t.dispatch_date) >= '2024-09-01'
  AND TRY_CONVERT(DATE, t.dispatch_date) < '2024-10-01'
GROUP BY
    de.event_type;


/*=====================================================================
  3. Recalculate the monthly on-time delivery rate for every driver
     and dispatch month. Return the row-level comparison using
     standard SQL Server rounding to three decimal places.
=====================================================================*/

WITH DeliverySummary AS
(
    SELECT
        t.driver_id,
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(DATE, t.dispatch_date)),
            MONTH(TRY_CONVERT(DATE, t.dispatch_date)),
            1
        ) AS DeliveryMonth,
        COUNT(*) AS TotalDeliveries,
        SUM(
            CASE
                WHEN de.on_time_flag = 'True' THEN 1
                ELSE 0
            END
        ) AS OnTimeDeliveries
    FROM bronze.trips AS t
    INNER JOIN bronze.delivery_events AS de
        ON t.trip_id = de.trip_id
    WHERE de.event_type = 'Delivery'
      AND TRY_CONVERT(DATE, t.dispatch_date) IS NOT NULL
    GROUP BY
        t.driver_id,
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(DATE, t.dispatch_date)),
            MONTH(TRY_CONVERT(DATE, t.dispatch_date)),
            1
        )
),
CalculatedRates AS
(
    SELECT
        driver_id,
        DeliveryMonth,
        TotalDeliveries,
        OnTimeDeliveries,
        CAST(OnTimeDeliveries AS DECIMAL(18,6))
            / NULLIF(TotalDeliveries, 0) AS CalculatedRate
    FROM DeliverySummary
)
SELECT
    m.driver_id,
    TRY_CONVERT(DATE, m.month) AS MetricMonth,
    c.TotalDeliveries,
    c.OnTimeDeliveries,
    c.CalculatedRate,
    TRY_CONVERT(DECIMAL(18,4), m.on_time_delivery_rate) AS SourceRate,
    CASE
        WHEN c.driver_id IS NULL
            THEN 'NO DELIVERY EVENTS'
        WHEN ROUND(c.CalculatedRate, 3) =
             TRY_CONVERT(DECIMAL(18,4), m.on_time_delivery_rate)
            THEN 'MATCH'
        ELSE 'MISMATCH'
    END AS ValidationStatus
FROM bronze.driver_monthly_metrics AS m
LEFT JOIN CalculatedRates AS c
    ON m.driver_id = c.driver_id
   AND TRY_CONVERT(DATE, m.month) = c.DeliveryMonth
ORDER BY
    m.driver_id,
    MetricMonth;


/*=====================================================================
  4. Summarize the standard-rounding validation across all monthly
     source records. This retains all source rows through LEFT JOIN.
=====================================================================*/

WITH DeliverySummary AS
(
    SELECT
        t.driver_id,
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(DATE, t.dispatch_date)),
            MONTH(TRY_CONVERT(DATE, t.dispatch_date)),
            1
        ) AS DeliveryMonth,
        COUNT(*) AS TotalDeliveries,
        SUM(
            CASE
                WHEN de.on_time_flag = 'True' THEN 1
                ELSE 0
            END
        ) AS OnTimeDeliveries
    FROM bronze.trips AS t
    INNER JOIN bronze.delivery_events AS de
        ON t.trip_id = de.trip_id
    WHERE de.event_type = 'Delivery'
      AND TRY_CONVERT(DATE, t.dispatch_date) IS NOT NULL
    GROUP BY
        t.driver_id,
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(DATE, t.dispatch_date)),
            MONTH(TRY_CONVERT(DATE, t.dispatch_date)),
            1
        )
),
CalculatedRates AS
(
    SELECT
        driver_id,
        DeliveryMonth,
        TotalDeliveries,
        OnTimeDeliveries,
        CAST(OnTimeDeliveries AS DECIMAL(18,6))
            / NULLIF(TotalDeliveries, 0) AS CalculatedRate
    FROM DeliverySummary
)
SELECT
    CASE
        WHEN c.driver_id IS NULL
            THEN 'NO DELIVERY EVENTS'
        WHEN ROUND(c.CalculatedRate, 3) =
             TRY_CONVERT(DECIMAL(18,4), m.on_time_delivery_rate)
            THEN 'MATCH'
        ELSE 'MISMATCH'
    END AS ValidationStatus,
    COUNT(*) AS RecordCount
FROM bronze.driver_monthly_metrics AS m
LEFT JOIN CalculatedRates AS c
    ON m.driver_id = c.driver_id
   AND TRY_CONVERT(DATE, m.month) = c.DeliveryMonth
GROUP BY
    CASE
        WHEN c.driver_id IS NULL
            THEN 'NO DELIVERY EVENTS'
        WHEN ROUND(c.CalculatedRate, 3) =
             TRY_CONVERT(DECIMAL(18,4), m.on_time_delivery_rate)
            THEN 'MATCH'
        ELSE 'MISMATCH'
    END;


/*=====================================================================
  5. Inspect records that did not match after standard rounding.
     RateDifference is the unrounded calculated rate minus source rate.
=====================================================================*/

WITH DeliverySummary AS
(
    SELECT
        t.driver_id,
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(DATE, t.dispatch_date)),
            MONTH(TRY_CONVERT(DATE, t.dispatch_date)),
            1
        ) AS DeliveryMonth,
        COUNT(*) AS TotalDeliveries,
        SUM(
            CASE
                WHEN de.on_time_flag = 'True' THEN 1
                ELSE 0
            END
        ) AS OnTimeDeliveries
    FROM bronze.trips AS t
    INNER JOIN bronze.delivery_events AS de
        ON t.trip_id = de.trip_id
    WHERE de.event_type = 'Delivery'
      AND TRY_CONVERT(DATE, t.dispatch_date) IS NOT NULL
    GROUP BY
        t.driver_id,
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(DATE, t.dispatch_date)),
            MONTH(TRY_CONVERT(DATE, t.dispatch_date)),
            1
        )
),
CalculatedRates AS
(
    SELECT
        driver_id,
        DeliveryMonth,
        TotalDeliveries,
        OnTimeDeliveries,
        CAST(OnTimeDeliveries AS DECIMAL(18,6))
            / NULLIF(TotalDeliveries, 0) AS CalculatedRate
    FROM DeliverySummary
)
SELECT
    m.driver_id,
    TRY_CONVERT(DATE, m.month) AS MetricMonth,
    c.TotalDeliveries,
    c.OnTimeDeliveries,
    c.CalculatedRate,
    TRY_CONVERT(DECIMAL(18,4), m.on_time_delivery_rate) AS SourceRate,
    ROUND(
        c.CalculatedRate -
        TRY_CONVERT(DECIMAL(18,4), m.on_time_delivery_rate),
        4
    ) AS RateDifference
FROM bronze.driver_monthly_metrics AS m
INNER JOIN CalculatedRates AS c
    ON m.driver_id = c.driver_id
   AND TRY_CONVERT(DATE, m.month) = c.DeliveryMonth
WHERE ROUND(c.CalculatedRate, 3) <>
      TRY_CONVERT(DECIMAL(18,4), m.on_time_delivery_rate)
ORDER BY
    ABS(
        c.CalculatedRate -
        TRY_CONVERT(DECIMAL(18,4), m.on_time_delivery_rate)
    ) DESC;


/*=====================================================================
  6. Inspect the precision-boundary examples observed in the
     mismatch results. Compare standard rounding with truncation.
=====================================================================*/

SELECT
    CAST(5.0 / 16 AS DECIMAL(18,6)) AS ActualRate,
    ROUND(5.0 / 16, 3) AS RoundedRate,
    CAST(
        FLOOR((5.0 / 16) * 1000) / 1000.0
        AS DECIMAL(18,3)
    ) AS TruncatedRate,
    CAST(9.0 / 16 AS DECIMAL(18,6)) AS SecondActualRate,
    ROUND(9.0 / 16, 3) AS SecondRoundedRate,
    CAST(
        FLOOR((9.0 / 16) * 1000) / 1000.0
        AS DECIMAL(18,3)
    ) AS SecondTruncatedRate;


/*=====================================================================
  7. Test truncation against the complete dataset.

     This is a diagnostic comparison only. It is not the final
     classification of the 81 standard-rounding mismatches.
=====================================================================*/

WITH DeliverySummary AS
(
    SELECT
        t.driver_id,
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(DATE, t.dispatch_date)),
            MONTH(TRY_CONVERT(DATE, t.dispatch_date)),
            1
        ) AS DeliveryMonth,
        COUNT(*) AS TotalDeliveries,
        SUM(
            CASE
                WHEN de.on_time_flag = 'True' THEN 1
                ELSE 0
            END
        ) AS OnTimeDeliveries
    FROM bronze.trips AS t
    INNER JOIN bronze.delivery_events AS de
        ON t.trip_id = de.trip_id
    WHERE de.event_type = 'Delivery'
      AND TRY_CONVERT(DATE, t.dispatch_date) IS NOT NULL
    GROUP BY
        t.driver_id,
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(DATE, t.dispatch_date)),
            MONTH(TRY_CONVERT(DATE, t.dispatch_date)),
            1
        )
),
CalculatedRates AS
(
    SELECT
        driver_id,
        DeliveryMonth,
        TotalDeliveries,
        OnTimeDeliveries,
        CAST(OnTimeDeliveries AS DECIMAL(18,6))
            / NULLIF(TotalDeliveries, 0) AS CalculatedRate,
        CAST(
            FLOOR(
                (
                    CAST(OnTimeDeliveries AS DECIMAL(18,6))
                    / NULLIF(TotalDeliveries, 0)
                ) * 1000
            ) / 1000.0
            AS DECIMAL(18,3)
        ) AS TruncatedRate
    FROM DeliverySummary
)
SELECT
    COUNT(*) AS TotalMonthlyRecords,
    SUM(
        CASE
            WHEN c.TruncatedRate =
                 TRY_CONVERT(DECIMAL(18,3), m.on_time_delivery_rate)
            THEN 1
            ELSE 0
        END
    ) AS MatchingRecords,
    SUM(
        CASE
            WHEN c.driver_id IS NULL
            THEN 1
            ELSE 0
        END
    ) AS NoDeliveryEvents,
    SUM(
        CASE
            WHEN c.driver_id IS NOT NULL
             AND c.TruncatedRate <>
                 TRY_CONVERT(DECIMAL(18,3), m.on_time_delivery_rate)
            THEN 1
            ELSE 0
        END
    ) AS MismatchingRecords
FROM bronze.driver_monthly_metrics AS m
LEFT JOIN CalculatedRates AS c
    ON m.driver_id = c.driver_id
   AND TRY_CONVERT(DATE, m.month) = c.DeliveryMonth;


/*=====================================================================
  8. Classify the 81 records that failed standard rounding:
     determine whether their source values match the truncated rate
     or represent another difference.
=====================================================================*/

WITH DeliverySummary AS
(
    SELECT
        t.driver_id,
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(DATE, t.dispatch_date)),
            MONTH(TRY_CONVERT(DATE, t.dispatch_date)),
            1
        ) AS DeliveryMonth,
        COUNT(*) AS TotalDeliveries,
        SUM(
            CASE
                WHEN de.on_time_flag = 'True' THEN 1
                ELSE 0
            END
        ) AS OnTimeDeliveries
    FROM bronze.trips AS t
    INNER JOIN bronze.delivery_events AS de
        ON t.trip_id = de.trip_id
    WHERE de.event_type = 'Delivery'
      AND TRY_CONVERT(DATE, t.dispatch_date) IS NOT NULL
    GROUP BY
        t.driver_id,
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(DATE, t.dispatch_date)),
            MONTH(TRY_CONVERT(DATE, t.dispatch_date)),
            1
        )
),
CalculatedRates AS
(
    SELECT
        driver_id,
        DeliveryMonth,
        TotalDeliveries,
        OnTimeDeliveries,
        CAST(OnTimeDeliveries AS DECIMAL(18,6))
            / NULLIF(TotalDeliveries, 0) AS CalculatedRate,
        CAST(
            FLOOR(
                (
                    CAST(OnTimeDeliveries AS DECIMAL(18,6))
                    / NULLIF(TotalDeliveries, 0)
                ) * 1000
            ) / 1000.0
            AS DECIMAL(18,3)
        ) AS TruncatedRate
    FROM DeliverySummary
)
SELECT
    CASE
        WHEN c.TruncatedRate =
             TRY_CONVERT(DECIMAL(18,3), m.on_time_delivery_rate)
            THEN 'TRUNCATION MATCH'
        ELSE 'OTHER DIFFERENCE'
    END AS DifferenceType,
    COUNT(*) AS RecordCount
FROM bronze.driver_monthly_metrics AS m
INNER JOIN CalculatedRates AS c
    ON m.driver_id = c.driver_id
   AND TRY_CONVERT(DATE, m.month) = c.DeliveryMonth
WHERE ROUND(c.CalculatedRate, 3) <>
      TRY_CONVERT(DECIMAL(18,3), m.on_time_delivery_rate)
GROUP BY
    CASE
        WHEN c.TruncatedRate =
             TRY_CONVERT(DECIMAL(18,3), m.on_time_delivery_rate)
            THEN 'TRUNCATION MATCH'
        ELSE 'OTHER DIFFERENCE'
    END;
