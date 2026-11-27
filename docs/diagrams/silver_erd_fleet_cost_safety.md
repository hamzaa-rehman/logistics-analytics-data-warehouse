# Silver ERD — Fleet, Cost & Safety

Driver and vehicle assignments, fuel purchases, maintenance activity, and safety incidents.

**Schema:** `silver` · **Source of truth:** [`ddl_silver.sql`](../../scripts/silver/ddl_silver.sql)

This focused view is separated from the full 14-table ERD to make table definitions and relationships easier to inspect. It does not change the implemented schema.

```mermaid
erDiagram
    drivers {
        VARCHAR_50_ driver_id PK
        VARCHAR_100_ first_name
        VARCHAR_100_ last_name
        DATE hire_date
        DATE termination_date
        VARCHAR_100_ license_number
        VARCHAR_50_ license_state
        DATE date_of_birth
        VARCHAR_100_ home_terminal
        VARCHAR_30_ employment_status
        VARCHAR_1_ cdl_class
        SMALLINT years_experience
    }
    trucks {
        VARCHAR_50_ truck_id PK
        VARCHAR_50_ unit_number
        VARCHAR_80_ make
        SMALLINT model_year
        VARCHAR_150_ vin
        DATE acquisition_date
        INT acquisition_mileage
        VARCHAR_30_ fuel_type
        SMALLINT tank_capacity_gallons
        VARCHAR_50_ status
        VARCHAR_100_ home_terminal
    }
    trailers {
        VARCHAR_50_ trailer_id PK
        VARCHAR_50_ trailer_number
        VARCHAR_100_ trailer_type
        SMALLINT length_feet
        SMALLINT model_year
        VARCHAR_150_ vin
        DATE acquisition_date
        VARCHAR_50_ status
        VARCHAR_100_ current_location
    }
    trips {
        VARCHAR_50_ trip_id PK
        VARCHAR_50_ load_id FK
        VARCHAR_50_ driver_id FK
        VARCHAR_50_ truck_id FK
        VARCHAR_50_ trailer_id FK
        DATE dispatch_date
        DECIMAL_6_2_ actual_distance_miles
        DECIMAL_5_1_ actual_duration_hours
        DECIMAL_5_1_ fuel_gallons_used
        DECIMAL_5_2_ average_mpg
        DECIMAL_5_2_ idle_time_hours
        VARCHAR_50_ trip_status
    }
    fuel_purchases {
        VARCHAR_50_ fuel_purchase_id PK
        VARCHAR_50_ trip_id FK
        VARCHAR_50_ truck_id FK
        VARCHAR_50_ driver_id FK
        DATETIME2 purchase_date
        VARCHAR_100_ location_city
        VARCHAR_10_ location_state
        DECIMAL_10_2_ gallons
        DECIMAL_5_4_ price_per_gallon
        DECIMAL_8_2_ total_cost
        VARCHAR_50_ fuel_card_number
    }
    maintenance_records {
        VARCHAR_50_ maintenance_id PK
        VARCHAR_50_ truck_id FK
        DATE maintenance_date
        VARCHAR_100_ maintenance_type
        INT odometer_reading
        DECIMAL_4_1_ labor_hours
        DECIMAL_7_2_ labor_cost
        DECIMAL_8_2_ parts_cost
        DECIMAL_8_2_ total_cost
        VARCHAR_100_ facility_location
        DECIMAL_4_1_ downtime_hours
        VARCHAR_200_ service_description
    }
    safety_incidents {
        VARCHAR_50_ incident_id PK
        VARCHAR_50_ trip_id FK
        VARCHAR_50_ truck_id FK
        VARCHAR_50_ driver_id FK
        DATETIME2 incident_date
        VARCHAR_100_ incident_type
        VARCHAR_100_ location_city
        VARCHAR_10_ location_state
        BIT at_fault_flag
        BIT injury_flag
        DECIMAL_8_2_ vehicle_damage_cost
        DECIMAL_8_2_ cargo_damage_cost
        DECIMAL_8_2_ claim_amount
        BIT preventable_flag
        VARCHAR_100_ description
    }
    drivers ||--o{ trips : "driver_id"
    trucks ||--o{ trips : "truck_id"
    trailers ||--o{ trips : "trailer_id"
    trips ||--o{ fuel_purchases : "trip_id"
    trucks ||--o{ fuel_purchases : "truck_id"
    drivers ||--o{ fuel_purchases : "driver_id"
    trucks ||--o{ maintenance_records : "truck_id"
    trips ||--o{ safety_incidents : "trip_id"
    trucks ||--o{ safety_incidents : "truck_id"
    drivers ||--o{ safety_incidents : "driver_id"
```

**Key notation:** `PK` = primary key; `FK` = foreign key. Composite primary-key columns are each marked `PK`. Relationship lines represent the declared foreign-key constraints; consult the DDL for exact nullability and constraint definitions.
