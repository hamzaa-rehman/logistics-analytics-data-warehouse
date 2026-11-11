/*
===============================================================================
Script:      investigate_january_2025_timestamps.sql
Purpose:     Investigate January 2025 timestamps in delivery_events and
             fuel_purchases.
Database:    LogisticsAnalytics
Schema:      bronze

Scope:
    - January 2025 actual and scheduled delivery-event timestamps.
    - Associated trip and load dates.
    - Pickup/delivery event sequence for affected trips.
    - January 2025 fuel purchases and their associated trips.
    - Dispatch timing, delivery timing, truck and driver associations.

Important:
    This is a one-off investigation script, not a reusable profiling script.
    All source values remain unchanged.

Evidence:
    Query results were supplied during the investigation. The consolidated
    script was formatted and reviewed after execution; it has not been
    independently rerun end-to-end as a single script.
===============================================================================
*/

USE LogisticsAnalytics;
GO

/*=============================================================================
  1. COUNT JANUARY 2025 DELIVERY-EVENT TIMESTAMPS
=============================================================================*/

SELECT
    COUNT(*) AS TotalRows,

    SUM(CASE
        WHEN TRY_CONVERT(DATETIME2, actual_datetime) >= '2025-01-01'
         AND TRY_CONVERT(DATETIME2, actual_datetime) <  '2025-02-01'
        THEN 1 ELSE 0
    END) AS JanuaryActualEvents,

    SUM(CASE
        WHEN TRY_CONVERT(DATETIME2, scheduled_datetime) >= '2025-01-01'
         AND TRY_CONVERT(DATETIME2, scheduled_datetime) <  '2025-02-01'
        THEN 1 ELSE 0
    END) AS JanuaryScheduledEvents

FROM bronze.delivery_events;
GO

/*
Observed:
    Total rows:                170,820
    January actual timestamps:     86
    January scheduled timestamps:  77
*/

/*=============================================================================
  2. RETRIEVE DELIVERY EVENTS WITH A JANUARY TIMESTAMP
=============================================================================*/

SELECT
    de.event_id,
    de.trip_id,
    de.load_id,
    de.event_type,
    de.scheduled_datetime,
    de.actual_datetime,
    t.dispatch_date,
    l.load_date

FROM bronze.delivery_events AS de

LEFT JOIN bronze.trips AS t
    ON de.trip_id = t.trip_id

LEFT JOIN bronze.loads AS l
    ON de.load_id = l.load_id

WHERE
    (
        TRY_CONVERT(DATETIME2, de.actual_datetime) >= '2025-01-01'
        AND TRY_CONVERT(DATETIME2, de.actual_datetime) < '2025-02-01'
    )
    OR
    (
        TRY_CONVERT(DATETIME2, de.scheduled_datetime) >= '2025-01-01'
        AND TRY_CONVERT(DATETIME2, de.scheduled_datetime) < '2025-02-01'
    )

ORDER BY
    TRY_CONVERT(DATETIME2, de.actual_datetime),
    de.event_id;
GO

/*
Observed:
    87 distinct Delivery events were returned.
    76 had both actual and scheduled timestamps in January.
    10 had only the actual timestamp in January.
    1 had only the scheduled timestamp in January.
    Associated trips and loads were dated December 30 or 31, 2024.
*/

/*=============================================================================
  3. RETRIEVE PICKUP AND DELIVERY EVENTS FOR THE 87 AFFECTED TRIPS
=============================================================================*/

WITH JanuaryDeliveryTrips AS
(
    SELECT DISTINCT
        trip_id
    FROM bronze.delivery_events
    WHERE event_type = 'Delivery'
      AND
      (
          (
              TRY_CONVERT(DATETIME2, actual_datetime) >= '2025-01-01'
              AND TRY_CONVERT(DATETIME2, actual_datetime) < '2025-02-01'
          )
          OR
          (
              TRY_CONVERT(DATETIME2, scheduled_datetime) >= '2025-01-01'
              AND TRY_CONVERT(DATETIME2, scheduled_datetime) < '2025-02-01'
          )
      )
)
SELECT
    de.trip_id,
    de.event_type,
    de.scheduled_datetime,
    de.actual_datetime,
    t.dispatch_date,
    l.load_date

FROM JanuaryDeliveryTrips AS jdt

INNER JOIN bronze.delivery_events AS de
    ON jdt.trip_id = de.trip_id

LEFT JOIN bronze.trips AS t
    ON de.trip_id = t.trip_id

LEFT JOIN bronze.loads AS l
    ON de.load_id = l.load_id

ORDER BY
    de.trip_id,
    de.event_type;
GO

/*
Observed:
    87 Pickup events and 87 Delivery events were returned.
    All 87 Pickup actual timestamps preceded their Delivery actual timestamps.
*/

/*=============================================================================
  4. VALIDATE EVENT COMPLETENESS AND ACTUAL SEQUENCE
=============================================================================*/

WITH JanuaryDeliveryTrips AS
(
    SELECT DISTINCT
        trip_id
    FROM bronze.delivery_events
    WHERE event_type = 'Delivery'
      AND
      (
          (
              TRY_CONVERT(DATETIME2, actual_datetime) >= '2025-01-01'
              AND TRY_CONVERT(DATETIME2, actual_datetime) < '2025-02-01'
          )
          OR
          (
              TRY_CONVERT(DATETIME2, scheduled_datetime) >= '2025-01-01'
              AND TRY_CONVERT(DATETIME2, scheduled_datetime) < '2025-02-01'
          )
      )
),
TripTimeline AS
(
    SELECT
        jdt.trip_id,

        MAX(CASE
            WHEN de.event_type = 'Pickup'
            THEN TRY_CONVERT(DATETIME2, de.actual_datetime)
        END) AS PickupActual,

        MAX(CASE
            WHEN de.event_type = 'Delivery'
            THEN TRY_CONVERT(DATETIME2, de.actual_datetime)
        END) AS DeliveryActual,

        SUM(CASE
            WHEN de.event_type = 'Pickup' THEN 1 ELSE 0
        END) AS PickupEvents,

        SUM(CASE
            WHEN de.event_type = 'Delivery' THEN 1 ELSE 0
        END) AS DeliveryEvents

    FROM JanuaryDeliveryTrips AS jdt

    LEFT JOIN bronze.delivery_events AS de
        ON jdt.trip_id = de.trip_id

    GROUP BY
        jdt.trip_id
)
SELECT
    COUNT(*) AS TotalTrips,

    SUM(CASE
        WHEN PickupEvents = 0 THEN 1 ELSE 0
    END) AS TripsWithoutPickup,

    SUM(CASE
        WHEN DeliveryEvents = 0 THEN 1 ELSE 0
    END) AS TripsWithoutDelivery,

    SUM(CASE
        WHEN PickupActual < DeliveryActual THEN 1 ELSE 0
    END) AS PickupBeforeDelivery,

    SUM(CASE
        WHEN PickupActual >= DeliveryActual
          OR PickupActual IS NULL
          OR DeliveryActual IS NULL
        THEN 1 ELSE 0
    END) AS InvalidOrMissingActualSequence

FROM TripTimeline;
GO

/*
Observed:
    Total trips:                         87
    Trips without Pickup:                 0
    Trips without Delivery:               0
    Pickup actual before Delivery actual: 87
    Invalid or missing actual sequence:    0
*/

/*=============================================================================
  5. COUNT JANUARY 2025 FUEL PURCHASES BY DATE
=============================================================================*/

SELECT
    CAST(TRY_CONVERT(DATETIME2, purchase_date) AS DATE) AS PurchaseDate,
    COUNT(*) AS PurchaseCount,
    COUNT(DISTINCT truck_id) AS DistinctTrucks,
    COUNT(DISTINCT driver_id) AS DistinctDrivers

FROM bronze.fuel_purchases

WHERE TRY_CONVERT(DATETIME2, purchase_date) >= '2025-01-01'
  AND TRY_CONVERT(DATETIME2, purchase_date) <  '2025-02-01'

GROUP BY
    CAST(TRY_CONVERT(DATETIME2, purchase_date) AS DATE)

ORDER BY
    PurchaseDate;
GO

/*
Observed:
    2025-01-01: 137 purchases, 52 distinct trucks, 70 distinct drivers.
    2025-01-02:  64 purchases, 33 distinct trucks, 32 distinct drivers.
    Total:      201 purchases.
*/

/*=============================================================================
  6. VALIDATE FUEL-PURCHASE TRIP ASSOCIATIONS AND DISPATCH DATE RANGE
=============================================================================*/

SELECT
    COUNT(*) AS JanuaryPurchases,

    COUNT(DISTINCT fp.trip_id) AS DistinctTrips,

    MIN(TRY_CONVERT(DATE, t.dispatch_date)) AS EarliestTripDispatch,

    MAX(TRY_CONVERT(DATE, t.dispatch_date)) AS LatestTripDispatch,

    SUM(CASE
        WHEN t.trip_id IS NULL
          OR TRY_CONVERT(DATE, t.dispatch_date) IS NULL
        THEN 1 ELSE 0
    END) AS MissingTripOrInvalidDispatchDate

FROM bronze.fuel_purchases AS fp

LEFT JOIN bronze.trips AS t
    ON fp.trip_id = t.trip_id

WHERE TRY_CONVERT(DATETIME2, fp.purchase_date) >= '2025-01-01'
  AND TRY_CONVERT(DATETIME2, fp.purchase_date) < '2025-02-01';
GO

/*
Observed:
    January purchases: 201
    Distinct trips:    115
    Dispatch dates:    December 29 through December 31, 2024
    Missing trip/date associations: 0
*/

/*=============================================================================
  7. COMPARE PURCHASE DATE WITH TRIP DISPATCH DATE
=============================================================================*/

WITH JanuaryPurchases AS
(
    SELECT
        fp.fuel_purchase_id,
        TRY_CONVERT(DATE, fp.purchase_date) AS PurchaseDate,
        TRY_CONVERT(DATE, t.dispatch_date) AS DispatchDate
    FROM bronze.fuel_purchases AS fp
    LEFT JOIN bronze.trips AS t
        ON fp.trip_id = t.trip_id
    WHERE TRY_CONVERT(DATETIME2, fp.purchase_date) >= '2025-01-01'
      AND TRY_CONVERT(DATETIME2, fp.purchase_date) < '2025-02-01'
)
SELECT
    CASE
        WHEN DispatchDate IS NULL THEN 'Missing Dispatch Date'
        WHEN PurchaseDate < DispatchDate THEN 'Before Dispatch'
        WHEN PurchaseDate = DispatchDate THEN 'On Dispatch Date'
        WHEN PurchaseDate > DispatchDate THEN 'After Dispatch'
    END AS PurchaseTiming,

    COUNT(*) AS PurchaseCount

FROM JanuaryPurchases

GROUP BY
    CASE
        WHEN DispatchDate IS NULL THEN 'Missing Dispatch Date'
        WHEN PurchaseDate < DispatchDate THEN 'Before Dispatch'
        WHEN PurchaseDate = DispatchDate THEN 'On Dispatch Date'
        WHEN PurchaseDate > DispatchDate THEN 'After Dispatch'
    END

ORDER BY
    PurchaseCount DESC;
GO

/*
Observed:
    All 201 purchases occurred after their associated trip dispatch dates.
*/

/*=============================================================================
  8. CHECK WHETHER EACH JANUARY PURCHASE HAS A DELIVERY EVENT
=============================================================================*/

WITH JanuaryPurchases AS
(
    SELECT
        fp.fuel_purchase_id,
        fp.trip_id,
        TRY_CONVERT(DATETIME2, fp.purchase_date) AS PurchaseDateTime
    FROM bronze.fuel_purchases AS fp
    WHERE TRY_CONVERT(DATETIME2, fp.purchase_date) >= '2025-01-01'
      AND TRY_CONVERT(DATETIME2, fp.purchase_date) < '2025-02-01'
),
DeliveryTimeline AS
(
    SELECT
        trip_id,
        COUNT(*) AS DeliveryEventCount,
        MAX(TRY_CONVERT(DATETIME2, actual_datetime)) AS ActualDeliveryDateTime
    FROM bronze.delivery_events
    WHERE event_type = 'Delivery'
    GROUP BY trip_id
)
SELECT
    COUNT(*) AS TotalPurchases,

    SUM(CASE
        WHEN dt.trip_id IS NULL THEN 1 ELSE 0
    END) AS TripsWithoutDeliveryEvent,

    SUM(CASE
        WHEN jp.PurchaseDateTime < dt.ActualDeliveryDateTime
        THEN 1 ELSE 0
    END) AS PurchasesBeforeDelivery,

    SUM(CASE
        WHEN jp.PurchaseDateTime >= dt.ActualDeliveryDateTime
        THEN 1 ELSE 0
    END) AS PurchasesOnOrAfterDelivery

FROM JanuaryPurchases AS jp

LEFT JOIN DeliveryTimeline AS dt
    ON jp.trip_id = dt.trip_id;
GO

/*
Observed:
    Total purchases:              201
    Trips without Delivery event:   0
    Purchases before delivery:     52
    Purchases on or after delivery:149
*/

/*=============================================================================
  9. SUMMARIZE PURCHASE-TO-DELIVERY TIME DIFFERENCES
=============================================================================*/

WITH JanuaryPurchases AS
(
    SELECT
        fp.fuel_purchase_id,
        fp.trip_id,
        TRY_CONVERT(DATETIME2, fp.purchase_date) AS PurchaseDateTime
    FROM bronze.fuel_purchases AS fp
    WHERE TRY_CONVERT(DATETIME2, fp.purchase_date) >= '2025-01-01'
      AND TRY_CONVERT(DATETIME2, fp.purchase_date) < '2025-02-01'
),
DeliveryTimeline AS
(
    SELECT
        trip_id,
        MAX(TRY_CONVERT(DATETIME2, actual_datetime)) AS ActualDeliveryDateTime
    FROM bronze.delivery_events
    WHERE event_type = 'Delivery'
    GROUP BY trip_id
),
PurchaseDifferences AS
(
    SELECT
        jp.fuel_purchase_id,
        jp.trip_id,
        DATEDIFF
        (
            MINUTE,
            dt.ActualDeliveryDateTime,
            jp.PurchaseDateTime
        ) AS MinutesFromDelivery
    FROM JanuaryPurchases AS jp
    INNER JOIN DeliveryTimeline AS dt
        ON jp.trip_id = dt.trip_id
)
SELECT
    CASE
        WHEN MinutesFromDelivery < 0 THEN 'Before Delivery'
        ELSE 'On or After Delivery'
    END AS PurchaseTiming,

    COUNT(*) AS PurchaseCount,
    MIN(MinutesFromDelivery) AS MinimumMinutes,
    MAX(MinutesFromDelivery) AS MaximumMinutes,
    AVG(CAST(MinutesFromDelivery AS DECIMAL(18, 2))) AS AverageMinutes

FROM PurchaseDifferences

GROUP BY
    CASE
        WHEN MinutesFromDelivery < 0 THEN 'Before Delivery'
        ELSE 'On or After Delivery'
    END;
GO

/*
Observed:
    Before delivery:
        52 purchases; minimum -2,009 minutes; maximum -30 minutes;
        average -735.634615 minutes.

    On or after delivery:
        149 purchases; minimum 8 minutes; maximum 3,631 minutes;
        average 1,406.986577 minutes.
*/

/*=============================================================================
  10. INSPECT PURCHASES OCCURRING AFTER DELIVERY
=============================================================================*/

WITH JanuaryPurchases AS
(
    SELECT
        fp.fuel_purchase_id,
        fp.trip_id,
        fp.truck_id,
        fp.driver_id,
        TRY_CONVERT(DATETIME2, fp.purchase_date) AS PurchaseDateTime
    FROM bronze.fuel_purchases AS fp
    WHERE TRY_CONVERT(DATETIME2, fp.purchase_date) >= '2025-01-01'
      AND TRY_CONVERT(DATETIME2, fp.purchase_date) < '2025-02-01'
),
DeliveryTimeline AS
(
    SELECT
        trip_id,
        MAX(TRY_CONVERT(DATETIME2, actual_datetime)) AS ActualDeliveryDateTime
    FROM bronze.delivery_events
    WHERE event_type = 'Delivery'
    GROUP BY trip_id
)
SELECT TOP (10)
    jp.fuel_purchase_id,
    jp.trip_id,
    jp.truck_id,
    jp.driver_id,
    t.dispatch_date,
    dt.ActualDeliveryDateTime,
    jp.PurchaseDateTime,

    DATEDIFF
    (
        MINUTE,
        dt.ActualDeliveryDateTime,
        jp.PurchaseDateTime
    ) AS MinutesAfterDelivery

FROM JanuaryPurchases AS jp

INNER JOIN DeliveryTimeline AS dt
    ON jp.trip_id = dt.trip_id

INNER JOIN bronze.trips AS t
    ON jp.trip_id = t.trip_id

WHERE jp.PurchaseDateTime >= dt.ActualDeliveryDateTime

ORDER BY
    MinutesAfterDelivery DESC;
GO

/*
This query was used to inspect individual purchases occurring after delivery.
It does not establish why the purchase is associated with the trip.
*/

/*=============================================================================
  11. VALIDATE TRUCK AND DRIVER ASSOCIATIONS
=============================================================================*/

SELECT
    COUNT(*) AS TotalJanuaryPurchases,

    SUM(CASE
        WHEN t.trip_id IS NULL THEN 1 ELSE 0
    END) AS MissingTrips,

    SUM(CASE
        WHEN fp.truck_id IS NOT NULL
         AND t.truck_id IS NOT NULL
         AND fp.truck_id <> t.truck_id
        THEN 1 ELSE 0
    END) AS TruckMismatches,

    SUM(CASE
        WHEN fp.driver_id IS NOT NULL
         AND t.driver_id IS NOT NULL
         AND fp.driver_id <> t.driver_id
        THEN 1 ELSE 0
    END) AS DriverMismatches,

    SUM(CASE
        WHEN fp.truck_id = t.truck_id
         AND fp.driver_id = t.driver_id
        THEN 1 ELSE 0
    END) AS FullyMatchingNonNullAssociations,

    SUM(CASE
        WHEN fp.driver_id IS NULL
         AND t.driver_id IS NULL
        THEN 1 ELSE 0
    END) AS BothDriverIDsNull

FROM bronze.fuel_purchases AS fp

LEFT JOIN bronze.trips AS t
    ON fp.trip_id = t.trip_id

WHERE TRY_CONVERT(DATETIME2, fp.purchase_date) >= '2025-01-01'
  AND TRY_CONVERT(DATETIME2, fp.purchase_date) < '2025-02-01';
GO

/*
Observed:
    Total January purchases:                 201
    Missing trips:                             0
    Truck mismatches:                          0
    Driver mismatches:                         0
    Fully matching non-NULL associations:    199
    Both driver IDs NULL:                      2

SQL equality comparisons do not treat NULL = NULL as TRUE. The separate
BothDriverIDsNull metric accounts for the two records with NULL driver IDs
in both the fuel purchase and its associated trip.
*/

/*=============================================================================
  12. IDENTIFY RECORDS WITH NULL DRIVER ASSOCIATIONS
=============================================================================*/

SELECT
    fp.fuel_purchase_id,
    fp.trip_id,

    fp.truck_id AS PurchaseTruckID,
    t.truck_id AS TripTruckID,

    fp.driver_id AS PurchaseDriverID,
    t.driver_id AS TripDriverID

FROM bronze.fuel_purchases AS fp

INNER JOIN bronze.trips AS t
    ON fp.trip_id = t.trip_id

WHERE TRY_CONVERT(DATETIME2, fp.purchase_date) >= '2025-01-01'
  AND TRY_CONVERT(DATETIME2, fp.purchase_date) < '2025-02-01'

  AND
  (
      fp.driver_id IS NULL
      OR t.driver_id IS NULL
  )

ORDER BY
    fp.fuel_purchase_id;
GO

/*
Observed records:
    FUEL00193404 / TRIP00085249
        Purchase truck: TRK00023
        Trip truck:     TRK00023
        Driver IDs:     NULL in both records

    FUEL00035251 / TRIP00085366
        Purchase truck: TRK00099
        Trip truck:     TRK00099
        Driver IDs:     NULL in both records
*/

/*=============================================================================
  13. INVESTIGATION CONCLUSION
=============================================================================*/

/*
DELIVERY EVENTS
    - 87 distinct Delivery events had an actual or scheduled timestamp in
      January 2025.
    - Associated trips and loads were dated December 30 or 31, 2024.
    - All 87 trips had one Pickup and one Delivery event.
    - All Pickup actual timestamps preceded Delivery actual timestamps.
    - No missing or invalid event sequences were identified.

FUEL PURCHASES
    - 201 purchases occurred on January 1 and 2, 2025.
    - They referenced 115 trips dispatched from December 29 through 31, 2024.
    - All purchases occurred after dispatch and had a matching Delivery event.
    - 52 purchases occurred before delivery; 149 occurred on or after delivery.
    - All truck associations matched.
    - 199 records had matching non-NULL driver associations.
    - Two records had NULL driver IDs in both the purchase and trip records.

OVERALL INTERPRETATION
    The January 2025 timestamps are plausibly associated with year-end
    operational activity. No timestamp error was established.

    The business meaning of the fuel-purchase-to-trip association, especially
    purchases occurring after delivery, remains unverified. Matching
    identifiers establish internal consistency, not the operational meaning
    of the relationship.

    Preserve the original timestamps and source associations in Bronze.
    Do not shift timestamps or infer business meaning without an authoritative
    business rule.
*/

/*
===============================================================================
END OF JANUARY 2025 TIMESTAMP INVESTIGATION
===============================================================================
*/
