
/*
======================================================================
 Stored Procedure: Load Silver Layer (Bronze -> Silver)
======================================================================

Script Purpose:
    This stored procedure loads cleaned and standardized data
    from the Bronze layer into the Silver layer.

    It performs the following actions:
    - Deletes existing Silver data in foreign-key dependency order.
    - Converts raw VARCHAR values into the target Silver data types.
    - Converts blank values in typed columns into NULL.
    - Preserves nullable foreign keys.
    - Inserts records in parent-to-child dependency order.
    - Tracks the number of rows loaded into each table.
    - Measures the total loading duration.
    - Uses a transaction to ensure the reload is atomic.
    - Handles errors and rolls back the transaction if loading fails.

Source:      bronze
Destination: silver
Database:    LogisticsAnalytics
Tables:      14

======================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN

    -- =============================================
    -- 1. INITIALIZE
    -- =============================================

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @BatchStartTime DATETIME2 = SYSDATETIME();
    DECLARE @RowsInserted BIGINT;
    DECLARE @TotalRows BIGINT = 0;

    BEGIN TRY

        BEGIN TRANSACTION;


        -- =============================================
        -- 2. DELETE EXISTING SILVER DATA
        -- Child tables must be deleted before parent tables.
        -- =============================================

        DELETE FROM silver.delivery_events;
        DELETE FROM silver.safety_incidents;
        DELETE FROM silver.fuel_purchases;
        DELETE FROM silver.maintenance_records;
        DELETE FROM silver.driver_monthly_metrics;
        DELETE FROM silver.truck_utilization_metrics;
        DELETE FROM silver.trips;
        DELETE FROM silver.loads;
        DELETE FROM silver.trailers;
        DELETE FROM silver.trucks;
        DELETE FROM silver.routes;
        DELETE FROM silver.facilities;
        DELETE FROM silver.drivers;
        DELETE FROM silver.customers;


        -- =============================================
        -- 3. LOAD CUSTOMERS
        -- =============================================

        INSERT INTO silver.customers
        (
            customer_id,
            customer_name,
            customer_type,
            credit_terms_days,
            primary_freight_type,
            account_status,
            contract_start_date,
            annual_revenue_potential
        )
        SELECT
            TRIM(customer_id),
            customer_name,
            customer_type,
            CONVERT(INT, NULLIF(TRIM(credit_terms_days), '')),
            primary_freight_type,
            account_status,
            CONVERT(DATE, NULLIF(TRIM(contract_start_date), ''), 23),
            CONVERT(INT, NULLIF(TRIM(annual_revenue_potential), ''))
        FROM bronze.customers;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Customers: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 4. LOAD DRIVERS
        -- =============================================

        INSERT INTO silver.drivers
        (
            driver_id,
            first_name,
            last_name,
            hire_date,
            termination_date,
            license_number,
            license_state,
            date_of_birth,
            home_terminal,
            employment_status,
            cdl_class,
            years_experience
        )
        SELECT
            TRIM(driver_id),
            first_name,
            last_name,
            CONVERT(DATE, NULLIF(TRIM(hire_date), ''), 23),
            CONVERT(DATE, NULLIF(TRIM(termination_date), ''), 23),
            license_number,
            license_state,
            CONVERT(DATE, NULLIF(TRIM(date_of_birth), ''), 23),
            home_terminal,
            employment_status,
            cdl_class,
            CONVERT(SMALLINT, NULLIF(TRIM(years_experience), ''))
        FROM bronze.drivers;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Drivers: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 5. LOAD FACILITIES
        -- =============================================

        INSERT INTO silver.facilities
        (
            facility_id,
            facility_name,
            facility_type,
            city,
            state,
            latitude,
            longitude,
            dock_doors,
            operating_hours
        )
        SELECT
            TRIM(facility_id),
            facility_name,
            facility_type,
            city,
            state,
            CONVERT(DECIMAL(10,6), NULLIF(TRIM(latitude), '')),
            CONVERT(DECIMAL(10,6), NULLIF(TRIM(longitude), '')),
            CONVERT(INT, NULLIF(TRIM(dock_doors), '')),
            operating_hours
        FROM bronze.facilities;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Facilities: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 6. LOAD ROUTES
        -- =============================================

        INSERT INTO silver.routes
        (
            route_id,
            origin_city,
            origin_state,
            destination_city,
            destination_state,
            typical_distance_miles,
            base_rate_per_mile,
            fuel_surcharge_rate,
            typical_transit_days
        )
        SELECT
            TRIM(route_id),
            origin_city,
            origin_state,
            destination_city,
            destination_state,
            CONVERT(DECIMAL(10,2), NULLIF(TRIM(typical_distance_miles), '')),
            CONVERT(DECIMAL(10,4), NULLIF(TRIM(base_rate_per_mile), '')),
            CONVERT(DECIMAL(10,6), NULLIF(TRIM(fuel_surcharge_rate), '')),
            CONVERT(SMALLINT, NULLIF(TRIM(typical_transit_days), ''))
        FROM bronze.routes;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Routes: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 7. LOAD TRUCKS
        -- =============================================

        INSERT INTO silver.trucks
        (
            truck_id,
            unit_number,
            make,
            model_year,
            vin,
            acquisition_date,
            acquisition_mileage,
            fuel_type,
            tank_capacity_gallons,
            status,
            home_terminal
        )
        SELECT
            TRIM(truck_id),
            unit_number,
            make,
            CONVERT(SMALLINT, NULLIF(TRIM(model_year), '')),
            vin,
            CONVERT(DATE, NULLIF(TRIM(acquisition_date), ''), 23),
            CONVERT(INT, NULLIF(TRIM(acquisition_mileage), '')),
            fuel_type,
            CONVERT(SMALLINT, NULLIF(TRIM(tank_capacity_gallons), '')),
            status,
            home_terminal
        FROM bronze.trucks;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Trucks: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 8. LOAD TRAILERS
        -- =============================================

        INSERT INTO silver.trailers
        (
            trailer_id,
            trailer_number,
            trailer_type,
            length_feet,
            model_year,
            vin,
            acquisition_date,
            status,
            current_location
        )
        SELECT
            TRIM(trailer_id),
            trailer_number,
            trailer_type,
            CONVERT(SMALLINT, NULLIF(TRIM(length_feet), '')),
            CONVERT(SMALLINT, NULLIF(TRIM(model_year), '')),
            vin,
            CONVERT(DATE, NULLIF(TRIM(acquisition_date), ''), 23),
            status,
            current_location
        FROM bronze.trailers;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Trailers: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 9. LOAD LOADS
        -- =============================================

        INSERT INTO silver.loads
        (
            load_id,
            customer_id,
            route_id,
            load_date,
            load_type,
            weight_lbs,
            pieces,
            revenue,
            fuel_surcharge,
            accessorial_charges,
            load_status,
            booking_type
        )
        SELECT
            TRIM(load_id),
            NULLIF(TRIM(customer_id), ''),
            NULLIF(TRIM(route_id), ''),
            CONVERT(DATE, NULLIF(TRIM(load_date), ''), 23),
            load_type,
            CONVERT(DECIMAL(12,2), NULLIF(TRIM(weight_lbs), '')),
            CONVERT(SMALLINT, NULLIF(TRIM(pieces), '')),
            CONVERT(DECIMAL(12,2), NULLIF(TRIM(revenue), '')),
            CONVERT(DECIMAL(12,2), NULLIF(TRIM(fuel_surcharge), '')),
            CONVERT(DECIMAL(12,2), NULLIF(TRIM(accessorial_charges), '')),
            load_status,
            booking_type
        FROM bronze.loads;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Loads: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 10. LOAD TRIPS
        -- =============================================

        INSERT INTO silver.trips
        (
            trip_id,
            load_id,
            driver_id,
            truck_id,
            trailer_id,
            dispatch_date,
            actual_distance_miles,
            actual_duration_hours,
            fuel_gallons_used,
            average_mpg,
            idle_time_hours,
            trip_status
        )
        SELECT
            TRIM(trip_id),
            NULLIF(TRIM(load_id), ''),
            NULLIF(TRIM(driver_id), ''),
            NULLIF(TRIM(truck_id), ''),
            NULLIF(TRIM(trailer_id), ''),
            CONVERT(DATE, NULLIF(TRIM(dispatch_date), ''), 23),
            CONVERT(DECIMAL(6,2), NULLIF(TRIM(actual_distance_miles), '')),
            CONVERT(DECIMAL(5,1), NULLIF(TRIM(actual_duration_hours), '')),
            CONVERT(DECIMAL(5,1), NULLIF(TRIM(fuel_gallons_used), '')),
            CONVERT(DECIMAL(5,2), NULLIF(TRIM(average_mpg), '')),
            CONVERT(DECIMAL(5,2), NULLIF(TRIM(idle_time_hours), '')),
            trip_status
        FROM bronze.trips;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Trips: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 11. LOAD FUEL PURCHASES
        -- =============================================

        INSERT INTO silver.fuel_purchases
        (
            fuel_purchase_id,
            trip_id,
            truck_id,
            driver_id,
            purchase_date,
            location_city,
            location_state,
            gallons,
            price_per_gallon,
            total_cost,
            fuel_card_number
        )
        SELECT
            TRIM(fuel_purchase_id),
            NULLIF(TRIM(trip_id), ''),
            NULLIF(TRIM(truck_id), ''),
            NULLIF(TRIM(driver_id), ''),
            CONVERT(DATETIME2, NULLIF(TRIM(purchase_date), '')),
            location_city,
            location_state,
            CONVERT(DECIMAL(10,2), NULLIF(TRIM(gallons), '')),
            CONVERT(DECIMAL(5,4), NULLIF(TRIM(price_per_gallon), '')),
            CONVERT(DECIMAL(8,2), NULLIF(TRIM(total_cost), '')),
            fuel_card_number
        FROM bronze.fuel_purchases;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Fuel purchases: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 12. LOAD MAINTENANCE RECORDS
        -- =============================================

        INSERT INTO silver.maintenance_records
        (
            maintenance_id,
            truck_id,
            maintenance_date,
            maintenance_type,
            odometer_reading,
            labor_hours,
            labor_cost,
            parts_cost,
            total_cost,
            facility_location,
            downtime_hours,
            service_description
        )
        SELECT
            TRIM(maintenance_id),
            NULLIF(TRIM(truck_id), ''),
            CONVERT(DATE, NULLIF(TRIM(maintenance_date), ''), 23),
            maintenance_type,
            CONVERT(INT, NULLIF(TRIM(odometer_reading), '')),
            CONVERT(DECIMAL(4,1), NULLIF(TRIM(labor_hours), '')),
            CONVERT(DECIMAL(7,2), NULLIF(TRIM(labor_cost), '')),
            CONVERT(DECIMAL(8,2), NULLIF(TRIM(parts_cost), '')),
            CONVERT(DECIMAL(8,2), NULLIF(TRIM(total_cost), '')),
            facility_location,
            CONVERT(DECIMAL(4,1), NULLIF(TRIM(downtime_hours), '')),
            service_description
        FROM bronze.maintenance_records;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Maintenance records: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 13. LOAD DELIVERY EVENTS
        -- =============================================

        INSERT INTO silver.delivery_events
        (
            event_id,
            load_id,
            trip_id,
            event_type,
            facility_id,
            scheduled_datetime,
            actual_datetime,
            detention_minutes,
            on_time_flag,
            location_city,
            location_state
        )
        SELECT
            TRIM(event_id),
            NULLIF(TRIM(load_id), ''),
            NULLIF(TRIM(trip_id), ''),
            event_type,
            NULLIF(TRIM(facility_id), ''),
            CONVERT(DATETIME2, NULLIF(TRIM(scheduled_datetime), '')),
            CONVERT(DATETIME2, NULLIF(TRIM(actual_datetime), '')),
            CONVERT(SMALLINT, NULLIF(TRIM(detention_minutes), '')),
            CONVERT(BIT, NULLIF(TRIM(on_time_flag), '')),
            location_city,
            location_state
        FROM bronze.delivery_events;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Delivery events: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 14. LOAD SAFETY INCIDENTS
        -- =============================================

        INSERT INTO silver.safety_incidents
        (
            incident_id,
            trip_id,
            truck_id,
            driver_id,
            incident_date,
            incident_type,
            location_city,
            location_state,
            at_fault_flag,
            injury_flag,
            vehicle_damage_cost,
            cargo_damage_cost,
            claim_amount,
            preventable_flag,
            description
        )
        SELECT
            TRIM(incident_id),
            NULLIF(TRIM(trip_id), ''),
            NULLIF(TRIM(truck_id), ''),
            NULLIF(TRIM(driver_id), ''),
            CONVERT(DATETIME2, NULLIF(TRIM(incident_date), '')),
            incident_type,
            location_city,
            location_state,
            CONVERT(BIT, NULLIF(TRIM(at_fault_flag), '')),
            CONVERT(BIT, NULLIF(TRIM(injury_flag), '')),
            CONVERT(DECIMAL(8,2), NULLIF(TRIM(vehicle_damage_cost), '')),
            CONVERT(DECIMAL(8,2), NULLIF(TRIM(cargo_damage_cost), '')),
            CONVERT(DECIMAL(8,2), NULLIF(TRIM(claim_amount), '')),
            CONVERT(BIT, NULLIF(TRIM(preventable_flag), '')),
            description
        FROM bronze.safety_incidents;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Safety incidents: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 15. LOAD DRIVER MONTHLY METRICS
        -- =============================================

        INSERT INTO silver.driver_monthly_metrics
        (
            driver_id,
            [month],
            trips_completed,
            total_miles,
            total_revenue,
            average_mpg,
            total_fuel_gallons,
            on_time_delivery_rate,
            average_idle_hours
        )
        SELECT
            TRIM(driver_id),
            CONVERT(DATE, NULLIF(TRIM([month]), ''), 23),
            CONVERT(SMALLINT, NULLIF(TRIM(trips_completed), '')),
            CONVERT(DECIMAL(8,2), NULLIF(TRIM(total_miles), '')),
            CONVERT(DECIMAL(12,2), NULLIF(TRIM(total_revenue), '')),
            CONVERT(DECIMAL(4,2), NULLIF(TRIM(average_mpg), '')),
            CONVERT(DECIMAL(6,1), NULLIF(TRIM(total_fuel_gallons), '')),
            CONVERT(DECIMAL(5,4), NULLIF(TRIM(on_time_delivery_rate), '')),
            CONVERT(DECIMAL(3,1), NULLIF(TRIM(average_idle_hours), ''))
        FROM bronze.driver_monthly_metrics;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Driver monthly metrics: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 16. LOAD TRUCK UTILIZATION METRICS
        -- =============================================

        INSERT INTO silver.truck_utilization_metrics
        (
            truck_id,
            [month],
            trips_completed,
            total_miles,
            total_revenue,
            average_mpg,
            maintenance_events,
            maintenance_cost,
            downtime_hours,
            trips_per_day
        )
        SELECT
            TRIM(truck_id),
            CONVERT(DATE, NULLIF(TRIM([month]), ''), 23),
            CONVERT(SMALLINT, NULLIF(TRIM(trips_completed), '')),
            CONVERT(DECIMAL(9,2), NULLIF(TRIM(total_miles), '')),
            CONVERT(DECIMAL(12,2), NULLIF(TRIM(total_revenue), '')),
            CONVERT(DECIMAL(4,2), NULLIF(TRIM(average_mpg), '')),
            CONVERT(SMALLINT, NULLIF(TRIM(maintenance_events), '')),
            CONVERT(DECIMAL(8,2), NULLIF(TRIM(maintenance_cost), '')),
            CONVERT(DECIMAL(4,1), NULLIF(TRIM(downtime_hours), '')),
            CONVERT(DECIMAL(6,4), NULLIF(TRIM(utilization_rate), ''))
        FROM bronze.truck_utilization_metrics;

        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;

        PRINT 'Truck utilization metrics: ' + CAST(@RowsInserted AS VARCHAR(30)) + ' rows';


        -- =============================================
        -- 17. COMMIT AND DISPLAY SUMMARY
        -- =============================================

        COMMIT TRANSACTION;

        PRINT '========================================';
        PRINT 'SILVER LOADING COMPLETED';
        PRINT 'Total tables loaded: 14';
        PRINT 'Total rows loaded: ' + CAST(@TotalRows AS VARCHAR(30));
        PRINT 'Total duration: ' +
            CAST(DATEDIFF(SECOND, @BatchStartTime, SYSDATETIME()) AS VARCHAR(20))
            + ' seconds';
        PRINT '========================================';


    END TRY

    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        PRINT '========================================';
        PRINT 'SILVER LOADING FAILED';
        PRINT 'Error: ' + ERROR_MESSAGE();
        PRINT '========================================';

        THROW;

    END CATCH;

END;


-- =============================================
-- EXECUTE SILVER LOADING PROCEDURE
-- =============================================

EXEC silver.load_silver;

