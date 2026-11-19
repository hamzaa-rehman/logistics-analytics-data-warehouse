
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
    - Define primary keys and foreign keys as named constraints
      within the CREATE TABLE statements.
    - Primary-key columns are NOT NULL.
    - Preserve the original nullability of all non-primary-key
      columns, including nullable foreign-key columns.
    - Do not define UNIQUE or CHECK constraints in this script.
    - Use CREATE TABLE statements only; no ALTER TABLE statements.

    Execution:
    - Create the Silver schema if it does not already exist.
    - Create all 14 tables in parent-to-child dependency order.
    - Parent tables must exist before dependent tables are created.
    - Execute this script after reset_silver.sql when a full
      Silver rebuild is required.

    Deployment:
    - This script creates table structures only.
    - It does not drop existing tables or delete existing data.
    - It does not load or transform Bronze data.
    - Silver data loading and validation are handled separately.

    Related Scripts:
    - reset_silver.sql : Drops existing Silver tables.
    - ddl_silver.sql   : Creates Silver table structures.
    - load_silver.sql  : Loads and transforms Bronze data (planned).

    Database: LogisticsAnalytics
    Schema:   silver
    Tables:   14
*/



-- ============================================================
-- 1. CUSTOMERS
-- Customer account and commercial information.
-- Grain: One row per customer.
-- ============================================================

CREATE TABLE silver.customers
(
    customer_id              VARCHAR(50)  NOT NULL,   -- Unique customer identifier
    customer_name            VARCHAR(255),    -- Customer or company name
    customer_type            VARCHAR(100),    -- Classification of the customer
    credit_terms_days        INT,             -- Agreed credit period in days
    primary_freight_type     VARCHAR(50),     -- Main freight category handled
    account_status           VARCHAR(30),     -- Current account status
    contract_start_date      DATE,            -- Date the customer contract began
    annual_revenue_potential INT,             -- Estimated annual revenue potential

    CONSTRAINT PK_customers
        PRIMARY KEY (customer_id)
);


-- ============================================================
-- 2. DRIVERS
-- Driver identity, employment and licensing information.
-- Grain: One row per driver.
-- ============================================================

CREATE TABLE silver.drivers
(
    driver_id          VARCHAR(50)  NOT NULL,   -- Unique driver identifier
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
    years_experience   SMALLINT,        -- Reported years of driving experience

    CONSTRAINT PK_drivers
        PRIMARY KEY (driver_id)
);


-- ============================================================
-- 3. FACILITIES
-- Facility locations and operational characteristics.
-- Grain: One row per facility.
-- ============================================================

CREATE TABLE silver.facilities
(
    facility_id       VARCHAR(50)  NOT NULL,   -- Unique facility identifier
    facility_name     VARCHAR(100),      -- Facility name
    facility_type     VARCHAR(100),      -- Type of facility
    city              VARCHAR(100),      -- Facility city
    state             VARCHAR(10),       -- State or regional code
    latitude          DECIMAL(10,6),     -- Geographic latitude
    longitude         DECIMAL(10,6),     -- Geographic longitude
    dock_doors        INT,               -- Number of loading dock doors
    operating_hours   VARCHAR(50),       -- Facility operating hours or schedule

    CONSTRAINT PK_facilities
        PRIMARY KEY (facility_id)
);


-- ============================================================
-- 4. ROUTES
-- Standard route information and pricing assumptions.
-- Grain: One row per route.
-- ============================================================

CREATE TABLE silver.routes
(
    route_id                VARCHAR(50)  NOT NULL,   -- Unique route identifier
    origin_city             VARCHAR(100),     -- Route starting city
    origin_state            VARCHAR(50),      -- Route starting state
    destination_city        VARCHAR(100),     -- Route destination city
    destination_state       VARCHAR(50),      -- Route destination state
    typical_distance_miles  DECIMAL(10,2),    -- Expected route distance in miles
    base_rate_per_mile      DECIMAL(10,4),    -- Standard charge per mile
    fuel_surcharge_rate     DECIMAL(10,6),    -- Fuel surcharge rate; scale requires confirmation
    typical_transit_days    SMALLINT,         -- Expected transit duration in days

    CONSTRAINT PK_routes
        PRIMARY KEY (route_id)
);


-- ============================================================
-- 5. TRUCKS
-- Truck identification, acquisition and operational information.
-- Grain: One row per truck.
-- ============================================================

CREATE TABLE silver.trucks
(
    truck_id              VARCHAR(50)  NOT NULL,   -- Unique truck identifier
    unit_number           VARCHAR(50),     -- Internal truck unit number
    make                  VARCHAR(80),     -- Truck manufacturer
    model_year            SMALLINT,        -- Truck model year
    vin                   VARCHAR(150),    -- Vehicle identification number; source values need validation
    acquisition_date      DATE,            -- Date the truck was acquired
    acquisition_mileage   INT,             -- Mileage recorded at acquisition
    fuel_type             VARCHAR(30),     -- Truck fuel type
    tank_capacity_gallons SMALLINT,        -- Fuel tank capacity in gallons
    status                VARCHAR(50),     -- Current truck status
    home_terminal         VARCHAR(100),    -- Truck's assigned home terminal

    CONSTRAINT PK_trucks
        PRIMARY KEY (truck_id)
);


-- ============================================================
-- 6. TRAILERS
-- Trailer identification, specifications and current status.
-- Grain: One row per trailer.
-- ============================================================

CREATE TABLE silver.trailers
(
    trailer_id       VARCHAR(50)  NOT NULL,   -- Unique trailer identifier
    trailer_number   VARCHAR(50),     -- Internal trailer number
    trailer_type     VARCHAR(100),    -- Trailer classification
    length_feet      SMALLINT,        -- Trailer length in feet
    model_year       SMALLINT,        -- Trailer model year
    vin              VARCHAR(150),    -- Trailer vehicle identification number
    acquisition_date DATE,            -- Date the trailer was acquired
    status           VARCHAR(50),     -- Current trailer status
    current_location VARCHAR(100),    -- Trailer's reported current location

    CONSTRAINT PK_trailers
        PRIMARY KEY (trailer_id)
);


-- ============================================================
-- 7. LOADS
-- Customer freight bookings and commercial load information.
-- Grain: One row per load.
-- ============================================================

CREATE TABLE silver.loads
(
    load_id               VARCHAR(50)  NOT NULL,   -- Unique load identifier
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
    booking_type          VARCHAR(50),       -- Load booking classification

    CONSTRAINT PK_loads
        PRIMARY KEY (load_id),

    CONSTRAINT FK_loads_customers
        FOREIGN KEY (customer_id)
        REFERENCES silver.customers (customer_id),

    CONSTRAINT FK_loads_routes
        FOREIGN KEY (route_id)
        REFERENCES silver.routes (route_id)
);


-- ============================================================
-- 8. TRIPS
-- Actual transportation execution and trip performance.
-- Grain: One row per trip.
-- ============================================================

CREATE TABLE silver.trips
(
    trip_id                 VARCHAR(50)  NOT NULL,   -- Unique trip identifier
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
    trip_status             VARCHAR(50),      -- Current or final trip status

    CONSTRAINT PK_trips
        PRIMARY KEY (trip_id),

    CONSTRAINT FK_trips_loads
        FOREIGN KEY (load_id)
        REFERENCES silver.loads (load_id),

    CONSTRAINT FK_trips_drivers
        FOREIGN KEY (driver_id)
        REFERENCES silver.drivers (driver_id),

    CONSTRAINT FK_trips_trucks
        FOREIGN KEY (truck_id)
        REFERENCES silver.trucks (truck_id),

    CONSTRAINT FK_trips_trailers
        FOREIGN KEY (trailer_id)
        REFERENCES silver.trailers (trailer_id)
);


-- ============================================================
-- 9. FUEL PURCHASES
-- Fuel transactions associated with trucks, drivers and trips.
-- Grain: One row per fuel purchase.
-- ============================================================

CREATE TABLE silver.fuel_purchases
(
    fuel_purchase_id  VARCHAR(50)  NOT NULL,   -- Unique fuel purchase identifier
    trip_id           VARCHAR(50),      -- Trip associated with the fuel purchase
    truck_id          VARCHAR(50),      -- Truck making the purchase; may be NULL
    driver_id         VARCHAR(50),      -- Driver making the purchase; may be NULL
    purchase_date     DATETIME2,        -- Fuel purchase date and time
    location_city     VARCHAR(100),     -- City where fuel was purchased
    location_state    VARCHAR(10),      -- State where fuel was purchased
    gallons           DECIMAL(10,2),    -- Quantity of fuel purchased in gallons
    price_per_gallon  DECIMAL(5,4),     -- Price charged per gallon
    total_cost        DECIMAL(8,2),     -- Total fuel purchase cost
    fuel_card_number  VARCHAR(50),      -- Fuel card used for the transaction

    CONSTRAINT PK_fuel_purchases
        PRIMARY KEY (fuel_purchase_id),

    CONSTRAINT FK_fuel_purchases_trips
        FOREIGN KEY (trip_id)
        REFERENCES silver.trips (trip_id),

    CONSTRAINT FK_fuel_purchases_trucks
        FOREIGN KEY (truck_id)
        REFERENCES silver.trucks (truck_id),

    CONSTRAINT FK_fuel_purchases_drivers
        FOREIGN KEY (driver_id)
        REFERENCES silver.drivers (driver_id)
);


-- ============================================================
-- 10. MAINTENANCE RECORDS
-- Truck maintenance activities, costs and downtime.
-- Grain: One row per maintenance record.
-- ============================================================

CREATE TABLE silver.maintenance_records
(
    maintenance_id      VARCHAR(50)  NOT NULL,   -- Unique maintenance record identifier
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
    service_description VARCHAR(200),     -- Description of the service performed

    CONSTRAINT PK_maintenance_records
        PRIMARY KEY (maintenance_id),

    CONSTRAINT FK_maintenance_records_trucks
        FOREIGN KEY (truck_id)
        REFERENCES silver.trucks (truck_id)
);


-- ============================================================
-- 11. DELIVERY EVENTS
-- Scheduled and actual milestones during load delivery.
-- Grain: One row per delivery event.
-- ============================================================

CREATE TABLE silver.delivery_events
(
    event_id            VARCHAR(50)  NOT NULL,   -- Unique delivery event identifier
    load_id             VARCHAR(50),      -- Load associated with the event
    trip_id             VARCHAR(50),      -- Trip associated with the event
    event_type          VARCHAR(50),      -- Event classification, e.g. pickup or delivery
    facility_id         VARCHAR(50),      -- Facility associated with the event
    scheduled_datetime  DATETIME2,        -- Scheduled event date and time
    actual_datetime     DATETIME2,        -- Actual event date and time
    detention_minutes   SMALLINT,         -- Detention duration in minutes
    on_time_flag        BIT,              -- 1 = on time, 0 = not on time
    location_city       VARCHAR(100),     -- City where the event occurred
    location_state      VARCHAR(10),      -- State where the event occurred

    CONSTRAINT PK_delivery_events
        PRIMARY KEY (event_id),

    CONSTRAINT FK_delivery_events_loads
        FOREIGN KEY (load_id)
        REFERENCES silver.loads (load_id),

    CONSTRAINT FK_delivery_events_trips
        FOREIGN KEY (trip_id)
        REFERENCES silver.trips (trip_id),

    CONSTRAINT FK_delivery_events_facilities
        FOREIGN KEY (facility_id)
        REFERENCES silver.facilities (facility_id)
);


-- ============================================================
-- 12. SAFETY INCIDENTS
-- Safety events, responsibility indicators and financial impact.
-- Grain: One row per safety incident.
-- ============================================================

CREATE TABLE silver.safety_incidents
(
    incident_id          VARCHAR(50)  NOT NULL,   -- Unique safety incident identifier
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
    description          VARCHAR(100),     -- Detailed incident description

    CONSTRAINT PK_safety_incidents
        PRIMARY KEY (incident_id),

    CONSTRAINT FK_safety_incidents_trips
        FOREIGN KEY (trip_id)
        REFERENCES silver.trips (trip_id),

    CONSTRAINT FK_safety_incidents_trucks
        FOREIGN KEY (truck_id)
        REFERENCES silver.trucks (truck_id),

    CONSTRAINT FK_safety_incidents_drivers
        FOREIGN KEY (driver_id)
        REFERENCES silver.drivers (driver_id)
);


-- ============================================================
-- 13. DRIVER MONTHLY METRICS
-- Aggregated operational and performance metrics by driver/month.
-- Grain: One row per driver per reporting month.
-- ============================================================

CREATE TABLE silver.driver_monthly_metrics
(
    driver_id               VARCHAR(50)  NOT NULL,   -- Driver associated with the metrics
    [month]                 DATE         NOT NULL,   -- Reporting month
    trips_completed         SMALLINT,         -- Number of completed trips
    total_miles             DECIMAL(8,2),     -- Total miles driven during the month
    total_revenue           DECIMAL(12,2),    -- Total revenue attributed to the driver
    average_mpg             DECIMAL(4,2),     -- Average fuel efficiency
    total_fuel_gallons      DECIMAL(6,1),     -- Total fuel consumed during the month
    on_time_delivery_rate   DECIMAL(5,4),     -- On-time delivery proportion; 1.0000 = 100%
    average_idle_hours      DECIMAL(3,1),     -- Average idle hours; calculation period to be confirmed

    CONSTRAINT PK_driver_monthly_metrics
        PRIMARY KEY (driver_id, [month]),

    CONSTRAINT FK_driver_monthly_metrics_drivers
        FOREIGN KEY (driver_id)
        REFERENCES silver.drivers (driver_id)
);


-- ============================================================
-- 14. TRUCK UTILIZATION METRICS
-- Aggregated operational, maintenance and utilization metrics
-- by truck/month.
-- Grain: One row per truck per reporting month.
-- ============================================================

CREATE TABLE silver.truck_utilization_metrics
(
    truck_id           VARCHAR(50)  NOT NULL,   -- Truck associated with the metrics
    [month]            DATE         NOT NULL,   -- Reporting month
    trips_completed    SMALLINT,         -- Number of completed trips
    total_miles        DECIMAL(9,2),     -- Total miles travelled during the month
    total_revenue      DECIMAL(12,2),    -- Total revenue attributed to the truck
    average_mpg        DECIMAL(4,2),     -- Average fuel efficiency
    maintenance_events SMALLINT,         -- Number of maintenance events
    maintenance_cost   DECIMAL(8,2),     -- Total maintenance cost
    downtime_hours     DECIMAL(4,1),     -- Total downtime in hours
    trips_per_day      DECIMAL(6,4),     -- Utilization measure; formula and scale need confirmation

    CONSTRAINT PK_truck_utilization_metrics
        PRIMARY KEY (truck_id, [month]),

    CONSTRAINT FK_truck_utilization_metrics_trucks
        FOREIGN KEY (truck_id)
        REFERENCES silver.trucks (truck_id)
);
