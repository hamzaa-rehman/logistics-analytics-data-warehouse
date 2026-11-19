/*
    ============================================================
    SILVER LAYER - DATA VALIDATION
    ============================================================

    Purpose:
    Validate the integrity and completeness of data loaded
    from the Bronze layer into the Silver layer.

    Validation sections:
    1. Row count comparison
    2. Primary key validation
    3. Foreign key validation
    4. Data integrity checks

    Database: LogisticsAnalytics
    Source:   bronze
    Target:   silver
*/

USE LogisticsAnalytics;

/*
    ============================================================
    1. ROW COUNT VALIDATION
    ============================================================

    Compare the number of rows in each Bronze source table
    against its corresponding Silver destination table.

    Expected result:
    All 14 tables should have matching row counts.
*/

SELECT
    'customers' AS TableName,
    (SELECT COUNT_BIG(*) FROM bronze.customers) AS BronzeRows,
    (SELECT COUNT_BIG(*) FROM silver.customers) AS SilverRows

UNION ALL

SELECT
    'delivery_events',
    (SELECT COUNT_BIG(*) FROM bronze.delivery_events),
    (SELECT COUNT_BIG(*) FROM silver.delivery_events)

UNION ALL

SELECT
    'driver_monthly_metrics',
    (SELECT COUNT_BIG(*) FROM bronze.driver_monthly_metrics),
    (SELECT COUNT_BIG(*) FROM silver.driver_monthly_metrics)

UNION ALL

SELECT
    'drivers',
    (SELECT COUNT_BIG(*) FROM bronze.drivers),
    (SELECT COUNT_BIG(*) FROM silver.drivers)

UNION ALL

SELECT
    'facilities',
    (SELECT COUNT_BIG(*) FROM bronze.facilities),
    (SELECT COUNT_BIG(*) FROM silver.facilities)

UNION ALL

SELECT
    'fuel_purchases',
    (SELECT COUNT_BIG(*) FROM bronze.fuel_purchases),
    (SELECT COUNT_BIG(*) FROM silver.fuel_purchases)

UNION ALL

SELECT
    'loads',
    (SELECT COUNT_BIG(*) FROM bronze.loads),
    (SELECT COUNT_BIG(*) FROM silver.loads)

UNION ALL

SELECT
    'maintenance_records',
    (SELECT COUNT_BIG(*) FROM bronze.maintenance_records),
    (SELECT COUNT_BIG(*) FROM silver.maintenance_records)

UNION ALL

SELECT
    'routes',
    (SELECT COUNT_BIG(*) FROM bronze.routes),
    (SELECT COUNT_BIG(*) FROM silver.routes)

UNION ALL

SELECT
    'safety_incidents',
    (SELECT COUNT_BIG(*) FROM bronze.safety_incidents),
    (SELECT COUNT_BIG(*) FROM silver.safety_incidents)

UNION ALL

SELECT
    'trailers',
    (SELECT COUNT_BIG(*) FROM bronze.trailers),
    (SELECT COUNT_BIG(*) FROM silver.trailers)

UNION ALL

SELECT
    'trips',
    (SELECT COUNT_BIG(*) FROM bronze.trips),
    (SELECT COUNT_BIG(*) FROM silver.trips)

UNION ALL

SELECT
    'truck_utilization_metrics',
    (SELECT COUNT_BIG(*) FROM bronze.truck_utilization_metrics),
    (SELECT COUNT_BIG(*) FROM silver.truck_utilization_metrics)

UNION ALL

SELECT
    'trucks',
    (SELECT COUNT_BIG(*) FROM bronze.trucks),
    (SELECT COUNT_BIG(*) FROM silver.trucks);


/*
    ============================================================
    2. PRIMARY KEY VALIDATION
    ============================================================

    Checks:
    1. NULL values in primary-key columns.
    2. Duplicate primary-key values or combinations.

    Expected result:
    NULL key rows = 0
    Duplicate key groups = 0
*/

SELECT
    'customers' AS TableName,
    (SELECT COUNT_BIG(*) FROM silver.customers
     WHERE customer_id IS NULL) AS NullKeyRows,
    (SELECT COUNT_BIG(*) FROM (
        SELECT customer_id
        FROM silver.customers
        GROUP BY customer_id
        HAVING COUNT_BIG(*) > 1
    ) d) AS DuplicateKeyGroups

UNION ALL

SELECT
    'delivery_events',
    (SELECT COUNT_BIG(*) FROM silver.delivery_events
     WHERE event_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT event_id
        FROM silver.delivery_events
        GROUP BY event_id
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'driver_monthly_metrics',
    (SELECT COUNT_BIG(*) FROM silver.driver_monthly_metrics
     WHERE driver_id IS NULL OR [month] IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT driver_id, [month]
        FROM silver.driver_monthly_metrics
        GROUP BY driver_id, [month]
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'drivers',
    (SELECT COUNT_BIG(*) FROM silver.drivers
     WHERE driver_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT driver_id
        FROM silver.drivers
        GROUP BY driver_id
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'facilities',
    (SELECT COUNT_BIG(*) FROM silver.facilities
     WHERE facility_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT facility_id
        FROM silver.facilities
        GROUP BY facility_id
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'fuel_purchases',
    (SELECT COUNT_BIG(*) FROM silver.fuel_purchases
     WHERE fuel_purchase_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT fuel_purchase_id
        FROM silver.fuel_purchases
        GROUP BY fuel_purchase_id
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'loads',
    (SELECT COUNT_BIG(*) FROM silver.loads
     WHERE load_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT load_id
        FROM silver.loads
        GROUP BY load_id
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'maintenance_records',
    (SELECT COUNT_BIG(*) FROM silver.maintenance_records
     WHERE maintenance_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT maintenance_id
        FROM silver.maintenance_records
        GROUP BY maintenance_id
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'routes',
    (SELECT COUNT_BIG(*) FROM silver.routes
     WHERE route_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT route_id
        FROM silver.routes
        GROUP BY route_id
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'safety_incidents',
    (SELECT COUNT_BIG(*) FROM silver.safety_incidents
     WHERE incident_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT incident_id
        FROM silver.safety_incidents
        GROUP BY incident_id
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'trailers',
    (SELECT COUNT_BIG(*) FROM silver.trailers
     WHERE trailer_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT trailer_id
        FROM silver.trailers
        GROUP BY trailer_id
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'trips',
    (SELECT COUNT_BIG(*) FROM silver.trips
     WHERE trip_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT trip_id
        FROM silver.trips
        GROUP BY trip_id
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'truck_utilization_metrics',
    (SELECT COUNT_BIG(*) FROM silver.truck_utilization_metrics
     WHERE truck_id IS NULL OR [month] IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT truck_id, [month]
        FROM silver.truck_utilization_metrics
        GROUP BY truck_id, [month]
        HAVING COUNT_BIG(*) > 1
    ) d)

UNION ALL

SELECT
    'trucks',
    (SELECT COUNT_BIG(*) FROM silver.trucks
     WHERE truck_id IS NULL),
    (SELECT COUNT_BIG(*) FROM (
        SELECT truck_id
        FROM silver.trucks
        GROUP BY truck_id
        HAVING COUNT_BIG(*) > 1
    ) d);

/*
===============================================================================
SECTION 3: FOREIGN KEY ORPHAN VALIDATION
===============================================================================
Purpose:
    Identify foreign key values in Silver child tables that do not have
    a matching primary key in their parent tables.

Expected Result:
    OrphanRows = 0 for all 18 foreign key relationships.
===============================================================================
*/

SELECT
    'FK_delivery_events_facilities' AS ForeignKeyName,
    'delivery_events' AS ChildTable,
    'facilities' AS ParentTable,
    COUNT_BIG(*) AS OrphanRows
FROM silver.delivery_events c
WHERE c.facility_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.facilities p
      WHERE p.facility_id = c.facility_id
  )

UNION ALL

SELECT
    'FK_delivery_events_loads',
    'delivery_events',
    'loads',
    COUNT_BIG(*)
FROM silver.delivery_events c
WHERE c.load_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.loads p
      WHERE p.load_id = c.load_id
  )

UNION ALL

SELECT
    'FK_delivery_events_trips',
    'delivery_events',
    'trips',
    COUNT_BIG(*)
FROM silver.delivery_events c
WHERE c.trip_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.trips p
      WHERE p.trip_id = c.trip_id
  )

UNION ALL

SELECT
    'FK_driver_monthly_metrics_drivers',
    'driver_monthly_metrics',
    'drivers',
    COUNT_BIG(*)
FROM silver.driver_monthly_metrics c
WHERE c.driver_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.drivers p
      WHERE p.driver_id = c.driver_id
  )

UNION ALL

SELECT
    'FK_fuel_purchases_drivers',
    'fuel_purchases',
    'drivers',
    COUNT_BIG(*)
FROM silver.fuel_purchases c
WHERE c.driver_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.drivers p
      WHERE p.driver_id = c.driver_id
  )

UNION ALL

SELECT
    'FK_fuel_purchases_trips',
    'fuel_purchases',
    'trips',
    COUNT_BIG(*)
FROM silver.fuel_purchases c
WHERE c.trip_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.trips p
      WHERE p.trip_id = c.trip_id
  )

UNION ALL

SELECT
    'FK_fuel_purchases_trucks',
    'fuel_purchases',
    'trucks',
    COUNT_BIG(*)
FROM silver.fuel_purchases c
WHERE c.truck_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.trucks p
      WHERE p.truck_id = c.truck_id
  )

UNION ALL

SELECT
    'FK_loads_customers',
    'loads',
    'customers',
    COUNT_BIG(*)
FROM silver.loads c
WHERE c.customer_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.customers p
      WHERE p.customer_id = c.customer_id
  )

UNION ALL

SELECT
    'FK_loads_routes',
    'loads',
    'routes',
    COUNT_BIG(*)
FROM silver.loads c
WHERE c.route_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.routes p
      WHERE p.route_id = c.route_id
  )

UNION ALL

SELECT
    'FK_maintenance_records_trucks',
    'maintenance_records',
    'trucks',
    COUNT_BIG(*)
FROM silver.maintenance_records c
WHERE c.truck_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.trucks p
      WHERE p.truck_id = c.truck_id
  )

UNION ALL

SELECT
    'FK_safety_incidents_drivers',
    'safety_incidents',
    'drivers',
    COUNT_BIG(*)
FROM silver.safety_incidents c
WHERE c.driver_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.drivers p
      WHERE p.driver_id = c.driver_id
  )

UNION ALL

SELECT
    'FK_safety_incidents_trips',
    'safety_incidents',
    'trips',
    COUNT_BIG(*)
FROM silver.safety_incidents c
WHERE c.trip_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.trips p
      WHERE p.trip_id = c.trip_id
  )

UNION ALL

SELECT
    'FK_safety_incidents_trucks',
    'safety_incidents',
    'trucks',
    COUNT_BIG(*)
FROM silver.safety_incidents c
WHERE c.truck_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.trucks p
      WHERE p.truck_id = c.truck_id
  )

UNION ALL

SELECT
    'FK_trips_drivers',
    'trips',
    'drivers',
    COUNT_BIG(*)
FROM silver.trips c
WHERE c.driver_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.drivers p
      WHERE p.driver_id = c.driver_id
  )

UNION ALL

SELECT
    'FK_trips_loads',
    'trips',
    'loads',
    COUNT_BIG(*)
FROM silver.trips c
WHERE c.load_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.loads p
      WHERE p.load_id = c.load_id
  )

UNION ALL

SELECT
    'FK_trips_trailers',
    'trips',
    'trailers',
    COUNT_BIG(*)
FROM silver.trips c
WHERE c.trailer_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.trailers p
      WHERE p.trailer_id = c.trailer_id
  )

UNION ALL

SELECT
    'FK_trips_trucks',
    'trips',
    'trucks',
    COUNT_BIG(*)
FROM silver.trips c
WHERE c.truck_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.trucks p
      WHERE p.truck_id = c.truck_id
  )

UNION ALL

SELECT
    'FK_truck_utilization_metrics_trucks',
    'truck_utilization_metrics',
    'trucks',
    COUNT_BIG(*)
FROM silver.truck_utilization_metrics c
WHERE c.truck_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM silver.trucks p
      WHERE p.truck_id = c.truck_id
  );

/*
===============================================================================
SECTION 4: CONSTRAINT STATUS VALIDATION
===============================================================================
Purpose:
    Verify that all Silver primary key and foreign key constraints
    are enabled and that foreign keys are trusted.

Expected Result:
    14 enabled primary keys.
    18 enabled and trusted foreign keys.
===============================================================================
*/

-- Primary key constraint status
SELECT
    kc.name AS ConstraintName,
    'PRIMARY KEY' AS ConstraintType,
    s.name AS SchemaName,
    t.name AS TableName,
    i.is_disabled AS IsDisabled,
    CAST(NULL AS BIT) AS IsNotTrusted,
    CASE
        WHEN i.is_disabled = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS ValidationStatus
FROM sys.key_constraints kc
INNER JOIN sys.tables t
    ON kc.parent_object_id = t.object_id
INNER JOIN sys.schemas s
    ON t.schema_id = s.schema_id
INNER JOIN sys.indexes i
    ON kc.parent_object_id = i.object_id
    AND kc.unique_index_id = i.index_id
WHERE kc.type = 'PK'
  AND s.name = 'silver'

UNION ALL

-- Foreign key constraint status
SELECT
    fk.name AS ConstraintName,
    'FOREIGN KEY' AS ConstraintType,
    s.name AS SchemaName,
    t.name AS TableName,
    fk.is_disabled AS IsDisabled,
    fk.is_not_trusted AS IsNotTrusted,
    CASE
        WHEN fk.is_disabled = 0
         AND fk.is_not_trusted = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS ValidationStatus
FROM sys.foreign_keys fk
INNER JOIN sys.tables t
    ON fk.parent_object_id = t.object_id
INNER JOIN sys.schemas s
    ON t.schema_id = s.schema_id
WHERE s.name = 'silver'

ORDER BY
    ConstraintType,
    TableName,
    ConstraintName;

/*
===============================================================================
SECTION 5: BRONZE-TO-SILVER PRIMARY KEY RECONCILIATION
===============================================================================
Purpose:
    Verify that every transformed Bronze primary key exists in Silver
    and every Silver primary key exists in Bronze.

Expected Result:
    MissingInSilver = 0
    MissingInBronze = 0

Note:
    Key transformations mirror silver.load_silver.
    Composite keys are compared using both key columns.
===============================================================================
*/

-- Single-column primary keys

SELECT 'customers' AS TableName,
       'Missing in Silver' AS CheckType,
       COUNT_BIG(*) AS IssueCount
FROM bronze.customers b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.customers s
    WHERE s.customer_id = TRIM(b.customer_id)
)

UNION ALL

SELECT 'customers', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.customers s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.customers b
    WHERE s.customer_id = TRIM(b.customer_id)
)

UNION ALL

SELECT 'delivery_events', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.delivery_events b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.delivery_events s
    WHERE s.event_id = TRIM(b.event_id)
)

UNION ALL

SELECT 'delivery_events', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.delivery_events s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.delivery_events b
    WHERE s.event_id = TRIM(b.event_id)
)

UNION ALL

SELECT 'drivers', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.drivers b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.drivers s
    WHERE s.driver_id = TRIM(b.driver_id)
)

UNION ALL

SELECT 'drivers', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.drivers s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.drivers b
    WHERE s.driver_id = TRIM(b.driver_id)
)

UNION ALL

SELECT 'facilities', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.facilities b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.facilities s
    WHERE s.facility_id = TRIM(b.facility_id)
)

UNION ALL

SELECT 'facilities', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.facilities s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.facilities b
    WHERE s.facility_id = TRIM(b.facility_id)
)

UNION ALL

SELECT 'fuel_purchases', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.fuel_purchases b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.fuel_purchases s
    WHERE s.fuel_purchase_id = TRIM(b.fuel_purchase_id)
)

UNION ALL

SELECT 'fuel_purchases', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.fuel_purchases s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.fuel_purchases b
    WHERE s.fuel_purchase_id = TRIM(b.fuel_purchase_id)
)

UNION ALL

SELECT 'loads', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.loads b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.loads s
    WHERE s.load_id = TRIM(b.load_id)
)

UNION ALL

SELECT 'loads', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.loads s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.loads b
    WHERE s.load_id = TRIM(b.load_id)
)

UNION ALL

SELECT 'maintenance_records', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.maintenance_records b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.maintenance_records s
    WHERE s.maintenance_id = TRIM(b.maintenance_id)
)

UNION ALL

SELECT 'maintenance_records', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.maintenance_records s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.maintenance_records b
    WHERE s.maintenance_id = TRIM(b.maintenance_id)
)

UNION ALL

SELECT 'routes', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.routes b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.routes s
    WHERE s.route_id = TRIM(b.route_id)
)

UNION ALL

SELECT 'routes', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.routes s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.routes b
    WHERE s.route_id = TRIM(b.route_id)
)

UNION ALL

SELECT 'safety_incidents', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.safety_incidents b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.safety_incidents s
    WHERE s.incident_id = TRIM(b.incident_id)
)

UNION ALL

SELECT 'safety_incidents', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.safety_incidents s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.safety_incidents b
    WHERE s.incident_id = TRIM(b.incident_id)
)

UNION ALL

SELECT 'trailers', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.trailers b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.trailers s
    WHERE s.trailer_id = TRIM(b.trailer_id)
)

UNION ALL

SELECT 'trailers', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.trailers s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.trailers b
    WHERE s.trailer_id = TRIM(b.trailer_id)
)

UNION ALL

SELECT 'trips', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.trips b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.trips s
    WHERE s.trip_id = TRIM(b.trip_id)
)

UNION ALL

SELECT 'trips', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.trips s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.trips b
    WHERE s.trip_id = TRIM(b.trip_id)
)

UNION ALL

SELECT 'trucks', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.trucks b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.trucks s
    WHERE s.truck_id = TRIM(b.truck_id)
)

UNION ALL

SELECT 'trucks', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.trucks s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.trucks b
    WHERE s.truck_id = TRIM(b.truck_id)
)

-- Composite primary key: driver_monthly_metrics

UNION ALL

SELECT 'driver_monthly_metrics', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.driver_monthly_metrics b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.driver_monthly_metrics s
    WHERE s.driver_id = TRIM(b.driver_id)
      AND s.[month] = CONVERT(DATE, NULLIF(TRIM(b.[month]), ''), 23)
)

UNION ALL

SELECT 'driver_monthly_metrics', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.driver_monthly_metrics s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.driver_monthly_metrics b
    WHERE s.driver_id = TRIM(b.driver_id)
      AND s.[month] = CONVERT(DATE, NULLIF(TRIM(b.[month]), ''), 23)
)

-- Composite primary key: truck_utilization_metrics

UNION ALL

SELECT 'truck_utilization_metrics', 'Missing in Silver', COUNT_BIG(*)
FROM bronze.truck_utilization_metrics b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.truck_utilization_metrics s
    WHERE s.truck_id = TRIM(b.truck_id)
      AND s.[month] = CONVERT(DATE, NULLIF(TRIM(b.[month]), ''), 23)
)

UNION ALL

SELECT 'truck_utilization_metrics', 'Missing in Bronze', COUNT_BIG(*)
FROM silver.truck_utilization_metrics s
WHERE NOT EXISTS (
    SELECT 1
    FROM bronze.truck_utilization_metrics b
    WHERE s.truck_id = TRIM(b.truck_id)
      AND s.[month] = CONVERT(DATE, NULLIF(TRIM(b.[month]), ''), 23)
)

ORDER BY TableName, CheckType;

/*
===============================================================================
SECTION 6: TARGETED TRANSFORMATION VALIDATION
===============================================================================
Purpose:
    Validate selected transformations and approved data-handling decisions.

Expected Result:
    IssueCount = 0 for every check.
===============================================================================
*/

-- 1. Validate trips.dispatch_date conversion

SELECT
    'trips.dispatch_date' AS CheckName,
    COUNT_BIG(*) AS IssueCount
FROM bronze.trips b
INNER JOIN silver.trips s
    ON s.trip_id = TRIM(b.trip_id)
WHERE
       s.dispatch_date <> CONVERT(DATE, NULLIF(TRIM(b.dispatch_date), ''), 23)
    OR (s.dispatch_date IS NULL
        AND CONVERT(DATE, NULLIF(TRIM(b.dispatch_date), ''), 23) IS NOT NULL)
    OR (s.dispatch_date IS NOT NULL
        AND CONVERT(DATE, NULLIF(TRIM(b.dispatch_date), ''), 23) IS NULL)

UNION ALL

-- 2. Validate renamed utilization column and numeric conversion

SELECT
    'truck_utilization_metrics.trips_per_day' AS CheckName,
    COUNT_BIG(*) AS IssueCount
FROM bronze.truck_utilization_metrics b
INNER JOIN silver.truck_utilization_metrics s
    ON s.truck_id = TRIM(b.truck_id)
   AND s.[month] = CONVERT(DATE, NULLIF(TRIM(b.[month]), ''), 23)
WHERE
       s.trips_per_day <> CONVERT(DECIMAL(6,4), NULLIF(TRIM(b.utilization_rate), ''))
    OR (s.trips_per_day IS NULL
        AND CONVERT(DECIMAL(6,4), NULLIF(TRIM(b.utilization_rate), '')) IS NOT NULL)
    OR (s.trips_per_day IS NOT NULL
        AND CONVERT(DECIMAL(6,4), NULLIF(TRIM(b.utilization_rate), '')) IS NULL)

UNION ALL

-- 3. Validate nullable fuel_purchases.truck_id handling

SELECT
    'fuel_purchases.truck_id NULL handling' AS CheckName,
    COUNT_BIG(*) AS IssueCount
FROM bronze.fuel_purchases b
INNER JOIN silver.fuel_purchases s
    ON s.fuel_purchase_id = TRIM(b.fuel_purchase_id)
WHERE
       (s.truck_id IS NULL
        AND NULLIF(TRIM(b.truck_id), '') IS NOT NULL)
    OR (s.truck_id IS NOT NULL
        AND NULLIF(TRIM(b.truck_id), '') IS NULL);
