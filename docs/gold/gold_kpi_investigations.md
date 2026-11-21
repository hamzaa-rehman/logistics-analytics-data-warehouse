# Gold Layer — KPI Investigations & Business Rules

**Status:** Working reference — updated through Safety Performance (KPI 8)  
**Purpose:** Preserve the evidence, KPI definitions, data limitations, and modelling decisions established during pre-Gold investigations. This document is the business-analysis reference for Gold design and should be updated as further investigations are completed.

> **Important:** Figures below are based on SQL query outputs shared and reviewed during the investigation. This document records those results; it does not claim that every source column has undergone full reconciliation. Where an interpretation is provisional, it is explicitly labelled.

## 1. Project context and scope

The project uses the Logistics Operations Database (2022–2024) and follows a Bronze → Silver → Gold medallion architecture.

- Bronze and Silver contain 14 source tables.
- Silver contains 549,706 rows across the 14 typed tables.
- Gold is intended to support business-facing logistics, fleet, revenue, delivery, customer, and cost analysis.
- The dataset represents freight/logistics operations. It is **not** a car-sharing or vehicle-rental dataset. Any relevance to mobility operations must be described as transferable analytics capability, not as direct rental-business evidence.

### 1.1 Analytical period

| Subject | Observed period |
|---|---|
| Loads | 2022-01-01 to 2024-12-31 |
| Trips | 2022-01-01 to 2024-12-31 |
| Delivery events | 2022-01-01 to 2025-01 (partial month present) |
| Fuel purchases | 2022-01-01 to 2025-01 (timestamps extend into January 2025) |
| Customer contract start dates | 2020-01-07 to 2022-01-01 |
| First observed customer loads | 2022-01-01 to 2022-01-11 |

January 2025 activity in delivery and fuel data must be treated as partial-period activity unless completeness is independently established. Do not compare partial January 2025 with complete months or years without an explicit qualification.

## 2. KPI 1 — Reported Load Revenue

### 2.1 Investigation results

Source: `silver.loads`, one row per load.

| Measure | Result |
|---|---:|
| Total loads | 85,410 |
| Loads with revenue | 85,410 |
| NULL revenue | 0 |
| Zero revenue | 0 |
| Negative revenue | 0 |
| Revenue date range | 2022-01-01 to 2024-12-31 |
| Minimum revenue per load | 125.93 |
| Maximum revenue per load | 8,125.22 |
| Average revenue per load | 3,073.712683 |
| Sum of reported load revenue | 262,525,800.29 |
| Sum of fuel surcharge | 29,962,528.65 |
| Sum of accessorial charges | 6,119,100.00 |
| Combined comparison amount | 298,621,428.94 |

All 85,410 loads have status `Completed`; no other status values were present in the reviewed Silver result.

### 2.2 Revenue and route-rate checks

- Route-based estimated base freight was calculated as `typical_distance_miles * base_rate_per_mile`.
- Average recorded load revenue was 3,073.712683; average estimated base freight was 3,073.159750.
- Average recorded revenue less estimated base freight was 0.552932.
- 42,635 loads were above the estimate, 3 equal, and 42,772 below.
- This route-based amount is an indicative comparison, not a verified contractual invoice price.
- Fuel surcharge was validated against `typical_distance_miles * fuel_surcharge_rate`: all 85,410 rows matched within 0.01, with zero above/below exceptions. The source field `fuel_surcharge_rate` therefore behaves like a per-mile rate in this dataset, not a percentage.

### 2.3 Gold definition and decisions

**Approved measure:** Reported Load Revenue = `SUM(silver.loads.revenue)`.

- Fact grain: one row per load.
- Business date: `load_date`.
- No load-status filter is currently required because all reviewed rows are Completed.
- Keep `fuel_surcharge` and `accessorial_charges` as separate measures.
- Preserve zero accessorial charges.

**Do not label 298,621,428.94 as Total Revenue or All-in Revenue.** The accounting definition does not establish whether fuel surcharge and accessorial charges are already included in `revenue`. The combined amount is retained only as a comparison figure until that definition is confirmed.

## 3. KPI 2 — Completed Trip Activity

### 3.1 Investigation results

Source: `silver.trips`, one row per trip.

| Measure | Result |
|---|---:|
| Total trips | 85,410 |
| NULL dispatch dates | 0 |
| Dispatch date range | 2022-01-01 to 2024-12-31 |
| Distinct trip statuses | 1 (Completed) |
| Total actual distance | 122,159,201 miles |
| Average distance per trip | 1,430.268130 miles |
| Average duration per trip | 25.014673 hours |

Monthly trip counts over the 36 complete months ranged from 2,136 to 2,496. Average distance per trip was generally around 1,400–1,458 miles, and average duration around 24.56–25.49 hours.

### 3.2 Gold definition and decisions

**Approved measure:** Completed Trip Count = `COUNT_BIG(*)` from the one-row-per-trip fact.

- Fact grain: one row per trip.
- Business date: `dispatch_date`.
- No status filter is currently required because all reviewed trips are Completed.
- Supporting measures: total actual distance, average distance per trip, and average trip duration.

## 4. KPI 3 — Fleet Performance

### 4.1 Overall fleet activity results

Source: `silver.trips`.

| Measure | Result |
|---|---:|
| Total trips | 85,410 |
| Trucks with recorded trips | 92 |
| Truck inventory in Silver | 120 |
| Trips with NULL truck_id | 1,672 (approximately 1.96%) |
| Total actual distance | 122,159,201 miles |
| Total trip fuel used | 18,946,280.1 gallons |
| Average recorded trip MPG (`AVG(average_mpg)`) | 6.501462 |
| Weighted aggregate MPG (`SUM(distance)/SUM(fuel)`) | 6.4476615 (approximately 6.448) |
| Average idle time per trip | 7.010783 hours |

All 36 months showed 92 distinct trucks with recorded activity. This consistency is an observation about recorded trip activity, not evidence that the same trucks were available every day.

### 4.2 Truck-level comparison

- 92 trucks had recorded trips and can be included in truck-level rankings.
- Highest aggregate MPG in the reviewed ranking: TRK00057 — 951 trips, 1,377,066 miles, 211,494.2 gallons, 6.511 aggregate MPG.
- Lowest aggregate MPG in the reviewed ranking: TRK00113 — 880 trips, 1,265,996 miles, 198,111.5 gallons, 6.390 aggregate MPG.
- The observed truck-level aggregate MPG range was narrow: 6.390–6.511.

### 4.3 Gold definition and decisions

- Use weighted aggregate fleet MPG, `SUM(actual_distance_miles) / NULLIF(SUM(fuel_gallons_used), 0)`, as the overall fleet fuel-efficiency measure.
- Keep `AVG(average_mpg)` distinct; it is the simple average of per-trip MPG and is not the same calculation.
- Label idle time as average idle hours per trip, not per truck or per day.
- Retain trips with NULL `truck_id` in overall trip, distance, and fuel measures where the measure's source values are present.
- Exclude NULL-truck trips from truck-level rankings, but disclose the 1,672 unassigned-truck trips.

**Fleet utilization limitation:** The Silver field `trips_per_day` is a trips-per-calendar-day measure derived from the source metric. It is not a utilization percentage. The dataset does not provide a reliable available-time or available-capacity denominator, so true fleet utilization cannot be calculated. Do not present truck counts or `trips_per_day` as a true utilization rate.

## 5. KPI 4 — Delivery Performance

### 5.1 Event-level results

Source: `silver.delivery_events`, one row per delivery event.

| Event type | Events | On time | Late | Missing on_time_flag | On-time rate |
|---|---:|---:|---:|---:|---:|
| Delivery | 85,410 | 38,102 | 47,308 | 0 | 44.61% |
| Pickup | 85,410 | 56,993 | 28,417 | 0 | 66.73% |

### 5.2 Approved KPI definition

**On-Time Delivery Rate** = on-time Delivery events / all Delivery events × 100.

- Include only `event_type = 'Delivery'` in the numerator and denominator.
- Do not mix Pickup events into the delivery KPI.
- Keep both Pickup and Delivery event types in the underlying event fact for separate analysis.
- Use `actual_datetime` for delivery performance time trends.
- Average delivery detention should be calculated for Delivery events, not mixed with Pickup events.

### 5.3 Annual results and January 2025 qualification

| Period | Delivery events | On-time deliveries | On-time rate | Average detention |
|---|---:|---:|---:|---:|
| 2022 | 28,489 | 12,730 | 44.68% | 106.81 min |
| 2023 | 28,178 | 12,555 | 44.56% | 106.07 min |
| 2024 | 28,657 | 12,783 | 44.61% | 106.89 min |
| Jan 2025 (partial) | 86 | 34 | 39.53% | 114.47 min |

The complete years show a stable on-time delivery rate around 44.6%, with no sustained improvement visible in the reviewed annual figures. January 2025 is partial and must not be compared as if it were a complete month.

### 5.4 Detention and on-time flag investigation

A prior investigation found an observed relationship between `detention_minutes` and `on_time_flag`:

- Events marked on time generally fell within an approximate ±120-minute window.
- Events outside that window were generally marked late.
- This is an observed data pattern, not proof that detention causes lateness or that ±120 minutes is a formal business rule.

Earlier event samples also showed Delivery events often marked late while corresponding Pickup events were marked on time. Keep the event types distinct when interpreting performance.

## 6. KPI 5 — Customer Performance

### 6.1 Customer coverage and revenue concentration

Sources: `silver.customers` and `silver.loads`.

| Measure | Result |
|---|---:|
| Total customers | 200 |
| Customers with at least one load | 200 |
| Customers without loads | 0 |
| Total loads | 85,410 |
| Loads without customer_id | 0 |
| Unassigned load revenue | No unassigned rows; SUM result was NULL |
| Total reported load revenue | 262,525,800.29 |
| Top 10 customers' revenue | 14,961,272.21 |
| Top 10 share of total reported load revenue | 5.70% |
| Top 20 customers' revenue | 29,391,799.43 |
| Top 20 share of total reported load revenue | 11.20% |

All 200 customer records are represented in load activity, and every load is assigned to a customer. Revenue is broadly distributed across customers; the top 20 account for 11.20% of reported load revenue.

In the customer ranking, the highest individual contribution was approximately 0.59% and the lowest approximately 0.41%. Use `customer_id` as the customer identity; repeated customer names exist and names alone should not be treated as unique identifiers.

### 6.2 Customer type performance

| Customer type | Customers | Loads | Reported load revenue | Average revenue per load | Revenue contribution |
|---|---:|---:|---:|---:|---:|
| Contract | 75 | 32,209 | 98,795,209.72 | 3,067.32 | 37.63% |
| Spot | 63 | 26,856 | 82,851,956.36 | 3,085.04 | 31.56% |
| Dedicated | 62 | 26,345 | 80,878,634.21 | 3,069.98 | 30.81% |
| **Total** | **200** | **85,410** | **262,525,800.29** | — | **100.00%** |

Contract customers contribute the largest revenue share, alongside the largest customer count and load volume. Spot customers have the highest average revenue per load, but differences between types are small. Do not infer that one customer type is inherently more valuable from revenue share alone.

### 6.3 Contract start vs. first observed load

For each customer, the earliest `silver.loads.load_date` was compared with `silver.customers.contract_start_date`.

| Finding | Result |
|---|---:|
| Customers compared | 200 |
| First observed load before contract start | 0 |
| First observed load on contract start date | 0 |
| First observed load after contract start | 200 |
| Earliest contract start | 2020-01-07 |
| Latest contract start | 2022-01-01 |
| Earliest first observed load | 2022-01-01 |
| Latest first observed load | 2022-01-11 |

All customers' first observed loads occur after their recorded contract start dates. However, load history begins on 2022-01-01, while contract dates extend back to 2020. The dataset therefore does not establish the actual date on which a customer was acquired.

### 6.4 Gold definition and decisions

- Customer identity: `customer_id`, not customer name.
- Include `contract_start_date` in `dim_customer`.
- A derived `first_observed_load_date` may be useful as an analytical attribute if its derivation and meaning are documented.
- Do not label `contract_start_date` or `first_observed_load_date` as verified `customer_acquisition_date`.
- Customer acquisition or cohort analysis must be explicitly labelled as contract-start cohorts or first-observed-load cohorts, not verified acquisition.
- Customer revenue contribution should use the complete reported load revenue denominator. Current results show no unassigned customer loads.

## 7. KPI 6 — Fuel Purchases and Fuel Cost

### 7.1 Purchase profile and date coverage

Source: `silver.fuel_purchases`, one row per fuel purchase.

| Measure | Result |
|---|---:|
| Fuel purchase records | 196,442 |
| Records with trip_id | 196,442 |
| Records with truck_id | 192,562 |
| Records with NULL truck_id | 3,880 (1.97%) |
| Records with driver_id | 192,454 |
| Records with NULL driver_id | 3,988 (2.03%) |
| NULL purchase dates | 0 |
| NULL gallons | 0 |
| NULL price per gallon | 0 |
| NULL total_cost | 0 |
| Purchase date range | 2022-01-01 to 2025-01-02 23:00 |
| Total purchased gallons | 24,519,037.80 |
| Total recorded fuel cost | 95,592,992.04 |
| Purchase quantity range | 50–200 gallons |
| Price-per-gallon range | 3.15–5.00 |

All fuel purchase records have a trip_id. The missing truck and driver identifiers are not random assignment conflicts: the subsequent purchase-to-trip comparison found that missing purchase-level IDs correspond to NULL IDs on the associated trip.

The currency represented by `total_cost` was not established in the investigation. Report it as recorded fuel cost unless the source currency is confirmed.

### 7.2 Recorded fuel cost validation

The recorded `total_cost` was compared with `ROUND(gallons * price_per_gallon, 2)`.

| Result | Records |
|---|---:|
| Matches rounded calculation | 193,964 |
| Variances | 2,478 (1.26%) |
| Variance on every mismatching row | -0.01 |
| Aggregate recorded-minus-calculated difference | -24.78 |

Every mismatch showed the recorded `total_cost` exactly 0.01 below the rounded product of gallons and price per gallon. The precise origin of this consistent one-cent difference was not established.

**Decision:** Use source-recorded `total_cost` for fuel expenditure reporting. Do not recalculate, overwrite, or exclude affected purchase records. Preserve the one-cent variance as a documented source-level difference.

### 7.3 Purchase-to-trip assignment reconciliation

All 196,442 purchase records have a trip_id. Comparing purchase-level truck and driver IDs with the corresponding `silver.trips` assignments produced:

- All populated purchase truck IDs matched the associated trip truck IDs.
- All populated purchase driver IDs matched the associated trip driver IDs.
- No conflicting truck or driver assignments were found.
- The 3,880 NULL purchase truck IDs correspond to trips with NULL truck_id.
- The 3,988 NULL purchase driver IDs correspond to trips with NULL driver_id.

This validates identifier consistency; it does not prove that the purchased gallons were consumed exclusively during the referenced trip.

### 7.4 Purchase quantity and monthly patterns

- Purchase quantities ranged from 50 to 200 gallons.
- Average purchase quantity was approximately 124.82 gallons; standard deviation was approximately 43.35 gallons.
- There were 1,501 distinct purchase quantities. The frequency review returned only the 150 most common quantities, so it was not treated as a complete distribution review.
- Monthly purchase volume during complete months in 2022–2024 was approximately 615,000–737,000 gallons.
- Average price per gallon was approximately 4.20 in 2022, 3.85 in 2023, and 3.65 in 2024. These are source-observed values; no external economic explanation or currency assumption is attached.
- January 2025 contains only 201 purchases and is a partial period.

### 7.5 Purchase gallons compared with trip-recorded fuel consumption

Monthly purchases were aggregated separately from trip consumption before being compared. For each complete month from January 2022 through December 2024, purchased gallons exceeded trip-recorded consumption by approximately 120,000–180,000 gallons.

Examples:
- January 2022: 669,956.20 purchased vs. 549,603.7 consumed; difference 120,352.5 gallons.
- August 2022: 736,548.20 purchased vs. 556,760.8 consumed; difference 179,787.4 gallons.
- December 2024: 674,250.70 purchased vs. 523,421.3 consumed; difference 150,829.4 gallons.

January 2025 has 201 purchases (25,477 gallons) and no trips in the same-month comparison because the trip dispatch-date range ends on 2024-12-31. It is not comparable with complete months.

The monthly comparison is descriptive only. Purchase date and dispatch date represent different business events, and fuel purchased in one month may be consumed during another month. The monthly difference does not establish wastage, theft, inventory change, or data error.

### 7.6 Trip-level purchase-to-consumption comparison

Fuel purchases were aggregated by trip_id and compared with each trip's `fuel_gallons_used`.

| Comparison category | Trips | Purchase records | Purchased gallons | Trip-recorded gallons |
|---|---:|---:|---:|---:|
| No Purchase Record | 8,471 | 0 | 0.00 | 1,884,461.8 |
| Purchased < Consumed | 26,990 | 43,375 | 4,896,930.30 | 8,430,140.6 |
| Purchased = Consumed | 9 | 18 | 2,111.80 | 2,111.8 |
| Purchased > Consumed | 49,940 | 153,049 | 19,619,995.70 | 8,629,565.9 |
| **Total** | **85,410** | **196,442** | **24,519,037.80** | **18,946,280.1** |

A separate trip-consumption check found:
- 85,410 total trips.
- 0 NULL fuel-consumption values.
- 0 zero fuel-consumption values.
- 0 negative fuel-consumption values.
- Minimum recorded consumption: 12.0 gallons.
- Maximum recorded consumption: 611.9 gallons.

The aggregate purchased-minus-consumed difference is 5,572,757.70 gallons. Although purchase records are linked to trips and their truck/driver IDs are consistent, this does not prove that all gallons purchased against a trip were consumed on that same trip. Purchases may replenish a tank for use across multiple trips; the dataset does not establish exclusive trip-level fuel allocation.

**Decision:** Do not calculate or label the purchase-versus-consumption difference as fuel wastage, theft, or operational loss. Keep purchase quantities and trip fuel consumption as separate measures at their respective grains.

### 7.7 Fuel cost attribution by truck and driver

The final assignment breakdown grouped fuel purchase records by whether truck_id and driver_id were present.

| Truck assignment | Driver assignment | Purchases | Distinct trucks | Distinct drivers | Gallons | Recorded fuel cost |
|---|---|---:|---:|---:|---:|---:|
| Assigned | Assigned | 188,668 | 92 | 124 | 23,551,617.00 | 91,828,723.79 |
| Assigned | Unassigned | 3,894 | 92 | 0 | 481,576.60 | 1,869,833.77 |
| Unassigned | Assigned | 3,786 | 0 | 124 | 474,353.40 | 1,849,485.04 |
| Unassigned | Unassigned | 94 | 0 | 0 | 11,490.80 | 44,949.44 |
| **Total** | | **196,442** | | | **24,519,037.80** | **95,592,992.04** |

- 188,668 purchases (approximately 96.04%) have both assignments.
- 3,894 purchases have a truck but no driver.
- 3,786 purchases have a driver but no truck.
- 94 purchases have neither assignment.
- Fuel cost without a truck assignment is 1,894,434.48.
- Fuel cost without a driver assignment is 1,914,382.21.

The two unassigned-cost totals overlap for the 94 purchases missing both IDs; do not add them together.

### 7.8 Gold definitions and decisions

1. **Fuel expenditure:** `SUM(fuel_purchases.total_cost)`, using the source-recorded amount.
2. **Fuel purchase volume:** `SUM(fuel_purchases.gallons)`, at one row per purchase.
3. **Average purchase price:** derive from purchase-level values with a clearly stated averaging method; do not confuse a simple average of row prices with total cost divided by total gallons.
4. **Truck and driver attribution:** use the respective purchase-level IDs. Retain unassigned purchases in overall expenditure totals and show unassigned cost separately in truck/driver reporting.
5. **Trip fuel consumption:** use `SUM(trips.fuel_gallons_used)`, at one row per trip.
6. Keep fuel purchases and trips as separate fact processes. Do not join raw purchase rows directly to trip rows and then aggregate trip measures, as multiple purchases per trip can duplicate trip values.
7. Do not infer fuel wastage or a fuel loss KPI from purchase-versus-consumption differences.
8. January 2025 fuel activity is partial and must be qualified in time trends.
9. Do not state a currency until the source currency is verified.

## Cross-KPI modelling and interpretation rules

1. **Preserve fact grain.** Loads, trips, delivery events, fuel purchases, and maintenance records have different grains. Do not flatten one-to-many relationships into a single joined fact in a way that duplicates revenue, trip counts, or costs.
2. **Keep measures at their natural grain.** Load revenue belongs to the load grain; trip distance and trip fuel belong to trip grain; delivery punctuality belongs to delivery-event grain; fuel-purchase expense belongs to fuel-purchase grain.
3. **Use explicit date roles.** Current business dates are `loads.load_date`, `trips.dispatch_date`, and `delivery_events.actual_datetime`. Fuel and maintenance date roles still need final KPI-specific review.
4. **Keep definitions visible.** Distinguish reported load revenue, fuel surcharge, accessorial charges, trip MPG, weighted fleet MPG, on-time delivery rate, and average detention.
5. **Do not overstate unsupported KPIs.** True fleet utilization and verified customer acquisition are not supported by the available fields.
6. **Respect missing identifiers.** Retain unassigned truck trips in overall trip measures, while excluding them from truck-level attribution.
7. **Separate observation from causation.** Correlations and data patterns do not establish business causality.


## 8. Maintenance performance and cost (KPI 7)

**Status: Investigated.** The maintenance investigation used `silver.maintenance_records` at its natural grain: one row per maintenance event. The source contains 2,920 maintenance records dated 2022-01-01 through 2024-12-31.

### 8.1 Completeness and cost validation (08A)

| Check | Result |
|---|---:|
| Maintenance records | 2,920 |
| Records with truck ID | 2,920 |
| Missing truck IDs | 0 |
| Records with maintenance date, type, labor hours, labor cost, parts cost, total cost, and downtime | 2,920 for each field |
| Recorded maintenance cost | 5,730,573.28 |
| Labor cost | 1,280,507.09 |
| Parts cost | 4,450,066.19 |
| Minimum / maximum recorded cost per event | 60.82 / 4,426.57 |
| Minimum / maximum downtime per event | 2 / 48 hours |
| Negative total-cost, labor-cost, parts-cost, or downtime records | 0 |
| Cost-component mismatches | 0 |

The component totals reconcile exactly: labor cost plus parts cost equals recorded total cost (1,280,507.09 + 4,450,066.19 = 5,730,573.28). The mismatch check allowed a 0.01 tolerance; no records exceeded it. Parts account for approximately 77.65% of recorded maintenance cost and labor approximately 22.35%.

The dataset does not establish the currency. Report the measure as **recorded maintenance cost**, not as AED, USD, or another assumed currency. Retain source `total_cost`; do not replace it with a recalculated value.

### 8.2 Truck-level maintenance attribution (08B)

All 2,920 maintenance events have a populated `truck_id`. The query returned 120 trucks with maintenance records, covering the 120 trucks in the Silver truck inventory. This supports truck-level attribution of maintenance events, recorded costs, and downtime.

There are approximately 24.33 maintenance events per truck on average across the observed period (2,920 / 120); this is a simple fleet-wide average and does not adjust for truck age, mileage, or operating exposure.

Highest recorded maintenance cost by truck in the returned results:

| Truck | Events | Recorded maintenance cost |
|---|---:|---:|
| TRK00003 | 41 | 90,161.42 |
| TRK00073 | 39 | 76,573.99 |
| TRK00081 | 32 | 73,892.72 |
| TRK00099 | 34 | 73,231.77 |
| TRK00014 | 34 | 71,801.82 |

Highest cumulative downtime in the returned results:

| Truck | Events | Downtime |
|---|---:|---:|
| TRK00003 | 41 | 1,133.1 hours |
| TRK00044 | 38 | 1,080.4 hours |
| TRK00073 | 39 | 996.3 hours |
| TRK00046 | 29 | 974.5 hours |
| TRK00014 | 34 | 940.4 hours |

These are descriptive rankings, not evidence that a truck is unreliable or poorly maintained. Usage exposure (for example, trips and miles), truck age, and maintenance mix would be needed for fair comparisons. Summed maintenance downtime is not necessarily total truck unavailability; the source does not establish whether downtime intervals overlap or how availability should be measured.

### 8.3 Maintenance type analysis (08C)

Seven maintenance categories were present:

| Maintenance type | Events | Recorded cost | Average cost / event | Labor cost | Parts cost | Downtime hours | Average downtime / event |
|---|---:|---:|---:|---:|---:|---:|---:|
| Preventive | 422 | 963,576.34 | 2,283.36 | 185,316.55 | 778,259.79 | 10,569.8 | 25.05 |
| Repair | 424 | 945,375.44 | 2,229.66 | 183,295.81 | 762,079.63 | 10,452.9 | 24.65 |
| Tire | 414 | 919,413.24 | 2,220.80 | 185,706.00 | 733,707.24 | 10,087.1 | 24.36 |
| Brake | 402 | 911,667.23 | 2,267.83 | 182,732.81 | 728,934.42 | 10,031.8 | 24.95 |
| Engine | 415 | 890,537.88 | 2,145.87 | 187,553.72 | 702,984.16 | 10,396.3 | 25.05 |
| Transmission | 411 | 879,620.87 | 2,140.20 | 170,056.41 | 709,564.46 | 10,034.9 | 24.42 |
| Inspection | 432 | 220,382.28 | 510.14 | 185,845.79 | 34,536.49 | 10,657.7 | 24.67 |

Inspection has the highest event count (432) and the lowest recorded cost (220,382.28), while its cumulative downtime (10,657.7 hours) is the highest among the categories. This demonstrates that recorded expenditure and downtime should be reported as separate measures; it does not establish why the patterns differ or that inspections prevent repairs.

### 8.4 Gold implications and approved analytical handling

- Candidate `fact_maintenance_records` grain: **one row per maintenance event**.
- Preserve `truck_id`, `maintenance_date`, and `maintenance_type` for truck, date, and category analysis.
- Use source `total_cost` for recorded maintenance expenditure. Retain `labor_cost` and `parts_cost` as separate measures; their sum reconciles to source total within the tested 0.01 tolerance.
- Retain `downtime_hours` as a separate measure. Do not label its sum as fleet unavailability without a validated availability definition.
- Supported measures include maintenance event count, recorded maintenance cost, labor cost, parts cost, downtime hours, average cost per event, and average downtime per event.
- Truck-level comparisons are supported because all maintenance records have `truck_id`; comparisons of reliability or cost efficiency should account for usage exposure and truck age.
- Do not assume the currency or infer causation from descriptive category patterns.
- Avoid joining raw maintenance events directly to trip-level records and summing measures without controlling the relationship grain; one-to-many joins can duplicate measures.

## 9. Candidate Gold model implications (not yet final)

The following are modelling directions for design review, not approved DDL:

- `fact_loads`: one row per load; customer and route relationships; load date; reported revenue, fuel surcharge, and accessorial charges kept as separate measures.
- `fact_trips`: one row per trip; dispatch date; distance, duration, fuel gallons, recorded MPG, idle hours; nullable truck/driver/load relationships preserved.
- `fact_delivery_events`: one row per event; event type, scheduled and actual timestamps, detention, on-time flag, load/trip/facility relationships.
- `dim_customer`: customer attributes including customer type, account status, contract start date; customer key must be based on customer identity.
- Shared dimensions such as date, truck, driver, route, and facility should be included only where they support defined analysis and can be related without creating ambiguous or fanout-prone joins.
- Candidate `fact_fuel_purchases` and `fact_maintenance_records` have now been investigated; their grains and measures should be finalized in Gold design.
- Candidate `fact_safety_incidents`: one row per incident, with recorded incident rates using validated trip exposure; driver/truck drill-downs remain descriptive until entity-level exposure is validated.

Final fact/dimension selection, surrogate-key strategy, relationships, and DDL must be decided in the Gold model design stage after remaining cost and safety investigations.

## 10. Outstanding investigations

| Area | Status | Required next work |
|---|---|---|
| Reported load revenue | Investigated | Carry approved definition and accounting caveat into Gold |
| Trip activity | Investigated | Carry trip grain and dispatch-date definition into Gold |
| Fleet performance | Investigated | Carry weighted MPG, NULL truck handling, and utilization limitation into Gold |
| Delivery performance | Investigated | Carry Delivery-only denominator, partial January caveat, and detention finding into Gold |
| Customer performance | Investigated | Carry customer coverage, concentration, segmentation, and acquisition-proxy caveat into Gold |
| Fuel purchases | Investigated | Carry source-cost validation, assignment coverage, separate purchase/consumption grains, partial January 2025 caveat, and attribution rules into Gold |
| Maintenance | Investigated | Carry event grain, source-cost measure, truck attribution, maintenance categories, and downtime caveats into Gold design |
| Safety | Investigated | Carry incident grain, claim reconciliation, annual rates, classification flags, NULL attribution, and descriptive driver/truck drill-down rules into Gold design |
| Gold dimensional model | Pending | Define business processes, fact grains, dimensions, relationships, and measures before DDL |
| Gold validation | Pending | Define source-to-Gold reconciliation and business-rule checks after implementation |

## 11. Evidence and change-control notes

- This document records the investigation results and decisions available at the time of writing.
- The investigation SQL is maintained in `scripts/gold/gold_kpi_investigations.sql`. The exact Safety Performance queries 08A–08K supplied and executed during the investigation have been appended. For earlier Fuel checks 07A–07F, exact query text was not available in the reviewed source material and has not been reconstructed or presented as executed SQL.
- Do not imply that a query is committed merely because its output is documented here.
- When a new investigation is completed, add its query purpose, source tables and grain, result, interpretation, caveats, Gold implication, and status.
- If a definition changes, update this document and the Gold model/data dictionary together.
- Retain this document as project documentation after Gold is complete. It provides auditability and explains why the Gold KPIs and model were designed as they were. It should only be archived or shortened if it becomes redundant with a better-maintained final business-rules document; do not delete it merely because implementation is finished.


## 12. KPI 8 — Safety Performance

**Status: Investigated.** This investigation uses `silver.safety_incidents` at its natural grain (the level of detail represented by each row): one row per recorded safety incident. Trip exposure is sourced separately from `silver.trips`. The investigation contains 11 executed queries (09A–09K), preserved in `scripts/gold/gold_kpi_investigations.sql`.

### 12.1 Completeness, date coverage, and recorded amounts (09A)

| Measure | Result |
|---|---:|
| Total incident records | 170 |
| Incidents with incident_date | 170 |
| Incidents with incident_type | 170 |
| Incidents with trip_id | 170 |
| Incidents with truck_id | 169 |
| Incidents with driver_id | 169 |
| Incidents with at_fault_flag | 170 |
| Incidents with injury_flag | 170 |
| Incidents with preventable_flag | 170 |
| Incidents with vehicle_damage_cost | 170 |
| Incidents with cargo_damage_cost | 170 |
| Incidents with claim_amount | 170 |
| Incident date range | 2022-01-05 02:00 to 2024-12-24 09:00 |
| Total vehicle damage cost | 1,603,561.11 |
| Total cargo damage cost | 1,049,610.71 |
| Total recorded claim amount | 2,653,171.82 |
| Minimum / maximum claim amount | 0.00 / 64,245.72 |

All incidents have a date, type, trip ID, classification flags, damage amounts, and claim amount. One incident lacks a truck ID and one incident lacks a driver ID. The two missing identifiers belong to different incident records, as confirmed in the targeted attribution lookup.

The source currency was not established. Use **recorded claim amount**, **recorded vehicle damage cost**, and **recorded cargo damage cost**; do not label these values as AED, USD, or another assumed currency.

### 12.2 Claim amount reconciliation (09B)

The recorded claim amount was compared with the sum of vehicle and cargo damage costs for every incident, using a 0.01 tolerance (the accepted margin of difference).

| Validation | Result |
|---|---:|
| Total incidents | 170 |
| Matching incidents | 170 |
| Mismatching incidents | 0 |
| Maximum absolute difference | 0.00 |
| Total difference | 0.00 |

Every incident satisfies:

`claim_amount = vehicle_damage_cost + cargo_damage_cost`

**Decision:** Use source `claim_amount` as the claim measure. Do not add claim amount to vehicle and cargo damage costs when calculating a combined financial total; that would count the same damage twice. Vehicle and cargo damage remain useful as separate breakdown measures.

### 12.3 Missing truck and driver attribution (09C and 09E)

The two records with missing identifiers are:

| Incident | Trip | Missing identifier | Other incident identifier |
|---|---|---|---|
| INC00000060 | TRIP00067707 | truck_id | driver_id = DRV00101 |
| INC00000086 | TRIP00078852 | driver_id | truck_id = TRK00120 |

The associated trip records were checked:

- INC00000060: both the incident and trip record have NULL truck_id; driver DRV00101 is present in both.
- INC00000086: both the incident and trip record have NULL driver_id; truck TRK00120 is present in both.
- Both incidents occurred two calendar days after their associated trip dispatch dates.

The missing identifiers cannot be recovered from `silver.trips`. This is partial attribution (an incident can be linked to some operational entities but not all), not proof that the incident record itself is invalid.

**Decision:** Preserve both incidents. Keep `truck_id` and `driver_id` nullable in the candidate safety fact. Do not infer or manufacture missing identifiers.

### 12.4 Incident frequency, classifications, and financial impact by type (09D)

| Incident type | Incidents | At fault | Injury | Preventable | Vehicle damage | Cargo damage | Recorded claim |
|---|---:|---:|---:|---:|---:|---:|---:|
| DOT Violation | 39 | 16 | 5 | 18 | 300,252.95 | 281,194.27 | 581,447.22 |
| Equipment Damage | 35 | 14 | 10 | 9 | 408,250.78 | 332,719.95 | 740,970.73 |
| Accident | 35 | 8 | 4 | 14 | 337,990.48 | 149,427.66 | 487,418.14 |
| Customer Complaint | 34 | 8 | 10 | 13 | 351,743.20 | 80,748.74 | 432,491.94 |
| Moving Violation | 27 | 8 | 4 | 10 | 205,323.70 | 205,520.09 | 410,843.79 |
| **Total** | **170** | **54** | **33** | **64** | **1,603,561.11** | **1,049,610.71** | **2,653,171.82** |

DOT Violation is the most frequent category (39 incidents, 22.94% of all incidents). Equipment Damage has the largest recorded claim total (740,970.73) despite having fewer incidents than DOT Violation.

Average recorded claim per incident, calculated from the category totals:

| Incident type | Average recorded claim per incident |
|---|---:|
| Equipment Damage | 21,170.59 |
| Moving Violation | 15,216.44 |
| DOT Violation | 14,908.90 |
| Accident | 13,926.23 |
| Customer Complaint | 12,720.35 |

Frequency (how often an event occurs) and severity (the impact of an event) are different views. These claim amounts are descriptive financial measures; the dataset does not establish the currency or the cause of the differences.

### 12.5 Incident-to-trip relationship (09F)

| Measure | Result |
|---|---:|
| Incident records | 170 |
| Distinct trips with incidents | 170 |
| Additional incident records beyond one per trip | 0 |
| Incident trip IDs matched to Silver trips | 170 |
| Incident trip IDs not found | 0 |

Each recorded incident is associated with a different trip, and all 170 trip IDs match `silver.trips`. This is a one-to-one relationship within the observed incident records only; it does not mean every trip has an incident.

### 12.6 Overall safety rates (09G)

Trip exposure was calculated independently from `silver.trips` before being combined with incident totals. This avoids a fanout (a join that duplicates rows and inflates aggregated measures) between the trip and incident records.

| Measure | Result |
|---|---:|
| Recorded incidents | 170 |
| Distinct trips with incidents | 170 |
| Total trips | 85,410 |
| Total trip distance | 122,159,201 miles |
| Incidents per 1,000 trips | 1.9904 |
| Incidents per million miles | 1.3916 |
| Percentage of trips with a recorded incident | 0.1990% |

Definitions:

- **Incidents per 1,000 trips** = recorded incident count / total trips × 1,000.
- **Incidents per million miles** = recorded incident count / total trip miles × 1,000,000.
- **Percentage of trips with a recorded incident** = distinct trips with incidents / total trips × 100.

The incident count and distinct affected-trip count are equal in this dataset because each incident belongs to a different trip. These are recorded incident rates, not verified industry-standard safety rates. They depend on the completeness and consistency of incident reporting and should not be compared with another operator unless definitions and exposure methods are aligned.

### 12.7 Annual safety trend (09H)

Incident counts are grouped by `incident_date`; trip counts and distance are grouped by `dispatch_date`.

| Year | Incidents | Trips | Trip miles | Incidents / 1,000 trips | Incidents / million miles |
|---|---:|---:|---:|---:|---:|
| 2022 | 56 | 28,589 | 40,887,271 | 1.9588 | 1.3696 |
| 2023 | 54 | 28,165 | 40,496,933 | 1.9173 | 1.3334 |
| 2024 | 60 | 28,656 | 40,774,997 | 2.0938 | 1.4715 |

- From 2022 to 2023, both exposure-adjusted rates decreased slightly.
- From 2023 to 2024, incidents increased by 11.11%; incidents per 1,000 trips increased by approximately 9.20%; incidents per million miles increased by approximately 10.36%.
- Trip volume and mileage remained broadly similar across the three years.

**Defensible interpretation:** Recorded safety performance deteriorated in 2024 compared with 2023 because both incident rates increased while trip volume and distance remained relatively stable. The dataset does not establish why this occurred. The total of 170 incidents across three years is limited evidence for strong conclusions about long-term safety performance.

### 12.8 Overlap among at-fault, injury, and preventable flags (09I)

The three flags are independent classifications. All eight possible TRUE/FALSE combinations were present.

| At fault | Injury | Preventable | Incidents | Total recorded claim | Average recorded claim |
|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 0 | 58 | 894,330.16 | 15,419.49 |
| 0 | 0 | 1 | 36 | 484,358.19 | 13,454.39 |
| 1 | 0 | 0 | 24 | 417,023.18 | 17,375.97 |
| 1 | 0 | 1 | 19 | 307,687.10 | 16,194.06 |
| 0 | 1 | 0 | 15 | 253,153.02 | 16,876.87 |
| 1 | 1 | 0 | 9 | 184,189.50 | 20,465.50 |
| 0 | 1 | 1 | 7 | 97,411.30 | 13,915.90 |
| 1 | 1 | 1 | 2 | 15,019.37 | 7,509.69 |
| **Total** | | | **170** | **2,653,171.82** | — |

Overall classification totals:

| Classification | Incidents | Share of all incidents |
|---|---:|---:|
| At fault | 54 | 31.76% |
| Injury involved | 33 | 19.41% |
| Preventable | 64 | 37.65% |

These percentages overlap because one incident can satisfy more than one classification. Do not add them together.

Preventable does not mean at fault: 36 incidents were marked preventable but not at fault. Injury involvement is also independent of the other flags. The highest average claim appears in the at-fault, injury-involved, non-preventable group (9 incidents); the lowest average appears in the group marked all three (2 incidents). These small group sizes do not support strong severity conclusions.

### 12.9 Incident and trip calendar-year alignment (09J)

| Validation | Result |
|---|---:|
| Incidents matched to trips | 170 |
| Incident and dispatch in the same calendar year | 170 |
| Different calendar years | 0 |
| Minimum days from dispatch to incident | 0 |
| Maximum days from dispatch to incident | 3 |
| Average days from dispatch to incident | 1.129411 |

All incident dates fall in the same calendar year as the associated trip dispatch dates. This supports the annual comparison in Section 12.7, even though the incident and dispatch dates are not necessarily the same date.

### 12.10 Driver and truck attribution (09K)

| Measure | Result |
|---|---:|
| Total incidents | 170 |
| Distinct drivers involved | 92 |
| Distinct trucks involved | 80 |
| Incidents without driver ID | 1 |
| Incidents without truck ID | 1 |
| Distinct trips involved | 170 |

Driver and truck incident counts can support descriptive drill-downs (moving from an overall summary to a more detailed entity-level view). They should not be presented as individual performance rankings. A fair driver- or truck-level rate requires the corresponding driver- or truck-level exposure denominator (for example, trips or miles for that same driver or truck). Overall fleet exposure cannot be substituted for individual exposure.

### 12.11 Gold definitions, modelling decisions, and caveats

**Candidate fact grain:** `fact_safety_incidents`, one row per incident.

Recommended reporting scope:

- Overall safety: incident count, at-fault count, injury count, preventable count, recorded claim amount, vehicle damage, and cargo damage.
- Incident category: frequency, classification counts, recorded damage, and average/total claim amount.
- Time trends: incidents per 1,000 trips and per million miles, with incident date and trip dispatch date aligned by calendar year as validated.
- Driver and truck analysis: descriptive incident counts and financial measures, with NULL identifiers retained and no unsupported individual performance rankings.

Modelling and interpretation rules:

1. Retain `incident_id` as the incident identity and preserve one row per incident.
2. Retain nullable `trip_id`, `driver_id`, and `truck_id` relationships. In the observed data all incident trip IDs match; one driver ID and one truck ID are missing and cannot be recovered from the associated trip records.
3. Keep the incident fact separate from the trip fact. Do not directly join raw incident rows to other event facts and then sum their measures without controlling the relationship grain.
4. Use source `claim_amount` as the recorded claim measure. Vehicle and cargo damage are component views and must not be added again to claim amount.
5. Retain `at_fault_flag`, `injury_flag`, and `preventable_flag` independently.
6. Use recorded incident rates as descriptive operational measures, not as verified industry-standard rates.
7. Do not rank individual drivers or trucks as good/bad performers using raw incident counts. Add exposure-adjusted entity-level rates only after validating driver- and truck-specific trip/mileage denominators.
8. Currency is unknown. Do not label claim or damage amounts with a currency symbol or currency name until confirmed.
9. Do not infer causation for the 2024 increase or for differences among incident categories.

**Gold decision:** Include a candidate `fact_safety_incidents` in dimensional model design, with overall, category, annual, driver, and truck reporting supported. Driver- and truck-level views are descriptive drill-downs, not performance leaderboards.

