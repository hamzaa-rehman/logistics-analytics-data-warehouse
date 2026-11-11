# Bronze Investigation — Geographic Consistency of City/State Attributes

## 1. Objective and scope

CATEGORY profiling showed that several source tables contain city and state attributes. Frequency distributions alone cannot establish whether each city is consistently paired with one state. This investigation tested city/state consistency within six source relationships and compared two inconsistent sources with mappings found elsewhere in the dataset.

| Source relationship | City column | State column |
|---|---|---|
| delivery_events | location_city | location_state |
| fuel_purchases | location_city | location_state |
| facilities | city | state |
| safety_incidents | location_city | location_state |
| routes — origin | origin_city | origin_state |
| routes — destination | destination_city | destination_state |

Investigation SQL: [`investigate_geographic_consistency.sql`](../../../scripts/bronze/investigations/investigate_geographic_consistency.sql).

## 2. Methodology

### 2.1 Within-source consistency

For each relationship, records were grouped by city and the number of distinct state values was counted. A city associated with more than one state indicates an internal inconsistency in that source. A city associated with one state is only internally consistent; this does not prove geographic correctness.

### 2.2 Distinct city/state pairs

Each relationship was reduced to distinct city/state pairs and counted. These counts represent unique combinations, not underlying source rows.

### 2.3 Internal reference comparison

The mappings from `delivery_events`, `facilities`, and the route origin/destination relationships were combined as an internal reference. A reference state was used only when a city had exactly one distinct state across those sources.

Distinct pairs from `fuel_purchases` and `safety_incidents` were compared with that internal mapping and classified as Matches Reference, Mismatch, No Reference, or Ambiguous Reference.

This reference is derived from the same dataset. It is not an authoritative external geographic source.

## 3. Results

### 3.1 Within-source consistency

| Source relationship | Distinct cities | Distinct city/state pairs | Result |
|---|---:|---:|---|
| delivery_events | 20 | 20 | No city mapped to multiple states |
| fuel_purchases | 25 | 575 | Every observed city appeared with all 23 observed states |
| facilities | 21 | 21 | No city mapped to multiple states |
| safety_incidents | 25 | 145 | Cities appeared with multiple states |
| routes — origin | 18 | 18 | No origin city mapped to multiple states |
| routes — destination | 19 | 19 | No destination city mapped to multiple states |

For `fuel_purchases`, 25 cities and 23 states produced 575 distinct combinations (25 × 23), meaning every observed city was paired with every observed state in that table.

### 3.2 Comparison with the internal reference

| Source | Matches reference | Mismatches | Total distinct pairs |
|---|---:|---:|---:|
| fuel_purchases | 25 | 550 | 575 |
| safety_incidents | 7 | 138 | 145 |

No No Reference or Ambiguous Reference categories appeared in the reported summary; all pairs in these two sources were classified as either matching or disagreeing with a single internal reference state.

**These are distinct city/state pair counts, not affected transaction or incident row counts.** The investigation did not calculate the number or percentage of source records affected.

## 4. Interpretation

The results establish substantial disagreement between `fuel_purchases` and `safety_incidents` and the internally consistent mappings found in the other source relationships:

- `fuel_purchases`: 550 of 575 distinct pairs disagreed with the internal reference.
- `safety_incidents`: 138 of 145 distinct pairs disagreed with the internal reference.

A match does not prove real-world geographic accuracy. The investigation also does not establish the cause of the disagreements. Source-generation issues or independently assigned city and state fields are possible explanations, but neither was proven by these queries.

## 5. Data-quality assessment

| Source | Assessment | Evidence | Status |
|---|---|---|---|
| fuel_purchases city/state | Significant internal inconsistency | 575 distinct pairs; 550 disagree with internal reference | Internal disagreement confirmed; root cause unknown |
| safety_incidents city/state | Significant internal inconsistency | 145 distinct pairs; 138 disagree with internal reference | Internal disagreement confirmed; root cause unknown |
| delivery_events, facilities, routes | Internally consistent in this check | Each city had one state within each tested relationship | External correctness not verified |

This finding demonstrates disagreement among source tables. It does not prove that every mismatching state is geographically false.

## 6. Recommended Silver-layer handling

1. Preserve original Bronze city and state values.
2. Identify and approve an authoritative geographic reference or a documented business-owned mapping.
3. Validate the suspect pairs against that approved reference.
4. Define explicit handling for unmatched, ambiguous, and invalid pairs.
5. Apply any standardization or correction in Silver using documented, reproducible rules.
6. Retain lineage so original source values remain traceable.

Do not silently replace source states using the internal reference alone. Internal agreement is useful for prioritizing validation, not a substitute for authoritative verification.

## 7. Limitations

- **No external verification:** The internal reference may itself contain geographically incorrect but internally consistent mappings.
- **Distinct-pair grain:** Counts represent unique city/state pairs, not source-record impact.
- **No root-cause analysis:** The queries identify disagreement but do not explain how it arose.
- **Text matching:** Aliases, alternate spellings, abbreviations, and city names shared by different states were not resolved.
- **Current snapshot:** Results apply to the Bronze data present when the queries were executed.

## 8. Conclusion and status

The investigation found major internal city/state inconsistencies in `fuel_purchases` and `safety_incidents`: 550 and 138 mismatching distinct pairs, respectively, against the internal reference mapping.

The internal comparison is complete. Geographic correctness remains **unverified externally** and must be validated against an approved reference or business rule before any Silver-layer correction.

## 9. Related resources

- [CATEGORY profiling report](../category_profiling.md)
- [CATEGORY profiling SQL](../../../scripts/bronze/profile_category.sql)
- [Geographic consistency investigation SQL](../../../scripts/bronze/investigations/investigate_geographic_consistency.sql)
- [Bronze Layer README](../readme.md)
