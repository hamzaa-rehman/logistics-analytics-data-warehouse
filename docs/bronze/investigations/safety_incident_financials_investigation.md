# Investigation: `safety_incidents` financial metrics

## 1. Investigation Overview

This investigation examines zero values and financial relationships across three numeric columns in the Bronze `safety_incidents` table:

- `cargo_damage_cost`
- `vehicle_damage_cost`
- `claim_amount`

The investigation was initiated after numeric profiling identified zero values in all three columns.

The objective was to determine whether these zero values show suspicious patterns, whether they are associated with particular incident categories or flags, and whether the three financial columns have a consistent mathematical relationship.

The investigation also examines positive financial values to understand their distribution across incident types.

### 1.1 Investigation Objectives

1. Identify combinations of zero values across the three financial columns.
2. Examine zero-value distributions by incident type.
3. Compare zero-value patterns across incident flags.
4. Analyze the distribution of positive cargo and vehicle damage costs.
5. Review selected high- and low-value cargo damage records and their descriptions.
6. Validate whether `claim_amount` equals the combined vehicle and cargo damage costs.
7. Establish appropriate recommendations for handling these values in the Silver layer.

### 1.2 Source Table

| Property | Details |
|---|---|
| Source layer | Bronze |
| Schema | `bronze` |
| Table | `safety_incidents` |
| Total records | 170 |
| Financial columns | `cargo_damage_cost`, `vehicle_damage_cost`, `claim_amount` |
| Source data type | `VARCHAR` |
| Numeric profiling conversion | `DECIMAL(18,4)` |

All three financial columns successfully passed the earlier numeric profiling conversion checks. No NULL values or invalid numeric conversions were identified in these columns.

---

## 2. Initial Numeric Profiling Findings

The initial numeric profiling identified the following zero-value counts:

| Column | Total Records | Zero Values | Positive Values |
|---|---:|---:|---:|
| `cargo_damage_cost` | 170 | 122 | 48 |
| `vehicle_damage_cost` | 170 | 52 | 118 |
| `claim_amount` | 170 | 39 | 131 |

No negative values were identified in these three columns.

The zero values required further investigation because a zero financial amount can represent a legitimate absence of damage or cost, but it can also reflect a source-data or business-process issue.

Zero values were therefore investigated rather than automatically classified as missing or incorrect.

---

## 3. Zero-Value Combination Analysis

### 3.1 Objective

The first investigation examined how the three financial columns contained zero values together.

This helped establish whether zero values occurred independently or whether certain financial columns consistently contained zero values at the same time.

### 3.2 Results

Four combinations were identified across the 170 incidents.

| Zero Cargo Damage | Zero Claim Amount | Zero Vehicle Damage | Incident Count |
|---:|---:|---:|---:|
| 1 | 0 | 0 | 83 |
| 1 | 1 | 1 | 39 |
| 0 | 0 | 0 | 35 |
| 0 | 0 | 1 | 13 |
| **Total** | | | **170** |

`1` indicates that the corresponding financial column contains zero; `0` indicates a non-zero value.

### 3.3 Observations

- 83 incidents had zero cargo damage cost while vehicle damage cost and claim amount were non-zero.
- 39 incidents had zero values in all three financial columns.
- 35 incidents had positive values in all three financial columns.
- 13 incidents had zero vehicle damage cost while cargo damage cost and claim amount were non-zero.
- All 39 incidents with zero claim amounts also had zero cargo and vehicle damage costs.
- No incident had a zero claim amount alongside positive values in either damage-cost column.

The zero counts reconcile with the initial numeric profiling:

- Cargo damage: 83 + 39 = 122 zero values.
- Claim amount: 39 zero values.
- Vehicle damage: 39 + 13 = 52 zero values.

### 3.4 Interpretation

The zero values do not represent one uniform pattern.

Some incidents have zero values in individual damage categories, while others have zero values across all three financial columns.

This suggests that the columns capture different combinations of recorded damage costs. However, the dataset does not provide enough business documentation to establish why each individual incident has a particular financial value.

---

## 4. Categorical Distribution Analysis

### 4.1 Objective

The categorical columns were reviewed to understand the overall composition of the incident records and provide context for the financial analysis.

The following dimensions were examined:

- `incident_type`
- `at_fault_flag`
- `injury_flag`
- `preventable_flag`

### 4.2 Overall Distributions

**Incident type**

| Incident Type | Incident Count |
|---|---:|
| Accident | 35 |
| Customer Complaint | 34 |
| DOT Violation | 39 |
| Equipment Damage | 35 |
| Moving Violation | 27 |
| **Total** | **170** |

**Incident flags**

| Column | Category | Incident Count |
|---|---|---:|
| `at_fault_flag` | False | 116 |
| `at_fault_flag` | True | 54 |
| `injury_flag` | False | 137 |
| `injury_flag` | True | 33 |
| `preventable_flag` | False | 106 |
| `preventable_flag` | True | 64 |

Each categorical distribution accounts for all 170 incident records.

---

## 5. Zero-Value Analysis by Incident Type

### 5.1 Objective

Zero-value counts and percentages were compared across the five incident types.

Percentages were calculated within each incident type to account for differences in category sizes.

### 5.2 Zero-Value Counts

| Incident Type | Total Incidents | Zero Cargo Damage | Zero Claim Amount | Zero Vehicle Damage |
|---|---:|---:|---:|---:|
| Accident | 35 | 29 | 8 | 9 |
| Customer Complaint | 34 | 25 | 8 | 11 |
| DOT Violation | 39 | 28 | 12 | 14 |
| Equipment Damage | 35 | 22 | 5 | 9 |
| Moving Violation | 27 | 18 | 6 | 9 |
| **Total** | **170** | **122** | **39** | **52** |

### 5.3 Zero-Value Percentages

| Incident Type | Zero Cargo Damage | Zero Claim Amount | Zero Vehicle Damage |
|---|---:|---:|---:|
| Accident | 82.86% | 22.86% | 25.71% |
| Customer Complaint | 73.53% | 23.53% | 32.35% |
| DOT Violation | 71.79% | 30.77% | 35.90% |
| Equipment Damage | 62.86% | 14.29% | 25.71% |
| Moving Violation | 66.67% | 22.22% | 33.33% |

### 5.4 Observations

- Every incident type contains both zero and positive values across the financial columns.
- Accident incidents have the highest zero cargo damage percentage at 82.86%.
- Equipment Damage incidents have the lowest zero cargo damage percentage at 62.86%.
- DOT Violations have the highest zero claim amount percentage at 30.77%.
- DOT Violations also have the highest zero vehicle damage percentage at 35.90%.
- Equipment Damage incidents have the lowest zero claim amount percentage at 14.29%.

### 5.5 Interpretation

Zero values are distributed across all five incident types rather than being isolated to a single category.

Although some differences exist between incident types, the descriptive results do not establish that incident type causes or explains the presence of zero financial values.

---

## 6. Zero-Value Analysis by Incident Flags

### 6.1 Objective

The investigation also compared zero-value counts across the three incident flags:

- `at_fault_flag`
- `injury_flag`
- `preventable_flag`

The purpose was to identify whether the presence of zero financial values showed notable differences between the categories of these flags.

### 6.2 Results

The following percentages represent zero values within each flag category.

| Dimension | Category | Zero Cargo Damage | Zero Claim Amount | Zero Vehicle Damage |
|---|---|---:|---:|---:|
| At fault | False | 69.83% | 25.00% | 34.48% |
| At fault | True | 75.93% | 18.52% | 22.22% |
| Injury | False | 71.53% | 23.36% | 29.20% |
| Injury | True | 72.73% | 21.21% | 36.36% |
| Preventable | False | 73.58% | 18.87% | 26.42% |
| Preventable | True | 68.75% | 29.69% | 37.50% |

### 6.3 Observations

- Cargo damage zero percentages are relatively similar across the flag categories.
- Claim amount zero percentages differ between preventable and non-preventable incidents.
- Vehicle damage zero percentages are also higher in the preventable category than in the non-preventable category.
- Injury and non-injury categories show relatively similar cargo damage and claim amount zero percentages.
- No single flag category explains the occurrence of zero values across all three financial columns.

### 6.4 Interpretation

The results show descriptive differences between some flag categories.

For example, preventable incidents have higher zero claim and vehicle damage percentages than non-preventable incidents in this dataset.

These observations do not establish causation or statistical significance. They should not be treated as evidence that a particular incident flag determines whether financial damage occurs.

---

## 7. Positive Cargo Damage Cost Analysis

### 7.1 Objective

The 48 incidents with positive `cargo_damage_cost` values were examined separately.

The investigation compared positive cargo damage costs across incident types using:

- Number of positive records
- Total positive cost
- Average positive cost
- Median positive cost
- Minimum and maximum positive cost

Zero values were excluded from the positive-cost averages and medians.

### 7.2 Positive Cargo Damage Summary

| Incident Type | Positive Records | Total Cost | Average Cost | Median Cost |
|---|---:|---:|---:|---:|
| Accident | 6 | 149,427.66 | 24,904.61 | 19,570.63 |
| Customer Complaint | 9 | 80,748.74 | 8,972.08 | 6,225.41 |
| DOT Violation | 11 | 281,194.27 | 25,563.12 | 28,315.16 |
| Equipment Damage | 13 | 332,719.95 | 25,593.84 | 24,601.04 |
| Moving Violation | 9 | 205,520.09 | 22,835.57 | 31,507.48 |
| **Total** | **48** | **1,049,610.71** | | |

### 7.3 Positive Cargo Damage Ranges

| Incident Type | Positive Records | Minimum Positive Cost | Maximum Positive Cost | Average Positive Cost |
|---|---:|---:|---:|---:|
| Accident | 6 | 5,222.46 | 49,744.07 | 24,904.61 |
| Customer Complaint | 9 | 376.13 | 28,390.39 | 8,972.08 |
| DOT Violation | 11 | 2,310.73 | 49,251.50 | 25,563.12 |
| Equipment Damage | 13 | 32.85 | 47,959.36 | 25,593.84 |
| Moving Violation | 9 | 214.41 | 36,910.92 | 22,835.57 |

### 7.4 Observations

- Equipment Damage incidents have the highest number of positive cargo damage records, with 13.
- Customer Complaint incidents have the lowest average positive cargo damage cost.
- Equipment Damage and DOT Violation incidents have the highest average positive cargo damage costs.
- The average and median values differ in several categories, indicating that the distributions are not necessarily symmetrical.
- The positive-record counts within individual categories are relatively small, ranging from 6 to 13.

### 7.5 Interpretation

Positive cargo damage costs vary across incident types.

However, the relatively small number of positive records in each category means these statistics should be interpreted descriptively. They do not establish formal outliers or reliable differences in underlying incident severity.

---

## 8. Individual Cargo Damage Record Review

### 8.1 Objective

All 48 positive cargo damage records were inspected in descending cost order.

The five highest and five lowest positive cargo damage records were also reviewed alongside their incident descriptions and flags.

### 8.2 Highest Positive Cargo Damage Records

| Incident ID | Incident Type | Cargo Damage Cost | Description |
|---|---|---:|---|
| INC00000109 | Accident | 49,744.07 | Severe incident involving other driver |
| INC00000034 | DOT Violation | 49,251.50 | Minor incident involving other driver |
| INC00000070 | Equipment Damage | 47,959.36 | Moderate incident involving traffic |
| INC00000089 | DOT Violation | 45,853.75 | Severe incident involving equipment |
| INC00000159 | Equipment Damage | 44,746.09 | Severe incident involving other driver |

### 8.3 Lowest Positive Cargo Damage Records

| Incident ID | Incident Type | Cargo Damage Cost | Description |
|---|---|---:|---|
| INC00000104 | Moving Violation | 383.06 | Severe incident involving other driver |
| INC00000009 | Customer Complaint | 379.10 | Moderate incident involving traffic |
| INC00000039 | Customer Complaint | 376.13 | Moderate incident involving equipment |
| INC00000094 | Moving Violation | 214.41 | Severe incident involving equipment |
| INC00000111 | Equipment Damage | 32.85 | Moderate incident involving traffic |

### 8.4 Observations

The incident descriptions do not consistently correspond to the magnitude of cargo damage costs.

For example, a record described as a minor incident has one of the highest cargo damage costs, while a record described as severe has a relatively low cargo damage cost.

### 8.5 Interpretation

The description field may refer to overall incident severity or another aspect of the incident rather than the financial impact on cargo specifically.

The available data does not establish a direct relationship between the wording of the descriptions and cargo damage amounts.

No records were classified as erroneous based solely on this comparison.

---

## 9. Claim Amount and Combined Damage Cost Validation

### 9.1 Objective

A further investigation examined whether `claim_amount` is mathematically equal to the combined values of `vehicle_damage_cost` and `cargo_damage_cost`.

The following relationship was tested for every incident:

`claim_amount = vehicle_damage_cost + cargo_damage_cost`

The difference was calculated as:

`Difference = claim_amount - (vehicle_damage_cost + cargo_damage_cost)`

A difference of zero indicates an exact arithmetic match.

### 9.2 Results

| Validation Metric | Result |
|---|---:|
| Total incidents tested | 170 |
| Matching records | 170 |
| Mismatching records | 0 |
| Match percentage | 100% |

All 170 records produced a difference of `0.0000`.

### 9.3 Interpretation

The investigation confirmed that `claim_amount` is mathematically equal to the sum of `vehicle_damage_cost` and `cargo_damage_cost` for every record in the dataset.

This is a consistent arithmetic relationship across all 170 incidents.

However, the validation establishes the relationship in the available data, not the independently verified business definition of `claim_amount`.

It remains possible that the source dataset uses this formula as a construction rule. No external claim documentation or business specification was available to confirm the intended meaning.

### 9.4 Data Modeling Consideration

The arithmetic relationship is important when designing the Silver and Gold layers.

Before deciding whether to retain, recalculate, or derive `claim_amount`, its business definition should be confirmed.

Until then, the original source column should be preserved.

---

## 10. Positive Vehicle Damage Cost Analysis

### 10.1 Objective

The 118 incidents with positive `vehicle_damage_cost` values were examined by incident type.

The analysis compared:

- Total incidents
- Number of positive records
- Minimum positive cost
- Maximum positive cost
- Average positive cost

### 10.2 Results

| Incident Type | Total Incidents | Positive Records | Minimum Positive Cost | Maximum Cost | Average Positive Cost |
|---|---:|---:|---:|---:|---:|
| Accident | 35 | 26 | 852.10 | 24,614.16 | 12,999.63 |
| Customer Complaint | 34 | 23 | 2,870.01 | 24,302.32 | 15,293.18 |
| DOT Violation | 39 | 25 | 837.51 | 24,102.19 | 12,010.12 |
| Equipment Damage | 35 | 26 | 2,103.69 | 23,775.81 | 15,701.95 |
| Moving Violation | 27 | 18 | 1,898.17 | 19,681.98 | 11,406.87 |
| **Total** | **170** | **118** | | | |

### 10.3 Observations

- Every incident type contains both zero and positive vehicle damage costs.
- Equipment Damage incidents have the highest average positive vehicle damage cost.
- Moving Violation incidents have the lowest average positive vehicle damage cost.
- The positive vehicle damage counts reconcile to 118 records, while 52 records contain zero values.

### 10.4 Interpretation

Positive vehicle damage costs are present across all five incident types.

The observed differences are descriptive and do not establish that incident type causes a particular vehicle damage cost.

---

## 11. Consolidated Findings

The investigation produced the following findings:

| Area | Finding | Status |
|---|---|---|
| Cargo damage zero values | 122 zero values and 48 positive values | Investigated |
| Vehicle damage zero values | 52 zero values and 118 positive values | Investigated |
| Claim amount zero values | 39 zero values and 131 positive values | Investigated |
| Zero-value combinations | Four distinct combinations identified across all incidents | Investigated |
| Incident type analysis | Zero and positive values occur across all five incident types | Investigated |
| Incident flag analysis | Descriptive differences exist, but no causal conclusion is established | Investigated |
| Positive cargo damage | 48 positive records reviewed by incident type | Investigated |
| Cargo descriptions | Description wording does not consistently correspond to cargo damage magnitude | Investigated |
| Claim amount relationship | All 170 records satisfy the arithmetic relationship with zero mismatches | Validated |
| Positive vehicle damage | 118 positive records reviewed by incident type | Investigated |
| NULL and numeric conversion checks | No NULL values or invalid numeric conversions identified in the three columns | Passed |

---

## 12. Conclusions and Silver Layer Recommendations

### 12.1 Preserve Zero Values

The investigation did not identify evidence that the zero values in the three financial columns are automatically invalid.

Zero values occur across multiple incident types and flag categories, and their combinations show different financial patterns.

**Recommendation:**

Preserve zero values as zero in the Silver layer.

Do not automatically:

- Convert zero values to NULL.
- Replace zero values with averages or other estimated values.
- Impute financial amounts.
- Treat every zero as a data-quality error.

Any future change should be supported by a confirmed business definition or additional source evidence.

### 12.2 Preserve the Three Financial Columns

Retain the following source attributes in Silver:

- `cargo_damage_cost`
- `vehicle_damage_cost`
- `claim_amount`

Although `claim_amount` matches the sum of the two damage-cost columns for all 170 records, its business definition has not been independently confirmed.

Do not remove or redefine the source column based only on the observed arithmetic relationship.

### 12.3 Convert to Appropriate Numeric Types in Silver

The Bronze columns are stored as `VARCHAR`.

During Silver transformation, convert the financial values to an appropriate numeric data type after applying the planned conversion and validation rules.

The original Bronze values should remain unchanged.

### 12.4 Retain the Source Values Until Business Definitions Are Confirmed

The investigation does not establish:

- Whether zero means no damage, no recorded cost, or another business condition.
- Whether the three financial columns represent actual incurred costs, estimates, or another financial measure.
- Whether `claim_amount` is formally defined as the sum of the two damage-cost columns.
- Which currency or monetary unit is used.

These points require additional business documentation or source-system confirmation.

---

## 13. Limitations

The findings should be interpreted within the limitations of the available dataset.

1. **No confirmed currency unit:** The monetary unit has not been verified. Values are therefore reported in dataset units without assigning a currency.
2. **No business definitions:** Definitions for cargo damage cost, vehicle damage cost, and claim amount were not available.
3. **No external validation:** Financial amounts were not compared against contracts, insurance records, invoices, or external claim documentation.
4. **Descriptive analysis only:** Category comparisons do not establish causality or statistical significance.
5. **Limited positive-record counts:** Some incident types contain relatively few positive cargo damage records, so their averages and medians should be interpreted cautiously.
6. **Arithmetic consistency is not business validation:** The exact relationship between claim amount and the two damage-cost columns confirms internal arithmetic consistency, not the independently verified meaning or correctness of the amounts.
7. **Source completeness is unverified:** The investigation does not independently establish whether every real-world incident or financial amount has been captured in the source dataset.

---

## 14. Final Investigation Decision

**Recommended handling for the Silver layer:**

| Column | Recommendation | Reason |
|---|---|---|
| `cargo_damage_cost` | Preserve zero values and retain the column | Zero values occur across incident types and flags; no confirmed evidence identifies them as invalid |
| `vehicle_damage_cost` | Preserve zero values and retain the column | Zero and positive values occur across all five incident types |
| `claim_amount` | Preserve zero values and retain the column | All 170 records match the sum of the two damage-cost columns, but the business definition remains unverified |

**Overall conclusion:**

The investigation did not identify a clear data-quality anomaly that justifies changing the zero values in these three financial columns.

The exact arithmetic relationship between `claim_amount` and the two damage-cost columns demonstrates internal consistency across all 170 records.

The recommended approach is to preserve the original financial values, convert them to appropriate numeric types during Silver processing, and avoid assumptions about missing values, currency, or business meaning until further evidence is available.

---

## 15. Related Files

**Investigation SQL script:**

[`investigate_safety_incident_financials.sql`](../../../scripts/bronze/investigations/investigate_safety_incident_financials.sql)

**Related Bronze documentation:**

- [`numeric_profiling.md`](../numeric_profiling.md)
- [`readme.md`](../readme.md)

---

*Investigation performed against the Bronze `safety_incidents` table. The findings and query results are based on the 170 records available in the source dataset.*
