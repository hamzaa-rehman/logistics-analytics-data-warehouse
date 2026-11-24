/*
===============================================================================
 Stored Procedure: Load Gold Layer (Silver -> Gold)
===============================================================================
Purpose:
    Full-refresh load of the six Gold dimensions and six Gold fact tables.

Process:
    1. Begin one transaction.
    2. Delete Gold facts, then source-based dimensions.
    3. Load dimensions and generate surrogate keys.
    4. Validate source-to-dimension lookups and required date keys.
    5. Load facts at their defined source grain.
    6. Commit and report row counts and duration.

Important:
    - gold.dim_date is populated by ddl_gold.sql and is preserved.
    - Optional source relationships remain NULL.
    - Populated but unresolved dimension keys stop the load.
    - Each fact is loaded independently; no fact-to-fact joins.
    - Run this script to create/alter and execute the procedure.

Database: LogisticsAnalytics
Source:   silver
Target:   gold
===============================================================================
*/

USE LogisticsAnalytics;
GO

CREATE OR ALTER PROCEDURE gold.load_gold
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @BatchStartTime DATETIME2 = SYSDATETIME();
    DECLARE @RowsInserted BIGINT;
    DECLARE @TotalRows BIGINT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- =====================================================
        -- 1. DELETE EXISTING GOLD DATA
        -- Facts first, then dimensions. Preserve dim_date.
        -- =====================================================

        DELETE FROM gold.fact_delivery_events;
        DELETE FROM gold.fact_safety_incidents;
        DELETE FROM gold.fact_fuel_purchases;
        DELETE FROM gold.fact_maintenance_records;
        DELETE FROM gold.fact_trips;
        DELETE FROM gold.fact_loads;

        DELETE FROM gold.dim_customer;
        DELETE FROM gold.dim_driver;
        DELETE FROM gold.dim_truck;
        DELETE FROM gold.dim_trailer;
        DELETE FROM gold.dim_route;
        DELETE FROM gold.dim_facility;

        -- =====================================================
        -- 2. LOAD DIMENSIONS
        -- =====================================================

        INSERT INTO gold.dim_customer
        (
            customer_id, customer_name, customer_type, credit_terms_days,
            primary_freight_type, account_status, contract_start_date,
            annual_revenue_potential
        )
        SELECT
            customer_id, customer_name, customer_type, credit_terms_days,
            primary_freight_type, account_status, contract_start_date,
            annual_revenue_potential
        FROM silver.customers;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'dim_customer: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        INSERT INTO gold.dim_driver
        (
            driver_id, first_name, last_name, hire_date, termination_date,
            license_state, home_terminal, employment_status, cdl_class,
            years_experience
        )
        SELECT
            driver_id, first_name, last_name, hire_date, termination_date,
            license_state, home_terminal, employment_status, cdl_class,
            years_experience
        FROM silver.drivers;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'dim_driver: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        INSERT INTO gold.dim_truck
        (
            truck_id, unit_number, make, model_year, vin, acquisition_date,
            acquisition_mileage, fuel_type, tank_capacity_gallons, status,
            home_terminal
        )
        SELECT
            truck_id, unit_number, make, model_year, vin, acquisition_date,
            acquisition_mileage, fuel_type, tank_capacity_gallons, status,
            home_terminal
        FROM silver.trucks;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'dim_truck: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        INSERT INTO gold.dim_trailer
        (
            trailer_id, trailer_number, trailer_type, length_feet, model_year,
            vin, acquisition_date, status, current_location
        )
        SELECT
            trailer_id, trailer_number, trailer_type, length_feet, model_year,
            vin, acquisition_date, status, current_location
        FROM silver.trailers;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'dim_trailer: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        INSERT INTO gold.dim_route
        (
            route_id, origin_city, origin_state, destination_city,
            destination_state, typical_distance_miles, base_rate_per_mile,
            fuel_surcharge_rate, typical_transit_days
        )
        SELECT
            route_id, origin_city, origin_state, destination_city,
            destination_state, typical_distance_miles, base_rate_per_mile,
            fuel_surcharge_rate, typical_transit_days
        FROM silver.routes;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'dim_route: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        INSERT INTO gold.dim_facility
        (
            facility_id, facility_name, facility_type, city, state, latitude,
            longitude, dock_doors, operating_hours
        )
        SELECT
            facility_id, facility_name, facility_type, city, state, latitude,
            longitude, dock_doors, operating_hours
        FROM silver.facilities;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'dim_facility: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        -- =====================================================
        -- 3. LOAD FACT: LOADS
        -- Grain: one row per load.
        -- =====================================================

        IF EXISTS
        (
            SELECT 1
            FROM silver.loads AS s
            LEFT JOIN gold.dim_customer AS d
                ON s.customer_id = d.customer_id
            WHERE s.customer_id IS NOT NULL
              AND d.customer_key IS NULL
        )
            BEGIN
                ;THROW 50001, 'Unresolved customer_id in silver.loads.', 1;

        END;


        IF EXISTS
        (
            SELECT 1
            FROM silver.loads AS s
            LEFT JOIN gold.dim_route AS d
                ON s.route_id = d.route_id
            WHERE s.route_id IS NOT NULL
              AND d.route_key IS NULL
        )
            BEGIN
                ;THROW 50002, 'Unresolved route_id in silver.loads.', 1;

        END;


        IF EXISTS
        (
            SELECT 1
            FROM silver.loads AS s
            LEFT JOIN gold.dim_date AS d
                ON s.load_date = d.full_date
            WHERE s.load_date IS NULL OR d.date_key IS NULL
        )
            BEGIN
                ;THROW 50003, 'Missing or unresolved load_date in silver.loads.', 1;

        END;


        INSERT INTO gold.fact_loads
        (
            load_id, customer_key, route_key, load_date_key, load_type,
            weight_lbs, pieces, revenue, fuel_surcharge, accessorial_charges,
            load_status, booking_type
        )
        SELECT
            s.load_id, c.customer_key, r.route_key, dt.date_key, s.load_type,
            s.weight_lbs, s.pieces, s.revenue, s.fuel_surcharge,
            s.accessorial_charges, s.load_status, s.booking_type
        FROM silver.loads AS s
        LEFT JOIN gold.dim_customer AS c
            ON s.customer_id = c.customer_id
        LEFT JOIN gold.dim_route AS r
            ON s.route_id = r.route_id
        INNER JOIN gold.dim_date AS dt
            ON s.load_date = dt.full_date;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'fact_loads: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        -- =====================================================
        -- 4. LOAD FACT: TRIPS
        -- Grain: one row per trip. load_id is traceability only.
        -- =====================================================

        IF EXISTS
        (
            SELECT 1 FROM silver.trips AS s
            LEFT JOIN gold.dim_driver AS d ON s.driver_id = d.driver_id
            WHERE s.driver_id IS NOT NULL AND d.driver_key IS NULL
        )
            BEGIN
                ;THROW 50004, 'Unresolved driver_id in silver.trips.', 1;

        END;


        IF EXISTS
        (
            SELECT 1 FROM silver.trips AS s
            LEFT JOIN gold.dim_truck AS d ON s.truck_id = d.truck_id
            WHERE s.truck_id IS NOT NULL AND d.truck_key IS NULL
        )
            BEGIN
                ;THROW 50005, 'Unresolved truck_id in silver.trips.', 1;

        END;


        IF EXISTS
        (
            SELECT 1 FROM silver.trips AS s
            LEFT JOIN gold.dim_trailer AS d ON s.trailer_id = d.trailer_id
            WHERE s.trailer_id IS NOT NULL AND d.trailer_key IS NULL
        )
            BEGIN
                ;THROW 50006, 'Unresolved trailer_id in silver.trips.', 1;

        END;


        IF EXISTS
        (
            SELECT 1 FROM silver.trips AS s
            LEFT JOIN gold.dim_date AS d ON s.dispatch_date = d.full_date
            WHERE s.dispatch_date IS NULL OR d.date_key IS NULL
        )
            BEGIN
                ;THROW 50007, 'Missing or unresolved dispatch_date in silver.trips.', 1;

        END;


        INSERT INTO gold.fact_trips
        (
            trip_id, load_id, driver_key, truck_key, trailer_key,
            dispatch_date_key, actual_distance_miles, actual_duration_hours,
            fuel_gallons_used, average_mpg, idle_time_hours, trip_status
        )
        SELECT
            s.trip_id, s.load_id, dr.driver_key, tr.truck_key, tl.trailer_key,
            dt.date_key, s.actual_distance_miles, s.actual_duration_hours,
            s.fuel_gallons_used, s.average_mpg, s.idle_time_hours, s.trip_status
        FROM silver.trips AS s
        LEFT JOIN gold.dim_driver AS dr ON s.driver_id = dr.driver_id
        LEFT JOIN gold.dim_truck AS tr ON s.truck_id = tr.truck_id
        LEFT JOIN gold.dim_trailer AS tl ON s.trailer_id = tl.trailer_id
        INNER JOIN gold.dim_date AS dt ON s.dispatch_date = dt.full_date;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'fact_trips: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        -- =====================================================
        -- 5. LOAD FACT: DELIVERY EVENTS
        -- Grain: one row per pickup or delivery event.
        -- =====================================================

        IF EXISTS
        (
            SELECT 1 FROM silver.delivery_events AS s
            LEFT JOIN gold.dim_facility AS d ON s.facility_id = d.facility_id
            WHERE s.facility_id IS NOT NULL AND d.facility_key IS NULL
        )
            BEGIN
                ;THROW 50008, 'Unresolved facility_id in silver.delivery_events.', 1;

        END;


        IF EXISTS
        (
            SELECT 1 FROM silver.delivery_events AS s
            LEFT JOIN gold.dim_date AS d
                ON CAST(s.scheduled_datetime AS DATE) = d.full_date
            WHERE s.scheduled_datetime IS NULL OR d.date_key IS NULL
        )
            BEGIN
                ;THROW 50009, 'Missing or unresolved scheduled_datetime date.', 1;

        END;


        IF EXISTS
        (
            SELECT 1 FROM silver.delivery_events AS s
            LEFT JOIN gold.dim_date AS d
                ON CAST(s.actual_datetime AS DATE) = d.full_date
            WHERE s.actual_datetime IS NULL OR d.date_key IS NULL
        )
            BEGIN
                ;THROW 50010, 'Missing or unresolved actual_datetime date.', 1;

        END;


        INSERT INTO gold.fact_delivery_events
        (
            event_id, load_id, trip_id, facility_key, scheduled_date_key,
            actual_date_key, event_type, scheduled_datetime, actual_datetime,
            detention_minutes, on_time_flag, location_city, location_state
        )
        SELECT
            s.event_id, s.load_id, s.trip_id, f.facility_key,
            ds.date_key, da.date_key, s.event_type, s.scheduled_datetime,
            s.actual_datetime, s.detention_minutes, s.on_time_flag,
            s.location_city, s.location_state
        FROM silver.delivery_events AS s
        LEFT JOIN gold.dim_facility AS f ON s.facility_id = f.facility_id
        INNER JOIN gold.dim_date AS ds
            ON CAST(s.scheduled_datetime AS DATE) = ds.full_date
        INNER JOIN gold.dim_date AS da
            ON CAST(s.actual_datetime AS DATE) = da.full_date;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'fact_delivery_events: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        -- =====================================================
        -- 6. LOAD FACT: FUEL PURCHASES
        -- Grain: one row per purchase. Use purchase-level IDs.
        -- =====================================================

        IF EXISTS
        (
            SELECT 1 FROM silver.fuel_purchases AS s
            LEFT JOIN gold.dim_truck AS d ON s.truck_id = d.truck_id
            WHERE s.truck_id IS NOT NULL AND d.truck_key IS NULL
        )
            BEGIN
                ;THROW 50011, 'Unresolved truck_id in silver.fuel_purchases.', 1;

        END;


        IF EXISTS
        (
            SELECT 1 FROM silver.fuel_purchases AS s
            LEFT JOIN gold.dim_driver AS d ON s.driver_id = d.driver_id
            WHERE s.driver_id IS NOT NULL AND d.driver_key IS NULL
        )
            BEGIN
                ;THROW 50012, 'Unresolved driver_id in silver.fuel_purchases.', 1;

        END;


        IF EXISTS
        (
            SELECT 1 FROM silver.fuel_purchases AS s
            LEFT JOIN gold.dim_date AS d
                ON CAST(s.purchase_date AS DATE) = d.full_date
            WHERE s.purchase_date IS NULL OR d.date_key IS NULL
        )
            BEGIN
                ;THROW 50013, 'Missing or unresolved purchase_date in silver.fuel_purchases.', 1;

        END;


        INSERT INTO gold.fact_fuel_purchases
        (
            fuel_purchase_id, trip_id, truck_key, driver_key, purchase_date_key,
            purchase_date, location_city, location_state, gallons,
            price_per_gallon, total_cost
        )
        SELECT
            s.fuel_purchase_id, s.trip_id, t.truck_key, dr.driver_key,
            dt.date_key, s.purchase_date, s.location_city, s.location_state,
            s.gallons, s.price_per_gallon, s.total_cost
        FROM silver.fuel_purchases AS s
        LEFT JOIN gold.dim_truck AS t ON s.truck_id = t.truck_id
        LEFT JOIN gold.dim_driver AS dr ON s.driver_id = dr.driver_id
        INNER JOIN gold.dim_date AS dt
            ON CAST(s.purchase_date AS DATE) = dt.full_date;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'fact_fuel_purchases: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        -- =====================================================
        -- 7. LOAD FACT: MAINTENANCE RECORDS
        -- Grain: one row per maintenance record.
        -- facility_location remains text, not a facility key.
        -- =====================================================

        IF EXISTS
        (
            SELECT 1 FROM silver.maintenance_records AS s
            LEFT JOIN gold.dim_truck AS d ON s.truck_id = d.truck_id
            WHERE s.truck_id IS NOT NULL AND d.truck_key IS NULL
        )
            BEGIN
                ;THROW 50014, 'Unresolved truck_id in silver.maintenance_records.', 1;

        END;


        IF EXISTS
        (
            SELECT 1 FROM silver.maintenance_records AS s
            LEFT JOIN gold.dim_date AS d ON s.maintenance_date = d.full_date
            WHERE s.maintenance_date IS NULL OR d.date_key IS NULL
        )
            BEGIN
                ;THROW 50015, 'Missing or unresolved maintenance_date.', 1;

        END;


        INSERT INTO gold.fact_maintenance_records
        (
            maintenance_id, truck_key, maintenance_date_key, maintenance_type,
            odometer_reading, labor_hours, labor_cost, parts_cost, total_cost,
            facility_location, downtime_hours, service_description
        )
        SELECT
            s.maintenance_id, t.truck_key, dt.date_key, s.maintenance_type,
            s.odometer_reading, s.labor_hours, s.labor_cost, s.parts_cost,
            s.total_cost, s.facility_location, s.downtime_hours,
            s.service_description
        FROM silver.maintenance_records AS s
        LEFT JOIN gold.dim_truck AS t ON s.truck_id = t.truck_id
        INNER JOIN gold.dim_date AS dt ON s.maintenance_date = dt.full_date;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'fact_maintenance_records: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        -- =====================================================
        -- 8. LOAD FACT: SAFETY INCIDENTS
        -- Grain: one row per incident. Nullable entity IDs stay NULL.
        -- =====================================================

        IF EXISTS
        (
            SELECT 1 FROM silver.safety_incidents AS s
            LEFT JOIN gold.dim_truck AS d ON s.truck_id = d.truck_id
            WHERE s.truck_id IS NOT NULL AND d.truck_key IS NULL
        )
            BEGIN
                ;THROW 50016, 'Unresolved truck_id in silver.safety_incidents.', 1;

        END;


        IF EXISTS
        (
            SELECT 1 FROM silver.safety_incidents AS s
            LEFT JOIN gold.dim_driver AS d ON s.driver_id = d.driver_id
            WHERE s.driver_id IS NOT NULL AND d.driver_key IS NULL
        )
            BEGIN
                ;THROW 50017, 'Unresolved driver_id in silver.safety_incidents.', 1;

        END;


        IF EXISTS
        (
            SELECT 1 FROM silver.safety_incidents AS s
            LEFT JOIN gold.dim_date AS d
                ON CAST(s.incident_date AS DATE) = d.full_date
            WHERE s.incident_date IS NULL OR d.date_key IS NULL
        )
            BEGIN
                ;THROW 50018, 'Missing or unresolved incident_date in silver.safety_incidents.', 1;

        END;


        INSERT INTO gold.fact_safety_incidents
        (
            incident_id, trip_id, truck_key, driver_key, incident_date_key,
            incident_date, incident_type, location_city, location_state,
            at_fault_flag, injury_flag, vehicle_damage_cost, cargo_damage_cost,
            claim_amount, preventable_flag
        )
        SELECT
            s.incident_id, s.trip_id, t.truck_key, dr.driver_key, dt.date_key,
            s.incident_date, s.incident_type, s.location_city, s.location_state,
            s.at_fault_flag, s.injury_flag, s.vehicle_damage_cost,
            s.cargo_damage_cost, s.claim_amount, s.preventable_flag
        FROM silver.safety_incidents AS s
        LEFT JOIN gold.dim_truck AS t ON s.truck_id = t.truck_id
        LEFT JOIN gold.dim_driver AS dr ON s.driver_id = dr.driver_id
        INNER JOIN gold.dim_date AS dt
            ON CAST(s.incident_date AS DATE) = dt.full_date;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        PRINT 'fact_safety_incidents: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';

        -- =====================================================
        -- 9. COMMIT AND DISPLAY SUMMARY
        -- =====================================================

        COMMIT TRANSACTION;

        PRINT '========================================';
        PRINT 'GOLD LOADING COMPLETED';
        PRINT 'Tables loaded: 12';
        PRINT 'Total rows loaded: ' + CAST(@TotalRows AS VARCHAR(30));
        PRINT 'Duration: '
            + CAST(DATEDIFF(SECOND, @BatchStartTime, SYSDATETIME()) AS VARCHAR(20))
            + ' seconds';
        PRINT '========================================';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        PRINT '========================================';
        PRINT 'GOLD LOADING FAILED';
        PRINT 'Error: ' + ERROR_MESSAGE();
        PRINT '========================================';

        THROW;
    END CATCH;
END;
GO

-- Execute the full-refresh Gold loading procedure.
EXEC gold.load_gold;
GO
