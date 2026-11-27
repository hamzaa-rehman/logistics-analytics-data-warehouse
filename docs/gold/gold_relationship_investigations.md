# Gold Layer — Relationship Investigations & Modelling Decisions

**Status:** Completed for initial Gold dimensional-model design  
**Source:** Validated Silver tables in the `LogisticsAnalytics` database  
**Purpose:** Preserve the relationship checks, observed cardinalities, data-quality findings, and modelling decisions established before Gold implementation.

**Supporting SQL:** [Gold relationship investigation queries](../../scripts/gold/gold_relationship_investigations.sql).

> **Scope note:** The figures in this document are the results of SQL queries run by the project owner and reviewed during the modelling discussion. This document records those outputs; it does not claim that the assistant independently executed queries against the database.

## 1. Summary

The investigations establish the main entity and event relationships needed for the initial Gold model:

- Loads and trips have a validated one-to-one relationship in the current data.
- Each trip has exactly two delivery events: one Pickup and one Delivery.
- Loads connect to customers and routes.
- Trips connect to drivers, trucks, and trailers, with some nullable assignments.
- Delivery events connect to facilities.
- Facility identifiers are complete and valid, but event-recorded locations frequently differ from facility master locations.

These findings support separate fact tables for distinct business processes. A one-to-one relationship between loads and trips does not make their measures interchangeable, and a one-to-two relationship between trips and delivery events creates a duplication risk when facts are joined at raw row level.

## 2. Loads ↔ Trips

**Investigated relationship:** `silver.loads.load_id` ↔ `silver.trips.load_id`

| Check | Result |
|---|---:|
| Loads | 85,410 |
| Trips | 85,410 |
| Trips without a load ID | 0 |
| Distinct trip load IDs | 85,410 |
| Trip load IDs not found in loads | 0 |
| Loads without a trip | 0 |
| Loads with multiple trips | 0 |

**Finding:** The observed relationship is one load to one trip (1:1) across all 85,410 records.

**Gold decision:** Keep `fact_loads` and `fact_trips` as separate facts. They represent different business processes and have different measures and analytical dates. Do not merge their measures into one fact merely because the current relationship is 1:1.

## 3. Trips ↔ Delivery Events

**Investigated relationship:** `silver.delivery_events.trip_id` ↔ `silver.trips.trip_id`

| Check | Result |
|---|---:|
| Delivery events | 170,820 |
| Events without trip ID | 0 |
| Distinct trips represented | 85,410 |
| Event trip IDs not found in trips | 0 |
| Trips without events | 0 |
| Trips with exactly one Pickup event | 85,410 |
| Trips with exactly one Delivery event | 85,410 |
| Trips with exactly two events | 85,410 |

**Finding:** Every trip has exactly two events: one Pickup and one Delivery. The event fact grain is one row per event, not one row per trip.

**Gold decision:** Use `fact_delivery_events` at one row per event. Retain `event_type` so Pickup and Delivery can be analysed separately. The On-Time Delivery Rate must use Delivery events only; Pickup events must not enter its numerator or denominator.

## 4. Delivery Event `load_id` Consistency

The event-level `load_id` was compared with the `load_id` on the associated trip.

| Check | Result |
|---|---:|
| Delivery events | 170,820 |
| Events without load ID | 0 |
| Events with a matching trip/load ID | 170,820 |
| Events with unmatched load IDs | 0 |
| Events where event and trip load IDs disagree | 0 |

**Finding:** All event `load_id` values agree with the `load_id` on their associated trips.

**Gold decision:** The validated relationship chain is Loads (85,410) → Trips (85,410) → Delivery Events (170,820). Do not directly join raw load, trip, and event facts and then aggregate their measures: the two event rows per trip can duplicate load- and trip-level measures (fanout).

## 5. Trips ↔ Trailers

**Investigated relationship:** `silver.trips.trailer_id` ↔ `silver.trailers.trailer_id`

| Check | Result |
|---|---:|
| Trips | 85,410 |
| Trips without trailer ID | 1,680 (approximately 1.97%) |
| Distinct trailers used | 180 |
| Unmatched trailer IDs | 0 |
| Trailers without recorded trips | 0 |
| Trailers used on multiple trips | 180 |

All 180 trailer records are represented in trip activity. In the reviewed trailer-level distribution, trip counts ranged from 427 to 514; recorded distance ranged from 599,684 to 747,711 miles.

**Gold decision:** Include all 180 Silver trailers in `dim_trailer`. The trailer key in `fact_trips` must remain nullable to preserve the 1,680 trips without a recorded trailer assignment.

**Interpretation limit:** Trip counts and cumulative distance alone do not establish trailer availability, utilization, or underutilization.

## 6. Trips ↔ Drivers

**Investigated relationship:** `silver.trips.driver_id` ↔ `silver.drivers.driver_id`

| Check | Result |
|---|---:|
| Trips | 85,410 |
| Trips without driver ID | 1,714 (approximately 2.01%) |
| Distinct drivers used on trips | 124 |
| Unmatched driver IDs | 0 |
| Drivers without recorded trips | 26 |
| Drivers with multiple trips | 124 |

**Gold decision:** Include all 150 Silver drivers in `dim_driver`, not only the 124 represented in trip activity. Keep the driver key nullable in `fact_trips`.

**Interpretation limit:** The 26 drivers without recorded trips must not automatically be labelled inactive or terminated. Their absence from trip activity does not establish employment status or activity in other processes.

## 7. Trips ↔ Trucks

**Investigated relationship:** `silver.trips.truck_id` ↔ `silver.trucks.truck_id`

| Check | Result |
|---|---:|
| Trips | 85,410 |
| Trips without truck ID | 1,672 (approximately 1.96%) |
| Distinct trucks used on trips | 92 |
| Unmatched truck IDs | 0 |
| Trucks without recorded trips | 28 |
| Trucks with multiple trips | 92 |

**Gold decision:** Include all 120 Silver trucks in `dim_truck`. Keep the truck key nullable in `fact_trips`.

**Interpretation limit:** The 28 trucks without recorded trips cannot be assumed to be unavailable, inactive, or out of service based on this relationship check alone.

## 8. Loads ↔ Routes

**Investigated relationship:** `silver.loads.route_id` ↔ `silver.routes.route_id`

The route relationship is on `silver.loads`. The Silver `trips` table does **not** contain a `route_id` column.

| Check | Result |
|---|---:|
| Loads | 85,410 |
| Loads without route ID | 0 |
| Distinct routes used | 58 |
| Unmatched route IDs | 0 |
| Routes without loads | 0 |
| Routes used by multiple loads | 58 |

**Gold decision:** Connect `dim_route` to `fact_loads`. Do not add or fabricate a `route_id` in `fact_trips`. If route analysis is needed alongside trip measures, use the validated load-to-trip relationship with appropriate grain control.

## 9. Loads ↔ Customers

**Investigated relationship:** `silver.loads.customer_id` ↔ `silver.customers.customer_id`

| Check | Result |
|---|---:|
| Loads | 85,410 |
| Loads without customer ID | 0 |
| Distinct customers represented | 200 |
| Unmatched customer IDs | 0 |
| Customers without loads | 0 |
| Customers with multiple loads | 200 |

**Gold decision:** Include all 200 customers in `dim_customer` and connect the dimension to `fact_loads` through the customer key. Use `customer_id` as the customer identity; customer names are not guaranteed to be unique.

## 10. Delivery Events ↔ Facilities

**Investigated relationship:** `silver.delivery_events.facility_id` ↔ `silver.facilities.facility_id`

| Check | Result |
|---|---:|
| Delivery events | 170,820 |
| Events without facility ID | 0 |
| Distinct facilities used | 50 |
| Events with unmatched facility IDs | 0 |
| Facilities without events | 0 |
| Facilities associated with multiple events | 50 |

**Finding:** All 170,820 events have a valid facility reference, and all 50 facilities are represented in event activity.

**Gold decision:** Include all 50 facilities in `dim_facility` and connect it to `fact_delivery_events` through the facility key.

## 11. Event Location vs. Facility Master Location

The event's `location_city` and `location_state` were compared with the associated facility's `city` and `state`, using trimmed, case-insensitive text comparisons.

| Check | Result |
|---|---:|
| Events compared | 170,820 |
| Exact city-and-state matches | 5,885 (approximately 3.44%) |
| City and/or state mismatches | 164,935 (approximately 96.56%) |
| Records with missing location values | 0 |

**Finding:** The event-recorded location frequently differs from the associated facility's master location. The relationship key itself is complete and valid; the location discrepancy is a separate data-quality or business-semantics issue.

**Gold decision:**
- Preserve event `location_city` and `location_state` as event attributes.
- Preserve facility `city` and `state` in `dim_facility`.
- Do not overwrite one location with the other.
- Do not assume the mismatch is necessarily an error without source-system definitions explaining what the event location represents.
- Retain this limitation for dashboard interpretation. No additional investigation is currently required unless the source system supplies a clearer definition of event location.

## 12. Implemented Gold Model and Relationship Safeguards

The relationship findings were incorporated into the deployed Gold dimensional model. The physical schema, keys, data types, constraints, and source-to-target mappings are defined in [the Gold DDL](../../scripts/gold/ddl_gold.sql) and [the Gold data dictionary](gold_data_dictionary.md). The implemented model contains the following seven dimensions and six facts.

### Dimensions

| Dimension | Source | Source rows / generated coverage |
|---|---|---:|
| `dim_customer` | `silver.customers` | 200 |
| `dim_driver` | `silver.drivers` | 150 |
| `dim_truck` | `silver.trucks` | 120 |
| `dim_trailer` | `silver.trailers` | 180 |
| `dim_route` | `silver.routes` | 58 |
| `dim_facility` | `silver.facilities` | 50 |
| `dim_date` | Generated calendar | 5,114 dates (2012-01-01 through 2025-12-31) |

### Facts

| Implemented fact table | Source | Implemented grain (the level of detail represented by each row) |
|---|---|---|
| `fact_loads` | `silver.loads` | One row per load |
| `fact_trips` | `silver.trips` | One row per trip |
| `fact_delivery_events` | `silver.delivery_events` | One row per Pickup or Delivery event |
| `fact_fuel_purchases` | `silver.fuel_purchases` | One row per fuel purchase |
| `fact_maintenance_records` | `silver.maintenance_records` | One row per maintenance record |
| `fact_safety_incidents` | `silver.safety_incidents` | One row per safety incident |

The six fact processes above are implemented at their documented grains. The two monthly metric tables remain in Silver and are outside the current Gold scope; they should be added only if a defined reporting requirement justifies a separate fact design.

### Relationship and aggregation safeguards

1. Preserve separate facts for loads, trips, delivery events, fuel purchases, maintenance records, and safety incidents because they represent different event grains.
2. Preserve nullable entity keys where Silver contains missing optional assignments. Do not invent dimension members or infer missing driver, truck, or trailer assignments.
3. Include complete source dimensions, even where some entities have no recorded trip activity.
4. Connect routes to loads, not directly to trips; Silver trips has no `route_id`.
5. Connect facilities to delivery events; retain event location fields separately from facility master location fields.
6. Do not aggregate measures after joining multiple raw fact tables unless the join cardinality and resulting grain have been deliberately controlled. Aggregate each process at its intended grain first to avoid fanout and inflated totals.
7. Keep the load/trip/event relationship chain in mind: one load ↔ one trip, and one trip → two delivery events.

## 13. Investigation and implementation closure

The relationship investigations required to design the Gold model are complete, and their decisions have been implemented in the deployed seven-dimension, six-fact schema. The completed model preserves the documented fact grains, nullable optional relationships, route-to-load relationship, facility-to-delivery-event relationship, and safeguards against cross-fact fanout.

The project owner validated all 18 Gold foreign-key relationships: zero orphan rows, with every constraint enabled and trusted. All 13 Gold tables have enabled single-column primary keys. Fact business-key uniqueness, Silver-to-Gold fact row counts, and selected measure preservation across all six fact tables also passed. See the [Gold validation record](gold_validation.md) for the detailed results and scope.

No further relationship investigation is currently required for the implemented model. Reopen a specific relationship investigation only if a schema change, new reporting requirement, or validation result identifies a concrete issue. The eight Gold reporting views have since been implemented and validated using the fact grains and relationship cardinalities documented here; see [Gold Reporting Views](gold_reporting_views.md). The next development stage is the Power BI semantic model and report development.
