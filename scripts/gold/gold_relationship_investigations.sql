/* ============================================================================
   GOLD LAYER — RELATIONSHIP INVESTIGATION QUERIES
   Project: Logistics Analytics Data Warehouse
   Database: LogisticsAnalytics
   Source layer: Silver

   Supporting findings:
     docs/gold/gold_relationship_investigations.md

   Scope:
     01 Loads-to-Trips
     02 Delivery Events-to-Trips
     03 Event load_id vs Trip load_id
     04 Trips-to-Trailers
     05 Trailer trip distribution
     06 Trips-to-Drivers
     07 Trips-to-Trucks
     08 Loads-to-Routes
     09 Loads-to-Customers
     10 Delivery Events-to-Facilities
     11 Event location vs Facility master location
     12 Detail of mismatched event/facility locations

   Notes:
     - Investigation SQL only; not Gold production SQL.
     - Missingness percentage = missing records / total records * 100.
       This is an observed dataset rate, not a predictive probability.
     - Missingness, unmatched keys, and relationship cardinality are
       separate checks.
     - The uploaded investigation queries are retained in substance;
       missingness percentages are added where nullable keys are assessed.
   ============================================================================ */

USE LogisticsAnalytics;


/* ============================================================================
   01 — LOADS-TO-TRIPS RELATIONSHIP

   Does each load have exactly one trip, and does each trip reference a load?
   ============================================================================ */

WITH TripLoadCounts AS
(
    SELECT load_id, COUNT_BIG(*) AS trip_count
    FROM silver.trips
    WHERE load_id IS NOT NULL
    GROUP BY load_id
)
SELECT
    (SELECT COUNT_BIG(*) FROM silver.loads) AS total_loads,
    (SELECT COUNT_BIG(*) FROM silver.trips) AS total_trips,
    (SELECT COUNT_BIG(*) FROM silver.trips WHERE load_id IS NULL)
        AS trips_without_load_id,
    CAST(
        100.0 * (SELECT COUNT_BIG(*) FROM silver.trips WHERE load_id IS NULL)
        / NULLIF((SELECT COUNT_BIG(*) FROM silver.trips), 0)
        AS DECIMAL(5,2)
    ) AS trip_load_id_missingness_pct,
    (SELECT COUNT_BIG(DISTINCT load_id)
     FROM silver.trips WHERE load_id IS NOT NULL) AS distinct_trip_load_ids,
    (SELECT COUNT_BIG(*)
     FROM silver.trips AS t
     LEFT JOIN silver.loads AS l ON t.load_id = l.load_id
     WHERE t.load_id IS NOT NULL AND l.load_id IS NULL)
        AS trips_with_unmatched_load_id,
    (SELECT COUNT_BIG(*)
     FROM silver.loads AS l
     LEFT JOIN TripLoadCounts AS tlc ON l.load_id = tlc.load_id
     WHERE tlc.load_id IS NULL) AS loads_without_trips,
    (SELECT COUNT_BIG(*) FROM TripLoadCounts WHERE trip_count > 1)
        AS loads_with_multiple_trips;


/* ============================================================================
   02 — DELIVERY EVENTS-TO-TRIPS RELATIONSHIP

   Does every event reference a trip, and does each trip have one Pickup and
   one Delivery event?
   ============================================================================ */

WITH EventCounts AS
(
    SELECT
        trip_id,
        COUNT_BIG(*) AS total_events,
        SUM(CASE WHEN event_type = 'Pickup' THEN 1 ELSE 0 END) AS pickup_events,
        SUM(CASE WHEN event_type = 'Delivery' THEN 1 ELSE 0 END) AS delivery_events,
        COUNT(DISTINCT load_id) AS distinct_load_ids
    FROM silver.delivery_events
    GROUP BY trip_id
)
SELECT
    (SELECT COUNT_BIG(*) FROM silver.delivery_events) AS total_events,
    (SELECT COUNT_BIG(*) FROM silver.delivery_events WHERE trip_id IS NULL)
        AS events_without_trip_id,
    CAST(
        100.0 * (SELECT COUNT_BIG(*) FROM silver.delivery_events WHERE trip_id IS NULL)
        / NULLIF((SELECT COUNT_BIG(*) FROM silver.delivery_events), 0)
        AS DECIMAL(5,2)
    ) AS event_trip_id_missingness_pct,
    (SELECT COUNT_BIG(DISTINCT trip_id) FROM silver.delivery_events)
        AS distinct_event_trip_ids,
    (SELECT COUNT_BIG(*)
     FROM silver.delivery_events AS e
     LEFT JOIN silver.trips AS t ON e.trip_id = t.trip_id
     WHERE t.trip_id IS NULL) AS events_with_unmatched_trip_id,
    (SELECT COUNT_BIG(*)
     FROM silver.trips AS t
     LEFT JOIN EventCounts AS ec ON t.trip_id = ec.trip_id
     WHERE ec.trip_id IS NULL) AS trips_without_events,
    (SELECT COUNT_BIG(*) FROM EventCounts WHERE pickup_events <> 1)
        AS trips_without_exactly_one_pickup,
    (SELECT COUNT_BIG(*) FROM EventCounts WHERE delivery_events <> 1)
        AS trips_without_exactly_one_delivery,
    (SELECT COUNT_BIG(*) FROM EventCounts WHERE total_events <> 2)
        AS trips_without_exactly_two_events,
    (SELECT COUNT_BIG(*) FROM EventCounts WHERE distinct_load_ids <> 1)
        AS trips_with_multiple_or_missing_load_ids;


/* ============================================================================
   03 — DELIVERY EVENT LOAD ID VS TRIP LOAD ID

   Do event load IDs agree with the load ID on the associated trip?
   NULL event load IDs are counted separately, not as matches or mismatches.
   ============================================================================ */

SELECT
    COUNT_BIG(*) AS total_events,
    SUM(CASE WHEN e.load_id IS NULL THEN 1 ELSE 0 END) AS events_without_load_id,
    CAST(
        100.0 * SUM(CASE WHEN e.load_id IS NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT_BIG(*), 0)
        AS DECIMAL(5,2)
    ) AS event_load_id_missingness_pct,
    SUM(CASE WHEN e.load_id = t.load_id THEN 1 ELSE 0 END) AS matching_load_ids,
    SUM(CASE WHEN e.load_id <> t.load_id THEN 1 ELSE 0 END) AS mismatching_load_ids,
    SUM(CASE
        WHEN e.load_id IS NOT NULL AND t.load_id IS NULL THEN 1 ELSE 0
    END) AS events_with_load_but_trip_without_load
FROM silver.delivery_events AS e
INNER JOIN silver.trips AS t
    ON e.trip_id = t.trip_id;


/* ============================================================================
   04 — TRIPS-TO-TRAILERS RELATIONSHIP
   ============================================================================ */

WITH TrailerTripCounts AS
(
    SELECT trailer_id, COUNT_BIG(*) AS trip_count
    FROM silver.trips
    WHERE trailer_id IS NOT NULL
    GROUP BY trailer_id
)
SELECT
    (SELECT COUNT_BIG(*) FROM silver.trips) AS total_trips,
    (SELECT COUNT_BIG(*) FROM silver.trips WHERE trailer_id IS NULL)
        AS trips_without_trailer_id,
    CAST(
        100.0 * (SELECT COUNT_BIG(*) FROM silver.trips WHERE trailer_id IS NULL)
        / NULLIF((SELECT COUNT_BIG(*) FROM silver.trips), 0)
        AS DECIMAL(5,2)
    ) AS trip_trailer_id_missingness_pct,
    (SELECT COUNT_BIG(DISTINCT trailer_id)
     FROM silver.trips WHERE trailer_id IS NOT NULL) AS distinct_trailers_used,
    (SELECT COUNT_BIG(*)
     FROM silver.trips AS t
     LEFT JOIN silver.trailers AS tr ON t.trailer_id = tr.trailer_id
     WHERE t.trailer_id IS NOT NULL AND tr.trailer_id IS NULL)
        AS trips_with_unmatched_trailer_id,
    (SELECT COUNT_BIG(*)
     FROM silver.trailers AS tr
     LEFT JOIN TrailerTripCounts AS ttc ON tr.trailer_id = ttc.trailer_id
     WHERE ttc.trailer_id IS NULL) AS trailers_without_trips,
    (SELECT COUNT_BIG(*) FROM TrailerTripCounts WHERE trip_count > 1)
        AS trailers_used_on_multiple_trips;


/* ============================================================================
   05 — TRAILER TRIP DISTRIBUTION

   Descriptive distribution only; not proof of availability or utilization.
   ============================================================================ */

SELECT
    tr.trailer_id,
    COUNT_BIG(*) AS trip_count,
    SUM(t.actual_distance_miles) AS total_distance_miles,
    MIN(t.dispatch_date) AS first_trip_date,
    MAX(t.dispatch_date) AS last_trip_date
FROM silver.trips AS t
INNER JOIN silver.trailers AS tr ON t.trailer_id = tr.trailer_id
GROUP BY tr.trailer_id
ORDER BY trip_count DESC, tr.trailer_id;


/* ============================================================================
   06 — TRIPS-TO-DRIVERS RELATIONSHIP
   ============================================================================ */

WITH DriverTripCounts AS
(
    SELECT driver_id, COUNT_BIG(*) AS trip_count
    FROM silver.trips
    WHERE driver_id IS NOT NULL
    GROUP BY driver_id
)
SELECT
    (SELECT COUNT_BIG(*) FROM silver.trips) AS total_trips,
    (SELECT COUNT_BIG(*) FROM silver.trips WHERE driver_id IS NULL)
        AS trips_without_driver_id,
    CAST(
        100.0 * (SELECT COUNT_BIG(*) FROM silver.trips WHERE driver_id IS NULL)
        / NULLIF((SELECT COUNT_BIG(*) FROM silver.trips), 0)
        AS DECIMAL(5,2)
    ) AS trip_driver_id_missingness_pct,
    (SELECT COUNT_BIG(DISTINCT driver_id)
     FROM silver.trips WHERE driver_id IS NOT NULL) AS distinct_drivers_used,
    (SELECT COUNT_BIG(*)
     FROM silver.trips AS t
     LEFT JOIN silver.drivers AS d ON t.driver_id = d.driver_id
     WHERE t.driver_id IS NOT NULL AND d.driver_id IS NULL)
        AS trips_with_unmatched_driver_id,
    (SELECT COUNT_BIG(*)
     FROM silver.drivers AS d
     LEFT JOIN DriverTripCounts AS dtc ON d.driver_id = dtc.driver_id
     WHERE dtc.driver_id IS NULL) AS drivers_without_trips,
    (SELECT COUNT_BIG(*) FROM DriverTripCounts WHERE trip_count > 1)
        AS drivers_with_multiple_trips;


/* ============================================================================
   07 — TRIPS-TO-TRUCKS RELATIONSHIP
   ============================================================================ */

WITH TruckTripCounts AS
(
    SELECT truck_id, COUNT_BIG(*) AS trip_count
    FROM silver.trips
    WHERE truck_id IS NOT NULL
    GROUP BY truck_id
)
SELECT
    (SELECT COUNT_BIG(*) FROM silver.trips) AS total_trips,
    (SELECT COUNT_BIG(*) FROM silver.trips WHERE truck_id IS NULL)
        AS trips_without_truck_id,
    CAST(
        100.0 * (SELECT COUNT_BIG(*) FROM silver.trips WHERE truck_id IS NULL)
        / NULLIF((SELECT COUNT_BIG(*) FROM silver.trips), 0)
        AS DECIMAL(5,2)
    ) AS trip_truck_id_missingness_pct,
    (SELECT COUNT_BIG(DISTINCT truck_id)
     FROM silver.trips WHERE truck_id IS NOT NULL) AS distinct_trucks_used,
    (SELECT COUNT_BIG(*)
     FROM silver.trips AS t
     LEFT JOIN silver.trucks AS tr ON t.truck_id = tr.truck_id
     WHERE t.truck_id IS NOT NULL AND tr.truck_id IS NULL)
        AS trips_with_unmatched_truck_id,
    (SELECT COUNT_BIG(*)
     FROM silver.trucks AS tr
     LEFT JOIN TruckTripCounts AS ttc ON tr.truck_id = ttc.truck_id
     WHERE ttc.truck_id IS NULL) AS trucks_without_trips,
    (SELECT COUNT_BIG(*) FROM TruckTripCounts WHERE trip_count > 1)
        AS trucks_with_multiple_trips;


/* ============================================================================
   08 — LOADS-TO-ROUTES RELATIONSHIP

   Schema reminder: route_id is on silver.loads, not silver.trips.
   ============================================================================ */

WITH RouteLoadCounts AS
(
    SELECT route_id, COUNT_BIG(*) AS load_count
    FROM silver.loads
    WHERE route_id IS NOT NULL
    GROUP BY route_id
)
SELECT
    (SELECT COUNT_BIG(*) FROM silver.loads) AS total_loads,
    (SELECT COUNT_BIG(*) FROM silver.loads WHERE route_id IS NULL)
        AS loads_without_route_id,
    CAST(
        100.0 * (SELECT COUNT_BIG(*) FROM silver.loads WHERE route_id IS NULL)
        / NULLIF((SELECT COUNT_BIG(*) FROM silver.loads), 0)
        AS DECIMAL(5,2)
    ) AS load_route_id_missingness_pct,
    (SELECT COUNT_BIG(DISTINCT route_id)
     FROM silver.loads WHERE route_id IS NOT NULL) AS distinct_routes_used,
    (SELECT COUNT_BIG(*)
     FROM silver.loads AS l
     LEFT JOIN silver.routes AS r ON l.route_id = r.route_id
     WHERE l.route_id IS NOT NULL AND r.route_id IS NULL)
        AS loads_with_unmatched_route_id,
    (SELECT COUNT_BIG(*)
     FROM silver.routes AS r
     LEFT JOIN RouteLoadCounts AS rlc ON r.route_id = rlc.route_id
     WHERE rlc.route_id IS NULL) AS routes_without_loads,
    (SELECT COUNT_BIG(*) FROM RouteLoadCounts WHERE load_count > 1)
        AS routes_used_by_multiple_loads;


/* ============================================================================
   09 — LOADS-TO-CUSTOMERS RELATIONSHIP
   ============================================================================ */

WITH CustomerLoadCounts AS
(
    SELECT customer_id, COUNT_BIG(*) AS load_count
    FROM silver.loads
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
)
SELECT
    (SELECT COUNT_BIG(*) FROM silver.loads) AS total_loads,
    (SELECT COUNT_BIG(*) FROM silver.loads WHERE customer_id IS NULL)
        AS loads_without_customer_id,
    CAST(
        100.0 * (SELECT COUNT_BIG(*) FROM silver.loads WHERE customer_id IS NULL)
        / NULLIF((SELECT COUNT_BIG(*) FROM silver.loads), 0)
        AS DECIMAL(5,2)
    ) AS load_customer_id_missingness_pct,
    (SELECT COUNT_BIG(DISTINCT customer_id)
     FROM silver.loads WHERE customer_id IS NOT NULL) AS distinct_customers_used,
    (SELECT COUNT_BIG(*)
     FROM silver.loads AS l
     LEFT JOIN silver.customers AS c ON l.customer_id = c.customer_id
     WHERE l.customer_id IS NOT NULL AND c.customer_id IS NULL)
        AS loads_with_unmatched_customer_id,
    (SELECT COUNT_BIG(*)
     FROM silver.customers AS c
     LEFT JOIN CustomerLoadCounts AS clc ON c.customer_id = clc.customer_id
     WHERE clc.customer_id IS NULL) AS customers_without_loads,
    (SELECT COUNT_BIG(*) FROM CustomerLoadCounts WHERE load_count > 1)
        AS customers_with_multiple_loads;


/* ============================================================================
   10 — DELIVERY EVENTS-TO-FACILITIES RELATIONSHIP
   ============================================================================ */

WITH FacilityEventCounts AS
(
    SELECT facility_id, COUNT_BIG(*) AS event_count
    FROM silver.delivery_events
    WHERE facility_id IS NOT NULL
    GROUP BY facility_id
)
SELECT
    (SELECT COUNT_BIG(*) FROM silver.delivery_events) AS total_events,
    (SELECT COUNT_BIG(*) FROM silver.delivery_events WHERE facility_id IS NULL)
        AS events_without_facility_id,
    CAST(
        100.0 * (SELECT COUNT_BIG(*) FROM silver.delivery_events WHERE facility_id IS NULL)
        / NULLIF((SELECT COUNT_BIG(*) FROM silver.delivery_events), 0)
        AS DECIMAL(5,2)
    ) AS event_facility_id_missingness_pct,
    (SELECT COUNT_BIG(DISTINCT facility_id)
     FROM silver.delivery_events WHERE facility_id IS NOT NULL)
        AS distinct_facilities_used,
    (SELECT COUNT_BIG(*)
     FROM silver.delivery_events AS e
     LEFT JOIN silver.facilities AS f ON e.facility_id = f.facility_id
     WHERE e.facility_id IS NOT NULL AND f.facility_id IS NULL)
        AS events_with_unmatched_facility_id,
    (SELECT COUNT_BIG(*)
     FROM silver.facilities AS f
     LEFT JOIN FacilityEventCounts AS fec ON f.facility_id = fec.facility_id
     WHERE fec.facility_id IS NULL) AS facilities_without_events,
    (SELECT COUNT_BIG(*) FROM FacilityEventCounts WHERE event_count > 1)
        AS facilities_with_multiple_events;


/* ============================================================================
   11 — DELIVERY EVENT LOCATION VS FACILITY MASTER LOCATION

   Compare trimmed, case-insensitive city and state values.
   A mismatch is not automatically proof of an error; source semantics matter.
   ============================================================================ */

SELECT
    COUNT_BIG(*) AS total_events,
    SUM(CASE
        WHEN UPPER(LTRIM(RTRIM(e.location_city))) =
             UPPER(LTRIM(RTRIM(f.city)))
         AND UPPER(LTRIM(RTRIM(e.location_state))) =
             UPPER(LTRIM(RTRIM(f.state)))
        THEN 1 ELSE 0
    END) AS exact_location_matches,
    SUM(CASE
        WHEN UPPER(LTRIM(RTRIM(e.location_city))) <>
             UPPER(LTRIM(RTRIM(f.city)))
          OR UPPER(LTRIM(RTRIM(e.location_state))) <>
             UPPER(LTRIM(RTRIM(f.state)))
        THEN 1 ELSE 0
    END) AS location_mismatches,
    SUM(CASE
        WHEN e.location_city IS NULL
          OR e.location_state IS NULL
          OR f.city IS NULL
          OR f.state IS NULL
        THEN 1 ELSE 0
    END) AS records_with_missing_location_values,
    CAST(
        100.0 * SUM(CASE
            WHEN e.location_city IS NULL
              OR e.location_state IS NULL
              OR f.city IS NULL
              OR f.state IS NULL
            THEN 1 ELSE 0
        END) / NULLIF(COUNT_BIG(*), 0)
        AS DECIMAL(5,2)
    ) AS location_value_missingness_pct
FROM silver.delivery_events AS e
INNER JOIN silver.facilities AS f
    ON e.facility_id = f.facility_id;


/* ============================================================================
   12 — DETAIL OF MISMATCHED DELIVERY EVENT AND FACILITY LOCATIONS

   Output grain: event type, facility, and event-recorded city/state grouping.
   ============================================================================ */

SELECT
    e.event_type,
    e.facility_id,
    f.facility_name,
    f.city AS facility_city,
    f.state AS facility_state,
    e.location_city AS event_city,
    e.location_state AS event_state,
    COUNT_BIG(*) AS event_count
FROM silver.delivery_events AS e
INNER JOIN silver.facilities AS f
    ON e.facility_id = f.facility_id
WHERE
    UPPER(LTRIM(RTRIM(e.location_city))) <>
        UPPER(LTRIM(RTRIM(f.city)))
    OR
    UPPER(LTRIM(RTRIM(e.location_state))) <>
        UPPER(LTRIM(RTRIM(f.state)))
GROUP BY
    e.event_type,
    e.facility_id,
    f.facility_name,
    f.city,
    f.state,
    e.location_city,
    e.location_state
ORDER BY
    event_count DESC,
    e.facility_id,
    e.event_type;
