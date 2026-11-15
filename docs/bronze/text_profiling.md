# Bronze Layer — TEXT Profiling

## 1. Purpose and scope

TEXT profiling examines descriptive text columns that are not primarily identifiers or controlled categories. The objective is to assess completeness, basic text length, distinct values, and selected value distributions without changing the raw Bronze data.

The profiling covered all **7 columns classified as `TEXT`** in `bronze.profiling_config`, across five Bronze tables.

Reusable SQL: [`profile_text_columns.sql`](../../scripts/bronze/profile_text_columns.sql).

## 2. Methodology

The script validates the profiling configuration against SQL Server metadata and dynamically generates summary queries for every configured TEXT column.

For each column, it reports:

- Total row count.
- NULL count.
- True empty-string count.
- Whitespace-only count.
- Distinct non-NULL value count.
- Minimum, maximum, and average text length for non-empty values.

### Whitespace and length handling

A true empty string is identified using `DATALENGTH(column) = 0`. This avoids relying on equality with `''`, because SQL Server character comparisons can treat trailing spaces as insignificant.

Whitespace-only detection converts tabs (`CHAR(9)`), line feeds (`CHAR(10)`), and carriage returns (`CHAR(13)`) to ordinary spaces before applying `TRIM()`. The check therefore covers ordinary spaces and these common control characters, but is not a universal Unicode-whitespace test.

`LEN()` is used for character length and ignores trailing ordinary spaces. NULL, empty, and detected whitespace-only values are excluded from the length statistics.

The script also produces frequency distributions for `facilities.operating_hours`, `maintenance_records.service_description`, and `safety_incidents.description`.

## 3. Overall results

| Check | Result |
|---|---:|
| Configured TEXT columns | 7 |
| Tables represented | 5 |
| Total rows across the seven columns | 3,690 |
| NULL values | 0 |
| Empty strings | 0 |
| Whitespace-only values detected | 0 |

All seven columns contained non-empty values in the observed extract.

## 4. Column-level results

| Table | Column | Rows | Distinct values | Min length | Max length | Avg length |
|---|---|---:|---:|---:|---:|---:|
| customers | customer_name | 200 | 107 | 8 | 25 | 15.395000 |
| drivers | first_name | 150 | 20 | 4 | 9 | 6.100000 |
| drivers | last_name | 150 | 20 | 5 | 9 | 6.626666 |
| facilities | facility_name | 50 | 35 | 11 | 32 | 21.620000 |
| facilities | operating_hours | 50 | 4 | 4 | 8 | 6.240000 |
| maintenance_records | service_description | 2,920 | 21 | 12 | 22 | 16.945890 |
| safety_incidents | description | 170 | 12 | 32 | 40 | 35.100000 |

The row total of 3,690 is the sum of rows profiled across the seven columns; it is not a count of unique records across the database.

## 5. Selected frequency observations

### 5.1 Facility operating hours

| Operating hours | Rows |
|---|---:|
| 24/7 | 16 |
| 8AM-5PM | 13 |
| 7AM-7PM | 11 |
| 6AM-10PM | 10 |
| **Total** | **50** |

Four distinct schedule labels were observed. The values use a consistent, readable text format in the reviewed frequency output. This does not independently validate whether each facility's schedule is operationally correct.

**Silver consideration:** retain the source field as text unless a defined scheduling requirement justifies parsing it into structured time attributes.

### 5.2 Maintenance service descriptions

There were 21 distinct descriptions across 2,920 maintenance records. The observed descriptions combine a maintenance classification (for example, Scheduled, Routine, or Emergency) with a service area or activity (for example, Engine, Inspection, Tire, Repair, Preventive, Transmission, or Brake).

Frequencies ranged from 121 to 152 records per description. No single description dominated the distribution.

**Silver consideration:** preserve the original description. Separate attributes such as maintenance classification and service category may be derived later if the naming pattern is confirmed and parsing rules are validated. No split is applied in Bronze.

### 5.3 Safety incident descriptions

There were 12 distinct descriptions across 170 safety incidents. The descriptions follow a pattern combining three severity labels (Minor, Moderate, Severe) with four contexts (Traffic, Weather, Other driver, Equipment). All 12 combinations appeared in the observed frequency output.

**Silver consideration:** preserve the original description. Derived severity and context attributes may support analysis, but should only be created after validating the source wording and parsing rules.

## 6. Findings and analytical decisions

| Finding | Assessment | Silver-layer consideration |
|---|---|---|
| No NULL, empty, or detected whitespace-only values | No completeness issue detected by these checks in the current extract | No missing-text handling is indicated by this profile alone |
| Customer and driver names contain repeated values | Repetition is expected for names and does not make them unique identifiers | Retain as descriptive attributes; do not use names as keys |
| Facility names have 35 distinct values across 50 rows | Names are descriptive and not necessarily unique | Retain as text; use facility identifiers for joins |
| Operating hours have four distinct labels | Values are compact schedule descriptions | Retain as text unless a validated structured schedule is needed |
| Maintenance descriptions show a repeated two-part naming pattern | Potential opportunity for analytical attributes | Preserve source text; consider derived fields only after validating the pattern |
| Safety incident descriptions cover 12 severity/context combinations | Potential opportunity for analytical attributes | Preserve source text; consider derived fields only after validating the pattern |

These are observations and recommendations, not confirmed source-system business rules or proof of full semantic correctness.

## 7. Limitations

1. **Current extract:** Results describe the data available when profiling was executed and may change after a Bronze refresh.
2. **Whitespace scope:** The check covers ordinary spaces, tabs, line feeds, and carriage returns after replacement. Other Unicode whitespace characters were not comprehensively tested.
3. **Length semantics:** SQL Server `LEN()` excludes trailing ordinary spaces; the reported lengths follow that SQL Server behavior.
4. **Descriptive profiling:** Distinct counts and frequencies do not establish whether names, schedules, or descriptions are factually correct.
5. **Pattern interpretation:** The suggested maintenance and incident attributes are hypotheses for downstream modelling, not transformations performed in Bronze.

## 8. Conclusion

All seven configured TEXT columns were profiled for the current Bronze extract. The checks found no NULL, empty, or detected whitespace-only values. Selected frequency distributions revealed consistent schedule labels and repeatable descriptive patterns in maintenance and safety incident text.

The original text fields should be preserved in Bronze. Any structured attributes derived from descriptive text should be introduced and validated in Silver, with the source description retained for traceability.

## 9. Related resources

- [Bronze Layer README](readme.md)
- [Numeric profiling](numeric_profiling.md)
- [DATE and DATETIME profiling](date_datetime_profiling.md)
- [CATEGORY profiling](category_profiling.md)
- [TEXT profiling SQL](../../scripts/bronze/profile_text_columns.sql)
