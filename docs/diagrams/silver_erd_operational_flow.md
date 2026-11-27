# Silver ERD — Operational Flow

Customer and route master data through loads, trips, delivery events, and facility references.

**Schema:** `silver` · **Source of truth:** [`ddl_silver.sql`](../../scripts/silver/ddl_silver.sql)

This focused view is separated from the full 14-table ERD to make table definitions and relationships easier to inspect. It does not change the implemented schema.

```mermaid
erDiagram
    customers {
        VARCHAR_50_ customer_id
        VARCHAR_255_ customer_name
        VARCHAR_100_ customer_type
        INT credit_terms_days
        VARCHAR_50_ primary_freight_type
        VARCHAR_30_ account_status
        DATE contract_start_date
        INT annual_revenue_potential
    }
    routes {
        VARCHAR_50_ route_id
        VARCHAR_100_ origin_city
        VARCHAR_50_ origin_state
        VARCHAR_100_ destination_city
        VARCHAR_50_ destination_state
        DECIMAL_10_2_ typical_distance_miles
        DECIMAL_10_4_ base_rate_per_mile
        DECIMAL_10_6_ fuel_surcharge_rate
        SMALLINT typical_transit_days
    }
    loads {
        VARCHAR_50_ load_id
        VARCHAR_50_ customer_id
        VARCHAR_50_ route_id
        DATE load_date
        VARCHAR_100_ load_type
        DECIMAL_12_2_ weight_lbs
        SMALLINT pieces
        DECIMAL_12_2_ revenue
        DECIMAL_12_2_ fuel_surcharge
        DECIMAL_12_2_ accessorial_charges
        VARCHAR_50_ load_status
        VARCHAR_50_ booking_type
    }
    trips {
        VARCHAR_50_ trip_id
        VARCHAR_50_ load_id
        VARCHAR_50_ driver_id
        VARCHAR_50_ truck_id
        VARCHAR_50_ trailer_id
        DATE dispatch_date
        DECIMAL_6_2_ actual_distance_miles
        DECIMAL_5_1_ actual_duration_hours
        DECIMAL_5_1_ fuel_gallons_used
        DECIMAL_5_2_ average_mpg
        DECIMAL_5_2_ idle_time_hours
        VARCHAR_50_ trip_status
    }
    delivery_events {
        VARCHAR_50_ event_id
        VARCHAR_50_ load_id
        VARCHAR_50_ trip_id
        VARCHAR_50_ event_type
        VARCHAR_50_ facility_id
        DATETIME2 scheduled_datetime
        DATETIME2 actual_datetime
        SMALLINT detention_minutes
        BIT on_time_flag
        VARCHAR_100_ location_city
        VARCHAR_10_ location_state
    }
    facilities {
        VARCHAR_50_ facility_id
        VARCHAR_100_ facility_name
        VARCHAR_100_ facility_type
        VARCHAR_100_ city
        VARCHAR_10_ state
        DECIMAL_10_6_ latitude
        DECIMAL_10_6_ longitude
        INT dock_doors
        VARCHAR_50_ operating_hours
    }
    customers ||--o{ loads : "customer_id"
    routes ||--o{ loads : "route_id"
    loads ||--o{ trips : "load_id"
    loads ||--o{ delivery_events : "load_id"
    trips ||--o{ delivery_events : "trip_id"
    facilities ||--o{ delivery_events : "facility_id"
```

**Relationship note:** The diagram uses one-to-many notation for declared foreign-key relationships. Nullable foreign keys remain optional on the child side; consult the DDL for exact nullability and constraint definitions.
