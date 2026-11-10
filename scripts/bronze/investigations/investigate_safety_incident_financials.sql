
/*
===============================================================================
  Project:       Logistics Analytics Data Warehouse
  Layer:         Bronze
  Script:        investigate_safety_incident_financials.sql
  Purpose:       Investigate zero values and financial relationships in
                 safety_incidents:
                   - cargo_damage_cost
                   - claim_amount
                   - vehicle_damage_cost

  Investigation Scope:
    1. Identify combinations of zero values across financial columns.
    2. Inspect the source table structure and data types.
    3. Review categorical distributions.
    4. Analyze zero values by incident type and incident flags.
    5. Examine positive cargo damage costs.
    6. Review the highest and lowest cargo damage records.
    7. Validate the relationship between claim amount and damage costs.
    8. Examine positive vehicle damage costs.

  Notes:
    - Bronze columns are stored as VARCHAR.
    - TRY_CONVERT is used for numeric analysis without modifying Bronze data.
    - Monetary units and commercial correctness have not been independently
      verified.
    - Queries are intended for investigation, not data transformation.

===============================================================================
*/

USE LogisticsAnalytics;

/*
===============================================================================
  1. ZERO-VALUE COMBINATIONS
===============================================================================

  Purpose:
    Identify how the three financial columns contain zero values together.

  This helps determine whether zero values occur independently or whether
  certain financial columns consistently contain zero at the same time.
===============================================================================
*/

SELECT
    CASE
        WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) = 0
            THEN 1 ELSE 0
    END AS ZeroCargoDamage,

    CASE
        WHEN TRY_CONVERT(DECIMAL(18,4), claim_amount) = 0
            THEN 1 ELSE 0
    END AS ZeroClaimAmount,

    CASE
        WHEN TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost) = 0
            THEN 1 ELSE 0
    END AS ZeroVehicleDamage,

    COUNT(*) AS IncidentCount

FROM bronze.safety_incidents

GROUP BY
    CASE
        WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) = 0
            THEN 1 ELSE 0
    END,

    CASE
        WHEN TRY_CONVERT(DECIMAL(18,4), claim_amount) = 0
            THEN 1 ELSE 0
    END,

    CASE
        WHEN TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost) = 0
            THEN 1 ELSE 0
    END

ORDER BY IncidentCount DESC;


/*
===============================================================================
  2. SOURCE TABLE STRUCTURE AND DATA TYPES
===============================================================================

  Purpose:
    Inspect the column order, column names, and SQL Server data types of
    bronze.safety_incidents.

  This confirms the source structure before further investigation.
===============================================================================
*/

SELECT
    c.column_id,
    c.name AS ColumnName,
    t.name AS DataType

FROM sys.columns AS c

JOIN sys.types AS t
    ON c.user_type_id = t.user_type_id

WHERE c.object_id = OBJECT_ID('bronze.safety_incidents')

ORDER BY c.column_id;


/*
===============================================================================
  3. CATEGORICAL DISTRIBUTIONS
===============================================================================

  Purpose:
    Review the distribution of incident types and incident-related flags.

  Dimensions:
    - incident_type
    - at_fault_flag
    - injury_flag
    - preventable_flag

  This provides context for interpreting the financial zero values.
===============================================================================
*/

SELECT
    'incident_type' AS ColumnName,
    incident_type AS CategoryValue,
    COUNT(*) AS IncidentCount

FROM bronze.safety_incidents

GROUP BY incident_type

UNION ALL

SELECT
    'at_fault_flag',
    at_fault_flag,
    COUNT(*)

FROM bronze.safety_incidents

GROUP BY at_fault_flag

UNION ALL

SELECT
    'injury_flag',
    injury_flag,
    COUNT(*)

FROM bronze.safety_incidents

GROUP BY injury_flag

UNION ALL

SELECT
    'preventable_flag',
    preventable_flag,
    COUNT(*)

FROM bronze.safety_incidents

GROUP BY preventable_flag

ORDER BY ColumnName, IncidentCount DESC;


/*
===============================================================================
  4. ZERO-VALUE COUNTS BY INCIDENT TYPE
===============================================================================

  Purpose:
    Count zero values in each financial column for every incident type.

  This helps identify whether zero values are concentrated in particular
  incident categories.
===============================================================================
*/

SELECT
    incident_type,
    COUNT(*) AS TotalIncidents,

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) = 0
                THEN 1 ELSE 0
        END
    ) AS ZeroCargoDamage,

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), claim_amount) = 0
                THEN 1 ELSE 0
        END
    ) AS ZeroClaimAmount,

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost) = 0
                THEN 1 ELSE 0
        END
    ) AS ZeroVehicleDamage

FROM bronze.safety_incidents

GROUP BY incident_type

ORDER BY incident_type;


/*
===============================================================================
  5. ZERO-VALUE PERCENTAGES BY INCIDENT TYPE
===============================================================================

  Purpose:
    Calculate the percentage of incidents with zero values in each financial
    column, within each incident type.

  Percentages provide a fairer comparison between categories with different
  incident counts.
===============================================================================
*/

SELECT
    incident_type,
    COUNT(*) AS TotalIncidents,

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) = 0
                THEN 1 ELSE 0
        END
    ) AS ZeroCargoDamage,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) = 0
                    THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS ZeroCargoDamagePct,

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), claim_amount) = 0
                THEN 1 ELSE 0
        END
    ) AS ZeroClaimAmount,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN TRY_CONVERT(DECIMAL(18,4), claim_amount) = 0
                    THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS ZeroClaimAmountPct,

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost) = 0
                THEN 1 ELSE 0
        END
    ) AS ZeroVehicleDamage,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost) = 0
                    THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS ZeroVehicleDamagePct

FROM bronze.safety_incidents

GROUP BY incident_type

ORDER BY incident_type;


/*
===============================================================================
  6. ZERO-VALUE COUNTS BY INCIDENT FLAGS
===============================================================================

  Purpose:
    Compare zero-value counts across:
      - at_fault_flag
      - injury_flag
      - preventable_flag

  UNION ALL combines the results from the three separate dimensions into
  one result set.
===============================================================================
*/

SELECT
    'at_fault_flag' AS Dimension,
    at_fault_flag AS CategoryValue,
    COUNT(*) AS TotalIncidents,

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) = 0
                THEN 1 ELSE 0
        END
    ) AS ZeroCargoDamage,

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), claim_amount) = 0
                THEN 1 ELSE 0
        END
    ) AS ZeroClaimAmount,

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost) = 0
                THEN 1 ELSE 0
        END
    ) AS ZeroVehicleDamage

FROM bronze.safety_incidents

GROUP BY at_fault_flag

UNION ALL

SELECT
    'injury_flag',
    injury_flag,
    COUNT(*),

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) = 0
                THEN 1 ELSE 0
        END
    ),

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), claim_amount) = 0
                THEN 1 ELSE 0
        END
    ),

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost) = 0
                THEN 1 ELSE 0
        END
    )

FROM bronze.safety_incidents

GROUP BY injury_flag

UNION ALL

SELECT
    'preventable_flag',
    preventable_flag,
    COUNT(*),

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) = 0
                THEN 1 ELSE 0
        END
    ),

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), claim_amount) = 0
                THEN 1 ELSE 0
        END
    ),

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost) = 0
                THEN 1 ELSE 0
        END
    )

FROM bronze.safety_incidents

GROUP BY preventable_flag

ORDER BY Dimension, CategoryValue;


/*
===============================================================================
  7. POSITIVE CARGO DAMAGE COST SUMMARY BY INCIDENT TYPE
===============================================================================

  Purpose:
    Analyze positive cargo damage costs separately from zero values.

  Metrics:
    - Number of positive records
    - Minimum positive cost
    - Maximum positive cost
    - Average positive cost

  Zero values are excluded from the positive-cost calculations.
===============================================================================
*/

SELECT
    incident_type,
    COUNT(*) AS TotalIncidents,

    SUM(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) > 0
                THEN 1 ELSE 0
        END
    ) AS PositiveCargoDamageCount,

    MIN(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) > 0
                THEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost)
        END
    ) AS MinCargoDamage,

    MAX(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) > 0
                THEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost)
        END
    ) AS MaxCargoDamage,

    AVG(
        CASE
            WHEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) > 0
                THEN TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost)
        END
    ) AS AvgCargoDamage

FROM bronze.safety_incidents

GROUP BY incident_type

ORDER BY incident_type;


/*
===============================================================================
  8. CARGO DAMAGE COST: MEAN AND MEDIAN BY INCIDENT TYPE
===============================================================================

  Purpose:
    Compare the average and median positive cargo damage costs by incident
    type.

  PERCENTILE_CONT calculates the median.
  Window functions calculate statistics within each incident type.
===============================================================================
*/

WITH PositiveCargo AS
(
    SELECT
        incident_type,
        TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) AS CargoDamageCost

    FROM bronze.safety_incidents

    WHERE TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) > 0
),

CargoStatistics AS
(
    SELECT
        incident_type,

        COUNT(*) OVER (
            PARTITION BY incident_type
        ) AS PositiveIncidents,

        SUM(CargoDamageCost) OVER (
            PARTITION BY incident_type
        ) AS TotalCargoDamageCost,

        AVG(CargoDamageCost) OVER (
            PARTITION BY incident_type
        ) AS AverageCargoDamageCost,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY CargoDamageCost)
            OVER (PARTITION BY incident_type) AS MedianCargoDamageCost

    FROM PositiveCargo
)

SELECT DISTINCT
    incident_type,
    PositiveIncidents,
    TotalCargoDamageCost,
    AverageCargoDamageCost,
    MedianCargoDamageCost

FROM CargoStatistics

ORDER BY incident_type;


/*
===============================================================================
  9. INSPECT ALL POSITIVE CARGO DAMAGE RECORDS
===============================================================================

  Purpose:
    Review individual incidents with positive cargo damage costs.

  The results are ordered from highest to lowest cost and include incident
  flags and dates for contextual investigation.
===============================================================================
*/

SELECT
    incident_id,
    incident_type,
    TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) AS CargoDamageCost,
    TRY_CONVERT(DATE, incident_date) AS IncidentDate,
    at_fault_flag,
    injury_flag,
    preventable_flag

FROM bronze.safety_incidents

WHERE TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) > 0

ORDER BY CargoDamageCost DESC;


/*
===============================================================================
  10. REVIEW THE FIVE HIGHEST AND FIVE LOWEST CARGO DAMAGE RECORDS
===============================================================================

  Purpose:
    Inspect the descriptions associated with the highest and lowest positive
    cargo damage costs.

  ROW_NUMBER assigns separate rankings:
    - HighestRank: highest cost first.
    - LowestRank: lowest cost first.

  The final result returns the five records at each end of the distribution.
===============================================================================
*/

WITH RankedCargo AS
(
    SELECT
        incident_id,
        incident_type,
        cargo_damage_cost,
        description,

        ROW_NUMBER() OVER (
            ORDER BY TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) DESC
        ) AS HighestRank,

        ROW_NUMBER() OVER (
            ORDER BY TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) ASC
        ) AS LowestRank

    FROM bronze.safety_incidents

    WHERE TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) > 0
)

SELECT
    incident_id,
    incident_type,
    cargo_damage_cost,
    description,

    CASE
        WHEN HighestRank <= 5 THEN 'Highest'
        WHEN LowestRank <= 5 THEN 'Lowest'
    END AS CostGroup

FROM RankedCargo

WHERE HighestRank <= 5
   OR LowestRank <= 5

ORDER BY
    CASE
        WHEN HighestRank <= 5 THEN 1
        ELSE 2
    END,
    HighestRank;


/*
===============================================================================
  11. VALIDATE THE CLAIM AMOUNT RELATIONSHIP
===============================================================================

  Purpose:
    Check whether claim_amount equals the sum of:
      - vehicle_damage_cost
      - cargo_damage_cost

  Difference = ClaimAmount - CombinedDamageCost

  A difference of zero indicates that the arithmetic relationship matches
  for that incident.
===============================================================================
*/

SELECT
    incident_id,

    TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost) AS VehicleDamageCost,

    TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost) AS CargoDamageCost,

    TRY_CONVERT(DECIMAL(18,4), claim_amount) AS ClaimAmount,

    TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost)
        + TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost)
        AS CombinedDamageCost,

    TRY_CONVERT(DECIMAL(18,4), claim_amount)
        - (
            TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost)
            + TRY_CONVERT(DECIMAL(18,4), cargo_damage_cost)
          ) AS Difference

FROM bronze.safety_incidents

ORDER BY incident_id;


/*
===============================================================================
  12. POSITIVE VEHICLE DAMAGE COST SUMMARY BY INCIDENT TYPE
===============================================================================

  Purpose:
    Examine positive vehicle damage costs across incident types.

  Metrics:
    - Total incidents
    - Number of positive records
    - Minimum positive cost
    - Maximum cost
    - Average positive cost

  This complements the cargo damage analysis.
===============================================================================
*/

WITH VehicleDamage AS
(
    SELECT
        incident_type,
        TRY_CONVERT(DECIMAL(18,4), vehicle_damage_cost) AS VehicleDamageCost

    FROM bronze.safety_incidents
)

SELECT
    incident_type,
    COUNT(*) AS TotalIncidents,

    SUM(
        CASE
            WHEN VehicleDamageCost > 0 THEN 1 ELSE 0
        END
    ) AS PositiveRecords,

    MIN(
        CASE
            WHEN VehicleDamageCost > 0 THEN VehicleDamageCost
        END
    ) AS MinimumPositiveCost,

    MAX(VehicleDamageCost) AS MaximumCost,

    AVG(
        CASE
            WHEN VehicleDamageCost > 0 THEN VehicleDamageCost
        END
    ) AS AveragePositiveCost

FROM VehicleDamage

GROUP BY incident_type

ORDER BY incident_type;


/*
===============================================================================
  END OF INVESTIGATION
===============================================================================
*/
