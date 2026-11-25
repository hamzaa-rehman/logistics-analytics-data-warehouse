/*
===============================================================================
GOLD LAYER - TABLE CREATION
===============================================================================
Purpose:
    Create the dimensional reporting model for the Logistics Analytics
    Data Warehouse.

Design:
    - Seven dimensions and six transaction-level fact tables.
    - Entity dimensions use warehouse-generated INT IDENTITY surrogate keys.
    - Source business identifiers are retained as NOT NULL UNIQUE columns.
    - Fact tables use BIGINT IDENTITY primary keys and retain source identifiers.
    - Date dimension uses an integer YYYYMMDD key and covers 2012-01-01 to
      2025-12-31 inclusive.
    - Source attributes retain their Silver datatypes and nullability unless
      explicitly excluded or described below.
    - Fact date keys are NOT NULL because source profiling confirmed complete
      date values for the selected transaction date columns. The load process
      must validate these values before insertion.
    - Nullable source entity relationships remain nullable in Gold.
    - No fact-to-fact foreign keys are created. Source identifiers such as
      load_id and trip_id are retained for traceability without creating
      unsafe cross-fact dependencies.
    - Driver date_of_birth and license_number, fuel_card_number, and safety
      incident description are intentionally excluded from Gold reporting.

Important:
    - This script creates the Gold structures and populates the static date dimension.
    - It does not load transactional dimension or fact data.
    - The date dimension stores both calendar year and ISO week-year separately.
    - Run reset_gold.sql only when a full Gold rebuild is intended.
    - Validate source-to-target lookups and date keys in the Gold load process.

Database: LogisticsAnalytics
Schema:   gold
Tables:   13
===============================================================================
*/

USE LogisticsAnalytics;
GO

IF SCHEMA_ID(N'gold') IS NULL
    EXEC(N'CREATE SCHEMA gold');
GO

-- ============================================================================
-- 1. DIMENSION: CUSTOMER
-- Grain: One row per source customer.
-- ============================================================================
CREATE TABLE gold.dim_customer
(
    customer_key            INT IDENTITY(1,1) NOT NULL,
    customer_id             VARCHAR(50) NOT NULL,
    customer_name           VARCHAR(255) NULL,
    customer_type           VARCHAR(100) NULL,
    credit_terms_days       INT NULL,
    primary_freight_type    VARCHAR(50) NULL,
    account_status          VARCHAR(30) NULL,
    contract_start_date     DATE NULL,
    annual_revenue_potential INT NULL,

    CONSTRAINT PK_dim_customer PRIMARY KEY (customer_key),
    CONSTRAINT UQ_dim_customer_customer_id UNIQUE (customer_id)
);
GO

-- ============================================================================
-- 2. DIMENSION: DRIVER
-- Grain: One row per source driver.
-- PII excluded: license_number and date_of_birth.
-- ============================================================================
CREATE TABLE gold.dim_driver
(
    driver_key          INT IDENTITY(1,1) NOT NULL,
    driver_id           VARCHAR(50) NOT NULL,
    first_name          VARCHAR(100) NULL,
    last_name           VARCHAR(100) NULL,
    hire_date           DATE NULL,
    termination_date    DATE NULL,
    license_state       VARCHAR(50) NULL,
    home_terminal       VARCHAR(100) NULL,
    employment_status   VARCHAR(30) NULL,
    cdl_class           VARCHAR(1) NULL,
    years_experience    SMALLINT NULL,

    CONSTRAINT PK_dim_driver PRIMARY KEY (driver_key),
    CONSTRAINT UQ_dim_driver_driver_id UNIQUE (driver_id)
);
GO

-- ============================================================================
-- 3. DIMENSION: TRUCK
-- Grain: One row per source truck.
-- ============================================================================
CREATE TABLE gold.dim_truck
(
    truck_key               INT IDENTITY(1,1) NOT NULL,
    truck_id                VARCHAR(50) NOT NULL,
    unit_number             VARCHAR(50) NULL,
    make                    VARCHAR(80) NULL,
    model_year              SMALLINT NULL,
    vin                     VARCHAR(150) NULL,
    acquisition_date        DATE NULL,
    acquisition_mileage     INT NULL,
    fuel_type               VARCHAR(30) NULL,
    tank_capacity_gallons   SMALLINT NULL,
    status                  VARCHAR(50) NULL,
    home_terminal           VARCHAR(100) NULL,

    CONSTRAINT PK_dim_truck PRIMARY KEY (truck_key),
    CONSTRAINT UQ_dim_truck_truck_id UNIQUE (truck_id)
);
GO

-- ============================================================================
-- 4. DIMENSION: TRAILER
-- Grain: One row per source trailer.
-- ============================================================================
CREATE TABLE gold.dim_trailer
(
    trailer_key        INT IDENTITY(1,1) NOT NULL,
    trailer_id         VARCHAR(50) NOT NULL,
    trailer_number     VARCHAR(50) NULL,
    trailer_type       VARCHAR(100) NULL,
    length_feet        SMALLINT NULL,
    model_year         SMALLINT NULL,
    vin                VARCHAR(150) NULL,
    acquisition_date   DATE NULL,
    status             VARCHAR(50) NULL,
    current_location   VARCHAR(100) NULL,

    CONSTRAINT PK_dim_trailer PRIMARY KEY (trailer_key),
    CONSTRAINT UQ_dim_trailer_trailer_id UNIQUE (trailer_id)
);
GO

-- ============================================================================
-- 5. DIMENSION: ROUTE
-- Grain: One row per source route.
-- ============================================================================
CREATE TABLE gold.dim_route
(
    route_key               INT IDENTITY(1,1) NOT NULL,
    route_id                VARCHAR(50) NOT NULL,
    origin_city             VARCHAR(100) NULL,
    origin_state            VARCHAR(50) NULL,
    destination_city        VARCHAR(100) NULL,
    destination_state       VARCHAR(50) NULL,
    typical_distance_miles  DECIMAL(10,2) NULL,
    base_rate_per_mile      DECIMAL(10,4) NULL,
    fuel_surcharge_rate     DECIMAL(10,6) NULL,
    typical_transit_days    SMALLINT NULL,

    CONSTRAINT PK_dim_route PRIMARY KEY (route_key),
    CONSTRAINT UQ_dim_route_route_id UNIQUE (route_id)
);
GO

-- ============================================================================
-- 6. DIMENSION: FACILITY
-- Grain: One row per source facility.
-- ============================================================================
CREATE TABLE gold.dim_facility
(
    facility_key    INT IDENTITY(1,1) NOT NULL,
    facility_id     VARCHAR(50) NOT NULL,
    facility_name   VARCHAR(100) NULL,
    facility_type   VARCHAR(100) NULL,
    city            VARCHAR(100) NULL,
    state           VARCHAR(10) NULL,
    latitude        DECIMAL(10,6) NULL,
    longitude       DECIMAL(10,6) NULL,
    dock_doors      INT NULL,
    operating_hours VARCHAR(50) NULL,

    CONSTRAINT PK_dim_facility PRIMARY KEY (facility_key),
    CONSTRAINT UQ_dim_facility_facility_id UNIQUE (facility_id)
);
GO

-- ============================================================================
-- 7. DIMENSION: DATE
-- Grain: One row per calendar date.
-- Key format: YYYYMMDD. Week starts Monday; ISO week numbering is used.
-- ============================================================================
CREATE TABLE gold.dim_date
(
    date_key        INT NOT NULL,
    full_date       DATE NOT NULL,
    day_of_month    TINYINT NOT NULL,
    day_name        VARCHAR(10) NOT NULL,
    day_of_week     TINYINT NOT NULL, -- Monday = 1, Sunday = 7
    week_of_year    TINYINT NOT NULL, -- ISO week number (1-53)
    iso_week_year   SMALLINT NOT NULL, -- Year to which the ISO week belongs
    month_number    TINYINT NOT NULL,
    month_name      VARCHAR(10) NOT NULL,
    quarter_number  TINYINT NOT NULL,
    year_number     SMALLINT NOT NULL,
    year_month      CHAR(7) NOT NULL,
    is_weekend      BIT NOT NULL,

    CONSTRAINT PK_dim_date PRIMARY KEY (date_key),
    CONSTRAINT UQ_dim_date_full_date UNIQUE (full_date)
);
GO

;WITH calendar_dates AS
(
    SELECT CONVERT(DATE, '20120101', 112) AS calendar_date
    UNION ALL
    SELECT DATEADD(DAY, 1, calendar_date)
    FROM calendar_dates
    WHERE calendar_date < CONVERT(DATE, '20251231', 112)
),
calendar_attributes AS
(
    SELECT
        calendar_date,
        CONVERT(TINYINT, DATEDIFF(DAY, CONVERT(DATE, '19000101', 112), calendar_date) % 7 + 1) AS weekday_number
    FROM calendar_dates
)
INSERT INTO gold.dim_date
(
    date_key, full_date, day_of_month, day_name, day_of_week,
    week_of_year, iso_week_year, month_number, month_name, quarter_number,
    year_number, year_month, is_weekend
)
SELECT
    YEAR(calendar_date) * 10000 + MONTH(calendar_date) * 100 + DAY(calendar_date),
    calendar_date,
    DAY(calendar_date),
    CASE weekday_number
        WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday' WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday' WHEN 6 THEN 'Saturday'
        WHEN 7 THEN 'Sunday'
    END,
    weekday_number,
    DATEPART(ISO_WEEK, calendar_date),
    YEAR(DATEADD(DAY, 4 - weekday_number, calendar_date)),
    MONTH(calendar_date),
    CASE MONTH(calendar_date)
        WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
        WHEN 4 THEN 'April' WHEN 5 THEN 'May' WHEN 6 THEN 'June'
        WHEN 7 THEN 'July' WHEN 8 THEN 'August' WHEN 9 THEN 'September'
        WHEN 10 THEN 'October' WHEN 11 THEN 'November' WHEN 12 THEN 'December'
    END,
    DATEPART(QUARTER, calendar_date),
    YEAR(calendar_date),
    CONVERT(CHAR(7), calendar_date, 126),
    CASE WHEN weekday_number IN (6, 7) THEN 1 ELSE 0 END
FROM calendar_attributes
OPTION (MAXRECURSION 0);
GO

-- ============================================================================
-- DATE DIMENSION VALIDATION
-- Confirm the generated calendar range and ISO week attributes.
-- ISO week-year is the calendar year containing the Thursday of the ISO week.
-- ============================================================================
IF
(
    SELECT COUNT(*)
    FROM gold.dim_date
) <> 5114
    THROW 51001, 'dim_date must contain exactly 5,114 dates.', 1;

IF EXISTS
(
    SELECT 1
    FROM gold.dim_date
    WHERE full_date < CONVERT(DATE, '20120101', 112)
       OR full_date > CONVERT(DATE, '20251231', 112)
       OR week_of_year <> DATEPART(ISO_WEEK, full_date)
       OR iso_week_year <> YEAR(DATEADD(DAY, 4 - day_of_week, full_date))
)
    THROW 51002, 'dim_date contains an invalid date range or ISO week attribute.', 1;

-- Boundary examples: calendar year and ISO week-year can differ.
SELECT
    full_date,
    year_number AS calendar_year,
    week_of_year AS iso_week_number,
    iso_week_year
FROM gold.dim_date
WHERE full_date IN
(
    CONVERT(DATE, '20210101', 112),
    CONVERT(DATE, '20210104', 112),
    CONVERT(DATE, '20241230', 112),
    CONVERT(DATE, '20241231', 112),
    CONVERT(DATE, '20250101', 112)
)
ORDER BY full_date;
GO

-- ============================================================================
-- 8. FACT: LOADS
-- Grain: One row per load.
-- Reported load revenue is revenue only; other charges remain separate.
-- ============================================================================
CREATE TABLE gold.fact_loads
(
    load_fact_key       BIGINT IDENTITY(1,1) NOT NULL,
    load_id             VARCHAR(50) NOT NULL,
    customer_key        INT NULL,
    route_key           INT NULL,
    load_date_key       INT NOT NULL,
    load_type           VARCHAR(100) NULL,
    weight_lbs          DECIMAL(12,2) NULL,
    pieces              SMALLINT NULL,
    revenue             DECIMAL(12,2) NULL,
    fuel_surcharge      DECIMAL(12,2) NULL,
    accessorial_charges DECIMAL(12,2) NULL,
    load_status         VARCHAR(50) NULL,
    booking_type        VARCHAR(50) NULL,

    CONSTRAINT PK_fact_loads PRIMARY KEY (load_fact_key),
    CONSTRAINT UQ_fact_loads_load_id UNIQUE (load_id),
    CONSTRAINT FK_fact_loads_customer FOREIGN KEY (customer_key)
        REFERENCES gold.dim_customer (customer_key),
    CONSTRAINT FK_fact_loads_route FOREIGN KEY (route_key)
        REFERENCES gold.dim_route (route_key),
    CONSTRAINT FK_fact_loads_date FOREIGN KEY (load_date_key)
        REFERENCES gold.dim_date (date_key)
);
GO

-- ============================================================================
-- 9. FACT: TRIPS
-- Grain: One row per trip. load_id retained for traceability only.
-- ============================================================================
CREATE TABLE gold.fact_trips
(
    trip_fact_key           BIGINT IDENTITY(1,1) NOT NULL,
    trip_id                 VARCHAR(50) NOT NULL,
    load_id                 VARCHAR(50) NULL,
    driver_key              INT NULL,
    truck_key               INT NULL,
    trailer_key             INT NULL,
    dispatch_date_key       INT NOT NULL,
    actual_distance_miles   DECIMAL(6,2) NULL,
    actual_duration_hours   DECIMAL(5,1) NULL,
    fuel_gallons_used       DECIMAL(5,1) NULL,
    average_mpg             DECIMAL(5,2) NULL,
    idle_time_hours         DECIMAL(5,2) NULL,
    trip_status             VARCHAR(50) NULL,

    CONSTRAINT PK_fact_trips PRIMARY KEY (trip_fact_key),
    CONSTRAINT UQ_fact_trips_trip_id UNIQUE (trip_id),
    CONSTRAINT FK_fact_trips_driver FOREIGN KEY (driver_key)
        REFERENCES gold.dim_driver (driver_key),
    CONSTRAINT FK_fact_trips_truck FOREIGN KEY (truck_key)
        REFERENCES gold.dim_truck (truck_key),
    CONSTRAINT FK_fact_trips_trailer FOREIGN KEY (trailer_key)
        REFERENCES gold.dim_trailer (trailer_key),
    CONSTRAINT FK_fact_trips_dispatch_date FOREIGN KEY (dispatch_date_key)
        REFERENCES gold.dim_date (date_key)
);
GO

-- ============================================================================
-- 10. FACT: DELIVERY EVENTS
-- Grain: One row per pickup or delivery event.
-- Scheduled and actual date keys are roles of the shared date dimension.
-- ============================================================================
CREATE TABLE gold.fact_delivery_events
(
    delivery_event_fact_key BIGINT IDENTITY(1,1) NOT NULL,
    event_id                VARCHAR(50) NOT NULL,
    load_id                 VARCHAR(50) NULL,
    trip_id                 VARCHAR(50) NULL,
    facility_key            INT NULL,
    scheduled_date_key      INT NOT NULL,
    actual_date_key         INT NOT NULL,
    event_type              VARCHAR(50) NULL,
    scheduled_datetime      DATETIME2 NULL,
    actual_datetime         DATETIME2 NULL,
    detention_minutes       SMALLINT NULL,
    on_time_flag            BIT NULL,
    location_city           VARCHAR(100) NULL,
    location_state          VARCHAR(10) NULL,

    CONSTRAINT PK_fact_delivery_events PRIMARY KEY (delivery_event_fact_key),
    CONSTRAINT UQ_fact_delivery_events_event_id UNIQUE (event_id),
    CONSTRAINT FK_fact_delivery_events_facility FOREIGN KEY (facility_key)
        REFERENCES gold.dim_facility (facility_key),
    CONSTRAINT FK_fact_delivery_events_scheduled_date FOREIGN KEY (scheduled_date_key)
        REFERENCES gold.dim_date (date_key),
    CONSTRAINT FK_fact_delivery_events_actual_date FOREIGN KEY (actual_date_key)
        REFERENCES gold.dim_date (date_key)
);
GO

-- ============================================================================
-- 11. FACT: FUEL PURCHASES
-- Grain: One row per fuel purchase. Entity keys use purchase-level IDs.
-- ============================================================================
CREATE TABLE gold.fact_fuel_purchases
(
    fuel_purchase_fact_key BIGINT IDENTITY(1,1) NOT NULL,
    fuel_purchase_id       VARCHAR(50) NOT NULL,
    trip_id                VARCHAR(50) NULL,
    truck_key              INT NULL,
    driver_key             INT NULL,
    purchase_date_key      INT NOT NULL,
    purchase_date          DATETIME2 NULL,
    location_city          VARCHAR(100) NULL,
    location_state         VARCHAR(10) NULL,
    gallons                DECIMAL(10,2) NULL,
    price_per_gallon       DECIMAL(5,4) NULL,
    total_cost             DECIMAL(8,2) NULL,

    CONSTRAINT PK_fact_fuel_purchases PRIMARY KEY (fuel_purchase_fact_key),
    CONSTRAINT UQ_fact_fuel_purchases_purchase_id UNIQUE (fuel_purchase_id),
    CONSTRAINT FK_fact_fuel_purchases_truck FOREIGN KEY (truck_key)
        REFERENCES gold.dim_truck (truck_key),
    CONSTRAINT FK_fact_fuel_purchases_driver FOREIGN KEY (driver_key)
        REFERENCES gold.dim_driver (driver_key),
    CONSTRAINT FK_fact_fuel_purchases_date FOREIGN KEY (purchase_date_key)
        REFERENCES gold.dim_date (date_key)
);
GO

-- ============================================================================
-- 12. FACT: MAINTENANCE RECORDS
-- Grain: One row per maintenance record.
-- facility_location remains source text; it is not a facility_id.
-- ============================================================================
CREATE TABLE gold.fact_maintenance_records
(
    maintenance_fact_key BIGINT IDENTITY(1,1) NOT NULL,
    maintenance_id       VARCHAR(50) NOT NULL,
    truck_key             INT NULL,
    maintenance_date_key INT NOT NULL,
    maintenance_type     VARCHAR(100) NULL,
    odometer_reading     INT NULL,
    labor_hours          DECIMAL(4,1) NULL,
    labor_cost           DECIMAL(7,2) NULL,
    parts_cost           DECIMAL(8,2) NULL,
    total_cost           DECIMAL(8,2) NULL,
    facility_location    VARCHAR(100) NULL,
    downtime_hours       DECIMAL(4,1) NULL,
    service_description  VARCHAR(200) NULL,

    CONSTRAINT PK_fact_maintenance_records PRIMARY KEY (maintenance_fact_key),
    CONSTRAINT UQ_fact_maintenance_records_maintenance_id UNIQUE (maintenance_id),
    CONSTRAINT FK_fact_maintenance_records_truck FOREIGN KEY (truck_key)
        REFERENCES gold.dim_truck (truck_key),
    CONSTRAINT FK_fact_maintenance_records_date FOREIGN KEY (maintenance_date_key)
        REFERENCES gold.dim_date (date_key)
);
GO

-- ============================================================================
-- 13. FACT: SAFETY INCIDENTS
-- Grain: One row per safety incident. Claim amount is not additive to
-- vehicle/cargo damage components; it already represents their combined value.
-- ============================================================================
CREATE TABLE gold.fact_safety_incidents
(
    safety_incident_fact_key BIGINT IDENTITY(1,1) NOT NULL,
    incident_id              VARCHAR(50) NOT NULL,
    trip_id                  VARCHAR(50) NULL,
    truck_key                INT NULL,
    driver_key               INT NULL,
    incident_date_key        INT NOT NULL,
    incident_date            DATETIME2 NULL,
    incident_type            VARCHAR(100) NULL,
    location_city            VARCHAR(100) NULL,
    location_state           VARCHAR(10) NULL,
    at_fault_flag            BIT NULL,
    injury_flag              BIT NULL,
    vehicle_damage_cost      DECIMAL(8,2) NULL,
    cargo_damage_cost        DECIMAL(8,2) NULL,
    claim_amount             DECIMAL(8,2) NULL,
    preventable_flag         BIT NULL,

    CONSTRAINT PK_fact_safety_incidents PRIMARY KEY (safety_incident_fact_key),
    CONSTRAINT UQ_fact_safety_incidents_incident_id UNIQUE (incident_id),
    CONSTRAINT FK_fact_safety_incidents_truck FOREIGN KEY (truck_key)
        REFERENCES gold.dim_truck (truck_key),
    CONSTRAINT FK_fact_safety_incidents_driver FOREIGN KEY (driver_key)
        REFERENCES gold.dim_driver (driver_key),
    CONSTRAINT FK_fact_safety_incidents_date FOREIGN KEY (incident_date_key)
        REFERENCES gold.dim_date (date_key)
);
GO

/*
POST-CREATION STRUCTURAL CHECK (run after the script completes):

Confirm that all 13 Gold tables were created.
*/
SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = 'gold'
ORDER BY t.name;