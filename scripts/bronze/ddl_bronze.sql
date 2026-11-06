
/*
======================================================================
DDL Script: Create Bronze Tables
======================================================================

Script Purpose:
    This script creates tables in the 'bronze' schema to store
    raw data imported from the source CSV files.

    It performs the following actions:
    - Drops existing Bronze tables if they already exist.
    - Creates 14 Bronze tables corresponding to source CSV files.
    - Defines all source columns using VARCHAR data types.
    - Preserves raw source values without applying transformations.

Important Notes:
    - Bronze tables store data in its original raw format.
    - No primary keys or foreign keys are enforced in this layer.
    - Data cleaning and type conversions are performed in Silver.
    - Running this script again drops and recreates existing tables,
      which deletes their stored data.

Usage:
    Execute this script before running bronze.load_bronze.

======================================================================
*/

-- =============================================
-- Table: bronze.customers
-- Description: Stores raw customer information
--              imported from customers.csv.
-- =============================================

IF OBJECT_ID('bronze.customers', 'U') IS NOT NULL
    DROP TABLE bronze.customers

CREATE TABLE bronze.customers
(
    customer_id              VARCHAR(50),
    customer_name            VARCHAR(255),
    customer_type            VARCHAR(100),
    credit_terms_days        VARCHAR(50),
    primary_freight_type     VARCHAR(100),
    account_status           VARCHAR(100),
    contract_start_date      VARCHAR(50),
    annual_revenue_potential VARCHAR(50)
)

-- =============================================
-- Table: bronze.delivery_events
-- Description: Stores raw delivery event records
--              imported from delivery_events.csv.
-- =============================================

IF OBJECT_ID('bronze.delivery_events', 'U') IS NOT NULL
    DROP TABLE bronze.delivery_events;


CREATE TABLE bronze.delivery_events
(
    event_id             VARCHAR(50),
    load_id              VARCHAR(50),
    trip_id              VARCHAR(50),
    event_type           VARCHAR(100),
    facility_id          VARCHAR(50),
    scheduled_datetime   VARCHAR(50),
    actual_datetime      VARCHAR(50),
    detention_minutes    VARCHAR(50),
    on_time_flag         VARCHAR(50),
    location_city        VARCHAR(100),
    location_state       VARCHAR(100)
)

-- =============================================
-- Table: bronze.driver_monthly_metrics
-- Description: Stores raw monthly performance
--              metrics for drivers imported from
--              driver_monthly_metrics.csv.
-- =============================================

IF OBJECT_ID('bronze.driver_monthly_metrics', 'U') IS NOT NULL
    DROP TABLE bronze.driver_monthly_metrics

CREATE TABLE bronze.driver_monthly_metrics
(
    driver_id               VARCHAR(50),
    month                   VARCHAR(50),
    trips_completed         VARCHAR(50),
    total_miles             VARCHAR(50),
    total_revenue           VARCHAR(50),
    average_mpg             VARCHAR(50),
    total_fuel_gallons      VARCHAR(50),
    on_time_delivery_rate   VARCHAR(50),
    average_idle_hours      VARCHAR(50)
)


-- =============================================
-- Table: bronze.drivers
-- Description: Stores raw driver information
--              imported from drivers.csv.
-- =============================================

IF OBJECT_ID('bronze.drivers', 'U') IS NOT NULL
    DROP TABLE bronze.drivers;


CREATE TABLE bronze.drivers
(
    driver_id             VARCHAR(50),
    first_name            VARCHAR(100),
    last_name             VARCHAR(100),
    hire_date             VARCHAR(50),
    termination_date      VARCHAR(50),
    license_number        VARCHAR(100),
    license_state         VARCHAR(100),
    date_of_birth         VARCHAR(50),
    home_terminal         VARCHAR(100),
    employment_status     VARCHAR(100),
    cdl_class             VARCHAR(50),
    years_experience      VARCHAR(50)
)

-- =============================================
-- Table: bronze.facilities
-- Description: Stores raw facility information
--              imported from facilities.csv.
-- =============================================

IF OBJECT_ID('bronze.facilities', 'U') IS NOT NULL
    DROP TABLE bronze.facilities;


CREATE TABLE bronze.facilities
(
    facility_id       VARCHAR(50),
    facility_name     VARCHAR(255),
    facility_type     VARCHAR(100),
    city              VARCHAR(100),
    state             VARCHAR(100),
    latitude          VARCHAR(50),
    longitude         VARCHAR(50),
    dock_doors        VARCHAR(50),
    operating_hours   VARCHAR(255)
)

-- =============================================
-- Table: bronze.fuel_purchases
-- Description: Stores raw fuel purchase records
--              imported from fuel_purchases.csv.
-- =============================================

IF OBJECT_ID('bronze.fuel_purchases', 'U') IS NOT NULL
    DROP TABLE bronze.fuel_purchases;


CREATE TABLE bronze.fuel_purchases
(
    fuel_purchase_id    VARCHAR(50),
    trip_id             VARCHAR(50),
    truck_id            VARCHAR(50),
    driver_id           VARCHAR(50),
    purchase_date       VARCHAR(50),
    location_city       VARCHAR(100),
    location_state      VARCHAR(100),
    gallons             VARCHAR(50),
    price_per_gallon    VARCHAR(50),
    total_cost          VARCHAR(50),
    fuel_card_number    VARCHAR(100)
)

-- =============================================
-- Table: bronze.loads
-- Description: Stores raw shipment/load records
--              imported from loads.csv.
-- =============================================

IF OBJECT_ID('bronze.loads', 'U') IS NOT NULL
    DROP TABLE bronze.loads;


CREATE TABLE bronze.loads
(
    load_id                 VARCHAR(50),
    customer_id             VARCHAR(50),
    route_id                VARCHAR(50),
    load_date               VARCHAR(50),
    load_type               VARCHAR(100),
    weight_lbs              VARCHAR(50),
    pieces                  VARCHAR(50),
    revenue                 VARCHAR(50),
    fuel_surcharge          VARCHAR(50),
    accessorial_charges     VARCHAR(50),
    load_status             VARCHAR(100),
    booking_type            VARCHAR(100)
)

-- =============================================
-- Table: bronze.maintenance_records
-- Description: Stores raw vehicle maintenance
--              records imported from
--              maintenance_records.csv.
-- =============================================

IF OBJECT_ID('bronze.maintenance_records', 'U') IS NOT NULL
    DROP TABLE bronze.maintenance_records;

CREATE TABLE bronze.maintenance_records
(
    maintenance_id          VARCHAR(50),
    truck_id                VARCHAR(50),
    maintenance_date        VARCHAR(50),
    maintenance_type        VARCHAR(100),
    odometer_reading        VARCHAR(50),
    labor_hours             VARCHAR(50),
    labor_cost              VARCHAR(50),
    parts_cost              VARCHAR(50),
    total_cost              VARCHAR(50),
    facility_location       VARCHAR(255),
    downtime_hours          VARCHAR(50),
    service_description     VARCHAR(MAX)
)

-- =============================================
-- Table: bronze.routes
-- Description: Stores raw route information
--              imported from routes.csv.
-- =============================================

IF OBJECT_ID('bronze.routes', 'U') IS NOT NULL
    DROP TABLE bronze.routes;

CREATE TABLE bronze.routes
(
    route_id                    VARCHAR(50),
    origin_city                 VARCHAR(100),
    origin_state                VARCHAR(100),
    destination_city            VARCHAR(100),
    destination_state           VARCHAR(100),
    typical_distance_miles      VARCHAR(50),
    base_rate_per_mile          VARCHAR(50),
    fuel_surcharge_rate         VARCHAR(50),
    typical_transit_days        VARCHAR(50)
)

-- =============================================
-- Table: bronze.safety_incidents
-- Description: Stores raw driver and vehicle
--              safety incident records imported
--              from safety_incidents.csv.
-- =============================================

IF OBJECT_ID('bronze.safety_incidents', 'U') IS NOT NULL
    DROP TABLE bronze.safety_incidents;

CREATE TABLE bronze.safety_incidents
(
    incident_id             VARCHAR(50),
    trip_id                 VARCHAR(50),
    truck_id                VARCHAR(50),
    driver_id               VARCHAR(50),
    incident_date           VARCHAR(50),
    incident_type           VARCHAR(100),
    location_city           VARCHAR(100),
    location_state          VARCHAR(100),
    at_fault_flag           VARCHAR(50),
    injury_flag             VARCHAR(50),
    vehicle_damage_cost     VARCHAR(50),
    cargo_damage_cost       VARCHAR(50),
    claim_amount            VARCHAR(50),
    preventable_flag        VARCHAR(50),
    description             VARCHAR(MAX)
)

-- =============================================
-- Table: bronze.trailers
-- Description: Stores raw trailer information
--              imported from trailers.csv.
-- =============================================

IF OBJECT_ID('bronze.trailers', 'U') IS NOT NULL
    DROP TABLE bronze.trailers;

CREATE TABLE bronze.trailers
(
    trailer_id          VARCHAR(50),
    trailer_number      VARCHAR(100),
    trailer_type        VARCHAR(100),
    length_feet         VARCHAR(50),
    model_year          VARCHAR(50),
    vin                 VARCHAR(100),
    acquisition_date    VARCHAR(50),
    status              VARCHAR(100),
    current_location    VARCHAR(255)
)

-- =============================================
-- Table: bronze.trips
-- Description: Stores raw trip records
--              imported from trips.csv.
-- =============================================

IF OBJECT_ID('bronze.trips', 'U') IS NOT NULL
    DROP TABLE bronze.trips;


CREATE TABLE bronze.trips
(
    trip_id                 VARCHAR(50),
    load_id                 VARCHAR(50),
    driver_id               VARCHAR(50),
    truck_id                VARCHAR(50),
    trailer_id              VARCHAR(50),
    dispatch_date           VARCHAR(50),
    actual_distance_miles   VARCHAR(50),
    actual_duration_hours   VARCHAR(50),
    fuel_gallons_used       VARCHAR(50),
    average_mpg             VARCHAR(50),
    idle_time_hours         VARCHAR(50),
    trip_status             VARCHAR(100)
)

-- =============================================
-- Table: bronze.truck_utilization_metrics
-- Description: Stores raw truck utilization
--              metrics imported from
--              truck_utilization_metrics.csv.
-- =============================================

IF OBJECT_ID('bronze.truck_utilization_metrics', 'U') IS NOT NULL
    DROP TABLE bronze.truck_utilization_metrics;

CREATE TABLE bronze.truck_utilization_metrics
(
    truck_id                VARCHAR(50),
    month                   VARCHAR(50),
    trips_completed         VARCHAR(50),
    total_miles             VARCHAR(50),
    total_revenue           VARCHAR(50),
    average_mpg             VARCHAR(50),
    maintenance_events      VARCHAR(50),
    maintenance_cost        VARCHAR(50),
    downtime_hours          VARCHAR(50),
    utilization_rate        VARCHAR(50)
)

-- =============================================
-- Table: bronze.trucks
-- Description: Stores raw truck information
--              imported from trucks.csv.
-- =============================================

IF OBJECT_ID('bronze.trucks', 'U') IS NOT NULL
    DROP TABLE bronze.trucks;

CREATE TABLE bronze.trucks
(
    truck_id                  VARCHAR(50),
    unit_number               VARCHAR(100),
    make                      VARCHAR(100),
    model_year                VARCHAR(50),
    vin                       VARCHAR(100),
    acquisition_date          VARCHAR(50),
    acquisition_mileage       VARCHAR(50),
    fuel_type                 VARCHAR(100),
    tank_capacity_gallons     VARCHAR(50),
    status                    VARCHAR(100),
    home_terminal             VARCHAR(100)
)

