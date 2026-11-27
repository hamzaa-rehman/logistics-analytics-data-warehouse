# Silver ERD — Monthly Metrics

Monthly driver and truck metric tables and their parent-entity relationships.

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
    driver_monthly_metrics {
        VARCHAR_50_ driver_id FK
        DATE month PK
        SMALLINT trips_completed
        DECIMAL_8_2_ total_miles
        DECIMAL_12_2_ total_revenue
        DECIMAL_4_2_ average_mpg
        DECIMAL_6_1_ total_fuel_gallons
        DECIMAL_5_4_ on_time_delivery_rate
        DECIMAL_3_1_ average_idle_hours
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
    truck_utilization_metrics {
        VARCHAR_50_ truck_id FK
        DATE month PK
        SMALLINT trips_completed
        DECIMAL_9_2_ total_miles
        DECIMAL_12_2_ total_revenue
        DECIMAL_4_2_ average_mpg
        SMALLINT maintenance_events
        DECIMAL_8_2_ maintenance_cost
        DECIMAL_4_1_ downtime_hours
        DECIMAL_6_4_ trips_per_day
    }
    drivers ||--o{ driver_monthly_metrics : "driver_id"
    trucks ||--o{ truck_utilization_metrics : "truck_id"
```

**Key notation:** `PK` = primary key; `FK` = foreign key. Composite primary-key columns are each marked `PK`. Relationship lines represent the declared foreign-key constraints; consult the DDL for exact nullability and constraint definitions.
