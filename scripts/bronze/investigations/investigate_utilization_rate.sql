/*
================================================================================
Project:        Logistics Analytics Data Warehouse
Layer:          Bronze
Script:         investigate_utilization_rate.sql
Purpose:        Investigate the business meaning of utilization_rate.

Background:
    Numeric profiling identified values greater than 1.0 in
    bronze.truck_utilization_metrics.utilization_rate.

    This investigation tests whether the source metric is calculated as:

        trips_completed / number of calendar days in the month

Validation:
    The suspected calculation is compared against every record.

Verified result from the investigation:
    Total records:       3,312
    Matching records:    3,312
    Mismatching records: 0

Conclusion:
    The source metric represents average completed trips per calendar day,
    not a utilization percentage.

Silver-layer consideration:
    Consider naming the Silver column trips_per_day while retaining the
    original utilization_rate name in Bronze for source traceability.

Note:
    These are investigation queries, not part of the reusable profiling script.
================================================================================
*/


/*
================================================================================
STEP 1: Identify values greater than 1.0
================================================================================

Purpose:
    Determine which recorded values exceed 1.0 and how frequently they occur.
*/

SELECT
    utilization_rate,
    COUNT(*) AS RecordCount
FROM bronze.truck_utilization_metrics
GROUP BY utilization_rate
HAVING TRY_CONVERT(DECIMAL(18,4), utilization_rate) > 1
ORDER BY
    TRY_CONVERT(DECIMAL(18,4), utilization_rate) DESC;


/*
================================================================================
STEP 2: Inspect sample records
================================================================================

Purpose:
    Examine related truck, month, trip, mileage, and downtime values.
*/

SELECT TOP 20
    truck_id,
    [month],
    utilization_rate,
    total_miles,
    trips_completed,
    downtime_hours
FROM bronze.truck_utilization_metrics
WHERE TRY_CONVERT(DECIMAL(18,4), utilization_rate) > 1
ORDER BY
    TRY_CONVERT(DECIMAL(18,4), utilization_rate) DESC;


/*
================================================================================
STEP 3: Compare sample records with the suspected calculation
================================================================================

Suspected calculation:
    trips_completed / calendar days in the month

ROUND(..., 3) matches the recorded metric's observed precision.
*/

SELECT TOP 20
    truck_id,
    [month],
    trips_completed,
    utilization_rate,

    DAY
    (
        EOMONTH(TRY_CONVERT(DATE, [month]))
    ) AS DaysInMonth,

    ROUND
    (
        TRY_CONVERT(DECIMAL(18,4), trips_completed) /
        DAY(EOMONTH(TRY_CONVERT(DATE, [month]))),
        3
    ) AS CalculatedRate

FROM bronze.truck_utilization_metrics
WHERE TRY_CONVERT(DECIMAL(18,4), utilization_rate) > 1
ORDER BY
    TRY_CONVERT(DECIMAL(18,4), utilization_rate) DESC;


/*
================================================================================
STEP 4: Validate the suspected calculation across all records
================================================================================

Purpose:
    Compare the recorded metric with the calculated trips-per-day value
    for every record.

The result separates:
    - Matching records
    - Mismatching records
    - Uncheckable records caused by NULL or invalid inputs
================================================================================
*/

;WITH RateCalculation AS
(
    SELECT
        TRY_CONVERT(DECIMAL(18,4), utilization_rate) AS SourceRate,

        TRY_CONVERT(DECIMAL(18,4), trips_completed) AS TripsCompleted,

        TRY_CONVERT(DATE, [month]) AS MonthDate

    FROM bronze.truck_utilization_metrics
),
CalculatedRate AS
(
    SELECT
        SourceRate,

        ROUND
        (
            TripsCompleted /
            NULLIF(DAY(EOMONTH(MonthDate)), 0),
            3
        ) AS ExpectedRate

    FROM RateCalculation
)

SELECT
    COUNT_BIG(*) AS TotalRows,

    SUM
    (
        CASE
            WHEN SourceRate IS NOT NULL
             AND ExpectedRate IS NOT NULL
             AND SourceRate = ExpectedRate
            THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END
    ) AS MatchingRows,

    SUM
    (
        CASE
            WHEN SourceRate IS NOT NULL
             AND ExpectedRate IS NOT NULL
             AND SourceRate <> ExpectedRate
            THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END
    ) AS MismatchingRows,

    SUM
    (
        CASE
            WHEN SourceRate IS NULL
              OR ExpectedRate IS NULL
            THEN CONVERT(BIGINT, 1)
            ELSE CONVERT(BIGINT, 0)
        END
    ) AS UncheckableRows

FROM CalculatedRate;
