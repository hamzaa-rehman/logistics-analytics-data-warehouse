/*
    Bronze Identifier Integrity Investigations
    -------------------------------------------
    These checks consolidate the targeted investigations performed against
    the current Bronze extract. They are read-only.

    Important interpretation:
      - Candidate keys are tested for non-NULL and uniqueness in this extract;
        this does not create or prove formal database constraints.
      - FK checks report NULL references separately from orphan references.
      - Repeated business identifiers are not automatically errors.
      - Composite-key checks use GROUP BY, avoiding CONCAT-based key collisions.
*/

USE LogisticsAnalytics;


SET NOCOUNT ON;

-------------------------------------------------------------------------------
-- 1. Candidate primary-key checks (12 columns)
-------------------------------------------------------------------------------
SELECT 'customers' AS table_name, 'customer_id' AS column_name,
       COUNT_BIG(*) AS total_rows,
       COUNT_BIG(customer_id) AS non_null_count,
       COUNT_BIG(*) - COUNT_BIG(customer_id) AS null_count,
       COUNT_BIG(DISTINCT customer_id) AS distinct_count,
       COUNT_BIG(customer_id) - COUNT_BIG(DISTINCT customer_id) AS duplicate_count
FROM bronze.customers
UNION ALL SELECT 'delivery_events','event_id',COUNT_BIG(*),COUNT_BIG(event_id),COUNT_BIG(*)-COUNT_BIG(event_id),COUNT_BIG(DISTINCT event_id),COUNT_BIG(event_id)-COUNT_BIG(DISTINCT event_id) FROM bronze.delivery_events
UNION ALL SELECT 'drivers','driver_id',COUNT_BIG(*),COUNT_BIG(driver_id),COUNT_BIG(*)-COUNT_BIG(driver_id),COUNT_BIG(DISTINCT driver_id),COUNT_BIG(driver_id)-COUNT_BIG(DISTINCT driver_id) FROM bronze.drivers
UNION ALL SELECT 'facilities','facility_id',COUNT_BIG(*),COUNT_BIG(facility_id),COUNT_BIG(*)-COUNT_BIG(facility_id),COUNT_BIG(DISTINCT facility_id),COUNT_BIG(facility_id)-COUNT_BIG(DISTINCT facility_id) FROM bronze.facilities
UNION ALL SELECT 'fuel_purchases','fuel_purchase_id',COUNT_BIG(*),COUNT_BIG(fuel_purchase_id),COUNT_BIG(*)-COUNT_BIG(fuel_purchase_id),COUNT_BIG(DISTINCT fuel_purchase_id),COUNT_BIG(fuel_purchase_id)-COUNT_BIG(DISTINCT fuel_purchase_id) FROM bronze.fuel_purchases
UNION ALL SELECT 'loads','load_id',COUNT_BIG(*),COUNT_BIG(load_id),COUNT_BIG(*)-COUNT_BIG(load_id),COUNT_BIG(DISTINCT load_id),COUNT_BIG(load_id)-COUNT_BIG(DISTINCT load_id) FROM bronze.loads
UNION ALL SELECT 'maintenance_records','maintenance_id',COUNT_BIG(*),COUNT_BIG(maintenance_id),COUNT_BIG(*)-COUNT_BIG(maintenance_id),COUNT_BIG(DISTINCT maintenance_id),COUNT_BIG(maintenance_id)-COUNT_BIG(DISTINCT maintenance_id) FROM bronze.maintenance_records
UNION ALL SELECT 'routes','route_id',COUNT_BIG(*),COUNT_BIG(route_id),COUNT_BIG(*)-COUNT_BIG(route_id),COUNT_BIG(DISTINCT route_id),COUNT_BIG(route_id)-COUNT_BIG(DISTINCT route_id) FROM bronze.routes
UNION ALL SELECT 'safety_incidents','incident_id',COUNT_BIG(*),COUNT_BIG(incident_id),COUNT_BIG(*)-COUNT_BIG(incident_id),COUNT_BIG(DISTINCT incident_id),COUNT_BIG(incident_id)-COUNT_BIG(DISTINCT incident_id) FROM bronze.safety_incidents
UNION ALL SELECT 'trailers','trailer_id',COUNT_BIG(*),COUNT_BIG(trailer_id),COUNT_BIG(*)-COUNT_BIG(trailer_id),COUNT_BIG(DISTINCT trailer_id),COUNT_BIG(trailer_id)-COUNT_BIG(DISTINCT trailer_id) FROM bronze.trailers
UNION ALL SELECT 'trips','trip_id',COUNT_BIG(*),COUNT_BIG(trip_id),COUNT_BIG(*)-COUNT_BIG(trip_id),COUNT_BIG(DISTINCT trip_id),COUNT_BIG(trip_id)-COUNT_BIG(DISTINCT trip_id) FROM bronze.trips
UNION ALL SELECT 'trucks','truck_id',COUNT_BIG(*),COUNT_BIG(truck_id),COUNT_BIG(*)-COUNT_BIG(truck_id),COUNT_BIG(DISTINCT truck_id),COUNT_BIG(truck_id)-COUNT_BIG(DISTINCT truck_id) FROM bronze.trucks
ORDER BY table_name, column_name;
-- null_count is calculated explicitly for every candidate identifier.

-------------------------------------------------------------------------------
-- 2. Foreign-key integrity checks (18 unique relationships)
--    NULL references are not counted as orphans.
-------------------------------------------------------------------------------
SELECT 'trips.driver_id -> drivers.driver_id' AS relationship,
       COUNT_BIG(*) AS total_rows, COUNT_BIG(c.driver_id) AS non_null_count,
       COUNT_BIG(*)-COUNT_BIG(c.driver_id) AS null_count,
       SUM(CASE WHEN c.driver_id IS NOT NULL AND p.driver_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) AS orphan_count
FROM bronze.trips c LEFT JOIN bronze.drivers p ON c.driver_id=p.driver_id
UNION ALL SELECT 'trips.load_id -> loads.load_id',COUNT_BIG(*),COUNT_BIG(c.load_id),COUNT_BIG(*)-COUNT_BIG(c.load_id),SUM(CASE WHEN c.load_id IS NOT NULL AND p.load_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.trips c LEFT JOIN bronze.loads p ON c.load_id=p.load_id
UNION ALL SELECT 'trips.truck_id -> trucks.truck_id',COUNT_BIG(*),COUNT_BIG(c.truck_id),COUNT_BIG(*)-COUNT_BIG(c.truck_id),SUM(CASE WHEN c.truck_id IS NOT NULL AND p.truck_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.trips c LEFT JOIN bronze.trucks p ON c.truck_id=p.truck_id
UNION ALL SELECT 'trips.trailer_id -> trailers.trailer_id',COUNT_BIG(*),COUNT_BIG(c.trailer_id),COUNT_BIG(*)-COUNT_BIG(c.trailer_id),SUM(CASE WHEN c.trailer_id IS NOT NULL AND p.trailer_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.trips c LEFT JOIN bronze.trailers p ON c.trailer_id=p.trailer_id
UNION ALL SELECT 'loads.customer_id -> customers.customer_id',COUNT_BIG(*),COUNT_BIG(c.customer_id),COUNT_BIG(*)-COUNT_BIG(c.customer_id),SUM(CASE WHEN c.customer_id IS NOT NULL AND p.customer_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.loads c LEFT JOIN bronze.customers p ON c.customer_id=p.customer_id
UNION ALL SELECT 'loads.route_id -> routes.route_id',COUNT_BIG(*),COUNT_BIG(c.route_id),COUNT_BIG(*)-COUNT_BIG(c.route_id),SUM(CASE WHEN c.route_id IS NOT NULL AND p.route_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.loads c LEFT JOIN bronze.routes p ON c.route_id=p.route_id
UNION ALL SELECT 'delivery_events.load_id -> loads.load_id',COUNT_BIG(*),COUNT_BIG(c.load_id),COUNT_BIG(*)-COUNT_BIG(c.load_id),SUM(CASE WHEN c.load_id IS NOT NULL AND p.load_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.delivery_events c LEFT JOIN bronze.loads p ON c.load_id=p.load_id
UNION ALL SELECT 'delivery_events.trip_id -> trips.trip_id',COUNT_BIG(*),COUNT_BIG(c.trip_id),COUNT_BIG(*)-COUNT_BIG(c.trip_id),SUM(CASE WHEN c.trip_id IS NOT NULL AND p.trip_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.delivery_events c LEFT JOIN bronze.trips p ON c.trip_id=p.trip_id
UNION ALL SELECT 'delivery_events.facility_id -> facilities.facility_id',COUNT_BIG(*),COUNT_BIG(c.facility_id),COUNT_BIG(*)-COUNT_BIG(c.facility_id),SUM(CASE WHEN c.facility_id IS NOT NULL AND p.facility_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.delivery_events c LEFT JOIN bronze.facilities p ON c.facility_id=p.facility_id
UNION ALL SELECT 'fuel_purchases.driver_id -> drivers.driver_id',COUNT_BIG(*),COUNT_BIG(c.driver_id),COUNT_BIG(*)-COUNT_BIG(c.driver_id),SUM(CASE WHEN c.driver_id IS NOT NULL AND p.driver_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.fuel_purchases c LEFT JOIN bronze.drivers p ON c.driver_id=p.driver_id
UNION ALL SELECT 'fuel_purchases.truck_id -> trucks.truck_id',COUNT_BIG(*),COUNT_BIG(c.truck_id),COUNT_BIG(*)-COUNT_BIG(c.truck_id),SUM(CASE WHEN c.truck_id IS NOT NULL AND p.truck_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.fuel_purchases c LEFT JOIN bronze.trucks p ON c.truck_id=p.truck_id
UNION ALL SELECT 'maintenance_records.truck_id -> trucks.truck_id',COUNT_BIG(*),COUNT_BIG(c.truck_id),COUNT_BIG(*)-COUNT_BIG(c.truck_id),SUM(CASE WHEN c.truck_id IS NOT NULL AND p.truck_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.maintenance_records c LEFT JOIN bronze.trucks p ON c.truck_id=p.truck_id
UNION ALL SELECT 'safety_incidents.driver_id -> drivers.driver_id',COUNT_BIG(*),COUNT_BIG(c.driver_id),COUNT_BIG(*)-COUNT_BIG(c.driver_id),SUM(CASE WHEN c.driver_id IS NOT NULL AND p.driver_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.safety_incidents c LEFT JOIN bronze.drivers p ON c.driver_id=p.driver_id
UNION ALL SELECT 'safety_incidents.truck_id -> trucks.truck_id',COUNT_BIG(*),COUNT_BIG(c.truck_id),COUNT_BIG(*)-COUNT_BIG(c.truck_id),SUM(CASE WHEN c.truck_id IS NOT NULL AND p.truck_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.safety_incidents c LEFT JOIN bronze.trucks p ON c.truck_id=p.truck_id
UNION ALL SELECT 'safety_incidents.trip_id -> trips.trip_id',COUNT_BIG(*),COUNT_BIG(c.trip_id),COUNT_BIG(*)-COUNT_BIG(c.trip_id),SUM(CASE WHEN c.trip_id IS NOT NULL AND p.trip_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.safety_incidents c LEFT JOIN bronze.trips p ON c.trip_id=p.trip_id
UNION ALL SELECT 'driver_monthly_metrics.driver_id -> drivers.driver_id',COUNT_BIG(*),COUNT_BIG(c.driver_id),COUNT_BIG(*)-COUNT_BIG(c.driver_id),SUM(CASE WHEN c.driver_id IS NOT NULL AND p.driver_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.driver_monthly_metrics c LEFT JOIN bronze.drivers p ON c.driver_id=p.driver_id
UNION ALL SELECT 'truck_utilization_metrics.truck_id -> trucks.truck_id',COUNT_BIG(*),COUNT_BIG(c.truck_id),COUNT_BIG(*)-COUNT_BIG(c.truck_id),SUM(CASE WHEN c.truck_id IS NOT NULL AND p.truck_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.truck_utilization_metrics c LEFT JOIN bronze.trucks p ON c.truck_id=p.truck_id
UNION ALL SELECT 'fuel_purchases.trip_id -> trips.trip_id',COUNT_BIG(*),COUNT_BIG(c.trip_id),COUNT_BIG(*)-COUNT_BIG(c.trip_id),SUM(CASE WHEN c.trip_id IS NOT NULL AND p.trip_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) FROM bronze.fuel_purchases c LEFT JOIN bronze.trips p ON c.trip_id=p.trip_id
ORDER BY relationship;

-------------------------------------------------------------------------------
-- 3. Business identifier uniqueness checks (6 columns)
-------------------------------------------------------------------------------
SELECT 'drivers' AS table_name,'license_number' AS column_name,COUNT_BIG(*) AS total_rows,COUNT_BIG(license_number) AS non_null_count,COUNT_BIG(DISTINCT license_number) AS distinct_count,COUNT_BIG(license_number)-COUNT_BIG(DISTINCT license_number) AS duplicate_count FROM bronze.drivers
UNION ALL SELECT 'fuel_purchases','fuel_card_number',COUNT_BIG(*),COUNT_BIG(fuel_card_number),COUNT_BIG(DISTINCT fuel_card_number),COUNT_BIG(fuel_card_number)-COUNT_BIG(DISTINCT fuel_card_number) FROM bronze.fuel_purchases
UNION ALL SELECT 'trailers','trailer_number',COUNT_BIG(*),COUNT_BIG(trailer_number),COUNT_BIG(DISTINCT trailer_number),COUNT_BIG(trailer_number)-COUNT_BIG(DISTINCT trailer_number) FROM bronze.trailers
UNION ALL SELECT 'trailers','vin',COUNT_BIG(*),COUNT_BIG(vin),COUNT_BIG(DISTINCT vin),COUNT_BIG(vin)-COUNT_BIG(DISTINCT vin) FROM bronze.trailers
UNION ALL SELECT 'trucks','unit_number',COUNT_BIG(*),COUNT_BIG(unit_number),COUNT_BIG(DISTINCT unit_number),COUNT_BIG(unit_number)-COUNT_BIG(DISTINCT unit_number) FROM bronze.trucks
UNION ALL SELECT 'trucks','vin',COUNT_BIG(*),COUNT_BIG(vin),COUNT_BIG(DISTINCT vin),COUNT_BIG(vin)-COUNT_BIG(DISTINCT vin) FROM bronze.trucks
ORDER BY table_name,column_name;

-------------------------------------------------------------------------------
-- 4. Trailer-number duplicates: inspect the actual records
-------------------------------------------------------------------------------
WITH DuplicateTrailerNumbers AS
(
    SELECT trailer_number
    FROM bronze.trailers
    WHERE trailer_number IS NOT NULL
    GROUP BY trailer_number
    HAVING COUNT_BIG(*) > 1
)
SELECT
    t.trailer_number,
    COUNT_BIG(*) AS occurrence_count,
    COUNT_BIG(DISTINCT t.trailer_id) AS distinct_trailer_ids
FROM bronze.trailers AS t
INNER JOIN DuplicateTrailerNumbers AS d
    ON d.trailer_number = t.trailer_number
GROUP BY t.trailer_number
ORDER BY t.trailer_number;

-- Return every record for every duplicated trailer number, not only values
-- identified during the earlier investigation.
WITH DuplicateTrailerNumbers AS
(
    SELECT trailer_number
    FROM bronze.trailers
    WHERE trailer_number IS NOT NULL
    GROUP BY trailer_number
    HAVING COUNT_BIG(*) > 1
)
SELECT
    t.trailer_id,
    t.trailer_number,
    t.vin,
    t.status,
    t.trailer_type,
    t.model_year
FROM bronze.trailers AS t
INNER JOIN DuplicateTrailerNumbers AS d
    ON d.trailer_number = t.trailer_number
ORDER BY t.trailer_number, t.trailer_id;

-------------------------------------------------------------------------------
-- 5. Composite-key checks
--    Duplicate groups and NULL components are reported separately.
-------------------------------------------------------------------------------

-- Driver-month: expected candidate grain is one row per driver per month.
SELECT driver_id, month, COUNT_BIG(*) AS rows_in_group
FROM bronze.driver_monthly_metrics
WHERE driver_id IS NOT NULL
  AND month IS NOT NULL
GROUP BY driver_id, month
HAVING COUNT_BIG(*) > 1
ORDER BY driver_id, month;

SELECT
    COUNT_BIG(*) AS total_rows,
    SUM(CASE WHEN driver_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) AS null_driver_id_rows,
    SUM(CASE WHEN month IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) AS null_month_rows
FROM bronze.driver_monthly_metrics;

-- Truck-month: expected candidate grain is one row per truck per month.
SELECT truck_id, month, COUNT_BIG(*) AS rows_in_group
FROM bronze.truck_utilization_metrics
WHERE truck_id IS NOT NULL
  AND month IS NOT NULL
GROUP BY truck_id, month
HAVING COUNT_BIG(*) > 1
ORDER BY truck_id, month;

SELECT
    COUNT_BIG(*) AS total_rows,
    SUM(CASE WHEN truck_id IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) AS null_truck_id_rows,
    SUM(CASE WHEN month IS NULL THEN CONVERT(BIGINT,1) ELSE 0 END) AS null_month_rows
FROM bronze.truck_utilization_metrics;

