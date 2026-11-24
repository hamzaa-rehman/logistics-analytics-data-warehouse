/*
===============================================================================
GOLD LAYER - DATA AND STRUCTURAL VALIDATION
===============================================================================
Database: LogisticsAnalytics
Source:   silver
Target:   gold

Purpose:
    Validate the deployed Gold dimensional model and the loaded fact data.

Validation areas:
    1. Source-to-Gold row-count reconciliation for six dimensions and six facts.
    2. Primary-key constraint presence and enabled index status.
    3. Primary-key column inventory (single-column vs composite).
    4. Dimension business-key and surrogate-key completeness/uniqueness.
    5. Fact business-key completeness/uniqueness (fact grain check).
    6. Orphan checks across all 18 Gold fact-to-dimension relationships.
    7. Foreign-key enabled and trusted status.
    8. Fact-table column inventory for source-to-target measure review (diagnostic).

Important:
    - Run after gold.load_gold has completed successfully.
    - dim_date is generated in Gold and has no one-to-one Silver source table;
      it is intentionally excluded from source-to-target row-count checks.
    - NULL values in optional fact-to-dimension relationships are preserved
      and are not counted as orphan records.
    - Required fact date keys are NOT NULL in the deployed Gold DDL.
    - This script does not perform measure-level reconciliation. That work
      requires explicit source-to-target measure mapping and is a separate
      validation stage.

The results recorded in docs/gold/gold_validation.md are based on outputs
shared by the project owner.

The fact-table column inventory at the end is diagnostic metadata output; it
is not a PASS/FAIL test. Use it when reviewing source-to-target measure mappings.
===============================================================================
*/

USE LogisticsAnalytics;

-- ============================================================================
-- 1. SOURCE-TO-GOLD ROW-COUNT RECONCILIATION
--    Six source-backed dimensions and six fact tables.
--    dim_date is excluded because it is generated in Gold.
-- ============================================================================

WITH row_counts AS
(
    SELECT
        'customers -> dim_customer' AS table_name,
        (SELECT COUNT_BIG(*) FROM silver.customers) AS silver_rows,
        (SELECT COUNT_BIG(*) FROM gold.dim_customer) AS gold_rows

    UNION ALL

    SELECT
        'drivers -> dim_driver',
        (SELECT COUNT_BIG(*) FROM silver.drivers),
        (SELECT COUNT_BIG(*) FROM gold.dim_driver)

    UNION ALL

    SELECT
        'trucks -> dim_truck',
        (SELECT COUNT_BIG(*) FROM silver.trucks),
        (SELECT COUNT_BIG(*) FROM gold.dim_truck)

    UNION ALL

    SELECT
        'trailers -> dim_trailer',
        (SELECT COUNT_BIG(*) FROM silver.trailers),
        (SELECT COUNT_BIG(*) FROM gold.dim_trailer)

    UNION ALL

    SELECT
        'routes -> dim_route',
        (SELECT COUNT_BIG(*) FROM silver.routes),
        (SELECT COUNT_BIG(*) FROM gold.dim_route)

    UNION ALL

    SELECT
        'facilities -> dim_facility',
        (SELECT COUNT_BIG(*) FROM silver.facilities),
        (SELECT COUNT_BIG(*) FROM gold.dim_facility)

    UNION ALL

    SELECT
        'loads -> fact_loads',
        (SELECT COUNT_BIG(*) FROM silver.loads),
        (SELECT COUNT_BIG(*) FROM gold.fact_loads)

    UNION ALL

    SELECT
        'trips -> fact_trips',
        (SELECT COUNT_BIG(*) FROM silver.trips),
        (SELECT COUNT_BIG(*) FROM gold.fact_trips)

    UNION ALL

    SELECT
        'delivery_events -> fact_delivery_events',
        (SELECT COUNT_BIG(*) FROM silver.delivery_events),
        (SELECT COUNT_BIG(*) FROM gold.fact_delivery_events)

    UNION ALL

    SELECT
        'fuel_purchases -> fact_fuel_purchases',
        (SELECT COUNT_BIG(*) FROM silver.fuel_purchases),
        (SELECT COUNT_BIG(*) FROM gold.fact_fuel_purchases)

    UNION ALL

    SELECT
        'maintenance_records -> fact_maintenance_records',
        (SELECT COUNT_BIG(*) FROM silver.maintenance_records),
        (SELECT COUNT_BIG(*) FROM gold.fact_maintenance_records)

    UNION ALL

    SELECT
        'safety_incidents -> fact_safety_incidents',
        (SELECT COUNT_BIG(*) FROM silver.safety_incidents),
        (SELECT COUNT_BIG(*) FROM gold.fact_safety_incidents)
)
SELECT
    table_name,
    silver_rows,
    gold_rows,
    gold_rows - silver_rows AS row_difference,
    CASE
        WHEN silver_rows = gold_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM row_counts
ORDER BY table_name;


-- ============================================================================
-- 2. PRIMARY-KEY CONSTRAINT VALIDATION
--    Confirm every Gold table has an enabled, unique primary-key index.
-- ============================================================================

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    kc.name AS primary_key_name,
    i.name AS primary_key_index,
    i.is_disabled,
    i.is_hypothetical,
    i.is_unique,
    CASE
        WHEN kc.name IS NOT NULL
         AND i.is_disabled = 0
         AND i.is_hypothetical = 0
         AND i.is_unique = 1
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
LEFT JOIN sys.key_constraints AS kc
    ON t.object_id = kc.parent_object_id
   AND kc.type = 'PK'
LEFT JOIN sys.indexes AS i
    ON kc.parent_object_id = i.object_id
   AND kc.unique_index_id = i.index_id
WHERE s.name = 'gold'
ORDER BY t.name;


-- ============================================================================
-- 3. PRIMARY-KEY COLUMN INVENTORY
--    Diagnostic query to identify the exact PK columns and key ordinals.
-- ============================================================================

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    kc.name AS primary_key_name,
    c.name AS primary_key_column,
    ic.key_ordinal,
    COUNT(*) OVER
    (
        PARTITION BY t.object_id, kc.object_id
    ) AS total_pk_columns
FROM sys.key_constraints AS kc
INNER JOIN sys.tables AS t
    ON kc.parent_object_id = t.object_id
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
INNER JOIN sys.index_columns AS ic
    ON kc.parent_object_id = ic.object_id
   AND kc.unique_index_id = ic.index_id
INNER JOIN sys.columns AS c
    ON ic.object_id = c.object_id
   AND ic.column_id = c.column_id
WHERE s.name = 'gold'
  AND kc.type = 'PK'
  AND ic.key_ordinal > 0
ORDER BY
    t.name,
    ic.key_ordinal;


-- ============================================================================
-- 4. DIMENSION BUSINESS-KEY AND SURROGATE-KEY VALIDATION
--    Check NULLs and duplicate values in each dimension's business and
--    surrogate keys. dim_date uses full_date as its alternate business key.
-- ============================================================================

WITH dimension_key_checks AS
(
    SELECT
        'dim_customer' AS table_name,
        'customer_id' AS business_key,
        COUNT_BIG(*) AS total_rows,
        COUNT_BIG(customer_id) AS business_key_non_null,
        COUNT_BIG(DISTINCT customer_id) AS business_key_distinct,
        COUNT_BIG(customer_key) AS surrogate_key_non_null,
        COUNT_BIG(DISTINCT customer_key) AS surrogate_key_distinct
    FROM gold.dim_customer

    UNION ALL

    SELECT
        'dim_driver', 'driver_id',
        COUNT_BIG(*), COUNT_BIG(driver_id),
        COUNT_BIG(DISTINCT driver_id), COUNT_BIG(driver_key),
        COUNT_BIG(DISTINCT driver_key)
    FROM gold.dim_driver

    UNION ALL

    SELECT
        'dim_truck', 'truck_id',
        COUNT_BIG(*), COUNT_BIG(truck_id),
        COUNT_BIG(DISTINCT truck_id), COUNT_BIG(truck_key),
        COUNT_BIG(DISTINCT truck_key)
    FROM gold.dim_truck

    UNION ALL

    SELECT
        'dim_trailer', 'trailer_id',
        COUNT_BIG(*), COUNT_BIG(trailer_id),
        COUNT_BIG(DISTINCT trailer_id), COUNT_BIG(trailer_key),
        COUNT_BIG(DISTINCT trailer_key)
    FROM gold.dim_trailer

    UNION ALL

    SELECT
        'dim_route', 'route_id',
        COUNT_BIG(*), COUNT_BIG(route_id),
        COUNT_BIG(DISTINCT route_id), COUNT_BIG(route_key),
        COUNT_BIG(DISTINCT route_key)
    FROM gold.dim_route

    UNION ALL

    SELECT
        'dim_facility', 'facility_id',
        COUNT_BIG(*), COUNT_BIG(facility_id),
        COUNT_BIG(DISTINCT facility_id), COUNT_BIG(facility_key),
        COUNT_BIG(DISTINCT facility_key)
    FROM gold.dim_facility

    UNION ALL

    SELECT
        'dim_date', 'full_date',
        COUNT_BIG(*), COUNT_BIG(full_date),
        COUNT_BIG(DISTINCT full_date), COUNT_BIG(date_key),
        COUNT_BIG(DISTINCT date_key)
    FROM gold.dim_date
)
SELECT
    table_name,
    business_key,
    total_rows,
    total_rows - business_key_non_null AS business_key_nulls,
    business_key_non_null - business_key_distinct
        AS business_key_duplicate_rows,
    total_rows - surrogate_key_non_null AS surrogate_key_nulls,
    surrogate_key_non_null - surrogate_key_distinct
        AS surrogate_key_duplicate_rows,
    CASE
        WHEN business_key_non_null = total_rows
         AND business_key_distinct = total_rows
         AND surrogate_key_non_null = total_rows
         AND surrogate_key_distinct = total_rows
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM dimension_key_checks
ORDER BY table_name;


-- ============================================================================
-- 5. FACT BUSINESS-KEY UNIQUENESS / GRAIN VALIDATION
--    One source business identifier should identify one row in each fact.
-- ============================================================================

WITH fact_key_checks AS
(
    SELECT
        'fact_delivery_events' AS table_name,
        'event_id' AS business_key,
        COUNT_BIG(*) AS total_rows,
        COUNT_BIG(event_id) AS non_null_keys,
        COUNT_BIG(DISTINCT event_id) AS distinct_keys
    FROM gold.fact_delivery_events

    UNION ALL

    SELECT
        'fact_fuel_purchases', 'fuel_purchase_id',
        COUNT_BIG(*), COUNT_BIG(fuel_purchase_id),
        COUNT_BIG(DISTINCT fuel_purchase_id)
    FROM gold.fact_fuel_purchases

    UNION ALL

    SELECT
        'fact_loads', 'load_id',
        COUNT_BIG(*), COUNT_BIG(load_id),
        COUNT_BIG(DISTINCT load_id)
    FROM gold.fact_loads

    UNION ALL

    SELECT
        'fact_maintenance_records', 'maintenance_id',
        COUNT_BIG(*), COUNT_BIG(maintenance_id),
        COUNT_BIG(DISTINCT maintenance_id)
    FROM gold.fact_maintenance_records

    UNION ALL

    SELECT
        'fact_safety_incidents', 'incident_id',
        COUNT_BIG(*), COUNT_BIG(incident_id),
        COUNT_BIG(DISTINCT incident_id)
    FROM gold.fact_safety_incidents

    UNION ALL

    SELECT
        'fact_trips', 'trip_id',
        COUNT_BIG(*), COUNT_BIG(trip_id),
        COUNT_BIG(DISTINCT trip_id)
    FROM gold.fact_trips
)
SELECT
    table_name,
    business_key,
    total_rows,
    non_null_keys,
    distinct_keys,
    total_rows - non_null_keys AS null_keys,
    non_null_keys - distinct_keys AS duplicate_key_rows,
    CASE
        WHEN total_rows = non_null_keys
         AND non_null_keys = distinct_keys
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM fact_key_checks
ORDER BY table_name;


-- ============================================================================
-- 6. FOREIGN-KEY ORPHAN VALIDATION
--    Check all 18 fact-to-dimension relationships.
--    NULL optional relationships are intentionally excluded from orphan
--    counts; populated keys must resolve to a dimension row.
-- ============================================================================

WITH orphan_checks AS
(
    -- FACT LOADS: 3 relationships
    SELECT
        'fact_loads -> dim_customer' AS relationship_name,
        COUNT_BIG(*) AS orphan_rows
    FROM gold.fact_loads AS f
    LEFT JOIN gold.dim_customer AS d
        ON f.customer_key = d.customer_key
    WHERE f.customer_key IS NOT NULL
      AND d.customer_key IS NULL

    UNION ALL

    SELECT
        'fact_loads -> dim_route',
        COUNT_BIG(*)
    FROM gold.fact_loads AS f
    LEFT JOIN gold.dim_route AS d
        ON f.route_key = d.route_key
    WHERE f.route_key IS NOT NULL
      AND d.route_key IS NULL

    UNION ALL

    SELECT
        'fact_loads -> dim_date',
        COUNT_BIG(*)
    FROM gold.fact_loads AS f
    LEFT JOIN gold.dim_date AS d
        ON f.load_date_key = d.date_key
    WHERE f.load_date_key IS NOT NULL
      AND d.date_key IS NULL

    -- FACT TRIPS: 4 relationships
    UNION ALL

    SELECT
        'fact_trips -> dim_driver',
        COUNT_BIG(*)
    FROM gold.fact_trips AS f
    LEFT JOIN gold.dim_driver AS d
        ON f.driver_key = d.driver_key
    WHERE f.driver_key IS NOT NULL
      AND d.driver_key IS NULL

    UNION ALL

    SELECT
        'fact_trips -> dim_truck',
        COUNT_BIG(*)
    FROM gold.fact_trips AS f
    LEFT JOIN gold.dim_truck AS d
        ON f.truck_key = d.truck_key
    WHERE f.truck_key IS NOT NULL
      AND d.truck_key IS NULL

    UNION ALL

    SELECT
        'fact_trips -> dim_trailer',
        COUNT_BIG(*)
    FROM gold.fact_trips AS f
    LEFT JOIN gold.dim_trailer AS d
        ON f.trailer_key = d.trailer_key
    WHERE f.trailer_key IS NOT NULL
      AND d.trailer_key IS NULL

    UNION ALL

    SELECT
        'fact_trips -> dim_date',
        COUNT_BIG(*)
    FROM gold.fact_trips AS f
    LEFT JOIN gold.dim_date AS d
        ON f.dispatch_date_key = d.date_key
    WHERE f.dispatch_date_key IS NOT NULL
      AND d.date_key IS NULL

    -- FACT DELIVERY EVENTS: 3 relationships
    UNION ALL

    SELECT
        'fact_delivery_events -> dim_facility',
        COUNT_BIG(*)
    FROM gold.fact_delivery_events AS f
    LEFT JOIN gold.dim_facility AS d
        ON f.facility_key = d.facility_key
    WHERE f.facility_key IS NOT NULL
      AND d.facility_key IS NULL

    UNION ALL

    SELECT
        'fact_delivery_events -> dim_date (scheduled)',
        COUNT_BIG(*)
    FROM gold.fact_delivery_events AS f
    LEFT JOIN gold.dim_date AS d
        ON f.scheduled_date_key = d.date_key
    WHERE f.scheduled_date_key IS NOT NULL
      AND d.date_key IS NULL

    UNION ALL

    SELECT
        'fact_delivery_events -> dim_date (actual)',
        COUNT_BIG(*)
    FROM gold.fact_delivery_events AS f
    LEFT JOIN gold.dim_date AS d
        ON f.actual_date_key = d.date_key
    WHERE f.actual_date_key IS NOT NULL
      AND d.date_key IS NULL

    -- FACT FUEL PURCHASES: 3 relationships
    UNION ALL

    SELECT
        'fact_fuel_purchases -> dim_truck',
        COUNT_BIG(*)
    FROM gold.fact_fuel_purchases AS f
    LEFT JOIN gold.dim_truck AS d
        ON f.truck_key = d.truck_key
    WHERE f.truck_key IS NOT NULL
      AND d.truck_key IS NULL

    UNION ALL

    SELECT
        'fact_fuel_purchases -> dim_driver',
        COUNT_BIG(*)
    FROM gold.fact_fuel_purchases AS f
    LEFT JOIN gold.dim_driver AS d
        ON f.driver_key = d.driver_key
    WHERE f.driver_key IS NOT NULL
      AND d.driver_key IS NULL

    UNION ALL

    SELECT
        'fact_fuel_purchases -> dim_date',
        COUNT_BIG(*)
    FROM gold.fact_fuel_purchases AS f
    LEFT JOIN gold.dim_date AS d
        ON f.purchase_date_key = d.date_key
    WHERE f.purchase_date_key IS NOT NULL
      AND d.date_key IS NULL

    -- FACT MAINTENANCE RECORDS: 2 relationships
    UNION ALL

    SELECT
        'fact_maintenance_records -> dim_truck',
        COUNT_BIG(*)
    FROM gold.fact_maintenance_records AS f
    LEFT JOIN gold.dim_truck AS d
        ON f.truck_key = d.truck_key
    WHERE f.truck_key IS NOT NULL
      AND d.truck_key IS NULL

    UNION ALL

    SELECT
        'fact_maintenance_records -> dim_date',
        COUNT_BIG(*)
    FROM gold.fact_maintenance_records AS f
    LEFT JOIN gold.dim_date AS d
        ON f.maintenance_date_key = d.date_key
    WHERE f.maintenance_date_key IS NOT NULL
      AND d.date_key IS NULL

    -- FACT SAFETY INCIDENTS: 3 relationships
    UNION ALL

    SELECT
        'fact_safety_incidents -> dim_truck',
        COUNT_BIG(*)
    FROM gold.fact_safety_incidents AS f
    LEFT JOIN gold.dim_truck AS d
        ON f.truck_key = d.truck_key
    WHERE f.truck_key IS NOT NULL
      AND d.truck_key IS NULL

    UNION ALL

    SELECT
        'fact_safety_incidents -> dim_driver',
        COUNT_BIG(*)
    FROM gold.fact_safety_incidents AS f
    LEFT JOIN gold.dim_driver AS d
        ON f.driver_key = d.driver_key
    WHERE f.driver_key IS NOT NULL
      AND d.driver_key IS NULL

    UNION ALL

    SELECT
        'fact_safety_incidents -> dim_date',
        COUNT_BIG(*)
    FROM gold.fact_safety_incidents AS f
    LEFT JOIN gold.dim_date AS d
        ON f.incident_date_key = d.date_key
    WHERE f.incident_date_key IS NOT NULL
      AND d.date_key IS NULL
)
SELECT
    relationship_name,
    orphan_rows,
    CASE
        WHEN orphan_rows = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM orphan_checks
ORDER BY relationship_name;


-- ============================================================================
-- 7. FOREIGN-KEY CONSTRAINT STATUS VALIDATION
--    Confirm all Gold foreign keys are enabled and trusted.
-- ============================================================================

SELECT
    fk.name AS foreign_key_name,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS child_schema,
    OBJECT_NAME(fk.parent_object_id) AS child_table,
    OBJECT_NAME(fk.referenced_object_id) AS referenced_table,
    fk.is_disabled,
    fk.is_not_trusted,
    CASE
        WHEN fk.is_disabled = 0
         AND fk.is_not_trusted = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM sys.foreign_keys AS fk
WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = 'gold'
ORDER BY
    child_table,
    foreign_key_name;


-- ============================================================================
-- 8. FACT-TABLE COLUMN INVENTORY (DIAGNOSTIC)
--    Display the deployed fact-table columns and SQL Server data types.
--    This supports measure mapping and reconciliation planning; it does not
--    produce a PASS/FAIL result.
-- ============================================================================

SELECT
    t.name AS table_name,
    c.column_id,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
INNER JOIN sys.columns AS c
    ON t.object_id = c.object_id
WHERE s.name = 'gold'
  AND t.name LIKE 'fact[_]%'
ORDER BY
    t.name,
    c.column_id;
