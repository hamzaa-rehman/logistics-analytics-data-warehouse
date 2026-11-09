/*
    Investigation: delivery_events.detention_minutes
    Project: Logistics Analytics Data Warehouse
    Layer: Bronze

    These are the author's executed detention-related queries,
    reorganized into readable sections with explanatory comments.
    Query logic is retained.

    Important data-type note:
      Bronze columns are VARCHAR. MIN() and MAX() applied directly to
      detention_minutes therefore sort text, not numeric values.
      The original queries are retained as executed, but their min/max
      outputs must not be interpreted as numeric extrema.
      Numeric profiling previously identified a numeric maximum of 239.
      Run a separately cast numeric aggregation if grouped numeric
      minimum/maximum values are required.

    Investigation status:
      The business definition of detention_minutes and its relationship
      to event timing/on_time_flag remain unresolved.
*/

USE LogisticsAnalytics;
GO

/* 1. Frequency distribution of the source detention values.
      ORDER BY follows VARCHAR/text ordering. */
SELECT
    detention_minutes,
    COUNT(*) AS record_count
FROM bronze.delivery_events
GROUP BY detention_minutes
ORDER BY detention_minutes;
GO

/* 2. Detention distribution by event type.
      MIN/MAX are retained as executed; they sort VARCHAR text. */
SELECT
    event_type,
    COUNT(*) AS total_events,
    SUM(CASE WHEN detention_minutes = 0 THEN 1 ELSE 0 END) AS zero_detention,
    SUM(CASE WHEN detention_minutes > 0 THEN 1 ELSE 0 END) AS positive_detention,
    MIN(detention_minutes) AS min_detention,
    MAX(detention_minutes) AS max_detention,
    AVG(CAST(detention_minutes AS DECIMAL(10,2))) AS avg_detention
FROM bronze.delivery_events
GROUP BY event_type
ORDER BY event_type;
GO

/* 3. Detention by facility and event type.
      MAX is retained as executed; it sorts VARCHAR text. */
SELECT
    facility_id,
    event_type,
    COUNT(*) AS total_events,
    SUM(CASE WHEN detention_minutes = 0 THEN 1 ELSE 0 END) AS zero_detention,
    AVG(CAST(detention_minutes AS DECIMAL(10,2))) AS avg_detention,
    MAX(detention_minutes) AS max_detention
FROM bronze.delivery_events
GROUP BY
    facility_id,
    event_type
ORDER BY
    facility_id,
    event_type;
GO

/* 4. Inspect delivery_events column names and data types. */
SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bronze'
  AND TABLE_NAME = 'delivery_events'
ORDER BY ORDINAL_POSITION;
GO

/* 5. Detention by event type and on-time flag. */
SELECT
    event_type,
    on_time_flag,
    COUNT(*) AS total_events,
    SUM(CASE WHEN detention_minutes = 0 THEN 1 ELSE 0 END) AS zero_detention,
    SUM(CASE WHEN detention_minutes > 0 THEN 1 ELSE 0 END) AS positive_detention,
    AVG(CAST(detention_minutes AS DECIMAL(10,2))) AS avg_detention
FROM bronze.delivery_events
GROUP BY
    event_type,
    on_time_flag
ORDER BY
    event_type,
    on_time_flag;
GO

/* 6. Inspect the first 20 delivery event records. */
SELECT TOP 20
    event_id,
    event_type,
    scheduled_datetime,
    actual_datetime,
    on_time_flag,
    detention_minutes
FROM bronze.delivery_events
ORDER BY event_id;
GO
