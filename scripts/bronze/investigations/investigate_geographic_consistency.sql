/*
Bronze geographic consistency investigation
Database: LogisticsAnalytics

Investigates city/state pairs in delivery_events, fuel_purchases, facilities,
safety_incidents, and route origins/destinations.

The internal reference mapping uses delivery_events, facilities, and routes.
These are internally consistent sources in this dataset, not an authoritative
external geographic reference. A mismatch indicates disagreement with the
internal mapping; it does not independently prove which value is correct.
Pair counts are distinct city/state combinations, not affected row counts.
*/
USE LogisticsAnalytics;


/* 1. City-to-multiple-state checks within each source. */
SELECT N'delivery_events' AS SourceTable, location_city AS City,
       COUNT(DISTINCT location_state) AS StateCount
FROM bronze.delivery_events
GROUP BY location_city
HAVING COUNT(DISTINCT location_state) > 1;

SELECT N'fuel_purchases' AS SourceTable, location_city AS City,
       COUNT(DISTINCT location_state) AS StateCount
FROM bronze.fuel_purchases
GROUP BY location_city
HAVING COUNT(DISTINCT location_state) > 1;

SELECT N'facilities' AS SourceTable, city AS City,
       COUNT(DISTINCT state) AS StateCount
FROM bronze.facilities
GROUP BY city
HAVING COUNT(DISTINCT state) > 1;

SELECT N'safety_incidents' AS SourceTable, location_city AS City,
       COUNT(DISTINCT location_state) AS StateCount
FROM bronze.safety_incidents
GROUP BY location_city
HAVING COUNT(DISTINCT location_state) > 1;

SELECT origin_city AS City, COUNT(DISTINCT origin_state) AS StateCount
FROM bronze.routes
GROUP BY origin_city
HAVING COUNT(DISTINCT origin_state) > 1;

SELECT destination_city AS City, COUNT(DISTINCT destination_state) AS StateCount
FROM bronze.routes
GROUP BY destination_city
HAVING COUNT(DISTINCT destination_state) > 1;

/* 2. Distinct city/state pair counts by source. */
SELECT N'delivery_events' AS SourceTable, COUNT_BIG(*) AS DistinctPairs
FROM (SELECT DISTINCT location_city, location_state FROM bronze.delivery_events) AS p
UNION ALL
SELECT N'fuel_purchases', COUNT_BIG(*)
FROM (SELECT DISTINCT location_city, location_state FROM bronze.fuel_purchases) AS p
UNION ALL
SELECT N'facilities', COUNT_BIG(*)
FROM (SELECT DISTINCT city, state FROM bronze.facilities) AS p
UNION ALL
SELECT N'safety_incidents', COUNT_BIG(*)
FROM (SELECT DISTINCT location_city, location_state FROM bronze.safety_incidents) AS p
UNION ALL
SELECT N'routes_origin', COUNT_BIG(*)
FROM (SELECT DISTINCT origin_city, origin_state FROM bronze.routes) AS p
UNION ALL
SELECT N'routes_destination', COUNT_BIG(*)
FROM (SELECT DISTINCT destination_city, destination_state FROM bronze.routes) AS p
ORDER BY SourceTable;

/* 3. Inspect the distinct pairs from the two inconsistent sources. */
SELECT DISTINCT location_city AS City, location_state AS State
FROM bronze.fuel_purchases
ORDER BY City, State;

SELECT DISTINCT location_city AS City, location_state AS State
FROM bronze.safety_incidents
ORDER BY City, State;

/* 4. Compare suspect pairs with internally consistent source mappings. */
WITH ReferenceMappings AS
(
    SELECT location_city AS City, location_state AS State
    FROM bronze.delivery_events
    UNION ALL
    SELECT city, state FROM bronze.facilities
    UNION ALL
    SELECT origin_city, origin_state FROM bronze.routes
    UNION ALL
    SELECT destination_city, destination_state FROM bronze.routes
),
ReferenceSummary AS
(
    SELECT City, MIN(State) AS ReferenceState,
           COUNT(DISTINCT State) AS ReferenceStateCount
    FROM ReferenceMappings
    GROUP BY City
),
SuspectMappings AS
(
    SELECT DISTINCT 'fuel_purchases' AS SourceTable,
           location_city AS City, location_state AS State
    FROM bronze.fuel_purchases
    UNION ALL
    SELECT DISTINCT 'safety_incidents',
           location_city, location_state
    FROM bronze.safety_incidents
),
Comparison AS
(
    SELECT S.SourceTable, S.City, S.State, R.ReferenceState,
           CASE
               WHEN R.City IS NULL THEN 'No Reference'
               WHEN R.ReferenceStateCount > 1 THEN 'Ambiguous Reference'
               WHEN S.State = R.ReferenceState THEN 'Matches Reference'
               ELSE 'Mismatch'
           END AS ComparisonResult
    FROM SuspectMappings AS S
    LEFT JOIN ReferenceSummary AS R ON S.City = R.City
)
SELECT SourceTable, ComparisonResult,
       COUNT_BIG(*) AS DistinctCityStatePairs
FROM Comparison
GROUP BY SourceTable, ComparisonResult
ORDER BY SourceTable, ComparisonResult;

/* 5. Return the detailed mismatching pairs for review. */
WITH ReferenceMappings AS
(
    SELECT location_city AS City, location_state AS State
    FROM bronze.delivery_events
    UNION ALL
    SELECT city, state FROM bronze.facilities
    UNION ALL
    SELECT origin_city, origin_state FROM bronze.routes
    UNION ALL
    SELECT destination_city, destination_state FROM bronze.routes
),
ReferenceSummary AS
(
    SELECT City, MIN(State) AS ReferenceState,
           COUNT(DISTINCT State) AS ReferenceStateCount
    FROM ReferenceMappings
    GROUP BY City
),
SuspectMappings AS
(
    SELECT DISTINCT 'fuel_purchases' AS SourceTable,
           location_city AS City, location_state AS State
    FROM bronze.fuel_purchases
    UNION ALL
    SELECT DISTINCT 'safety_incidents',
           location_city, location_state
    FROM bronze.safety_incidents
)
SELECT S.SourceTable, S.City, S.State AS SourceState,
       R.ReferenceState, R.ReferenceStateCount
FROM SuspectMappings AS S
LEFT JOIN ReferenceSummary AS R ON S.City = R.City
WHERE R.City IS NULL
   OR R.ReferenceStateCount > 1
   OR S.State <> R.ReferenceState
ORDER BY S.SourceTable, S.City, S.State;

/*
Recorded results:
  Source             Matching pairs   Mismatches   Total pairs
  fuel_purchases          25             550          575
  safety_incidents         7             138          145

Internal pair counts:
  delivery_events: 20 cities / 20 pairs
  fuel_purchases: 25 cities / 575 pairs
  facilities: 21 cities / 21 pairs
  safety_incidents: 25 cities / 145 pairs
  routes origin: 18 cities / 18 pairs
  routes destination: 19 cities / 19 pairs

The exact cause is unknown. Validate against an approved external geographic
reference before correcting or standardizing values in Silver. Preserve raw
Bronze values and document any downstream changes.
*/
