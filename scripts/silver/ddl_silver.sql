
/*
    ============================================================
    SILVER LAYER - TABLE CREATION
    ============================================================

    Purpose:
    Create cleaned and standardized target structures for the
    14 source entities in the Bronze layer.

    Design:
    - Preserve the original entity structure and grain.
    - Convert raw VARCHAR values into appropriate SQL data types
      during the Silver loading process.
    - Retain source NULLs unless investigation establishes that
      they should be handled differently.
    - Add PK, FK, UNIQUE and CHECK constraints after data
      validation, not before.

    WARNING:
    These DROP TABLE statements delete existing table data.
    Use this script during schema development or before a
    deliberate full reload.
*/


-- ============================================================
-- 1. CUSTOMERS
-- Customer account and commercial information.
-- Grain: One row per customer.
-- ============================================================

IF OBJECT_ID('silver.customers', 'U') IS NOT NULL
    DROP TABLE silver.customers;

CREATE TABLE silver.customers
(
    customer_id              VARCHAR(50),     -- Unique customer identifier
    customer_name            VARCHAR(255),    -- Customer or company name
    customer_type            VARCHAR(100),    -- Classification of the customer
    credit_terms_days        INT,              -- Agreed credit period in days
    primary_freight_type     VARCHAR(50),     -- Main freight category handled
    account_status           VARCHAR(30),     -- Current account status
    contract_start_date      DATE,             -- Date the customer contract began
    annual_revenue_potential BIGINT            -- Estimated annual revenue potential
);


-- ============================================================
-- 2. DRIVERS
-- Driver identity, employment and licensing information.
-- Grain: One row per driver.
-- ============================================================

IF OBJECT_ID('silver.drivers', 'U') IS NOT NULL
    DROP TABLE silver.drivers;

CREATE TABLE silver.drivers
(
    driver_id          VARCHAR(50),     -- Unique driver identifier
    first_name         VARCHAR(100),    -- Driver's first name
    last_name          VARCHAR(100),    -- Driver's last name
    hire_date          DATE,            -- Date the driver joined the company
    termination_date   DATE,            -- Employment termination date; may be NULL
    license_number     VARCHAR(100),    -- Driver's license number
    license_state      VARCHAR(50),     -- State or jurisdiction issuing the license
    date_of_birth      DATE,            -- Driver's date of birth
    home_terminal      VARCHAR(100),    -- Driver's assigned home terminal
    employment_status  VARCHAR(30),     -- Current employment status
    cdl_class          VARCHAR(1),      -- Commercial driver's license class
    years_experience   SMALLINT         -- Reported years of driving experience
);


-- ============================================================
-- 3. FACILITIES
-- Facility locations and operational characteristics.
-- Grain: One row per facility.
-- ============================================================

IF OBJECT_ID('silver.facilities', 'U') IS NOT NULL
    DROP TABLE silver.facilities;

CREATE TABLE silver.facilities
(
    facility_id       VARCHAR(50),       -- Unique facility identifier
    facility_name     VARCHAR(100),      -- Facility name
    facility_type     VARCHAR(100),      -- Type of facility
    city              VARCHAR(100),      -- Facility city
    state             VARCHAR(10),       -- State or regional code
    latitude          DECIMAL(10,6),     -- Geographic latitude
    longitude         DECIMAL(10,6),     -- Geographic longitude
    dock_doors        INT,               -- Number of loading dock doors
    operating_hours   VARCHAR(50)        -- Facility operating hours or schedule
);


-- ============================================================
-- 4. ROUTES
-- Standard route information and pricing assumptions.
-- Grain: One row per route.
-- ============================================================

IF OBJECT_ID('silver.routes', 'U') IS NOT NULL
    DROP TABLE silver.routes;

CREATE TABLE silver.routes
(
    route_id                VARCHAR(50),      -- Unique route identifier
    origin_city             VARCHAR(100),     -- Route starting city
    origin_state            VARCHAR(50),      -- Route starting state
    destination_city        VARCHAR(100),     -- Route destination city
    destination_state       VARCHAR(50),      -- Route destination state
    typical_distance_miles  DECIMAL(10,2),    -- Expected route distance in miles
    base_rate_per_mile      DECIMAL(10,4),    -- Standard charge per mile
    fuel_surcharge_rate     DECIMAL(10,6),    -- Fuel surcharge rate; scale requires confirmation
    typical_transit_days    SMALLINT         -- Expected transit duration in days
);


-- ============================================================
-- 5. TRUCKS
-- Truck identification, acquisition and operational information.
-- Grain: One row per truck.
-- ============================================================

IF OBJECT_ID('silver.trucks', 'U') IS NOT NULL
    DROP TABLE silver.trucks;

CREATE TABLE silver.trucks
(
    truck_id              VARCHAR(50),     -- Unique truck identifier
    unit_number           SMALLINT,        -- Internal truck unit number
    make                  VARCHAR(80),     -- Truck manufacturer
    model_year            SMALLINT,        -- Truck model year
    vin                   VARCHAR(150),    -- Vehicle identification number; source values need validation
    acquisition_date      DATE,            -- Date the truck was acquired
    acquisition_mileage   INT,             -- Mileage recorded at acquisition
    fuel_type             VARCHAR(30),     -- Truck fuel type
    tank_capacity_gallons SMALLINT,        -- Fuel tank capacity in gallons
    status                VARCHAR(50),     -- Current truck status
    home_terminal         VARCHAR(100)     -- Truck's assigned home terminal
);


-- ============================================================
-- 6. TRAILERS
-- Trailer identification, specifications and current status.
-- Grain: One row per trailer.
-- ============================================================

IF OBJECT_ID('silver.trailers', 'U') IS NOT NULL
    DROP TABLE silver.trailers;

CREATE TABLE silver.trailers
(
    trailer_id       VARCHAR(50),     -- Unique trailer identifier
    trailer_number   SMALLINT,        -- Internal trailer number
    trailer_type     VARCHAR(100),    -- Trailer classification
    length_feet      SMALLINT,        -- Trailer length in feet
    model_year       SMALLINT,        -- Trailer model year
    vin              VARCHAR(150),    -- Trailer vehicle identification number
    acquisition_date DATE,            -- Date the trailer was acquired
    status           VARCHAR(50),     -- Current trailer status
    current_location VARCHAR(100)     -- Trailer's reported current location
);


-- ============================================================
-- 7. LOADS
-- Customer freight bookings and commercial load information.
-- Grain: One row per load.
-- ============================================================

IF OBJECT_ID('silver.loads', 'U') IS NOT NULL
    DROP TABLE silver.loads;

CREATE TABLE silver.loads
(
    load_id               VARCHAR(50),       -- Unique load identifier
    customer_id           VARCHAR(50),       -- Customer associated with the load
    route_id              VARCHAR(50),       -- Planned route for the load
    load_date             DATE,              -- Load booking or creation date
    load_type             VARCHAR(100),      -- Type of freight load
    weight_lbs            DECIMAL(12,2),     -- Load weight in pounds
    pieces                SMALLINT,          -- Number of freight pieces
    revenue               DECIMAL(12,2),     -- Revenue associated with the load
    fuel_surcharge        DECIMAL(12,2),     -- Fuel surcharge amount
    accessorial_charges   DECIMAL(12,2),     -- Additional charges; business meaning to be confirmed
    load_status           VARCHAR(50),       -- Current load status
    booking_type          VARCHAR(50)        -- Load booking classification
);


-- ============================================================
-- 8. TRIPS
-- Actual transportation execution and trip performance.
-- Grain: One row per trip.
-- ============================================================

IF OBJECT_ID('silver.trips', 'U') IS NOT NULL
    DROP TABLE silver.trips;

CREATE TABLE silver.trips
(
    trip_id                 VARCHAR(50),      -- Unique trip identifier
    load_id                 VARCHAR(50),      -- Load transported during the trip
    driver_id               VARCHAR(50),      -- Driver assigned to the trip; may be NULL
    truck_id                VARCHAR(50),      -- Truck assigned to the trip; may be NULL
    trailer_id              VARCHAR(50),      -- Trailer assigned to the trip; may be NULL
    dispatch_date           DATE,             -- Trip dispatch date
    actual_distance_miles   DECIMAL(6,2),     -- Actual distance travelled in miles
    actual_duration_hours   DECIMAL(5,1),     -- Actual trip duration in hours
    fuel_gallons_used       DECIMAL(5,1),     -- Fuel consumed during the trip
    average_mpg             DECIMAL(5,2),     -- Average fuel efficiency in miles per gallon
    idle_time_hours         DECIMAL(5,2),     -- Time spent idling in hours
    trip_status             VARCHAR(50)      -- Current or final trip status
);


-- ============================================================
-- 9. FUEL PURCHASES
-- Fuel transactions associated with trucks, drivers and trips.
-- Grain: One row per fuel purchase.
-- ============================================================

IF OBJECT_ID('silver.fuel_purchases', 'U') IS NOT NULL
    DROP TABLE silver.fuel_purchases;

CREATE TABLE silver.fuel_purchases
(
    fuel_purchase_id  VARCHAR(50),      -- Unique fuel purchase identifier
    trip_id           VARCHAR(50),      -- Trip associated with the fuel purchase
    truck_id          VARCHAR(50),      -- Truck making the purchase; may be NULL
    driver_id         VARCHAR(50),      -- Driver making the purchase; may be NULL
    purchase_date     DATETIME2,        -- Fuel purchase date and time
    location_city     VARCHAR(100),     -- City where fuel was purchased
    location_state    VARCHAR(10),      -- State where fuel was purchased
    gallons           DECIMAL(10,2),    -- Quantity of fuel purchased in gallons
    price_per_gallon  DECIMAL(5,4),     -- Price charged per gallon
    total_cost        DECIMAL(8,2),     -- Total fuel purchase cost
    fuel_card_number  VARCHAR(50)      -- Fuel card used for the transaction
);


-- ============================================================
-- 10. MAINTENANCE RECORDS
-- Truck maintenance activities, costs and downtime.
-- Grain: One row per maintenance record.
-- ============================================================

IF OBJECT_ID('silver.maintenance_records', 'U') IS NOT NULL
    DROP TABLE silver.maintenance_records;

CREATE TABLE silver.maintenance_records
(
    maintenance_id      VARCHAR(50),      -- Unique maintenance record identifier
    truck_id            VARCHAR(50),      -- Truck receiving maintenance
    maintenance_date    DATE,             -- Maintenance service date
    maintenance_type    VARCHAR(100),     -- Category of maintenance performed
    odometer_reading    INT,              -- Truck odometer reading at service
    labor_hours         DECIMAL(4,1),     -- Labor time spent on maintenance
    labor_cost          DECIMAL(7,2),     -- Cost of maintenance labor
    parts_cost          DECIMAL(8,2),     -- Cost of replacement parts
    total_cost          DECIMAL(8,2),     -- Total maintenance cost
    facility_location   VARCHAR(100),     -- Facility or location where service occurred
    downtime_hours      DECIMAL(4,1),     -- Truck downtime resulting from maintenance
    service_description VARCHAR(200)     -- Description of the service performed
);


-- ============================================================
-- 11. DELIVERY EVENTS
-- Scheduled and actual milestones during load delivery.
-- Grain: One row per delivery event.
-- ============================================================

IF OBJECT_ID('silver.delivery_events', 'U') IS NOT NULL
    DROP TABLE silver.delivery_events;

CREATE TABLE silver.delivery_events
(
    event_id            VARCHAR(50),      -- Unique delivery event identifier
    load_id             VARCHAR(50),      -- Load associated with the event
    trip_id             VARCHAR(50),      -- Trip associated with the event
    event_type          VARCHAR(50),      -- Event classification, e.g. pickup or delivery
    facility_id         VARCHAR(50),      -- Facility associated with the event
    scheduled_datetime  DATETIME2,        -- Scheduled event date and time
    actual_datetime     DATETIME2,        -- Actual event date and time
    detention_minutes   SMALLINT,         -- Detention duration in minutes
    on_time_flag        BIT,              -- 1 = on time, 0 = not on time
    location_city       VARCHAR(100),     -- City where the event occurred
    location_state      VARCHAR(10)       -- State where the event occurred
);


-- ============================================================
-- 12. SAFETY INCIDENTS
-- Safety events, responsibility indicators and financial impact.
-- Grain: One row per safety incident.
-- ============================================================

IF OBJECT_ID('silver.safety_incidents', 'U') IS NOT NULL
    DROP TABLE silver.safety_incidents;

CREATE TABLE silver.safety_incidents
(
    incident_id          VARCHAR(50),      -- Unique safety incident identifier
    trip_id              VARCHAR(50),      -- Trip associated with the incident
    truck_id             VARCHAR(50),      -- Truck involved; may be NULL
    driver_id            VARCHAR(50),      -- Driver involved; may be NULL
    incident_date        DATETIME2,        -- Incident date and time
    incident_type        VARCHAR(100),     -- Type of safety incident
    location_city        VARCHAR(100),     -- City where the incident occurred
    location_state       VARCHAR(10),      -- State where the incident occurred
    at_fault_flag        BIT,              -- 1 = at fault, 0 = not at fault
    injury_flag          BIT,              -- 1 = injury reported, 0 = no injury reported
    vehicle_damage_cost  DECIMAL(8,2),     -- Estimated vehicle damage cost
    cargo_damage_cost    DECIMAL(8,2),     -- Estimated cargo damage cost
    claim_amount         DECIMAL(8,2),     -- Associated insurance claim amount
    preventable_flag     BIT,              -- 1 = preventable, 0 = not preventable
    description          VARCHAR(MAX)      -- Detailed incident description
);


-- ============================================================
-- 13. DRIVER MONTHLY METRICS
-- Aggregated operational and performance metrics by driver/month.
-- Grain: One row per driver per reporting month.
-- ============================================================

IF OBJECT_ID('silver.driver_monthly_metrics', 'U') IS NOT NULL
    DROP TABLE silver.driver_monthly_metrics;

CREATE TABLE silver.driver_monthly_metrics
(
    driver_id               VARCHAR(50),      -- Driver associated with the metrics
    month                   DATE,             -- Reporting month
    trips_completed         SMALLINT,         -- Number of completed trips
    total_miles             DECIMAL(8,2),     -- Total miles driven during the month
    total_revenue            DECIMAL(12,2),    -- Total revenue attributed to the driver
    average_mpg             DECIMAL(4,2),     -- Average fuel efficiency
    total_fuel_gallons      DECIMAL(6,1),     -- Total fuel consumed during the month
    on_time_delivery_rate   DECIMAL(5,4),     -- On-time delivery proportion; 1.0000 = 100%
    average_idle_hours      DECIMAL(3,1)      -- Average idle hours; calculation period to be confirmed
);


-- ============================================================
-- 14. TRUCK UTILIZATION METRICS
-- Aggregated operational, maintenance and utilization metrics
-- by truck/month.
-- Grain: One row per truck per reporting month.
-- ============================================================

IF OBJECT_ID('silver.truck_utilization_metrics', 'U') IS NOT NULL
    DROP TABLE silver.truck_utilization_metrics;

CREATE TABLE silver.truck_utilization_metrics
(
    truck_id           VARCHAR(50),      -- Truck associated with the metrics
    month              DATE,             -- Reporting month
    trips_completed    SMALLINT,         -- Number of completed trips
    total_miles        DECIMAL(9,2),     -- Total miles travelled during the month
    total_revenue      DECIMAL(12,2),    -- Total revenue attributed to the truck
    average_mpg        DECIMAL(4,2),     -- Average fuel efficiency
    maintenance_events SMALLINT,         -- Number of maintenance events
    maintenance_cost   DECIMAL(8,2),     -- Total maintenance cost
    downtime_hours     DECIMAL(4,1),     -- Total downtime in hours
    utilization_rate   DECIMAL(6,4)      -- Utilization measure; formula and scale need confirmation
);
